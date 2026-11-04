## Ігровий світ однієї локації: селище або бойова долина в кільці скель. Локацію задає GameState.location;
## перехід між локаціями перезавантажує сцену (меші землі й моделі кешуються, тож це швидко).
class_name GameWorld
extends Node3D

signal player_died_signal
signal warmed

const CAM_YAW_DEG := 45.0
const CAM_PITCH_DEG := -52.0
const CAM_DISTANCE := 17.0
const DEATH_DELAY := 2.6
const RESPAWN_CHECK := 4.0
const AUTOSAVE_SECONDS := 20.0
const EXPLORE_RADIUS := 9.0
const CLIFF_STEP := 3.3
const EXIT_GAP_DEG := 8.0
const EXIT_TRIGGER_R := 3.4
const INTERACT_R := 3.4
const HERB_PICKUP_R := 1.5

## Види, які вже «прогріті» в цьому запуску: шейдери скомпільовано, повторно не чекаємо.
static var warmed_kinds := {}

var player: Player
var camera: Camera3D
var hud: Hud
var shrine: Shrine
var exit_gates: Array = []
var loc_id := "village"
var loc: Dictionary = {}
var arena_radius := 42.0
var safe := false
var exits: Array = []                 # [{id, to, label, angle_deg, dir: Vector2}]
var interactables: Array = []         # [{kind: npc|chest, id, name, pos: Vector3, node: Node3D, ...}]
var herbs: Array = []                 # [{node, pos}]
var boss: Enemy = null
var instant_transition := false       # у тестах: без затемнення й перезавантаження сцени
var _tree_points: Array = []
var _respawn_t := 0.0
var _boss_t := 0.0
var _cam_pos := Vector3.ZERO
var _enemy_root: Node3D
var _loot_root: Node3D
var _death_running := false
var _save_t := 0.0
var _explore_t := 0.0
var _exit_cd := 1.5
var _transitioning := false
var _fade_rect: ColorRect
var _rng := RandomNumberGenerator.new()
var is_warmed := false
var skip_warmup := false
var is_cave := false
var cave_entrance := Vector3.INF
var _music_t := 0.0
var _pack_seq := 0
var _cave_won := false


func _ready() -> void:
	_rng.randomize()
	if not GameState.has_hero:
		GameState.new_hero("Мандрівник", "perun", "druzhynnyk")
	loc_id = GameState.location if Locations.has(GameState.location) else Locations.START
	loc = Locations.get_def(loc_id)
	is_cave = bool(loc.get("cave", false))
	if is_cave:
		loc = loc.duplicate(true)
		var cl := maxi(1, GameState.cave_level)
		loc["levels"] = [cl, cl + 2]
		loc["boss"]["level"] = cl + 3
		var back := GameState.cave_from if Locations.has(GameState.cave_from) else Locations.START
		for e in loc["exits"]:
			if str(e["to"]) == "@back":
				e["to"] = back
				e["label"] = "Назовні: %s" % Locations.get_def(back)["name"]
	arena_radius = float(loc["radius"])
	safe = bool(loc.get("safe", false))
	for e in loc["exits"]:
		var ex: Dictionary = (e as Dictionary).duplicate()
		var a := deg_to_rad(float(ex["angle_deg"]))
		ex["dir"] = Vector2(cos(a), sin(a))
		exits.append(ex)
	_build_environment()
	add_child(Terrain.build(loc_id))
	_build_props()
	_build_exits()
	_build_houses()
	shrine = Shrine.new()
	shrine.name = "Shrine"
	add_child(shrine)
	_enemy_root = Node3D.new()
	_enemy_root.name = "Enemies"
	add_child(_enemy_root)
	_loot_root = Node3D.new()
	_loot_root.name = "Loot"
	add_child(_loot_root)
	_build_npcs()
	_build_chests()
	_build_herbs()
	_build_cave_entrance()
	_build_player()
	_build_camera()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player, self)
	GameState.leveled_up.connect(_on_level_up)
	GameState.quest_changed.connect(_on_quest_changed)
	_spawn_initial()
	_spawn_boss()
	Sound.set_ambience(str(loc.get("amb", loc_id)))
	Sound.set_combat(false)
	Sound.start_music()
	GameState.mark_explored(Vector2(player.position.x, player.position.z), EXPLORE_RADIUS)
	GameState.save_game()
	_build_fade()
	if skip_warmup:
		is_warmed = true
		warmed.emit()
		_fade_in()
	else:
		_warm_up.call_deferred()
	if GameState.notice != "":
		var msg := GameState.notice
		GameState.notice = ""
		hud.toast.call_deferred(msg)


