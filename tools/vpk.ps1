# Minimal VPK v2 reader for Deadlock's pak01.
#   .\tools\vpk.ps1 -List 'regex'                 -> list matching paths
#   .\tools\vpk.ps1 -Extract 'regex' -Out dir     -> extract matching files; compiled panorama
#                                                    files (*.vxml_c/vcss_c/vjs_c) are also decoded to source
#   .\tools\vpk.ps1 -Grep 'regex' -In 'pathregex' -> search decoded panorama sources for text
param(
    [string]$List,
    [string]$Extract,
    [string]$Grep,
    [string]$In = '^panorama/.*\.(vxml_c|vcss_c|vjs_c|vts_c)$',
    [string]$Out = "$PSScriptRoot\..\vanilla",
    [string]$Vpk = 'C:\Program Files (x86)\Steam\steamapps\common\Deadlock\game\citadel\pak01_dir.vpk'
)

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public class VpkEntry {
    public string Path; public ushort Archive; public uint Offset; public uint Length; public byte[] Preload;
}

public static class VpkReader {
    static string ReadZ(BinaryReader r) {
        var ms = new MemoryStream(); byte b;
        while ((b = r.ReadByte()) != 0) ms.WriteByte(b);
        return Encoding.UTF8.GetString(ms.ToArray());
    }

    public static long DataStart;

    public static List<VpkEntry> ReadDir(string dirPath) {
        var list = new List<VpkEntry>();
        using (var r = new BinaryReader(File.OpenRead(dirPath))) {
            if (r.ReadUInt32() != 0x55aa1234) throw new Exception("not a vpk");
            uint ver = r.ReadUInt32();
            uint treeSize = r.ReadUInt32();
            long hdr = 12;
            if (ver == 2) { r.ReadBytes(16); hdr = 28; }
            DataStart = hdr + treeSize;
            while (true) {
                string ext = ReadZ(r); if (ext.Length == 0) break;
                while (true) {
                    string dir = ReadZ(r); if (dir.Length == 0) break;
                    while (true) {
                        string name = ReadZ(r); if (name.Length == 0) break;
                        var e = new VpkEntry();
                        r.ReadUInt32();
                        ushort preload = r.ReadUInt16();
                        e.Archive = r.ReadUInt16();
                        e.Offset = r.ReadUInt32();
                        e.Length = r.ReadUInt32();
                        r.ReadUInt16();
                        e.Preload = r.ReadBytes(preload);
                        e.Path = (dir == " " ? "" : dir + "/") + name + (ext == " " ? "" : "." + ext);
                        list.Add(e);
                    }
                }
            }
        }
        return list;
    }

    public static byte[] ReadFile(string dirPath, VpkEntry e) {
        var buf = new byte[e.Preload.Length + e.Length];
        Array.Copy(e.Preload, buf, e.Preload.Length);
        if (e.Length > 0) {
            string p = e.Archive == 0x7fff ? dirPath : dirPath.Replace("_dir.vpk", "_" + e.Archive.ToString("000") + ".vpk");
            using (var f = File.OpenRead(p)) {
                f.Seek(e.Offset + (e.Archive == 0x7fff ? DataStart : 0), SeekOrigin.Begin);
                int got = 0;
                while (got < e.Length) { int n = f.Read(buf, e.Preload.Length + got, (int)e.Length - got); if (n <= 0) break; got += n; }
            }
        }
        return buf;
    }

    // Pull the original source text out of a compiled panorama resource.
    public static byte[] DecodePanorama(byte[] d) {
        uint blockOffset = BitConverter.ToUInt32(d, 8);
        uint blockCount = BitConverter.ToUInt32(d, 12);
        int p = 8 + (int)blockOffset;
        for (int i = 0; i < blockCount; i++, p += 12) {
            string type = Encoding.ASCII.GetString(d, p, 4);
            int off = p + 4 + (int)BitConverter.ToUInt32(d, p + 4);
            int size = (int)BitConverter.ToUInt32(d, p + 8);
            if (type != "DATA") continue;
            int q = off + 4;
            int names = BitConverter.ToUInt16(d, q); q += 2;
            for (int n = 0; n < names; n++) { while (d[q] != 0) q++; q += 1 + 8; }
            var res = new byte[off + size - q];
            Array.Copy(d, q, res, 0, res.Length);
            return res;
        }
        return null;
    }
}
'@

$entries = [VpkReader]::ReadDir($Vpk)

if ($List) {
    $entries | Where-Object { $_.Path -match $List } | ForEach-Object { $_.Path } | Sort-Object
}

if ($Extract) {
    foreach ($e in ($entries | Where-Object { $_.Path -match $Extract })) {
        $bytes = [VpkReader]::ReadFile($Vpk, $e)
        $dest = Join-Path $Out $e.Path
        New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
        [IO.File]::WriteAllBytes($dest, $bytes)
        if ($e.Path -match '\.v(xml|css|js|ts)_c$') {
            $src = [VpkReader]::DecodePanorama($bytes)
            if ($src) { [IO.File]::WriteAllBytes(($dest -replace '\.v(\w+)_c$', '.$1'), $src) }
        }
        $e.Path
    }
}

if ($Grep) {
    foreach ($e in ($entries | Where-Object { $_.Path -match $In })) {
        $src = [VpkReader]::DecodePanorama([VpkReader]::ReadFile($Vpk, $e))
        if (-not $src) { continue }
        $n = 0
        foreach ($line in ([Text.Encoding]::UTF8.GetString($src) -split "`n")) {
            $n++
            if ($line -match $Grep) { "{0}:{1}: {2}" -f $e.Path, $n, $line.Trim() }
        }
    }
}
