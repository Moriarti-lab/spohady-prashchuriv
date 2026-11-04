## Герой гравця: рух, звичайна атака за зброєю, навички, життя й чар.
class_name Player
extends CharacterBody3D

signal died
signal vitals_changed
signal skill_cast(slot: int)
signal potion_used(kind: String)

const TURN_SPEED := 16.0
const DASH_SPEED := 30.0
const DASH_TIME := 0.2
const POTION_COOLDOWN := 6.0
const HP_POTION_HEAL := 0.45
const MANA_POTION_RESTORE := 0.5

var body_radius := 0.4
var hp := 100.0
var mana := 50.0
var dead := false

## Вводиться з екрана (стік і кнопки) або з клавіатури.
var move_input := Vector2.ZERO
var attack_held := false
## Поворот входу відносно камери (світові осі = екранні осі після повороту)
var input_yaw := 0.0

var model: Node3D
var weapon_pivot: Node3D
var cooldowns := {}          # id навички -> залишок, с
var cooldown_total := {}     # id навички -> повний час
var attack_cd := 0.0
var combat_timer := 99.0     # с від останньої бойової дії
var invuln := 0.0
var _dash_t := 0.0
var _dash_dir := Vector3.ZERO
var _knock := Vector3.ZERO
var _facing := Vector3(0, 0, -1)
var _hit_counter := 0
var _walk_t := 0.0
var _swing := 0.0
var _regen_acc := 0.0
var _flash_t := 0.0
var _world_root: Node = null
var potion_cd := 0.0
var last_target: Enemy = null
var last_target_t := 0.0
var _weapon_base := ""
var shield_hp := 0.0
var shield_t := 0.0
var _dash_speed := DASH_SPEED


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = body_radius
	sh.height = 1.7
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	rebuild_model()
	hp = HeroStats.max_hp()
	mana = HeroStats.max_mana()
	GameState.changed.connect(_on_state_changed)


func _exit_tree() -> void:
	if GameState.changed.is_connected(_on_state_changed):
		GameState.changed.disconnect(_on_state_changed)


## Спорядження або Древо змінилися: оновлюємо зброю в руках і межі життя та чару.
func _on_state_changed() -> void:
	if _current_weapon_base() != _weapon_base:
		rebuild_model()
	var mh := HeroStats.max_hp()
	var mm := HeroStats.max_mana()
	if hp > mh or mana > mm:
		hp = minf(hp, mh)
		mana = minf(mana, mm)
	vitals_changed.emit()


func _base_of(slot: String) -> String:
	var w: Variant = GameState.equipment.get(slot, null)
	return str(w.get("base", "")) if typeof(w) == TYPE_DICTIONARY else ""


func _current_weapon_base() -> String:
	return _base_of("main") + "|" + _base_of("off")


func facing_vec2() -> Vector2:
	return Vector2(_facing.x, _facing.z).normalized()


func set_world_root(n: Node) -> void:
	_world_root = n


func _fx_parent() -> Node:
	return _world_root if _world_root != null else get_parent()


