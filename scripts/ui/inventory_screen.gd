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
var _detail_rich: RichTextLabel
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
var _bag_filter := "all"  # all|weapon|armor|nauz|thread|other
var _filter_btns: Dictionary = {}
var _btn_socket: Button
var _btn_stash: Button
var _action_bar: VBoxContainer
var _detail_scroll: ScrollContainer
var _more_menu: MenuButton
var _btn_attach: Button
var _stash_slots: Array = []
var _sel_stash := -1
var _nauz_focus: Dictionary = {}  # {"where": "bag"|"socket", "index": int}
var _thread_slot_sel := -1
var _thread_slot_row: HBoxContainer
var _thread_pick_box: VBoxContainer
var _confirm: AcceptDialog
var _sell_cancel_btn: Button
# Nauzi redesign 0.5.4.1
var _sel_nauz_uid := -1
var _sel_thread_uid := -1
var _nauz_inner := 0  # 0 наузи, 1 нитки
var _equip_pick_mode := false
var _nauz_tab_btn: Button
var _thread_tab_btn: Button
var _nauz_target_label: Label
var _nauz_list_title: Label
var _nauz_action_bar: VBoxContainer
var _nauz_detail_scroll: ScrollContainer
var _nauz_detail_rich: RichTextLabel
var _btn_nauz_equip: Button
var _btn_nauz_unequip: Button
var _btn_weave: Button
var _socket_pick_row: HBoxContainer


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
	panel.clip_contents = true
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.clip_contents = true
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
	_confirm = AcceptDialog.new()
	_confirm.title = "Підтвердження"
	_confirm.ok_button_text = "Так"
	_sell_cancel_btn = _confirm.add_cancel_button("Скасувати")
	_confirm.canceled.connect(_on_sell_canceled)
	add_child(_confirm)
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
	_sel_nauz_uid = -1
	_sel_thread_uid = -1
	_equip_pick_mode = false
	_nauz_inner = 0
	_thread_slot_sel = -1
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
	h.add_theme_constant_override("separation", 10)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# спорядження (у вузькому landscape скролиться, щоб не виштовхувати ActionBar)
	var left_sc := ScrollContainer.new()
	left_sc.name = "EquipScroll"
	left_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_sc.custom_minimum_size = Vector2(250, 80)
	left_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_sc.clip_contents = true
	h.add_child(left_sc)
	TouchScroll.attach(left_sc)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_sc.add_child(left)
	left.add_child(FolkTheme.label("Спорядження", 20, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var eg := GridContainer.new()
	eg.columns = 3
	eg.add_theme_constant_override("h_separation", 6)
	eg.add_theme_constant_override("v_separation", 6)
	left.add_child(eg)
	for s in EQUIP_ORDER:
		var sl := ItemSlot.new(70.0)
		sl.equip_slot = s
		sl.caption = Items.SLOT_NAMES[s]
		sl.tapped.connect(_on_slot_tapped)
		eg.add_child(sl)
		_equip_slots[s] = sl
	_stats_label = FolkTheme.label("", 17, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	left.add_child(_stats_label)
	# сітка сумки
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	bag_sc.custom_minimum_size = Vector2(COLUMNS * 68.0 + 8.0, 68.0)
	bag_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(bag_sc)
	bag_sc.add_child(grid)
	TouchScroll.attach(bag_sc)
	for i in range(GameState.BAG_SIZE):
		var sl2 := ItemSlot.new(68.0)
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
	stash_sc.custom_minimum_size = Vector2(COLUMNS * 68.0 + 8.0, 48.0)
	stash_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(stash_sc)
	stash_sc.add_child(stash_grid)
	TouchScroll.attach(stash_sc)
	for i in range(GameState.STASH_SIZE):
		var ss := ItemSlot.new(56.0)
		ss.index = 1000 + i
		ss.tapped.connect(_on_stash_tapped)
		stash_grid.add_child(ss)
		_stash_slots.append(ss)
	# опис скролиться; ActionBar прибитий до низу правої колонки (якорі), щоб не йшов під низ екрана
	var right := Control.new()
	right.name = "DetailPane"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(240, 120)
	right.clip_contents = true
	h.add_child(right)
	_action_bar = VBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.add_theme_constant_override("separation", 4)
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_action_bar.offset_top = -56
	_action_bar.offset_bottom = -2
	_action_bar.offset_left = 0
	_action_bar.offset_right = 0
	_action_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.add_child(_action_bar)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_scroll.offset_bottom = -60
	_detail_scroll.offset_top = 0
	_detail_scroll.offset_left = 0
	_detail_scroll.offset_right = 0
	right.add_child(_detail_scroll)
	TouchScroll.attach(_detail_scroll)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 4)
	_detail_scroll.add_child(dv)
	_detail_name = FolkTheme.label("Торкнись предмета", 22, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_detail_name.visible = false
	dv.add_child(_detail_name)
	_detail_rich = DescFormat.make_rich()
	_detail_rich.bbcode_enabled = true
	_detail_rich.fit_content = true
	_detail_rich.scroll_active = false
	_detail_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_child(_detail_rich)
	_detail_body = FolkTheme.label("", 18, Palette.TURQUOISE.lightened(0.4), HORIZONTAL_ALIGNMENT_LEFT, true)
	_detail_body.visible = false
	dv.add_child(_detail_body)
	_detail_cmp = FolkTheme.label("", 15, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	_detail_cmp.visible = false
	dv.add_child(_detail_cmp)
	var btns := HBoxContainer.new()
	btns.name = "PrimaryActions"
	btns.add_theme_constant_override("separation", 6)
	_action_bar.add_child(btns)
	_btn_equip = Button.new()
	_btn_equip.text = "Одягти"
	FolkTheme.apply_button(_btn_equip, Palette.EMBROIDERY, 17)
	_btn_equip.custom_minimum_size = Vector2(0, 48)
	_btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_equip.pressed.connect(_on_equip)
	btns.add_child(_btn_equip)
	_btn_sell = Button.new()
	_btn_sell.text = "Продати"
	FolkTheme.apply_button(_btn_sell, Palette.PANEL_LIGHT, 16)
	_btn_sell.custom_minimum_size = Vector2(0, 48)
	_btn_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_sell.pressed.connect(_on_sell)
	btns.add_child(_btn_sell)
	_more_menu = MenuButton.new()
	_more_menu.text = "Ще ▾"
	FolkTheme.apply_button(_more_menu, Palette.PANEL_LIGHT, 16)
	_more_menu.custom_minimum_size = Vector2(96, 48)
	btns.add_child(_more_menu)
	_more_menu.get_popup().id_pressed.connect(_on_more_action)
	_btn_equip2 = Button.new()
	_btn_equip2.visible = false
	_btn_equip2.pressed.connect(func() -> void: _on_equip(true))
	_action_bar.add_child(_btn_equip2)
	_btn_socket = Button.new()
	_btn_socket.visible = false
	_btn_socket.pressed.connect(_on_socket)
	_action_bar.add_child(_btn_socket)
	_btn_stash = Button.new()
	_btn_stash.visible = false
	_btn_stash.pressed.connect(_on_to_stash)
	_action_bar.add_child(_btn_stash)
	_btn_attach = Button.new()
	_btn_attach.visible = false
	_btn_attach.pressed.connect(_on_attach_thread)
	_action_bar.add_child(_btn_attach)

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
		if Nauzi.is_nauz(it):
			_select_nauz_uid(int(it.get("uid", 0)))
			_show_tab(TAB_SKILLS)
			_nauz_inner = 0
			_on_nauz_equip_pressed()
			return
		var pref := _alt_slot(it) if alt else ""
		var slot := GameState.target_slot(it, pref)
		if GameState.equip_from_bag(_sel_bag, pref):
			_sel_bag = -1
			_sel_equip = slot
		else:
			if GameState.last_error != "" and _detail_rich:
				_detail_rich.text = "[color=#D8574B]%s[/color]" % GameState.last_error
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
		_select_nauz_uid(int(it.get("uid", 0)))
		_show_tab(TAB_SKILLS)
		_nauz_inner = 0
		_on_nauz_equip_pressed()


func _on_to_stash() -> void:
	if GameState.location != Locations.START:
		return
	if _sel_bag >= 0 and GameState.move_bag_to_stash(_sel_bag):
		_sel_bag = -1
	elif _sel_stash >= 0 and GameState.move_stash_to_bag(_sel_stash):
		_sel_stash = -1
	_refresh()


func _on_attach_thread() -> void:
	# Нитка з _sel_bag → в ОБРАНИЙ науз (вкладка «Наузи»), інакше — перший у сумці.
	# t61: раніше завжди брався перший науз у сумці, що неінтуїтивно.
	# Нитка знімається з сумки лише після успішних перевірок у GameState.attach_*.
	if _sel_bag < 0 or _sel_bag >= GameState.bag.size():
		return
	if not Nauzi.is_thread(GameState.bag[_sel_bag]):
		return
	var ti := _sel_bag
	if _sel_nauz_uid > 0:
		var found: Dictionary = GameState.find_nauz_by_uid(_sel_nauz_uid)
		if found.is_empty():
			_attach_thread_fail("Обраний науз не знайдено — обери його на вкладці «Наузи».")
			return
		var idx := int(found.get("index", -1))
		if idx < 0:
			_attach_thread_fail("Невірний індекс науза — обери науз знову.")
			return
		# Перечитати індекс нитки після можливих змін UI (захист від застарілого _sel_bag).
		if ti < 0 or ti >= GameState.bag.size() or not Nauzi.is_thread(GameState.bag[ti]):
			_attach_thread_fail("Нитка більше не в сумці — обери її знову.")
			return
		var ok := false
		if str(found.get("where", "")) == "socket":
			ok = GameState.attach_thread_to_socket(idx, ti)
		else:
			# Науз у сумці: індекси валідні на момент виклику; GameState знімає нитку лише після fit/slots.
			if idx == ti:
				_attach_thread_fail("Обери науз і нитку окремо.")
				return
			ok = GameState.attach_thread(idx, ti)
		if ok:
			_sel_bag = -1
			_refresh()
		else:
			_attach_thread_fail(GameState.last_error if GameState.last_error != "" else "Не вдалося вплести.")
		return
	var nauz_i := -1
	for i in range(GameState.bag.size()):
		if Nauzi.is_nauz(GameState.bag[i]):
			nauz_i = i
			break
	if nauz_i < 0:
		_attach_thread_fail("У сумці немає науза — обери науз на вкладці «Наузи».")
		return
	if nauz_i == ti:
		_attach_thread_fail("Обери науз і нитку окремо.")
		return
	if not GameState.attach_thread(nauz_i, ti):
		_attach_thread_fail(GameState.last_error if GameState.last_error != "" else "Не вдалося вплести.")
		return
	_sel_bag = -1
	_refresh()


func _attach_thread_fail(msg: String) -> void:
	## Показує причину і на вкладці Наузи, і в описі (якщо відкрита сумка / «Ще»).
	_status_nauz(msg)
	if _detail_rich:
		_detail_rich.text = "[color=#D8574B]%s[/color]" % msg


func _on_more_action(id: int) -> void:
	match id:
		1:
			_on_equip(true)
		2:
			_on_socket()
		3:
			_on_to_stash()
		4:
			_on_attach_thread()


func _on_sell() -> void:
	if _sel_bag < 0 or _sel_bag >= GameState.bag.size():
		return
	var it: Dictionary = GameState.bag[_sel_bag]
	if int(it.get("rarity", 0)) >= 2:
		_confirm.dialog_text = "Продати «%s» (%s) за %d гривень?" % [
			str(it.get("name", "?")), DescFormat.rarity_name(int(it.get("rarity", 0))), Items.sell_value(it)]
		# Уникнути подвійного продажу, якщо попереднє вікно закрили без «Так».
		if _confirm.confirmed.is_connected(_do_sell_confirmed):
			_confirm.confirmed.disconnect(_do_sell_confirmed)
		_confirm.confirmed.connect(_do_sell_confirmed, CONNECT_ONE_SHOT)
		_confirm.popup_centered()
		return
	_do_sell_confirmed()


func _on_sell_canceled() -> void:
	if _confirm.confirmed.is_connected(_do_sell_confirmed):
		_confirm.confirmed.disconnect(_do_sell_confirmed)


func _do_sell_confirmed() -> void:
	if _sel_bag >= 0 and GameState.sell(_sel_bag) > 0:
		_sel_bag = -1
	_refresh()


func _rebuild_more_menu(it: Dictionary) -> void:
	if _more_menu == null:
		return
	var popup := _more_menu.get_popup()
	popup.clear()
	var any := false
	if not it.is_empty() and _sel_bag >= 0:
		var alt := _alt_slot(it)
		if alt != "" and not Nauzi.is_nauz(it) and not Nauzi.is_thread(it):
			popup.add_item("У ліву руку" if Items.type_of(it) == "hand1" else "У слот «%s»" % Items.SLOT_NAMES[alt], 1)
			any = true
		if Nauzi.is_nauz(it):
			popup.add_item("У гніздо науза", 2)
			any = true
		if Nauzi.is_thread(it):
			popup.add_item("Вплести нитку", 4)
			any = true
	if GameState.location == Locations.START and (_sel_bag >= 0 or _sel_stash >= 0):
		popup.add_item("Зі скрині" if _sel_stash >= 0 else "У скриню", 3)
		any = true
	_more_menu.visible = not it.is_empty() or _sel_stash >= 0
	_more_menu.disabled = not any


func _refresh() -> void:
	_gold_label.text = "Гривні: %d · Зілля ж%d/ч%d · Вода забуття: %d" % [GameState.gold, GameState.hp_potions, GameState.mana_potions, GameState.oblivion_water]
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
	var is_nauz_sel := Nauzi.is_nauz(it)
	var can_equip := not it.is_empty() and not is_nauz_sel and not Nauzi.is_thread(it) and str(it.get("kind", "")) != "oblivion"
	_btn_equip.visible = can_equip or is_nauz_sel or (_sel_equip != "" and not it.is_empty())
	_btn_sell.visible = _sel_bag >= 0 and not it.is_empty()
	_btn_equip2.visible = false
	_btn_socket.visible = false
	_btn_stash.visible = false
	_btn_attach.visible = false
	_rebuild_more_menu(it)
	if it.is_empty():
		if _detail_rich:
			_detail_rich.text = "[i]Торкнись предмета в сумці чи спорядженні.[/i]"
		return
	var cmp_item := {}
	if _sel_bag >= 0:
		if Nauzi.is_nauz(it):
			_btn_equip.text = "Одягнути"
			_btn_equip.disabled = false
		else:
			var tslot := GameState.target_slot(it)
			var disp: Array = GameState.displaced_by(it, tslot)
			if disp.size() > 0 and typeof(disp[0]) == TYPE_DICTIONARY:
				cmp_item = disp[0]
			_btn_equip.text = "Одягти"
			_btn_equip.disabled = false
		_btn_sell.text = "Продати"
	else:
		_btn_equip.text = "Зняти" if GameState.bag_free() > 0 else "Сумка повна"
		_btn_equip.disabled = GameState.bag_free() <= 0
	if _detail_rich:
		_detail_rich.text = DescFormat.item_tooltip(it, {"where": "bag", "compare": cmp_item})


# ---------- Навички ----------

# ---------- Наузи / Нитки ----------

func _build_skill_page() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.clip_contents = true
	# гнізда героя
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	top.add_child(FolkTheme.label("Гнізда:", 18, Palette.GOLD))
	for i in range(GameState.QUICK_SLOTS):
		var chip := SkillChip.new(70.0)
		var idx := i
		chip.tapped.connect(func(_c: SkillChip) -> void:
			_sel_quick = idx
			var sn: Variant = GameState.socket_nauz(idx)
			if typeof(sn) == TYPE_DICTIONARY and sn != null:
				_select_nauz_uid(int(sn.get("uid", 0)))
			else:
				if _equip_pick_mode and _sel_nauz_uid > 0:
					_do_equip_into_socket(idx)
				else:
					_status_nauz("Гніздо %d порожнє. Обери науз у сумці й натисни «Одягнути»." % (idx + 1))
			_refresh())
		top.add_child(chip)
		_quick_chips.append(chip)
	# внутрішні вкладки
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	root.add_child(inner)
	_nauz_tab_btn = Button.new()
	_nauz_tab_btn.text = "Наузи"
	FolkTheme.apply_button(_nauz_tab_btn, Palette.EMBROIDERY, 18)
	_nauz_tab_btn.custom_minimum_size = Vector2(120, 44)
	_nauz_tab_btn.pressed.connect(func() -> void:
		_nauz_inner = 0
		_equip_pick_mode = false
		_refresh())
	inner.add_child(_nauz_tab_btn)
	_thread_tab_btn = Button.new()
	_thread_tab_btn.text = "Нитки"
	FolkTheme.apply_button(_thread_tab_btn, Palette.PANEL_LIGHT, 18)
	_thread_tab_btn.custom_minimum_size = Vector2(120, 44)
	_thread_tab_btn.pressed.connect(func() -> void:
		_nauz_inner = 1
		_equip_pick_mode = false
		_refresh())
	inner.add_child(_thread_tab_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(sp)
	# ціль (видима на обох вкладках)
	_nauz_target_label = FolkTheme.label("Ціль: —", 18, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_nauz_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_nauz_target_label)
	# контент: сітка + деталі/дії
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	root.add_child(body)
	# ліва сітка
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(320, 80)
	body.add_child(left)
	_nauz_list_title = FolkTheme.label("Наузи в сумці", 20, Palette.GOLD)
	left.add_child(_nauz_list_title)
	var list_sc := ScrollContainer.new()
	list_sc.name = "NauziListScroll"
	list_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_sc.custom_minimum_size = Vector2(300, 80)
	list_sc.clip_contents = true
	left.add_child(list_sc)
	TouchScroll.attach(list_sc)
	_skill_grid = GridContainer.new()
	_skill_grid.columns = 4
	_skill_grid.add_theme_constant_override("h_separation", 8)
	_skill_grid.add_theme_constant_override("v_separation", 6)
	list_sc.add_child(_skill_grid)
	# гнізда ниток (під списком на вкладці Нитки — також у правій панелі; тут ряд для швидкого доступу)
	_thread_slot_row = HBoxContainer.new()
	_thread_slot_row.add_theme_constant_override("separation", 6)
	left.add_child(_thread_slot_row)
	# права панель опису + дії
	var right := Control.new()
	right.name = "NauziDetailPane"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(260, 120)
	right.clip_contents = true
	body.add_child(right)
	_nauz_action_bar = VBoxContainer.new()
	_nauz_action_bar.name = "NauziActionBar"
	_nauz_action_bar.add_theme_constant_override("separation", 4)
	_nauz_action_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_nauz_action_bar.offset_top = -56
	_nauz_action_bar.offset_bottom = -2
	_nauz_action_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.add_child(_nauz_action_bar)
	var abtn := HBoxContainer.new()
	abtn.add_theme_constant_override("separation", 6)
	_nauz_action_bar.add_child(abtn)
	_btn_nauz_equip = Button.new()
	_btn_nauz_equip.text = "Одягнути"
	FolkTheme.apply_button(_btn_nauz_equip, Palette.EMBROIDERY, 17)
	_btn_nauz_equip.custom_minimum_size = Vector2(0, 48)
	_btn_nauz_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_nauz_equip.pressed.connect(_on_nauz_equip_pressed)
	abtn.add_child(_btn_nauz_equip)
	_btn_nauz_unequip = Button.new()
	_btn_nauz_unequip.text = "Зняти"
	FolkTheme.apply_button(_btn_nauz_unequip, Palette.PANEL_LIGHT, 16)
	_btn_nauz_unequip.custom_minimum_size = Vector2(0, 48)
	_btn_nauz_unequip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_nauz_unequip.pressed.connect(_on_nauz_unequip_pressed)
	abtn.add_child(_btn_nauz_unequip)
	_btn_weave = Button.new()
	_btn_weave.text = "Вплести"
	FolkTheme.apply_button(_btn_weave, Palette.EMBROIDERY, 17)
	_btn_weave.custom_minimum_size = Vector2(0, 48)
	_btn_weave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_weave.pressed.connect(_on_weave_pressed)
	abtn.add_child(_btn_weave)
	_nauz_detail_scroll = ScrollContainer.new()
	_nauz_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_nauz_detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nauz_detail_scroll.offset_bottom = -60
	right.add_child(_nauz_detail_scroll)
	TouchScroll.attach(_nauz_detail_scroll)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 4)
	_nauz_detail_scroll.add_child(dv)
	_skill_info = FolkTheme.label("", 17, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	dv.add_child(_skill_info)
	_nauz_detail_rich = DescFormat.make_rich()
	_nauz_detail_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_child(_nauz_detail_rich)
	_thread_pick_box = VBoxContainer.new()
	_thread_pick_box.add_theme_constant_override("separation", 4)
	dv.add_child(_thread_pick_box)
	# пікер гнізда
	_socket_pick_row = HBoxContainer.new()
	_socket_pick_row.add_theme_constant_override("separation", 6)
	_socket_pick_row.visible = false
	root.add_child(_socket_pick_row)
	return root


func _status_nauz(msg: String) -> void:
	if _skill_info:
		_skill_info.text = msg


func _select_nauz_uid(uid: int) -> void:
	_sel_nauz_uid = uid
	_sel_thread_uid = -1
	_thread_slot_sel = -1
	_equip_pick_mode = false
	_nauz_focus = {}
	var found := GameState.find_nauz_by_uid(uid)
	if not found.is_empty():
		_nauz_focus = {"where": str(found["where"]), "index": int(found["index"])}
		if str(found["where"]) == "socket":
			_sel_quick = int(found["index"])


func _select_thread_uid(uid: int) -> void:
	_sel_thread_uid = uid


func _resolved_nauz() -> Dictionary:
	return GameState.find_nauz_by_uid(_sel_nauz_uid)


func _resolved_thread_bag_index() -> int:
	if _sel_thread_uid <= 0:
		return -1
	for i in range(GameState.bag.size()):
		if Nauzi.is_thread(GameState.bag[i]) and int(GameState.bag[i].get("uid", 0)) == _sel_thread_uid:
			return i
	return -1


func _on_nauz_equip_pressed() -> void:
	var found := _resolved_nauz()
	if found.is_empty() or str(found.get("where", "")) != "bag":
		_status_nauz("Обери науз у сумці.")
		return
	var item: Dictionary = found["item"]
	var reason := Nauzi.can_use(item)
	if reason != "":
		_status_nauz(reason)
		_refresh()
		return
	_equip_pick_mode = true
	_status_nauz("Обери гніздо героя (1–4), куди одягнути «%s»." % str(item.get("name", "науз")))
	_refresh()


func _do_equip_into_socket(slot: int) -> void:
	if _sel_nauz_uid <= 0:
		return
	var ok := GameState.equip_nauz(slot, _sel_nauz_uid)
	if ok:
		_equip_pick_mode = false
		_sel_quick = slot
		_status_nauz("Науз одягнено в гніздо %d." % (slot + 1))
		# uid лишається — тепер у сокеті
	else:
		_status_nauz(GameState.last_error if GameState.last_error != "" else "Не вдалося одягнути.")
	_refresh()


func _on_nauz_unequip_pressed() -> void:
	var found := _resolved_nauz()
	if found.is_empty() or str(found.get("where", "")) != "socket":
		_status_nauz("Обери одягнений науз у гнізді.")
		return
	var slot := int(found["index"])
	var uid := _sel_nauz_uid
	if GameState.unequip_nauz(slot):
		_status_nauz("Науз знято в сумку.")
		_select_nauz_uid(uid)  # тепер у сумці
	else:
		_status_nauz(GameState.last_error if GameState.last_error != "" else "Не вдалося зняти.")
	_refresh()


func _on_weave_pressed() -> void:
	var found := _resolved_nauz()
	if found.is_empty():
		_status_nauz("Обери цільовий науз (у сумці або в гнізді).")
		return
	var nauz: Dictionary = found["item"]
	var open_slots := Nauzi.thread_slots(int(nauz.get("level", 1)))
	var threads: Array = nauz.get("threads", [])
	if _thread_slot_sel < 0:
		_status_nauz("Обери порожнє гніздо нитки.")
		return
	if _thread_slot_sel >= open_slots:
		_status_nauz("Гніздо закрите.")
		return
	if _thread_slot_sel != threads.size():
		_status_nauz("Спочатку заповни гніздо %d." % (threads.size() + 1))
		return
	var tbi := _resolved_thread_bag_index()
	if tbi < 0:
		_status_nauz("Обери нитку в списку.")
		return
	var ok := false
	if str(found["where"]) == "socket":
		ok = GameState.attach_thread_to_socket(int(found["index"]), tbi)
	else:
		# індекс науза міг зміститись — шукаємо знову за uid
		var again := GameState.find_nauz_by_uid(_sel_nauz_uid)
		if again.is_empty() or str(again["where"]) != "bag":
			_status_nauz("Цільовий науз зник із сумки.")
			_refresh()
			return
		ok = GameState.attach_thread(int(again["index"]), tbi)
	if ok:
		_sel_thread_uid = -1
		_thread_slot_sel = -1
		_status_nauz("Нитку вплетено.")
	else:
		_status_nauz(GameState.last_error if GameState.last_error != "" else "Не вдалося вплести.")
	_refresh()


func _focused_nauz() -> Dictionary:
	var found := _resolved_nauz()
	if found.is_empty():
		return {}
	return found["item"]


func _refresh_skills() -> void:
	# відновити фокус за uid після змін сумки
	if _sel_nauz_uid > 0:
		var f := GameState.find_nauz_by_uid(_sel_nauz_uid)
		if f.is_empty():
			_sel_nauz_uid = -1
			_nauz_focus = {}
		else:
			_nauz_focus = {"where": str(f["where"]), "index": int(f["index"])}
			if str(f["where"]) == "socket":
				_sel_quick = int(f["index"])
	FolkTheme.apply_button(_nauz_tab_btn, Palette.EMBROIDERY if _nauz_inner == 0 else Palette.PANEL_LIGHT, 18)
	FolkTheme.apply_button(_thread_tab_btn, Palette.EMBROIDERY if _nauz_inner == 1 else Palette.PANEL_LIGHT, 18)
	for i in range(_quick_chips.size()):
		var chip: SkillChip = _quick_chips[i]
		chip.set_skill(GameState.quick_skill(i))
		var sn0: Variant = GameState.socket_nauz(i)
		var sel_sock := (_sel_nauz_uid > 0 and typeof(sn0) == TYPE_DICTIONARY and sn0 != null
			and int(sn0.get("uid", 0)) == _sel_nauz_uid)
		chip.selected = sel_sock or (_equip_pick_mode and i == _sel_quick)
		if typeof(sn0) == TYPE_DICTIONARY and sn0 != null:
			chip.note = "р.%d" % int(sn0.get("level", 1))
		else:
			chip.note = "порожньо" if not _equip_pick_mode else "← сюди"
		chip.queue_redraw()
	var found := _resolved_nauz()
	if found.is_empty():
		_nauz_target_label.text = "Ціль: —"
	else:
		var it: Dictionary = found["item"]
		var where_ua := "гніздо %d" % (int(found["index"]) + 1) if str(found["where"]) == "socket" else "сумка"
		_nauz_target_label.text = "Ціль: %s · %s · р.%d" % [str(it.get("name", "?")), where_ua, int(it.get("level", 1))]
	# кнопки дій
	var in_bag := (not found.is_empty() and str(found["where"]) == "bag")
	var in_sock := (not found.is_empty() and str(found["where"]) == "socket")
	_btn_nauz_equip.visible = _nauz_inner == 0
	_btn_nauz_unequip.visible = _nauz_inner == 0
	_btn_weave.visible = _nauz_inner == 1
	_btn_nauz_equip.disabled = not in_bag
	_btn_nauz_equip.text = "Обери гніздо…" if _equip_pick_mode else "Одягнути"
	_btn_nauz_unequip.disabled = not in_sock
	_btn_weave.disabled = found.is_empty() or _sel_thread_uid <= 0 or _thread_slot_sel < 0
	_socket_pick_row.visible = false
	if _equip_pick_mode and in_bag:
		_rebuild_socket_pick()
	# список
	for ch in _skill_grid.get_children():
		_skill_grid.remove_child(ch)
		ch.queue_free()
	_thread_slot_row.visible = _nauz_inner == 1
	if _nauz_inner == 0:
		_nauz_list_title.text = "Наузи в сумці"
		_fill_nauz_bag_grid()
	else:
		_nauz_list_title.text = "Нитки в сумці"
		_fill_thread_bag_grid()
	_refresh_thread_slots()
	# опис
	_thread_pick_box.visible = false
	if found.is_empty():
		if _skill_info.text == "" or _skill_info.text.begins_with("Ціль") or _skill_info.text.begins_with("Науз"):
			_skill_info.text = "Обери науз у гнізді або сумці."
		_nauz_detail_rich.text = ""
	else:
		var nauz: Dictionary = found["item"]
		var req_fail := Nauzi.can_use(nauz)
		if req_fail != "" and in_bag:
			_skill_info.text = req_fail
		elif _skill_info.text == "" or _skill_info.text.begins_with("Обери"):
			_skill_info.text = "%s · %s" % [str(nauz.get("name", "")), "в гнізді" if in_sock else "в сумці"]
		_nauz_detail_rich.text = DescFormat.item_tooltip(nauz, {"where": "nauz"})


func _rebuild_socket_pick() -> void:
	for c in _socket_pick_row.get_children():
		_socket_pick_row.remove_child(c)
		c.queue_free()
	_socket_pick_row.visible = true
	_socket_pick_row.add_child(FolkTheme.label("Куди одягнути:", 18, Palette.GOLD))
	for i in range(GameState.QUICK_SLOTS):
		var b := Button.new()
		var sn: Variant = GameState.socket_nauz(i)
		if typeof(sn) == TYPE_DICTIONARY and sn != null:
			b.text = "%d: замінити «%s»" % [i + 1, str(sn.get("name", "?"))]
		else:
			b.text = "%d: порожнє" % (i + 1)
		FolkTheme.apply_button(b, Palette.EMBROIDERY, 15)
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot := i
		b.pressed.connect(func() -> void: _do_equip_into_socket(slot))
		_socket_pick_row.add_child(b)
	var cancel := Button.new()
	cancel.text = "Скасувати"
	FolkTheme.apply_button(cancel, Palette.PANEL_LIGHT, 15)
	cancel.custom_minimum_size = Vector2(120, 44)
	cancel.pressed.connect(func() -> void:
		_equip_pick_mode = false
		_refresh())
	_socket_pick_row.add_child(cancel)


func _fill_nauz_bag_grid() -> void:
	_skill_grid.columns = 4
	var any := false
	for bi in range(GameState.bag.size()):
		var it2: Dictionary = GameState.bag[bi]
		if not Nauzi.is_nauz(it2):
			continue
		any = true
		var chip3 := SkillChip.new(68.0)
		chip3.set_skill(str(it2.get("skill", "")))
		var uid := int(it2.get("uid", 0))
		chip3.selected = uid == _sel_nauz_uid
		chip3.note = "р.%d" % int(it2.get("level", 1))
		chip3.tapped.connect(func(_c: SkillChip) -> void:
			_select_nauz_uid(uid)
			_refresh())
		_skill_grid.add_child(chip3)
	if not any:
		_skill_grid.add_child(FolkTheme.label("У сумці немає наузів.", 18, Palette.TEXT_DIM))


func _fill_thread_bag_grid() -> void:
	var nauz := _focused_nauz()
	var rows: Array = []
	for bi in range(GameState.bag.size()):
		var th2: Dictionary = GameState.bag[bi]
		if not Nauzi.is_thread(th2):
			continue
		var reason := ""
		if nauz.is_empty():
			reason = "Спочатку обери науз"
		else:
			reason = Nauzi.thread_fit_reason(nauz, th2)
		rows.append({"bi": bi, "th": th2, "reason": reason, "ok": reason == ""})
	rows.sort_custom(func(a, b): return (1 if a["ok"] else 0) > (1 if b["ok"] else 0))
	if rows.is_empty():
		_skill_grid.add_child(FolkTheme.label("У сумці немає ниток.", 18, Palette.TEXT_DIM))
		return
	# одна колонка кнопок у сітці 1 — зручніше читати причини
	_skill_grid.columns = 1
	for row in rows:
		var th2: Dictionary = row["th"]
		var uid := int(th2.get("uid", 0))
		var b := Button.new()
		var nm := str(th2.get("name", "Нитка"))
		var rar := DescFormat.rarity_name(int(th2.get("rarity", 0)))
		if row["ok"]:
			b.text = "✓ %s · %s" % [nm, rar]
			FolkTheme.apply_button(b, Palette.TURQUOISE.darkened(0.2) if uid != _sel_thread_uid else Palette.EMBROIDERY, 15)
			b.disabled = false
		else:
			b.text = "✗ %s — %s" % [nm, str(row["reason"])]
			FolkTheme.apply_button(b, Palette.PANEL, 14)
			b.disabled = true
		b.custom_minimum_size = Vector2(280, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if row["ok"]:
			b.pressed.connect(func() -> void:
				_select_thread_uid(uid)
				_refresh())
		_skill_grid.add_child(b)


func _refresh_thread_slots() -> void:
	for c in _thread_slot_row.get_children():
		_thread_slot_row.remove_child(c)
		c.queue_free()
	if _nauz_inner != 1:
		return
	var nauz := _focused_nauz()
	if nauz.is_empty():
		_thread_slot_row.add_child(FolkTheme.label("Обери науз — побачиш 3 гнізда ниток.", 16, Palette.TEXT_DIM))
		return
	var open_slots := Nauzi.thread_slots(int(nauz.get("level", 1)))
	var threads: Array = nauz.get("threads", [])
	var unlocks := [1, 8, 15]
	_thread_slot_row.add_child(FolkTheme.label("Гнізда:", 16, Palette.GOLD))
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 48)
		if i >= open_slots:
			b.text = "🔒 з р.%d" % unlocks[i]
			b.disabled = true
			FolkTheme.apply_button(b, Palette.PANEL, 14)
		elif i < threads.size() and typeof(threads[i]) == TYPE_DICTIONARY:
			var th: Dictionary = threads[i]
			b.text = str(th.get("name", "Нитка"))
			FolkTheme.apply_button(b, Palette.GOLD.darkened(0.25), 13)
			b.disabled = true
		else:
			b.text = "Порожнє %d" % (i + 1)
			FolkTheme.apply_button(b, Palette.EMBROIDERY if _thread_slot_sel == i else Palette.PANEL_LIGHT, 14)
			var slot_i := i
			b.pressed.connect(func() -> void:
				_thread_slot_sel = slot_i
				_refresh())
		_thread_slot_row.add_child(b)


func _attach_focused(thread_bag_index: int) -> void:
	if thread_bag_index >= 0 and thread_bag_index < GameState.bag.size():
		_sel_thread_uid = int(GameState.bag[thread_bag_index].get("uid", 0))
	var nauz := _focused_nauz()
	if not nauz.is_empty():
		var ths: Array = nauz.get("threads", [])
		_thread_slot_sel = ths.size()
	_on_weave_pressed()


func _on_skill_tapped(id: String) -> void:
	_sel_skill = id
	GameState.set_quick(_sel_quick, id)
	_refresh()

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
