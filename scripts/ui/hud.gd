class_name HUD
extends CanvasLayer
## In-game HUD: HP, gold, spell level, objectives, pending mods, and the mobile joystick.

const JoystickScene: PackedScene = preload("res://scenes/ui/VirtualJoystick.tscn")

var _hp_bar: ProgressBar
var _hp_label: Label
var _gold_label: Label
var _spell_label: Label
var _objective_label: Label
var _hint_label: Label
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 10

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	_hp_label = _label(box, "HP")
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(220, 14)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.25)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_hp_bar)
	_gold_label = _label(box, "")
	_spell_label = _label(box, "")
	_objective_label = _label(box, "")

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.position = Vector2(-300, 16)
	_hint_label.custom_minimum_size = Vector2(600, 0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 6)
	add_child(_hint_label)

	add_child(JoystickScene.instantiate())

	GameState.gold_changed.connect(func(_g: int) -> void: _refresh())
	GameState.spell_level_changed.connect(func(_l: int) -> void: _refresh())
	GameState.mods_changed.connect(_refresh)
	GameState.objectives_changed.connect(_refresh)
	_refresh()


func bind_player(player: Player) -> void:
	player.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(player.hp, player.max_hp)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < Config.NEST_SPAWN_DELAY_SEC:
		_hint_label.text = "Monsters awaken in %d…" % ceili(Config.NEST_SPAWN_DELAY_SEC - _elapsed)
	elif not GameState.pending_mods.is_empty():
		_hint_label.text = "You found a spell mod! Return to the castle to apply it."
	else:
		_hint_label.text = ""


func _on_hp_changed(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "HP  %d / %d" % [hp, max_hp]


func _refresh() -> void:
	_gold_label.text = "Gold  %d" % GameState.gold
	var mods: String = ""
	if not GameState.active_mods.is_empty():
		mods = "  +%d mod(s)" % GameState.active_mods.size()
	_spell_label.text = "Spell  Lv %d  (%d dmg)%s" % [GameState.spell_level, Config.spell_damage(GameState.spell_level), mods]
	_objective_label.text = "Nests  %d/4    Bosses  %d/4" % [GameState.nests_destroyed, GameState.bosses_defeated]


func _label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)
	return l
