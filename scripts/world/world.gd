## Єдина локація пробної версії: долина навколо Капища, обгороджена скелями, де блукають вороги Ордену.
class_name GameWorld
extends Node3D

signal player_died_signal
signal warmed

const ARENA_RADIUS := 42.0
const CAM_YAW_DEG := 45.0
const CAM_PITCH_DEG := -52.0
const CAM_DISTANCE := 17.0
const DEATH_DELAY := 2.6
const RESPAWN_CHECK := 4.0
const TARGET_COUNTS := {"novice": 6, "werewolf": 4, "wraith": 3}
const AUTOSAVE_SECONDS := 20.0
const EXPLORE_RADIUS := 9.0
const CLIFF_STEP := 3.3
## Виходи з долини. Поки зачинені: торкнувшись тригера, гравець бачить «Шлях закритий».
## angle_deg — напрям від Капища на площині (x, z); цей напрям на екрані дивиться «вгору».
const EXITS := [
	{"id": "forest_path", "name": "Стежка до лісу", "angle_deg": 225.0, "closed": true},
]
const EXIT_GAP_DEG := 8.0
const EXIT_TRIGGER_R := 3.4
const EXIT_TRIGGER_DIST := 38.6
const CLOSED_TEXT := "Шлях закритий"

var player: Player
var camera: Camera3D
var hud: Hud
var shrine: Shrine
var exit_gates: Array = []
var _tree_points: Array = []
var _respawn_t := 0.0
var _cam_pos := Vector3.ZERO
var _enemy_root: Node3D
var _loot_root: Node3D
var _death_running := false
var _save_t := 0.0
var _explore_t := 0.0
var _exit_cd := 0.0
var _rng := RandomNumberGenerator.new()
var is_warmed := false
var skip_warmup := false


func _ready() -> void:
	_rng.randomize()
	if not GameState.has_hero:
		GameState.new_hero("Мандрівник", "perun", "druzhynnyk")
	_build_environment()
	var dirs: Array = []
	for e in EXITS:
		var a := deg_to_rad(float(e["angle_deg"]))
		dirs.append(Vector2(cos(a), sin(a)))
	add_child(Terrain.build(ARENA_RADIUS, dirs))
	_build_props()
	_build_exits()
	shrine = Shrine.new()
	shrine.name = "Shrine"
	add_child(shrine)
	_enemy_root = Node3D.new()
	_enemy_root.name = "Enemies"
	add_child(_enemy_root)
	_loot_root = Node3D.new()
	_loot_root.name = "Loot"
	add_child(_loot_root)
	_build_player()
	_build_camera()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player, self)
	GameState.leveled_up.connect(_on_level_up)
	_spawn_initial()
	GameState.mark_explored(Vector2(player.position.x, player.position.z), EXPLORE_RADIUS)
	GameState.save_game()
	if skip_warmup:
		is_warmed = true
		warmed.emit()
	else:
		_warm_up.call_deferred()


func _exit_tree() -> void:
	if GameState.leveled_up.is_connected(_on_level_up):
		GameState.leveled_up.disconnect(_on_level_up)


# ---------- Побудова світу ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1F2A25")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("B7B3B0")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("2D3A33")
	env.fog_density = 0.010
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Єдине сонце без тіней: усе тіньове лише в кольорі вершин і загальному світлі.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color("FFE2BA")
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	add_child(sun)


func exit_dir(i: int) -> Vector2:
	var a := deg_to_rad(float(EXITS[i]["angle_deg"]))
	return Vector2(cos(a), sin(a))


## Точка перед брамою, де спрацьовує тригер (x, z).
func exit_trigger_pos(i: int) -> Vector2:
	return exit_dir(i) * EXIT_TRIGGER_DIST


