## Круглий значок навички для екрана навичок: слот швидкого доступу або вивчена навичка.
class_name SkillChip
extends Control

signal tapped(chip: SkillChip)

var skill_id := ""
var selected := false
var number := 0              # номер слота (1–4), 0 — без номера
var note := ""               # напис під значком (замість назви)
var locked := false          # ще не вивчена: тьмяний значок
var _press_pos := Vector2.ZERO
var _down := false
var _d := 84.0


func _init(diameter: float = 84.0, label_h: float = 34.0) -> void:
	_d = diameter
	custom_minimum_size = Vector2(maxf(diameter + 12.0, 120.0), diameter + label_h)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_skill(id: String) -> void:
	skill_id = id
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			_press_pos = mb.position
		else:
			if _down and mb.position.distance_to(_press_pos) < 24.0:
				tapped.emit(self)
			_down = false
		accept_event()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, _d * 0.5 + 4.0)
	var r := _d * 0.5
	var def: Dictionary = Skills.get_def(skill_id)
	var base: Color = Color(def["color"]).darkened(0.45) if not def.is_empty() else Palette.PANEL_LIGHT
	draw_circle(c, r, Color(base, 0.9))
	if not def.is_empty():
		var tex := Icons.texture(Icons.skill_icon_id(skill_id, GameState.blessing))
		var tint := Color(0.55, 0.55, 0.6, 0.8) if locked else Color.WHITE
		if tex != null:
			# значок вписано в коло з відступом ~12%, щоб кінчики не обрізались маскою
			var dd := (r - 3.0) * 2.0 * 0.88
			draw_texture_rect(tex, Rect2(c - Vector2(dd, dd) * 0.5, Vector2(dd, dd)), false, tint)
		else:
			_text(str(def["short"]), c + Vector2(0, 7), int(_d * 0.24), Palette.LINEN if not locked else Palette.TEXT_DIM, true)
	else:
		_text("—", c + Vector2(0, 8), int(_d * 0.34), Palette.TEXT_DIM, true)
	draw_arc(c, r - 1.5, 0.0, TAU, 40, Color.WHITE if selected else Palette.GOLD, 5.0 if selected else 3.0, true)
	if number > 0:
		draw_circle(c + Vector2(-r * 0.72, -r * 0.72), 13.0, Palette.NIGHT)
		draw_arc(c + Vector2(-r * 0.72, -r * 0.72), 13.0, 0.0, TAU, 20, Palette.GOLD, 2.0, true)
		_text("%d" % number, c + Vector2(-r * 0.72, -r * 0.72 + 7.0), 19, Palette.LINEN, true)
	var cap := note if note != "" else (str(def["name"]) if not def.is_empty() else "Порожньо")
	_text(cap, Vector2(size.x * 0.5, _d + 28.0), 17, Palette.LINEN if not def.is_empty() else Palette.TEXT_DIM, true)


func _text(t: String, p: Vector2, fs: int, col: Color, centered: bool) -> void:
	var font := ThemeDB.fallback_font
	var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := p - Vector2(ts.x * 0.5, 0) if centered else p
	draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Palette.NIGHT)
	draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
