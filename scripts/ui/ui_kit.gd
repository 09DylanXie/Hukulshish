class_name UIKit
extends RefCounted
## Small helpers for building the prototype's menus in code (no art yet).


## Full-screen key-art background + a centered VBox. Returns the VBox to add widgets to.
static func make_centered_menu(parent: Control, title: String, subtitle: String = "") -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var bg_tex: Texture2D = Config.get_tex("res://assets/sprites/ui/menu_background.png")
	if bg_tex != null:
		var art := TextureRect.new()
		art.texture = bg_tex
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(art)

		var dim := ColorRect.new()
		dim.color = Color(0.03, 0.02, 0.07, 0.46)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(440, 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(box)

	box.add_child(make_label(title, 58, Color(0.98, 0.84, 0.35)))
	if subtitle != "":
		box.add_child(make_label(subtitle, 22, Color(0.84, 0.9, 0.96)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	return box


static func make_label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func make_button(text: String, on_pressed: Callable, size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", size)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.14, 0.2, 0.95)
	normal.border_color = Color(0.32, 0.34, 0.45, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(10)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.24, 0.24, 0.36, 1.0)
	hover.border_color = Color(0.95, 0.82, 0.35, 1.0)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(10)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.32, 0.3, 0.46, 1.0)
	pressed.border_color = Color(1.0, 0.9, 0.5, 1.0)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(10)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.1, 0.1, 0.14, 0.6)
	disabled.border_color = Color(0.22, 0.22, 0.28, 0.5)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(6)
	disabled.set_content_margin_all(10)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(on_pressed)
	return b
