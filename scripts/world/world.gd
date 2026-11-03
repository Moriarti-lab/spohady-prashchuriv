## Єдина локація пробної версії: долина навколо Капища, де блукають вороги Ордену.
class_name GameWorld
extends Node3D

signal player_died_signal

const ARENA_RADIUS := 34.0
const CAM_YAW_DEG := 45.0
const CAM_PITCH_DEG := -52.0
const CAM_DISTANCE := 17.0
const DEATH_DELAY := 2.6
const RESPAWN_CHECK := 5.0
const TARGET_COUNTS := {"novice": 4, "werewolf": 3, "wraith": 2}
const AUTOSAVE_SECONDS := 20.0

var player: Player
var camera: Camera3D
var hud: Hud
var shrine: Shrine
var _tree_points: Array = []
var _respawn_t := 0.0
var _cam_pos := Vector3.ZERO
var _enemy_root: Node3D
var _death_running := false
var _save_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if not GameState.has_hero:
		GameState.new_hero("Мандрівник", "perun", "druzhynnyk")
	_build_environment()
	add_child(Terrain.build(ARENA_RADIUS))
	_build_props()
	shrine = Shrine.new()
	shrine.name = "Shrine"
	add_child(shrine)
	_enemy_root = Node3D.new()
	_enemy_root.name = "Enemies"
	add_child(_enemy_root)
	_build_player()
	_build_camera()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player, self)
	GameState.leveled_up.connect(_on_level_up)
	_spawn_initial()
	GameState.save_game()


func _exit_tree() -> void:
	if GameState.leveled_up.is_connected(_on_level_up):
		GameState.leveled_up.disconnect(_on_level_up)


# ---------- Побудова світу ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2B2A38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("A99AB8")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("3A3548")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color("FFD7A6")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var pines0: Array = []
	var pines1: Array = []
	var birches: Array = []
	var deads: Array = []
	var rocks: Array = []
	var flowers := {}
	for c in [Palette.EMBROIDERY, Palette.GOLD, Palette.LINEN, Color("8A6FD0")]:
		flowers[c] = []
	var grass: Array = []
	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)

	# дерева в долині (з колізією)
	var placed := 0
	var guard := 0
	while placed < 46 and guard < 600:
		guard += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.5, ARENA_RADIUS - 2.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if _too_close(p, 3.5):
			continue
		_tree_points.append(p)
		placed += 1
		var t := LowPoly.xf(p, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.85, 1.3))
		var pick := rng.randf()
		if pick < 0.40:
			pines0.append(t)
		elif pick < 0.70:
			pines1.append(t)
		elif pick < 0.88:
			birches.append(t)
		else:
			deads.append(t)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.5
		sh.height = 3.0
		cs.shape = sh
		cs.position = p + Vector3(0, 1.5, 0)
		colliders.add_child(cs)
	# густий ліс на краю (без колізії; межу тримає код)
	for i in range(150):
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(ARENA_RADIUS - 0.5, ARENA_RADIUS + 9.0)
		var p2 := Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		var t2 := LowPoly.xf(p2, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(1.0, 1.6))
		if rng.randf() < 0.55:
			pines0.append(t2)
		else:
			pines1.append(t2)
	# каміння
	for i in range(18):
		var a3 := rng.randf() * TAU
		var r3 := rng.randf_range(7.0, ARENA_RADIUS - 1.0)
		var p3 := Vector3(cos(a3) * r3, 0, sin(a3) * r3)
		if _too_close(p3, 2.0):
			continue
		_tree_points.append(p3)
		rocks.append(LowPoly.xf(p3, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.8, 1.6)))
		var cs2 := CollisionShape3D.new()
		var sh2 := CylinderShape3D.new()
		sh2.radius = 0.8
		sh2.height = 1.2
		cs2.shape = sh2
		cs2.position = p3 + Vector3(0, 0.6, 0)
		colliders.add_child(cs2)
	# квіти й трава
	var keys := flowers.keys()
	for i in range(140):
		var a4 := rng.randf() * TAU
		var r4 := rng.randf_range(5.5, ARENA_RADIUS - 2.0)
		var key: Color = keys[rng.randi() % keys.size()]
		flowers[key].append(LowPoly.xf(Vector3(cos(a4) * r4, 0, sin(a4) * r4), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.8, 1.4)))
	for i in range(260):
		var a5 := rng.randf() * TAU
		var r5 := rng.randf_range(3.5, ARENA_RADIUS)
		grass.append(LowPoly.xf(Vector3(cos(a5) * r5, 0, sin(a5) * r5), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.8, 1.6)))

	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	if pines0.size() > 0:
		root.add_child(Props.multimesh(Props.pine_mesh(0), pines0, true))
	if pines1.size() > 0:
		root.add_child(Props.multimesh(Props.pine_mesh(1), pines1, true))
	if birches.size() > 0:
		root.add_child(Props.multimesh(Props.birch_mesh(), birches, true))
	if deads.size() > 0:
		root.add_child(Props.multimesh(Props.dead_tree_mesh(), deads, true))
	if rocks.size() > 0:
		root.add_child(Props.multimesh(Props.rock_mesh(), rocks, true))
	for c in flowers.keys():
		if flowers[c].size() > 0:
			root.add_child(Props.multimesh(Props.flower_mesh(c), flowers[c], false))
	root.add_child(Props.multimesh(Props.grass_mesh(), grass, false))


