## Герой гравця: рух, звичайна атака за зброєю, навички, життя й чар.
class_name Player
extends CharacterBody3D

signal died
signal vitals_changed
signal skill_cast(slot: int)

const TURN_SPEED := 16.0
const DASH_SPEED := 30.0
const DASH_TIME := 0.2

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


func set_world_root(n: Node) -> void:
	_world_root = n


func _fx_parent() -> Node:
	return _world_root if _world_root != null else get_parent()


func rebuild_model() -> void:
	if model != null:
		model.queue_free()
	var accent: Color = Blessings.get_def(GameState.blessing)["color"]
	model = ModelFactory.hero(GameState.hero_class, accent)
	add_child(model)
	weapon_pivot = model.get_node("WeaponPivot")


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	if dead:
		return
	combat_timer += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			ModelFactory.set_flash(model, false)

	# клавіатура
	var mv := _input_vec()
	if Input.is_action_just_pressed("skill_1"):
		use_skill(0)
	if Input.is_action_just_pressed("skill_2"):
		use_skill(1)

	var speed := HeroStats.move_speed()
	if GameState.blessing == "veles" and combat_timer > 5.0:
		speed *= 1.10

	var vel := Vector3(mv.x, 0, mv.y) * speed
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	if _dash_t > 0.0:
		_dash_t -= delta
		vel = _dash_dir * DASH_SPEED
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
	if combat_timer > 6.0 and hp < HeroStats.max_hp():
		heal(HeroStats.max_hp() * 0.01 * delta, false)
		changed = true
	_regen_acc += delta
	if changed and _regen_acc > 0.1:
		_regen_acc = 0.0
		vitals_changed.emit()


func _animate(delta: float, move_amount: float) -> void:
	if model == null:
		return
	var bob := absf(sin(_walk_t * 2.2)) * 0.07 * clampf(move_amount * 2.0, 0.0, 1.0)
	model.position.y = bob
	model.rotation.x = lerpf(model.rotation.x, -0.12 * minf(move_amount, 1.0), 10.0 * delta)
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta * 4.5)
	if weapon_pivot != null:
		var kind: String = HeroStats.weapon_def()["kind"]
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
	attack_cd = HeroStats.attack_interval()
	combat_timer = 0.0
	_swing = 1.0
	match kind:
		"melee":
			var t := create_tween()
			t.tween_callback(_melee_hit.bind(dir, reach)).set_delay(0.12)
		"arrow":
			_shoot(ModelFactory.arrow(), dir, 22.0, Palette.LINEN, true)
		_:
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


func _shoot(visual: Node3D, dir: Vector3, spd: float, spark: Color, basic: bool, dmg_override: float = -1.0) -> void:
	var pr := Projectile.new()
	pr.add_child(visual)
	pr.velocity = dir * spd
	pr.life = float(HeroStats.weapon_def()["range"]) / spd + 0.25
	pr.spark_color = spark
	var base := HeroStats.weapon_damage() if dmg_override < 0.0 else dmg_override
	var r := _roll_damage(base)
	pr.hit_callback = func(target: Node) -> void:
		if is_instance_valid(target) and is_instance_valid(self):
			deal_damage(target as Enemy, r[0], r[1], basic, 2.5)
	_fx_parent().add_child(pr)
	pr.global_position = global_position + Vector3(0, 1.1, 0) + dir * 0.6
	pr.look_at(pr.global_position + dir, Vector3.UP)


## Єдина точка нанесення шкоди ворогу.
func deal_damage(enemy: Enemy, amount: float, crit: bool, basic: bool, knock_force: float) -> void:
	if enemy == null or enemy.dead:
		return
	combat_timer = 0.0
	enemy.take_damage(amount, global_position, crit, knock_force)
	# Громова мітка Перуна: кожен 5-й звичайний удар б'є блискавкою
	if basic and GameState.blessing == "perun":
		_hit_counter += 1
		if _hit_counter % 5 == 0 and not enemy.dead:
			Fx.lightning(_fx_parent(), enemy.global_position)
			enemy.take_damage(amount * 0.5, global_position, false, 0.0)


# ---------- Навички ----------

