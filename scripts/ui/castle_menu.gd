class_name CastleMenu
extends CanvasLayer
## Castle upgrade menu (§5, §6.2–6.3). Pauses the game while open.
## Upgrade the base spell with gold, spend mod parts on the 4 base-spell mods,
## and inspect boss spells acquired during the run.

var _root: Control
var _resources_label: Label
var _upgrade_button: Button
var _mods_box: VBoxContainer
var _spells_box: VBoxContainer


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
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(UIKit.make_label("Kingdom Castle", 34, Color(0.95, 0.8, 0.3)))
	box.add_child(UIKit.make_label("Restored HP up to 70% max", 15, Color(0.55, 0.9, 0.65)))
	_resources_label = UIKit.make_label("", 20)
	box.add_child(_resources_label)
	_upgrade_button = UIKit.make_button("", _on_upgrade_pressed, 19)
	box.add_child(_upgrade_button)

	box.add_child(UIKit.make_label("Spell Mods (+0.1× per level)", 22, Color(0.45, 0.85, 1.0)))
	_mods_box = VBoxContainer.new()
	_mods_box.add_theme_constant_override("separation", 6)
	box.add_child(_mods_box)

	box.add_child(UIKit.make_label("Boss Spells", 22, Color(1.0, 0.65, 0.25)))
	_spells_box = VBoxContainer.new()
	_spells_box.add_theme_constant_override("separation", 4)
	box.add_child(_spells_box)

	box.add_child(UIKit.make_button("Leave Castle", close, 20))


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
			_spells_box.add_child(UIKit.make_label(info, 16, s["color"] as Color))


func _on_upgrade_pressed() -> void:
	GameState.try_upgrade_spell()


func _on_buy_mod(id: String) -> void:
	GameState.try_buy_mod(id)
