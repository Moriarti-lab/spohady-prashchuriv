## Екран «Древо звитяги»: велике дерево з прокруткою й масштабом та панель опису вузла.
class_name PerkTreeScreen
extends Control

signal closed

var _view: PerkTreeView
var _title: Label
var _effect: RichTextLabel
var _status: Label
var _points: Label
var _stats: Label
var _icon: TextureRect
var _unlock_btn: Button
var _selected := ""
var _modal: Control
var _modal_row: HBoxContainer
var _confirm: AcceptDialog


func _ready() -> void:
	_confirm = AcceptDialog.new()
	_confirm.title = "Скидання Древа"
	_confirm.ok_button_text = "Підтвердити"
	add_child(_confirm)
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.05, 1.0)
	FolkTheme.fullscreen(bg)
	add_child(bg)
	var margin := MarginContainer.new()
	FolkTheme.fullscreen(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	margin.add_child(root_v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root_v.add_child(head)
	head.add_child(FolkTheme.label("Древо звитяги", 32, Palette.GOLD))
	var head_sp := Control.new()
	head_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_sp)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(130, 56)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(h)

	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	_view = PerkTreeView.new()
	FolkTheme.fullscreen(_view)
	_view.node_selected.connect(_on_node_selected)
	left.add_child(_view)
	# кнопки керування виглядом
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.position = Vector2(10, 10)
	left.add_child(tools)
	for spec in [["+", 1.25], ["−", 0.8]]:
		var b := Button.new()
		b.text = spec[0]
		FolkTheme.apply_button(b, Palette.PANEL_LIGHT, 34)
		b.custom_minimum_size = Vector2(64, 64)
		var f: float = spec[1]
		b.pressed.connect(func() -> void: _view.zoom_center(f))
		tools.add_child(b)
	var cb := Button.new()
	cb.text = "Центр"
	FolkTheme.apply_button(cb, Palette.PANEL_LIGHT, 20)
	cb.custom_minimum_size = Vector2(96, 64)
	cb.pressed.connect(_focus_start)
	tools.add_child(cb)
	var hint := FolkTheme.label("Тягни — рухати · щипок — масштаб", 18, Palette.TEXT_DIM)
	hint.position = Vector2(14, 0)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position.y -= 34.0
	hint.position.x = 14.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(hint)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	panel.custom_minimum_size = Vector2(390, 0)
	h.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(FolkTheme.label("Вузол", 26, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(OrnamentBand.new(26))
	_points = FolkTheme.label("", 24, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_points)
	_stats = FolkTheme.label("", 18, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(_stats)
	v.add_child(HSeparator.new())
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	v.add_child(tr)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.add_child(_icon)
	_title = FolkTheme.label("Торкнись вузла", 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(_title)
	var effect_sc := ScrollContainer.new()
	effect_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(effect_sc)
	TouchScroll.attach(effect_sc)
	_effect = DescFormat.make_rich()
	_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_sc.add_child(_effect)
	_status = FolkTheme.label("", 19, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(_status)
	_unlock_btn = Button.new()
	_unlock_btn.text = "Відкрити перк"
	FolkTheme.apply_button(_unlock_btn, Palette.EMBROIDERY, 22)
	_unlock_btn.custom_minimum_size = Vector2(0, 52)
	_unlock_btn.pressed.connect(_on_unlock)
	v.add_child(_unlock_btn)
	_build_starter_modal()


func _build_starter_modal() -> void:
	_modal = Control.new()
	FolkTheme.fullscreen(_modal)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	FolkTheme.fullscreen(dim)
	_modal.add_child(dim)
	var c := CenterContainer.new()
	FolkTheme.fullscreen(c)
	_modal.add_child(c)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(FolkTheme.label("Обери стартову навичку", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(FolkTheme.label("Одну з трьох: безкоштовно, один раз. Решту навичок відкриєш на Древі.", 21, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(OrnamentBand.new(24))
	_modal_row = HBoxContainer.new()
	_modal_row.add_theme_constant_override("separation", 14)
	v.add_child(_modal_row)


func _show_starter_modal() -> void:
	for ch in _modal_row.get_children():
		_modal_row.remove_child(ch)
		ch.queue_free()
	for c in GameState.starter_choices():
		var sid: String = c["skill"]
		var node_id: String = c["node"]
		var d: Dictionary = Skills.get_def(sid)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 0)
		card.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.95), Palette.GOLD.darkened(0.2), 2, 10))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		var chip := SkillChip.new(92.0, 4.0)
		chip.set_skill(sid)
		chip.note = " "
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()
		cc.add_child(chip)
		cv.add_child(cc)
		cv.add_child(FolkTheme.label(str(d.get("name", sid)), 26, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(FolkTheme.label(Skills.role_name(sid), 20, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
		var tx := FolkTheme.label(Skills.describe(sid), 19, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
		tx.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(tx)
		var b := Button.new()
		b.text = "Обрати"
		FolkTheme.apply_button(b, Palette.EMBROIDERY, 24)
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func() -> void: _on_starter_picked(node_id))
		cv.add_child(b)
		_modal_row.add_child(card)
	_modal.visible = true


func _on_starter_picked(node_id: String) -> void:
	if GameState.choose_starter(node_id):
		_modal.visible = false
		var st := PerkTree.class_start(GameState.hero_class)
		_selected = st
		_view.selected = st
		_focus_start()
		_refresh()
		_status.text = "Стартовий науз обрано. Далі відкривай пасивні вузли Древа."



func _ensure_respec_ui() -> void:
	if has_meta("respec_ui"):
		return
	set_meta("respec_ui", true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var b1 := Button.new()
	b1.text = "Скинути вузол (−50×рівень)"
	FolkTheme.apply_button(b1, Palette.PANEL_LIGHT, 16)
	b1.custom_minimum_size = Vector2(240, 44)
	b1.pressed.connect(func() -> void:
		var id := str(get_meta("sel_node", ""))
		if id == "":
			_status.text = "Обери вузол для часткового скиду."
			return
		if GameState.respec_node(id):
			_status.text = "Вузол і залежні повернуто. Перки оновлено."
			_refresh()
		else:
			_status.text = "Не вдалося (ціна %d гривень або вузол потрібний для шляху)." % (50 * GameState.level)
	)
	row.add_child(b1)
	var b2 := Button.new()
	b2.text = "Повне скидання (−200×рівень)"
	FolkTheme.apply_button(b2, Palette.EMBROIDERY, 16)
	b2.custom_minimum_size = Vector2(260, 44)
	b2.pressed.connect(func() -> void:
		_confirm.dialog_text = "Повне скидання Древа коштує %d гривень. Продовжити?" % (200 * GameState.level)
		_confirm.confirmed.connect(func() -> void:
			if GameState.respec_full(false):
				_status.text = "Древо скинуто. Перки повернуто."
				_refresh()
			else:
				_status.text = "Потрібно %d гривень або Вода забуття." % (200 * GameState.level)
		, CONNECT_ONE_SHOT)
		_confirm.popup_centered()
	)
	row.add_child(b2)
	var b3 := Button.new()
	b3.text = "Вода забуття"
	FolkTheme.apply_button(b3, Palette.TURQUOISE.darkened(0.2), 16)
	b3.custom_minimum_size = Vector2(160, 44)
	b3.pressed.connect(func() -> void:
		_confirm.dialog_text = "Використати Воду забуття (залишок: %d)?" % GameState.oblivion_water
		_confirm.confirmed.connect(func() -> void:
			if GameState.respec_full(true):
				_status.text = "Вода забуття: Древо скинуто."
				_refresh()
			else:
				_status.text = "Немає Води забуття (залишок %d)." % GameState.oblivion_water
		, CONNECT_ONE_SHOT)
		_confirm.popup_centered()
	)
	row.add_child(b3)
	# try attach under root
	if _status.get_parent() != null:
		_status.get_parent().add_child(row)


func open() -> void:
	_ensure_respec_ui()
	visible = true
	_modal.visible = false
	if GameState.starter_pending():
		_show_starter_modal()
	_selected = ""
	_view.selected = ""
	_focus_start()
	_refresh()


func _focus_start() -> void:
	var st := PerkTree.class_start(GameState.hero_class)
	_view.focus_on(st, 0.55)


func _on_node_selected(id: String) -> void:
	_selected = id
	set_meta("sel_node", id)
	_refresh()


func _on_unlock() -> void:
	if _selected == "":
		return
	if GameState.unlock(_selected):
		var d: Dictionary = PerkTree.get_def(_selected)
		if str(d.get("skill", "")) != "":
			_status.text = "Вузол відкрито. Активні вміння — це наузи: дивись вкладку «Наузи»."
			_refresh(true)
			return
	_refresh()


func _refresh(keep_status: bool = false) -> void:
	_points.text = "Вільних перків: %d" % GameState.perk_points
	_stats.text = "%s %d · %s %d · %s %d\nЖиття %d · Чар %d" % [
		Strings.stat_name("str"), HeroStats.stat_shown("str"),
		Strings.stat_name("agi"), HeroStats.stat_shown("agi"),
		Strings.stat_name("faith"), HeroStats.stat_shown("faith"),
		int(HeroStats.max_hp()), int(HeroStats.max_mana())]
	if _selected == "":
		_unlock_btn.disabled = true
		_icon.texture = null
		return
	var d: Dictionary = PerkTree.get_def(_selected)
	_title.text = str(d.get("name", _selected))
	_icon.texture = _view._icon_for(_selected)
	var fx := PerkTree.effect_text(_selected)
	if str(d.get("skill", "")) != "" and Skills.has(str(d["skill"])):
		var sk: String = str(d["skill"])
		fx += ("\n\n" if fx != "" else "") + Skills.describe(sk)
	var desc := str(d.get("description", ""))
	if desc != "":
		fx += ("\n\n" if fx != "" else "") + desc
	_effect.text = DescFormat.node_bb(_selected) if _selected != "" else ""
	var reason := GameState.unlock_block_reason(_selected)
	_unlock_btn.disabled = reason != ""
	if not keep_status:
		_status.text = "Можна відкрити." if reason == "" else reason
	_view.selected = _selected
	_view.queue_redraw()
