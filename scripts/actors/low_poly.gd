## Допоміжні функції для простих low-poly моделей із примітивів.
## Частина моделі = [mesh, Transform3D, Color]. Усі частини склеюються в один меш
## з плоскими гранями та кольором вершин (мало викликів малювання на телефоні).
class_name LowPoly

static var _materials := {}


static func vc_material(alpha: bool = false, double_sided: bool = false) -> StandardMaterial3D:
	var key := "vc|%s|%s" % [alpha, double_sided]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.92
	m.metallic = 0.0
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m


static func glow_material(color: Color, energy: float = 2.0, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "glow|%s|%s|%s" % [color.to_html(true), energy, alpha]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m
	return m


static func unshaded_material(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "unshaded|%s|%s" % [color.to_html(true), alpha]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m
	return m


static func xf(pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)
	return Transform3D(b, pos)


# ---------- Частини ----------

static func box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> Array:
	var m := BoxMesh.new()
	m.size = size
	return [m, xf(pos, rot_deg), color]


static func cyl(top: float, bottom: float, h: float, pos: Vector3, color: Color,
		sides: int = 6, rot_deg: Vector3 = Vector3.ZERO) -> Array:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return [m, xf(pos, rot_deg), color]


static func cone(r: float, h: float, pos: Vector3, color: Color, sides: int = 6) -> Array:
	return cyl(0.0, r, h, pos, color, sides)


static func ball(r: float, pos: Vector3, color: Color, sides: int = 6,
		scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO) -> Array:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = sides
	m.rings = maxi(2, sides / 2)
	return [m, xf(pos, rot_deg, scl), color]


static func prism(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> Array:
	var m := PrismMesh.new()
	m.size = size
	return [m, xf(pos, rot_deg), color]


# ---------- Складання ----------

static func build_mesh(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var mesh: Mesh = p[0]
		var t: Transform3D = p[1]
		var col: Color = p[2]
		var arr: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			for i in range(verts.size()):
				idx.append(i)
		for i in range(0, idx.size() - 2, 3):
			var ia: int = idx[i]
			var ib: int = idx[i + 1]
			var ic: int = idx[i + 2]
			var a: Vector3 = t * verts[ia]
			var b: Vector3 = t * verts[ib]
			var c: Vector3 = t * verts[ic]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length_squared() < 0.0000001:
				continue
			n = n.normalized()
			# Узгоджуємо напрям нормалі з нормалями вершин меша.
			var ref: Vector3 = t.basis * (norms[ia] + norms[ib] + norms[ic])
			if n.dot(ref) < 0.0:
				n = -n
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(a)
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(b)
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(c)
	return st.commit()


## Створює MeshInstance3D зі склеєних частин.
static func instance(parts: Array, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh(parts)
	mi.material_override = material if material != null else vc_material()
	return mi


## Світна деталь (очі, вогонь, снаряд): окремий меш зі світним матеріалом.
static func glow_instance(part: Array, color: Color, energy: float = 2.0, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh([part])
	mi.material_override = glow_material(color, energy, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
