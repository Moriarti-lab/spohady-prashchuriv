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
	v.custom_minimum_size = Vector2(250, 0)
	h.add_child(v)
	v.add_child(FolkTheme.label("Карта земель", 30, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(OrnamentBand.new(22))
	v.add_child(FolkTheme.label("Біла стрілка — ти.\nЗолотий ромб — Капище: там лікуються.\nЖовті кружки — люди, квадрати — будинки.\nЧервоні цятки — вороги, бірюзові — привиди, фіолетовий — міні-бос.\nЗолоті крапки — здобич і скрині.\nБірюзова брама — вихід до іншої місцевості.", 19, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 24)
	close.custom_minimum_size = Vector2(0, 60)
	close.pressed.connect(func() -> void: closed.emit())
	v.add_child(close)


func open(world: GameWorld, player: Player) -> void:
	map.bind(world, player)
	map.mark_dirty()
	visible = true
