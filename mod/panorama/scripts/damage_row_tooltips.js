// Damage report row tooltips.
// Runs once per CitadelDamageRows panel (hud_damage_rows.xml). The game creates one child
// per damage source inside #Data with the id "AbilityDamage_<key>", where <key> is the
// ability / item class name. Hovering an ability or item row shows the game's own tooltip
// for it; gun, melee and NPC rows show nothing.
//
// Which keys count as abilities / items comes from damage_row_tooltip_data.js (generated
// from the game data by tools\gen_data.ps1).
//
// The tooltip events take (CUtlStringToken ability, CPlayerSlot slot). From script the
// token has to be passed as its numeric hash; passing the name string is rejected.
// For abilities the slot is the attacker's: ability -> owning hero (generated data) ->
// the top bar player panel showing that hero's name ("TopBarPlayer<slot>").
(function () {
	'use strict';

	var DEBUG = false;

	var ROW_PREFIX = 'AbilityDamage_';
	var HOOKED_ATTR = 'damage_row_tooltip_hooked';
	var SCAN_INTERVAL = 0.25;
	var DEFAULT_SLOT = 0;

	var ctx = $.GetContextPanel();
	var kinds = $.DamageRowTooltipKinds || {};
	var heroes = $.DamageRowTooltipHeroes || {};
	var hud = null;

	// The HUD root, found by walking up from this panel.
	function findHud() {
		if (alive(hud)) return hud;
		hud = null;
		var p = ctx;
		for (var i = 0; alive(p) && i < 50; i++) {
			if (p.id === 'Hud') { hud = p; break; }
			p = p.GetParent();
		}
		return hud;
	}

	function norm(s) {
		return String(s || '').replace(/\s+/g, ' ').trim().toLowerCase();
	}

	// Collects the top bar's per-player panels ("TopBarPlayer<slot>"). Depth-limited walk;
	// does not descend into a player panel once found.
	function topBarPlayers(panel, depth, out) {
		if (!alive(panel) || depth > 8) return out;
		var kids = panel.Children() || [];
		for (var i = 0; i < kids.length; i++) {
			var k = kids[i];
			if (!alive(k)) continue;
			var m = /^TopBarPlayer(\d+)$/.exec(String(k.id || ''));
			if (m) out.push({ slot: parseInt(m[1], 10), panel: k });
			else topBarPlayers(k, depth + 1, out);
		}
		return out;
	}

	function heroNameOf(playerPanel) {
		var labels = playerPanel.FindChildrenWithClassTraverse('HeroName') || [];
		return labels.length && alive(labels[0]) ? String(labels[0].text || '') : '';
	}

	// Player slot of whoever is playing the hero that owns this ability, or DEFAULT_SLOT.
	function slotForAbility(key) {
		var heroKey = heroes[key];
		if (!heroKey) { log('no hero for ' + key + ', slot ' + DEFAULT_SLOT); return DEFAULT_SLOT; }
		try {
			var want = norm($.Localize('#' + heroKey));
			var bar = alive(findHud()) ? hud.FindChildTraverse('TopBar') : null;
			var players = topBarPlayers(alive(bar) ? bar : findHud(), 0, []);
			var seen = [];
			for (var i = 0; i < players.length; i++) {
				var name = heroNameOf(players[i].panel);
				seen.push(players[i].slot + '=' + name);
				if (norm(name) === want) {
					log(key + ' -> ' + heroKey + ' "' + want + '" -> slot ' + players[i].slot + ' [' + seen.join(', ') + ' ...]');
					return players[i].slot;
				}
			}
			log(key + ' -> ' + heroKey + ' "' + want + '" not in top bar [' + seen.join(', ') + '], slot ' + DEFAULT_SLOT);
		} catch (e) {
			log('slot lookup failed for ' + key + ': ' + e);
		}
		return DEFAULT_SLOT;
	}

	// The tooltip currently showing, shared by every damage-rows panel: { row, kind, token }.
	// Kept on $ so a row in one panel can clear a tooltip opened from another.
	function current() { return $.DamageRowTooltipCurrent || null; }

	function log(msg) {
		if (DEBUG) $.Msg('[DRT] ' + msg + '\n');
	}

	function alive(panel) {
		return !!panel && (!panel.IsValid || panel.IsValid());
	}

	// CUtlStringToken hash: MurmurHash2 of the lowercased string, seed 0x31415926.
	function token(str) {
		str = str.toLowerCase();
		var m = 0x5bd1e995, len = str.length, h = (0x31415926 ^ len) >>> 0, i = 0, k;
		while (len >= 4) {
			k = (str.charCodeAt(i) & 0xff) | ((str.charCodeAt(i + 1) & 0xff) << 8) |
				((str.charCodeAt(i + 2) & 0xff) << 16) | ((str.charCodeAt(i + 3) & 0xff) << 24);
			k = Math.imul(k, m); k ^= k >>> 24; k = Math.imul(k, m);
			h = Math.imul(h, m) ^ k;
			i += 4; len -= 4;
		}
		if (len === 3) h ^= (str.charCodeAt(i + 2) & 0xff) << 16;
		if (len >= 2) h ^= (str.charCodeAt(i + 1) & 0xff) << 8;
		if (len >= 1) { h ^= (str.charCodeAt(i) & 0xff); h = Math.imul(h, m); }
		h ^= h >>> 13; h = Math.imul(h, m); h ^= h >>> 15;
		return h >>> 0;
	}

	function keyOf(row) {
		var id = String(row.id || '');
		return id.indexOf(ROW_PREFIX) === 0 ? id.substring(ROW_PREFIX.length) : '';
	}

	// 'a' ability, 'i' item, anything else: no tooltip.
	function kindOf(key) {
		if (Object.prototype.hasOwnProperty.call(kinds, key)) return kinds[key];
		// Not in the generated table: added to the game after this mod was built.
		// NPC rows use display names ("T1 Guardian"), which are never class names.
		if (!/^[a-z0-9_]+$/.test(key)) return 'x';
		if (key.indexOf('upgrade_') === 0) return 'i';
		if (/weapon|melee|gun|npc|trooper/.test(key)) return 'x';
		return 'a';
	}

	function hideCurrent() {
		var cur = current();
		if (!cur) return;
		$.DamageRowTooltipCurrent = null;
		if (!alive(cur.row)) return;
		try {
			if (cur.kind === 'i') $.DispatchEvent('CitadelHideModTooltip', cur.row, cur.token, cur.slot);
			else $.DispatchEvent('CitadelHideAbilityDetailsTooltip', cur.row);
		} catch (e) {
			log('hide failed: ' + e);
		}
	}

	function show(row) {
		// Always clear first: a row with no tooltip must not keep the previous row's showing.
		hideCurrent();
		var key = keyOf(row);
		var kind = kindOf(key);
		if (kind !== 'a' && kind !== 'i') return;
		var tok = token(key);
		// An item's name does not say who owns it, so items stay on the default slot.
		var slot = kind === 'a' ? slotForAbility(key) : DEFAULT_SLOT;
		try {
			if (kind === 'i') $.DispatchEvent('CitadelShowModTooltip', row, tok, slot);
			else $.DispatchEvent('CitadelShowAbilityDetailsTooltip', row, tok, slot);
			$.DamageRowTooltipCurrent = { row: row, kind: kind, token: tok, slot: slot };
			log('show ' + kind + ' ' + key + ' slot ' + slot);
		} catch (e) {
			log('show failed for ' + key + ': ' + e);
		}
	}

	function hide(row) {
		var cur = current();
		if (cur && cur.row === row) hideCurrent();
	}

	function hook(row) {
		row.SetAttributeString(HOOKED_ATTR, '1');
		row.SetPanelEvent('onmouseover', function () { show(row); });
		row.SetPanelEvent('onmouseout', function () { hide(row); });
	}

	function scan() {
		if (!alive(ctx)) return; // panel destroyed: stop polling
		try {
			var data = ctx.FindChildTraverse('Data');
			if (alive(data)) {
				var rows = data.Children() || [];
				for (var i = 0; i < rows.length; i++) {
					var row = rows[i];
					if (alive(row) && row.GetAttributeString(HOOKED_ATTR, '') !== '1') hook(row);
				}
			}
		} catch (e) {
			log('scan failed: ' + e);
		}
		$.Schedule(SCAN_INTERVAL, scan);
	}

	scan();
})();
