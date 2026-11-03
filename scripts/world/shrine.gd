## Капище: місце відродження й зцілення в центрі долини.
class_name Shrine
extends Node3D

const HEAL_RADIUS := 3.4
var _ring: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	var parts: Array = []
	var stone := Color("8D8A86")
	var dark := Color("5E5A57")
	# кам'яне коло
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var p := Vector3(sin(a) * 3.2, 0.0, cos(a) * 3.2)
		parts.append(LowPoly.box(Vector3(0.55, 1.5 + 0.25 * float(i % 3), 0.5), p + Vector3(0, 0.8, 0), stone, Vector3(0, rad_to_deg(a), 0)))
		parts.append(LowPoly.box(Vector3(0.7, 0.2, 0.65), p + Vector3(0, 0.1, 0), dark, Vector3(0, rad_to_deg(a), 0)))
		parts.append(LowPoly.box(Vector3(0.12, 0.12, 0.05), p + Vector3(0, 1.1, 0) - Vector3(sin(a), 0, cos(a)) * 0.27, Palette.EMBROIDERY, Vector3(0, rad_to_deg(a), 0)))
	# капище-ідол у центрі
	parts.append(LowPoly.cyl(0.9, 1.1, 0.35, Vector3(0, 0.18, 0), dark, 8))
	parts.append(LowPoly.cyl(0.38, 0.46, 2.6, Vector3(0, 1.6, 0), Color("6B4A2E"), 6))
	parts.append(LowPoly.cyl(0.42, 0.42, 0.12, Vector3(0, 1.0, 0), Palette.EMBROIDERY, 6))
	parts.append(LowPoly.cyl(0.42, 0.42, 0.12, Vector3(0, 2.2, 0), Palette.GOLD, 6))
	parts.append(LowPoly.box(Vector3(0.3, 0.3, 0.12), Vector3(0, 1.65, -0.4), Color("D9C6A0")))
	parts.append(LowPoly.cone(0.5, 0.5, Vector3(0, 3.1, 0), Palette.EMBROIDERY, 6))
	add_child(LowPoly.instance(parts))
	var orb := LowPoly.glow_instance(LowPoly.ball(0.2, Vector3(0, 3.5, 0), Palette.TURQUOISE, 6), Palette.TURQUOISE, 3.0)
	add_child(orb)
	# Світло немає: від нього змінюються шейдери й гра смикається. Лише світний камінь.
	var halo := LowPoly.glow_instance(LowPoly.ball(0.34, Vector3(0, 3.5, 0), Palette.TURQUOISE, 6), Palette.TURQUOISE, 1.2, 0.3)
	add_child(halo)
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 4
	_ring.mesh = t
	_ring.material_override = LowPoly.glow_material(Palette.TURQUOISE, 1.8, 0.8)
	_ring.scale = Vector3(HEAL_RADIUS - 0.4, 0.2, HEAL_RADIUS - 0.4)
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var name_label := Label3D.new()
	name_label.text = "Капище"
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 40
	name_label.pixel_size = 0.012
	name_label.outline_size = 12
	name_label.modulate = Palette.GOLD
	name_label.outline_modulate = Palette.NIGHT
	name_label.position = Vector3(0, 4.3, 0)
	add_child(name_label)
	# колізія ідола
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.6
	sh.height = 3.0
	cs.shape = sh
	cs.position.y = 1.5
	body.add_child(cs)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	if _ring != null:
		var s := 1.0 + 0.04 * sin(_t * 2.0)
		_ring.scale = Vector3(HEAL_RADIUS - 0.4, 0.2, HEAL_RADIUS - 0.4) * Vector3(s, 1, s)
