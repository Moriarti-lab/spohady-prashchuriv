## Ворог Ордену Єдиного з простим ШІ: блукає, помічає героя, переслідує й б'є.
## Види: послушник (ближній бій), перевертень (перетворюється на звіра), привид (дальній).
class_name Enemy
extends CharacterBody3D

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, TRANSFORM }

var kind := "novice"
var level := 1
var def: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var dmg := 1.0
var speed := 1.0
var xp_reward := 1
var body_radius := 0.45
var dead := false
var is_beast := false

var target: Player = null
var home := Vector3.ZERO
var state := State.IDLE
var _state_t := 0.0
var _attack_cd := 0.0
var _wander_dir := Vector3.ZERO
var _wander_t := 0.0
var _knock := Vector3.ZERO
var _desired := Vector3.ZERO
var _model: Node3D
var _bar: Node3D
var _bar_fill: Sprite3D
var _bar_t := 0.0
var _t := randf() * 10.0
var _strafe := 1.0
var _flash_t := 0.0
var _world_root: Node = null
var is_boss := false
var boss_id := ""
var boss_name := ""
var scale_mult := 1.0
var stun_t := 0.0
var slow_t := 0.0
var slow_f := 0.0


## Викликати ДО додавання в сцену.
func setup(p_kind: String, p_level: int, p_target: Player, p_home: Vector3, p_world: Node) -> void:
	kind = p_kind
	level = p_level
	target = p_target
	home = p_home
	_world_root = p_world
	def = EnemyDefs.get_def(kind)
	var m := EnemyDefs.level_mult(level)
	max_hp = float(def["hp"]) * m
	hp = max_hp
	dmg = float(def["dmg"]) * m
	speed = float(def["speed"]) * randf_range(0.92, 1.08)
	xp_reward = int(round(float(def["xp"]) * (1.0 + 0.5 * float(level - 1))))
	body_radius = float(def["radius"])
	_strafe = 1.0 if randf() < 0.5 else -1.0


## Робить ворога мінібосом: більший, міцніший, велика нагорода. Викликати після setup(), до додавання в сцену.
func make_boss(p_id: String, p_name: String, p_scale: float, p_hp_mult: float = 1.0) -> void:
	is_boss = true
	boss_id = p_id
	boss_name = p_name
	scale_mult = p_scale
	max_hp *= 7.0 * p_hp_mult
	hp = max_hp
	dmg *= 1.5
	xp_reward *= 8
	body_radius *= p_scale
	speed *= 1.05


func apply_stun(t: float) -> void:
	if dead:
		return
	var tt := t * (0.4 if is_boss else 1.0)
	stun_t = maxf(stun_t, tt)
	if state == State.WINDUP:
		state = State.CHASE
		_model.scale = _base_scale()
	Fx.sparks(_fx_parent(), global_position + Vector3(0, float(def["height"]) * scale_mult + 0.3, 0), Color("FFE07A"), 4)


func apply_slow(f: float, t: float) -> void:
	if dead:
		return
	slow_f = maxf(slow_f if slow_t > 0.0 else 0.0, f * (0.5 if is_boss else 1.0))
	slow_t = maxf(slow_t, t)


func _ready() -> void:
	add_to_group("enemies")
	if kind == "wraith":
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 4
		collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = body_radius * 0.9 if not is_boss else body_radius * 0.8
	sh.height = 1.7
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	_model = ModelFactory.enemy(kind)
	add_child(_model)
	_model.scale = _base_scale()
	_build_bar()
	if is_boss:
		_bar.visible = true
		_build_boss_label()
	rotation.y = randf() * TAU
	_wander_t = randf() * 2.0


func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, float(def["height"]) * scale_mult + 0.45, 0)
	_bar.visible = false
	add_child(_bar)
	var bg := Sprite3D.new()
	bg.texture = Fx.white_texture()
	bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg.modulate = Palette.NIGHT
	bg.pixel_size = 0.0125
	bg.scale = Vector3(11.0, 1.45, 1.0)
	bg.no_depth_test = true
	bg.render_priority = 1
	_bar.add_child(bg)
	_bar_fill = Sprite3D.new()
	_bar_fill.texture = Fx.white_texture()
	_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_fill.modulate = Palette.BLOOD.lightened(0.15)
	_bar_fill.pixel_size = 0.0125
	_bar_fill.scale = Vector3(10.6, 1.0, 1.0)
	_bar_fill.centered = false
	_bar_fill.offset = Vector2(-4, -4)
	_bar_fill.region_enabled = true
	_bar_fill.region_rect = Rect2(0, 0, 8, 8)
	_bar_fill.no_depth_test = true
	_bar_fill.render_priority = 2
	_bar.add_child(_bar_fill)


