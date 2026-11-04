## Розмова з жителем селища: привітання, завдання (взяти / здати) і кнопка торгівлі в Радима.
class_name DialogScreen
extends Control

signal closed
signal shop_requested

const GREET := {
	"merchant": "Здоровенькі були! Дорога дальня, а речі треба добрі. Дивися, що привіз, торг не вимагаю лише з друзями.",
	"herbalist": "Заходь, не соромся. Трави збирати — діло тонке, а в лісі тепер небезпечно.",
	"elder": "Сідай, мій хлопче. Орден Єдиного стирає нашу пам'ять, а ми ще пам'ятаємо. Допоможеш?",
}
const IDLE := {
	"merchant": "Більше жодних справ. Заходь, коли потрібні речі чи зілля.",
	"herbalist": "Дякую тобі за все. Хай оберіг береже твою стежку.",
	"elder": "Іди з миром. Коли повернешся з вістями, я вислухаю.",
}

var npc_id := ""
var _title: Label
var _body: VBoxContainer
var _msg: Label


func _ready() -> void:
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	FolkTheme.fullscreen(dim)
	add_child(dim)
	var center := CenterContainer.new()
	FolkTheme.fullscreen(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(OrnamentBand.new())
	_title = FolkTheme.label("", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	v.add_child(_body)
	_msg = FolkTheme.label("", 21, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(_msg)
	var close := Button.new()
	close.text = "Бувай"
	FolkTheme.apply_button(close, Palette.PANEL_LIGHT, 24)
	close.custom_minimum_size = Vector2(0, 58)
	close.pressed.connect(func() -> void: closed.emit())
	v.add_child(close)
	v.add_child(OrnamentBand.new())


func npc_def() -> Dictionary:
	for n in Locations.get_def("village")["npcs"]:
		if str(n["id"]) == npc_id:
			return n
	return {}


func open(id: String) -> void:
	npc_id = id
	_msg.text = ""
	visible = true
	_rebuild()


func _text(t: String, col: Color = Palette.LINEN) -> void:
	_body.add_child(FolkTheme.label(t, 22, col, HORIZONTAL_ALIGNMENT_LEFT, true))


func _button(t: String, col: Color, handler: Callable) -> void:
	var b := Button.new()
	b.text = t
	FolkTheme.apply_button(b, col, 22)
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(handler)
	_body.add_child(b)


func _rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var nd := npc_def()
	_title.text = "%s · %s" % [nd.get("name", "?"), nd.get("role", "")]
	var any := false
	for qid in GameState.quests_to_turn_in(npc_id):
		any = true
		var d := Quests.get_def(qid)
		_text("«%s»\n%s" % [d["name"], d["done_text"]], Palette.GOLD)
		_button("Здати: %s (%s)" % [d["name"], Quests.reward_text(qid)], Palette.EMBROIDERY, func() -> void: _turn_in(qid))
	for qid in GameState.quests_active_for(npc_id):
		any = true
		var d2 := Quests.get_def(qid)
		_text("«%s» — ще в дорозі: %s (%d/%d)" % [d2["name"], d2["progress_text"], GameState.quest_progress(qid), int(d2["need"])], Palette.TEXT_DIM)
	for qid in GameState.quests_of(npc_id):
		any = true
		var d3 := Quests.get_def(qid)
		_text("«%s»\n%s\nНагорода: %s." % [d3["name"], d3["intro"], Quests.reward_text(qid)])
		_button("Прийняти завдання", Palette.EMBROIDERY, func() -> void: _accept(qid))
	if not any:
		_text(str(GREET.get(npc_id, "")) if GameState.quests.is_empty() else str(IDLE.get(npc_id, "")))
	if npc_id == "merchant":
		_button("Торгувати", Palette.TURQUOISE.darkened(0.25), func() -> void: shop_requested.emit())


func _accept(qid: String) -> void:
	if GameState.accept_quest(qid):
		_msg.text = "Завдання прийнято: %s. Список — у меню героя." % Quests.get_def(qid)["name"]
	_rebuild()


func _turn_in(qid: String) -> void:
	var t := GameState.turn_in_quest(qid)
	if t == "":
		_msg.text = GameState.last_error
	else:
		_msg.text = "Нагорода: %s" % t
	_rebuild()