func _exit_tree() -> void:
	if GameState.leveled_up.is_connected(_on_level_up):
		GameState.leveled_up.disconnect(_on_level_up)
	if GameState.quest_changed.is_connected(_on_quest_changed):
		GameState.quest_changed.disconnect(_on_quest_changed)


# ---------- Побудова світу ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = loc["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("B7B3B0")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = loc["fog"]
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
	return exits[i]["dir"]


## Точка перед брамою, де спрацьовує тригер (x, z).
func exit_trigger_pos(i: int) -> Vector2:
	return exit_dir(i) * (arena_radius - EXIT_TRIGGER_R)


## Номер виходу, що веде в локацію `to` (-1, якщо немає).
func exit_index_to(to: String) -> int:
	for i in range(exits.size()):
		if str(exits[i]["to"]) == to:
			return i
	return -1


func _near_exit(a: float) -> bool:
	for e in exits:
		var d := absf(wrapf(a - deg_to_rad(float(e["angle_deg"])), -PI, PI))
		if d < deg_to_rad(EXIT_GAP_DEG):
			return true
	return false


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 + loc_id.hash() % 5000
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
	var R := arena_radius

	# --- межа: суцільне кільце скель (без прогалин, крім брам) ---
	var ring_r := R + 1.6
	var n := int(ceil(TAU * ring_r / CLIFF_STEP))
	for i in range(n):
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.02, 0.02)
		if _near_exit(a):
			continue
		var rr := ring_r + rng.randf_range(-0.6, 0.9)
		var s := rng.randf_range(1.15, 1.7)
		cliffs.append(LowPoly.xf(Vector3(cos(a) * rr, 0, sin(a) * rr), Vector3(0, rng.randf() * 360.0, 0), Vector3(s, s * rng.randf_range(0.9, 1.5), s)))
	for i in range(n):
		var a2 := TAU * (float(i) + 0.5) / float(n)
		if _near_exit(a2):
			continue
		var rr2 := ring_r + 3.0 + rng.randf_range(0.0, 1.5)
		var s2 := rng.randf_range(1.4, 2.0)
		cliffs.append(LowPoly.xf(Vector3(cos(a2) * rr2, 0, sin(a2) * rr2), Vector3(0, rng.randf() * 360.0, 0), Vector3(s2, s2 * rng.randf_range(1.0, 1.6), s2)))
	for i in range(int(n * 0.9)):
		var a3 := rng.randf() * TAU
		if _near_exit(a3):
			continue
		var r3 := R - rng.randf_range(0.2, 1.8)
		var s3 := rng.randf_range(0.9, 1.6)
		stones.append(LowPoly.xf(Vector3(cos(a3) * r3, 0, sin(a3) * r3), Vector3(0, rng.randf() * 360.0, 0), Vector3(s3, s3, s3)))
	# щільний ліс за скелями
	for i in range(200):
		var a4 := rng.randf() * TAU
		if _near_exit(a4):
			continue
		var r4 := rng.randf_range(R + 4.5, R + 16.0)
		var t4 := LowPoly.xf(Vector3(cos(a4) * r4, 0, sin(a4) * r4), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(1.1, 1.8))
		if rng.randf() < 0.6:
			pines0.append(t4)
		else:
			pines1.append(t4)
	for i in range(100):
		var a5 := rng.randf() * TAU
		if _near_exit(a5):
			continue
		var r5 := rng.randf_range(R + 2.4, R + 5.0)
		pines1.append(LowPoly.xf(Vector3(cos(a5) * r5, 0, sin(a5) * r5), Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(1.2, 1.7)))

	# --- місця, що лишаємо вільними: будинки, NPC, скрині, бос ---
	var reserved: Array = []
	for h in loc.get("houses", []):
		reserved.append([Vector3(float(h["pos"][0]), 0, float(h["pos"][1])), 6.0])
	for c in loc.get("chests", []):
		reserved.append([Vector3(float(c["pos"][0]), 0, float(c["pos"][1])), 3.0])
	for npc in loc.get("npcs", []):
		reserved.append([Vector3(float(npc["pos"][0]), 0, float(npc["pos"][1])), 3.0])
	if loc.has("boss"):
		reserved.append([Vector3(float(loc["boss"]["pos"][0]), 0, float(loc["boss"]["pos"][1])), 5.0])

	# --- дерева й каміння в долині (з колізією) ---
	var tree_target := int(loc.get("trees", 50))
	var mix: Array = loc.get("tree_mix", [0.4, 0.32, 0.18, 0.1])
	var placed := 0
	var guard := 0
	while placed < tree_target and guard < tree_target * 20:
		guard += 1
		var a6 := rng.randf() * TAU
		var r6 := rng.randf_range(9.0, R - 5.0)
		var p := Vector3(cos(a6) * r6, 0, sin(a6) * r6)
		if _too_close(p, 4.0) or _near_exit_point(p, 9.0) or _near_reserved(p, reserved):
			continue
		_tree_points.append(p)
		placed += 1
		var t := LowPoly.xf(p, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.85, 1.3))
		var pick := rng.randf()
		if pick < float(mix[0]):
			pines0.append(t)
		elif pick < float(mix[0]) + float(mix[1]):
			pines1.append(t)
		elif pick < float(mix[0]) + float(mix[1]) + float(mix[2]):
			birches.append(t)
		else:
			deads.append(t)
		_add_collider(colliders, p, 0.5, 3.0)
	var rplaced := 0
	guard = 0
	var rock_target := int(loc.get("rocks", 12))
	while rplaced < rock_target and guard < 400:
		guard += 1
		var a7 := rng.randf() * TAU
		var r7 := rng.randf_range(8.0, R - 4.0)
		var p3 := Vector3(cos(a7) * r7, 0, sin(a7) * r7)
		if _too_close(p3, 2.4) or _near_exit_point(p3, 8.0) or _near_reserved(p3, reserved):
			continue
		_tree_points.append(p3)
		rplaced += 1
		rocks.append(LowPoly.xf(p3, Vector3(0, rng.randf() * 360.0, 0), Vector3.ONE * rng.randf_range(0.8, 1.6)))
		_add_collider(colliders, p3, 0.8, 1.2)
	for i in range(int(loc.get("grass", 200))):
		var a8 := rng.randf() * TAU
		var r8 := rng.randf_range(5.0, R - 2.0)
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
	# болото: калюжі; руїни: уламки стін
	var puddles := int(loc.get("puddles", 0))
	for i in range(puddles):
		var pa := rng.randf() * TAU
		var pr := rng.randf_range(6.0, R - 5.0)
		var pp := Vector3(cos(pa) * pr, 0.0, sin(pa) * pr)
		if _near_exit_point(pp, 6.0) or _near_reserved(pp, reserved):
			continue
		var pu := Structures.puddle()
		pu.position = pp
		pu.rotation.y = rng.randf() * TAU
		pu.scale = Vector3.ONE * rng.randf_range(0.8, 1.7)
		root.add_child(pu)
	var walls := int(loc.get("ruin_walls", 0))
	guard = 0
	while walls > 0 and guard < 300:
		guard += 1
		var wa := rng.randf() * TAU
		var wr := rng.randf_range(8.0, R - 5.0)
		var wp := Vector3(cos(wa) * wr, 0.0, sin(wa) * wr)
		if _too_close(wp, 4.0) or _near_exit_point(wp, 9.0) or _near_reserved(wp, reserved):
			continue
		_tree_points.append(wp)
		walls -= 1
		var rw := Structures.ruin_wall()
		rw.position = wp
		rw.rotation.y = rng.randf() * TAU
		root.add_child(rw)
		_add_box_collider(colliders, wp, Vector3(3.4, 2.0, 0.8), rw.rotation.y)