func rebuild_model() -> void:
	if model != null:
		model.queue_free()
	var accent: Color = Blessings.get_def(GameState.blessing)["color"]
	_weapon_base = _current_weapon_base()
	model = ModelFactory.hero(GameState.hero_class, accent, _base_of("main"), _base_of("off"))
	add_child(model)
	weapon_pivot = model.find_child("WeaponPivot", true, false)
	if weapon_pivot != null and weapon_pivot.has_meta("rig"):
		weapon_pivot = null


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	if dead:
		return
	combat_timer += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	if last_target_t > 0.0:
		last_target_t -= delta
	invuln = maxf(0.0, invuln - delta)
	HeroStats.tick_buffs(delta)
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield_hp = 0.0
			vitals_changed.emit()
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			ModelFactory.set_flash(model, false)

	# клавіатура
	var mv := _input_vec()
	for i in range(GameState.QUICK_SLOTS):
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			use_skill(i)
	if Input.is_action_just_pressed("potion_hp"):
		use_potion("hp")
	if Input.is_action_just_pressed("potion_mana"):
		use_potion("mana")

	var speed := HeroStats.move_speed()
	if GameState.blessing == "veles" and combat_timer > 5.0:
		speed *= 1.10

	var vel := Vector3(mv.x, 0, mv.y) * speed
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	if _dash_t > 0.0:
		_dash_t -= delta
		vel = _dash_dir * _dash_speed
	velocity = vel + _knock
	move_and_slide()
	position.y = 0.0

	# повертаємося обличчям
	var want := _facing
	if mv.length() > 0.1:
		want = Vector3(mv.x, 0, mv.y).normalized()
		_walk_t += delta * speed * 2.0
	var target_yaw := atan2(-want.x, -want.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
	_facing = want

	# атака
	if (attack_held or Input.is_action_pressed("attack")) and attack_cd <= 0.0:
		basic_attack()

	_regen(delta)
	_animate(delta, mv.length())


## Рух із джойстика або клавіатури, повернутий за камерою.
func _input_vec() -> Vector2:
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var v := move_input if move_input.length() > 0.05 else kb
	if v.length() > 1.0:
		v = v.normalized()
	return v.rotated(input_yaw)


func _regen(delta: float) -> void:
	var changed := false
	if mana < HeroStats.max_mana():
		mana = minf(HeroStats.max_mana(), mana + HeroStats.mana_regen() * delta)
		changed = true
	# повільне відновлення життя поза боєм
	if hp < HeroStats.max_hp():
		var rate := HeroStats.hp_regen()
		if combat_timer > 6.0:
			rate += HeroStats.max_hp() * 0.01
		if rate > 0.0:
			heal(rate * delta, false)
			changed = true
	_regen_acc += delta
	if changed and _regen_acc > 0.1:
		_regen_acc = 0.0
		vitals_changed.emit()


func _animate(delta: float, move_amount: float) -> void:
	if model == null:
		return
	if model is RigModel:
		(model as RigModel).set_move(move_amount)
		return
	var bob := absf(sin(_walk_t * 2.2)) * 0.07 * clampf(move_amount * 2.0, 0.0, 1.0)
	model.position.y = bob
	model.rotation.x = lerpf(model.rotation.x, -0.12 * minf(move_amount, 1.0), 10.0 * delta)
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta * 4.5)
	if weapon_pivot != null:
		var kind: String = HeroStats.attack_kind()
		if kind == "melee":
			weapon_pivot.rotation.x = deg_to_rad(-15.0 - 110.0 * sin(_swing * PI))
		else:
			weapon_pivot.rotation.x = deg_to_rad(-8.0 * _swing)


# ---------- Звичайна атака ----------

func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func nearest_enemy(max_dist: float) -> Enemy:
	var best: Enemy = null
	var bd := max_dist
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		var d := _flat_dist(en.global_position)
		if d < bd:
			bd = d
			best = en
	return best


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _dir_to(p: Vector3) -> Vector3:
	var d := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	return d.normalized() if d.length() > 0.01 else _facing


func _roll_damage(base: float) -> Array:
	var d := base * randf_range(0.9, 1.1)
	var crit := randf() < HeroStats.crit_chance()
	if crit:
		d *= HeroStats.crit_mult()
	return [d, crit]


func basic_attack() -> void:
	if dead:
		return
	var w: Dictionary = HeroStats.weapon_def()
	var kind: String = w["kind"]
	var reach := float(w["range"])
	var target := nearest_enemy(reach + (0.6 if kind == "melee" else 0.0))
	var dir := _facing
	if target != null:
		dir = _dir_to(target.global_position)
	elif attack_held or Input.is_action_pressed("attack"):
		# без цілі: все одно замахуємося у бік погляду, але без витрати часу на «порожні» постріли
		if kind != "melee":
			var far := nearest_enemy(reach + 8.0)
			if far != null:
				dir = _dir_to(far.global_position)
			else:
				attack_cd = 0.15
				return
	_face_now(dir)
	if model is RigModel:
		(model as RigModel).attack(kind, bool(model.get_meta("two_handed", false)))
	attack_cd = HeroStats.attack_interval()
	combat_timer = 0.0
	_swing = 1.0
	match kind:
		"melee":
			Sound.play("sfx_whoosh", -6.0)
			var t := create_tween()
			t.tween_callback(_melee_hit.bind(dir, reach)).set_delay(0.12)
		"arrow":
			Sound.play("sfx_arrow", -4.0)
			_shoot(ModelFactory.arrow(), dir, 22.0, Palette.LINEN, true)
		_:
			Sound.play(Sound.blessing_magic(GameState.blessing), -8.0)
			var col: Color = Blessings.get_def(GameState.blessing)["color"]
			_shoot(ModelFactory.bolt(col), dir, 16.0, col, true)


