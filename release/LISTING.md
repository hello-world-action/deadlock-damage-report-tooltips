# Store listing draft — Damage Report Tooltips

Text to paste into the GameBanana submission form. Edit freely; nothing here is uploaded
automatically.

## Name

Damage Report Tooltips

## One-line summary

Hover a row in the Incoming Damage report to see the ability or item that hit you.

## Description

When you die, Deadlock shows an Incoming Damage table listing what hit you — but the rows are
just names and icons. This mod makes them hoverable: move the mouse over an ability or item
row and you get the game's own tooltip for it, the same one you'd see in the shop or on the
scoreboard.

**What you get**

- **Abilities:** the full in-game ability tooltip, shown for the enemy who hit you — so it
  reflects the upgrades they have actually bought.
- **Items:** the full in-game item tooltip.
- **Guns, melee, troopers and guardians:** unchanged, no tooltip.

**Good to know**

- Item tooltips are generic. They aren't scaled to the attacker's stats.
- Works in any game language (it uses the game's own tooltips and hero names).
- It only shows information the game already shows elsewhere; it doesn't reveal anything new.
- Replaces one layout file, `panorama/layout/hud_damage_rows`. It will conflict with another
  mod that replaces the same file.
- New heroes and items added by a patch get tooltips automatically. If a patch changes the
  damage report itself, the mod may need an update — disable it if the report looks wrong.

**Install**

- Deadlock Mod Manager: install from the store, or Mods Library → Add Local Mod → pick the zip.
- Manual: copy `pak50_dir.vpk` into `Deadlock\game\citadel\addons\` (rename to a free
  `pakNN_dir.vpk` if needed), with the usual `gameinfo.gi` addons edit. Restart the game.

## Category

HUD / UI (pick whichever GameBanana's Deadlock category tree calls it).

## Screenshots to take (the form will want at least one)

1. An ability row hovered, with the ability tooltip showing next to the Incoming Damage table.
2. An item row hovered, with the item tooltip showing.
3. Optional: the unmodded table for a before/after.

## Credits

- Author: <your GameBanana name>
- Built with Source 2 Viewer (ValveResourceFormat) and the community Reduced CSDK 13.
- Approach informed by Predi-i's Deadlock-UI-Mods (script-driven Panorama HUD mods).

## Changelog

- 1.0.0 — first release.
