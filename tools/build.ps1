# Compiles .\mod with the CSDK resourcecompiler and packs the result into build\damage_row_tooltips_dir.vpk.
#   .\tools\build.ps1            -> compile + pack
#   .\tools\build.ps1 -Install   -> also copy into Deadlock's addons folder (as pakNN_dir.vpk)
param(
    [switch]$Install,
    [string]$Csdk = "$PSScriptRoot\..\csdk\Reduced_CSDK_13",
    [string]$Deadlock = 'C:\Program Files (x86)\Steam\steamapps\common\Deadlock',
    [string]$PakName = 'pak50_dir.vpk'
)
$ErrorActionPreference = 'Stop'

$root     = (Resolve-Path "$PSScriptRoot\..").Path
$Csdk     = (Resolve-Path $Csdk).Path
$addon    = 'damage_row_tooltips'
$content  = Join-Path $Csdk "content\citadel_addons\$addon"
$game     = Join-Path $Csdk "game\citadel_addons\$addon"
$compiler = Join-Path $Csdk 'game\bin\win64\resourcecompiler.exe'
$outDir   = Join-Path $root 'build'
$outVpk   = Join-Path $outDir "${addon}_dir.vpk"

# 1. Stage sources into the CSDK addon content folder.
foreach ($d in $content, $game) { if (Test-Path $d) { Remove-Item -Recurse -Force $d } }
New-Item -ItemType Directory -Force $content, $game, $outDir | Out-Null
Copy-Item -Recurse "$root\mod\*" $content

# 2. Compile.
$sources = Get-ChildItem $content -Recurse -File | Where-Object { $_.Extension -in '.xml', '.css', '.js' }
$compileArgs = @()
foreach ($s in $sources) { $compileArgs += '-i'; $compileArgs += $s.FullName }
$compileArgs += '-nop4'
& $compiler @compileArgs | Out-Host
if ($LASTEXITCODE -ne 0) { throw "resourcecompiler failed with exit code $LASTEXITCODE" }

$compiled = Get-ChildItem $game -Recurse -File | Where-Object { $_.Name -match '_c$' }
if ($compiled.Count -ne $sources.Count) {
    throw "expected $($sources.Count) compiled files, found $($compiled.Count) in $game"
}

# 3. Pack a single-file VPK v2 (all data stored in the _dir file).
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public static class VpkWriter {
    static void Z(BinaryWriter w, string s) { w.Write(Encoding.UTF8.GetBytes(s)); w.Write((byte)0); }

    static uint Crc32(byte[] d) {
        uint c = 0xFFFFFFFF;
        foreach (byte b in d) {
            c ^= b;
            for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
        }
        return ~c;
    }

    // files: relative path with forward slashes -> absolute path on disk
    public static void Write(string output, Dictionary<string, string> files) {
        var tree = new SortedDictionary<string, SortedDictionary<string, List<string>>>(StringComparer.Ordinal);
        foreach (var rel in files.Keys) {
            string ext = Path.GetExtension(rel).TrimStart('.');
            string dir = Path.GetDirectoryName(rel).Replace('\\', '/');
            if (dir.Length == 0) dir = " ";
            if (!tree.ContainsKey(ext)) tree[ext] = new SortedDictionary<string, List<string>>(StringComparer.Ordinal);
            if (!tree[ext].ContainsKey(dir)) tree[ext][dir] = new List<string>();
            tree[ext][dir].Add(rel);
        }

        var treeMs = new MemoryStream();
        var dataMs = new MemoryStream();
        var tw = new BinaryWriter(treeMs);
        foreach (var ext in tree) {
            Z(tw, ext.Key);
            foreach (var dir in ext.Value) {
                Z(tw, dir.Key);
                foreach (var rel in dir.Value) {
                    byte[] bytes = File.ReadAllBytes(files[rel]);
                    Z(tw, Path.GetFileNameWithoutExtension(rel));
                    tw.Write(Crc32(bytes));
                    tw.Write((ushort)0);            // preload bytes
                    tw.Write((ushort)0x7fff);       // stored in this file
                    tw.Write((uint)dataMs.Position);
                    tw.Write((uint)bytes.Length);
                    tw.Write((ushort)0xffff);
                    dataMs.Write(bytes, 0, bytes.Length);
                }
                tw.Write((byte)0);
            }
            tw.Write((byte)0);
        }
        tw.Write((byte)0);
        tw.Flush();

        using (var w = new BinaryWriter(File.Create(output))) {
            w.Write(0x55aa1234u);
            w.Write(2u);
            w.Write((uint)treeMs.Length);
            w.Write((uint)dataMs.Length);
            w.Write(0u); w.Write(0u); w.Write(0u);  // no md5 / signature sections
            w.Write(treeMs.ToArray());
            w.Write(dataMs.ToArray());
        }
    }
}
'@

$files = New-Object 'System.Collections.Generic.Dictionary[string,string]'
foreach ($f in $compiled) {
    $files[$f.FullName.Substring($game.Length + 1).Replace('\', '/')] = $f.FullName
}
[VpkWriter]::Write($outVpk, $files)
"Packed $($files.Count) files -> $outVpk"
$files.Keys | ForEach-Object { "  $_" }

# 4. Optional install.
if ($Install) {
    $addons = Join-Path $Deadlock 'game\citadel\addons'
    New-Item -ItemType Directory -Force $addons | Out-Null
    Copy-Item $outVpk (Join-Path $addons $PakName) -Force
    "Installed -> $(Join-Path $addons $PakName)"
}
