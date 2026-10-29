class_name CastleMenu
extends CanvasLayer
## Castle upgrade & shop menu (§5, §6.2–6.3). Pauses the game while open.
## Left column: Base Spell upgrade, Spell Mods (Spell Scrolls), and Augmentations (Augmentation Scrolls).
## Middle column: Personal Shop (Enhancers dropped by Goblins at 1/3 rate).
## Right column: Gold Shop and Boss Spells.

var _root: Control
var _resources_label: Label
var _upgrade_button: Button
var _mods_box: VBoxContainer
var _augs_box: VBoxContainer
var _personal_box: VBoxContainer
var _spells_box: VBoxContainer
var _gold_shop_box: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	GameState.changed.connect(_refresh)


func open() -> void:
	if GameState.run_over:
		return
	_refresh()
	_root.show()
	get_tree().paused = true


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
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1620, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	outer.add_child(UIKit.make_label("Kingdom Castle", 34, Color(0.95, 0.8, 0.3)))
	outer.add_child(UIKit.make_label("Restored HP up to %d HP" % Config.CASTLE_HEAL_MAX_HP, 15, Color(0.55, 0.9, 0.65)))
	_resources_label = UIKit.make_label("", 20)
	outer.add_child(_resources_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	outer.add_child(columns)

	# Left column: Base spell + Spell Mods + Augmentations
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	columns.add_child(left_col)

	_upgrade_button = UIKit.make_button("", _on_upgrade_pressed, 16)
	_upgrade_button.custom_minimum_size = Vector2(0, 42)
	left_col.add_child(_upgrade_button)

	left_col.add_child(UIKit.make_label("Spell Mods", 22, Color(0.45, 0.85, 1.0)))
	_mods_box = VBoxContainer.new()
	_mods_box.add_theme_constant_override("separation", 6)
	left_col.add_child(_mods_box)

	left_col.add_child(UIKit.make_label("Augmentations (Demon Drops)", 22, Color(1.0, 0.38, 0.52)))
	_augs_box = VBoxContainer.new()
	_augs_box.add_theme_constant_override("separation", 6)
	left_col.add_child(_augs_box)

	# Middle column: Personal Shop (Goblin & Undead Enhancers)
	var mid_col := VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.add_theme_constant_override("separation", 8)
	columns.add_child(mid_col)

	mid_col.add_child(UIKit.make_label("Personal Shop (Goblin & Undead Enhancers)", 22, Color(0.35, 0.95, 0.55)))
	_personal_box = VBoxContainer.new()
	_personal_box.add_theme_constant_override("separation", 6)
	mid_col.add_child(_personal_box)

	# Right column: Gold Shop + Boss Spells
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	columns.add_child(right_col)

	right_col.add_child(UIKit.make_label("Gold Shop", 22, Color(1.0, 0.85, 0.25)))
	_gold_shop_box = VBoxContainer.new()
	_gold_shop_box.add_theme_constant_override("separation", 6)
	right_col.add_child(_gold_shop_box)

	right_col.add_child(UIKit.make_label("Boss Spells", 22, Color(1.0, 0.65, 0.25)))
	_spells_box = VBoxContainer.new()
	_spells_box.add_theme_constant_override("separation", 4)
	right_col.add_child(_spells_box)

	outer.add_child(UIKit.make_button("Leave Castle", close, 19))


func _refresh() -> void:
	if _root == null:
		return
	if GameState.sandbox_mode:
		_resources_label.text = "SANDBOX MODE — Gold: ∞      Spell Scrolls: ∞      Augmentation Scrolls: ∞      Enhancers: ∞"
	else:
		_resources_label.text = "Gold: %d      Spell Scrolls: %d      Augmentation Scrolls: %d      Enhancers: %d" % [
			GameState.gold, GameState.mod_parts, GameState.aug_scrolls, GameState.enhancers]

	var lvl: int = GameState.spell_level
	if GameState.is_spell_maxed():
		_upgrade_button.text = "Base Spell Lv %d (%d base dmg) — MAX" % [lvl, Config.spell_damage(lvl)]
		_upgrade_button.disabled = true
	else:
		var cost: int = GameState.next_upgrade_cost()
		_upgrade_button.text = "Upgrade Base Spell  Lv %d → %d  (%d → %d base dmg)  —  %d gold" % [
			lvl, lvl + 1, Config.spell_damage(lvl), Config.spell_damage(lvl + 1), cost]
		_upgrade_button.disabled = GameState.gold < cost

	# Populate Spell Mods (Spell Scrolls)
	for c in _mods_box.get_children():
		c.queue_free()
	for id in ["damage", "mana_regen", "mana_pool", "range"]:
		var mod_lvl: int = int(GameState.mod_levels.get(id, 0))
		var cost: int = GameState.next_mod_cost(id)
		var scroll_word: String = "scroll" if cost == 1 else "scrolls"
		var text: String = ""
		var maxed: bool = GameState.is_mod_maxed(id)
		match id:
			"damage":
				var cur_m: float = GameState.mod_multiplier("damage")
				text = "Damage  Lv %d (×%.1f → ×%.1f)  —  %d %s" % [mod_lvl, cur_m, cur_m + Config.MOD_STEP, cost, scroll_word]
			"mana_regen":
				var cur_r: float = GameState.mana_regen()
				text = "Mana Regen  Lv %d (%.1f/s → %.1f/s)  —  %d %s" % [mod_lvl, cur_r, cur_r + Config.MANA_REGEN_STEP, cost, scroll_word]
			"mana_pool":
				var cur_p: int = GameState.max_mana()
				if maxed:
					text = "Mana Pool  Lv %d (%d max mana) — MAX" % [mod_lvl, cur_p]
				else:
					var next_p: int = Config.max_mana_for_level(mod_lvl + 1)
					text = "Mana Pool  Lv %d (%d → %d max mana)  —  %d %s" % [mod_lvl, cur_p, next_p, cost, scroll_word]
			"range":
				var cur_rng: float = GameState.mod_multiplier("range")
				text = "Range  Lv %d (×%.1f → ×%.1f)  —  %d %s" % [mod_lvl, cur_rng, cur_rng + Config.MOD_STEP, cost, scroll_word]
		var btn: Button = UIKit.make_button(text, _on_buy_mod.bind(id), 16)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.disabled = maxed or GameState.mod_parts < cost
		_mods_box.add_child(btn)

	# Populate Augmentations (Augmentation Scrolls: max 3, costs 1, 2, 3)
	for c in _augs_box.get_children():
		c.queue_free()
	for id in ["split", "bomb", "sniper"]:
		var aug_lvl: int = GameState.aug_level(id)
		var maxed: bool = GameState.is_aug_maxed(id)
		var cost: int = GameState.next_aug_cost(id)
		var scroll_word: String = "aug scroll" if cost == 1 else "aug scrolls"
		var text: String = ""
		match id:
			"split":
				if maxed:
					text = "Split Spell  Lv 3 (re-splits 3× @ 45°, Chain Lightning) — MAX"
				elif aug_lvl == 0:
					text = "Split Spell  Lv 0 → 1 (splits into 2 @ 45°, ½ dmg)  —  %d %s" % [cost, scroll_word]
				elif aug_lvl == 1:
					text = "Split Spell  Lv 1 → 2 (splits re-split again, 2× chain)  —  %d %s" % [cost, scroll_word]
				else:
					text = "Split Spell  Lv 2 → 3 (re-splits 3× + Chain Lightning)  —  %d %s" % [cost, scroll_word]
			"bomb":
				var next_dps: int = int(Config.BOMB_BASE_DPS + Config.BOMB_DPS_STEP * aug_lvl)
				if maxed:
					text = "Bombspell  Lv 3 (7 dmg/s, all hits + range end) — MAX"
				elif aug_lvl == 0:
					text = "Bombspell  Lv 0 → 1 (3 dmg/s fire, 3s)  —  %d %s" % [cost, scroll_word]
				elif aug_lvl == 2:
					text = "Bombspell  Lv 2 → 3 (7 dmg/s + all hits & max range)  —  %d %s" % [cost, scroll_word]
				else:
					var cur_dps: int = int(GameState.bomb_dps())
					text = "Bombspell  Lv %d → %d (%d → %d dmg/s fire)  —  %d %s" % [aug_lvl, aug_lvl + 1, cur_dps, next_dps, cost, scroll_word]
			"sniper":
				var next_mult: int = int(Config.SNIPER_BASE_DAMAGE_MULT + Config.SNIPER_DAMAGE_STEP * aug_lvl)
				if maxed:
					text = "Sniper  Lv 3 (5× spd, 4× dmg + Bomb Explosion) — MAX"
				elif aug_lvl == 0:
					text = "Sniper  Lv 0 → 1 (5× spd vs enemies, 2× dmg)  —  %d %s" % [cost, scroll_word]
				elif aug_lvl == 2:
					text = "Sniper  Lv 2 → 3 (4× dmg + Bomb Explosion on hit)  —  %d %s" % [cost, scroll_word]
				else:
					var cur_mult: int = int(GameState.sniper_damage_mult())
					text = "Sniper  Lv %d → %d (%d× → %d× dmg)  —  %d %s" % [aug_lvl, aug_lvl + 1, cur_mult, next_mult, cost, scroll_word]
		var btn: Button = UIKit.make_button(text, _on_buy_aug.bind(id), 16)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.disabled = maxed or GameState.aug_scrolls < cost
		_augs_box.add_child(btn)

	# Populate Personal Shop (Goblin & Undead Enhancers: max 3, costs 3, 5, 9)
	for c in _personal_box.get_children():
		c.queue_free()
	for id in ["luck", "move_speed", "health_regen", "mine_capacity", "mine_rate", "income"]:
		var p_lvl: int = GameState.personal_level(id)
		var maxed: bool = GameState.is_personal_maxed(id)
		var cost: int = GameState.next_personal_cost(id)
		var text: String = ""
		match id:
			"luck":
				var cur_pct: int = p_lvl * 20
				var next_pct: int = (p_lvl + 1) * 20
				if maxed:
					text = "Luck  Lv 3 (+60% drop rate) — MAX"
				else:
					text = "Luck  Lv %d → %d (+%d%% → +%d%% drop rate)  —  %d enhancers" % [p_lvl, p_lvl + 1, cur_pct, next_pct, cost]
			"move_speed":
				var cur_pct: int = p_lvl * 5
				var next_pct: int = (p_lvl + 1) * 5
				if maxed:
					text = "Movement Speed  Lv 3 (+15% move speed) — MAX"
				else:
					text = "Movement Speed  Lv %d → %d (+%d%% → +%d%% speed)  —  %d enhancers" % [p_lvl, p_lvl + 1, cur_pct, next_pct, cost]
			"health_regen":
				if maxed:
					text = "Health Regen  Lv 3 (+3 HP / 10s) — MAX"
				else:
					text = "Health Regen  Lv %d → %d (+%d → +%d HP/10s)  —  %d enhancers" % [p_lvl, p_lvl + 1, p_lvl, p_lvl + 1, cost]
			"mine_capacity":
				var cur_cap: int = GameState.gold_mine_cap()
				var next_cap: int = int(round(float(Config.GOLD_MINE_CAP) * (1.0 + Config.MINE_CAPACITY_STEP * (p_lvl + 1))))
				if maxed:
					text = "Capacity  Lv 3 (%d mine cap, +3/3) — MAX" % cur_cap
				else:
					text = "Capacity  Lv %d → %d (+%d/3 → +%d/3 mine cap)  —  %d enhancers" % [p_lvl, p_lvl + 1, p_lvl, p_lvl + 1, cost]
			"mine_rate":
				var cur_pct: int = p_lvl * 15
				var next_pct: int = (p_lvl + 1) * 15
				if maxed:
					text = "Rate  Lv 3 (+45% mine gold/s) — MAX"
				else:
					text = "Rate  Lv %d → %d (+%d%% → +%d%% mine gold/s)  —  %d enhancers" % [p_lvl, p_lvl + 1, cur_pct, next_pct, cost]
			"income":
				var cur_pct: int = p_lvl * 50
				var next_pct: int = (p_lvl + 1) * 50
				if maxed:
					text = "Income Multiplier  Lv 3 (+150% enemy gold) — MAX"
				else:
					text = "Income Multiplier  Lv %d → %d (+%d%% → +%d%% enemy gold)  —  %d enhancers" % [p_lvl, p_lvl + 1, cur_pct, next_pct, cost]
		var btn: Button = UIKit.make_button(text, _on_buy_personal.bind(id), 15)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.disabled = maxed or GameState.enhancers < cost
		_personal_box.add_child(btn)

	# Populate Boss Spells
	for c in _spells_box.get_children():
		c.queue_free()
	if GameState.boss_spells.is_empty():
		_spells_box.add_child(UIKit.make_label(
			"None yet — bosses have a 1/3 chance to drop a new spell (costs %d mana)." % int(Config.BOSS_SPELL_MANA_COST),
			15, Color(0.7, 0.7, 0.75)))
	else:
		for s in GameState.boss_spells:
			var info: String = "★ %s — %.1f dmg, %.2f/s, %d mana (frozen)" % [
				s["name"], float(s["damage"]), float(s["fire_rate"]), int(s.get("mana_cost", Config.BOSS_SPELL_MANA_COST))]
			_spells_box.add_child(UIKit.make_label(info, 15, s["color"] as Color))

	# Populate Gold Shop
	for c in _gold_shop_box.get_children():
		c.queue_free()

	# 0. Max HP Upgrade (5 → 6 → 7 → 10; +1, +1, +3 on final upgrade; does not instantly heal)
	if GameState.is_max_hp_maxed():
		var mhp_done: Button = UIKit.make_button("Max HP (%d) — MAX" % GameState.player_max_hp(), func() -> void: pass, 16)
		mhp_done.custom_minimum_size = Vector2(0, 38)
		mhp_done.disabled = true
		_gold_shop_box.add_child(mhp_done)
	else:
		var cur_mhp: int = GameState.player_max_hp()
		var next_mhp: int = Config.player_max_hp_for_level(GameState.max_hp_level + 1)
		var mhp_cost: int = GameState.next_gold_max_hp_cost()
		var mhp_btn: Button = UIKit.make_button(
			"Max HP +%d (%d → %d Max HP)  —  %d gold" % [next_mhp - cur_mhp, cur_mhp, next_mhp, mhp_cost],
			func() -> void: GameState.try_buy_max_hp_gold(), 16)
		mhp_btn.custom_minimum_size = Vector2(0, 38)
		mhp_btn.disabled = GameState.gold < mhp_cost
		_gold_shop_box.add_child(mhp_btn)

	# 1. Spell Scroll (100 gold first, +100 each up to 10)
	var bought: int = GameState.mod_parts_bought_with_gold
	if GameState.can_buy_gold_mod_part():
		var mp_cost: int = GameState.next_gold_mod_part_cost()
		var mp_btn: Button = UIKit.make_button(
			"Spell Scroll (%d/%d)  —  %d gold" % [bought, Config.GOLD_SHOP_MOD_PART_MAX, mp_cost],
			func() -> void: GameState.try_buy_gold_mod_part(), 16)
		mp_btn.custom_minimum_size = Vector2(0, 38)
		mp_btn.disabled = GameState.gold < mp_cost
		_gold_shop_box.add_child(mp_btn)
	else:
		var mp_done: Button = UIKit.make_button("Spell Scroll (%d/%d) — SOLD OUT" % [bought, Config.GOLD_SHOP_MOD_PART_MAX], func() -> void: pass, 16)
		mp_done.custom_minimum_size = Vector2(0, 38)
		mp_done.disabled = true
		_gold_shop_box.add_child(mp_done)

	# 2. Magnet (300 gold)
	if GameState.magnet_unlocked:
		var mag_done: Button = UIKit.make_button("Magnet — UNLOCKED", func() -> void: pass, 16)
		mag_done.custom_minimum_size = Vector2(0, 35)
		mag_done.disabled = true
		_gold_shop_box.add_child(mag_done)
	else:
		var mag_btn: Button = UIKit.make_button(
			"Magnet (pulls dropped scrolls)  —  %d gold" % Config.GOLD_SHOP_MAGNET_COST,
			func() -> void: GameState.try_buy_magnet(), 16)
		mag_btn.custom_minimum_size = Vector2(0, 35)
		mag_btn.disabled = GameState.gold < Config.GOLD_SHOP_MAGNET_COST
		_gold_shop_box.add_child(mag_btn)

	# 2b. Auto Gold Collector (500 gold; collects all gold mines every 30s)
	if GameState.auto_collector_unlocked:
		var col_done: Button = UIKit.make_button("Auto Gold Collector (every 30s) — UNLOCKED", func() -> void: pass, 16)
		col_done.custom_minimum_size = Vector2(0, 35)
		col_done.disabled = true
		_gold_shop_box.add_child(col_done)
	else:
		var col_btn: Button = UIKit.make_button(
			"Auto Gold Collector (mines every 30s)  —  %d gold" % Config.GOLD_SHOP_AUTO_COLLECTOR_COST,
			func() -> void: GameState.try_buy_auto_collector(), 16)
		col_btn.custom_minimum_size = Vector2(0, 35)
		col_btn.disabled = GameState.gold < Config.GOLD_SHOP_AUTO_COLLECTOR_COST
		_gold_shop_box.add_child(col_btn)

	# 3. Temporary Magic Shield (+1 Shield, 200 gold)
	var sh_btn: Button = UIKit.make_button(
		"Magic Shield (+1 Shield) [Owned: %d]  —  %d gold" % [GameState.shield_items, Config.GOLD_SHOP_SHIELD_COST],
		func() -> void: GameState.try_buy_shield_item(), 16)
	sh_btn.custom_minimum_size = Vector2(0, 38)
	sh_btn.disabled = GameState.gold < Config.GOLD_SHOP_SHIELD_COST
	_gold_shop_box.add_child(sh_btn)

	# 4. 3 HP Healing Potion (100 gold)
	var hp_btn: Button = UIKit.make_button(
		"3 HP Healing Potion [Owned: %d]  —  %d gold" % [GameState.heal_potions, Config.GOLD_SHOP_POTION_COST],
		func() -> void: GameState.try_buy_heal_potion(), 16)
	hp_btn.custom_minimum_size = Vector2(0, 38)
	hp_btn.disabled = GameState.gold < Config.GOLD_SHOP_POTION_COST
	_gold_shop_box.add_child(hp_btn)

	# 5. 2× Damage Boost Potion (30s, 100 gold)
	var dmg_btn: Button = UIKit.make_button(
		"2× Damage Boost Potion (30s) [Owned: %d]  —  %d gold" % [GameState.damage_potions, Config.GOLD_SHOP_POTION_COST],
		func() -> void: GameState.try_buy_damage_potion(), 16)
	dmg_btn.custom_minimum_size = Vector2(0, 38)
	dmg_btn.disabled = GameState.gold < Config.GOLD_SHOP_POTION_COST
	_gold_shop_box.add_child(dmg_btn)

	# 6. Auto-Shooting Unlock (1000 gold; toggle with E)
	if GameState.auto_shoot_unlocked:
		var auto_done: Button = UIKit.make_button("Auto-Shooting — UNLOCKED (Press E to toggle)", func() -> void: pass, 16)
		auto_done.custom_minimum_size = Vector2(0, 38)
		auto_done.disabled = true
		_gold_shop_box.add_child(auto_done)
	else:
		var auto_btn: Button = UIKit.make_button(
			"Unlock Auto-Shooting (toggle with E)  —  %d gold" % Config.GOLD_SHOP_AUTO_SHOOT_COST,
			func() -> void: GameState.try_buy_auto_shoot(), 16)
		auto_btn.custom_minimum_size = Vector2(0, 38)
		auto_btn.disabled = GameState.gold < Config.GOLD_SHOP_AUTO_SHOOT_COST
		_gold_shop_box.add_child(auto_btn)

	# 7. Homing Unlock (1500 gold; toggle with F)
	if GameState.homing_unlocked:
		var homing_done: Button = UIKit.make_button("Homing — UNLOCKED (Press F to toggle)", func() -> void: pass, 16)
		homing_done.custom_minimum_size = Vector2(0, 38)
		homing_done.disabled = true
		_gold_shop_box.add_child(homing_done)
	else:
		var homing_btn: Button = UIKit.make_button(
			"Unlock Homing (toggle with F)  —  %d gold" % Config.GOLD_SHOP_HOMING_COST,
			func() -> void: GameState.try_buy_homing(), 16)
		homing_btn.custom_minimum_size = Vector2(0, 38)
		homing_btn.disabled = GameState.gold < Config.GOLD_SHOP_HOMING_COST
		_gold_shop_box.add_child(homing_btn)

	# 8. Doppelganger (5000 gold; 5 HP, no shield, copies current abilities and follows player until death)
	if GameState.doppelganger_alive:
		var dop_done: Button = UIKit.make_button("Doppelganger (5 HP) — ACTIVE", func() -> void: pass, 16)
		dop_done.custom_minimum_size = Vector2(0, 38)
		dop_done.disabled = true
		_gold_shop_box.add_child(dop_done)
	else:
		var dop_btn: Button = UIKit.make_button(
			"Doppelganger (5 HP, copies abilities)  —  %d gold" % Config.GOLD_SHOP_DOPPELGANGER_COST,
			func() -> void: GameState.try_buy_doppelganger(), 16)
		dop_btn.custom_minimum_size = Vector2(0, 38)
		dop_btn.disabled = GameState.gold < Config.GOLD_SHOP_DOPPELGANGER_COST
		_gold_shop_box.add_child(dop_btn)


func _on_upgrade_pressed() -> void:
	GameState.try_upgrade_spell()


func _on_buy_mod(id: String) -> void:
	GameState.try_buy_mod(id)


func _on_buy_aug(id: String) -> void:
	GameState.try_buy_aug(id)


func _on_buy_personal(id: String) -> void:
	GameState.try_buy_personal(id)
