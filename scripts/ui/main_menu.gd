extends Control
## Main Menu: Start, Rules & Guide (with visual diagrams), Quit Game (§3).
## Quit is hidden on the web build (quit() does nothing there).

var _rules_overlay: Control
var _tab_containers: Array[Control] = []
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	var box: VBoxContainer = UIKit.make_centered_menu(self, "Hukulshish", "Defend the kingdom. Destroy the four nests.")
	var start: Button = UIKit.make_button("Start", func() -> void:
		GameState.sandbox_mode = false
		GameState.coop_mode = false
		SceneRouter.goto(SceneRouter.MAP_SIZE_SELECT)
	)
	box.add_child(start)
	box.add_child(UIKit.make_button("Multiplayer (connection test)", _open_multiplayer, 22))

	var rules_btn: Button = UIKit.make_button("Rules & Guide", _open_rules)
	box.add_child(rules_btn)

	if OS.has_feature("web"):
		box.add_child(UIKit.make_label("Thanks for playing!", 18, Color(0.7, 0.7, 0.8)))
	else:
		box.add_child(UIKit.make_button("Quit Game", func() -> void: get_tree().quit()))
	box.add_child(UIKit.make_label("WASD to move • left-click to shoot • walk into the castle to shop & upgrade", 16, Color(0.6, 0.6, 0.7)))

	_build_rules_overlay()


func _open_multiplayer() -> void:
	if get_node_or_null("WebRTCLobby") != null:
		return
	var lobby: Control = preload("res://scripts/ui/webrtc_lobby.gd").new()
	lobby.name = "WebRTCLobby"
	add_child(lobby)


func _unhandled_input(event: InputEvent) -> void:
	if _rules_overlay != null and _rules_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_rules()
		get_viewport().set_input_as_handled()


func _open_rules() -> void:
	if _rules_overlay != null:
		_select_tab(0)
		_rules_overlay.show()


func _close_rules() -> void:
	if _rules_overlay != null:
		_rules_overlay.hide()


func _select_tab(idx: int) -> void:
	for i in _tab_containers.size():
		_tab_containers[i].visible = (i == idx)
		_tab_buttons[i].modulate = Color(1.0, 0.95, 0.65) if (i == idx) else Color(0.78, 0.8, 0.88)


func _build_rules_overlay() -> void:
	_rules_overlay = Control.new()
	_rules_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules_overlay.hide()
	add_child(_rules_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1460, 880)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	outer.add_child(UIKit.make_label("Hukulshish — Rules & Visual Guide", 36, Color(0.95, 0.82, 0.32)))

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 16)
	outer.add_child(tab_bar)

	var tab_titles: Array[String] = [
		"1. Basics, Controls & Shops",
		"2. Augmentations & Lv 3 Uniques (Illustrated)",
		"3. Enemies, Drops, Bosses & Endless Mode",
	]
	for i in tab_titles.size():
		var tb: Button = UIKit.make_button(tab_titles[i], _select_tab.bind(i), 18)
		tb.custom_minimum_size = Vector2(420, 46)
		tab_bar.add_child(tb)
		_tab_buttons.append(tb)

	var content_holder := Control.new()
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(content_holder)

	var tab1: Control = _build_tab_basics()
	var tab2: Control = _build_tab_augmentations()
	var tab3: Control = _build_tab_enemies_and_bosses()
	for t in [tab1, tab2, tab3]:
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		content_holder.add_child(t)
		_tab_containers.append(t)

	var close_btn: Button = UIKit.make_button("Close Guide", _close_rules, 20)
	close_btn.custom_minimum_size = Vector2(280, 48)
	outer.add_child(close_btn)


