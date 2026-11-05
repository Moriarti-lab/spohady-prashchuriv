## Екран «Сумка»: спорядження, сітка предметів, опис, продаж; друга вкладка — вибір навичок для швидких слотів.
class_name InventoryScreen
extends Control

signal closed

const COLUMNS := 6
const TAB_BAG := 0
const TAB_SKILLS := 1
const TAB_NAUZI := 1
const TAB_STATS := 2
## Порядок слотів у сітці спорядження (3 колонки).
const EQUIP_ORDER := ["head", "amulet", "hands", "main", "body", "off", "ring1", "feet", "ring2"]

var _tab := TAB_BAG
var _bag_page: Control
var _skill_page: Control
var _tab_bag_btn: Button
var _tab_skill_btn: Button
var _tab_stats_btn: Button
var _stats_page: Control
var _stats_box: VBoxContainer
var _btn_equip2: Button
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
var _bag_filter := "all"  # all|weapon|armor|nauz|thread|other
var _filter_btns: Dictionary = {}
var _btn_socket: Button
var _btn_stash: Button
var _btn_attach: Button
var _stash_slots: Array = []
var _sel_stash := -1


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
	_tab_skill_btn = _tab_button("Наузи", TAB_SKILLS)
	head.add_child(_tab_skill_btn)
	_tab_stats_btn = _tab_button("Характеристики", TAB_STATS)
	_tab_stats_btn.custom_minimum_size = Vector2(230, 56)
	head.add_child(_tab_stats_btn)
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
	_stats_page = _build_stats_page()
	_stats_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_stats_page)
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
	_stats_page.visible = t == TAB_STATS
	FolkTheme.apply_button(_tab_stats_btn, Palette.EMBROIDERY if t == TAB_STATS else Palette.PANEL_LIGHT, 24)
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
	left.custom_minimum_size = Vector2(290, 0)
	h.add_child(left)
	left.add_child(FolkTheme.label("Спорядження", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var eg := GridContainer.new()
	eg.columns = 3
	eg.add_theme_constant_override("h_separation", 8)
	eg.add_theme_constant_override("v_separation", 8)
	left.add_child(eg)
	for s in EQUIP_ORDER:
		var sl := ItemSlot.new(88.0)
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
	var filt := HBoxContainer.new()
	filt.add_theme_constant_override("separation", 4)
	mid.add_child(filt)
	for pair in [["all", "Усе"], ["weapon", "Зброя"], ["armor", "Броня"], ["nauz", "Наузи"], ["thread", "Нитки"], ["other", "Інше"]]:
		var fb := Button.new()
		fb.text = pair[1]
		FolkTheme.apply_button(fb, Palette.PANEL_LIGHT, 14)
		fb.custom_minimum_size = Vector2(70, 36)
		var fid: String = pair[0]
		fb.pressed.connect(func() -> void:
			_bag_filter = fid
			_refresh())
		filt.add_child(fb)
		_filter_btns[fid] = fb
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	# Сумка більша за екран: гортається пальцем (плавно, з інерцією).
	var bag_sc := ScrollContainer.new()
	bag_sc.name = "BagScroll"
	bag_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_sc.custom_minimum_size = Vector2(COLUMNS * 80.0 + 14.0, 80.0 * 5.0)
	bag_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(bag_sc)
	bag_sc.add_child(grid)
	TouchScroll.attach(bag_sc)
	for i in range(GameState.BAG_SIZE):
		var sl2 := ItemSlot.new(74.0)
		sl2.index = i
		sl2.tapped.connect(_on_slot_tapped)
		grid.add_child(sl2)
		_bag_slots.append(sl2)
	mid.add_child(FolkTheme.label("Скриня (у селищі)", 20, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var stash_grid := GridContainer.new()
	stash_grid.columns = COLUMNS
	stash_grid.add_theme_constant_override("h_separation", 6)
	stash_grid.add_theme_constant_override("v_separation", 6)
	var stash_sc := ScrollContainer.new()
	stash_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stash_sc.custom_minimum_size = Vector2(COLUMNS * 80.0 + 14.0, 80.0 * 2.0)
	mid.add_child(stash_sc)
	stash_sc.add_child(stash_grid)
	TouchScroll.attach(stash_sc)
	for i in range(GameState.STASH_SIZE):
		var ss := ItemSlot.new(64.0)
		ss.index = 1000 + i
		ss.tapped.connect(_on_stash_tapped)
		stash_grid.add_child(ss)
		_stash_slots.append(ss)
	# опис
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(250, 0)
	h.add_child(right)
	# Опис гортається, кнопки завжди внизу.
	var dsc := ScrollContainer.new()
	dsc.name = "DetailScroll"
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dsc.custom_minimum_size = Vector2(250, 120)
	right.add_child(dsc)
	TouchScroll.attach(dsc)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 6)
	dsc.add_child(dv)
	_detail_name = FolkTheme.label("Торкнись предмета", 24, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_detail_name)
	_detail_body = FolkTheme.label("", 19, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_detail_body)
	_detail_cmp = FolkTheme.label("", 16, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_detail_cmp)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	right.add_child(btns)
	_btn_equip = Button.new()
	_btn_equip.text = "Одягти"
	FolkTheme.apply_button(_btn_equip, Palette.EMBROIDERY, 19)
	_btn_equip.custom_minimum_size.y = 52
	_btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_equip.pressed.connect(_on_equip)
	btns.add_child(_btn_equip)
	_btn_equip2 = Button.new()
	FolkTheme.apply_button(_btn_equip2, Palette.PANEL_LIGHT, 17)
	_btn_equip2.custom_minimum_size.y = 52
	_btn_equip2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_equip2.pressed.connect(func() -> void: _on_equip(true))
	btns.add_child(_btn_equip2)
	_btn_sell = Button.new()
	_btn_sell.text = "Продати"
	FolkTheme.apply_button(_btn_sell, Palette.PANEL_LIGHT, 18)
	_btn_sell.custom_minimum_size.y = 52
	_btn_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_sell.pressed.connect(_on_sell)
	btns.add_child(_btn_sell)
	var btns2 := HBoxContainer.new()
	btns2.add_theme_constant_override("separation", 6)
	right.add_child(btns2)
	_btn_socket = Button.new()
	_btn_socket.text = "У гніздо науза"
	FolkTheme.apply_button(_btn_socket, Palette.TURQUOISE.darkened(0.2), 17)
	_btn_socket.custom_minimum_size.y = 48
	_btn_socket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_socket.pressed.connect(_on_socket)
	btns2.add_child(_btn_socket)
	_btn_stash = Button.new()
	_btn_stash.text = "У скриню"
	FolkTheme.apply_button(_btn_stash, Palette.PANEL_LIGHT, 17)
	_btn_stash.custom_minimum_size.y = 48
	_btn_stash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_stash.pressed.connect(_on_to_stash)
	btns2.add_child(_btn_stash)
	_btn_attach = Button.new()
	_btn_attach.text = "Вплести нитку в обраний науз"
	FolkTheme.apply_button(_btn_attach, Palette.PANEL_LIGHT, 16)
	_btn_attach.custom_minimum_size.y = 44
	_btn_attach.pressed.connect(_on_attach_thread)
	right.add_child(_btn_attach)
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


## Куди піде предмет за другою кнопкою (ліва рука / другий перстень), або "".
func _alt_slot(it: Dictionary) -> String:
	match Items.type_of(it):
		"hand1": return "off"
		"ring": return "ring2" if GameState.target_slot(it) == "ring1" else "ring1"
	return ""


func _on_equip(alt: bool = false) -> void:
	if _sel_bag >= 0 and _sel_bag < GameState.bag.size():
		var it: Dictionary = GameState.bag[_sel_bag]
		var pref := _alt_slot(it) if alt else ""
		var slot := GameState.target_slot(it, pref)
		if GameState.equip_from_bag(_sel_bag, pref):
			_sel_bag = -1
			_sel_equip = slot
	elif _sel_equip != "":
		if GameState.unequip(_sel_equip):
			_sel_equip = ""
			_sel_bag = GameState.bag.size() - 1
	_refresh()



func _on_stash_tapped(sl: ItemSlot) -> void:
	_sel_stash = sl.index - 1000
	_sel_bag = -1
	_sel_equip = ""
	_refresh()


func _on_socket() -> void:
	if _sel_bag < 0 or _sel_bag >= GameState.bag.size():
		return
	var it: Dictionary = GameState.bag[_sel_bag]
	if Nauzi.is_nauz(it):
		# перше вільне або _sel_quick
		var slot := _sel_quick
		for i in range(GameState.QUICK_SLOTS):
			if GameState.socket_nauz(i) == null:
				slot = i
				break
		if GameState.equip_nauz(slot, int(it.get("uid", 0))):
			_sel_bag = -1
	_refresh()


func _on_to_stash() -> void:
	if GameState.location != Locations.START:
		return
	if _sel_bag >= 0 and GameState.move_bag_to_stash(_sel_bag):
		_sel_bag = -1
	elif _sel_stash >= 0 and GameState.move_stash_to_bag(_sel_stash):
		_sel_stash = -1
	_refresh()


func _on_attach_thread() -> void:
	# нитка в _sel_bag → вплести в перший науз у сумці або в гнізді
	if _sel_bag < 0 or _sel_bag >= GameState.bag.size():
		return
	if not Nauzi.is_thread(GameState.bag[_sel_bag]):
		return
	var nauz_i := -1
	for i in range(GameState.bag.size()):
		if Nauzi.is_nauz(GameState.bag[i]):
			nauz_i = i
			break
	if nauz_i < 0:
		return
	var ti := _sel_bag
	if ti > nauz_i:
		# indices stable if we attach with nauz first
		pass
	GameState.attach_thread(nauz_i, ti)
	_sel_bag = -1
	_refresh()


func _on_sell() -> void:
	if _sel_bag >= 0 and GameState.sell(_sel_bag) > 0:
		_sel_bag = -1
	_refresh()


func _refresh() -> void:
	_gold_label.text = "Гривні: %d    Зілля: життя %d, чар %d" % [GameState.gold, GameState.hp_potions, GameState.mana_potions]
	if _tab == TAB_BAG:
		_refresh_bag()
	elif _tab == TAB_SKILLS:
		_refresh_skills()
	else:
		_refresh_stats()


func _refresh_bag() -> void:
	for fid in _filter_btns:
		FolkTheme.apply_button(_filter_btns[fid], Palette.EMBROIDERY if fid == _bag_filter else Palette.PANEL_LIGHT, 14)
	var view: Array = []
	for i in range(GameState.bag.size()):
		var bk := Items.bag_kind(GameState.bag[i])
		if _bag_filter == "all" or bk == _bag_filter:
			view.append(i)
	for i in range(_bag_slots.size()):
		var sl: ItemSlot = _bag_slots[i]
		if i < view.size():
			var bi: int = view[i]
			sl.index = bi
			sl.set_item(GameState.bag[bi])
			sl.selected = bi == _sel_bag
		else:
			sl.index = -1
			sl.set_item(null)
			sl.selected = false
		sl.queue_redraw()
	for i in range(_stash_slots.size()):
		var ss: ItemSlot = _stash_slots[i]
		ss.set_item(GameState.stash[i] if i < GameState.stash.size() else null)
		ss.selected = i == _sel_stash
		ss.modulate = Color(1, 1, 1, 1 if GameState.location == Locations.START else 0.45)
		ss.queue_redraw()
	var main_it: Variant = GameState.equipped("main")
	for s in Items.SLOTS:
		var es: ItemSlot = _equip_slots[s]
		es.set_item(GameState.equipped(s))
		es.ghost = main_it if (s == "off" and Items.is_two_handed(main_it)) else {}
		es.selected = s == _sel_equip
		es.queue_redraw()
	var wd := HeroStats.weapon_def()
	_stats_label.text = "Життя %d · Чар %d\nБроня %d (−%d%% шкоди)\nШкода %d · %s уд/с\nАтака: %s" % [
		int(HeroStats.max_hp()), int(HeroStats.max_mana()), int(HeroStats.armor()),
		int(round(HeroStats.damage_reduction() * 100.0)), int(HeroStats.weapon_damage()),
		Strings.num(snappedf(1.0 / HeroStats.attack_interval(), 0.01)), Items.kind_name(str(wd["kind"])).to_lower()]
	var it := _selected_item()
	_btn_equip.visible = not it.is_empty() and not Nauzi.is_nauz(it) and not Nauzi.is_thread(it)
	_btn_sell.visible = _sel_bag >= 0 and not it.is_empty()
	_btn_equip2.visible = false
	_btn_socket.visible = _sel_bag >= 0 and Nauzi.is_nauz(it)
	_btn_stash.visible = GameState.location == Locations.START and (_sel_bag >= 0 or _sel_stash >= 0)
	_btn_stash.text = "Зі скрині" if _sel_stash >= 0 else "У скриню"
	_btn_attach.visible = _sel_bag >= 0 and Nauzi.is_thread(it)
	_detail_cmp.text = ""
	if it.is_empty():
		_detail_name.text = "Торкнись предмета" if GameState.bag.size() > 0 or GameState.equipment.size() > 0 else "Сумка порожня"
		_detail_name.add_theme_color_override("font_color", Palette.LINEN)
		_detail_body.text = "Предмети падають з ворогів. Одягай кращі, зайве продавай за гривні."
		return
	var r := Items.rarity(int(it.get("rarity", 0)))
	_detail_name.text = str(it.get("name", "Річ"))
	_detail_name.add_theme_color_override("font_color", Items.rarity_color(it))
	_detail_body.text = "%s · %s · рів. %d\n%s" % [r["name"], Items.TYPE_NAMES.get(Items.type_of(it), ""), int(it.get("ilvl", 1)), "\n".join(Items.stat_lines(it))]
	if _sel_bag >= 0:
		var tslot := GameState.target_slot(it)
		var cmp: Array = []
		for dv in GameState.displaced_by(it, tslot):
			cmp.append("%s\n%s" % [dv.get("name", ""), "\n".join(Items.stat_lines(dv))])
		if cmp.is_empty():
			_detail_cmp.text = "Слот «%s» порожній." % Items.SLOT_NAMES.get(tslot, "")
		else:
			_detail_cmp.text = "Замість: " + "\n+ ".join(cmp)
		if Items.type_of(it) == "hand2":
			_detail_cmp.text += "\nДворучна: займає обидві руки."
		var alt := _alt_slot(it)
		if alt != "":
			_btn_equip2.visible = true
			_btn_equip2.text = "У ліву руку" if Items.type_of(it) == "hand1" else "У слот «%s»" % Items.SLOT_NAMES[alt]
		_btn_equip.text = "Одягти (%s)" % Items.SLOT_NAMES.get(tslot, "")
		_btn_equip.disabled = false
		_btn_sell.text = "Продати за %d гривень" % Items.sell_value(it)
	else:
		_btn_equip.text = "Зняти" if GameState.bag_free() > 0 else "Сумка повна"
		_btn_equip.disabled = GameState.bag_free() <= 0


# ---------- Навички ----------

func _build_skill_page() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(FolkTheme.label("Гнізда наузів: торкнись гнізда, потім науза зі списку (або встав із сумки на вкладці «Сумка»).", 22, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER))
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
	v.add_child(FolkTheme.label("Наузи в гніздах і сумці", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
	var shown: Dictionary = {}
	for i in range(GameState.QUICK_SLOTS):
		var sn: Variant = GameState.socket_nauz(i)
		if typeof(sn) == TYPE_DICTIONARY and sn != null:
			var sid0 := str(sn.get("skill", ""))
			shown[sid0] = true
			var chip2 := SkillChip.new(72.0)
			chip2.set_skill(sid0)
			chip2.selected = sid0 == _sel_skill
			chip2.note = "гніздо %d · р.%d" % [i + 1, int(sn.get("level", 1))]
			var sid: String = sid0
			chip2.tapped.connect(func(_c: SkillChip) -> void: _on_skill_tapped(sid))
			_skill_grid.add_child(chip2)
	for it2 in GameState.bag:
		if Nauzi.is_nauz(it2):
			var sid1 := str(it2.get("skill", ""))
			if shown.has(sid1):
				continue
			shown[sid1] = true
			var chip3 := SkillChip.new(72.0)
			chip3.set_skill(sid1)
			chip3.selected = sid1 == _sel_skill
			chip3.note = "сумка · р.%d" % int(it2.get("level", 1))
			var sidb: String = sid1
			chip3.tapped.connect(func(_c: SkillChip) -> void: _on_skill_tapped(sidb))
			_skill_grid.add_child(chip3)
	var txt := ""
	if _sel_skill != "" and Skills.DATA.has(_sel_skill):
		var d: Dictionary = Skills.get_def(_sel_skill)
		txt = "%s\n%s" % [d["name"], Skills.describe(_sel_skill, true)]
	else:
		txt = "Наузи знаходять у бою, у босів і обирають на старті. Сила росте від застосування."
	var b: Dictionary = Blessings.get_def(GameState.blessing)
	if b.get("skill_kind", "") == "passive":
		txt += "\nДар бога (завжди діє): %s — %s" % [b["skill_name"], b["skill_desc"]]
	_skill_info.text = txt


func _on_skill_tapped(id: String) -> void:
	_sel_skill = id
	GameState.set_quick(_sel_quick, id)
	_refresh()


# ---------- Характеристики ----------

func _build_stats_page() -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stats_box = VBoxContainer.new()
	_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_box.add_theme_constant_override("separation", 4)
	sc.add_child(_stats_box)
	return sc


func _pct(v: float) -> String:
	return "%s%%" % Strings.num(snappedf(v, 0.1))


func _stat_row(grid: GridContainer, name: String, value: String, tip: String = "") -> void:
	grid.add_child(FolkTheme.label(name, 20, Palette.TEXT_DIM))
	var l := FolkTheme.label(value, 20, Palette.LINEN)
	grid.add_child(l)


func _refresh_stats() -> void:
	for c in _stats_box.get_children():
		_stats_box.remove_child(c)
		c.queue_free()
	var cdef: Dictionary = Gear.class_def(GameState.hero_class)
	_stats_box.add_child(FolkTheme.label("%s · %s · рівень %d" % [GameState.hero_name, cdef.get("name", ""), GameState.level], 28, Palette.GOLD))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 2)
	_stats_box.add_child(g)
	var wd := HeroStats.weapon_def()
	if GameState.attr_points > 0:
		_stats_box.add_child(FolkTheme.label("Вільні очки атрибутів: %d (торкнись кнопки)" % GameState.attr_points, 22, Palette.GOLD))
		var ar := HBoxContainer.new()
		ar.add_theme_constant_override("separation", 8)
		_stats_box.add_child(ar)
		for pair in [["str", "Сила"], ["agi", "Спритність"], ["faith", "Віра"]]:
			var ab := Button.new()
			ab.text = "+1 " + pair[1]
			FolkTheme.apply_button(ab, Palette.EMBROIDERY, 18)
			ab.custom_minimum_size = Vector2(160, 44)
			var sid: String = pair[0]
			ab.pressed.connect(func() -> void:
				GameState.spend_attr(sid)
				_refresh())
			ar.add_child(ab)
	var rows := [
		[Strings.stat_name("str"), "%d (+%d)" % [HeroStats.stat_shown("str"), int(GameState.attr_spent.get("str", 0))]],
		[Strings.stat_name("agi"), "%d (+%d)" % [HeroStats.stat_shown("agi"), int(GameState.attr_spent.get("agi", 0))]],
		[Strings.stat_name("faith"), "%d (+%d)" % [HeroStats.stat_shown("faith"), int(GameState.attr_spent.get("faith", 0))]],
		["Життя", "%d" % int(HeroStats.max_hp())],
		["Чар", "%d" % int(HeroStats.max_mana())],
		["Відновлення чару", "%s/с" % Strings.num(snappedf(HeroStats.mana_regen(), 0.1))],
		["Відновлення життя", "%s/с" % Strings.num(snappedf(HeroStats.hp_regen(), 0.1))],
		["Броня", "%d" % int(HeroStats.armor())],
		["Зменшення шкоди", _pct(HeroStats.damage_reduction() * 100.0)],
		["Шкода атаки", "%d" % int(HeroStats.weapon_damage())],
		["Швидкість атаки", "%s уд/с" % Strings.num(snappedf(1.0 / HeroStats.attack_interval(), 0.01))],
		["Тип атаки", Items.kind_name(str(wd["kind"]))],
		["Шанс криту", _pct(HeroStats.crit_chance() * 100.0)],
		["Шкода криту", "×%s" % Strings.num(snappedf(HeroStats.crit_mult(), 0.01))],
		["Скорочення відновлення", _pct(HeroStats.cdr_pct())],
		["Швидкість руху", "%s м/с" % Strings.num(snappedf(HeroStats.move_speed(), 0.1))],
		["Вампіризм", _pct(HeroStats.lifesteal() * 100.0)],
		["Шипи (віддзеркалення)", _pct(HeroStats.thorns() * 100.0)],
		["Більше гривень", _pct((HeroStats.gold_mult() - 1.0) * 100.0)],
		["Більше здобичі", _pct((HeroStats.drop_mult() - 1.0) * 100.0)],
		["Більше досвіду", _pct((HeroStats.xp_mult() - 1.0) * 100.0)],
		["Досвід", "%d / %d" % [GameState.xp, GameState.xp_needed(GameState.level)]],
		["Вузлів Древа", "%d" % GameState.unlocked.size()],
		["Очок Древа", "%d" % GameState.perk_points],
	]
	for r in rows:
		_stat_row(g, r[0], r[1])
	_stats_box.add_child(HSeparator.new())
	# активні навички
	_stats_box.add_child(FolkTheme.label("Наузи (вміння)", 26, Palette.GOLD))
	var learned := GameState.learned_skills()
	var gl := GridContainer.new()
	gl.columns = 6
	gl.add_theme_constant_override("h_separation", 10)
	_stats_box.add_child(gl)
	for id in Skills.ORDER:
		var chip := SkillChip.new(64.0, 30.0)
		chip.set_skill(str(id))
		chip.locked = not (id in learned)
		chip.note = "" if not chip.locked else "закрита"
		var sid: String = str(id)
		chip.tapped.connect(func(_c: SkillChip) -> void: _show_skill_info(sid))
		gl.add_child(chip)
	_skill_note = FolkTheme.label("Торкнись навички, щоб побачити опис.", 19, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
	_stats_box.add_child(_skill_note)
	_stats_box.add_child(HSeparator.new())
	# пасивні вміння: помітні й ключові вузли Древа
	_stats_box.add_child(FolkTheme.label("Пасивні вміння (помітні та ключові вузли Древа)", 26, Palette.GOLD))
	var open_list: Array = []
	var closed_list: Array = []
	for id2 in PerkTree.nodes():
		var d: Dictionary = PerkTree.get_def(str(id2))
		if str(d.get("type", "")) in ["notable", "keystone", "core"]:
			(open_list if GameState.is_unlocked(str(id2)) else closed_list).append(d)
	for d2 in open_list:
		_stats_box.add_child(_passive_row(d2, true))
	if open_list.is_empty():
		_stats_box.add_child(FolkTheme.label("Поки жодного. Бери помітні вузли на Древі звитяги.", 19, Palette.TEXT_DIM))
	_stats_box.add_child(FolkTheme.label("Ще закриті: %d" % closed_list.size(), 22, Palette.TEXT_DIM))
	for d3 in closed_list:
		_stats_box.add_child(_passive_row(d3, false))


var _skill_note: Label


func _show_skill_info(id: String) -> void:
	var d: Dictionary = Skills.get_def(id)
	var learned := id in GameState.learned_skills()
	_skill_note.text = "%s%s · чар %d · перезарядка %d с\n%s" % [d["name"], "" if learned else " (закрита)", int(d["mana"]), int(d["cd"]), Skills.describe(id, learned)]


func _passive_row(d: Dictionary, open: bool) -> Control:
	var l := FolkTheme.label("%s%s: %s" % ["" if open else "🔒 ", d["name"], PerkTree.effect_text(str(d["id"])).replace("\n", "; ")], 18, Palette.LINEN if open else Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	return l
