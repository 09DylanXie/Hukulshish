class_name UIKit
extends RefCounted
## Small helpers for building the prototype's menus in code (no art yet).


## Full-screen dark background + a centered VBox. Returns the VBox to add widgets to.
static func make_centered_menu(parent: Control, title: String, subtitle: String = "") -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)

	box.add_child(make_label(title, 56, Color(0.95, 0.8, 0.3)))
	if subtitle != "":
		box.add_child(make_label(subtitle, 22, Color(0.8, 0.8, 0.9)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)
	return box


static func make_label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func make_button(text: String, on_pressed: Callable, size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_pressed)
	return b
