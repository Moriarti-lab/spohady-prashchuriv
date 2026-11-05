## Повна карта долини (відкривається дотиком по міні-карті або клавішею M).
class_name MapScreen
extends Control

signal closed

var map: MapView


func _ready() -> void:
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	FolkTheme.fullscreen(dim)
	add_child(dim)
	var center := CenterContainer.new()
	FolkTheme.fullscreen(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	center.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	map = MapView.new(MapView.Mode.FULL)
	map.custom_minimum_size = Vector2(540, 540)
	h.add_child(map)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(280, 0)
	h.add_child(v)
	var mhead := HBoxContainer.new()
	mhead.add_theme_constant_override("separation", 8)
	v.add_child(mhead)
	mhead.add_child(FolkTheme.label("Карта земель", 28, Palette.GOLD))
	var msp := Control.new()
	msp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mhead.add_child(msp)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(130, 56)
	close.pressed.connect(func() -> void: closed.emit())
	mhead.add_child(close)
	v.add_child(OrnamentBand.new(22))
	var desc_sc := ScrollContainer.new()
	desc_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(desc_sc)
	TouchScroll.attach(desc_sc)
	var desc := FolkTheme.label("Біла стрілка — ти.\nЗолотий ромб — Капище: там лікуються.\nЖовті кружки — люди, квадрати — будинки.\nЧервоні цятки — вороги, бірюзові — привиди, фіолетовий — міні-бос.\nЗолоті крапки — здобич і скрині.\nБірюзова брама — вихід до іншої місцевості.", 19, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	desc_sc.add_child(desc)


func open(world: GameWorld, player: Player) -> void:
	map.bind(world, player)
	map.mark_dirty()
	visible = true
