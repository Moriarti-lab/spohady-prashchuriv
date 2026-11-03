## Низькополігональна земля долини: кольорові трикутники, світла земля навколо капища.
class_name Terrain

const HALF := 44.0
const CELL := 2.0


static func build(arena_radius: float) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
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
			_tri(st, p00, p10, p01, _color(p00, p10, p01, arena_radius, rng))
			_tri(st, p10, p11, p01, _color(p10, p11, p01, arena_radius, rng))
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


static func _color(a: Vector3, b: Vector3, c: Vector3, arena_radius: float, rng: RandomNumberGenerator) -> Color:
	var m := (a + b + c) / 3.0
	var r := Vector2(m.x, m.z).length()
	var base := Color("4F7D3C")
	var k := rng.randf_range(-0.07, 0.07)
	if rng.randf() < 0.12:
		base = Color("6C8A3A")      # сухіша трава
	elif rng.randf() < 0.10:
		base = Color("3D6A3A")      # темніша
	if r < 5.2:
		base = Color("8F7F69") if rng.randf() < 0.6 else Color("7B6E5C")   # утоптана земля навколо капища
	elif r < 6.2 and rng.randf() < 0.5:
		base = Color("7E8A4A")
	# узлісся темніше
	var edge := clampf((r - (arena_radius - 8.0)) / 10.0, 0.0, 1.0)
	base = base.lerp(Color("1F2D22"), edge * 0.85)
	return Color(clampf(base.r + k, 0, 1), clampf(base.g + k, 0, 1), clampf(base.b + k, 0, 1))