func _face_now(dir: Vector3) -> void:
	_facing = dir
	rotation.y = atan2(-dir.x, -dir.z)


func _melee_hit(dir: Vector3, reach: float) -> void:
	if dead:
		return
	var base := HeroStats.weapon_damage()
	var any := false
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		var off := en.global_position - global_position
		off.y = 0.0
		var d := off.length()
		if d > reach + en.body_radius:
			continue
		if d > 0.6 and dir.dot(off.normalized()) < 0.2:
			continue
		var r := _roll_damage(base)
		deal_damage(en, r[0], r[1], true, 4.0)
		any = true
	if any:
		Fx.sparks(_fx_parent(), global_position + dir * 1.4 + Vector3(0, 1.0, 0), Palette.GOLD, 6)


func _shoot(visual: Node3D, dir: Vector3, spd: float, spark: Color, basic: bool, dmg_override: float = -1.0, life_t: float = -1.0, on_hit: Callable = Callable(), knock: float = 2.5) -> Projectile:
	var pr := Projectile.new()
	pr.add_child(visual)
	pr.velocity = dir * spd
	pr.life = life_t if life_t > 0.0 else (float(HeroStats.weapon_def()["range"]) if basic else 14.0) / spd + 0.25
	pr.spark_color = spark
	var base := HeroStats.weapon_damage() if dmg_override < 0.0 else dmg_override
	var r := _roll_damage(base)
	pr.hit_callback = func(target: Node) -> void:
		if is_instance_valid(target) and is_instance_valid(self):
			deal_damage(target as Enemy, r[0], r[1], basic, knock)
			if on_hit.is_valid():
				on_hit.call(target)
	_fx_parent().add_child(pr)
	pr.global_position = global_position + Vector3(0, 1.1, 0) + dir * 0.6
	pr.look_at(pr.global_position + dir, Vector3.UP)
	return pr


## Єдина точка нанесення шкоди ворогу.
func deal_damage(enemy: Enemy, amount: float, crit: bool, basic: bool, knock_force: float) -> void:
	if enemy == null or enemy.dead:
		return
	combat_timer = 0.0
	last_target = enemy
	last_target_t = 5.0
	enemy.take_damage(amount, global_position, crit, knock_force)
	var ls := HeroStats.lifesteal()
	if ls > 0.0 and amount > 0.0:
		heal(amount * ls, false)
	# Громова мітка Перуна: кожен 5-й звичайний удар б'є блискавкою
	if basic and GameState.blessing == "perun":
		_hit_counter += 1
		if _hit_counter % 5 == 0 and not enemy.dead:
			Fx.lightning(_fx_parent(), enemy.global_position)
			enemy.take_damage(amount * 0.5, global_position, false, 0.0)


# ---------- Навички ----------

func skill_id(slot: int) -> String:
	return GameState.quick_skill(slot)


func skill_cd_ratio(slot: int) -> float:
	var id := skill_id(slot)
	if id == "" or not cooldowns.has(id):
		return 0.0
	var tot := float(cooldown_total.get(id, 1.0))
	return clampf(float(cooldowns[id]) / maxf(tot, 0.01), 0.0, 1.0)


