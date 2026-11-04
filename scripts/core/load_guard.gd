## Запобіжник завантаження світу: збирає помилки рушія (Logger) і, якщо світ не показався
## за відведений час, прибирає темну заслону й показує повідомлення українською з текстом помилки.
## Замість чорного екрана гравець бачить, що сталося, і може повернутися в меню.
class_name LoadGuard
extends Node

const TIMEOUT := 15.0

class ErrLogger extends Logger:
	var lines: Array = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		lines.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		if lines.size() > 12:
			lines.pop_front()
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func recent() -> Array:
		mutex.lock()
		var out := lines.duplicate()
		mutex.unlock()
		return out

static var logger: ErrLogger = null

var _t := 0.0
var _armed := false
var _shown := false


static func install() -> void:
	if logger == null:
		logger = ErrLogger.new()
		OS.add_logger(logger)


static func recent_errors() -> Array:
	return logger.recent() if logger != null else []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Викликати перед переходом у світ.
func arm() -> void:
	_t = 0.0
	_armed = true
	_shown = false


func _process(delta: float) -> void:
	if not _armed:
		return
	var w := get_tree().current_scene
	if w != null and w.has_method("is_ready_for_play") and w.is_ready_for_play():
		_armed = false
		return
	_t += delta
	if _t >= TIMEOUT:
		_armed = false
		show_failure("Світ не завантажився за %d с." % int(TIMEOUT))


func show_failure(reason: String) -> void:
	if _shown:
		return
	_shown = true
	var w := get_tree().current_scene
	if w != null and w.has_method("force_reveal"):
		w.force_reveal()
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40; v.offset_right = -40; v.offset_top = 30; v.offset_bottom = -30
	bg.add_child(v)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 22)
	var errs := recent_errors()
	l.text = "Ой! Під час завантаження світу сталася помилка.\n%s\n\n%s\n\nНадішли, будь ласка, знімок цього екрана розробнику." % [reason, "\n".join(errs) if not errs.is_empty() else "Подробиць помилки немає."]
	v.add_child(l)
	var h := HBoxContainer.new()
	v.add_child(h)
	var b1 := Button.new()
	b1.text = "Продовжити"
	b1.custom_minimum_size = Vector2(220, 64)
	b1.pressed.connect(func(): layer.queue_free(); get_tree().paused = false)
	h.add_child(b1)
	var b2 := Button.new()
	b2.text = "У головне меню"
	b2.custom_minimum_size = Vector2(260, 64)
	b2.pressed.connect(func(): layer.queue_free(); get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/main.tscn"))
	h.add_child(b2)
	get_tree().root.add_child(layer)
