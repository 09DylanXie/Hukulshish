class_name CastleMenu
extends CanvasLayer
## Castle upgrade & shop menu (§5, §6.2–6.3). Pauses the game while open.
## Left side: Base Spell upgrade, Spell Mods, and Boss Spells.
## Right side: Gold Shop (Mod Parts, Magic Shield, Healing Potion, 2× Damage Potion, Auto-Shooting).

var _root: Control
var _resources_label: Label
var _upgrade_button: Button
var _mods_box: VBoxContainer
var _spells_box: VBoxContainer
var _gold_shop_box: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	GameState.changed.connect(_refresh)


func open() -> void:
	if GameState.run_over:
		return
	_refresh()
	_root.show()
	get_tree().paused = true
	_upgrade_button.grab_focus.call_deferred()


func close() -> void:
	_root.hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	outer.add_child(UIKit.make_label("Kingdom Castle", 36, Color(0.95, 0.8, 0.3)))
	outer.add_child(UIKit.make_label("Restored HP up to 70% max", 15, Color(0.55, 0.9, 0.65)))
	_resources_label = UIKit.make_label("", 22)
	outer.add_child(_resources_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	outer.add_child(columns)

	# Left column: Base spell + Spell Mods + Boss Spells
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 10)
	columns.add_child(left_col)

	_upgrade_button = UIKit.make_button("", _on_upgrade_pressed, 18)
	left_col.add_child(_upgrade_button)

	left_col.add_child(UIKit.make_label("Spell Mods", 24, Color(0.45, 0.85, 1.0)))
	_mods_box = VBoxContainer.new()
	_mods_box.add_theme_constant_override("separation", 6)
	left_col.add_child(_mods_box)

	left_col.add_child(UIKit.make_label("Boss Spells", 22, Color(1.0, 0.65, 0.25)))
	_spells_box = VBoxContainer.new()
	_spells_box.add_theme_constant_override("separation", 4)
	left_col.add_child(_spells_box)

	# Right column: Gold Shop
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 10)
	columns.add_child(right_col)

	right_col.add_child(UIKit.make_label("Gold Shop", 24, Color(1.0, 0.85, 0.25)))
	_gold_shop_box = VBoxContainer.new()
	_gold_shop_box.add_theme_constant_override("separation", 8)
	right_col.add_child(_gold_shop_box)

	outer.add_child(UIKit.make_button("Leave Castle", close, 20))


