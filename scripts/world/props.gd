## Дерева, каміння, квіти й трава: прості low-poly меші з примітивів.
class_name Props

const TRUNK := Color("5B3F2B")


static func pine_mesh(variant: int) -> ArrayMesh:
	var g1 := Color("2F5A34")
	var g2 := Color("3D6E3A")
	var g3 := Color("4A7C3F")
	if variant == 1:
		g1 = Color("2A4D3B")
		g2 = Color("35604A")
		g3 = Color("417057")
	var parts: Array = []
	parts.append(LowPoly.cyl(0.14, 0.22, 1.3, Vector3(0, 0.65, 0), TRUNK, 5))
	parts.append(LowPoly.cone(1.25, 1.5, Vector3(0, 1.7, 0), g1, 6))
	parts.append(LowPoly.cone(1.0, 1.35, Vector3(0, 2.45, 0), g2, 6))
	parts.append(LowPoly.cone(0.7, 1.2, Vector3(0, 3.2, 0), g3, 6))
	return LowPoly.build_mesh(parts)


static func birch_mesh() -> ArrayMesh:
	var parts: Array = []
	parts.append(LowPoly.cyl(0.1, 0.16, 2.3, Vector3(0, 1.15, 0), Color("E8E3D6"), 5))
	parts.append(LowPoly.box(Vector3(0.18, 0.05, 0.18), Vector3(0, 0.8, 0), Color("2E2B28")))
	parts.append(LowPoly.box(Vector3(0.18, 0.05, 0.18), Vector3(0, 1.5, 0), Color("2E2B28")))
	parts.append(LowPoly.ball(0.95, Vector3(0, 2.7, 0), Color("6E9E3F"), 6, Vector3(1, 1.1, 1)))
	parts.append(LowPoly.ball(0.6, Vector3(0.5, 2.3, 0.2), Color("84B04A"), 5))
	return LowPoly.build_mesh(parts)


static func dead_tree_mesh() -> ArrayMesh:
	var parts: Array = []
	var bark := Color("3B2E26")
	parts.append(LowPoly.cyl(0.1, 0.24, 2.4, Vector3(0, 1.2, 0), bark, 5))
	parts.append(LowPoly.box(Vector3(0.1, 1.1, 0.1), Vector3(0.45, 2.0, 0), bark, Vector3(0, 0, -50)))
	parts.append(LowPoly.box(Vector3(0.1, 0.9, 0.1), Vector3(-0.4, 1.7, 0.1), bark, Vector3(10, 0, 55)))
	parts.append(LowPoly.box(Vector3(0.08, 0.7, 0.08), Vector3(0.05, 2.5, 0.3), bark, Vector3(40, 0, 10)))
	return LowPoly.build_mesh(parts)


static func rock_mesh() -> ArrayMesh:
	var parts: Array = []
	parts.append(LowPoly.ball(0.7, Vector3(0, 0.3, 0), Color("77767A"), 5, Vector3(1.2, 0.7, 1.0), Vector3(0, 20, 0)))
	parts.append(LowPoly.ball(0.4, Vector3(0.55, 0.15, 0.2), Color("8A898D"), 5, Vector3(1, 0.7, 1)))
	return LowPoly.build_mesh(parts)


static func flower_mesh(color: Color) -> ArrayMesh:
	var parts: Array = []
	parts.append(LowPoly.box(Vector3(0.03, 0.3, 0.03), Vector3(0, 0.15, 0), Palette.LEAF))
	parts.append(LowPoly.ball(0.09, Vector3(0, 0.34, 0), color, 5, Vector3(1, 0.6, 1)))
	return LowPoly.build_mesh(parts)


static func grass_mesh() -> ArrayMesh:
	var parts: Array = []
	var c := Color("5E9446")
	parts.append(LowPoly.cone(0.05, 0.4, Vector3(0, 0.2, 0), c, 3))
	parts.append(LowPoly.cone(0.05, 0.3, Vector3(0.1, 0.15, 0.05), c.darkened(0.1), 3))
	parts.append(LowPoly.cone(0.05, 0.35, Vector3(-0.08, 0.17, -0.06), c.lightened(0.1), 3))
	return LowPoly.build_mesh(parts)


static func multimesh(mesh: Mesh, transforms: Array, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = LowPoly.vc_material()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
