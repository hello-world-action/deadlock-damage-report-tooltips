# Packages the built mod for distribution: release\DamageReportTooltips_v<Version>.zip
# containing the VPK and a short install note. Run build.ps1 first.
#   .\tools\release.ps1 -Version 1.0.0
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Deadlock = 'C:\Program Files (x86)\Steam\steamapps\common\Deadlock'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..").Path
$vpk  = Join-Path $root 'build\damage_row_tooltips_dir.vpk'
if (-not (Test-Path $vpk)) { throw "Build output not found: $vpk (run tools\build.ps1 first)" }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must look like 1.0.0' }

$client = 'unknown'
$inf = Join-Path $Deadlock 'game\citadel\steam.inf'
if ((Test-Path $inf) -and ((Get-Content $inf -Raw) -match 'ClientVersion=(\d+)')) { $client = $matches[1] }

$outDir = Join-Path $root 'release'
$stage  = Join-Path $outDir "stage_$Version"
$zip    = Join-Path $outDir "DamageReportTooltips_v$Version.zip"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

Copy-Item $vpk (Join-Path $stage 'pak50_dir.vpk')
@"
Damage Report Tooltips v$Version
Built against Deadlock client version $client.

Adds the game's own ability and item tooltips to the rows of the Incoming Damage
report (the table shown when you die). Hover a row to see what hit you.

INSTALL - Deadlock Mod Manager
  Mods Library -> Add Local Mod -> select this zip (or pak50_dir.vpk) -> enable -> restart Deadlock.

INSTALL - manual
  1. Copy pak50_dir.vpk into  <Deadlock>\game\citadel\addons\  (create the folder if missing).
     If you already have a pak50_dir.vpk there, rename this one to any unused pakNN_dir.vpk.
  2. Your gameinfo.gi must load the addons folder (the standard Deadlock modding edit).
  3. Restart Deadlock.

UNINSTALL
  Disable it in the mod manager, or delete the vpk from the addons folder.

NOTES
  - Hero abilities show the attacker's own tooltip (their upgrades and numbers).
  - Item tooltips are generic: they are not scaled to the attacker's stats.
  - Gun, melee, trooper and guardian rows have no tooltip.
  - This mod replaces panorama/layout/hud_damage_rows. It conflicts with any other mod
    that replaces the same file.
  - If a game update changes the damage report and it looks wrong, disable the mod and
    check for an updated version.
"@ | Set-Content (Join-Path $stage 'README.txt') -Encoding utf8

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Remove-Item -Recurse -Force $stage
"Wrote $zip (client $client)"