func skill_id(slot: int) -> String:
	var a := GameState.active_skills()
	return a[slot] if slot < a.size() else ""


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
	if id == "":
		return
	var def: Dictionary = Skills.get_def(id)
	if float(cooldowns.get(id, 0.0)) > 0.0:
		return
	var cost := float(def["mana"])
	if mana < cost:
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.3, 0), "Мало чару", Palette.MANA_COLOR, false)
		return
	mana -= cost
	combat_timer = 0.0
	var target := nearest_enemy(14.0)
	var dir := _facing
	if target != null:
		dir = _dir_to(target.global_position)
	match id:
		"power_strike":
			_cast_power_strike()
		"arrow_volley":
			_cast_volley(dir)
		"element_wave":
			_cast_wave()
		"stribog_dash":
			_cast_dash()
	var cd := float(def["cd"])
	if GameState.blessing == "mokosh" and randf() < 0.10:
		cd = 0.0
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.6, 0), "Нитка долі!", Color("D7A8FF"), false)
	cooldowns[id] = cd
	cooldown_total[id] = maxf(cd, 0.01)
	_swing = 1.0
	skill_cast.emit(slot)
	vitals_changed.emit()


func _cast_power_strike() -> void:
	var def: Dictionary = Skills.get_def("power_strike")
	var radius := float(def["radius"])
	Fx.ring_burst(_fx_parent(), global_position, radius, def["color"], 0.4)
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		if _flat_dist(en.global_position) <= radius + en.body_radius:
			var r := _roll_damage(HeroStats.skill_damage("power_strike"))
			deal_damage(en, r[0], r[1], false, 9.0)


func _cast_volley(dir: Vector3) -> void:
	var def: Dictionary = Skills.get_def("arrow_volley")
	var n := int(def["count"])
	for i in range(n):
		var ang := deg_to_rad(lerpf(-28.0, 28.0, float(i) / float(n - 1)))
		var d := dir.rotated(Vector3.UP, ang)
		_shoot(ModelFactory.arrow(), d, 22.0, Palette.LINEN, false, HeroStats.skill_damage("arrow_volley"))


func _cast_wave() -> void:
	var def: Dictionary = Skills.get_def("element_wave")
	var radius := float(def["radius"])
	var col: Color = Blessings.get_def(GameState.blessing)["color"]
	Fx.ring_burst(_fx_parent(), global_position, radius, col, 0.5)
	Fx.sparks(_fx_parent(), global_position + Vector3(0, 0.8, 0), col, 14)
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		if _flat_dist(en.global_position) <= radius + en.body_radius:
			var r := _roll_damage(HeroStats.skill_damage("element_wave"))
			deal_damage(en, r[0], r[1], false, 5.0)


func _cast_dash() -> void:
	var iv := _input_vec()
	var mv := Vector3(iv.x, 0, iv.y)
	_dash_dir = mv.normalized() if mv.length() > 0.1 else _facing
	_dash_t = DASH_TIME
	invuln = DASH_TIME + 0.1
	var col: Color = Skills.get_def("stribog_dash")["color"]
	Fx.ring_burst(_fx_parent(), global_position, 3.5, col, 0.4)
	for e in _enemies():
		var en: Enemy = e
		if en.dead:
			continue
		if _flat_dist(en.global_position) <= 3.5:
			en.take_damage(0.0, global_position, false, 12.0)


# ---------- Отримання шкоди, лікування, смерть ----------

func take_damage(amount: float, from_pos: Vector3, knock_force: float = 3.0) -> void:
	if dead or invuln > 0.0:
		return
	var final := maxf(1.0, amount * (1.0 - HeroStats.damage_reduction()))
	hp = maxf(0.0, hp - final)
	combat_timer = 0.0
	invuln = 0.12
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		_knock = away.normalized() * knock_force
	Fx.damage_number(_fx_parent(), global_position + Vector3(0, 2.2, 0), str(int(round(final))), Palette.EMBROIDERY.lightened(0.25), false)
	ModelFactory.set_flash(model, true)
	_flash_t = 0.1
	vitals_changed.emit()
	if hp <= 0.0:
		_die()


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
	var t := create_tween()
	t.tween_property(model, "rotation:x", -PI / 2.0, 0.5).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(model, "position:y", 0.15, 0.5)
	died.emit()


func respawn(at: Vector3) -> void:
	dead = false
	global_position = at
	rotation.y = 0.0
	_facing = Vector3(0, 0, -1)
	_knock = Vector3.ZERO
	cooldowns.clear()
	model.rotation.x = 0.0
	model.position.y = 0.0
	ModelFactory.set_flash(model, false)
	invuln = 2.0
	restore_full()