func _refresh() -> void:
	if _root == null:
		return
	_resources_label.text = "Gold: %d      Mod Parts: %d" % [GameState.gold, GameState.mod_parts]
	var lvl: int = GameState.spell_level
	if GameState.is_spell_maxed():
		_upgrade_button.text = "Base Spell Lv %d (%d base dmg) — MAX" % [lvl, Config.spell_damage(lvl)]
		_upgrade_button.disabled = true
	else:
		var cost: int = GameState.next_upgrade_cost()
		_upgrade_button.text = "Upgrade Base Spell  Lv %d → %d  (%d → %d base dmg)  —  %d gold" % [
			lvl, lvl + 1, Config.spell_damage(lvl), Config.spell_damage(lvl + 1), cost]
		_upgrade_button.disabled = GameState.gold < cost

	for c in _mods_box.get_children():
		c.queue_free()
	for id in Config.MODS:
		var label_name: String = Config.MODS[id]
		var mod_lvl: int = int(GameState.mod_levels.get(id, 0))
		var cur_mult: float = GameState.mod_multiplier(id)
		var next_mult: float = cur_mult + Config.MOD_STEP
		var cost: int = GameState.next_mod_cost(id)
		var text: String = "%s  Lv %d (×%.1f → ×%.1f)  —  %d part%s" % [
			label_name, mod_lvl, cur_mult, next_mult, cost, "" if cost == 1 else "s"]
		var btn: Button = UIKit.make_button(text, _on_buy_mod.bind(id), 17)
		btn.custom_minimum_size = Vector2(0, 42)
		btn.disabled = GameState.mod_parts < cost
		_mods_box.add_child(btn)

	for c in _spells_box.get_children():
		c.queue_free()
	if GameState.boss_spells.is_empty():
		_spells_box.add_child(UIKit.make_label("None yet — bosses have a 1/3 chance to drop a new spell.", 15, Color(0.7, 0.7, 0.75)))
	else:
		for s in GameState.boss_spells:
			var info: String = "★ %s — %.1f dmg, %.2f/s, %.1f tiles/s (frozen)" % [
				s["name"], float(s["damage"]), float(s["fire_rate"]), float(s["speed_tiles"])]
			_spells_box.add_child(UIKit.make_label(info, 15, s["color"] as Color))

	# Populate Gold Shop
	for c in _gold_shop_box.get_children():
		c.queue_free()

	# 1. Mod Part (100 gold first, +100 each up to 10)
	var bought: int = GameState.mod_parts_bought_with_gold
	if GameState.can_buy_gold_mod_part():
		var mp_cost: int = GameState.next_gold_mod_part_cost()
		var mp_btn: Button = UIKit.make_button(
			"Mod Part (%d/%d)  —  %d gold" % [bought, Config.GOLD_SHOP_MOD_PART_MAX, mp_cost],
			func() -> void: GameState.try_buy_gold_mod_part(), 17)
		mp_btn.custom_minimum_size = Vector2(0, 42)
		mp_btn.disabled = GameState.gold < mp_cost
		_gold_shop_box.add_child(mp_btn)
	else:
		var mp_done: Button = UIKit.make_button("Mod Part (%d/%d) — SOLD OUT" % [bought, Config.GOLD_SHOP_MOD_PART_MAX], func() -> void: pass, 17)
		mp_done.custom_minimum_size = Vector2(0, 42)
		mp_done.disabled = true
		_gold_shop_box.add_child(mp_done)

	# 2. Temporary Magic Shield (+1 Shield, 200 gold)
	var sh_btn: Button = UIKit.make_button(
		"Magic Shield (+1 Shield) [Owned: %d]  —  %d gold" % [GameState.shield_items, Config.GOLD_SHOP_SHIELD_COST],
		func() -> void: GameState.try_buy_shield_item(), 17)
	sh_btn.custom_minimum_size = Vector2(0, 42)
	sh_btn.disabled = GameState.gold < Config.GOLD_SHOP_SHIELD_COST
	_gold_shop_box.add_child(sh_btn)

	# 3. 3 HP Healing Potion (100 gold)
	var hp_btn: Button = UIKit.make_button(
		"3 HP Healing Potion [Owned: %d]  —  %d gold" % [GameState.heal_potions, Config.GOLD_SHOP_POTION_COST],
		func() -> void: GameState.try_buy_heal_potion(), 17)
	hp_btn.custom_minimum_size = Vector2(0, 42)
	hp_btn.disabled = GameState.gold < Config.GOLD_SHOP_POTION_COST
	_gold_shop_box.add_child(hp_btn)

	# 4. 2× Damage Boost Potion (30s, 100 gold)
	var dmg_btn: Button = UIKit.make_button(
		"2× Damage Boost Potion (30s) [Owned: %d]  —  %d gold" % [GameState.damage_potions, Config.GOLD_SHOP_POTION_COST],
		func() -> void: GameState.try_buy_damage_potion(), 17)
	dmg_btn.custom_minimum_size = Vector2(0, 42)
	dmg_btn.disabled = GameState.gold < Config.GOLD_SHOP_POTION_COST
	_gold_shop_box.add_child(dmg_btn)

	# 5. Auto-Shooting Unlock (1000 gold)
	if GameState.auto_shoot_unlocked:
		var auto_done: Button = UIKit.make_button("Auto-Shooting — UNLOCKED", func() -> void: pass, 17)
		auto_done.custom_minimum_size = Vector2(0, 42)
		auto_done.disabled = true
		_gold_shop_box.add_child(auto_done)
	else:
		var auto_btn: Button = UIKit.make_button(
			"Unlock Auto-Shooting  —  %d gold" % Config.GOLD_SHOP_AUTO_SHOOT_COST,
			func() -> void: GameState.try_buy_auto_shoot(), 17)
		auto_btn.custom_minimum_size = Vector2(0, 42)
		auto_btn.disabled = GameState.gold < Config.GOLD_SHOP_AUTO_SHOOT_COST
		_gold_shop_box.add_child(auto_btn)

	# 6. Homing Unlock (1500 gold)
	if GameState.homing_unlocked:
		var homing_done: Button = UIKit.make_button("Homing — UNLOCKED", func() -> void: pass, 17)
		homing_done.custom_minimum_size = Vector2(0, 42)
		homing_done.disabled = true
		_gold_shop_box.add_child(homing_done)
	else:
		var homing_btn: Button = UIKit.make_button(
			"Unlock Homing  —  %d gold" % Config.GOLD_SHOP_HOMING_COST,
			func() -> void: GameState.try_buy_homing(), 17)
		homing_btn.custom_minimum_size = Vector2(0, 42)
		homing_btn.disabled = GameState.gold < Config.GOLD_SHOP_HOMING_COST
		_gold_shop_box.add_child(homing_btn)


func _on_upgrade_pressed() -> void:
	GameState.try_upgrade_spell()


func _on_buy_mod(id: String) -> void:
	GameState.try_buy_mod(id)
