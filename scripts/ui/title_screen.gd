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
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		var qb := Button.new()
		qb.text = "Вийти"
		FolkTheme.apply_button(qb, Palette.PANEL_LIGHT, 24)
		qb.pressed.connect(func() -> void: get_tree().quit())
		v.add_child(qb)
	var ver := FolkTheme.label("%s · без реклами · без інтернету" % Strings.VERSION, 18, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(ver)
	_build_confirm()


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
	v.add_child(FolkTheme.label("Збереженого героя буде замінено новим.", 24, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true))
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
