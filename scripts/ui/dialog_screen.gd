## Розмова з жителем селища: привітання, завдання (взяти / здати) і кнопка торгівлі в Радима.
class_name DialogScreen
extends Control

signal closed
signal shop_requested

const GREET := {
	"merchant": "Здоровенькі були! Дорога дальня, а речі треба добрі. Дивися, що привіз, торг не вимагаю лише з друзями.",
	"herbalist": "Заходь, не соромся. Трави збирати — діло тонке, а в лісі тепер небезпечно.",
	"elder": "Сідай, мій хлопче. Орден Єдиного стирає нашу пам'ять, а ми ще пам'ятаємо. Допоможеш?",
	"mokryna": "Сідай ближче до вогнища. Я Мокрина — в'яжу нитки долі в наузи. Можу розв'язати вузол або обережно вийняти одну нитку.",
}
const IDLE := {
	"merchant": "Більше жодних справ. Заходь, коли потрібні речі чи зілля.",
	"herbalist": "Дякую тобі за все. Хай оберіг береже твою стежку.",
	"elder": "Іди з миром. Коли повернешся з вістями, я вислухаю.",
	"mokryna": "Коли матимеш науз чи нитку — принось. Радим ниток не тримає, то моя справа.",
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
	var dhead := HBoxContainer.new()
	dhead.add_theme_constant_override("separation", 8)
	v.add_child(dhead)
	_title = FolkTheme.label("", 34, Palette.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dhead.add_child(_title)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(130, 56)
	close.pressed.connect(func() -> void: closed.emit())
	dhead.add_child(close)
	v.add_child(OrnamentBand.new())
	var body_sc := ScrollContainer.new()
	body_sc.custom_minimum_size = Vector2(0, 220)
	body_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(body_sc)
	TouchScroll.attach(body_sc)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_sc.add_child(_body)
	_msg = FolkTheme.label("", 21, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(_msg)
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
	if npc_id == "mokryna":
		_text("Обери науз у списку: розв'язати (шанс ниток) або вийняти одну нитку за плату.", Palette.TURQUOISE.lightened(0.3))
		var shown := 0
		for i in range(GameState.bag.size()):
			var it: Variant = GameState.bag[i]
			if not Nauzi.is_nauz(it):
				continue
			shown += 1
			var idx := i
			var cost := Nauzi.untie_cost(it)
			_button("Розв'язати «%s» (−%d гривень)" % [it.get("name", "науз"), cost], Palette.EMBROIDERY, func() -> void: _mokryna_untie(idx))
			var threads: Array = it.get("threads", [])
			if threads.size() > 0:
				var ec := Nauzi.extract_cost(it)
				_button("Вийняти нитку з «%s» (−%d)" % [it.get("name", "науз"), ec], Palette.PANEL_LIGHT, func() -> void: _mokryna_extract(idx, 0))
		if shown == 0:
			_text("У сумці немає наузів. Знайди їх у бою або обери стартовий.", Palette.TEXT_DIM)



func _mokryna_untie(bag_index: int) -> void:
	var r: Dictionary = GameState.mokryna_untie(bag_index)
	if r.is_empty():
		_msg.text = GameState.last_error if GameState.last_error != "" else "Не вдалося розв'язати."
	else:
		var n := (r.get("threads", []) as Array).size()
		if n > 0:
			_msg.text = "Розв'язано. Ниток отримано: %d (−%d гривень)." % [n, int(r.get("cost", 0))]
		else:
			_msg.text = "Розв'язано. Ниток не випало (−%d гривень)." % int(r.get("cost", 0))
	_rebuild()


func _mokryna_extract(bag_index: int, thread_index: int) -> void:
	if GameState.mokryna_extract(bag_index, thread_index):
		_msg.text = "Нитку обережно вийнято."
	else:
		_msg.text = GameState.last_error if GameState.last_error != "" else "Не вдалося вийняти нитку."
	_rebuild()

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