func use_skill(slot: int) -> void:
	if dead:
		return
	var id := skill_id(slot)
	if id == "" or not Skills.has(id):
		return
	if float(cooldowns.get(id, 0.0)) > 0.0:
		return
	var p := HeroStats.skill_params(id)
	var kind := str(p["kind"])
	var cost := float(p["mana"])
	if mana < cost:
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.3, 0), "Мало чару", Palette.MANA_COLOR, false)
		return
	var target := nearest_enemy(14.0)
	if kind == "strike" or kind == "chain":
		var reach := float(p["range"]) + (0.0 if kind == "chain" or bool(p.get("ranged", false)) else 0.6)
		target = nearest_enemy(reach)
		if target == null:
			Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.3, 0), "Немає цілі", Palette.TEXT_DIM, false)
			return
	mana -= cost
	combat_timer = 0.0
	var dir := _facing
	if target != null:
		dir = _dir_to(target.global_position)
		_face_now(dir)
	Sound.play(Sound.skill_sound(id, kind))
	if model is RigModel:
		(model as RigModel).attack("cast" if kind in ["buff", "shield", "heal", "nova"] else ("melee" if kind in ["cone", "strike", "dash"] and HeroStats.attack_kind() == "melee" else "spell"))
	match kind:
		"nova":
			_cast_nova(id, p)
		"cone":
			_cast_cone(id, p, dir)
		"strike":
			_cast_strike(id, p, target)
		"volley":
			_cast_volley(id, p, dir)
		"zone":
			_cast_zone(id, p, dir, target)
		"chain":
			_cast_chain(id, p, target)
		"buff":
			_cast_buff(id, p)
		"shield":
			_cast_shield(id, p)
		"heal":
			_cast_ancestral_heal(p)
		"dash":
			_cast_dash(id, p)
	var cd := float(p["cd"])
	if GameState.blessing == "mokosh" and randf() < 0.10:
		cd = 0.0
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.6, 0), "Нитка долі!", Color("D7A8FF"), false)
	cooldowns[id] = cd
	cooldown_total[id] = maxf(cd, 0.01)
	_swing = 1.0
	skill_cast.emit(slot)
	vitals_changed.emit()


## Один удар навички по ворогові: шкода з критом, відкидання, приголомшення й сповільнення.
func _skill_hit(en: Enemy, id: String, p: Dictionary, knock_default: float = 3.0, stun_on: bool = true) -> void:
	if en == null or en.dead:
		return
	var r := _roll_damage(HeroStats.skill_damage(id))
	deal_damage(en, r[0], r[1], false, float(p.get("knock", knock_default)))
	if en.dead:
		return
	var st := float(p.get("stun", 0.0))
	if stun_on and st > 0.0:
		en.apply_stun(st)
	if float(p.get("slow", 0.0)) > 0.0:
		en.apply_slow(float(p["slow"]), float(p.get("slow_t", 1.5)))


func _enemies_in_circle(center: Vector3, radius: float) -> Array:
	var out: Array = []
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		var off := en.global_position - center
		off.y = 0.0
		if off.length() <= radius + en.body_radius:
			out.append(en)
	return out


func _cast_nova(id: String, p: Dictionary) -> void:
	var radius := float(p["radius"])
	var ticks := maxi(1, int(p.get("ticks", 1)))
	var col: Color = p["color"] if id != "element_wave" else Blessings.get_def(GameState.blessing)["color"]
	for i in range(ticks):
		if i == 0:
			_nova_tick(id, p, radius, col, true)
		else:
			var t := create_tween()
			t.tween_callback(_nova_tick.bind(id, p, radius, col, false)).set_delay(float(p.get("tick", 0.22)) * float(i))


func _nova_tick(id: String, p: Dictionary, radius: float, col: Color, first: bool) -> void:
	if dead:
		return
	_swing = 1.0
	Fx.ring_burst(_fx_parent(), global_position, radius, col, 0.3 if int(p.get("ticks", 1)) > 1 else 0.45)
	if first and bool(p.get("ultimate", false)):
		Fx.sparks(_fx_parent(), global_position + Vector3(0, 0.8, 0), col, 20)
	for en in _enemies_in_circle(global_position, radius):
		_skill_hit(en, id, p, 4.0, first)


func _cast_cone(id: String, p: Dictionary, dir: Vector3) -> void:
	var n := maxi(1, int(p["count"]))
	for i in range(n):
		var t := create_tween()
		t.tween_callback(_cone_hit.bind(id, p, i)).set_delay(float(p.get("delay", 0.13)) * float(i) + 0.05)


