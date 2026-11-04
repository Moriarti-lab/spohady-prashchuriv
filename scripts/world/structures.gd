## Низькополігональні будівлі, NPC, скрині й дрібниці світу. Меші кешуються й діляться між екземплярами.
class_name Structures

const WALL := Color("A8957A")
const WALL_DARK := Color("86745D")
const ROOF := Color("8A5A3A")
const ROOF_OLD := Color("5A4636")
const WOOD := Color("6B4A2E")
const STRAW := Color("C9A860")

static var _cache := {}


static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


static func _mi(mesh: ArrayMesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = LowPoly.vc_material()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# ---------- Будинки ----------

## kind: home (жива хата), elder (хата старійшини, більша), abandoned (стара, з проваленим дахом).
static func house(kind: String) -> MeshInstance3D:
	return _mi(_cached("house_" + kind, func() -> ArrayMesh: return LowPoly.build_mesh(_house_parts(kind))))


static func _house_parts(kind: String) -> Array:
	var p: Array = []
	var big := 1.25 if kind == "elder" else 1.0
	var old := kind == "abandoned"
	var wall := WALL_DARK if old else WALL
	var w := 4.2 * big
	var d := 3.4 * big
	p.append(LowPoly.box(Vector3(w + 0.3, 0.3, d + 0.3), Vector3(0, 0.15, 0), Color("77767C")))
	p.append(LowPoly.box(Vector3(w, 2.0, d), Vector3(0, 1.3, 0), wall))
	# дах
	var roof := ROOF_OLD if old else (STRAW if kind == "home" else ROOF)
	p.append(LowPoly.prism(Vector3(w + 0.9, 1.6, d + 0.8), Vector3(0, 3.1, 0), roof, Vector3(0, 0, 0)))
	if old:
		p.append(LowPoly.box(Vector3(1.2, 0.5, 1.2), Vector3(0.6, 3.3, 0.2), Color("2E2A27"), Vector3(0, 25, 12)))
		p.append(LowPoly.box(Vector3(0.15, 1.3, 0.15), Vector3(-1.1, 3.0, -0.3), WOOD, Vector3(0, 0, 40)))
	# двері й вікна (вхід з боку +Z; дім повертають у світі)
	p.append(LowPoly.box(Vector3(0.9, 1.5, 0.12), Vector3(0, 1.05, d * 0.5 + 0.02), WOOD.darkened(0.2)))
	var win := Color("2A2622") if old else Color("E8C875")
	p.append(LowPoly.box(Vector3(0.6, 0.55, 0.12), Vector3(-w * 0.3, 1.6, d * 0.5 + 0.02), win))
	p.append(LowPoly.box(Vector3(0.6, 0.55, 0.12), Vector3(w * 0.3, 1.6, d * 0.5 + 0.02), win))
	if not old:
		p.append(LowPoly.box(Vector3(w, 0.1, 0.14), Vector3(0, 2.0, d * 0.5 + 0.03), Palette.EMBROIDERY))
		p.append(LowPoly.cyl(0.18, 0.2, 0.9, Vector3(w * 0.3, 3.9, -d * 0.2), Color("77767C"), 5))
	else:
		p.append(LowPoly.box(Vector3(1.6, 0.9, 0.12), Vector3(w * 0.3 + 0.5, 0.7, d * 0.5 + 0.02), Color("6A5A46"), Vector3(0, 0, 14)))
	return p


## Колісний бар'єр-тин навколо (для сіл) — не використовується в колізіях, лише декор.
static func fence_piece() -> MeshInstance3D:
	return _mi(_cached("fence", func() -> ArrayMesh:
		var p: Array = []
		for i in range(4):
			p.append(LowPoly.box(Vector3(0.12, 1.0, 0.12), Vector3(-0.9 + i * 0.6, 0.5, 0), WOOD))
		p.append(LowPoly.box(Vector3(2.0, 0.1, 0.08), Vector3(0, 0.75, 0), WOOD.lightened(0.1)))
		p.append(LowPoly.box(Vector3(2.0, 0.1, 0.08), Vector3(0, 0.4, 0), WOOD.lightened(0.1)))
		return LowPoly.build_mesh(p)))


static func ruin_wall() -> MeshInstance3D:
	return _mi(_cached("ruin_wall", func() -> ArrayMesh:
		var p: Array = []
		var st := Color("7B7A80")
		p.append(LowPoly.box(Vector3(3.4, 1.8, 0.7), Vector3(0, 0.9, 0), st))
		p.append(LowPoly.box(Vector3(1.4, 0.9, 0.7), Vector3(-0.8, 2.2, 0), st.lightened(0.08)))
		p.append(LowPoly.box(Vector3(0.9, 0.6, 0.7), Vector3(1.0, 2.0, 0.05), st.darkened(0.08), Vector3(0, 6, 8)))
		return LowPoly.build_mesh(p)))


static func puddle() -> MeshInstance3D:
	return _mi(_cached("puddle", func() -> ArrayMesh:
		var p: Array = []
		p.append(LowPoly.cyl(1.4, 1.4, 0.04, Vector3(0, 0.03, 0), Color("38503F"), 7))
		p.append(LowPoly.cyl(0.9, 0.9, 0.05, Vector3(0.3, 0.04, 0.2), Color("43604A"), 6))
		return LowPoly.build_mesh(p)))


# ---------- Скриня, трава, вказівник ----------

static func chest(opened: bool = false) -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	p.append(LowPoly.box(Vector3(1.0, 0.55, 0.65), Vector3(0, 0.28, 0), WOOD))
	p.append(LowPoly.box(Vector3(1.04, 0.1, 0.7), Vector3(0, 0.55, 0), Color("3A3A40")))
	p.append(LowPoly.box(Vector3(0.1, 0.62, 0.7), Vector3(-0.3, 0.3, 0), Color("3A3A40")))
	p.append(LowPoly.box(Vector3(0.1, 0.62, 0.7), Vector3(0.3, 0.3, 0), Color("3A3A40")))
	if opened:
		p.append(LowPoly.box(Vector3(1.0, 0.1, 0.6), Vector3(0, 0.75, 0.38), WOOD.darkened(0.2), Vector3(-70, 0, 0)))
	else:
		p.append(LowPoly.prism(Vector3(1.0, 0.3, 0.65), Vector3(0, 0.7, 0), WOOD.lightened(0.1)))
		p.append(LowPoly.box(Vector3(0.14, 0.14, 0.06), Vector3(0, 0.5, -0.35), Palette.GOLD))
	root.add_child(LowPoly.instance(p))
	if not opened:
		root.add_child(LowPoly.glow_instance(LowPoly.ball(0.07, Vector3(0, 1.15, 0), Palette.GOLD, 5), Palette.GOLD, 2.5, 0.8))
	return root


static func herb() -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	var g := Color("6FBF5A")
	for i in range(5):
		var a := TAU * float(i) / 5.0
		p.append(LowPoly.box(Vector3(0.05, 0.5, 0.18), Vector3(cos(a) * 0.12, 0.25, sin(a) * 0.12), g.darkened(0.05 * i), Vector3(0, -rad_to_deg(a), 25)))
	p.append(LowPoly.ball(0.07, Vector3(0, 0.55, 0), Color("F4E27A"), 5))
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.ball(0.09, Vector3(0, 0.62, 0), Color("F4E27A"), 5), Color("F4E27A"), 1.8, 0.7))
	return root


