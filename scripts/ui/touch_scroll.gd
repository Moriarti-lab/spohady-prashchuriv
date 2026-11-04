## Плавне прокручування пальцем для ScrollContainer, навіть коли палець стоїть на кнопці чи речі.
## Після зсуву понад поріг відпускання вже не натискає кнопку. Має інерцію.
class_name TouchScroll
extends Node

const THRESHOLD := 14.0
var sc: ScrollContainer
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _vel := 0.0
var _vel_h := 0.0
var _last_t := 0


static func attach(p_sc: ScrollContainer) -> TouchScroll:
	var t := TouchScroll.new()
	t.sc = p_sc
	p_sc.add_child(t, false, Node.INTERNAL_MODE_FRONT)
	return t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _inside(pos: Vector2) -> bool:
	return sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos)


func _input(ev: InputEvent) -> void:
	if sc == null or not sc.is_visible_in_tree():
		return
	var pressed_ev := (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch
	if pressed_ev:
		var pos: Vector2 = ev.position
		if ev.is_pressed():
			if _inside(pos):
				_down = true
				_dragging = false
				_start = pos
				_vel = 0.0
				_vel_h = 0.0
		elif _down:
			_down = false
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
		return
	var moving := (ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0) or ev is InputEventScreenDrag
	if moving and _down:
		var rel: Vector2 = ev.relative
		if not _dragging and (ev.position - _start).length() > THRESHOLD:
			_dragging = true
		if _dragging:
			sc.scroll_vertical -= int(rel.y)
			sc.scroll_horizontal -= int(rel.x)
			var now := Time.get_ticks_msec()
			var dt := maxf(float(now - _last_t) / 1000.0, 0.008)
			_last_t = now
			_vel = lerpf(_vel, -rel.y / dt, 0.5)
			_vel_h = lerpf(_vel_h, -rel.x / dt, 0.5)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _down or sc == null:
		return
	if absf(_vel) > 20.0 or absf(_vel_h) > 20.0:
		sc.scroll_vertical += int(_vel * delta)
		sc.scroll_horizontal += int(_vel_h * delta)
		_vel = move_toward(_vel, 0.0, 2400.0 * delta)
		_vel_h = move_toward(_vel_h, 0.0, 2400.0 * delta)


func is_dragging() -> bool:
	return _dragging
