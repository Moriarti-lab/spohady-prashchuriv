## Головний екран: назва, «Продовжити», «Нова гра».
class_name TitleScreen
extends Control

var _confirm: Control
var _t := 0.0


func _ready() -> void:
	FolkTheme.fullscreen(self)
	get_tree().paused = false
	var center := CenterContainer.new()
	FolkTheme.fullscreen(center)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(560, 0)
	center.add_child(v)
	v.add_child(OrnamentBand.new(26))
	v.add_child(FolkTheme.label(Strings.GAME_TITLE, 68, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(FolkTheme.label("Згадай нас. Допоможи.", 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(OrnamentBand.new(26))
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	v.add_child(gap)
	if GameState.has_hero:
		var cont := Button.new()
		cont.text = "Продовжити: %s, рівень %d" % [GameState.hero_name, GameState.level]
		FolkTheme.apply_button(cont, Palette.EMBROIDERY, 28)
		cont.pressed.connect(_continue)
		v.add_child(cont)
	var nb := Button.new()
	nb.text = "Нова гра"
	FolkTheme.apply_button(nb, Palette.TURQUOISE.darkened(0.25) if GameState.has_hero else Palette.EMBROIDERY, 28)
	nb.pressed.connect(_new_game)
	v.add_child(nb)
	var sb := Button.new()
	sb.name = "SlotsButton"
	sb.text = "Збереження (комірка %d)" % GameState.slot
	FolkTheme.apply_button(sb, Palette.PANEL_LIGHT, 24)
	sb.pressed.connect(_open_slots)
	v.add_child(sb)
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		var qb := Button.new()
		qb.text = "Вийти"
		FolkTheme.apply_button(qb, Palette.PANEL_LIGHT, 24)
		qb.pressed.connect(func() -> void: get_tree().quit())
		v.add_child(qb)
	var ver := FolkTheme.label("%s · без реклами · без інтернету" % Strings.VERSION, 18, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(ver)
	_build_confirm()
	_build_slots()


func _build_confirm() -> void:
	_confirm = Control.new()
	FolkTheme.fullscreen(_confirm)
	_confirm.visible = false
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	FolkTheme.fullscreen(dim)
	_confirm.add_child(dim)
	var cc := CenterContainer.new()
	FolkTheme.fullscreen(cc)
	_confirm.add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Palette.PANEL, Palette.EMBROIDERY, 4, 16))
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(620, 0)
	panel.add_child(v)
	v.add_child(FolkTheme.label("Почати спочатку?", 36, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(FolkTheme.label("Героя в комірці %d буде замінено новим. Щоб зберегти його, обери іншу комірку в «Збереженнях»." % GameState.slot, 24, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true))
	var yes := Button.new()
	yes.text = "Так, нова гра"
	FolkTheme.apply_button(yes, Palette.EMBROIDERY)
	yes.pressed.connect(_go_create)
	v.add_child(yes)
	var no := Button.new()
	no.text = "Ні, повернутися"
	FolkTheme.apply_button(no, Palette.PANEL_LIGHT)
	no.pressed.connect(func() -> void: _confirm.visible = false)
	v.add_child(no)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Palette.NIGHT)
	# м'яке «багаття» знизу
	for i in range(8):
		var k := float(i) / 8.0
		draw_circle(Vector2(s.x * 0.5, s.y * 1.05), s.y * (0.95 - k * 0.8), Color(Palette.EMBROIDERY.darkened(0.55), 0.10 + 0.03 * k))
	# коловрат: повільно крутиться
	var c := Vector2(s.x * 0.5, s.y * 0.5)
	var R := minf(s.x, s.y) * 0.46
	for arm in range(8):
		var ang := _t * 0.08 + TAU * float(arm) / 8.0
		var a := c + Vector2(cos(ang), sin(ang)) * R * 0.2
		var b := c + Vector2(cos(ang), sin(ang)) * R
		var e := b + Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5)) * R * 0.22
		draw_polyline(PackedVector2Array([a, b, e]), Color(Palette.GOLD, 0.14), 6.0)
	draw_arc(c, R * 1.02, 0.0, TAU, 80, Color(Palette.GOLD, 0.14), 4.0)
	# вишивка зверху й знизу
	_draw_band(8.0, s.x)
	_draw_band(s.y - 8.0, s.x)


func _draw_band(y: float, w: float) -> void:
	var step := 28.0
	var n := int(w / step) + 1
	for i in range(n):
		var x := float(i) * step + 14.0
		var d := PackedVector2Array([Vector2(x, y - 9), Vector2(x + 9, y), Vector2(x, y + 9), Vector2(x - 9, y)])
		draw_colored_polygon(d, Palette.EMBROIDERY)
		draw_circle(Vector2(x, y), 3.0, Palette.GOLD)


func _continue() -> void:
	GameState.go_to_world()


func _new_game() -> void:
	if GameState.has_hero:
		_confirm.visible = true
	else:
		_go_create()


func _go_create() -> void:
	get_tree().change_scene_to_file("res://scenes/create_hero.tscn")


# ---------- Комірки збереження ----------

var _slots: Control
var _slots_box: VBoxContainer
var _del_confirm: Control
var _del_label: Label
var _del_slot := 0


func _overlay() -> Array:
	var root := Control.new()
	FolkTheme.fullscreen(root)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	FolkTheme.fullscreen(dim)
	root.add_child(dim)
	var cc := CenterContainer.new()
	FolkTheme.fullscreen(cc)
	root.add_child(cc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Palette.PANEL, Palette.EMBROIDERY, 4, 16))
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(760, 0)
	panel.add_child(v)
	return [root, v]


func _build_slots() -> void:
	var o := _overlay()
	_slots = o[0]
	_slots.name = "Slots"
	var v: VBoxContainer = o[1]
	v.add_child(FolkTheme.label("Збереження", 36, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	v.add_child(_slots_box)
	var back := Button.new()
	back.text = "Назад"
	FolkTheme.apply_button(back, Palette.PANEL_LIGHT)
	back.pressed.connect(func() -> void: _slots.visible = false)
	v.add_child(back)
	var o2 := _overlay()
	_del_confirm = o2[0]
	var v2: VBoxContainer = o2[1]
	v2.add_child(FolkTheme.label("Видалити збереження?", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_del_label = FolkTheme.label("", 24, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true)
	v2.add_child(_del_label)
	var yes := Button.new()
	yes.text = "Так, видалити назавжди"
	FolkTheme.apply_button(yes, Palette.EMBROIDERY)
	yes.pressed.connect(func() -> void:
		GameState.delete_slot(_del_slot)
		_del_confirm.visible = false
		_refresh_slots())
	v2.add_child(yes)
	var no := Button.new()
	no.text = "Ні, лишити"
	FolkTheme.apply_button(no, Palette.PANEL_LIGHT)
	no.pressed.connect(func() -> void: _del_confirm.visible = false)
	v2.add_child(no)


func _open_slots() -> void:
	_refresh_slots()
	_slots.visible = true


func _refresh_slots() -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	for i in range(1, GameState.SLOT_COUNT + 1):
		var info := GameState.slot_info(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_slots_box.add_child(row)
		var txt := "Комірка %d: порожньо" % i
		if not info.is_empty():
			txt = "Комірка %d: %s, %s, рів. %d · %s" % [i, info["name"], Gear.class_def(str(info["class"])).get("name", ""), int(info["level"]), info["location"]]
		var lb := FolkTheme.label(txt + ("  ◆" if i == GameState.slot else ""), 22, Palette.GOLD if i == GameState.slot else Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lb)
		var play := Button.new()
		play.text = "Грати" if not info.is_empty() else "Нова гра"
		FolkTheme.apply_button(play, Palette.EMBROIDERY, 22)
		var idx := i
		var empty := info.is_empty()
		play.pressed.connect(func() -> void:
			GameState.select_slot(idx)
			if empty:
				_go_create()
			else:
				_continue())
		row.add_child(play)
		if not empty:
			var del := Button.new()
			del.text = "Видалити"
			FolkTheme.apply_button(del, Palette.PANEL_LIGHT, 22)
			del.pressed.connect(func() -> void:
				_del_slot = idx
				_del_label.text = "Комірка %d: %s. Цього не можна скасувати." % [idx, info["name"]]
				_del_confirm.visible = true)
			row.add_child(del)
