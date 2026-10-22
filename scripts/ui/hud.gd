class_name HUD
extends CanvasLayer
## In-game HUD: HP bar, Fortnite-style Shield bar (max 5), gold/mod parts, objectives,
## top-right Pause button + Pause overlay, and the bottom circular item hotbar.

var _player: Player
var _hp_bar: ProgressBar
var _hp_label: Label
var _shield_bar: ProgressBar
var _shield_label: Label
var _gold_label: Label
var _spell_label: Label
var _objective_label: Label
var _hint_label: Label
var _pause_button: Button
var _pause_overlay: Control
var _slots: Array[Control] = []
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_stats_panel()
	_build_hint_label()
	_build_pause_ui()
	_build_hotbar()

	GameState.changed.connect(_refresh)
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
		# Only toggle pause here if the castle menu didn't already pause the tree.
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
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	_hp_label = _label(box, "HP")
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 14)
	_hp_bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.2, 0.25)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	box.add_child(_hp_bar)

	_shield_label = _label(box, "Shield")
	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(260, 12)
	_shield_bar.show_percentage = false
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.2, 0.68, 1.0)
	_shield_bar.add_theme_stylebox_override("fill", shield_fill)
	box.add_child(_shield_bar)

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
	add_child(_hint_label)


func _build_pause_ui() -> void:
	_pause_button = Button.new()
	_pause_button.text = "⏸ Pause"
	_pause_button.custom_minimum_size = Vector2(130, 44)
	_pause_button.add_theme_font_size_override("font_size", 20)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-146, 16)
	_pause_button.pressed.connect(func() -> void:
		if _pause_overlay.visible:
			_set_paused(false)
		elif not get_tree().paused:
			_set_paused(true)
	)
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

	var defs: Array[Dictionary] = [
		{"index": 0, "title": "Shield [1]", "color": Color(0.25, 0.72, 1.0)},
		{"index": 1, "title": "Heal +3 [2]", "color": Color(0.95, 0.28, 0.42)},
		{"index": 2, "title": "2× Dmg [3]", "color": Color(0.95, 0.68, 0.18)},
	]
	for d in defs:
		var slot := _HotbarSlot.new(int(d["index"]), String(d["title"]), d["color"] as Color, _use_slot)
		hbox.add_child(slot)
		_slots.append(slot)


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


func _refresh() -> void:
	_gold_label.text = "Gold  %d    Mod Parts  %d" % [GameState.gold, GameState.mod_parts]
	var base: Dictionary = GameState.base_spell_stats()
	var dmg: float = float(base["damage"]) * GameState.damage_boost_multiplier()
	var extra: String = ""
	if not GameState.boss_spells.is_empty():
		extra = "  +%d boss spell(s)" % GameState.boss_spells.size()
	var mode_tag: String = " [Auto]" if GameState.auto_shoot_unlocked else " [Click]"
	_spell_label.text = "Spell Lv %d  (%.1f dmg, %.1f/s)%s%s" % [
		GameState.spell_level, dmg, float(base["fire_rate"]), extra, mode_tag]
	if GameState.mega_boss_spawned:
		_objective_label.text = "Nests  4/4    Mega Boss  ACTIVE"
	else:
		_objective_label.text = "Nests  %d/4    Bosses  %d/4" % [GameState.nests_destroyed, GameState.bosses_defeated]
	for s in _slots:
		s.queue_redraw()


func _label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)
	return l


## Circular Minecraft-style hotbar slot at the bottom of the screen.
class _HotbarSlot extends Control:
	var slot_index: int = 0
	var title: String = ""
	var tint: Color = Color.WHITE
	var on_click: Callable
	var _hovered: bool = false

	func _init(idx: int, label_text: String, col: Color, callback: Callable) -> void:
		slot_index = idx
		title = label_text
		tint = col
		on_click = callback
		custom_minimum_size = Vector2(84, 88)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hovered = true
			queue_redraw()
		)
		mouse_exited.connect(func() -> void:
			_hovered = false
			queue_redraw()
		)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				on_click.call(slot_index)
				accept_event()

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, 34.0)
		var r: float = 28.0
		var count: int = 0
		var active_timer: float = 0.0
		match slot_index:
			0:
				count = GameState.shield_items
			1:
				count = GameState.heal_potions
				active_timer = GameState.heal_potion_timer
			2:
				count = GameState.damage_potions
				active_timer = GameState.damage_boost_timer

		# Outer slot circle
		var bg_col := Color(0.14, 0.16, 0.22, 0.92) if not _hovered else Color(0.22, 0.25, 0.34, 0.96)
		draw_circle(center, r, bg_col)
		var ring_col: Color = tint if (count > 0 or active_timer > 0.0) else Color(0.45, 0.48, 0.55, 0.7)
		draw_arc(center, r, 0.0, TAU, 36, ring_col, 3.0 if active_timer > 0.0 else 2.0)

		# Active 30s radial arc when potion effect is running
		if active_timer > 0.0:
			var ratio: float = clampf(active_timer / Config.POTION_DURATION_SEC, 0.0, 1.0)
			draw_arc(center, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, Color(1.0, 0.95, 0.35), 3.0)

		# Item icon inside circle
		var icon_alpha: float = 1.0 if (count > 0 or active_timer > 0.0) else 0.35
		var ic := Color(tint.r, tint.g, tint.b, icon_alpha)
		if slot_index == 0:
			# Shield emblem
			var pts := PackedVector2Array([
				center + Vector2(0, -14),
				center + Vector2(12, -8),
				center + Vector2(10, 6),
				center + Vector2(0, 15),
				center + Vector2(-10, 6),
				center + Vector2(-12, -8),
			])
			draw_colored_polygon(pts, ic)
		else:
			# Potion bottle
			draw_circle(center + Vector2(0, 4), 11.0, ic)
			draw_rect(Rect2(center + Vector2(-4, -13), Vector2(8, 8)), ic.lightened(0.25))
			draw_rect(Rect2(center + Vector2(-6, -15), Vector2(12, 3)), Color(0.85, 0.75, 0.55, icon_alpha))

		var font: Font = ThemeDB.fallback_font
		# Count badge
		draw_string(font, center + Vector2(10, 18), "×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		# Active timer countdown
		if active_timer > 0.0:
			draw_string(font, center + Vector2(-14, 5), "%ds" % ceili(active_timer), HORIZONTAL_ALIGNMENT_CENTER, 28, 13, Color(1, 1, 0.4))
		# Label under circle
		draw_string(font, Vector2(0, 78), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.88, 0.9, 0.95))
