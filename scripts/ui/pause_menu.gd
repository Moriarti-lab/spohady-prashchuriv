## Меню «Перепочинок»: продовжити, повернення до головного екрана. Сумка, Навички, Древо — у меню героя (портрет).
class_name PauseMenu
extends Control

signal resume_pressed
signal title_pressed

var _info: Label


func _ready() -> void:
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	FolkTheme.fullscreen(dim)
	add_child(dim)
	var center := CenterContainer.new()
	FolkTheme.fullscreen(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(OrnamentBand.new())
	v.add_child(FolkTheme.label("Перепочинок", 40, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_info = FolkTheme.label("", 22, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(_info)
	var b1 := Button.new()
	b1.text = "Продовжити"
	FolkTheme.apply_button(b1, Palette.EMBROIDERY)
	b1.pressed.connect(func() -> void: resume_pressed.emit())
	v.add_child(b1)
	var b3 := Button.new()
	b3.text = "До головного екрана"
	FolkTheme.apply_button(b3, Palette.PANEL_LIGHT)
	b3.pressed.connect(func() -> void: title_pressed.emit())
	v.add_child(b3)
	v.add_child(_slider("Музика", Sound.music_volume, func(x: float) -> void: Sound.set_music_volume(x)))
	v.add_child(_slider("Звуки", Sound.sfx_volume, func(x: float) -> void: Sound.set_sfx_volume(x)))
	v.add_child(FolkTheme.label("Гра зберігається сама.", 18, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(OrnamentBand.new())


func open() -> void:
	var b: Dictionary = Blessings.get_def(GameState.blessing)
	var c: Dictionary = Gear.class_def(GameState.hero_class)
	_info.text = "%s, %s\n%s\n%s %d · %s %d · %s %d" % [
		GameState.hero_name, c["name"], b["name"],
		Strings.stat_name("str"), HeroStats.stat_shown("str"),
		Strings.stat_name("agi"), HeroStats.stat_shown("agi"),
		Strings.stat_name("faith"), HeroStats.stat_shown("faith")]
	visible = true


## Повзунок гучності (0..100 %), значення одразу зберігається.
func _slider(title: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var lb := FolkTheme.label(title, 24, Palette.LINEN)
	lb.custom_minimum_size.x = 120
	h.add_child(lb)
	var sl := HSlider.new()
	sl.name = "Slider_" + title
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(300, 48)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sl)
	var pct := FolkTheme.label("%d%%" % int(round(value * 100.0)), 22, Palette.TEXT_DIM)
	pct.custom_minimum_size.x = 70
	h.add_child(pct)
	sl.value_changed.connect(func(x: float) -> void:
		pct.text = "%d%%" % int(round(x * 100.0))
		cb.call(x))
	return h