func _cone_hit(id: String, p: Dictionary, _i: int) -> void:
	if dead:
		return
	_swing = 1.0
	var reach := float(p["range"])
	var half := deg_to_rad(float(p["arc"]) * 0.5)
	var dir := _facing
	var near := nearest_enemy(reach + 1.5)
	if near != null:
		dir = _dir_to(near.global_position)
		_face_now(dir)
	var any := false
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		var off := en.global_position - global_position
		off.y = 0.0
		var d := off.length()
		if d > reach + en.body_radius:
			continue
		if d > 0.6 and absf(dir.angle_to(off.normalized())) > half:
			continue
		_skill_hit(en, id, p, 3.0, _i == 0)
		any = true
	Fx.sparks(_fx_parent(), global_position + dir * minf(reach, 3.0) * 0.6 + Vector3(0, 1.0, 0), p["color"], 7 if any else 4)


func _cast_strike(id: String, p: Dictionary, target: Enemy) -> void:
	if target == null:
		return
	if bool(p.get("ranged", false)):
		Fx.lightning(_fx_parent(), target.global_position)
	Fx.ring_burst(_fx_parent(), target.global_position, 1.6, p["color"], 0.35)
	Fx.sparks(_fx_parent(), target.global_position + Vector3(0, 1.0, 0), p["color"], 10)
	_skill_hit(target, id, p, 8.0)


func _cast_volley(id: String, p: Dictionary, dir: Vector3) -> void:
	var n := maxi(1, int(p["count"]))
	var spread := float(p.get("spread", 0.0))
	var delay := float(p.get("delay", 0.0))
	var col: Color = p["color"]
	for i in range(n):
		var ang := 0.0
		if spread >= 359.0:
			ang = TAU * float(i) / float(n)
		elif n > 1:
			ang = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(i) / float(n - 1)))
		var d := dir.rotated(Vector3.UP, ang)
		if delay > 0.0:
			var t := create_tween()
			t.tween_callback(_volley_shot.bind(id, p, d, col)).set_delay(delay * float(i))
		else:
			_volley_shot(id, p, d, col)


func _volley_shot(id: String, p: Dictionary, d: Vector3, col: Color) -> void:
	if dead:
		return
	var magic := bool(p.get("magic", false))
	var visual: Node3D = ModelFactory.bolt(col) if magic else ModelFactory.arrow()
	var spd := float(p.get("speed", 22.0))
	var life := float(p.get("life", 0.9))
	var slow := float(p.get("slow", 0.0))
	var slow_t := float(p.get("slow_t", 1.5))
	var stun := float(p.get("stun", 0.0))
	var cb := func(t: Node) -> void:
		var en := t as Enemy
		if en != null and not en.dead:
			if slow > 0.0:
				en.apply_slow(slow, slow_t)
			if stun > 0.0:
				en.apply_stun(stun)
	var pr := _shoot(visual, d, spd, col if magic else Palette.LINEN, false, HeroStats.skill_damage(id), life, cb, float(p.get("knock", 2.5)))
	if pr != null and bool(p.get("pierce", false)):
		pr.pierce = true
	if pr != null and bool(p.get("big", false)):
		pr.scale = Vector3(1.4, 1.4, 1.4)
	_swing = 1.0


func _cast_zone(id: String, p: Dictionary, dir: Vector3, target: Enemy) -> void:
	var at := str(p.get("at", "target"))
	var center := global_position
	match at:
		"target":
			if target != null and _flat_dist(target.global_position) <= float(p.get("range", 12.0)) + 1.0:
				center = target.global_position
			else:
				center = global_position + dir * minf(6.0, float(p.get("range", 12.0)))
		"ahead":
			center = global_position + dir * 4.0
			if target != null and _flat_dist(target.global_position) <= 6.0:
				center = target.global_position
	center.y = 0.0
	var radius := float(p["radius"])
	var delay := float(p.get("delay", 0.0))
	var ticks := maxi(1, int(p.get("ticks", 1)))
	var tick := float(p.get("tick", 0.5))
	var col: Color = p["color"]
	var follow := at == "self"
	Fx.ring_burst(_fx_parent(), center, radius, col.darkened(0.1), maxf(0.25, delay if delay > 0.0 else 0.3))
	for i in range(ticks):
		var t := create_tween()
		t.tween_callback(_zone_tick.bind(id, p, center, radius, col, i == 0, follow)).set_delay(delay + tick * float(i))


