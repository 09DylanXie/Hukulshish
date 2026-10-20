class_name CastleMenu
extends CanvasLayer
## Castle upgrade menu (§5, §6.2–6.3). Pauses the game while open.
## Upgrade the base spell with gold, and apply spell mods picked up from nests.

var _root: Control
var _gold_label: Label
var _upgrade_button: Button
var _mods_box: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	GameState.gold_changed.connect(func(_g: int) -> void: _refresh())
	GameState.spell_level_changed.connect(func(_l: int) -> void: _refresh())
	GameState.mods_changed.connect(_refresh)


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
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(UIKit.make_label("Kingdom Castle", 36, Color(0.95, 0.8, 0.3)))
	_gold_label = UIKit.make_label("", 20)
	box.add_child(_gold_label)
	_upgrade_button = UIKit.make_button("", _on_upgrade_pressed, 20)
	box.add_child(_upgrade_button)

	box.add_child(UIKit.make_label("Spell Mods", 24, Color(0.85, 0.6, 1)))
	_mods_box = VBoxContainer.new()
	_mods_box.add_theme_constant_override("separation", 6)
	box.add_child(_mods_box)

	box.add_child(UIKit.make_button("Leave Castle", close, 20))


func _refresh() -> void:
	if _root == null:
		return
	_gold_label.text = "Gold: %d" % GameState.gold
	var lvl: int = GameState.spell_level
	if GameState.is_spell_maxed():
		_upgrade_button.text = "Base Spell Lv %d (%d dmg) — MAX" % [lvl, Config.spell_damage(lvl)]
		_upgrade_button.disabled = true
	else:
		var cost: int = GameState.next_upgrade_cost()
		_upgrade_button.text = "Upgrade Base Spell  Lv %d → %d  (%d → %d dmg)  —  %d gold" % [
			lvl, lvl + 1, Config.spell_damage(lvl), Config.spell_damage(lvl + 1), cost]
		_upgrade_button.disabled = GameState.gold < cost

	for c in _mods_box.get_children():
		c.queue_free()
	if GameState.pending_mods.is_empty() and GameState.active_mods.is_empty():
		_mods_box.add_child(UIKit.make_label("None yet — destroyed nests sometimes drop one.", 16, Color(0.7, 0.7, 0.75)))
	for i in GameState.pending_mods.size():
		var mod: SpellData = GameState.pending_mods[i]
		var text: String = "Apply %s  (locks in %d dmg)" % [mod.name, Config.spell_damage(lvl)]
		_mods_box.add_child(UIKit.make_button(text, _on_apply_mod.bind(i), 18))
	for m in GameState.active_mods:
		var data: SpellData = m["data"]
		_mods_box.add_child(UIKit.make_label("✔ %s — %d dmg" % [data.name, m["damage"]], 16, data.color))


func _on_upgrade_pressed() -> void:
	GameState.try_upgrade_spell()


func _on_apply_mod(index: int) -> void:
	GameState.apply_mod(index)
