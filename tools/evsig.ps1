# Finds the C++ argument types of Panorama events in a Source 2 client.dll.
# For each event name: locate the name string, find code that references it, and report the
# RTTI class names (e.g. CUIEvent<1, CUtlStringToken, CPlayerSlot>) of vtables referenced nearby.
#   .\tools\evsig.ps1 -Names CitadelShowModTooltip,CitadelHideModTooltip
param(
    [string[]]$Names,
    [string]$Dll = 'C:\Program Files (x86)\Steam\steamapps\common\Deadlock\game\citadel\bin\win64\client.dll',
    [int]$Window = 0x180,
    [int]$Depth = 2,
    [switch]$Dump,
    [int]$Before = 0x40,
    [int]$After = 0x60
)

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public class EvSig {
    byte[] d; ulong imageBase;
    struct Sec { public string Name; public uint VA, VSize, Raw, RawSize; }
    List<Sec> secs = new List<Sec>();
    Sec text;
    // lea target rva -> list of instruction rvas
    Dictionary<uint, List<uint>> leaByTarget = new Dictionary<uint, List<uint>>();
    List<KeyValuePair<uint, uint>> leas = new List<KeyValuePair<uint, uint>>(); // (insn rva, target rva), sorted by insn

    public EvSig(string path) {
        d = File.ReadAllBytes(path);
        int pe = BitConverter.ToInt32(d, 0x3c);
        int nsec = BitConverter.ToUInt16(d, pe + 6);
        int optSize = BitConverter.ToUInt16(d, pe + 20);
        imageBase = BitConverter.ToUInt64(d, pe + 24 + 24);
        int s = pe + 24 + optSize;
        for (int i = 0; i < nsec; i++, s += 40) {
            var sec = new Sec();
            sec.Name = Encoding.ASCII.GetString(d, s, 8).TrimEnd('\0');
            sec.VSize = BitConverter.ToUInt32(d, s + 8);
            sec.VA = BitConverter.ToUInt32(d, s + 12);
            sec.RawSize = BitConverter.ToUInt32(d, s + 16);
            sec.Raw = BitConverter.ToUInt32(d, s + 20);
            secs.Add(sec);
            if (sec.Name == ".text") text = sec;
        }
        // index every rip-relative LEA in .text
        long end = text.Raw + Math.Min(text.RawSize, text.VSize) - 7;
        for (long i = text.Raw; i < end; i++) {
            byte rex = d[i];
            if ((rex == 0x48 || rex == 0x4C) && d[i + 1] == 0x8D && (d[i + 2] & 0xC7) == 0x05) {
                uint insn = (uint)(i - text.Raw) + text.VA;
                uint target = (uint)(insn + 7 + BitConverter.ToInt32(d, (int)i + 3));
                leas.Add(new KeyValuePair<uint, uint>(insn, target));
                List<uint> l;
                if (!leaByTarget.TryGetValue(target, out l)) { l = new List<uint>(); leaByTarget[target] = l; }
                l.Add(insn);
            }
        }
    }

    long Off(uint rva) {
        foreach (var s in secs) if (rva >= s.VA && rva < s.VA + s.RawSize) return rva - s.VA + s.Raw;
        return -1;
    }
    uint Rva(long off) {
        foreach (var s in secs) if (off >= s.Raw && off < s.Raw + s.RawSize) return (uint)(off - s.Raw) + s.VA;
        return 0;
    }
    bool InText(uint rva) { return rva >= text.VA && rva < text.VA + text.VSize; }

    string VtableName(uint rva) {
        long o = Off(rva);
        if (o < 8 || InText(rva)) return null;
        ulong colVa = BitConverter.ToUInt64(d, (int)o - 8);
        if (colVa < imageBase) return null;
        ulong colRva64 = colVa - imageBase;
        if (colRva64 > 0x7fffffff) return null;
        uint colRva = (uint)colRva64;
        long co = Off(colRva);
        if (co < 0 || co + 24 > d.Length) return null;
        if (BitConverter.ToUInt32(d, (int)co) != 1) return null;
        if (BitConverter.ToUInt32(d, (int)co + 20) != colRva) return null;
        long to = Off(BitConverter.ToUInt32(d, (int)co + 12));
        if (to < 0) return null;
        int p = (int)to + 16, e = p;
        while (e < d.Length && d[e] != 0 && e - p < 600) e++;
        string n = Encoding.ASCII.GetString(d, p, e - p);
        return n.StartsWith(".?A") ? n : null;
    }

    int LowerBound(uint insn) {
        int lo = 0, hi = leas.Count;
        while (lo < hi) { int m = (lo + hi) / 2; if (leas[m].Key < insn) lo = m + 1; else hi = m; }
        return lo;
    }

    void Collect(uint from, uint to, int depth, string indent, HashSet<string> seen, List<string> output) {
        for (int i = LowerBound(from); i < leas.Count && leas[i].Key < to; i++) {
            uint t = leas[i].Value;
            string n = VtableName(t);
            if (n != null) {
                if (seen.Add(n)) output.Add(indent + n);
            } else if (depth > 1 && InText(t)) {
                Collect(t, t + 0x200, depth - 1, indent + "  ", seen, output);
            }
        }
    }

    // Raw view around each xref: hex bytes plus every LEA / CALL / JMP target in range.
    public List<string> Dump(string name, int before, int after) {
        var output = new List<string>();
        byte[] pat = Encoding.ASCII.GetBytes("\0" + name + "\0");
        for (int i = 0; i + pat.Length <= d.Length; i++) {
            bool ok = true;
            for (int k = 0; k < pat.Length; k++) if (d[i + k] != pat[k]) { ok = false; break; }
            if (!ok) continue;
            uint srva = Rva(i + 1);
            List<uint> refs;
            if (srva == 0 || !leaByTarget.TryGetValue(srva, out refs)) continue;
            foreach (uint x in refs) {
                output.Add("xref @ 0x" + x.ToString("x"));
                long o = Off(x);
                for (long p = o - before; p < o + after; p++) {
                    uint rva = Rva(p);
                    string rel = ((long)rva - x).ToString("+0;-0");
                    if ((d[p] == 0x48 || d[p] == 0x4C) && d[p + 1] == 0x8D && (d[p + 2] & 0xC7) == 0x05) {
                        uint t = (uint)(rva + 7 + BitConverter.ToInt32(d, (int)p + 3));
                        string vn = VtableName(t);
                        string s = null;
                        long to = Off(t);
                        if (vn == null && !InText(t) && to > 0) {
                            int e = (int)to; while (e < d.Length && d[e] >= 0x20 && d[e] < 0x7f && e - to < 80) e++;
                            if (e - to >= 4) s = "\"" + Encoding.ASCII.GetString(d, (int)to, e - (int)to) + "\"";
                        }
                        output.Add("  " + rel + " lea r" + ((d[p + 2] >> 3) & 7) + (d[p] == 0x4C ? "+8" : "") + " -> 0x" + t.ToString("x") + (InText(t) ? " [code]" : "") + (vn != null ? " vtable " + vn : "") + (s ?? ""));
                    } else if (d[p] == 0xE8 || d[p] == 0xE9) {
                        uint t = (uint)(rva + 5 + BitConverter.ToInt32(d, (int)p + 1));
                        if (InText(t)) output.Add("  " + rel + (d[p] == 0xE8 ? " call" : " jmp") + " 0x" + t.ToString("x"));
                    }
                }
                var sb = new StringBuilder("  bytes:");
                for (long p = o - before; p < o + after; p++) sb.Append(' ').Append(d[p].ToString("x2"));
                output.Add(sb.ToString());
            }
        }
        return output;
    }

    public List<string> Find(string name, int window, int depth) {
        var output = new List<string>();
        byte[] pat = Encoding.ASCII.GetBytes("\0" + name + "\0");
        for (int i = 0; i + pat.Length <= d.Length; i++) {
            bool ok = true;
            for (int k = 0; k < pat.Length; k++) if (d[i + k] != pat[k]) { ok = false; break; }
            if (!ok) continue;
            uint srva = Rva(i + 1);
            List<uint> refs;
            if (srva == 0 || !leaByTarget.TryGetValue(srva, out refs)) continue;
            foreach (uint x in refs) {
                output.Add("xref @ 0x" + x.ToString("x") + " (string rva 0x" + srva.ToString("x") + ")");
                Collect(x - (uint)window, x + (uint)window, depth, "    ", new HashSet<string>(), output);
            }
        }
        return output;
    }
}
'@

$e = New-Object EvSig $Dll
foreach ($n in $Names) {
    "== $n"
    if ($Dump) { $e.Dump($n, $Before, $After) } else { $e.Find($n, $Window, $Depth) }
}