func _near_exit(a: float) -> bool:
	for e in EXITS:
		var d := absf(wrapf(a - deg_to_rad(float(e["angle_deg"])), -PI, PI))
		if d < deg_to_rad(EXIT_GAP_DEG):
			return true
	return false


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var pines0: Array = []
	var pines1: Array = []
	var birches: Array = []
	var deads: Array = []
	var rocks: Array = []
	var cliffs: Array = []
	var stones: Array = []
	var grass: Array = []
	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)

	# --- межа: суцільне кільце скель (без прогалин, крім брами) ---
	var ring_r := ARENA_RADIUS + 1.6
	var n := int(ceil(TAU * ring_r / CLIFF_STEP))
	for i in range(n):
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.02, 0.02)
		if _near_exit(a):
			continue
		var rr := ring_r + rng.randf_range(-0.6, 0.9)
		var s := rng.randf_range(1.15, 1.7)
		cliffs.append(LowPoly.xf(Vector3(cos(a) * rr, 0, sin(a) * rr), Vector3(0, rng.randf() * 360.0, 0), Vector3(s, s * rng.randf_range(0.9, 1.5), s)))
	# другий ряд скель, щоб не було просвітів
	for i in range(n):
		var a2 := TAU * (float(i) + 0.5) / float(n)
		if _near_exit(a2):
			continue
		var rr2 := ring_r + 3.0 + rng.randf_range(0.0, 1.5)
		var s2 := rng.randf_range(1.4, 2.0)
		cliffs.append(LowPoly.xf(Vector3(cos(a2) * rr2, 0, sin(a2) * rr2), Vector3(0, rng.randf() * 360.0, 0), Vector3(s2, s2 * rng.randf_range(1.0, 1.6), s2)))
	# купи каміння при підніжжі
	for i in range(int(n * 0.9)):
		var a3 := rng.randf() * TAU
		if _near_exit(a3):
			continue
		var r3 := ARENA_RADIUS - rng.randf_range(0.2, 1.8)
		var s3 := rng.randf_range(0.9, 1.6)
		stones.append(LowPoly.xf(Vector3(cos(a3) * r3, 0, sin(a3) * r3), Vector3(0, rng.randf() * 360.0, 0), Vector3(s3, s3, s3)))
	# щільний ліс за скелями
	for i in range(240):
		var a4 := rng.randf() * TAU
		if _near_exit(a4):
			continue
		var r4 := rng.randf_range(ARENA_RADIUS + 4.5, ARENA_RADIUS + 16.0)
		var t4 := LowPoly.xf(Vector3(cos(a4) * r4, 0, sin(a4) * r4), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(1.1, 1.8))
		if rng.randf() < 0.6:
			pines0.append(t4)
		else:
			pines1.append(t4)
	# стіна дерев безпосередньо за скелями — ще густіше, ніж далі
	for i in range(110):
		var a5 := rng.randf() * TAU
		if _near_exit(a5):
			continue
		var r5 := rng.randf_range(ARENA_RADIUS + 2.4, ARENA_RADIUS + 5.0)
		pines1.append(LowPoly.xf(Vector3(cos(a5) * r5, 0, sin(a5) * r5), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(1.2, 1.7)))

	# --- дерева й каміння в долині (з колізією) ---
	var placed := 0
	var guard := 0
	var exit_clear: Array = []
	for i in range(EXITS.size()):
		exit_clear.append(exit_trigger_pos(i))
	while placed < 52 and guard < 900:
		guard += 1
		var a6 := rng.randf() * TAU
		var r6 := rng.randf_range(9.0, ARENA_RADIUS - 5.0)
		var p := Vector3(cos(a6) * r6, 0, sin(a6) * r6)
		if _too_close(p, 4.0) or _near_exit_point(p, 9.0):
			continue
		_tree_points.append(p)
		placed += 1
		var t := LowPoly.xf(p, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.85, 1.3))
		var pick := rng.randf()
		if pick < 0.40:
			pines0.append(t)
		elif pick < 0.72:
			pines1.append(t)
		elif pick < 0.90:
			birches.append(t)
		else:
			deads.append(t)
		_add_collider(colliders, p, 0.5, 3.0)
	var rplaced := 0
	guard = 0
	while rplaced < 16 and guard < 400:
		guard += 1
		var a7 := rng.randf() * TAU
		var r7 := rng.randf_range(8.0, ARENA_RADIUS - 4.0)
		var p3 := Vector3(cos(a7) * r7, 0, sin(a7) * r7)
		if _too_close(p3, 2.4) or _near_exit_point(p3, 8.0):
			continue
		_tree_points.append(p3)
		rplaced += 1
		rocks.append(LowPoly.xf(p3, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.8, 1.6)))
		_add_collider(colliders, p3, 0.8, 1.2)
	# трава — тільки одна тонка зелена трава, без квітів
	for i in range(220):
		var a8 := rng.randf() * TAU
		var r8 := rng.randf_range(5.0, ARENA_RADIUS - 2.0)
		grass.append(LowPoly.xf(Vector3(cos(a8) * r8, 0, sin(a8) * r8), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.8, 1.5)))

	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var sets := [[Props.pine_mesh(0), pines0], [Props.pine_mesh(1), pines1], [Props.birch_mesh(), birches],
		[Props.dead_tree_mesh(), deads], [Props.rock_mesh(), rocks], [Props.cliff_mesh(), cliffs],
		[Props.stones_mesh(), stones], [Props.grass_mesh(), grass]]
	for s in sets:
		if (s[1] as Array).size() > 0:
			root.add_child(Props.multimesh(s[0], s[1]))