func _zone_tick(id: String, p: Dictionary, center: Vector3, radius: float, col: Color, first: bool, follow: bool) -> void:
	if dead:
		return
	var c := global_position if follow else center
	c.y = 0.0
	Fx.ring_burst(_fx_parent(), c, radius, col, 0.3)
	for en in _enemies_in_circle(c, radius):
		_skill_hit(en, id, p, 1.5, first)


func _cast_chain(id: String, p: Dictionary, target: Enemy) -> void:
	var hit := {}
	var cur := target
	var n := maxi(1, int(p["count"]))
	var jump := float(p.get("jump", 6.0))
	for i in range(n):
		if cur == null or cur.dead:
			break
		hit[cur.get_instance_id()] = true
		var en := cur
		var t := create_tween()
		t.tween_callback(_chain_hit.bind(id, p, en)).set_delay(0.08 * float(i))
		var nxt: Enemy = null
		var bd := jump
		for e in _enemies():
			var o: Enemy = e
			if o.dead or hit.has(o.get_instance_id()):
				continue
			var d := Vector2(o.global_position.x - cur.global_position.x, o.global_position.z - cur.global_position.z).length()
			if d < bd:
				bd = d
				nxt = o
		cur = nxt


func _chain_hit(id: String, p: Dictionary, en: Enemy) -> void:
	if en == null or not is_instance_valid(en) or en.dead:
		return
	Fx.lightning(_fx_parent(), en.global_position)
	_skill_hit(en, id, p, 2.0)


func _cast_buff(id: String, p: Dictionary) -> void:
	HeroStats.add_buff(id, p["buff"], float(p["dur"]))
	Fx.ring_burst(_fx_parent(), global_position, 3.0, p["color"], 0.5)
	Fx.sparks(_fx_parent(), global_position + Vector3(0, 1.0, 0), p["color"], 12)
	Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.4, 0), str(p["name"]), p["color"], false)
	GameState.changed.emit()


func _cast_shield(_id: String, p: Dictionary) -> void:
	shield_hp = float(p["absorb"]) + float(p["per_faith"]) * HeroStats.stat("faith")
	shield_t = float(p["dur"])
	Fx.ring_burst(_fx_parent(), global_position, 2.2, p["color"], 0.5)
	Fx.sparks(_fx_parent(), global_position + Vector3(0, 1.0, 0), p["color"], 12)
	Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.4, 0), "Щит %d" % int(shield_hp), p["color"], false)


func _cast_ancestral_heal(p: Dictionary) -> void:
	var amount := HeroStats.max_hp() * float(p["heal_pct"]) + HeroStats.stat("faith") * 1.5
	Fx.ring_burst(_fx_parent(), global_position, 3.0, p["color"], 0.5)
	Fx.sparks(_fx_parent(), global_position + Vector3(0, 0.8, 0), p["color"], 14)
	heal(amount)


func _cast_dash(id: String, p: Dictionary) -> void:
	var iv := _input_vec()
	var mv := Vector3(iv.x, 0, iv.y)
	_dash_dir = mv.normalized() if mv.length() > 0.1 else _facing
	_dash_t = DASH_TIME
	_dash_speed = float(p.get("dist", 6.0)) / DASH_TIME
	invuln = DASH_TIME + 0.1
	var radius := float(p.get("radius", 3.5))
	Fx.ring_burst(_fx_parent(), global_position, radius, p["color"], 0.4)
	for en in _enemies_in_circle(global_position, radius):
		(en as Enemy).take_damage(0.0, global_position, false, float(p.get("knock", 12.0)))
		if float(p.get("stun", 0.0)) > 0.0:
			(en as Enemy).apply_stun(float(p["stun"]))


# ---------- Отримання шкоди, лікування, смерть ----------