func _near_reserved(p: Vector3, reserved: Array) -> bool:
	for r in reserved:
		if (r[0] as Vector3).distance_to(p) < float(r[1]):
			return true
	return false


func _add_collider(parent: StaticBody3D, p: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = p + Vector3(0, h * 0.5, 0)
	parent.add_child(cs)


func _add_box_collider(parent: StaticBody3D, p: Vector3, size: Vector3, yaw: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = p + Vector3(0, size.y * 0.5, 0)
	cs.rotation.y = yaw
	parent.add_child(cs)


func _near_exit_point(p: Vector3, d: float) -> bool:
	for i in range(exits.size()):
		var tp := exit_trigger_pos(i)
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
	for i in range(exits.size()):
		var g := ExitGate.new()
		g.name = "Gate_" + str(exits[i]["id"])
		g.label_text = str(exits[i]["label"])
		add_child(g)
		var dir := exit_dir(i)
		g.position = Vector3(dir.x, 0, dir.y) * (arena_radius + 1.3)
		g.rotation.y = atan2(-dir.x, -dir.y)
		exit_gates.append(g)
		for sx: float in [-1.0, 1.0]:
			var side := Vector2(-dir.y, dir.x) * sx
			var pos := dir * (arena_radius + 1.0) + side * 4.3
			var mesh := MeshInstance3D.new()
			mesh.mesh = Props.cliff_mesh()
			mesh.material_override = LowPoly.vc_material()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.position = Vector3(pos.x, 0, pos.y)
			mesh.scale = Vector3(1.5, 1.35, 1.5)
			add_child(mesh)
		# вказівник біля дороги: куди веде вихід
		var sp := dir * (arena_radius - 9.0) + Vector2(-dir.y, dir.x) * 3.2
		var sign := Structures.signpost("→ " + str(exits[i]["label"]).replace("До ", ""))
		sign.position = Vector3(sp.x, 0, sp.y)
		sign.rotation.y = atan2(-dir.x, -dir.y)
		add_child(sign)


## Будинки: живі в селищі, покинуті з потертим дахом у бойових локаціях. Мають колізію.
func _build_houses() -> void:
	var colliders := get_node_or_null("Colliders") as StaticBody3D
	for h in loc.get("houses", []):
		var m := Structures.house(str(h["kind"]))
		var p := Vector3(float(h["pos"][0]), 0, float(h["pos"][1]))
		m.position = p
		m.rotation.y = deg_to_rad(float(h.get("yaw", 0.0)))
		add_child(m)
		_tree_points.append(p)
		var big := 1.25 if str(h["kind"]) == "elder" else 1.0
		if colliders != null:
			_add_box_collider(colliders, p, Vector3(4.5 * big, 3.0, 3.7 * big), m.rotation.y)
		if str(h["kind"]) == "abandoned":
			var l := Label3D.new()
			l.text = str(h.get("name", "Покинута хата"))
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.font_size = 30
			l.pixel_size = 0.011
			l.outline_size = 10
			l.modulate = Palette.LINEN.darkened(0.15)
			l.outline_modulate = Palette.NIGHT
			l.position = p + Vector3(0, 5.2, 0)
			add_child(l)


func _build_npcs() -> void:
	var colliders := get_node_or_null("Colliders") as StaticBody3D
	for npc in loc.get("npcs", []):
		var p := Vector3(float(npc["pos"][0]), 0, float(npc["pos"][1]))
		var hat := "cap"
		match str(npc["id"]):
			"herbalist": hat = "hood"
			"elder": hat = "beard"
		# Мешканці села — анімовані моделі KayKit Adventurers (запасний варіант — простий меш).
		var rig_file := "Rogue"
		match str(npc["id"]):
			"herbalist": rig_file = "Mage"
			"elder": rig_file = "Barbarian"
			"smith", "merchant", "trader": rig_file = "Knight"
		var node: Node3D = RigModel.create(rig_file, 0.74)
		if node == null:
			node = Structures.npc(Color(str(npc["color"])), hat)
		node.position = p
		node.rotation.y = atan2(-p.x, -p.z) + (PI if node is RigModel else 0.0)       # дивиться на Капище
		add_child(node)
		_label_over(node, "%s\n%s" % [npc["name"], npc["role"]], 2.4, Palette.GOLD)
		if colliders != null:
			_add_collider(colliders, p, 0.45, 1.8)
		interactables.append({"kind": "npc", "id": str(npc["id"]), "name": str(npc["name"]), "pos": p, "node": node})


func _build_chests() -> void:
	for c in loc.get("chests", []):
		var id := str(c["id"])
		var p := Vector3(float(c["pos"][0]), 0, float(c["pos"][1]))
		var opened := GameState.chest_opened(id)
		var node := Structures.chest(opened)
		node.position = p
		node.rotation.y = deg_to_rad(float(c.get("yaw", 0.0)))
		add_child(node)
		var d := {"kind": "chest", "id": id, "name": "Скриня", "pos": p, "node": node, "def": c, "opened": opened}
		interactables.append(d)


func _build_herbs() -> void:
	var count := int(loc.get("herbs", 0))
	if count <= 0 or GameState.quest_state("herbs") == "done":
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tries := 0
	while herbs.size() < count and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, arena_radius - 5.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if _too_close(p, 2.5) or _near_exit_point(p, 8.0):
			continue
		var node := Structures.herb()
		node.position = p
		add_child(node)
		_tree_points.append(p)
		herbs.append({"node": node, "pos": p})


func _label_over(parent: Node3D, text: String, h: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 30
	l.pixel_size = 0.0095
	l.outline_size = 10
	l.modulate = col
	l.outline_modulate = Palette.NIGHT
	l.position = Vector3(0, h + 0.4, 0)
	l.no_depth_test = false
	parent.add_child(l)


func _spawn_position() -> Vector3:
	if GameState.arrive_from == "cave" and cave_entrance != Vector3.INF:
		return cave_entrance - cave_entrance.normalized() * 4.0
	if GameState.arrive_from != "":
		var i := exit_index_to(GameState.arrive_from)
		if i >= 0:
			var d := exit_dir(i)
			return Vector3(d.x, 0, d.y) * (arena_radius - 8.5)
	return Vector3(0, 0, 5.5)


func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.set_world_root(self)
	player.position = _spawn_position()
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


# ---------- Затемнення при переході ----------

func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	layer.name = "Fade"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Palette.NIGHT
	FolkTheme.fullscreen(_fade_rect)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0 if skip_warmup else 1.0
	layer.add_child(_fade_rect)
	add_child(layer)


func _fade_in() -> void:
	if _fade_rect == null or _fade_rect.modulate.a <= 0.0:
		return
	# Заслона має зникати й тоді, коли гра на паузі (наприклад, одразу відкрилося Древо з вибором
	# стартової навички). Без цього в 0.3.0 новий герой бачив чорний екран.
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade_rect, "modulate:a", 0.0, 0.45)


## Світ показано гравцеві: прогрів завершено, заслона прибрана або зникає.
func is_ready_for_play() -> bool:
	return is_warmed and _fade_rect != null and is_instance_valid(_fade_rect)


## Аварійно прибрати всі заслони (запобіжник завантаження).
func force_reveal() -> void:
	if _fade_rect != null and is_instance_valid(_fade_rect):
		_fade_rect.modulate.a = 0.0
	for ch in get_children():
		if ch is CanvasLayer and ch.layer == 90:
			ch.queue_free()


# ---------- Прогрів: усі вигляди, що зʼявляються пізніше, показуємо заздалегідь ----------

## Причина мікрозависань у 0.1: перша поява ворога, сяйва, спрайта чи напису вимагала
## компіляції шейдера просто посеред гри. Тепер усе це один раз показується за темною заслоною.
## Після першої локації прогріваються лише нові види ворогів: перехід швидкий.
func _warm_up() -> void:
	if not is_inside_tree():
		return
	var kinds: Array = []
	for k in ["novice", "werewolf", "wraith", "beast", "hound", "archer", "brute"]:
		if not warmed_kinds.has(k):
			kinds.append(k)
	var first := warmed_kinds.is_empty()
	if kinds.is_empty():
		is_warmed = true
		warmed.emit()
		_fade_in()
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	var cr := ColorRect.new()
	cr.color = Palette.NIGHT
	FolkTheme.fullscreen(cr)
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(cr)
	var l := FolkTheme.label("Пращури збираються…" if first else "Дорога…", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	FolkTheme.fullscreen(l)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cr.add_child(l)
	add_child(layer)
	var holder := Node3D.new()
	holder.name = "WarmUp"
	add_child(holder)
	var base := player.global_position
	var i := 0
	for kind in kinds:
		var m := ModelFactory.enemy(kind)
		holder.add_child(m)
		m.global_position = base + Vector3(-5.0 + float(i) * 1.8, 0, -2.5)
		ModelFactory.set_flash(m, true)
		ModelFactory.set_flash(m, false)
		warmed_kinds[kind] = true
		i += 1
	if first:
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
		for typ in Items.TYPE_NAMES.keys():
			for r in [0, Items.RARITIES.size() - 1]:
				LootDrop.make_drop(holder, base + Vector3(-3.0 + float(j) * 0.7, 0, 4.2), LootDrop.KIND_ITEM, 1, Items.generate(1, rng, typ, r), rng).set_process(false)
				j += 1
		Fx.ring_burst(holder, base + Vector3(0, 0, -1), 2.0, Palette.GOLD, 0.2)
		Fx.sparks(holder, base + Vector3(0, 1, -1), Palette.TURQUOISE, 6)
		Fx.lightning(holder, base + Vector3(2, 0, -1))
		Fx.damage_number(holder, base + Vector3(0, 2, -1), "0", Palette.LINEN, true)
		var ch := Structures.chest(false)
		ch.position = base + Vector3(3, 0, -3)
		holder.add_child(ch)
		var hb := Structures.herb()
		hb.position = base + Vector3(4, 0, -3)
		holder.add_child(hb)
	for k in range(4):
		await get_tree().process_frame
	holder.queue_free()
	layer.queue_free()
	is_warmed = true
	warmed.emit()
	_fade_in()


# ---------- Вороги ----------

func _enemy_count(kind: String) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).kind == kind and not (e as Enemy).dead and not (e as Enemy).is_boss:
			n += 1
	return n


func _spawn_initial() -> void:
	var counts: Dictionary = loc.get("enemies", {})
	for kind in counts.keys():
		var left := int(counts[kind])
		while left > 0:
			var n := mini(left, _rng.randi_range(2, 4))
			_spawn_pack(kind, n, false)
			left -= n


## Зграя: ватажок і кілька поплічників поруч; помітивши героя, кидаються всі разом.
func _spawn_pack(kind: String, n: int, away: bool) -> void:
	_pack_seq += 1
	var leader := _spawn_enemy(kind, away)
	leader.pack_id = _pack_seq
	if n >= 2:
		leader.make_leader()
	for i in range(n - 1):
		var a := _rng.randf() * TAU
		var p := leader.home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.8, 3.6)
		var flat := Vector2(p.x, p.z)
		if flat.length() > arena_radius - 3.0:
			p = leader.home
		var e := _spawn_enemy_at(kind, p)
		e.pack_id = _pack_seq


## Рівень ворога залежить від того, наскільки глибоко він у локації (далі від входу — вищий).
func _level_at(pos: Vector3) -> int:
	var entry := exit_dir(0) * arena_radius if exits.size() > 0 else Vector2.ZERO
	var t := Vector2(pos.x, pos.z).distance_to(entry) / (arena_radius * 2.0)
	return EnemyDefs.level_in(loc, t, _rng)


func _spawn_enemy(kind: String, away_from_player: bool) -> Enemy:
	var pos := Vector3.ZERO
	var spawn := player.global_position
	for attempt in range(30):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(12.0, arena_radius - 4.0)
		pos = Vector3(cos(a) * r, 0, sin(a) * r)
		if _too_close(pos, 1.6) or _near_exit_point(pos, 10.0):
			continue
		if away_from_player and pos.distance_to(spawn) < 16.0:
			continue
		if pos.distance_to(spawn) < 12.0:
			continue
		break
	return _spawn_enemy_at(kind, pos)


func _spawn_enemy_at(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.name = "Enemy_" + kind
	e.setup(kind, _level_at(pos), player, pos, self)
	_enemy_root.add_child(e)
	e.global_position = pos
	e.died.connect(_on_enemy_died)
	return e


func _spawn_boss() -> void:
	if not loc.has("boss"):
		return
	var b: Dictionary = loc["boss"]
	if is_cave and _cave_won:
		return
	if not is_cave and not GameState.boss_ready(str(b["id"])) or (boss != null and is_instance_valid(boss) and not boss.dead):
		return
	var pos := Vector3(float(b["pos"][0]), 0, float(b["pos"][1]))
	var e := Enemy.new()
	e.name = "Boss_" + str(b["id"])
	e.setup(str(b["kind"]), int(b["level"]), player, pos, self)
	e.make_boss(str(b["id"]), str(b["name"]), float(b["scale"]), float(b.get("hp_mult", 1.0)))
	e.is_cave_boss = bool(b.get("cave", false))
	_enemy_root.add_child(e)
	e.global_position = pos
	e.died.connect(_on_enemy_died)
	boss = e


func _on_enemy_died(e: Enemy) -> void:
	GameState.add_xp(e.xp_reward)
	if e.is_boss and e.is_cave_boss:
		_on_cave_boss_died(e)
		boss = null
		return
	if e.is_boss:
		var ids := LootDrop.drop_from_boss(_loot_root, e.global_position, e.level, _rng)
		GameState.boss_killed(e.boss_id)
		Fx.ring_burst(self, e.global_position, 6.0, Palette.GOLD, 0.8)
		Fx.damage_number(self, e.global_position + Vector3(0, 3.4, 0), "%s повалений!" % e.boss_name, Palette.GOLD, true)
		if hud != null:
			hud.toast("%s повалений! Здобич чекає." % e.boss_name)
		boss = null
		return
	GameState.quest_event("kill", e.kind)
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
	if not player.dead:
		# Капище лікує
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
			_pick_herbs()
		_check_exits(delta)
	# вороги знову з'являються
	if not safe:
		_respawn_t += delta
		if _respawn_t >= RESPAWN_CHECK:
			_respawn_t = 0.0
			var counts: Dictionary = loc.get("enemies", {})
			for kind in counts.keys():
				var miss := int(counts[kind]) - _enemy_count(kind)
				if miss >= 2:
					_spawn_pack(kind, mini(miss, 3), true)
					break
				elif miss == 1:
					_spawn_enemy(kind, true)
					break
		_boss_t += delta
		if _boss_t >= 2.0 and not is_cave:
			_boss_t = 0.0
			if boss == null or not is_instance_valid(boss):
				_try_respawn_boss()
	# автозбереження
	_save_t += delta
	if _save_t >= AUTOSAVE_SECONDS:
		_save_t = 0.0
		GameState.save_game()


func _try_respawn_boss() -> void:
	if not loc.has("boss"):
		return
	var b: Dictionary = loc["boss"]
	var pos := Vector3(float(b["pos"][0]), 0, float(b["pos"][1]))
	if player.global_position.distance_to(pos) < 25.0:
		return
	_spawn_boss()


func _pick_herbs() -> void:
	if herbs.is_empty():
		return
	for i in range(herbs.size() - 1, -1, -1):
		var h: Dictionary = herbs[i]
		if (h["pos"] as Vector3).distance_to(player.global_position) < HERB_PICKUP_R:
			(h["node"] as Node3D).queue_free()
			herbs.remove_at(i)
			GameState.quest_event("item", "herb", 1)
			var have := int(GameState.quest_items.get("herb", 0))
			var need := int(Quests.get_def("herbs")["need"])
			var txt := "Цілюща трава (%d)" % have
			if GameState.quest_state("herbs") == "active":
				txt = "Цілюща трава %d/%d" % [mini(have, need), need]
			Fx.damage_number(self, player.global_position + Vector3(0, 2.2, 0), txt, Color("8BE06E"), true)


# ---------- Взаємодія: NPC, скрині ----------

## Найближчий обʼєкт, з яким можна говорити або який можна відкрити (null, якщо нічого поруч).
func nearest_interactable() -> Dictionary:
	if player == null or player.dead:
		return {}
	var best: Dictionary = {}
	var bd := INTERACT_R
	for it in interactables:
		if str(it["kind"]) == "chest" and bool(it.get("opened", false)):
			continue
		var dd := (it["pos"] as Vector3).distance_to(player.global_position)
		if dd < bd:
			bd = dd
			best = it
	return best


func interact_prompt(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	match str(it["kind"]):
		"npc":
			var mark := ""
			if not GameState.quests_to_turn_in(str(it["id"])).is_empty():
				mark = " (?)"
			elif not GameState.quests_of(str(it["id"])).is_empty():
				mark = " (!)"
			return "Говорити: %s%s" % [it["name"], mark]
		"chest":
			return "Відкрити скриню"
		"cave":
			return "Увійти до печери (рів. %d+)" % _cave_level_for_here()
		"portal":
			return "Портал назовні"
	return ""


## Виконує взаємодію. Для NPC відкриває діалог у HUD, для скрині видає здобич.
func interact(it: Dictionary) -> void:
	if it.is_empty():
		return
	match str(it["kind"]):
		"npc":
			if hud != null:
				hud.open_dialog(str(it["id"]))
		"chest":
			open_chest(it)
		"cave":
			enter_cave()
		"portal":
			leave_cave()


func open_chest(it: Dictionary) -> void:
	if bool(it.get("opened", false)):
		return
	var c: Dictionary = it["def"]
	it["opened"] = true
	GameState.mark_chest(str(it["id"]))
	# модель: відкрита скриня
	var old: Node3D = it["node"]
	var fresh := Structures.chest(true)
	fresh.position = old.position
	fresh.rotation = old.rotation
	add_child(fresh)
	old.queue_free()
	it["node"] = fresh
	Fx.sparks(self, it["pos"] + Vector3(0, 0.8, 0), Palette.GOLD, 10)
	var text := "Скриня відкрита"
	var qi := str(c.get("quest_item", ""))
	if qi != "":
		GameState.quest_event("item", qi, 1)
		text = "Знайдено: %s" % Quests.item_name(qi)
		Fx.damage_number(self, it["pos"] + Vector3(0, 2.2, 0), text, Palette.GOLD, true)
	var lvl := int(c.get("loot_level", 1))
	LootDrop.make_drop(_loot_root, it["pos"] + Vector3(1.2, 0, 0.8), LootDrop.KIND_GOLD, 8 + 6 * lvl, {}, _rng)
	LootDrop.make_drop(_loot_root, it["pos"] + Vector3(-1.2, 0, 0.8), LootDrop.KIND_ITEM, 1, Items.generate(lvl, _rng, "", 1), _rng)
	if hud != null:
		hud.toast(text)


# ---------- Виходи ----------

## Тригер виходу: торкнувшись брами, герой переходить в іншу локацію.
func _check_exits(delta: float) -> void:
	_exit_cd = maxf(0.0, _exit_cd - delta)
	if _transitioning:
		return
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for i in range(exits.size()):
		if pp.distance_to(exit_trigger_pos(i)) < EXIT_TRIGGER_R and _exit_cd <= 0.0:
			go_through_exit(i)
			return


func go_through_exit(i: int) -> void:
	if _transitioning or i < 0 or i >= exits.size():
		return
	var to := str(exits[i]["to"])
	if hud != null:
		hud.toast(str(exits[i]["label"]))
	_travel(to, loc_id)


func _travel(to: String, from: String) -> void:
	_transitioning = true
	if instant_transition:
		GameState.change_location(to, from)
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade_rect, "modulate:a", 1.0, 0.35)
	await tw.finished
	if not is_inside_tree():
		return
	GameState.change_location(to, from)
	GameState.load_guard.arm()
	get_tree().reload_current_scene()


func _on_quest_changed() -> void:
	if hud != null:
		hud.map_dirty()


func _process(delta: float) -> void:
	if player == null or camera == null:
		return
	_music_t -= delta
	if _music_t <= 0.0:
		_music_t = 0.5
		var fight := false
		if not player.dead:
			for e in get_tree().get_nodes_in_group("enemies"):
				var en: Enemy = e
				if en.state != Enemy.State.IDLE and en.global_position.distance_to(player.global_position) < 26.0:
					fight = true
					break
		Sound.set_combat(fight)
	_cam_pos = _cam_pos.lerp(player.global_position, minf(1.0, 8.0 * delta))
	_place_camera(_cam_pos)


func _clamp_to_arena(n: Node3D) -> void:
	var flat := Vector2(n.global_position.x, n.global_position.z)
	var limit := arena_radius - 1.2
	# біля брами лишаємо проліт: обмеження ширше
	for i in range(exits.size()):
		if flat.distance_to(exit_dir(i) * arena_radius) < 6.0:
			limit = arena_radius + 1.0
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


# ---------- Печери ----------

func _cave_level_for_here() -> int:
	return maxi(int(loc["levels"][1]), GameState.level) + 2


## Випадковий вхід до печери на поверхні (на новому місці при кожному приході).
func _build_cave_entrance() -> void:
	if not (loc_id in Locations.CAVE_HOSTS):
		return
	var pos := Vector3.INF
	if GameState.cave_pos_loc == loc_id and GameState.arrive_from == "cave":
		pos = Vector3(GameState.cave_pos.x, 0, GameState.cave_pos.y)
	else:
		for attempt in range(40):
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(16.0, arena_radius - 8.0)
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if _too_close(p, 3.5) or _near_exit_point(p, 12.0):
				continue
			pos = p
			break
		if pos == Vector3.INF:
			pos = Vector3(arena_radius * 0.5, 0, 0)
	cave_entrance = pos
	GameState.cave_pos = Vector2(pos.x, pos.z)
	GameState.cave_pos_loc = loc_id
	var node := Structures.cave_mouth()
	node.position = pos
	node.rotation.y = atan2(-pos.x, -pos.z)
	add_child(node)
	_label_over(node, "Печера", 3.6, Palette.GOLD)
	interactables.append({"kind": "cave", "id": "cave", "name": "Печера", "pos": pos - pos.normalized() * 2.2, "node": node})


func enter_cave() -> void:
	if _transitioning:
		return
	GameState.cave_from = loc_id
	GameState.cave_level = _cave_level_for_here()
	Sound.play("sfx_portal", -4.0)
	if hud != null:
		hud.toast("Печера: тут лігво Кощія")
	_travel("cave", loc_id)


func leave_cave() -> void:
	if _transitioning:
		return
	Sound.play("sfx_portal", -2.0)
	var back := GameState.cave_from if Locations.has(GameState.cave_from) else Locations.START
	_travel(back, "cave")


func _on_cave_boss_died(e: Enemy) -> void:
	_cave_won = true
	var lvl := e.level + 2
	LootDrop.drop_from_boss(_loot_root, e.global_position, lvl, _rng)
	LootDrop.drop_from_boss(_loot_root, e.global_position + Vector3(2, 0, 0), lvl, _rng)
	LootDrop.make_drop(_loot_root, e.global_position + Vector3(-2, 0, 1), LootDrop.KIND_GOLD, 150 + 30 * lvl, {}, _rng)
	GameState.add_xp(e.xp_reward)
	GameState.quest_event("boss", "koshchii")
	Fx.ring_burst(self, e.global_position, 8.0, Palette.GOLD, 0.9)
	Fx.damage_number(self, e.global_position + Vector3(0, 4.0, 0), "%s повалений!" % e.boss_name, Palette.GOLD, true)
	var pp := e.global_position + Vector3(0, 0, 5.0)
	if Vector2(pp.x, pp.z).length() > arena_radius - 4.0:
		pp = e.global_position.move_toward(Vector3.ZERO, 5.0)
		pp.y = 0.0
	var portal := Structures.portal()
	portal.position = pp
	add_child(portal)
	interactables.append({"kind": "portal", "id": "portal", "name": "Портал", "pos": pp, "node": portal})
	Sound.play("sfx_portal", 0.0)
	if hud != null:
		hud.toast("Кощія повалено! Збери здобич і ступи в портал.")


## Фаза Кощія змінилася.
func boss_phase(_e: Enemy, ph: int) -> void:
	if hud != null:
		hud.toast("Кощій лютує! (фаза %d)" % ph if ph < 3 else "Кощій кличе мерців — останній бій!")


func boss_summon(e: Enemy, n: int) -> void:
	if get_tree().get_nodes_in_group("enemies").size() > 24:
		return
	for i in range(n):
		var a := _rng.randf() * TAU
		var p := e.global_position + Vector3(cos(a), 0, sin(a)) * 4.0
		var m := _spawn_enemy_at("skel_minion", p)
		m.state = Enemy.State.CHASE
		Fx.sparks(self, p + Vector3(0, 0.6, 0), Color("7FE0FF"), 8)
