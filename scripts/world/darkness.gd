class_name Darkness
extends Node2D
## The Catacombs' darkness (§6.6). Blacks out the world beyond a shrunken circle around the player.
## It sits above characters and below the HUD, so enemies outside the circle can't be seen.

const COVER_MARGIN_PX: float = 4000.0
const SHADER_CODE: String = """
shader_type canvas_item;
uniform vec2 center;
uniform float radius;
uniform float softness;
varying vec2 world_position;

void vertex() {
	world_position = VERTEX;
}

void fragment() {
	float distance_out = distance(world_position, center);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius - softness, radius, distance_out));
}
"""

## The player the circle follows.
var target: Node2D
## The area to cover, in world px.
var bounds: Rect2 = Rect2()

var _material: ShaderMaterial


func _ready() -> void:
	z_as_relative = false
	z_index = Config.DARKNESS_Z_INDEX
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("radius", Config.tiles(Config.DARKNESS_RADIUS_TILES))
	_material.set_shader_parameter("softness", Config.tiles(Config.DARKNESS_SOFTNESS_TILES))
	material = _material


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		_material.set_shader_parameter("center", target.global_position)


func _draw() -> void:
	draw_rect(bounds.grow(COVER_MARGIN_PX), Color.WHITE)
