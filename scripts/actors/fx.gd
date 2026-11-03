## Прості візуальні ефекти: цифри шкоди, кільця, іскри, блискавка.
class_name Fx

static var _white: ImageTexture


static func white_texture() -> ImageTexture:
	if _white == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


static func damage_number(parent: Node, pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Palette.NIGHT
	l.font_size = 52 if big else 40
	l.pixel_size = 0.011
	l.no_depth_test = true
	l.position = pos + Vector3(randf_range(-0.2, 0.2), 0, 0)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.3, 0.85).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## Кільце, що розходиться по землі (удар, хвиля, рівень).
static func ring_burst(parent: Node, pos: Vector3, radius: float, color: Color, dur: float = 0.45) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.86
	t.outer_radius = 1.0
	t.rings = 18
	t.ring_segments = 4
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(pos.x, 0.12, pos.z)
	mi.scale = Vector3(0.3, 0.25, 0.3)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.25, radius), dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


## Вертикальний спалах блискавки (Громова мітка Перуна).
static func lightning(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 7.0, 0.12)
	mi.mesh = b
	mi.material_override = LowPoly.glow_material(Color("FFF6B0"), 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(pos.x, 3.5, pos.z)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale:x", 0.1, 0.16)
	tw.tween_callback(mi.queue_free)


## Короткий сплеск іскор.
static func sparks(parent: Node, pos: Vector3, color: Color, count: int = 10) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.09, 0.09, 0.09)
	p.mesh = m
	p.material_override = LowPoly.unshaded_material(color)
	p.amount = count
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(0.8).timeout.connect(p.queue_free)