func _build_tab_basics() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)

	# Left: Illustrated diagram of Hukulshish, Castle, and Gold Mine
	var diag := Control.new()
	diag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diag.custom_minimum_size = Vector2(460, 0)
	diag.draw.connect(_draw_basics_diagram.bind(diag))
	hbox.add_child(diag)

	# Right: Rules text
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	hbox.add_child(right)

	right.add_child(_section_title("Controls & Combat", Color(0.45, 0.85, 1.0)))
	right.add_child(_body_text(
		"• WASD / Arrow Keys: Move around the maze (3.0 tiles/sec base).\n" +
		"• Left-Click (Crosshair): Shoot sharp arcane spells from your sapphire staff toward the cursor.\n" +
		"• Mana Bar (Purple): Starts at 10 max mana (1.0/s regen). Base Spell costs 2 mana; Boss Spells cost 1.5 mana; Endless Mega Spell costs 2 mana.\n" +
		"• E Key (once Auto-Shooting is unlocked): Toggle Auto-Fire ON/OFF (automatically fires in the direction you point your staff at ½ fire rate).\n" +
		"• F Key (once Homing is unlocked): Toggle Homing ON/OFF (curves spells toward enemies; does not affect Split Shots).\n" +
		"• 1 / 2 / 3 Keys (or click bottom icons): Use Magic Shield (+1 Shield, max 5), Healing Potion (+3 HP), or 2× Damage Potion (30s).\n" +
		"• Esc or P: Pause the game."
	))

	right.add_child(_section_title("Kingdom Castle & Three Shops", Color(0.95, 0.82, 0.32)))
	right.add_child(_body_text(
		"• Entering the Castle heals you up to 3 HP (never above 3 HP) and opens the upgrade menu:\n" +
		"  1. Spell Mods (Cyan Spell Scrolls, 1/7 monster drop): Upgrade Damage (+0.1×/lv), Mana Regen (+0.5/s), Mana Pool (up to 29), and Range (+0.1×/lv).\n" +
		"  2. Personal Shop (Emerald Enhancers, 1/4 Goblin & Undead drop; costs 3, 5, 9 for Lv 1–3):\n" +
		"     • Luck (+20%/lv drop rate) • Movement Speed (+5%/lv) • Health Regen (+1 HP/10s per lv)\n" +
		"     • Capacity (+1/3 mine cap/lv) • Rate (+15% mine gold/s per lv) • Income Multiplier (+50%/lv enemy & boss gold).\n" +
		"  3. Gold Shop: Upgrade Max HP (7 → 8 → 9 → 12 without instant heal), buy Spell Scrolls (up to 10), Magnet (300g), Auto Gold Collector (500g), Shoot Through Walls (500g — lets your spells pass through maze walls), Shield/Potions, Auto-Shoot (1000g), Homing (1500g), or a Doppelganger (5000g)."
	))
	return hbox


func _build_tab_augmentations() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	vbox.add_child(_body_text(
		"Augmentation Scrolls (Crimson Diamonds) drop ONLY from Demons (1/5 base chance). " +
		"Each Augmentation can be upgraded 3 times (costing 1, 2, then 3 Scrolls) and unlocks a powerful Unique Ability at Level 3:"
	))

	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 18)
	vbox.add_child(cards)

	cards.add_child(_make_aug_card(
		"Split Spell (45° Chain Splits + Lightning)",
		Color(0.45, 0.88, 1.0),
		_draw_split_diagram,
		"• Splits your spell into 2 projectiles at a 45° angle on enemy hit (½ damage each, no Homing).\n" +
		"• Upgrading lets each split projectile RE-SPLIT into 2 again on hit: up to 1 split (Lv 1), 2 sequential splits (Lv 2), or 3 sequential splits (Lv 3)!\n" +
		"• LV 3 UNIQUE — CHAIN LIGHTNING: Every split hit arcs lightning to another nearby enemy, zapping BOTH enemies for the split shot's full damage!"
	))

	cards.add_child(_make_aug_card(
		"Bombspell (Fire Zone + All-Hit / Range)",
		Color(1.0, 0.52, 0.22),
		_draw_bomb_diagram,
		"• Creates a burning fire zone for 3s dealing 3 (Lv 1), 5 (Lv 2), or 7 (Lv 3) fire dmg/sec.\n" +
		"• 1 tick of fire damage immediately shatters a Demon's bubble shield.\n" +
		"• LV 3 UNIQUE — TOTAL DETONATION: Explodes on EVERY hit (even initial hits before splitting) AND explodes when a spell reaches max range!"
	))

	cards.add_child(_make_aug_card(
		"Sniper (5× Speed + Explosive Shell)",
		Color(1.0, 0.92, 0.28),
		_draw_sniper_diagram,
		"• On initial enemy hit, fires a 5× speed homing shot dealing 2× (Lv 1), 3× (Lv 2), or 4× (Lv 3) damage.\n" +
		"• Targets ONLY Monsters & Bosses (never Nests) and does not repeat.\n" +
		"• LV 3 UNIQUE — EXPLOSIVE SHELL: The Sniper shot detonates with a Bombspell fire explosion upon hitting its target!"
	))

	return vbox


