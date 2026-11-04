## Спокійна низькополігональна земля: майже однотонна, з плавними плямами, дороги між виходами й Капищем,
## утоптане коло навколо Капища і темніший край біля скель. Кольори беруться з опису локації.
## Побудований меш кешується за id локації: повторний вхід не перераховує нічого.
class_name Terrain

const HALF := 60.0
const CELL := 2.0

static var _cache := {}


## Дороги локації: масив ламаних (Array[Vector2]); виходи з'єднані з Капищем автоматично.
static func roads_of(loc_id: String) -> Array:
	var d := Locations.get_def(loc_id)
	var out: Array = []
	for r in d.get("roads", []):
		var line: Array = []
		for p in r:
			line.append(Vector2(float(p[0]), float(p[1])))
		out.append(line)
	var radius := float(d["radius"])
	for i in range(d["exits"].size()):
		var dir := Locations.exit_dir(loc_id, i)
		out.append([Vector2.ZERO, dir * (radius * 0.5), dir * (radius - 2.0)])
	return out


static func build(loc_id: String) -> MeshInstance3D:
	if not _cache.has(loc_id):
		_cache[loc_id] = _build_mesh(loc_id)
	var mi := MeshInstance3D.new()
	mi.mesh = _cache[loc_id]
	mi.material_override = LowPoly.vc_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Ground"
	return mi


static func _build_mesh(loc_id: String) -> ArrayMesh:
	var d := Locations.get_def(loc_id)
	var arena_radius := float(d["radius"])
	var noise := FastNoiseLite.new()
	noise.seed = 20261103 + loc_id.hash() % 1000
	noise.frequency = 0.045
	var segs: Array = []
	for line in roads_of(loc_id):
		for k in range(line.size() - 1):
			segs.append([line[k], line[k + 1]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(HALF * 2.0 / CELL)
	for i in range(n):
		for j in range(n):
			var x0 := -HALF + i * CELL
			var z0 := -HALF + j * CELL
			var p00 := Vector3(x0, 0, z0)
			var p10 := Vector3(x0 + CELL, 0, z0)
			var p01 := Vector3(x0, 0, z0 + CELL)
			var p11 := Vector3(x0 + CELL, 0, z0 + CELL)
			_tri(st, p00, p10, p01, _color((p00 + p10 + p01) / 3.0, arena_radius, noise, segs, d))
			_tri(st, p10, p11, p01, _color((p10 + p11 + p01) / 3.0, arena_radius, noise, segs, d))
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(p)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _color(m: Vector3, arena_radius: float, noise: FastNoiseLite, segs: Array, d: Dictionary) -> Color:
	var r := Vector2(m.x, m.z).length()
	var k := noise.get_noise_2d(m.x, m.z) * 0.035
	var col: Color = d["base"]
	# утоптана земля навколо Капища
	col = col.lerp(d["earth"], 1.0 - smoothstep(4.6, 7.5, r))
	# дороги
	var p2 := Vector2(m.x, m.z)
	var best := 99.0
	for s in segs:
		var dd := _seg_dist(p2, s[0], s[1])
		if dd < best:
			best = dd
	col = col.lerp(d["path"], 1.0 - smoothstep(1.1, 2.3, best))
	# темніший край біля скель
	var edge := smoothstep(arena_radius - 9.0, arena_radius + 3.0, r)
	col = col.lerp(d["edge"], edge * 0.85)
	return Color(clampf(col.r + k, 0, 1), clampf(col.g + k, 0, 1), clampf(col.b + k, 0, 1))
