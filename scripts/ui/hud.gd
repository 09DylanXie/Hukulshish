class_name HUD
extends CanvasLayer
## In-game HUD: HP bar, Fortnite-style Shield bar (max 5), Mana bar (with regen),
## gold / spell scrolls / aug scrolls, objectives, top-right Pause button + overlay, and bottom circular hotbar.

var _player: Player
var _hp_bar: ProgressBar
var _hp_label: Label
var _shield_bar: ProgressBar
var _shield_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label
var _gold_label: Label
var _spell_label: Label
var _objective_label: Label
var _hint_label: Label
var _pause_button: Button
var _pause_overlay: Control
var _slots: Array[Control] = []
var _slot_hovered: Array[bool] = [false, false, false]
var _elapsed: float = 0.0

const _SLOT_TITLES: Array[String] = ["Shield [1]", "Heal +3 [2]", "2× Dmg [3]"]
const _SLOT_COLORS: Array[Color] = [
	Color(0.25, 0.72, 1.0),
	Color(0.95, 0.28, 0.42),
	Color(0.95, 0.68, 0.18),
]


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_stats_panel()
	_build_hint_label()
	_build_pause_ui()
	_build_hotbar()

	GameState.changed.connect(_refresh)
	GameState.mana_changed.connect(_on_mana_changed)
	_on_mana_changed(GameState.mana, GameState.max_mana(), GameState.mana_regen())
	_refresh()


func bind_player(player: Player) -> void:
	_player = player
	player.hp_changed.connect(_on_hp_changed)
	player.shield_changed.connect(_on_shield_changed)
	_on_hp_changed(player.hp, player.max_hp)
	_on_shield_changed(player.shield, player.max_shield)


func _process(delta: float) -> void:
	if not get_tree().paused:
		_elapsed += delta
	if _elapsed < Config.NEST_SPAWN_DELAY_SEC:
		_hint_label.text = "Monsters awaken in %d…" % ceili(Config.NEST_SPAWN_DELAY_SEC - _elapsed)
	elif GameState.mega_boss_spawned and not GameState.mega_boss_defeated:
		_hint_label.text = "THE MEGA BOSS HAS AWAKENED! Defeat it to win!"
	elif not GameState.auto_shoot_unlocked and _elapsed < 12.0:
		_hint_label.text = "Left-click to shoot toward cursor • Enter castle to shop & heal"
	else:
		_hint_label.text = ""

	for s in _slots:
		s.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.run_over:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P):
		if _pause_overlay.visible:
			_set_paused(false)
			get_viewport().set_input_as_handled()
		elif not get_tree().paused:
			_set_paused(true)
			get_viewport().set_input_as_handled()
	elif not get_tree().paused and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_1:
			_use_slot(0)
		elif k == KEY_2:
			_use_slot(1)
		elif k == KEY_3:
			_use_slot(2)


func _build_stats_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_hp_label = _label(box, "HP")
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(280, 14)
	_hp_bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.2, 0.25)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	box.add_child(_hp_bar)

	_shield_label = _label(box, "Shield")
	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(280, 12)
	_shield_bar.show_percentage = false
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.2, 0.68, 1.0)
	_shield_bar.add_theme_stylebox_override("fill", shield_fill)
	box.add_child(_shield_bar)

	_mana_label = _label(box, "Mana")
	_mana_bar = ProgressBar.new()
	_mana_bar.custom_minimum_size = Vector2(280, 12)
	_mana_bar.show_percentage = false
	var mana_fill := StyleBoxFlat.new()
	mana_fill.bg_color = Color(0.58, 0.32, 0.98)
	_mana_bar.add_theme_stylebox_override("fill", mana_fill)
	box.add_child(_mana_bar)

	_gold_label = _label(box, "")
	_spell_label = _label(box, "")
	_objective_label = _label(box, "")


func _build_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.position = Vector2(-360, 18)
	_hint_label.custom_minimum_size = Vector2(720, 0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)


func _build_pause_ui() -> void:
	_pause_button = UIKit.make_button("⏸ Pause", func() -> void:
		if _pause_overlay.visible:
			_set_paused(false)
		elif not get_tree().paused:
			_set_paused(true)
	, 20)
	_pause_button.custom_minimum_size = Vector2(130, 44)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-146, 16)
	add_child(_pause_button)

	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.hide()
	add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(UIKit.make_label("Game Paused", 36, Color(0.95, 0.8, 0.3)))
	box.add_child(UIKit.make_button("Resume", func() -> void: _set_paused(false), 22))
	box.add_child(UIKit.make_button("Restart Run", func() -> void: SceneRouter.goto(SceneRouter.GAME), 22))
	box.add_child(UIKit.make_button("Main Menu", func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU), 22))


func _set_paused(paused_state: bool) -> void:
	_pause_overlay.visible = paused_state
	get_tree().paused = paused_state


func _build_hotbar() -> void:
	var bar_wrap := CenterContainer.new()
	bar_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_wrap.position = Vector2(0, -108)
	bar_wrap.custom_minimum_size = Vector2(0, 96)
	bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_wrap)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_wrap.add_child(hbox)

	for idx in 3:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(84, 88)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.mouse_entered.connect(_on_slot_hover.bind(idx, true))
		slot.mouse_exited.connect(_on_slot_hover.bind(idx, false))
		slot.gui_input.connect(_on_slot_gui_input.bind(idx, slot))
		slot.draw.connect(_draw_slot.bind(idx, slot))
		hbox.add_child(slot)
		_slots.append(slot)


