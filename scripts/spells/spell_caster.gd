extends Node2D
## Left-click fires the selected spell toward the cursor, and holding E fires every spell the player
## has. Either respects the fire rate and mana. A Doppelganger shoots at the same point.
## Once Homing is unlocked in the Gold Shop (1500 gold), fired projectiles home toward the closest enemy.

const VOLLEY_SPACING_PX: float = 7.0

var _cooldown: float = 0.0


func _progress() -> RunState:
	var player: Player = get_parent() as Player
	return player.progress if player != null and player.progress != null else GameState


func _physics_process(delta: float) -> void:
	var owner_player := get_parent() as Player
	if owner_player != null and owner_player.is_dead():
		return
	if _progress().coop_mode and (_progress().castle_menu_open or _progress().pause_menu_open):
		return

	_cooldown = maxf(0.0, _cooldown - delta)

	var fire_one: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null
	var fire_all: bool = Input.is_physical_key_pressed(KEY_E)
	var mouse_world: Vector2 = get_global_mouse_position()
	if owner_player != null and not owner_player.accepts_local_input:
		fire_one = owner_player.remote_fire_pressed
		fire_all = owner_player.remote_fire_all
		mouse_world = owner_player.remote_aim_position

	if _cooldown > 0.0 or not (fire_one or fire_all):
		return
	var spell: Dictionary = _progress().selected_spell()
	var aim: Vector2 = _aim_toward(mouse_world)
	var fired: bool = _fire_all(_progress().all_spells(), aim) if fire_all else _fire_one(spell, aim)
	if not fired:
		return
	_cooldown = 1.0 / maxf(0.05, float(spell["fire_rate"]))
	for node: Node in get_tree().get_nodes_in_group("doppelgangers"):
		if node.get("progress") == _progress():
			(node as Doppelganger).mirror_shot(int(spell["effect"]), fire_all, mouse_world)


func _aim_toward(point: Vector2) -> Vector2:
	var dir: Vector2 = global_position.direction_to(point)
	return dir if dir != Vector2.ZERO else Vector2.RIGHT


## Fires the base spell, and every other spell with it while the mana lasts.
## Returns false if there wasn't enough mana for the base spell, which then fires nothing.
func _fire_all(spells: Array[Dictionary], dir: Vector2) -> bool:
	var fired: bool = false
	for i in spells.size():
		var spell: Dictionary = spells[i]
		if not _progress().try_spend_mana(float(spell.get("mana_cost", Config.BASE_SPELL_MANA_COST))):
			if i == 0:
				return false
			continue
		# Side by side, so a volley doesn't look like one shot.
		var side: float = float((i + 1) / 2) * (1.0 if i % 2 == 1 else -1.0)
		_fire_dir(spell, dir, Config.tiles(float(spell["range_tiles"])), dir.orthogonal() * side * VOLLEY_SPACING_PX)
		fired = true
	return fired


func _fire_one(spell: Dictionary, dir: Vector2) -> bool:
	if not _progress().try_spend_mana(float(spell.get("mana_cost", Config.BASE_SPELL_MANA_COST))):
		return false
	_fire_dir(spell, dir, Config.tiles(float(spell["range_tiles"])))
	return true


func _fire_dir(spell: Dictionary, dir: Vector2, max_range: float, offset: Vector2 = Vector2.ZERO) -> void:
	var p: Projectile = Config.projectile_scene().instantiate()
	p.source_state = _progress()
	var dmg: float = float(spell["damage"]) * _progress().damage_boost_multiplier()
	p.effect = int(spell.get("effect", SpellData.Effect.NONE)) as SpellData.Effect
	var can_use_aug: bool = bool(spell.get("uses_augments", true))
	var aug_snap: Dictionary = spell.get("aug_levels", {}) as Dictionary
	p.setup(
		dir,
		Config.tiles(float(spell["speed_tiles"])),
		dmg,
		true,
		spell["color"] as Color,
		Config.tiles(float(spell["radius_tiles"])),
		max_range,
		_progress().is_homing_active() and bool(spell.get("can_home", true)),
		Projectile.ProjKind.INITIAL,
		null,
		can_use_aug,
		aug_snap
	)
	var owner_player := get_parent() as Player
	p.global_position = (owner_player.get_wand_tip_global(dir) if owner_player != null else global_position) + offset
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(p)
	AudioManager.play_cast(spell, p.global_position)
