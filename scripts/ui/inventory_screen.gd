## Екран «Сумка»: спорядження, сітка предметів, опис, продаж; друга вкладка — вибір навичок для швидких слотів.
class_name InventoryScreen
extends Control

signal closed

const COLUMNS := 6
const TAB_BAG := 0
const TAB_SKILLS := 1

var _tab := TAB_BAG
var _bag_page: Control
var _skill_page: Control
var _tab_bag_btn: Button
var _tab_skill_btn: Button
var _gold_label: Label
var _bag_slots: Array = []
var _equip_slots := {}
var _stats_label: Label
var _detail_name: Label
var _detail_body: Label
var _detail_cmp: Label
var _btn_equip: Button
var _btn_sell: Button
var _sel_bag := -1
var _sel_equip := ""
# навички
var _quick_chips: Array = []
var _skill_grid: GridContainer
var _skill_info: Label
var _sel_quick := 0
var _sel_skill := ""
var _clear_btn: Button


func _ready() -> void:
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	FolkTheme.fullscreen(dim)
	add_child(dim)
	var margin := MarginContainer.new()
	FolkTheme.fullscreen(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FolkTheme.frame_style(0.5))
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	# заголовок
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	_tab_bag_btn = _tab_button("Сумка", TAB_BAG)
	head.add_child(_tab_bag_btn)
	_tab_skill_btn = _tab_button("Навички", TAB_SKILLS)
	head.add_child(_tab_skill_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_gold_label = FolkTheme.label("", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gold_label)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(130, 56)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	root.add_child(OrnamentBand.new(24))
	_bag_page = _build_bag_page()
	_bag_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_bag_page)
	_skill_page = _build_skill_page()
	_skill_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_skill_page)
	GameState.changed.connect(_on_changed)
	_show_tab(TAB_BAG)


func _exit_tree() -> void:
	if GameState.changed.is_connected(_on_changed):
		GameState.changed.disconnect(_on_changed)


func _tab_button(text: String, idx: int) -> Button:
	var b := Button.new()
	b.text = text
	FolkTheme.apply_button(b, Palette.PANEL_LIGHT, 24)
	b.custom_minimum_size = Vector2(150, 56)
	b.pressed.connect(func() -> void: _show_tab(idx))
	return b


func open(tab: int = TAB_BAG) -> void:
	visible = true
	_sel_bag = -1
	_sel_equip = ""
	_sel_skill = ""
	_show_tab(tab)


func _on_changed() -> void:
	if visible:
		_refresh()


func _show_tab(t: int) -> void:
	_tab = t
	_bag_page.visible = t == TAB_BAG
	_skill_page.visible = t == TAB_SKILLS
	FolkTheme.apply_button(_tab_bag_btn, Palette.EMBROIDERY if t == TAB_BAG else Palette.PANEL_LIGHT, 24)
	FolkTheme.apply_button(_tab_skill_btn, Palette.EMBROIDERY if t == TAB_SKILLS else Palette.PANEL_LIGHT, 24)
	_refresh()


# ---------- Сумка ----------

