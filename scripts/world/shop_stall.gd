class_name ShopStall
extends Area2D
## One stall in a shop row (§6.3). Walking in heals the player and opens that part of the shop.

signal entered(player: Player, section: Section)

enum Section {
	SPELL,
	MODS,
	AUGMENTATIONS,
	PERSONAL,
	GOLD,
}

const NAMES: Dictionary = {
	Section.SPELL: "Spell",
	Section.MODS: "Spell Mods",
	Section.AUGMENTATIONS: "Augmentations",
	Section.PERSONAL: "Personal",
	Section.GOLD: "Gold",
}
const TEXTURES: Dictionary = {
	Section.SPELL: "res://assets/sprites/world/stall_spell.png",
	Section.MODS: "res://assets/sprites/world/stall_mods.png",
	Section.AUGMENTATIONS: "res://assets/sprites/world/stall_augmentations.png",
	Section.PERSONAL: "res://assets/sprites/world/stall_personal.png",
	Section.GOLD: "res://assets/sprites/world/stall_gold.png",
}

var section: Section = Section.SPELL


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.tiles(Config.SHOP_STALL_RADIUS_TILES)
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player and not (body as Player).is_dead():
		entered.emit(body as Player, section)


func _draw() -> void:
	Config.draw_ground_shadow(self, 28.0, 12.0, 0.34)
	var tex: Texture2D = Config.get_tex(TEXTURES[section])
	if tex == null:
		return
	draw_texture(tex, Vector2(-tex.get_width() * 0.5, -tex.get_height() + 20.0))
	var font: Font = ThemeDB.fallback_font
	var top := Vector2(-48.0, -tex.get_height() + 14.0)
	draw_string_outline(font, top, NAMES[section], HORIZONTAL_ALIGNMENT_CENTER, 96.0, 11, 4, Color(0, 0, 0, 0.9))
	draw_string(font, top, NAMES[section], HORIZONTAL_ALIGNMENT_CENTER, 96.0, 11, Color(1.0, 0.92, 0.6))
