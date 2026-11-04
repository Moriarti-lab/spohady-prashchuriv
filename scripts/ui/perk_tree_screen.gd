## Екран «Древо звитяги»: велике дерево з прокруткою й масштабом та панель опису вузла.
class_name PerkTreeScreen
extends Control

signal closed

var _view: PerkTreeView
var _title: Label
var _effect: Label
var _status: Label
var _points: Label
var _stats: Label
var _icon: TextureRect
var _unlock_btn: Button
var _selected := ""
var _modal: Control
var _modal_row: HBoxContainer


func _ready() -> void:
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	margin.add_child(h)

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
	v.add_child(FolkTheme.label("Древо звитяги", 32, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
	_effect = FolkTheme.label("", 21, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
	_effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_effect)
	_status = FolkTheme.label("", 19, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(_status)
	_unlock_btn = Button.new()
	_unlock_btn.text = "Відкрити перк"
	FolkTheme.apply_button(_unlock_btn, Palette.EMBROIDERY)
	_unlock_btn.pressed.connect(_on_unlock)
	v.add_child(_unlock_btn)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.PANEL_LIGHT)
	close.pressed.connect(func() -> void: closed.emit())
	v.add_child(close)
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
		cv.add_child(FolkTheme.label(str(d["name"]), 26, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
		_selected = node_id
		_view.selected = node_id
		_refresh()
		_status.text = "Навичку обрано. Далі відкривай вузли Древа."


func open() -> void:
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
	_refresh()


func _on_unlock() -> void:
	if _selected == "":
		return
	if GameState.unlock(_selected):
		var d: Dictionary = PerkTree.get_def(_selected)
		if str(d.get("skill", "")) != "":
			_status.text = "Нова навичка «%s» чекає на кнопці біля атаки. Обрати навички: меню «Навички»." % Skills.get_def(d["skill"])["name"]
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
	_title.text = str(d["name"])
	_icon.texture = _view._icon_for(_selected)
	var fx := PerkTree.effect_text(_selected)
	if str(d.get("skill", "")) != "" and Skills.has(str(d["skill"])):
		var sk: String = str(d["skill"])
		fx += ("\n\n" if fx != "" else "") + Skills.describe(sk)
	var desc := str(d.get("description", ""))
	if desc != "":
		fx += ("\n\n" if fx != "" else "") + desc
	_effect.text = PerkTree.dedupe_text(fx)
	var reason := GameState.unlock_block_reason(_selected)
	_unlock_btn.disabled = reason != ""
	if not keep_status:
		_status.text = "Можна відкрити." if reason == "" else reason
	_view.selected = _selected
	_view.queue_redraw()