func _build_bag_page() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	# спорядження
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(220, 0)
	h.add_child(left)
	left.add_child(FolkTheme.label("Спорядження", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var eg := GridContainer.new()
	eg.columns = 2
	eg.add_theme_constant_override("h_separation", 8)
	eg.add_theme_constant_override("v_separation", 8)
	left.add_child(eg)
	for s in Items.SLOTS:
		var sl := ItemSlot.new(100.0)
		sl.equip_slot = s
		sl.caption = Items.SLOT_NAMES[s]
		sl.tapped.connect(_on_slot_tapped)
		eg.add_child(sl)
		_equip_slots[s] = sl
	_stats_label = FolkTheme.label("", 19, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	left.add_child(_stats_label)
	# сітка сумки
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	h.add_child(mid)
	mid.add_child(FolkTheme.label("Сумка", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	mid.add_child(grid)
	for i in range(GameState.BAG_SIZE):
		var sl2 := ItemSlot.new(78.0)
		sl2.index = i
		sl2.tapped.connect(_on_slot_tapped)
		grid.add_child(sl2)
		_bag_slots.append(sl2)
	# опис
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(250, 0)
	h.add_child(right)
	_detail_name = FolkTheme.label("Торкнись предмета", 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	right.add_child(_detail_name)
	_detail_body = FolkTheme.label("", 21, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
	right.add_child(_detail_body)
	_detail_cmp = FolkTheme.label("", 17, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	right.add_child(_detail_cmp)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fill)
	_btn_equip = Button.new()
	_btn_equip.text = "Одягти"
	FolkTheme.apply_button(_btn_equip, Palette.EMBROIDERY, 24)
	_btn_equip.pressed.connect(_on_equip)
	right.add_child(_btn_equip)
	_btn_sell = Button.new()
	_btn_sell.text = "Продати"
	FolkTheme.apply_button(_btn_sell, Palette.PANEL_LIGHT, 22)
	_btn_sell.pressed.connect(_on_sell)
	right.add_child(_btn_sell)
	return h


func _on_slot_tapped(sl: ItemSlot) -> void:
	if sl.equip_slot != "":
		_sel_equip = sl.equip_slot
		_sel_bag = -1
	else:
		_sel_bag = sl.index
		_sel_equip = ""
	_refresh()


func _selected_item() -> Dictionary:
	if _sel_bag >= 0 and _sel_bag < GameState.bag.size():
		return GameState.bag[_sel_bag]
	if _sel_equip != "":
		var it: Variant = GameState.equipped(_sel_equip)
		if typeof(it) == TYPE_DICTIONARY:
			return it
	return {}


func _on_equip() -> void:
	if _sel_bag >= 0:
		var slot := Items.slot_of(GameState.bag[_sel_bag]) if _sel_bag < GameState.bag.size() else ""
		if GameState.equip_from_bag(_sel_bag):
			_sel_bag = -1
			_sel_equip = slot
	elif _sel_equip != "":
		if GameState.unequip(_sel_equip):
			_sel_equip = ""
			_sel_bag = GameState.bag.size() - 1
	_refresh()


func _on_sell() -> void:
	if _sel_bag >= 0 and GameState.sell(_sel_bag) > 0:
		_sel_bag = -1
	_refresh()


func _refresh() -> void:
	_gold_label.text = "Гривні: %d    Зілля: життя %d, чар %d" % [GameState.gold, GameState.hp_potions, GameState.mana_potions]
	if _tab == TAB_BAG:
		_refresh_bag()
	else:
		_refresh_skills()


func _refresh_bag() -> void:
	for i in range(_bag_slots.size()):
		var sl: ItemSlot = _bag_slots[i]
		sl.set_item(GameState.bag[i] if i < GameState.bag.size() else null)
		sl.selected = i == _sel_bag
		sl.queue_redraw()
	for s in Items.SLOTS:
		var es: ItemSlot = _equip_slots[s]
		es.set_item(GameState.equipped(s))
		es.selected = s == _sel_equip
		es.queue_redraw()
	var wd := HeroStats.weapon_def()
	_stats_label.text = "Життя %d · Чар %d\nБроня %d (−%d%% шкоди)\nШкода %d · %s уд/с\nАтака: %s" % [
		int(HeroStats.max_hp()), int(HeroStats.max_mana()), int(HeroStats.armor()),
		int(round(HeroStats.damage_reduction() * 100.0)), int(HeroStats.weapon_damage()),
		Strings.num(snappedf(1.0 / HeroStats.attack_interval(), 0.01)), Items.kind_name(str(wd["kind"])).to_lower()]
	var it := _selected_item()
	_btn_equip.visible = not it.is_empty()
	_btn_sell.visible = _sel_bag >= 0 and not it.is_empty()
	_detail_cmp.text = ""
	if it.is_empty():
		_detail_name.text = "Торкнись предмета" if GameState.bag.size() > 0 or GameState.equipment.size() > 0 else "Сумка порожня"
		_detail_name.add_theme_color_override("font_color", Palette.LINEN)
		_detail_body.text = "Предмети падають з ворогів. Одягай кращі, зайве продавай за гривні."
		return
	var r := Items.rarity(int(it.get("rarity", 0)))
	_detail_name.text = str(it.get("name", "Річ"))
	_detail_name.add_theme_color_override("font_color", Items.rarity_color(it))
	_detail_body.text = "%s · %s · рів. %d\n%s" % [r["name"], Items.SLOT_NAMES.get(Items.slot_of(it), ""), int(it.get("ilvl", 1)), "\n".join(Items.stat_lines(it))]
	if _sel_bag >= 0:
		var cur: Variant = GameState.equipped(Items.slot_of(it))
		if typeof(cur) == TYPE_DICTIONARY and not cur.is_empty():
			_detail_cmp.text = "Зараз одягнено: %s\n%s" % [cur.get("name", ""), "\n".join(Items.stat_lines(cur))]
		else:
			_detail_cmp.text = "Слот порожній."
		_btn_equip.text = "Одягти"
		_btn_equip.disabled = false
		_btn_sell.text = "Продати за %d гривень" % Items.sell_value(it)
	else:
		_btn_equip.text = "Зняти" if GameState.bag_free() > 0 else "Сумка повна"
		_btn_equip.disabled = GameState.bag_free() <= 0


# ---------- Навички ----------

func _build_skill_page() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(FolkTheme.label("Швидкі слоти: торкнись слота, потім навички, яку хочеш у ньому.", 22, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	for i in range(GameState.QUICK_SLOTS):
		var chip := SkillChip.new(92.0)
		chip.number = i + 1
		chip.tapped.connect(func(_c: SkillChip) -> void:
			_sel_quick = i
			_refresh())
		row.add_child(chip)
		_quick_chips.append(chip)
	_clear_btn = Button.new()
	_clear_btn.text = "Спорожнити слот"
	FolkTheme.apply_button(_clear_btn, Palette.PANEL_LIGHT, 20)
	_clear_btn.custom_minimum_size = Vector2(220, 52)
	_clear_btn.pressed.connect(func() -> void:
		GameState.set_quick(_sel_quick, "")
		_refresh())
	var cr := CenterContainer.new()
	cr.add_child(_clear_btn)
	v.add_child(cr)
	v.add_child(HSeparator.new())
	v.add_child(FolkTheme.label("Вивчені навички", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_skill_grid = GridContainer.new()
	_skill_grid.columns = 5
	_skill_grid.add_theme_constant_override("h_separation", 14)
	_skill_grid.add_theme_constant_override("v_separation", 6)
	var gc := CenterContainer.new()
	gc.add_child(_skill_grid)
	v.add_child(gc)
	_skill_info = FolkTheme.label("", 20, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, true)
	_skill_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_skill_info)
	return v


func _refresh_skills() -> void:
	for i in range(_quick_chips.size()):
		var chip: SkillChip = _quick_chips[i]
		chip.set_skill(GameState.quick_skill(i))
		chip.selected = i == _sel_quick
		chip.queue_redraw()
	_clear_btn.disabled = GameState.quick_skill(_sel_quick) == ""
	for ch in _skill_grid.get_children():
		_skill_grid.remove_child(ch)
		ch.queue_free()
	for id in GameState.learned_skills():
		var chip2 := SkillChip.new(72.0)
		chip2.set_skill(str(id))
		chip2.selected = str(id) == _sel_skill
		var at := GameState.quick.find(id)
		chip2.note = "слот %d" % (at + 1) if at >= 0 else ""
		var sid: String = str(id)
		chip2.tapped.connect(func(_c: SkillChip) -> void: _on_skill_tapped(sid))
		_skill_grid.add_child(chip2)
	var txt := ""
	if _sel_skill != "" and Skills.DATA.has(_sel_skill):
		var d: Dictionary = Skills.get_def(_sel_skill)
		txt = "%s · чар %d · перезарядка %d с\n%s" % [d["name"], int(d["mana"]), int(d["cd"]), d["desc"]]
	else:
		txt = "Нові навички відкриваються на Древі звитяги."
	var b: Dictionary = Blessings.get_def(GameState.blessing)
	if b.get("skill_kind", "") == "passive":
		txt += "\nДар бога (завжди діє): %s — %s" % [b["skill_name"], b["skill_desc"]]
	_skill_info.text = txt


func _on_skill_tapped(id: String) -> void:
	_sel_skill = id
	GameState.set_quick(_sel_quick, id)
	_refresh()