static func signpost(text: String) -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	p.append(LowPoly.box(Vector3(0.14, 2.0, 0.14), Vector3(0, 1.0, 0), WOOD))
	p.append(LowPoly.box(Vector3(1.6, 0.5, 0.08), Vector3(0.3, 1.8, 0), WOOD.lightened(0.15)))
	p.append(LowPoly.prism(Vector3(0.4, 0.5, 0.08), Vector3(1.3, 1.8, 0), WOOD.lightened(0.15), Vector3(0, 0, -90)))
	root.add_child(LowPoly.instance(p))
	var l := Label3D.new()
	l.text = text
	l.font_size = 30
	l.pixel_size = 0.009
	l.outline_size = 8
	l.modulate = Palette.LINEN
	l.outline_modulate = Palette.NIGHT
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0.3, 2.45, 0)
	root.add_child(l)
	return root


# ---------- NPC ----------

## Проста фігура людини в одязі кольору `color`; hat: "" / "cap" / "hood" / "beard".
static func npc(color: Color, hat: String = "") -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	var skin := Color("E3B58C")
	p.append(LowPoly.box(Vector3(0.17, 0.7, 0.22), Vector3(-0.12, 0.35, 0), Color("5E4A36")))
	p.append(LowPoly.box(Vector3(0.17, 0.7, 0.22), Vector3(0.12, 0.35, 0), Color("5E4A36")))
	p.append(LowPoly.cyl(0.24, 0.3, 0.8, Vector3(0, 1.05, 0), color, 7))
	p.append(LowPoly.cyl(0.31, 0.31, 0.09, Vector3(0, 0.72, 0), Palette.EMBROIDERY, 7))
	p.append(LowPoly.ball(0.2, Vector3(0, 1.62, 0), skin, 7))
	p.append(LowPoly.box(Vector3(0.12, 0.55, 0.12), Vector3(-0.35, 1.05, -0.05), color, Vector3(-10, 0, 10)))
	p.append(LowPoly.box(Vector3(0.12, 0.55, 0.12), Vector3(0.35, 1.05, -0.05), color, Vector3(-10, 0, -10)))
	match hat:
		"cap":
			p.append(LowPoly.cyl(0.22, 0.23, 0.14, Vector3(0, 1.8, 0), Color("7A4A2A"), 7))
		"hood":
			p.append(LowPoly.ball(0.25, Vector3(0, 1.66, 0.04), color.darkened(0.2), 7, Vector3(1, 1.1, 1)))
		"beard":
			p.append(LowPoly.cone(0.14, 0.45, Vector3(0, 1.4, -0.14), Color("E4E0D8"), 5))
			p.append(LowPoly.ball(0.22, Vector3(0, 1.74, 0.02), Color("E4E0D8"), 6, Vector3(1, 0.5, 1)))
		_:
			p.append(LowPoly.ball(0.22, Vector3(0, 1.72, 0.03), Color("6B4A2E"), 6, Vector3(1, 0.6, 1)))
	root.add_child(LowPoly.instance(p))
	return root