func _add_collider(parent: StaticBody3D, p: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = p + Vector3(0, h * 0.5, 0)
	parent.add_child(cs)


func _near_exit_point(p: Vector3, d: float) -> bool:
	for i in range(EXITS.size()):
		var tp := exit_trigger_pos(i)
		# коридор від Капища до брами
		var dir := exit_dir(i)
		var flat := Vector2(p.x, p.z)
		var along := flat.dot(dir)
		var lateral := absf(flat.x * dir.y - flat.y * dir.x)
		if along > 6.0 and lateral < 3.2:
			return true
		if flat.distance_to(tp) < d:
			return true
	return false


func _too_close(p: Vector3, d: float) -> bool:
	for q in _tree_points:
		if (q as Vector3).distance_to(p) < d:
			return true
	return false


func _build_exits() -> void:
	for i in range(EXITS.size()):
		var g := ExitGate.new()
		g.name = "Gate_" + str(EXITS[i]["id"])
		add_child(g)
		var dir := exit_dir(i)
		g.position = Vector3(dir.x, 0, dir.y) * (ARENA_RADIUS + 1.3)
		g.rotation.y = atan2(-dir.x, -dir.y)
		exit_gates.append(g)
		# валуни по боках брами
		for sx: float in [-1.0, 1.0]:
			var side := Vector2(-dir.y, dir.x) * sx
			var pos := dir * (ARENA_RADIUS + 1.0) + side * 4.3
			var mesh := MeshInstance3D.new()
			mesh.mesh = Props.cliff_mesh()
			mesh.material_override = LowPoly.vc_material()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.position = Vector3(pos.x, 0, pos.y)
			mesh.scale = Vector3(1.5, 1.35, 1.5)
			add_child(mesh)


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
	camera.far = 150.0
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


# ---------- Прогрів: усі вигляди, що зʼявляються пізніше, показуємо заздалегідь ----------

## Причина мікрозависань у 0.1: перша поява ворога, сяйва, спрайта чи напису вимагала
## компіляції шейдера просто посеред гри. Тепер усе це один раз показується за темною заслоною.
func _warm_up() -> void:
	if not is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	var cr := ColorRect.new()
	cr.color = Palette.NIGHT
	FolkTheme.fullscreen(cr)
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(cr)
	var l := FolkTheme.label("Пращури збираються…", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	FolkTheme.fullscreen(l)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cr.add_child(l)
	add_child(layer)
	var holder := Node3D.new()
	holder.name = "WarmUp"
	add_child(holder)
	var base := player.global_position
	var i := 0
	for kind in ["novice", "werewolf", "wraith", "beast"]:
		var m := ModelFactory.enemy(kind)
		holder.add_child(m)
		m.global_position = base + Vector3(-3.0 + float(i) * 2.0, 0, -2.5)
		ModelFactory.set_flash(m, true)
		ModelFactory.set_flash(m, false)
		i += 1
	var bar := Node3D.new()
	holder.add_child(bar)
	bar.global_position = base + Vector3(0, 2, -3)
	for c in [Palette.NIGHT, Palette.BLOOD]:
		var sp := Sprite3D.new()
		sp.texture = Fx.white_texture()
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.modulate = c
		sp.no_depth_test = true
		sp.pixel_size = 0.0125
		bar.add_child(sp)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var j := 0
	for kind in [LootDrop.KIND_GOLD, LootDrop.KIND_HP, LootDrop.KIND_MANA]:
		LootDrop.make_drop(holder, base + Vector3(-2.0 + float(j) * 1.0, 0, 3.4), kind, 1, {}, rng).set_process(false)
		j += 1
	for slot in Items.SLOTS:
		for r in [0, Items.RARITIES.size() - 1]:
			LootDrop.make_drop(holder, base + Vector3(-3.0 + float(j) * 0.7, 0, 4.2), LootDrop.KIND_ITEM, 1, Items.generate(1, rng, slot, r), rng).set_process(false)
			j += 1
	Fx.ring_burst(holder, base + Vector3(0, 0, -1), 2.0, Palette.GOLD, 0.2)
	Fx.sparks(holder, base + Vector3(0, 1, -1), Palette.TURQUOISE, 6)
	Fx.lightning(holder, base + Vector3(2, 0, -1))
	Fx.damage_number(holder, base + Vector3(0, 2, -1), "0", Palette.LINEN, true)
	for k in range(4):
		await get_tree().process_frame
	holder.queue_free()
	layer.queue_free()
	is_warmed = true
	warmed.emit()


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
		var r := _rng.randf_range(12.0, ARENA_RADIUS - 4.0)
		pos = Vector3(cos(a) * r, 0, sin(a) * r)
		if _too_close(pos, 1.6):
			continue
		if away_from_player and pos.distance_to(player.global_position) < 16.0:
			continue
		if pos.distance_to(player.global_position) < 9.0:
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
	LootDrop.drop_from_enemy(_loot_root, e.global_position, e.kind, e.level, _rng)


# ---------- Дотик по світу ----------

## Дотик (екранна точка) по здобичі на землі: вона летить до героя. Повертає true, якщо влучили.
func tap_world(screen_pos: Vector2) -> bool:
	if camera == null or player == null or player.dead:
		return false
	var o := camera.project_ray_origin(screen_pos)
	var n := camera.project_ray_normal(screen_pos)
	if absf(n.y) < 0.001:
		return false
	var t := -o.y / n.y
	if t <= 0.0:
		return false
	var hit := o + n * t
	var best: LootDrop = null
	var bd := 2.0
	for d in get_tree().get_nodes_in_group("loot"):
		var ld := d as LootDrop
		if ld == null or ld.attract:
			continue
		var dd := Vector2(ld.global_position.x - hit.x, ld.global_position.z - hit.z).length()
		if dd < bd:
			bd = dd
			best = ld
	if best == null:
		return false
	best.attract = true
	return true


## Підібрати все біля героя одним дотиком по кнопці (необовʼязково).
func loot_near(radius: float) -> int:
	var n := 0
	for d in get_tree().get_nodes_in_group("loot"):
		var ld := d as LootDrop
		if ld != null and ld.global_position.distance_to(player.global_position) < radius:
			ld.attract = true
			n += 1
	return n


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
		# відкриття мапи
		_explore_t += delta
		if _explore_t >= 0.25:
			_explore_t = 0.0
			if GameState.mark_explored(Vector2(player.global_position.x, player.global_position.z), EXPLORE_RADIUS):
				if hud != null:
					hud.map_dirty()
		_check_exits(delta)
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


## Тригер виходу: поки шлях зачинений, лише повідомлення.
func _check_exits(delta: float) -> void:
	_exit_cd = maxf(0.0, _exit_cd - delta)
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for i in range(EXITS.size()):
		if pp.distance_to(exit_trigger_pos(i)) < EXIT_TRIGGER_R and _exit_cd <= 0.0:
			_exit_cd = 3.5
			on_exit_touched(i)


func on_exit_touched(i: int) -> void:
	if bool(EXITS[i].get("closed", true)):
		if hud != null:
			hud.toast(CLOSED_TEXT)
		Fx.damage_number(self, Vector3(player.global_position.x, 2.6, player.global_position.z), CLOSED_TEXT, Palette.GOLD, true)


func _process(delta: float) -> void:
	if player == null or camera == null:
		return
	_cam_pos = _cam_pos.lerp(player.global_position, minf(1.0, 8.0 * delta))
	_place_camera(_cam_pos)


func _clamp_to_arena(n: Node3D) -> void:
	var flat := Vector2(n.global_position.x, n.global_position.z)
	var limit := ARENA_RADIUS - 1.2
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
