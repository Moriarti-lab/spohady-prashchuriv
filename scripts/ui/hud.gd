## Ігровий інтерфейс: життя, чар, звитяга, міні-карта, джойстик, кнопки атаки, навичок і зілля.
class_name Hud
extends CanvasLayer

const MARGIN := 36.0
const SKILL_COUNT := 4
const SKILL_ANGLES := [172.0, 212.0, 252.0, 292.0]   # градуси навколо кнопки атаки, 180° — ліворуч, 270° — вгору
const SKILL_DIST := 156.0
const MINI_SIZE := 150.0
const TOP_STRIP := 92.0       # верхня смуга кнопок: дотики тут не підбирають здобич

var player: Player
var world: GameWorld

var _root: Control
var _stick: TouchStick
var _attack: TouchButton
var _skills: Array = []
var _potion_hp: TouchButton
var _potion_mana: TouchButton
var _hp_bar: StatBar
var _mana_bar: StatBar
var _xp_bar: StatBar
var _name_label: Label
var _gold_label: Label
var _portrait: Control
var _top_panel: PanelContainer
var _submenu: PanelContainer
var _submenu_btns := {}
var _btn_interact: Button
var _interact_item: Dictionary = {}
var _quest_panel: PanelContainer
var _quest_label: Label
var _loc_label: Label
var _mini: MapView
var _mini_frame: Panel
var _target_panel: PanelContainer
var _target_art: TextureRect
var _target_name: Label
var _target_bar: StatBar
var _target_kind := ""
var _death_box: Control
var _death_label: Label
var _banner: Label
var _toast: Label
var _perk_screen: PerkTreeScreen
var _pause_menu: PauseMenu
var _inventory: InventoryScreen
var _map_screen: MapScreen
var _dialog: DialogScreen
var _shop: ShopScreen
var _quest_screen: QuestScreen
var _touches := {}      # індекс пальця -> роль ("stick", "attack", "skill0".."skill3", "potion_hp", "potion_mana")
var _overlay_open := false
var _toast_tween: Tween


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FolkTheme.fullscreen(_root)
	add_child(_root)
	_build_top_left()
	_build_top_right()
	_build_submenu()
	_build_interact()
	_build_target_frame()
	_build_touch_controls()
	_build_overlays()
	_root.resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	GameState.changed.connect(_on_state_changed)
	_on_state_changed()


func _exit_tree() -> void:
	if GameState.changed.is_connected(_on_state_changed):
		GameState.changed.disconnect(_on_state_changed)


func bind(p_player: Player, p_world: GameWorld) -> void:
	player = p_player
	world = p_world
	_mini.bind(world, player)
	_refresh_attack_label()
	if not world.is_warmed:
		world.warmed.connect(_maybe_starter, CONNECT_ONE_SHOT)


## Новий герой без навичок: одразу показуємо вибір стартової навички на Древі.
func _maybe_starter() -> void:
	# Спершу даємо заслоні зникнути, а вже потім ставимо гру на паузу й відкриваємо Древо.
	await get_tree().create_timer(0.55, true).timeout
	if not is_inside_tree():
		return
	if world != null and world._fade_rect != null and is_instance_valid(world._fade_rect):
		world._fade_rect.modulate.a = 0.0
	if GameState.starter_pending() and not _overlay_open and world != null and not world.skip_warmup:
		open_perks()


# ---------- Побудова ----------

