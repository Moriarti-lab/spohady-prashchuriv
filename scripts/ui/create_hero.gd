## Створення героя: ім'я → голос Мокоші → благословення бога → клас.
class_name CreateHero
extends Control

enum Step { NAME, INTRO, BLESSING, CLASS }

var step := Step.NAME
var hero_name := ""
var blessing := ""
var hero_class := ""

var _content: VBoxContainer
var _back: Button
var _next: Button
var _name_edit: LineEdit
var _detail: Label
var _detail_title: Label
var _portrait: PortraitSlot
var _cards := {}


func _ready() -> void:
	FolkTheme.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Palette.NIGHT
	FolkTheme.fullscreen(bg)
	add_child(bg)
	var margin := MarginContainer.new()
	FolkTheme.fullscreen(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	outer.add_child(OrnamentBand.new(22))
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	outer.add_child(_content)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	outer.add_child(nav)
	_back = Button.new()
	_back.text = "Назад"
	FolkTheme.apply_button(_back, Palette.PANEL_LIGHT)
	_back.custom_minimum_size.x = 220
	_back.pressed.connect(_on_back)
	nav.add_child(_back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	_next = Button.new()
	FolkTheme.apply_button(_next, Palette.EMBROIDERY)
	_next.custom_minimum_size.x = 320
	_next.pressed.connect(_on_next)
	nav.add_child(_next)
	_show_step(Step.NAME)


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()
	_cards.clear()


func _show_step(s: Step) -> void:
	step = s
	_clear()
	match s:
		Step.NAME:
			_build_name()
		Step.INTRO:
			_build_intro()
		Step.BLESSING:
			_build_blessing()
		Step.CLASS:
			_build_class()
	_back.visible = s != Step.NAME
	_update_next()


func _update_next() -> void:
	match step:
		Step.NAME:
			_next.text = "Далі"
			_next.disabled = false
		Step.INTRO:
			_next.text = "Далі"
			_next.disabled = false
		Step.BLESSING:
			_next.text = "Далі"
			_next.disabled = blessing == ""
		Step.CLASS:
			_next.text = "Вирушити в дорогу"
			_next.disabled = hero_class == ""


func _on_back() -> void:
	match step:
		Step.INTRO:
			_show_step(Step.NAME)
		Step.BLESSING:
			_show_step(Step.INTRO)
		Step.CLASS:
			_show_step(Step.BLESSING)


func _on_next() -> void:
	match step:
		Step.NAME:
			hero_name = _name_edit.text.strip_edges()
			if hero_name == "":
				hero_name = "Мандрівник"
			_show_step(Step.INTRO)
		Step.INTRO:
			_show_step(Step.BLESSING)
		Step.BLESSING:
			_show_step(Step.CLASS)
		Step.CLASS:
			_finish()


func _finish() -> void:
	GameState.new_hero(hero_name, blessing, hero_class)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# ---------- Кроки ----------

func _title(text: String) -> void:
	_content.add_child(FolkTheme.label(text, 40, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))


func _build_name() -> void:
	_title("Хто ти, подорожній?")
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(sp)
	_content.add_child(FolkTheme.label(Strings.NAME_PROMPT, 30, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER))
	var row := CenterContainer.new()
	_content.add_child(row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Твоє ім'я"
	_name_edit.text = hero_name
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(560, 84)
	_name_edit.add_theme_font_size_override("font_size", 38)
	_name_edit.add_theme_stylebox_override("normal", FolkTheme.panel_style(Palette.PANEL, Palette.GOLD, 3, 12))
	_name_edit.add_theme_stylebox_override("focus", FolkTheme.panel_style(Palette.PANEL, Palette.LINEN, 4, 12))
	_name_edit.add_theme_color_override("font_color", Palette.LINEN)
	_name_edit.add_theme_color_override("font_placeholder_color", Palette.TEXT_DIM)
	_name_edit.add_theme_color_override("caret_color", Palette.GOLD)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_next())
	row.add_child(_name_edit)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(sp2)


func _build_intro() -> void:
	_title(Strings.MOKOSH_SIGN.trim_prefix("— "))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(sp)
	var l := FolkTheme.label(Strings.MOKOSH_INTRO % hero_name, 32, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.custom_minimum_size.x = 900
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(l)
	_content.add_child(FolkTheme.label(Strings.MOKOSH_SIGN, 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(sp2)


func _build_blessing() -> void:
	_title("Пробуджена кров")
	var p := FolkTheme.label(Strings.BLESSING_PROMPT, 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true)
	_content.add_child(p)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 18)
	_content.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	h.add_child(grid)
	for id in Blessings.IDS:
		var d: Dictionary = Blessings.get_def(id)
		var b := Button.new()
		b.text = "%s\n%s" % [d["god"], d["style"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 96
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tex := FolkTheme.art_texture(FolkTheme.PORTRAIT_DIR + "blessing_%s.png" % id)
		if tex != null:
			b.icon = tex
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 80)
		b.pressed.connect(_pick_blessing.bind(id))
		_cards[id] = b
		grid.add_child(b)
		_style_card(b, Color(d["color"]), id == blessing)
	_build_detail_panel(h)
	if blessing != "":
		_pick_blessing(blessing)


func _build_class() -> void:
	_title("Обери шлях")
	_content.add_child(FolkTheme.label(Strings.CLASS_PROMPT, 24, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true))
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 18)
	_content.add_child(h)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	h.add_child(col)
	for id in Gear.CLASS_IDS:
		var d: Dictionary = Gear.class_def(id)
		var b := Button.new()
		b.text = "%s\n%s" % [d["name"], Gear.kit_text(id).replace("\n", " · ")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 110
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_pick_class.bind(id))
		_cards[id] = b
		col.add_child(b)
		_style_card(b, Palette.LEAF.darkened(0.2), id == hero_class)
	_build_detail_panel(h)
	if hero_class != "":
		_pick_class(hero_class)


func _build_detail_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Palette.PANEL, Palette.GOLD, 3, 14))
	panel.custom_minimum_size.x = 500
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	_portrait = PortraitSlot.new(Vector2(96, 96))
	top.add_child(_portrait)
	_detail_title = FolkTheme.label("Торкнись картки", 28, Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_detail_title)
	_detail = FolkTheme.label("", 21, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_detail)


func _style_card(b: Button, c: Color, selected: bool) -> void:
	var base := c.darkened(0.5)
	var border := Palette.LINEN if selected else Palette.GOLD.darkened(0.25)
	var bw := 5 if selected else 2
	b.add_theme_stylebox_override("normal", FolkTheme.panel_style(base, border, bw, 12))
	b.add_theme_stylebox_override("hover", FolkTheme.panel_style(base.lightened(0.1), border, bw, 12))
	b.add_theme_stylebox_override("pressed", FolkTheme.panel_style(base.darkened(0.2), Palette.LINEN, 5, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Palette.LINEN)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.LINEN)
	b.add_theme_font_size_override("font_size", 22)


func _pick_blessing(id: String) -> void:
	blessing = id
	for k in _cards.keys():
		_style_card(_cards[k], Color(Blessings.get_def(k)["color"]), k == id)
	var d: Dictionary = Blessings.get_def(id)
	_detail_title.text = d["name"]
	_detail.text = "%s\n\nБонус: %s.\n\nНавичка: «%s» (%s)\n%s\n\nСтихія снарядів: %s" % [
		d["legend"], Blessings.bonus_text(id), d["skill_name"],
		"активна" if d["skill_kind"] == "active" else "пасивна", d["skill_desc"], d["element"]]
	_portrait.set_art(FolkTheme.PORTRAIT_DIR + "blessing_%s.png" % id, d["color"], str(d["god"]).substr(0, 1))
	_update_next()


func _pick_class(id: String) -> void:
	hero_class = id
	for k in _cards.keys():
		_style_card(_cards[k], Palette.LEAF.darkened(0.2), k == id)
	var d: Dictionary = Gear.class_def(id)
	var w: Dictionary = Gear.WEAPONS[d["weapon"]]
	var start: Dictionary = PerkTree.get_def(d["start_node"])
	_detail_title.text = d["name"]
	_detail.text = "%s\n\nСпорядження:\n%s\n\nЗвичайна атака: %s\nСтарт на Древі: «%s», поруч із гілкою %s." % [
		d["desc"], Gear.kit_text(id), _attack_text(w["kind"]), start["name"], d["start_near"]]
	_portrait.set_art(FolkTheme.PORTRAIT_DIR + "class_%s.png" % id, Blessings.get_def(blessing).get("color", Palette.GOLD), str(d["name"]).substr(0, 1))
	_update_next()


func _attack_text(kind: String) -> String:
	match kind:
		"melee":
			return "удар зброєю по ворогах поруч"
		"arrow":
			return "стріла вдалину"
		_:
			return "магічна куля стихії твого бога"