## Вхід до печери: купа каміння з темним проходом.
static func cave_mouth() -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	var st := Color("6E6A62")
	p.append(LowPoly.ball(2.2, Vector3(0, 0.9, -0.6), st, 7))
	p.append(LowPoly.ball(1.3, Vector3(-1.9, 0.6, 0.1), st.darkened(0.1), 6))
	p.append(LowPoly.ball(1.2, Vector3(1.9, 0.55, 0.2), st.lightened(0.05), 6))
	p.append(LowPoly.box(Vector3(1.9, 1.9, 0.3), Vector3(0, 0.95, 1.45), Color("0B0A09")))
	p.append(LowPoly.box(Vector3(2.6, 0.35, 0.6), Vector3(0, 2.0, 1.4), st.darkened(0.2), Vector3(0, 0, 4)))
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.ball(0.12, Vector3(-1.2, 1.6, 1.6), Color("FFB347"), 5), Color("FFB347"), 2.5))
	root.add_child(LowPoly.glow_instance(LowPoly.ball(0.12, Vector3(1.2, 1.6, 1.6), Color("FFB347"), 5), Color("FFB347"), 2.5))
	return root


## Портал назовні після перемоги над Кощієм.
static func portal() -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	for i in range(10):
		var a := PI * float(i) / 9.0
		p.append(LowPoly.box(Vector3(0.5, 0.5, 0.4), Vector3(cos(a) * 1.6, sin(a) * 1.6 + 0.3, 0), Color("6E6A62"), Vector3(0, 0, rad_to_deg(a))))
	root.add_child(LowPoly.instance(p))
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.35
	cm.bottom_radius = 1.35
	cm.height = 0.05
	disc.mesh = cm
	disc.rotation_degrees.x = 90
	disc.position.y = 1.4
	disc.material_override = LowPoly.glow_material(Color("7FE0FF"), 3.0, 0.75)
	root.add_child(disc)
	var tw := disc.create_tween().set_loops()
	tw.tween_property(disc, "scale", Vector3(1.08, 1, 1.08), 0.7)
	tw.tween_property(disc, "scale", Vector3.ONE, 0.7)
	return root
