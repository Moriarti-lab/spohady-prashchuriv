## Крамниця Радима: купівля предметів з асортименту, що оновлюється, зілля й продаж речей із сумки (гривні).
class_name ShopScreen
extends Control

signal closed

var _gold: Label
var _timer: Label
var _msg: Label
var _stock: VBoxContainer
var _sell: VBoxContainer
var _t := 0.0


func _ready() -> void:
	FolkTheme.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
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
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	root.add_child(head)
	var t := FolkTheme.label("Крамниця Радима", 34, Palette.GOLD)
	head.add_child(t)
	_gold = FolkTheme.label("", 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gold)
	var close := Button.new()
	close.text = "Закрити"
	FolkTheme.apply_button(close, Palette.EMBROIDERY, 22)
	close.custom_minimum_size = Vector2(130, 56)
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)
	root.add_child(OrnamentBand.new(24))
	_timer = FolkTheme.label("", 19, Palette.TEXT_DIM)
	root.add_child(_timer)
	_msg = FolkTheme.label("", 20, Palette.TURQUOISE.lightened(0.4))
	root.add_child(_msg)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	_stock = _column(cols, "Купити")
	_sell = _column(cols, "Продати зі своєї сумки")


func _column(parent: Control, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	v.add_child(FolkTheme.label(title, 26, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	TouchScroll.attach(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return list


func open() -> void:
	GameState.refresh_stock()
	_msg.text = ""
	visible = true
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t >= 1.0:
		_t = 0.0
		if GameState.refresh_stock():
			_msg.text = "Радим привіз нові речі."
			_refresh()
		_update_timer()


func _update_timer() -> void:
	var s := GameState.stock_seconds_left()
	_timer.text = "Нові товари через %d:%02d. Ціни в гривнях%s." % [s / 60, s % 60, " (знижка 10%: рушник повернуто)" if GameState.price_mult() < 1.0 else ""]


func _clear(list: VBoxContainer) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()


func _row(item: Dictionary, price: int, btn_text: String, enabled: bool, handler: Callable) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.9), Items.rarity_color(item), 2, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var slot := ItemSlot.new(76.0)
	slot.set_item(item)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(slot)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	var n := FolkTheme.label(str(item.get("name", "Річ")), 21, Items.rarity_color(item), HORIZONTAL_ALIGNMENT_LEFT, true)
	info.add_child(n)
	info.add_child(FolkTheme.label(Items.summary(item), 16, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var b := Button.new()
	b.text = "%s\n%d грн" % [btn_text, price]
	FolkTheme.apply_button(b, Palette.EMBROIDERY, 19)
	b.custom_minimum_size = Vector2(120, 70)
	b.disabled = not enabled
	b.pressed.connect(handler)
	h.add_child(b)
	return p


func _potion_row(kind: String) -> Control:
	var price := GameState.potion_price(kind)
	var p := PanelContainer.new()
	var col := Palette.HP_COLOR if kind == "hp" else Palette.MANA_COLOR
	p.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.9), col, 2, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(Icons.make_control("potion_hp" if kind == "hp" else "potion_mana", 56.0, "Ж" if kind == "hp" else "Ч"))
	var nm := "Зілля життя" if kind == "hp" else "Зілля чару"
	var have := GameState.hp_potions if kind == "hp" else GameState.mana_potions
	var l := FolkTheme.label("%s (є %d)" % [nm, have], 21, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := Button.new()
	b.text = "Купити\n%d грн" % price
	FolkTheme.apply_button(b, Palette.EMBROIDERY, 19)
	b.custom_minimum_size = Vector2(120, 60)
	b.disabled = GameState.gold < price
	b.pressed.connect(func() -> void:
		if GameState.buy_potion(kind):
			_msg.text = "Куплено: %s" % nm
		else:
			_msg.text = GameState.last_error
		_refresh())
	h.add_child(b)
	return p


func _refresh() -> void:
	_gold.text = "Гривні: %d · Сумка: %d/%d" % [GameState.gold, GameState.bag.size(), GameState.BAG_SIZE]
	_update_timer()
	_clear(_stock)
	_stock.add_child(_potion_row("hp"))
	_stock.add_child(_potion_row("mana"))
	for i in range(GameState.merchant_stock.size()):
		var it: Dictionary = GameState.merchant_stock[i]
		var price := GameState.price_of(it)
		var idx := i
		_stock.add_child(_row(it, price, "Купити", GameState.gold >= price, func() -> void:
			if GameState.buy(idx):
				_msg.text = "Куплено: %s" % it.get("name", "")
			else:
				_msg.text = GameState.last_error
			_refresh()))
	if GameState.merchant_stock.is_empty():
		_stock.add_child(FolkTheme.label("Усе розкуплено. Зайди пізніше.", 20, Palette.TEXT_DIM))
	_clear(_sell)
	if GameState.bag.is_empty():
		_sell.add_child(FolkTheme.label("Сумка порожня.", 20, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for i in range(GameState.bag.size()):
		var it2: Dictionary = GameState.bag[i]
		var idx2 := i
		_sell.add_child(_row(it2, Items.sell_value(it2), "Продати", true, func() -> void:
			var v := GameState.sell(idx2)
			_msg.text = "Продано за %d грн" % v
			_refresh()))