func _build_boss_label() -> void:
	var l := Label3D.new()
	l.text = boss_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.012
	l.font_size = 40
	l.outline_size = 10
	l.modulate = Palette.GOLD
	l.position = Vector3(0, 0.55, 0)
	_bar.add_child(l)


func _fx_parent() -> Node:
	return _world_root if _world_root != null else get_parent()


# ---------- ШІ ----------

func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_knock = _knock.move_toward(Vector3.ZERO, 22.0 * delta)
	if slow_t > 0.0:
		slow_t -= delta
	if stun_t > 0.0:
		stun_t -= delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			ModelFactory.set_flash(_model, false)
	if _bar.visible:
		_bar_t -= delta
		if _bar_t <= 0.0 and hp >= max_hp:
			_bar.visible = false

	var ok := target != null and is_instance_valid(target) and not target.dead
	var to_t := Vector3.ZERO
	var dist := 999.0
	if ok:
		to_t = target.global_position - global_position
		to_t.y = 0.0
		dist = to_t.length()
	var dir := to_t.normalized() if dist > 0.01 else Vector3.ZERO

	_desired = Vector3.ZERO
	if stun_t > 0.0:
		state = State.CHASE if state == State.WINDUP else state
	else:
		_run_state(delta, ok, dist, dir)
	if slow_t > 0.0:
		_desired *= (1.0 - slow_f)
	_post_move(delta, ok, dist, dir)


func _run_state(delta: float, ok: bool, dist: float, dir: Vector3) -> void:
	match state:
		State.IDLE:
			_do_idle(delta, ok, dist, dir)
		State.CHASE:
			_do_chase(delta, ok, dist, dir)
		State.WINDUP:
			_do_windup(delta, ok, dist, dir)
		State.TRANSFORM:
			_do_transform(delta)


func _post_move(delta: float, ok: bool, dist: float, dir: Vector3) -> void:
	# відштовхування від інших ворогів
	var push := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self:
			continue
		var oe: Enemy = o
		var off := global_position - oe.global_position
		off.y = 0.0
		var d := off.length()
		if d < 1.1 and d > 0.01:
			push += off.normalized() * (1.1 - d) * 3.0
	velocity = _desired + _knock + push
	move_and_slide()
	position.y = 0.0

	# повернення й «ходьба»
	var face := Vector3(_desired.x, 0, _desired.z)
	if state == State.WINDUP or (state == State.CHASE and ok and dist < 3.0):
		face = dir
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), minf(1.0, 10.0 * delta))
	var moving := _desired.length() > 0.3
	if kind == "wraith":
		_model.position.y = 0.35 + sin(_t * 2.4) * 0.18
	else:
		_model.position.y = absf(sin(_t * 9.0)) * 0.06 if moving else 0.0
	if state != State.WINDUP and state != State.TRANSFORM:
		_model.scale = _model.scale.lerp(_base_scale(), 12.0 * delta)


func _base_scale() -> Vector3:
	return Vector3.ONE * (1.1 if is_beast else 1.0) * scale_mult


func _do_idle(delta: float, ok: bool, dist: float, dir: Vector3) -> void:
	if ok and dist < float(def["aggro"]):
		state = State.CHASE
		return
	_wander_t -= delta
	var off_home := home - global_position
	off_home.y = 0.0
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.5)
		if randf() < 0.4:
			_wander_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			_wander_dir = Vector3(cos(a), 0, sin(a))
		if off_home.length() > 6.0:
			_wander_dir = off_home.normalized()
	_desired = _wander_dir * speed * 0.35


func _do_chase(_delta: float, ok: bool, dist: float, dir: Vector3) -> void:
	if not ok or dist > float(def["aggro"]) * 1.9:
		state = State.IDLE
		return
	var rng := float(def["range"])
	if bool(def["ranged"]):
		var kmin := float(def["keep_min"])
		var kmax := float(def["keep_max"])
		if dist < kmin:
			_desired = -dir * speed
		elif dist > kmax:
			_desired = dir * speed
		else:
			_desired = dir.rotated(Vector3.UP, PI / 2.0) * speed * 0.6 * _strafe
		if _attack_cd <= 0.0 and dist <= rng:
			_begin_windup()
	else:
		if dist > rng:
			_desired = dir * speed
		elif _attack_cd <= 0.0:
			_begin_windup()


