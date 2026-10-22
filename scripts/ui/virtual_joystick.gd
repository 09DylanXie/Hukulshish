extends Control
## On-screen joystick for mobile browsers (§4). Only shown on touch devices.
## Drives the same Input Map actions as WASD, so the player script doesn't know it exists.
## Touch anywhere on the left half of the screen to place it.

const RADIUS: float = 70.0
const KNOB_RADIUS: float = 30.0

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios")
	set_process_input(visible)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and touch.position.x < get_viewport_rect().size.x * 0.5:
			_touch_index = touch.index
			_origin = touch.position
			_knob = _origin
			queue_redraw()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_apply(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			var offset: Vector2 = (drag.position - _origin).limit_length(RADIUS)
			_knob = _origin + offset
			_apply(offset / RADIUS)
			queue_redraw()


func _notification(what: int) -> void:
	# Release actions if the game pauses mid-drag (e.g. castle menu opens).
	if what == NOTIFICATION_PAUSED and _touch_index != -1:
		_touch_index = -1
		_apply(Vector2.ZERO)
		queue_redraw()


func _apply(v: Vector2) -> void:
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_up", "move_down", v.y)


func _set_axis(neg: String, pos: String, value: float) -> void:
	if value < 0.0:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > 0.0:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _draw() -> void:
	if _touch_index == -1:
		# Idle hint in the bottom-left corner.
		var idle: Vector2 = Vector2(RADIUS + 40, get_viewport_rect().size.y - RADIUS - 40)
		draw_circle(idle, RADIUS, Color(1, 1, 1, 0.08))
		draw_circle(idle, KNOB_RADIUS, Color(1, 1, 1, 0.18))
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.15))
	draw_arc(_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)
	draw_circle(_knob, KNOB_RADIUS, Color(1, 1, 1, 0.45))

