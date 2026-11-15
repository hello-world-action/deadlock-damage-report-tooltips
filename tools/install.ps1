# Installs the built mod into Deadlock. Close the game first.
#   .\tools\install.ps1             -> patch gameinfo.gi (once, with backup) and copy the VPK into addons
#   .\tools\install.ps1 -Uninstall  -> remove the VPK and restore the original gameinfo.gi
param(
    [switch]$Uninstall,
    [string]$Deadlock = 'C:\Program Files (x86)\Steam\steamapps\common\Deadlock',
    [string]$PakName = 'pak50_dir.vpk'
)
$ErrorActionPreference = 'Stop'

if (Get-Process -Name deadlock -ErrorAction SilentlyContinue) {
    throw 'Deadlock is running. Close it completely and run this again.'
}

$root   = (Resolve-Path "$PSScriptRoot\..").Path
$gi     = Join-Path $Deadlock 'game\citadel\gameinfo.gi'
$backup = "$gi.bak"
$addons = Join-Path $Deadlock 'game\citadel\addons'
$target = Join-Path $addons $PakName
$enc    = [Text.Encoding]::GetEncoding(28591)   # byte-preserving

if ($Uninstall) {
    if (Test-Path $target) { Remove-Item $target -Force; "Removed $target" }
    if (Test-Path $backup) { Copy-Item $backup $gi -Force; "Restored $gi from backup" }
    return
}

$vpk = Join-Path $root 'build\damage_row_tooltips_dir.vpk'
if (-not (Test-Path $vpk)) { throw "Build output not found: $vpk (run tools\build.ps1 first)" }

$text = [IO.File]::ReadAllText($gi, $enc)
if ($text -match 'citadel/addons') {
    'gameinfo.gi already has the addons search path'
} else {
    $rx = [regex]'(?m)^(\t+)Game\t+citadel\r?\n\t+Game\t+core(\r?)$'
    if (-not $rx.IsMatch($text)) { throw 'Could not find the "Game citadel / Game core" search path block in gameinfo.gi' }
    if (-not (Test-Path $backup)) { Copy-Item $gi $backup }
    $patched = $rx.Replace($text, {
        param($m)
        $i  = $m.Groups[1].Value
        $cr = $m.Groups[2].Value
        (@(
            "${i}Game`t`t`t`tcitadel/addons",
            "${i}Mod`t`t`t`t`tcitadel",
            "${i}Write`t`t`t`tcitadel",
            "${i}Game`t`t`t`tcitadel",
            "${i}Mod`t`t`t`t`tcore",
            "${i}Write`t`t`t`tcore",
            "${i}Game`t`t`t`tcore"
        ) -join "$cr`n") + $cr
    }, 1)
    [IO.File]::WriteAllText($gi, $patched, $enc)
    "Patched gameinfo.gi (backup: $backup)"
}

New-Item -ItemType Directory -Force $addons | Out-Null
Copy-Item $vpk $target -Force
"Installed $target"