func _begin_windup() -> void:
	state = State.WINDUP
	_state_t = float(def["windup"])


func _do_windup(delta: float, ok: bool, dist: float, dir: Vector3) -> void:
	_state_t -= delta
	# «Натяжка» удару: тіло стискається, потім пружинить.
	var k := 1.0 - clampf(_state_t / maxf(float(def["windup"]), 0.01), 0.0, 1.0)
	_model.scale = _base_scale() * Vector3(1.0 + 0.1 * k, 1.0 - 0.12 * k, 1.0 + 0.1 * k)
	if _state_t > 0.0:
		return
	state = State.CHASE
	_model.scale = _base_scale()
	var cd := float(def["cooldown"]) * (0.7 if is_beast else 1.0)
	_attack_cd = cd * randf_range(0.9, 1.15)
	if not ok:
		return
	if bool(def["ranged"]):
		_fire_bolt(dir)
	else:
		if dist <= float(def["range"]) + 0.7:
			target.take_damage(dmg, global_position, 6.0 if is_beast else 4.0)
			_knock = dir * 4.0   # короткий випад уперед


func _fire_bolt(dir: Vector3) -> void:
	var pr := Projectile.new()
	pr.team = "enemy"
	var col := Color(str(def.get("bolt", "A8F0FF")))
	if kind == "archer":
		pr.add_child(ModelFactory.arrow())
	else:
		pr.add_child(ModelFactory.bolt(col, 1.2))
	pr.velocity = dir * (11.0 if kind == "archer" else 7.5)
	pr.life = 3.0
	pr.radius = 0.4
	pr.spark_color = col
	var d := dmg
	var drain := float(def.get("mana_drain", 0.0))
	var from := global_position
	pr.hit_callback = func(t: Node) -> void:
		if is_instance_valid(t):
			var pl := t as Player
			pl.take_damage(d, from, 2.0)
			if drain > 0.0:
				pl.drain_mana(drain)
	_fx_parent().add_child(pr)
	pr.global_position = global_position + Vector3(0, 1.4, 0) + dir * 0.6
	if kind == "archer":
		pr.look_at(pr.global_position + dir, Vector3.UP)


func _do_transform(delta: float) -> void:
	_state_t -= delta
	_model.scale = _base_scale() * (1.0 + 0.08 * sin(_state_t * 40.0))
	if _state_t > 0.0:
		return
	_become_beast()
	state = State.CHASE


func _become_beast() -> void:
	is_beast = true
	if _model != null:
		_model.queue_free()
	_model = ModelFactory.werewolf_beast()
	add_child(_model)
	speed *= float(def["beast_speed"])
	dmg *= float(def["beast_dmg"])
	Fx.ring_burst(_fx_parent(), global_position, 2.5, Palette.BLOOD, 0.5)
	Fx.sparks(_fx_parent(), global_position + Vector3(0, 1, 0), Color("FFD23F"), 12)
	_attack_cd = 0.3


# ---------- Шкода й смерть ----------

func take_damage(amount: float, from_pos: Vector3, crit: bool = false, knock_force: float = 3.0) -> void:
	if dead:
		return
	hp -= amount
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01 and state != State.TRANSFORM:
		_knock = away.normalized() * knock_force
	if amount >= 1.0:
		var txt := str(int(round(amount)))
		if crit:
			txt += "!"
		Fx.damage_number(_fx_parent(), global_position + Vector3(0, float(def["height"]) * scale_mult + 0.5, 0), txt,
				Palette.GOLD if crit else Palette.LINEN, crit)
	ModelFactory.set_flash(_model, true)
	_flash_t = 0.08
	_bar.visible = true
	_bar_t = 4.0
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fill.region_rect = Rect2(0, 0, maxf(0.1, 8.0 * ratio), 8)
	# ворог одразу помічає героя
	if state == State.IDLE:
		state = State.CHASE
	if hp <= 0.0:
		_die()
		return
	if kind == "werewolf" and not is_beast and state != State.TRANSFORM and hp <= max_hp * 0.5:
		state = State.TRANSFORM
		_state_t = 0.8


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	_bar.visible = false
	Fx.sparks(_fx_parent(), global_position + Vector3(0, 1.0, 0), Palette.TURQUOISE if kind == "wraith" else Palette.ASH, 12)
	Fx.damage_number(_fx_parent(), global_position + Vector3(0, float(def["height"]) * scale_mult + 1.0, 0), "+%d" % xp_reward, Palette.XP_COLOR.lightened(0.2), true)
	died.emit(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_model, "scale", Vector3(1.0, 0.05, 1.0), 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
