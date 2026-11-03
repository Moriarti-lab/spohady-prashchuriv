## Екран «Древо звитяги»: радіальне дерево перків і панель опису.
class_name PerkTreeScreen
extends Control

signal closed

var _view: PerkTreeView
var _title: Label
var _effect: Label
var _status: Label
var _points: Label
var _stats: Label
var _unlock_btn: Button
var _selected := ""


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
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	margin.add_child(h)
	_view = PerkTreeView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.node_selected.connect(_on_node_selected)
	h.add_child(_view)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Palette.PANEL, Palette.GOLD, 3, 14))
	panel.custom_minimum_size = Vector2(430, 0)
	h.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(FolkTheme.label("Древо звитяги", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(OrnamentBand.new(18))
	_points = FolkTheme.label("", 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_points)
	_stats = FolkTheme.label("", 21, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(_stats)
	v.add_child(HSeparator.new())
	_title = FolkTheme.label("Торкнись вузла", 28, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(_title)
	_effect = FolkTheme.label("", 22, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
	_effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_effect)
	_status = FolkTheme.label("", 20, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
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


func open() -> void:
	visible = true
	_refresh()


func _on_node_selected(id: String) -> void:
	_selected = id
	_refresh()


func _on_unlock() -> void:
	if _selected == "":
		return
	if GameState.unlock(_selected):
		var d: Dictionary = PerkTree.get_def(_selected)
		if d.has("skill"):
			_status.text = "Нова навичка «%s» чекає на кнопці біля атаки." % Skills.get_def(d["skill"])["name"]
	_refresh(true)


func _refresh(keep_status: bool = false) -> void:
	_points.text = "Вільних перків: %d" % GameState.perk_points
	_stats.text = "%s %d · %s %d · %s %d\nЖиття %d · Чар %d" % [
		Strings.stat_name("str"), HeroStats.stat_shown("str"),
		Strings.stat_name("agi"), HeroStats.stat_shown("agi"),
		Strings.stat_name("faith"), HeroStats.stat_shown("faith"),
		int(HeroStats.max_hp()), int(HeroStats.max_mana())]
	if _selected == "":
		_unlock_btn.disabled = true
		return
	var d: Dictionary = PerkTree.get_def(_selected)
	_title.text = d["name"]
	var fx := PerkTree.effect_text(_selected)
	if d.has("desc") and not (d.has("hp_pct") or d.has("move_pct") or d.has("mana_regen") or d.has("dmg_pct")):
		fx += ("\n" if fx != "" else "") + str(d["desc"])
	_effect.text = fx
	var reason := GameState.unlock_block_reason(_selected)
	_unlock_btn.disabled = reason != ""
	if not keep_status:
		_status.text = "Можна відкрити." if reason == "" else reason
	_view.selected = _selected
	_view.queue_redraw()
