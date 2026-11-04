## Журнал завдань: активні (з прогресом і місцем), потім виконані.
class_name QuestScreen
extends Control

signal closed

var _list: VBoxContainer


func _ready() -> void:
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	FolkTheme.fullscreen(dim)
	add_child(dim)
	var margin := MarginContainer.new()
	FolkTheme.fullscreen(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	var t := FolkTheme.label("Завдання", 36, Palette.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(130, 56)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	root.add_child(OrnamentBand.new(24))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)


func open() -> void:
	visible = true
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var shown := 0
	for id in GameState.active_quests():
		shown += 1
		_list.add_child(_card(str(id)))
	var done: Array = []
	for id in Quests.ORDER:
		if GameState.quest_state(id) == "done":
			done.append(id)
	if shown == 0:
		_list.add_child(FolkTheme.label("Активних завдань немає. Поговори з людьми в селищі: Зоряна, Радим і Богдан знають, кому потрібна допомога.", 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	if not done.is_empty():
		_list.add_child(FolkTheme.label("Виконано", 26, Palette.GOLD))
		for id in done:
			_list.add_child(FolkTheme.label("✓ %s" % Quests.get_def(str(id))["name"], 22, Palette.TEXT_DIM))


func _card(id: String) -> Control:
	var d := Quests.get_def(id)
	var ready := GameState.quest_state(id) == "ready"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.9), Palette.TURQUOISE if ready else Palette.GOLD.darkened(0.2), 2, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(FolkTheme.label(str(d["name"]), 26, Palette.GOLD))
	v.add_child(FolkTheme.label(str(d["progress_text"]), 21, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true))
	var status := "%d / %d" % [GameState.quest_progress(id), int(d["need"])]
	if ready:
		status = "Готово: віднеси " + _npc_name(str(d["turn_in"]))
	v.add_child(FolkTheme.label("Прогрес: %s" % status, 21, Palette.TURQUOISE.lightened(0.4) if ready else Palette.LINEN))
	v.add_child(FolkTheme.label("Нагорода: %s" % Quests.reward_text(id), 19, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	return p


func _npc_name(id: String) -> String:
	for n in Locations.get_def("village")["npcs"]:
		if str(n["id"]) == id:
			return "%s (%s)" % [n["name"], n["role"]]
	return id