func _build_tab_enemies_and_bosses() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)

	var diag := Control.new()
	diag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diag.custom_minimum_size = Vector2(480, 0)
	diag.draw.connect(_draw_enemies_diagram.bind(diag))
	hbox.add_child(diag)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	hbox.add_child(right)

	right.add_child(_section_title("Monsters, Special Abilities & 3-Minute Scaling", Color(1.0, 0.45, 0.55)))
	right.add_child(_body_text(
		"• Goblin (Green): Fast melee monster; 1/4 chance to drop an Emerald Enhancer.\n" +
		"• Undead (Grey-Blue): Fires a WHITE 0-damage Slow Spell at ½ normal spell speed that slows your movement; 1/4 chance to drop an Enhancer.\n" +
		"• Demon (Crimson): Protected by a Cyan Bubble Shield that absorbs 1 spell hit (or 1 tick of Bombspell fire) before breaking; 1/5 chance to drop an Augmentation Scroll.\n" +
		"• Ogre (Brown): Heavy, high-HP melee bruiser.\n" +
		"• After 3 Minutes (every 30s): Enemy HP scales by +5 HP linearly on Medium, ×1.2 exponentially on Hard, and ×1.5 exponentially on Extreme (no change on Easy)."
	))

	right.add_child(_section_title("Nests, Mega Boss & Endless Mode", Color(1.0, 0.3, 0.3)))
	right.add_child(_body_text(
		"• 4 Corner Nests (70 HP): Destroying a Nest immediately spawns a Nest Boss (240 HP, drops 1000 gold + 1/3 chance for an Orange Boss Spell costing 1.5 mana).\n" +
		"• Mega Boss (2000 HP): Awakens once all 4 Nests are destroyed. Has a 100 HP Shield that regenerates after each ¼ of its max HP is lost (75%, 50%, 25%), and DUPLICATES into a second Mega Boss once 50% HP is lost! Defeat BOTH Mega Bosses to win!\n" +
		"• Endless Mode: Defeating both Mega Bosses spawns 4 new corner spawners, multiplies EVERYTHING'S HP by 2×, and drops a guaranteed 1/1 RED MEGA SPELL (costs 2 mana, combines all current spells × 1.5 damage and copies & uses your Base Spell's augmentations)!"
	))
	return hbox


func _make_aug_card(title: String, col: Color, draw_fn: Callable, desc: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_section_title(title, col))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0, 250)
	canvas.draw.connect(draw_fn.bind(canvas))
	box.add_child(canvas)
	box.add_child(_body_text(desc))
	return panel