func _build_top_left() -> void:
	var panel := PanelContainer.new()
	_top_panel = panel
	panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.82), Palette.GOLD, 2, 12))
	panel.position = Vector2(16, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	_portrait = PortraitSlot.new(Vector2(84, 84))
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_name_label = FolkTheme.label("", 21, Palette.LINEN)
	v.add_child(_name_label)
	_hp_bar = StatBar.new(Palette.HP_COLOR, Strings.HP, 26)
	v.add_child(_hp_bar)
	_mana_bar = StatBar.new(Palette.MANA_COLOR, Strings.MANA, 26)
	v.add_child(_mana_bar)
	_xp_bar = StatBar.new(Palette.XP_COLOR.darkened(0.15), Strings.XP, 20)
	_xp_bar.font_size = 14
	v.add_child(_xp_bar)
	_gold_label = FolkTheme.label("", 18, Palette.GOLD)
	v.add_child(_gold_label)


func _menu_button(text: String, color: Color, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	FolkTheme.apply_button(b, color, 24)
	b.custom_minimum_size = Vector2(250, 58)
	b.pressed.connect(func() -> void:
		close_submenu()
		handler.call())
	return b


## Портрет героя відкриває меню: Сумка, Навички, Характеристики, Древо, Завдання, Меню.
func _build_submenu() -> void:
	_submenu = PanelContainer.new()
	_submenu.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 1.0), Palette.GOLD, 3, 12))
	_submenu.visible = false
	_submenu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_submenu)
	# Дві колонки: меню коротке й не залазить на лівий джойстик.
	var v := GridContainer.new()
	v.columns = 2
	v.add_theme_constant_override("h_separation", 6)
	v.add_theme_constant_override("v_separation", 6)
	_submenu.add_child(v)
	var defs := [
		["bag", "Сумка", Palette.EMBROIDERY, func() -> void: open_inventory(InventoryScreen.TAB_BAG)],
		["skills", "Навички", Palette.PANEL_LIGHT, func() -> void: open_inventory(InventoryScreen.TAB_SKILLS)],
		["stats", "Характеристики", Palette.PANEL_LIGHT, func() -> void: open_inventory(InventoryScreen.TAB_STATS)],
		["perks", "Древо", Palette.TURQUOISE.darkened(0.25), open_perks],
		["quests", "Завдання", Palette.EMBROIDERY.darkened(0.2), open_quests],
		["menu", "Меню", Palette.PANEL_LIGHT, _open_pause],
	]
	for d in defs:
		var b := _menu_button(d[1], d[2], d[3])
		v.add_child(b)
		_submenu_btns[d[0]] = b


func toggle_submenu() -> void:
	_submenu.visible = not _submenu.visible
	_update_menu_badges()
	_layout()


func close_submenu() -> void:
	if _submenu != null:
		_submenu.visible = false


func _update_menu_badges() -> void:
	if _submenu_btns.is_empty():
		return
	var pts := GameState.perk_points
	(_submenu_btns["perks"] as Button).text = "Древо" if pts <= 0 else "Древо (+%d)" % pts
	var nq := GameState.active_quests().size()
	(_submenu_btns["quests"] as Button).text = "Завдання" if nq <= 0 else "Завдання (%d)" % nq


func _build_interact() -> void:
	_btn_interact = Button.new()
	FolkTheme.apply_button(_btn_interact, Palette.EMBROIDERY, 26)
	_btn_interact.custom_minimum_size = Vector2(340, 70)
	_btn_interact.visible = false
	_btn_interact.pressed.connect(func() -> void:
		if world != null and not _interact_item.is_empty():
			world.interact(_interact_item))
	_root.add_child(_btn_interact)


