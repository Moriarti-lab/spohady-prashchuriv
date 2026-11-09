## Повноекранне Древо: карта на весь екран; деталі вузла — висувна панель праворуч.
class_name PerkTreeScreen
extends Control

signal closed

var _view: PerkTreeView
var _title: Label
var _effect: RichTextLabel
var _status: Label
var _points: Label
var _stats: RichTextLabel
var _icon: TextureRect
var _unlock_btn: Button
var _selected := ""
var _modal: Control
var _modal_row: HBoxContainer
var _confirm: AcceptDialog
var _confirm_cancel_btn: Button
var _detail: PanelContainer
var _detail_open := false
var _respec_row: HBoxContainer


func _ready() -> void:
	_confirm = AcceptDialog.new()
	_confirm.title = "Скидання Древа"
	_confirm.ok_button_text = "Підтвердити"
	_confirm_cancel_btn = _confirm.add_cancel_button("Скасувати")
	add_child(_confirm)
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.05, 1.0)
	FolkTheme.fullscreen(bg)
	add_child(bg)

	# повноекранна карта
	_view = PerkTreeView.new()
	FolkTheme.fullscreen(_view)
	_view.node_selected.connect(_on_node_selected)
	_view.empty_tapped.connect(_hide_detail)
	add_child(_view)

	# верхня панель: непрозора підкладка, щоб вузли не перекривали текст
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 84
	top_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.09, 0.06, 0.05, 1.0)
	top_sb.border_color = Color(Palette.GOLD, 0.4)
	top_sb.set_border_width_all(0)
	top_sb.border_width_bottom = 2
	top_sb.content_margin_left = 10
	top_sb.content_margin_right = 10
	top_sb.content_margin_top = 10
	top_sb.content_margin_bottom = 8
	top_panel.add_theme_stylebox_override("panel", top_sb)
	add_child(top_panel)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	top_panel.add_child(head)
	head.add_child(FolkTheme.label("Древо звитяги", 28, Palette.GOLD))
	_points = FolkTheme.label("", 18, Palette.LINEN)
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_points)
	_stats = DescFormat.make_rich()
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stats.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stats.custom_minimum_size = Vector2(0, 28)
	_stats.add_theme_font_size_override("normal_font_size", 17)
	head.add_child(_stats)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	_respec_row = HBoxContainer.new()
	_respec_row.add_theme_constant_override("separation", 6)
	head.add_child(_respec_row)
	_build_respec_buttons(_respec_row)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(140, 52)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)

	# zoom tools
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.position = Vector2(14, 98)
	tools.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tools)
	for spec in [["+", 1.25], ["−", 0.8]]:
		var b := Button.new()
		b.text = spec[0]
		FolkTheme.apply_button(b, Palette.PANEL_LIGHT, 34)
		b.custom_minimum_size = Vector2(64, 64)
		var f: float = spec[1]
		b.pressed.connect(func() -> void: _view.zoom_center(f))
		tools.add_child(b)
	var cb := Button.new()
	cb.text = "Корінь"
	FolkTheme.apply_button(cb, Palette.PANEL_LIGHT, 18)
	cb.custom_minimum_size = Vector2(96, 56)
	cb.pressed.connect(_focus_start)
	tools.add_child(cb)
	var cb2 := Button.new()
	cb2.text = "Крона"
	FolkTheme.apply_button(cb2, Palette.PANEL_LIGHT, 18)
	cb2.custom_minimum_size = Vector2(96, 56)
	cb2.pressed.connect(func() -> void:
		if PerkTree.has_node("core"):
			_view.focus_on("core", 0.35))
	tools.add_child(cb2)

	var hint := FolkTheme.label("Тягни — рухати · щипок — масштаб · торкнись вузла", 17, Palette.TEXT_DIM)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(14, -36)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	# висувна панель деталей (праворуч)
	_detail = PanelContainer.new()
	_detail.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	_detail.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_detail.offset_left = -360
	_detail.offset_top = 92
	_detail.offset_bottom = -16
	_detail.offset_right = -12
	_detail.visible = false
	_detail.clip_contents = true
	add_child(_detail)
	var dv_pad := MarginContainer.new()
	dv_pad.clip_contents = true
	for side in ["left", "right", "top", "bottom"]:
		dv_pad.add_theme_constant_override("margin_" + side, 4)
	_detail.add_child(dv_pad)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dv.clip_contents = true
	dv_pad.add_child(dv)
	var dhead := HBoxContainer.new()
	dhead.add_theme_constant_override("separation", 8)
	dv.add_child(dhead)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dhead.add_child(_icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	_title = FolkTheme.label("Вузол", 20, Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.max_lines_visible = 2
	title_box.add_child(_title)
	dhead.add_child(title_box)
	var hide_btn := Button.new()
	hide_btn.text = "×"
	FolkTheme.apply_button(hide_btn, Palette.PANEL_LIGHT, 22)
	hide_btn.custom_minimum_size = Vector2(48, 48)
	hide_btn.pressed.connect(_hide_detail)
	dhead.add_child(hide_btn)
	var band_wrap := MarginContainer.new()
	band_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band_wrap.clip_contents = true
	band_wrap.add_theme_constant_override("margin_right", 2)
	band_wrap.add_theme_constant_override("margin_left", 2)
	var band := OrnamentBand.new(18)
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.clip_contents = true
	band_wrap.add_child(band)
	dv.add_child(band_wrap)
	var effect_sc := ScrollContainer.new()
	effect_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(effect_sc)
	TouchScroll.attach(effect_sc)
	_effect = DescFormat.make_rich()
	_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_sc.add_child(_effect)
	_status = FolkTheme.label("", 18, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_status)
	_unlock_btn = Button.new()
	_unlock_btn.text = "Відкрити перк"
	FolkTheme.apply_button(_unlock_btn, Palette.EMBROIDERY, 22)
	_unlock_btn.custom_minimum_size = Vector2(0, 56)
	_unlock_btn.pressed.connect(_on_unlock)
	dv.add_child(_unlock_btn)

	_build_starter_modal()


func _build_respec_buttons(row: HBoxContainer) -> void:
	var menu := MenuButton.new()
	menu.text = "Скидання ▾"
	FolkTheme.apply_button(menu, Palette.PANEL_LIGHT, 16)
	menu.custom_minimum_size = Vector2(140, 48)
	var popup := menu.get_popup()
	popup.add_item("Скинути вузол (−50×рівень)", 0)
	popup.add_item("Повне скидання (−200×рівень)", 1)
	popup.add_item("Вода забуття", 2)
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0:
				var nid := _selected
				if nid == "":
					_status_toast("Обери вузол для часткового скиду.")
					return
				if GameState.respec_node(nid):
					_status_toast("Вузол і залежні повернуто.")
					_refresh()
				else:
					_status_toast("Не вдалося (ціна %d гривень)." % (50 * GameState.level))
			1:
				_confirm.dialog_text = "Повне скидання Древа (−%d гривень)?" % (200 * GameState.level)
				_clear_confirm_handlers()
				_confirm.confirmed.connect(_on_confirm_respec_gold, CONNECT_ONE_SHOT)
				_confirm.popup_centered()
			2:
				_confirm.dialog_text = "Використати Воду забуття (залишок: %d)?" % GameState.oblivion_water
				_clear_confirm_handlers()
				_confirm.confirmed.connect(_on_confirm_respec_water, CONNECT_ONE_SHOT)
				_confirm.popup_centered()
	)
	row.add_child(menu)




func _clear_confirm_handlers() -> void:
	for c in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(c["callable"])


func _on_confirm_respec_gold() -> void:
	if GameState.respec_full(false):
		_status_toast("Древо скинуто.")
		_refresh()
	else:
		_status_toast("Недостатньо гривень.")


func _on_confirm_respec_water() -> void:
	if GameState.respec_full(true):
		_status_toast("Вода забуття: Древо скинуто.")
		_refresh()
	else:
		_status_toast("Немає Води забуття.")


func _status_toast(msg: String) -> void:
	_status.text = msg
	if _detail_open:
		pass


func _ensure_respec_ui() -> void:
	# кнопки вже в верхній панелі
	pass


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
	v.add_child(FolkTheme.label("Обери стартовий науз", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(FolkTheme.label("Одну з трьох: безкоштовно, один раз.", 21, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER))
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
		_status_toast("Стартовий науз обрано. Далі відкривай пасивні вузли Древа.")


func open() -> void:
	_ensure_respec_ui()
	visible = true
	_modal.visible = false
	_hide_detail()
	if GameState.starter_pending():
		_show_starter_modal()
	_selected = ""
	_view.selected = ""
	_focus_start()
	_refresh()


func _focus_start() -> void:
	var st := PerkTree.class_start(GameState.hero_class)
	_view.focus_on(st, 0.42)


func _on_node_selected(id: String) -> void:
	_selected = id
	set_meta("sel_node", id)
	_show_detail()
	_refresh()


func _show_detail() -> void:
	_detail.visible = true
	_detail_open = true


func _hide_detail() -> void:
	_detail.visible = false
	_detail_open = false
	_selected = ""
	if _view:
		_view.selected = ""


func _on_unlock() -> void:
	if _selected == "":
		return
	if GameState.unlock(_selected):
		_status_toast("Вузол відкрито.")
		_refresh(true)
		return
	_refresh()


func _refresh(keep_status: bool = false) -> void:
	_points.text = "Перки: %d" % GameState.perk_points
	var hs: String = str(Palette.STAT_BB.get("str", "D8574B"))
	var ha: String = str(Palette.STAT_BB.get("agi", "7CBF5A"))
	var hf: String = str(Palette.STAT_BB.get("faith", "E0A526"))
	_stats.text = "[color=#%s]%s %d[/color] · [color=#%s]%s %d[/color] · [color=#%s]%s %d[/color] · Життя %d · Чар %d · Вода %d" % [
		hs, Strings.stat_name("str"), HeroStats.stat_shown("str"),
		ha, Strings.stat_name("agi"), HeroStats.stat_shown("agi"),
		hf, Strings.stat_name("faith"), HeroStats.stat_shown("faith"),
		int(HeroStats.max_hp()), int(HeroStats.max_mana()), GameState.oblivion_water]
	if _selected == "" or not _detail_open:
		_unlock_btn.disabled = true
		return
	var d: Dictionary = PerkTree.get_def(_selected)
	_title.text = str(d.get("name", _selected))
	_icon.texture = _view._icon_for(_selected)
	_effect.text = DescFormat.node_bb(_selected)
	var openable := false
	if not GameState.is_unlocked(_selected) and not GameState.starter_pending() and GameState.perk_points > 0:
		for nb in PerkTree.neighbors(_selected):
			if GameState.is_unlocked(nb):
				openable = true
				break
	_unlock_btn.disabled = not openable
	if not keep_status:
		_status.text = ""
