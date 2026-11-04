## Здобич на землі: гривні, зілля або річ. Підбирається, коли підійти, або дотиком (тоді летить до героя).
class_name LootDrop
extends Node3D

const PICKUP_RADIUS := 1.5
const MAGNET_RADIUS := 3.2
const LIFETIME := 180.0
const KIND_GOLD := "gold"
const KIND_HP := "hp"
const KIND_MANA := "mana"
const KIND_ITEM := "item"

var kind := KIND_GOLD
var amount := 1
var item: Dictionary = {}
var attract := false          # летить до героя (після дотику)
var _age := 0.0
var _player: Player = null
var _visual: Node3D
var _spawn_vel := Vector3.ZERO
var _done := false

# Шанси здобичі з одного ворога.
const GOLD_CHANCE := 0.70
const HP_CHANCE := 0.14
const MANA_CHANCE := 0.09
const ITEM_CHANCE := {"novice": 0.20, "werewolf": 0.28, "wraith": 0.24, "hound": 0.14, "archer": 0.26, "brute": 0.42}


## Кидає здобич із ворога. Повертає масив створених LootDrop.
static func drop_from_enemy(parent: Node, pos: Vector3, enemy_kind: String, level: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var gm := HeroStats.gold_mult()
	var dm := HeroStats.drop_mult()
	if rng.randf() < GOLD_CHANCE:
		var base := rng.randi_range(3, 8)
		var mult := 1.0 + 0.25 * float(level - 1)
		if enemy_kind == "werewolf" or enemy_kind == "archer":
			mult *= 1.4
		elif enemy_kind == "brute":
			mult *= 2.2
		out.append(make_drop(parent, pos, KIND_GOLD, maxi(1, int(round(base * mult * gm))), {}, rng))
	if rng.randf() < HP_CHANCE * dm:
		out.append(make_drop(parent, pos, KIND_HP, 1, {}, rng))
	if rng.randf() < MANA_CHANCE * dm:
		out.append(make_drop(parent, pos, KIND_MANA, 1, {}, rng))
	if rng.randf() < float(ITEM_CHANCE.get(enemy_kind, 0.2)) * dm:
		out.append(make_drop(parent, pos, KIND_ITEM, 1, Items.generate(level, rng), rng))
	return out


## Велика нагорода за міні-боса: багато гривень, зілля й два предмети не нижче «Рідкісного».
static func drop_from_boss(parent: Node, pos: Vector3, level: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var gold := int(round(float(rng.randi_range(90, 140)) * (1.0 + 0.2 * float(level)) * HeroStats.gold_mult()))
	for i in range(3):
		out.append(make_drop(parent, pos, KIND_GOLD, gold / 3, {}, rng))
	out.append(make_drop(parent, pos, KIND_HP, 1, {}, rng))
	out.append(make_drop(parent, pos, KIND_MANA, 1, {}, rng))
	for i in range(2):
		var it := Items.generate(level + 1, rng, "", 2 if i == 0 else rng.randi_range(2, 3))
		out.append(make_drop(parent, pos, KIND_ITEM, 1, it, rng))
	return out


static func make_drop(parent: Node, pos: Vector3, p_kind: String, p_amount: int, p_item: Dictionary, rng: RandomNumberGenerator) -> LootDrop:
	var d := LootDrop.new()
	d.kind = p_kind
	d.amount = p_amount
	d.item = p_item
	var a := rng.randf() * TAU
	d._spawn_vel = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.8, 2.2)
	parent.add_child(d)
	d.global_position = Vector3(pos.x, 0.0, pos.z)
	return d


func _ready() -> void:
	add_to_group("loot")
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		_player = pl[0]


func _build_visual() -> void:
	match kind:
		KIND_GOLD:
			var parts: Array = []
			var g := Color("E8B53A")
			parts.append(LowPoly.cyl(0.2, 0.2, 0.06, Vector3(0, 0.1, 0), g, 8))
			parts.append(LowPoly.cyl(0.2, 0.2, 0.06, Vector3(0.14, 0.16, 0.1), g.lightened(0.15), 8))
			parts.append(LowPoly.cyl(0.2, 0.2, 0.06, Vector3(-0.1, 0.07, 0.18), g.darkened(0.1), 8))
			_visual.add_child(LowPoly.instance(parts))
		KIND_HP, KIND_MANA:
			var c: Color = Palette.HP_COLOR.lightened(0.15) if kind == KIND_HP else Palette.MANA_COLOR.lightened(0.1)
			var parts2: Array = []
			parts2.append(LowPoly.ball(0.2, Vector3(0, 0.25, 0), c, 6))
			parts2.append(LowPoly.cyl(0.07, 0.07, 0.18, Vector3(0, 0.5, 0), Color("D9D2C0"), 6))
			parts2.append(LowPoly.cyl(0.09, 0.09, 0.05, Vector3(0, 0.62, 0), Color("7A5532"), 6))
			_visual.add_child(LowPoly.instance(parts2))
			_visual.add_child(LowPoly.glow_instance(LowPoly.ball(0.12, Vector3(0, 0.25, 0), c, 5), c, 1.6))
		_:
			var col := Items.rarity_color(item)
			var typ := Items.type_of(item)
			var parts3: Array = []
			match typ:
				"hand1", "hand2":
					parts3.append(LowPoly.box(Vector3(0.1, 0.55, 0.05), Vector3(0, 0.3, 0), col, Vector3(0, 0, 55)))
					parts3.append(LowPoly.box(Vector3(0.24, 0.05, 0.07), Vector3(-0.1, 0.15, 0), Palette.GOLD, Vector3(0, 0, 55)))
				"shield":
					parts3.append(LowPoly.cyl(0.26, 0.26, 0.06, Vector3(0, 0.3, 0), col, 8, Vector3(90, 0, 0)))
					parts3.append(LowPoly.ball(0.07, Vector3(0, 0.3, 0.05), Palette.GOLD, 5))
				"head", "hands", "feet", "body":
					parts3.append(LowPoly.cyl(0.2, 0.26, 0.34, Vector3(0, 0.25, 0), col, 6))
					parts3.append(LowPoly.cyl(0.27, 0.27, 0.05, Vector3(0, 0.1, 0), Palette.GOLD, 6))
				"amulet":
					parts3.append(LowPoly.cyl(0.18, 0.18, 0.05, Vector3(0, 0.3, 0), Palette.GOLD, 8, Vector3(90, 0, 0)))
					parts3.append(LowPoly.ball(0.1, Vector3(0, 0.3, 0.03), col, 5))
				_:
					parts3.append(LowPoly.cyl(0.16, 0.16, 0.06, Vector3(0, 0.22, 0), Palette.GOLD, 8, Vector3(90, 0, 0)))
					parts3.append(LowPoly.ball(0.09, Vector3(0, 0.34, 0), col, 5))
			_visual.add_child(LowPoly.instance(parts3))
			_visual.add_child(LowPoly.glow_instance(LowPoly.ball(0.1, Vector3(0, 0.3, 0), col, 5), col, 1.5, 0.9))
			# промінь рідкісності
			var ridx := int(item.get("rarity", 0))
			if ridx >= 1:
				var beam := LowPoly.glow_instance(LowPoly.cyl(0.05, 0.05, 2.2 + 0.5 * ridx, Vector3(0, 1.2, 0), col, 4), col, 2.0, 0.35)
				add_child(beam)
			var l := Label3D.new()
			l.text = str(item.get("name", "Річ"))
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.font_size = 30
			l.pixel_size = 0.011
			l.outline_size = 10
			l.modulate = col.lightened(0.15)
			l.outline_modulate = Palette.NIGHT
			l.position = Vector3(0, 1.0, 0)
			l.no_depth_test = true
			add_child(l)


func label_text() -> String:
	match kind:
		KIND_GOLD:
			return "+%d гривень" % amount
		KIND_HP:
			return "Зілля життя"
		KIND_MANA:
			return "Зілля чару"
	return str(item.get("name", "Річ"))


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	# розліт від ворога
	if _age < 0.5:
		global_position += _spawn_vel * delta * (1.0 - _age / 0.5)
	_visual.rotation.y += delta * 1.6
	_visual.position.y = 0.08 + sin(_age * 3.0) * 0.05
	if _player == null or not is_instance_valid(_player) or _player.dead:
		return
	var off := _player.global_position - global_position
	off.y = 0.0
	var d := off.length()
	var magnet := attract or (kind != KIND_ITEM and d < MAGNET_RADIUS and _age > 0.6)
	if magnet and d > 0.05:
		global_position += off.normalized() * minf(d, (9.0 if attract else 6.0) * delta)
	if d < PICKUP_RADIUS and _age > 0.35:
		_pickup()


func _pickup() -> void:
	if _done:
		return
	var parent := get_parent()
	var pos := global_position + Vector3(0, 1.2, 0)
	match kind:
		KIND_GOLD:
			GameState.add_gold(amount)
			Fx.damage_number(parent, pos, "+%d гривень" % amount, Palette.GOLD, false)
		KIND_HP:
			GameState.add_potion("hp", 1)
			Fx.damage_number(parent, pos, "Зілля життя", Palette.HP_COLOR.lightened(0.3), false)
		KIND_MANA:
			GameState.add_potion("mana", 1)
			Fx.damage_number(parent, pos, "Зілля чару", Palette.MANA_COLOR.lightened(0.3), false)
		_:
			if not GameState.add_item(item):
				attract = false
				if int(Time.get_ticks_msec() / 1000) % 2 == 0 or _age < 1.0:
					Fx.damage_number(parent, pos, "Сумка повна", Palette.TEXT_DIM, false)
				_age = maxf(_age, 0.36)
				# не засипаємо повідомленнями: відсуваємо підбір
				_player = null
				get_tree().create_timer(2.0).timeout.connect(_rebind_player)
				return
			Fx.damage_number(parent, pos, label_text(), Items.rarity_color(item).lightened(0.2), true)
	_done = true
	queue_free()


func _rebind_player() -> void:
	if not is_inside_tree():
		return
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		_player = pl[0]