func _on_slot_hover(idx: int, hovered: bool) -> void:
	_slot_hovered[idx] = hovered
	_slots[idx].queue_redraw()


func _on_slot_gui_input(event: InputEvent, idx: int, slot: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_use_slot(idx)
			slot.accept_event()


func _draw_slot(idx: int, slot: Control) -> void:
	var center := Vector2(slot.size.x * 0.5, 34.0)
	var r: float = 28.0
	var tint: Color = _SLOT_COLORS[idx]
	var title: String = _SLOT_TITLES[idx]
	var count: int = 0
	var active_timer: float = 0.0
	match idx:
		0:
			count = GameState.shield_items
		1:
			count = GameState.heal_potions
			active_timer = GameState.heal_potion_timer
		2:
			count = GameState.damage_potions
			active_timer = GameState.damage_boost_timer

	var bg_col := Color(0.14, 0.16, 0.22, 0.92) if not _slot_hovered[idx] else Color(0.22, 0.25, 0.34, 0.96)
	slot.draw_circle(center, r, bg_col)
	var ring_col: Color = tint if (count > 0 or active_timer > 0.0) else Color(0.45, 0.48, 0.55, 0.7)
	slot.draw_arc(center, r, 0.0, TAU, 36, ring_col, 3.0 if active_timer > 0.0 else 2.0)

	if active_timer > 0.0:
		var ratio: float = clampf(active_timer / Config.POTION_DURATION_SEC, 0.0, 1.0)
		slot.draw_arc(center, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, Color(1.0, 0.95, 0.35), 3.0)

	var icon_alpha: float = 1.0 if (count > 0 or active_timer > 0.0) else 0.35
	var ic := Color(tint.r, tint.g, tint.b, icon_alpha)
	if idx == 0:
		var pts := PackedVector2Array([
			center + Vector2(0, -14),
			center + Vector2(12, -8),
			center + Vector2(10, 6),
			center + Vector2(0, 15),
			center + Vector2(-10, 6),
			center + Vector2(-12, -8),
		])
		slot.draw_colored_polygon(pts, ic)
	else:
		slot.draw_circle(center + Vector2(0, 4), 11.0, ic)
		slot.draw_rect(Rect2(center + Vector2(-4, -13), Vector2(8, 8)), ic.lightened(0.25))
		slot.draw_rect(Rect2(center + Vector2(-6, -15), Vector2(12, 3)), Color(0.85, 0.75, 0.55, icon_alpha))

	var font: Font = ThemeDB.fallback_font
	slot.draw_string(font, center + Vector2(10, 18), "×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if active_timer > 0.0:
		slot.draw_string(font, center + Vector2(-14, 5), "%ds" % ceili(active_timer), HORIZONTAL_ALIGNMENT_CENTER, 28, 13, Color(1, 1, 0.4))
	slot.draw_string(font, Vector2(0, 78), title, HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, 13, Color(0.88, 0.9, 0.95))


func _use_slot(index: int) -> void:
	if get_tree().paused or GameState.run_over:
		return
	match index:
		0:
			GameState.try_use_shield_item(_player)
		1:
			GameState.try_use_heal_potion(_player)
		2:
			GameState.try_use_damage_potion()
	_refresh()


func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "HP  %d / %d" % [hp, max_hp]


func _on_shield_changed(shield: int, max_shield: int) -> void:
	_shield_bar.max_value = max_shield
	_shield_bar.value = shield
	_shield_label.text = "Shield  %d / %d" % [shield, max_shield]


func _on_mana_changed(mana: float, max_mana: int, regen: float) -> void:
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_mana_label.text = "Mana  %.1f / %d  (+%.1f/s)" % [mana, max_mana, regen]


func _refresh() -> void:
	_gold_label.text = "Gold  %d   Spell Scrolls  %d   Aug Scrolls  %d" % [
		GameState.gold, GameState.mod_parts, GameState.aug_scrolls]
	var base: Dictionary = GameState.base_spell_stats()
	var dmg: float = float(base["damage"]) * GameState.damage_boost_multiplier()
	var extra: String = ""
	if not GameState.boss_spells.is_empty():
		extra = "  +%d boss spell(s)" % GameState.boss_spells.size()
	var mode_tag: String = " [Auto]" if GameState.auto_shoot_unlocked else " [Click]"
	if GameState.homing_unlocked:
		mode_tag += " [Homing]"
	if GameState.magnet_unlocked:
		mode_tag += " [Magnet]"
	_spell_label.text = "Spell Lv %d  (%.1f dmg, 1 mana)%s%s" % [
		GameState.spell_level, dmg, extra, mode_tag]
	if GameState.mega_boss_spawned:
		_objective_label.text = "Nests  4/4    Mega Boss  ACTIVE"
	else:
		_objective_label.text = "Nests  %d/4    Bosses  %d/4" % [GameState.nests_destroyed, GameState.bosses_defeated]
	for s in _slots:
		s.queue_redraw()


func _label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	parent.add_child(l)
	return l