func _section_title(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", col)
	return l


func _body_text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	return l


# --- Visual Diagram Renderers ---

func _draw_basics_diagram(c: Control) -> void:
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, Color(0.08, 0.1, 0.14, 0.95))
	c.draw_rect(rect, Color(0.3, 0.35, 0.48), false, 2.0)
	var font: Font = ThemeDB.fallback_font

	# 1. Mage with Sapphire Rhombus Staff + Offhand Open Magic Tome
	var p_pos := Vector2(120, 120)
	var r: float = 24.0
	c.draw_circle(p_pos, r * 1.35, Color(0.2, 0.7, 1.0, 0.22))
	c.draw_arc(p_pos, r * 1.35, 0.0, TAU, 28, Color(0.3, 0.85, 1.0, 0.85), 2.0)
	var mage_tex: Texture2D = Config.get_tex("res://assets/sprites/player/player_mage.png")
	if mage_tex != null:
		Config.draw_sprite_centered(c, mage_tex, p_pos, Vector2(58, 58))
	else:
		c.draw_circle(p_pos, r, Color(0.25, 0.3, 0.85))
	Config.draw_mage_loadout(c, p_pos, r, Vector2.RIGHT, 0.0, false, 1.0)
	c.draw_string(font, Vector2(200, 105), "Hukulshish (7 Base HP)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.9, 0.5))
	c.draw_string(font, Vector2(200, 128), "• Main Hand: Sapphire Gem Staff", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.65, 0.88, 1.0))
	c.draw_string(font, Vector2(200, 148), "• Offhand: Open Magic Tome", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.88, 0.68))

	# 2. Kingdom Castle (Heals up to 3 HP)
	var cas_pos := Vector2(120, 275)
	var cas_tex: Texture2D = Config.get_tex("res://assets/sprites/world/castle.png")
	if cas_tex != null:
		Config.draw_sprite_centered(c, cas_tex, cas_pos, Vector2(96, 96))
	else:
		c.draw_rect(Rect2(cas_pos - Vector2(42, 42), Vector2(84, 84)), Color(0.42, 0.4, 0.46))
	c.draw_string(font, Vector2(200, 265), "Kingdom Castle", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.82, 0.32))
	c.draw_string(font, Vector2(200, 288), "• Heals up to 3 HP on entry", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.95, 0.7))
	c.draw_string(font, Vector2(200, 308), "• Opens Spell, Personal & Gold Shops", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.88, 0.95))

	# 3. Gold Mine
	var mine_pos := Vector2(120, 425)
	var mine_tex: Texture2D = Config.get_tex("res://assets/sprites/world/gold_mine.png")
	if mine_tex != null:
		Config.draw_sprite_centered(c, mine_tex, mine_pos, Vector2(78, 78))
	else:
		c.draw_circle(mine_pos, 32.0, Color(0.38, 0.35, 0.32))
	c.draw_string(font, Vector2(200, 415), "Gold Mines (×3 on Map)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.88, 0.25))
	c.draw_string(font, Vector2(200, 438), "• 7.5 gold/s (333 cap base)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.88, 0.95))
	c.draw_string(font, Vector2(200, 458), "• Walk over or buy 500g Auto-Collector (30s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.88, 0.95))


func _draw_split_diagram(c: Control) -> void:
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, Color(0.07, 0.09, 0.14, 0.95))
	c.draw_rect(rect, Color(0.25, 0.55, 0.75), false, 1.5)
	var font: Font = ThemeDB.fallback_font

	var start := Vector2(30, rect.size.y * 0.55)
	var hit1 := Vector2(115, rect.size.y * 0.55)
	# Initial shot
	c.draw_line(start, hit1, Color(0.4, 0.75, 1.0), 4.0)
	c.draw_circle(hit1, 14.0, Color(0.85, 0.25, 0.3))

	# 1st Split (into 2 at 45°)
	var split1_top := hit1 + Vector2.from_angle(deg_to_rad(-22.5)) * 90.0
	var split1_bot := hit1 + Vector2.from_angle(deg_to_rad(22.5)) * 90.0
	c.draw_line(hit1, split1_top, Color(0.55, 0.88, 1.0), 3.0)
	c.draw_line(hit1, split1_bot, Color(0.55, 0.88, 1.0), 3.0)
	c.draw_circle(split1_top, 12.0, Color(0.85, 0.25, 0.3))
	c.draw_circle(split1_bot, 12.0, Color(0.85, 0.25, 0.3))

	# 2nd Split (each re-splits into 2 again!)
	var split2_a := split1_top + Vector2.from_angle(deg_to_rad(-45.0)) * 75.0
	var split2_b := split1_top + Vector2.from_angle(deg_to_rad(0.0)) * 75.0
	var split2_c := split1_bot + Vector2.from_angle(deg_to_rad(0.0)) * 75.0
	var split2_d := split1_bot + Vector2.from_angle(deg_to_rad(45.0)) * 75.0
	c.draw_line(split1_top, split2_a, Color(0.7, 0.94, 1.0), 2.4)
	c.draw_line(split1_top, split2_b, Color(0.7, 0.94, 1.0), 2.4)
	c.draw_line(split1_bot, split2_c, Color(0.7, 0.94, 1.0), 2.4)
	c.draw_line(split1_bot, split2_d, Color(0.7, 0.94, 1.0), 2.4)
	c.draw_circle(split2_b, 11.0, Color(0.85, 0.25, 0.3))
	c.draw_circle(split2_c, 11.0, Color(0.85, 0.25, 0.3))

	# Chain Lightning arc between hit enemies
	var lightning := PackedVector2Array([
		split2_b,
		split2_b.lerp(split2_c, 0.33) + Vector2(6, -6),
		split2_b.lerp(split2_c, 0.66) + Vector2(-6, 6),
		split2_c,
	])
	c.draw_polyline(lightning, Color(0.35, 0.9, 1.0, 0.6), 5.5)
	c.draw_polyline(lightning, Color(1.0, 1.0, 0.45), 2.5)
	c.draw_string(font, Vector2(18, 26), "1→2→4→8 Re-Splits (Lv 1–3) + Lv 3 Chain Lightning!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.45))


func _draw_bomb_diagram(c: Control) -> void:
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, Color(0.07, 0.09, 0.14, 0.95))
	c.draw_rect(rect, Color(0.75, 0.4, 0.2), false, 1.5)
	var font: Font = ThemeDB.fallback_font

	var start := Vector2(35, rect.size.y * 0.58)
	var hit1 := Vector2(155, rect.size.y * 0.58)
	var end_range := Vector2(325, rect.size.y * 0.58)

	# Fire zone on hit
	c.draw_circle(hit1, 44.0, Color(1.0, 0.38, 0.08, 0.28))
	c.draw_arc(hit1, 44.0, 0.0, TAU, 32, Color(1.0, 0.75, 0.2, 0.9), 2.5)
	c.draw_circle(hit1, 14.0, Color(0.85, 0.25, 0.3))

	# Fire zone at max range end
	c.draw_circle(end_range, 44.0, Color(1.0, 0.38, 0.08, 0.28))
	c.draw_arc(end_range, 44.0, 0.0, TAU, 32, Color(1.0, 0.75, 0.2, 0.9), 2.5)

	c.draw_line(start, end_range, Color(0.45, 0.8, 1.0), 3.5)
	c.draw_string(font, Vector2(105, rect.size.y * 0.58 + 62), "Explodes on Hit", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.8, 0.4))
	c.draw_string(font, Vector2(260, rect.size.y * 0.58 + 62), "Explodes at Max Range!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.8, 0.4))
	c.draw_string(font, Vector2(20, 26), "Lv 3: Explodes on EVERY hit (even split) + Range End!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.78, 0.35))


func _draw_sniper_diagram(c: Control) -> void:
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, Color(0.07, 0.09, 0.14, 0.95))
	c.draw_rect(rect, Color(0.75, 0.68, 0.22), false, 1.5)
	var font: Font = ThemeDB.fallback_font

	var start := Vector2(35, rect.size.y * 0.65)
	var hit1 := Vector2(140, rect.size.y * 0.65)
	var nest_pos := Vector2(240, rect.size.y * 0.78)
	var boss_pos := Vector2(325, rect.size.y * 0.42)

	# Initial spell hit
	c.draw_line(start, hit1, Color(0.4, 0.75, 1.0), 3.5)
	c.draw_circle(hit1, 14.0, Color(0.85, 0.25, 0.3))

	# Ignored Nest
	c.draw_circle(nest_pos, 18.0, Color(0.35, 0.32, 0.38))
	c.draw_circle(nest_pos, 8.0, Color(0.08, 0.05, 0.08))
	c.draw_string(font, nest_pos + Vector2(-28, 32), "Nest (Ignored)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.65, 0.7))

	# 5x Speed Sniper homing to Boss + Lv 3 Explosion
	c.draw_circle(boss_pos, 40.0, Color(1.0, 0.38, 0.08, 0.28))
	c.draw_arc(boss_pos, 40.0, 0.0, TAU, 32, Color(1.0, 0.75, 0.2, 0.9), 2.5)
	c.draw_line(hit1, boss_pos, Color(1.0, 0.95, 0.25), 4.0)
	c.draw_circle(boss_pos, 18.0, Color(0.65, 0.18, 0.7))
	c.draw_string(font, Vector2(20, 26), "Lv 3: 5× Speed vs Monsters/Bosses + Bomb Explosion!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.35))


func _draw_enemies_diagram(c: Control) -> void:
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, Color(0.08, 0.1, 0.14, 0.95))
	c.draw_rect(rect, Color(0.3, 0.35, 0.48), false, 2.0)
	var font: Font = ThemeDB.fallback_font

	c.draw_string(font, Vector2(20, 32), "Pickup Guide (All Pulled by 300g Magnet)", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.85, 0.35))

	# 1. Cyan Spell Scroll
	var p1 := Vector2(45, 72)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/spells/spell_scroll.png"), p1, Vector2(28, 28))
	c.draw_string(font, Vector2(72, 78), "Spell Scroll (1/7 all monsters) → Spell Mods", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.95, 1.0))

	# 2. Crimson Aug Scroll
	var p2 := Vector2(45, 112)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/spells/aug_scroll.png"), p2, Vector2(28, 28))
	c.draw_string(font, Vector2(72, 118), "Augmentation Scroll (1/5 Demons) → 3 Augmentations", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.65, 0.72))

	# 3. Emerald Enhancer
	var p3 := Vector2(45, 152)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/spells/enhancer.png"), p3, Vector2(28, 28))
	c.draw_string(font, Vector2(72, 158), "Enhancer (1/4 Goblins & Undead) → Personal Shop", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.65, 1.0, 0.75))

	# 4. Orange Boss Spell & Red Mega Spell
	var p4 := Vector2(45, 192)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/spells/boss_spell.png"), p4 - Vector2(10, 0), Vector2(24, 24))
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/spells/mega_spell.png"), p4 + Vector2(10, 0), Vector2(26, 26))
	c.draw_string(font, Vector2(72, 198), "Orange Boss Spell (1/3) & RED Endless Mega Spell (1/1)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.55))

	# Demon Bubble Shield + Undead White Slow Spell + Mega Boss Shield
	c.draw_string(font, Vector2(20, 250), "Special Enemy Mechanics", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.85, 0.35))

	var d_pos := Vector2(55, 305)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/monsters/demon.png"), d_pos, Vector2(36, 36))
	c.draw_circle(d_pos, 22.0, Color(0.25, 0.85, 1.0, 0.25))
	c.draw_arc(d_pos, 22.0, 0.0, TAU, 28, Color(0.45, 0.95, 1.0), 2.0)
	c.draw_string(font, Vector2(95, 310), "Demon: 1-Hit Cyan Bubble Shield", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.9, 0.95))

	var u_pos := Vector2(55, 365)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/monsters/undead.png"), u_pos, Vector2(36, 36))
	c.draw_line(u_pos + Vector2(18, 0), u_pos + Vector2(58, 0), Color(1, 1, 1, 0.6), 4.0)
	c.draw_circle(u_pos + Vector2(58, 0), 6.0, Color.WHITE)
	c.draw_string(font, Vector2(128, 370), "Undead: White 0-Dmg Slow Spell (½ Speed)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.95, 1.0))

	var m_pos := Vector2(55, 435)
	Config.draw_sprite_centered(c, Config.get_tex("res://assets/sprites/bosses/mega_boss.png"), m_pos, Vector2(48, 48))
	c.draw_arc(m_pos, 28.0, 0.0, TAU, 32, Color(0.35, 0.9, 1.0), 2.5)
	c.draw_string(font, Vector2(95, 432), "Mega Boss (2000 HP): 100 HP Shield", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.9, 1.0))
	c.draw_string(font, Vector2(95, 452), "Regenerates at 75%, 50%, and 25% HP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.9, 1.0))