func _build_top_right() -> void:
	_mini = MapView.new(MapView.Mode.MINI)
	_mini.custom_minimum_size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini.size = Vector2(MINI_SIZE, MINI_SIZE)
	_root.add_child(_mini)
	_mini_frame = Panel.new()
	_mini_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Palette.GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	_mini_frame.add_theme_stylebox_override("panel", sb)
	_mini_frame.size = Vector2(MINI_SIZE, MINI_SIZE)
	_root.add_child(_mini_frame)
	_loc_label = FolkTheme.label("", 18, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_loc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_loc_label)
	_quest_panel = PanelContainer.new()
	_quest_panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.8), Palette.GOLD.darkened(0.2), 2, 10))
	_quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_panel.visible = false
	_root.add_child(_quest_panel)
	_quest_label = FolkTheme.label("", 17, Palette.LINEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_quest_label.custom_minimum_size = Vector2(250, 0)
	_quest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_panel.add_child(_quest_label)


func _build_target_frame() -> void:
	_target_panel = PanelContainer.new()
	_target_panel.add_theme_stylebox_override("panel", FolkTheme.panel_style(Color(Palette.PANEL, 0.85), Palette.BLOOD.lightened(0.2), 2, 10))
	_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_panel.visible = false
	_root.add_child(_target_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_panel.add_child(h)
	_target_art = TextureRect.new()
	_target_art.custom_minimum_size = Vector2(54, 72)
	_target_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_target_art)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(210, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_target_name = FolkTheme.label("", 20, Palette.LINEN)
	v.add_child(_target_name)
	_target_bar = StatBar.new(Palette.BLOOD.lightened(0.15), "", 22)
	v.add_child(_target_bar)


func _build_touch_controls() -> void:
	_stick = TouchStick.new()
	FolkTheme.fullscreen(_stick)
	_root.add_child(_stick)
	_attack = TouchButton.new(80.0, Palette.EMBROIDERY)
	_attack.font_size = 26
	_root.add_child(_attack)
	for i in range(SKILL_COUNT):
		var b := TouchButton.new(48.0, Palette.TURQUOISE.darkened(0.2))
		b.font_size = 17
		_root.add_child(b)
		_skills.append(b)
	_potion_hp = TouchButton.new(34.0, Palette.HP_COLOR.darkened(0.3))
	_potion_hp.font_size = 15
	_potion_hp.text = "Життя"
	_root.add_child(_potion_hp)
	_potion_mana = TouchButton.new(34.0, Palette.MANA_COLOR.darkened(0.3))
	_potion_mana.font_size = 15
	_potion_mana.text = "Чар"
	_root.add_child(_potion_mana)


func _build_overlays() -> void:
	# смерть
	_death_box = Control.new()
	_death_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FolkTheme.fullscreen(_death_box)
	_death_box.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FolkTheme.fullscreen(dim)
	_death_box.add_child(dim)
	_death_label = FolkTheme.label("", 34, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true)
	FolkTheme.fullscreen(_death_label)
	_death_label.offset_left = 120.0
	_death_label.offset_right = -120.0
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_box.add_child(_death_label)
	_root.add_child(_death_box)
	# банер рівня
	_banner = FolkTheme.label("", 54, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)
	# підказки
	_toast = FolkTheme.label("", 28, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)
	# екрани
	_perk_screen = PerkTreeScreen.new()
	_perk_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_perk_screen.visible = false
	_perk_screen.closed.connect(_close_overlay)
	add_child(_perk_screen)
	_inventory = InventoryScreen.new()
	_inventory.process_mode = Node.PROCESS_MODE_ALWAYS
	_inventory.visible = false
	_inventory.closed.connect(_close_overlay)
	add_child(_inventory)
	_map_screen = MapScreen.new()
	_map_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_map_screen.visible = false
	_map_screen.closed.connect(_close_overlay)
	add_child(_map_screen)
	_dialog = DialogScreen.new()
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_dialog.visible = false
	_dialog.closed.connect(_close_overlay)
	_dialog.shop_requested.connect(open_shop)
	add_child(_dialog)
	_shop = ShopScreen.new()
	_shop.process_mode = Node.PROCESS_MODE_ALWAYS
	_shop.visible = false
	_shop.closed.connect(_close_overlay)
	add_child(_shop)
	_quest_screen = QuestScreen.new()
	_quest_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_quest_screen.visible = false
	_quest_screen.closed.connect(_close_overlay)
	add_child(_quest_screen)
	_pause_menu = PauseMenu.new()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.visible = false
	_pause_menu.resume_pressed.connect(_close_overlay)
	_pause_menu.title_pressed.connect(_go_title)
	add_child(_pause_menu)


# ---------- Розкладка ----------

func _layout() -> void:
	var vs := _root.size
	if vs.x < 10.0:
		vs = get_viewport().get_visible_rect().size
	_mini.position = Vector2(vs.x - MINI_SIZE - 16.0, 12.0)
	_mini_frame.position = _mini.position
	_loc_label.size = Vector2(300, 26)
	_loc_label.position = Vector2(_mini.position.x - 300.0 - 8.0, 14.0)
	_quest_panel.position = Vector2(vs.x - 250.0 - 40.0, MINI_SIZE + 22.0)
	_quest_panel.size = Vector2(250.0 + 24.0, 10)
	if _top_panel != null:
		_submenu.position = Vector2(16.0, _top_panel.position.y + _top_panel.size.y + 6.0)
		_submenu.size = Vector2(10, 10)
	_btn_interact.position = Vector2(vs.x * 0.5 - 170.0, vs.y - 120.0)
	_btn_interact.size = Vector2(340, 70)
	_target_panel.position = Vector2(vs.x * 0.5 - 150.0, 6.0)
	_attack.place(Vector2(vs.x - MARGIN - 80.0 - 20.0, vs.y - MARGIN - 80.0 - 10.0))
	for i in range(SKILL_COUNT):
		var a := deg_to_rad(float(SKILL_ANGLES[i]))
		(_skills[i] as TouchButton).place(_attack.center + Vector2(cos(a), sin(a)) * SKILL_DIST)
	_potion_hp.place(_attack.center + Vector2(64.0, -246.0))
	_potion_mana.place(_attack.center + Vector2(-20.0, -262.0))
	_stick.home = Vector2(MARGIN + 110.0 + 40.0, vs.y - MARGIN - 110.0 - 20.0)
	if not _stick.active:
		_stick.base_center = _stick.home
		_stick.queue_redraw()
	_banner.size = Vector2(vs.x, 80)
	_banner.position = Vector2(0, vs.y * 0.2)
	_toast.size = Vector2(vs.x, 40)
	_toast.position = Vector2(0, vs.y * 0.58)


# ---------- Оновлення ----------

func map_dirty() -> void:
	if _mini != null:
		_mini.mark_dirty()
	if _map_screen != null and _map_screen.map != null:
		_map_screen.map.mark_dirty()


func _on_state_changed() -> void:
	_name_label.text = "%s · %s %d" % [GameState.hero_name, Strings.LEVEL, GameState.level]
	_xp_bar.set_values(float(GameState.xp), float(GameState.xp_needed()))
	_update_menu_badges()
	_update_quest_tracker()
	_gold_label.text = "Гривні: %d" % GameState.gold
	(_portrait as PortraitSlot).set_portrait(GameState.blessing, GameState.hero_class)
	_loc_label.text = str(world.loc.get("name", "")) if world != null else Locations.get_def(GameState.location).get("name", "")
	if player != null:
		_refresh_attack_label()


func _refresh_attack_label() -> void:
	var kind: String = HeroStats.weapon_def()["kind"]
	_attack.text = {"melee": "Удар", "arrow": "Постріл", "magic": "Чари"}.get(kind, "Удар")


func _process(_delta: float) -> void:
	if player == null:
		return
	_hp_bar.set_values(player.hp, HeroStats.max_hp())
	_mana_bar.set_values(player.mana, HeroStats.max_mana())
	for i in range(SKILL_COUNT):
		_update_skill_button(i)
	_potion_hp.sub_text = "×%d" % GameState.hp_potions
	_potion_hp.cooldown = clampf(player.potion_cd / Player.POTION_COOLDOWN, 0.0, 1.0)
	_potion_hp.usable = GameState.hp_potions > 0
	_potion_hp.queue_redraw()
	_potion_mana.sub_text = "×%d" % GameState.mana_potions
	_potion_mana.cooldown = clampf(player.potion_cd / Player.POTION_COOLDOWN, 0.0, 1.0)
	_potion_mana.usable = GameState.mana_potions > 0
	_potion_mana.queue_redraw()
	_update_target()
	_update_interact()


## Підказка-кнопка «Говорити / Відкрити», коли поруч NPC чи скриня.
func _update_interact() -> void:
	if world == null:
		return
	var it := world.nearest_interactable() if not _overlay_open else {}
	_interact_item = it
	_btn_interact.visible = not it.is_empty()
	if not it.is_empty():
		_btn_interact.text = world.interact_prompt(it)


func _update_quest_tracker() -> void:
	var act := GameState.active_quests()
	_quest_panel.visible = not act.is_empty()
	if act.is_empty():
		return
	var lines: Array = []
	for id in act.slice(0, 3):
		var d := Quests.get_def(str(id))
		var line := "%s: %d/%d" % [d["name"], GameState.quest_progress(str(id)), int(d["need"])]
		if GameState.quest_state(str(id)) == "ready":
			line = "%s — віднести (%s)" % [d["name"], Locations.get_def("village")["npcs"][_npc_index(str(d["turn_in"]))]["name"]]
		lines.append(line)
	_quest_label.text = "Завдання\n" + "\n".join(lines)
	_quest_panel.size = Vector2(250.0 + 24.0, 10)


func _npc_index(npc_id: String) -> int:
	var arr: Array = Locations.get_def("village")["npcs"]
	for i in range(arr.size()):
		if str(arr[i]["id"]) == npc_id:
			return i
	return 0


func _update_skill_button(i: int) -> void:
	var b: TouchButton = _skills[i]
	var id := player.skill_id(i)
	if id == "":
		b.empty = true
		b.text = "—"
		b.sub_text = ""
		b.cooldown = 0.0
		b.usable = true
		b.icon = null
	else:
		var def: Dictionary = Skills.get_def(id)
		b.empty = false
		b.color = Color(def["color"]).darkened(0.35)
		b.text = def["short"]
		b.sub_text = "%d чару" % int(def["mana"])
		b.cooldown = player.skill_cd_ratio(i)
		b.usable = player.mana >= float(def["mana"])
		b.icon = Icons.texture(Icons.skill_icon_id(id, GameState.blessing))
	b.queue_redraw()


func _update_target() -> void:
	var t := player.last_target
	var show := t != null and is_instance_valid(t) and not t.dead and player.last_target_t > 0.0
	_target_panel.visible = show
	if not show:
		return
	if t.kind != _target_kind:
		_target_kind = t.kind
		_target_art.texture = FolkTheme.art_texture("res://art/enemies/%s.png" % t.kind)
	var tn: String = t.boss_name if t.is_boss else str(t.def.get("name", "Ворог")) + (" (ватажок)" if t.is_leader else "")
	_target_name.text = "%s · рів. %d" % [tn, t.level]
	_target_bar.set_values(t.hp, t.max_hp)


# ---------- Дотики (багатопальцеве керування) ----------

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if event.is_action("open_bag"):
			if _overlay_open:
				if _inventory.visible:
					_close_overlay()
			else:
				open_inventory(InventoryScreen.TAB_BAG)
		elif event.is_action("open_map"):
			if _overlay_open:
				if _map_screen.visible:
					_close_overlay()
			else:
				open_map()
		elif event.is_action("ui_cancel") and _overlay_open:
			_close_overlay()
		return
	if _overlay_open:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.get(d.index, "") == "stick":
			player.move_input = _stick.drag(d.position)


func _portrait_rect() -> Rect2:
	var r := Rect2(_portrait.global_position, _portrait.size)
	return r.grow(8.0)


func _touch_down(index: int, pos: Vector2) -> void:
	if _touches.has(index):
		return
	var vs := _root.size
	if _submenu.visible:
		if Rect2(_submenu.global_position, _submenu.size).has_point(pos):
			return   # дотик на меню обробляють самі кнопки
		if not _portrait_rect().has_point(pos):
			close_submenu()
			return
	if _portrait_rect().has_point(pos):
		_touches[index] = "portrait"
		return
	if _btn_interact.visible and Rect2(_btn_interact.global_position, _btn_interact.size).has_point(pos):
		return
	if _attack.hit(pos):
		_touches[index] = "attack"
		_attack.set_pressed(true)
		player.attack_held = true
		return
	for i in range(SKILL_COUNT):
		if (_skills[i] as TouchButton).hit(pos, 1.1):
			_touches[index] = "skill%d" % i
			(_skills[i] as TouchButton).set_pressed(true)
			player.use_skill(i)
			return
	if _potion_hp.hit(pos, 1.1):
		_touches[index] = "potion_hp"
		_potion_hp.set_pressed(true)
		player.use_potion("hp")
		return
	if _potion_mana.hit(pos, 1.1):
		_touches[index] = "potion_mana"
		_potion_mana.set_pressed(true)
		player.use_potion("mana")
		return
	if Rect2(_mini.position, _mini.size).grow(6.0).has_point(pos):
		_touches[index] = "map"
		return
	if pos.x < vs.x * 0.5 and pos.y > vs.y * 0.28 and not _has_role("stick"):
		_touches[index] = "stick"
		_stick.begin(pos)
		player.move_input = Vector2.ZERO
		return
	if pos.y > TOP_STRIP and world != null:
		# дотик по землі справа: підібрати здобич, що лежить там
		world.tap_world(pos)


func _touch_up(index: int) -> void:
	var role: String = _touches.get(index, "")
	_touches.erase(index)
	match role:
		"stick":
			_stick.end()
			player.move_input = Vector2.ZERO
		"attack":
			_attack.set_pressed(false)
			player.attack_held = false
		"potion_hp":
			_potion_hp.set_pressed(false)
		"potion_mana":
			_potion_mana.set_pressed(false)
		"map":
			open_map()
		"portrait":
			toggle_submenu()
		_:
			if role.begins_with("skill"):
				(_skills[int(role.substr(5))] as TouchButton).set_pressed(false)


func _has_role(role: String) -> bool:
	return role in _touches.values()


func _release_all() -> void:
	for idx in _touches.keys().duplicate():
		var role: String = _touches[idx]
		if role == "map" or role == "portrait":
			_touches.erase(idx)
		else:
			_touch_up(idx)
	if player != null:
		player.move_input = Vector2.ZERO
		player.attack_held = false


# ---------- Повідомлення ----------

func show_death(xp_lost: int) -> void:
	_release_all()
	var lost_text := "Звитяга: −%d." % xp_lost if xp_lost > 0 else "Звитяга не втрачена."
	_death_label.text = "Ти упав у бою.\nМокош сплітає нитку знову: ти прокинешся біля Капища.\n%s Гривні й речі лишаються з тобою." % lost_text
	_death_box.visible = true


func hide_death() -> void:
	_death_box.visible = false


func show_level_up(lvl: int) -> void:
	_banner.text = "Новий рівень: %d!\n+%d перки" % [lvl, GameState.PERKS_PER_LEVEL]
	_banner.visible = true
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: _banner.visible = false)


func toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# ---------- Екрани ----------

func _enter_overlay() -> void:
	close_submenu()
	_release_all()
	_hide_screens()
	_overlay_open = true
	get_tree().paused = true


func _hide_screens() -> void:
	_perk_screen.visible = false
	_pause_menu.visible = false
	_inventory.visible = false
	_map_screen.visible = false
	_dialog.visible = false
	_shop.visible = false
	_quest_screen.visible = false


func open_perks() -> void:
	_enter_overlay()
	_perk_screen.open()


func open_inventory(tab: int = InventoryScreen.TAB_BAG) -> void:
	_enter_overlay()
	_inventory.open(tab)


func open_quests() -> void:
	_enter_overlay()
	_quest_screen.open()


func open_dialog(npc_id: String) -> void:
	if _overlay_open:
		return
	_enter_overlay()
	_dialog.open(npc_id)


func open_shop() -> void:
	_enter_overlay()
	_shop.open()


func open_map() -> void:
	if _overlay_open or world == null:
		return
	_enter_overlay()
	_map_screen.open(world, player)


func _open_pause() -> void:
	_enter_overlay()
	_pause_menu.open()


func is_overlay_open() -> bool:
	return _overlay_open


func _close_overlay() -> void:
	_hide_screens()
	_overlay_open = false
	get_tree().paused = false
	GameState.save_game()
	_on_state_changed()


func _go_title() -> void:
	GameState.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
