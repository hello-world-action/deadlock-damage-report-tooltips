# Damage Report Tooltips

A HUD mod for [Deadlock](https://store.steampowered.com/app/1422450/Deadlock/) that adds the
game's own ability and item tooltips to the **Incoming Damage** report — the table shown on the
right of the screen when you die.

Hover a row and you see the same tooltip the game shows for that ability or item elsewhere,
without having to look it up on the scoreboard.

## What it does

| Row | On hover |
|---|---|
| Hero abilities | The in-game ability tooltip, shown for the enemy who hit you, so it reflects the upgrades they have bought |
| Items | The in-game item tooltip |
| Guns, melee, troopers, guardians | Nothing (unchanged) |

It only surfaces information the game already shows in other places.

## Status

- Built and tested against Deadlock client version **6861** (November 2026).
- There is no packaged download in this repository yet; for now, build it from source (below).
- Deadlock is in active development. A game update can break any HUD mod, including this one.
  If the damage report looks wrong after a patch, remove the mod.

## Known limits

- **Item tooltips aren't matched to the attacker.** An item row doesn't identify who owns the
  item, so the tooltip is requested for player slot 0 and its numbers may not reflect the
  attacker's stats.
- **Abilities bound to more than one hero**, or to a hero not found in the top bar, fall back to
  player slot 0 in the same way.
- **Conflicts:** the mod replaces `panorama/layout/hud_damage_rows`. It can't be combined with
  another mod that replaces the same file.
- **New heroes and items** added after a build are handled by a naming-based guess rather than
  the generated table, and their ability tooltips won't be matched to the attacker until the mod
  is rebuilt.

## Installing a built VPK

**Deadlock Mod Manager:** Mods Library → Add Local Mod → select the VPK (or a zip containing
it) → enable → restart Deadlock.

**Manually:**

1. Copy the VPK into `Deadlock\game\citadel\addons\` as `pakNN_dir.vpk`, using a number that
   isn't taken (create the folder if it doesn't exist).
2. Make sure `game\citadel\gameinfo.gi` loads the addons folder — the standard Deadlock modding
   edit that adds `Game citadel/addons` to `SearchPaths`.
3. Restart Deadlock. Mods are only loaded at startup.

To uninstall, disable it in the mod manager or delete the VPK.

## Building from source

Windows only; the scripts are PowerShell.

### Requirements

- Deadlock installed through Steam.
- **Source 2 Viewer CLI** — download `cli-windows-x64.zip` from the
  [ValveResourceFormat releases](https://github.com/ValveResourceFormat/ValveResourceFormat/releases)
  and extract it to `tools\s2v\` (so that `tools\s2v\Source2Viewer-CLI.exe` exists).
- **Reduced CSDK 13** — the community SDK, from the
  [Deadlock modding wiki](https://deadlockmodding.pages.dev/modding-tools/csdk-13). Extract it to
  `csdk\` (so that `csdk\Reduced_CSDK_13\game\bin\win64\resourcecompiler.exe` exists).

Neither tool is included in this repository.

### Commands

Run from the repository root, with Deadlock closed:

```powershell
.\tools\gen_data.ps1              # regenerate the data tables and layout from your installed game
.\tools\build.ps1                 # compile mod\ and pack build\damage_row_tooltips_dir.vpk
.\tools\install.ps1               # add the addons search path to gameinfo.gi (with a backup) and copy the VPK in
.\tools\install.ps1 -Uninstall    # remove the VPK and restore the original gameinfo.gi
.\tools\release.ps1 -Version 1.0.0   # zip the built VPK with an install note into release\
```

If PowerShell refuses to run scripts, use
`powershell -ExecutionPolicy Bypass -File .\tools\<script>.ps1`.

The scripts assume the default Steam location
(`C:\Program Files (x86)\Steam\steamapps\common\Deadlock`). `build.ps1`, `install.ps1` and
`release.ps1` take a `-Deadlock` parameter, and `gen_data.ps1` a `-Vpk` parameter, if yours is
elsewhere.

After a game update, run `gen_data.ps1`, `build.ps1` and `install.ps1` again. `gen_data.ps1`
stops with an error if the game's damage-row layout has changed shape, rather than producing a
broken mod.

### Repository layout

```
mod\panorama\
  layout\hud_damage_rows.xml           generated: the game's layout plus two script includes
  scripts\damage_row_tooltips.js       the mod's logic
  scripts\damage_row_tooltip_data.js   generated: ability / item / hero tables
tools\
  gen_data.ps1    builds the two generated files from the installed game
  build.ps1       compiles with the CSDK resourcecompiler and writes the VPK
  install.ps1     gameinfo.gi edit + copy to addons, and the reverse
  release.ps1     packages a build for distribution
  vpk.ps1         minimal VPK reader (list / extract files from the game's pak01)
  strings.ps1     dumps printable strings from a binary
  evsig.ps1       locates Panorama event registrations in client.dll
release\LISTING.md   draft text for a mod-site listing
```

## How it works

1. **One layout is overridden.** The game builds each damage row from a snippet in
   `panorama/layout/hud_damage_rows.xml`. The mod ships that layout unchanged apart from two
   script includes.
2. **Rows are found by id.** The game gives each row the id `AbilityDamage_<key>`, where `<key>`
   is the ability or item class name (for example `citadel_ability_hornet_leap` or
   `upgrade_toxic_bullets`). NPC rows use display names instead. The script polls the row
   container and attaches hover handlers to new rows.
3. **Rows are classified** as ability, item or neither, from a table generated out of
   `m_eAbilityType` in the game's `abilities.vdata`. Keys missing from the table are classified
   by name.
4. **The attacker's player slot is resolved** for abilities: the owning hero comes from
   `m_mapBoundAbilities` in `heroes.vdata`, and the slot from the top-bar panel
   (`TopBarPlayer<slot>`) whose hero-name label matches that hero's localized name.
5. **The game's own tooltip is shown** by dispatching its events:
   `CitadelShowAbilityDetailsTooltip(token, slot)` for abilities and
   `CitadelShowModTooltip(token, slot)` for items, with the matching hide events on mouse-out.

## Notes for other Panorama modders

Things that weren't obvious and may save you time:

- Deadlock's layouts are compiled to a binary AST (`.vxml_c`), not embedded source. You need
  Source 2 Viewer to read them and the CSDK `resourcecompiler` to write them. Stylesheets and
  scripts (`.vcss_c`, `.vjs_c`) still embed their source.
- In mod source files, includes reference the compiled names: `s2r://…/foo.vjs_c`,
  `s2r://…/foo.vcss_c`.
- Events that take a `CUtlStringToken` reject a name passed as a string from
  `$.DispatchEvent` ("Event arguments could not be parsed"). Pass the numeric hash instead:
  MurmurHash2 of the lowercased string with seed `0x31415926`. See `token()` in
  `damage_row_tooltips.js`.
- An event string the engine can't parse is evaluated as JavaScript, which surfaces as
  "`<EventName>` is not defined". That applies to `onmouseover="…"` in layout XML and to
  handlers passed to `$.CreatePanelWithProperties`.
- `CitadelShowReadOnlyAbilityDetailsTooltip` could not be called from script with any argument
  encoding tried; the two-argument per-player event works.
- The HUD, including this layout, is created when the game starts. Keep work out of script load:
  creating game panel types (`CitadelAbilityIcon`, `AbilityDetailsPanel`) from script at load
  crashed the game on launch. Do work in response to input, inside `try`/`catch`.
- `Image` panels expose `SetImage` to script but no way to read the current source.
- `CSDK 13` doesn't include a VPK packer; `build.ps1` writes a single-file VPK v2 itself.
- `tools\evsig.ps1 -Dump -Names <EventName>` shows where an event is registered in `client.dll`.
  The argument count is the constant loaded into `r8d` just after the name is referenced.
- Launching Deadlock with `-condebug` writes the console to `game\citadel\console.log`, which
  survives a crash. Set `DEBUG = true` in `damage_row_tooltips.js` for per-hover logging.

## Credits

- [Source 2 Viewer / ValveResourceFormat](https://valveresourceformat.github.io/) for decompiling
  game resources.
- The community **Reduced CSDK 13** for the resource compiler.
- [Predi-i/Deadlock-UI-Mods](https://github.com/Predi-i/Deadlock-UI-Mods) for showing that
  script-driven Panorama HUD mods are possible and how to build them.

Deadlock is a trademark of Valve Corporation. This is an unofficial fan-made mod, not affiliated
with or endorsed by Valve.