func _too_close(p: Vector3, d: float) -> bool:
	for q in _tree_points:
		if (q as Vector3).distance_to(p) < d:
			return true
	return false


func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.set_world_root(self)
	player.position = Vector3(0, 0, 5.5)
	player.input_yaw = -deg_to_rad(CAM_YAW_DEG)
	player.rotation.y = 0.0
	player.died.connect(_on_player_died)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 38.0
	camera.near = 1.0
	camera.far = 140.0
	camera.current = true
	add_child(camera)
	_cam_pos = player.position
	_place_camera(_cam_pos)


func _place_camera(focus: Vector3) -> void:
	var yaw := deg_to_rad(CAM_YAW_DEG)
	var pitch := deg_to_rad(CAM_PITCH_DEG)
	var offset := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(0, 0, CAM_DISTANCE)
	camera.global_position = focus + Vector3(0, 1.0, 0) + offset
	camera.rotation = Vector3(pitch, yaw, 0)


# ---------- Вороги ----------

func _enemy_count(kind: String) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).kind == kind and not (e as Enemy).dead:
			n += 1
	return n


func _spawn_initial() -> void:
	for kind in TARGET_COUNTS.keys():
		for i in range(int(TARGET_COUNTS[kind])):
			_spawn_enemy(kind, false)


func _spawn_enemy(kind: String, away_from_player: bool) -> void:
	var pos := Vector3.ZERO
	for attempt in range(30):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(11.0, ARENA_RADIUS - 3.0)
		pos = Vector3(cos(a) * r, 0, sin(a) * r)
		if _too_close(pos, 1.6):
			continue
		if away_from_player and pos.distance_to(player.global_position) < 15.0:
			continue
		if pos.distance_to(player.global_position) < 8.0:
			continue
		break
	var e := Enemy.new()
	e.name = "Enemy_" + kind
	var lvl := maxi(1, GameState.level - _rng.randi_range(0, 1))
	e.setup(kind, lvl, player, pos, self)
	_enemy_root.add_child(e)
	e.global_position = pos
	e.died.connect(_on_enemy_died)


func _on_enemy_died(e: Enemy) -> void:
	GameState.add_xp(e.xp_reward)


# ---------- Цикл ----------

func _physics_process(delta: float) -> void:
	# межа долини
	_clamp_to_arena(player)
	for e in get_tree().get_nodes_in_group("enemies"):
		_clamp_to_arena(e)
	# Капище лікує
	if not player.dead:
		var d := Vector2(player.global_position.x, player.global_position.z).length()
		if d < Shrine.HEAL_RADIUS:
			var heal_rate := HeroStats.max_hp() * 0.12
			if player.hp < HeroStats.max_hp():
				player.heal(heal_rate * delta, false)
			player.mana = minf(HeroStats.max_mana(), player.mana + HeroStats.max_mana() * 0.10 * delta)
	# вороги знову з'являються
	_respawn_t += delta
	if _respawn_t >= RESPAWN_CHECK:
		_respawn_t = 0.0
		for kind in TARGET_COUNTS.keys():
			if _enemy_count(kind) < int(TARGET_COUNTS[kind]):
				_spawn_enemy(kind, true)
				break
	# автозбереження
	_save_t += delta
	if _save_t >= AUTOSAVE_SECONDS:
		_save_t = 0.0
		GameState.save_game()


func _process(delta: float) -> void:
	if player == null or camera == null:
		return
	_cam_pos = _cam_pos.lerp(player.global_position, minf(1.0, 8.0 * delta))
	_place_camera(_cam_pos)


func _clamp_to_arena(n: Node3D) -> void:
	var flat := Vector2(n.global_position.x, n.global_position.z)
	var limit := ARENA_RADIUS - 1.0
	if flat.length() > limit:
		flat = flat.normalized() * limit
		n.global_position = Vector3(flat.x, n.global_position.y, flat.y)


# ---------- Смерть і рівні ----------

func _on_player_died() -> void:
	if _death_running:
		return
	_death_running = true
	player_died_signal.emit()
	var lost := GameState.apply_death_penalty()
	hud.show_death(lost)
	await get_tree().create_timer(DEATH_DELAY).timeout
	if not is_inside_tree():
		return
	_respawn_player()


func _respawn_player() -> void:
	var at := Vector3(0, 0, 5.0)
	# відганяємо ворогів від капища
	for e in get_tree().get_nodes_in_group("enemies"):
		var en: Enemy = e
		if en.global_position.distance_to(at) < 12.0:
			en.state = Enemy.State.IDLE
			var away := en.global_position - at
			away.y = 0.0
			var dir := away.normalized() if away.length() > 0.1 else Vector3.RIGHT
			en.global_position = at + dir * 14.0
	player.respawn(at)
	_cam_pos = at
	hud.hide_death()
	_death_running = false
	GameState.save_game()


func _on_level_up(new_level: int) -> void:
	player.restore_full()
	Fx.ring_burst(self, player.global_position, 5.0, Palette.GOLD, 0.7)
	Fx.sparks(self, player.global_position + Vector3(0, 1.0, 0), Palette.GOLD, 18)
	Fx.damage_number(self, player.global_position + Vector3(0, 2.8, 0), "Рівень %d!" % new_level, Palette.GOLD, true)
	hud.show_level_up(new_level)
