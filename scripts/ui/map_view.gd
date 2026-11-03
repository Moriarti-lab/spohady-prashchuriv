## Карта долини: міні-карта (навколо героя) і повна карта (вся долина). Показує досліджене,
## Капище, вихід, героя й ворогів у дослідженій зоні.
class_name MapView
extends Control

enum Mode { MINI, FULL }

const MINI_RANGE := 24.0         # скільки метрів від героя до краю міні-карти
const SEEN_RADIUS := 16.0        # ворогів видно, якщо вони так близько до героя або у вже відкритій клітинці
## Карта повернута, як камера: «вгору» на карті — це «вгору» на екрані гри.
const ROT := PI / 4.0
const UNEXPLORED := Color(0.06, 0.06, 0.07, 1.0)
const EXPLORED := Color(0.30, 0.37, 0.28, 1.0)
const EXPLORED_EDGE := Color(0.20, 0.25, 0.20, 1.0)

var mode := Mode.MINI
var world: GameWorld = null
var player: Player = null
var _tex: ImageTexture
var _img: Image
var _dirty := true
var _t := 0.0


func _init(p_mode: int = Mode.MINI) -> void:
	mode = p_mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func bind(p_world: GameWorld, p_player: Player) -> void:
	world = p_world
	player = p_player
	_dirty = true


func mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _rebuild_texture() -> void:
	var n := GameState.MAP_GRID
	if _img == null:
		_img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ex := GameState.explored
	var ok := ex.size() == n * n
	for y in range(n):
		for x in range(n):
			var c := UNEXPLORED
			if ok and ex[y * n + x] != 0:
				# край дослідженого темніший: м'яка межа
				var edge := false
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx < 0 or ny < 0 or nx >= n or ny >= n or ex[ny * n + nx] == 0:
						edge = true
						break
				c = EXPLORED_EDGE if edge else EXPLORED
				# за межею долини земля сіра (скелі)
				var wx := float(x - n / 2) + 0.5
				var wy := float(y - n / 2) + 0.5
				if Vector2(wx, wy).length() > GameWorld.ARENA_RADIUS - 0.5:
					c = Color(0.36, 0.36, 0.40, 1.0)
			_img.set_pixel(x, y, c)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	_dirty = false


## Масштаб (пікселів на метр) і центр (світові x, z, що лежать у центрі контролу).
func _view() -> Array:
	var cen := Vector2.ZERO
	var scale := minf(size.x, size.y) / (2.0 * (GameWorld.ARENA_RADIUS + 5.0))
	if mode == Mode.MINI:
		if player != null:
			cen = Vector2(player.global_position.x, player.global_position.z)
		scale = minf(size.x, size.y) / (2.0 * MINI_RANGE)
	return [cen, scale]


func to_px(w: Vector2, cen: Vector2, scale: float) -> Vector2:
	return size * 0.5 + (w - cen).rotated(ROT) * scale


func _draw() -> void:
	if world == null or player == null:
		return
	if _dirty or _tex == null:
		_rebuild_texture()
	var v := _view()
	var cen: Vector2 = v[0]
	var sc: float = v[1]
	draw_rect(Rect2(Vector2.ZERO, size), UNEXPLORED)
	# текстура досліджених клітинок: 1 клітинка = 1 метр
	var half := float(GameState.MAP_GRID) * 0.5
	draw_set_transform(to_px(Vector2.ZERO, cen, sc), ROT, Vector2(sc, sc))
	draw_texture_rect(_tex, Rect2(Vector2(-half, -half), Vector2(GameState.MAP_GRID, GameState.MAP_GRID)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# межа долини
	draw_arc(to_px(Vector2.ZERO, cen, sc), GameWorld.ARENA_RADIUS * sc, 0.0, TAU, 96, Color(0.62, 0.6, 0.66, 0.9), 2.5 if mode == Mode.MINI else 4.0, true)
	# вихід
	for i in range(GameWorld.EXITS.size()):
		var ep := to_px(world.exit_trigger_pos(i), cen, sc)
		var er := 6.0 if mode == Mode.MINI else 11.0
		draw_rect(Rect2(ep - Vector2(er, er * 0.7), Vector2(er * 2.0, er * 1.4)), Palette.TURQUOISE.lightened(0.2))
		draw_rect(Rect2(ep - Vector2(er, er * 0.7), Vector2(er * 2.0, er * 1.4)), Palette.GOLD, false, 2.0)
		if mode == Mode.FULL:
			_label(ep + Vector2(-60, -er - 8.0), "Вихід (зачинено)", 18, Palette.LINEN)
	# Капище
	var sp := to_px(Vector2.ZERO, cen, sc)
	var sr := 7.0 if mode == Mode.MINI else 13.0
	var diamond := PackedVector2Array([sp + Vector2(0, -sr), sp + Vector2(sr, 0), sp + Vector2(0, sr), sp + Vector2(-sr, 0)])
	draw_colored_polygon(diamond, Palette.GOLD)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Palette.NIGHT, 2.0)
	if mode == Mode.FULL:
		_label(sp + Vector2(-26, sr + 22.0), "Капище", 20, Palette.GOLD)
	# вороги (лише у вже відкритих місцях або поруч із героєм)
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var wp := Vector2(en.global_position.x, en.global_position.z)
		if wp.distance_to(pp) > SEEN_RADIUS and not GameState.is_explored(GameState.map_cell(wp)):
			continue
		var epx := to_px(wp, cen, sc)
		if not Rect2(Vector2.ZERO, size).grow(8.0).has_point(epx):
			continue
		var col := Palette.BLOOD.lightened(0.45)
		if en.kind == "wraith":
			col = Palette.TURQUOISE.lightened(0.3)
		draw_circle(epx, 3.5 if mode == Mode.MINI else 6.0, Palette.NIGHT)
		draw_circle(epx, 2.5 if mode == Mode.MINI else 4.5, col)
	# здобич
	for d in get_tree().get_nodes_in_group("loot"):
		var ld := d as LootDrop
		if ld == null:
			continue
		var lp := to_px(Vector2(ld.global_position.x, ld.global_position.z), cen, sc)
		if Rect2(Vector2.ZERO, size).has_point(lp):
			draw_circle(lp, 2.0 if mode == Mode.MINI else 3.0, Palette.GOLD)
	# герой: стрілка за напрямком погляду
	var hp := to_px(pp, cen, sc)
	var fwd := player.facing_vec2().rotated(ROT)
	var side := Vector2(-fwd.y, fwd.x)
	var hr := 7.0 if mode == Mode.MINI else 12.0
	var tri := PackedVector2Array([hp + fwd * hr * 1.3, hp - fwd * hr * 0.8 + side * hr * 0.8, hp - fwd * hr * 0.8 - side * hr * 0.8])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Palette.NIGHT, 2.0)
	if mode == Mode.FULL:
		_label(hp + Vector2(-20, -hr - 8.0), "Ти", 20, Color.WHITE)


func _label(p: Vector2, text: String, fs: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.NIGHT)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
