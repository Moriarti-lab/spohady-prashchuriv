## Спокійна низькополігональна земля: майже однотонна, з плавними плямами, стежка до виходу,
## утоптане коло навколо Капища і темніший край біля скель.
class_name Terrain

const HALF := 60.0
const CELL := 2.0
const BASE := Color("4E6B45")
const EARTH := Color("7A6E5A")
const PATH := Color("77694F")
const EDGE := Color("27342B")


## exit_dirs: масив одиничних Vector2 (x, z), куди ведуть стежки до виходів.
static func build(arena_radius: float, exit_dirs: Array = []) -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = 20261103
	noise.frequency = 0.045
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
			_tri(st, p00, p10, p01, _color((p00 + p10 + p01) / 3.0, arena_radius, noise, exit_dirs))
			_tri(st, p10, p11, p01, _color((p10 + p11 + p01) / 3.0, arena_radius, noise, exit_dirs))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = LowPoly.vc_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Ground"
	return mi


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(p)


static func _color(m: Vector3, arena_radius: float, noise: FastNoiseLite, exit_dirs: Array) -> Color:
	var r := Vector2(m.x, m.z).length()
	# дуже плавна пляма яскравості (±3%), без шахівки й різнобарв'я
	var k := noise.get_noise_2d(m.x, m.z) * 0.035
	var col := BASE
	# утоптана земля навколо Капища, м'який перехід
	col = col.lerp(EARTH, 1.0 - smoothstep(4.6, 7.5, r))
	# стежка до виходу
	for d in exit_dirs:
		var dir: Vector2 = d
		var along := m.x * dir.x + m.z * dir.y
		if along > 6.0:
			var lateral := absf(m.x * dir.y - m.z * dir.x)
			col = col.lerp(PATH, (1.0 - smoothstep(1.2, 2.6, lateral)) * smoothstep(6.0, 14.0, along))
	# темніший край біля скель
	var edge := smoothstep(arena_radius - 9.0, arena_radius + 3.0, r)
	col = col.lerp(EDGE, edge * 0.85)
	return Color(clampf(col.r + k, 0, 1), clampf(col.g + k, 0, 1), clampf(col.b + k, 0, 1))