func take_damage(amount: float, from_pos: Vector3, knock_force: float = 3.0) -> void:
	if not dead:
		Sound.play("sfx_player_hurt", -6.0)
	if dead or invuln > 0.0:
		return
	var final := maxf(1.0, amount * (1.0 - HeroStats.damage_reduction()))
	if shield_hp > 0.0:
		var soak := minf(shield_hp, final)
		shield_hp -= soak
		final -= soak
		if shield_hp <= 0.0:
			shield_t = 0.0
		if final <= 0.0:
			invuln = 0.1
			Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.2, 0), "Щит", Color("F5E3A8"), false)
			vitals_changed.emit()
			return
	var th := HeroStats.thorns()
	if th > 0.0:
		for en in _enemies_in_circle(from_pos, 2.0):
			(en as Enemy).take_damage(amount * th, global_position, false, 0.0)
			break
	hp = maxf(0.0, hp - final)
	combat_timer = 0.0
	invuln = 0.12
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		_knock = away.normalized() * knock_force
	Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.2, 0), str(int(round(final))), Palette.EMBROIDERY.lightened(0.25), false)
	ModelFactory.set_flash(model, true)
	if model is RigModel:
		(model as RigModel).hit()
	_flash_t = 0.1
	vitals_changed.emit()
	if hp <= 0.0:
		_die()


## Зілля: kind = "hp" або "mana". Спільна перезарядка, витрачає запас.
func use_potion(kind: String) -> bool:
	if dead or potion_cd > 0.0:
		return false
	if kind == "hp" and hp >= HeroStats.max_hp() - 0.5:
		return false
	if kind == "mana" and mana >= HeroStats.max_mana() - 0.5:
		return false
	if not GameState.take_potion(kind):
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.3, 0), "Зілля скінчились", Palette.TEXT_DIM, false)
		return false
	potion_cd = POTION_COOLDOWN
	if kind == "hp":
		heal(HeroStats.max_hp() * HP_POTION_HEAL)
		Fx.sparks(_fx_parent(), global_position + Vector3(0, 1.0, 0), Palette.HP_COLOR.lightened(0.3), 10)
	else:
		mana = minf(HeroStats.max_mana(), mana + HeroStats.max_mana() * MANA_POTION_RESTORE)
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.3, 0), "+%d чару" % int(HeroStats.max_mana() * MANA_POTION_RESTORE), Palette.MANA_COLOR.lightened(0.2), false)
		Fx.sparks(_fx_parent(), global_position + Vector3(0, 1.0, 0), Palette.MANA_COLOR, 10)
	potion_used.emit(kind)
	vitals_changed.emit()
	return true


func drain_mana(amount: float) -> void:
	if amount <= 0.0 or dead:
		return
	mana = maxf(0.0, mana - amount)
	Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.6, 0), "−%d чару" % int(amount), Palette.MANA_COLOR, false)
	vitals_changed.emit()


func heal(amount: float, show_number: bool = true) -> void:
	if dead:
		return
	var a := amount * HeroStats.heal_mult()
	hp = minf(HeroStats.max_hp(), hp + a)
	if show_number and a >= 1.0:
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.3, 0), "+%d" % int(round(a)), Palette.HP_COLOR.lightened(0.3), false)
	vitals_changed.emit()


func restore_full() -> void:
	hp = HeroStats.max_hp()
	mana = HeroStats.max_mana()
	vitals_changed.emit()


func _die() -> void:
	dead = true
	attack_held = false
	move_input = Vector2.ZERO
	if model is RigModel:
		(model as RigModel).die()
	else:
		var t := create_tween()
		t.tween_property(model, "rotation:x", -PI / 2.0, 0.5).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(model, "position:y", 0.15, 0.5)
	died.emit()


func respawn(at: Vector3) -> void:
	dead = false
	if model is RigModel:
		(model as RigModel).revive()
	global_position = at
	rotation.y = 0.0
	_facing = Vector3(0, 0, -1)
	_knock = Vector3.ZERO
	cooldowns.clear()
	HeroStats.clear_buffs()
	shield_hp = 0.0
	shield_t = 0.0
	potion_cd = 0.0
	model.rotation.x = 0.0
	model.position.y = 0.0
	ModelFactory.set_flash(model, false)
	invuln = 2.0
	restore_full()
