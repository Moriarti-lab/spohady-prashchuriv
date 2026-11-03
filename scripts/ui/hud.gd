## Ігровий інтерфейс: життя, чар, звитяга, джойстик, кнопки атаки й навичок.
class_name Hud
extends CanvasLayer

const MARGIN := 36.0

var player: Player
var world: Node

var _root: Control
var _stick: TouchStick
var _attack: TouchButton
var _skills: Array = []
var _hp_bar: StatBar
var _mana_bar: StatBar
var _xp_bar: StatBar
var _name_label: Label
var _portrait: Control
var _perk_btn: Button
var _pause_btn: Button
var _death_box: Control
var _death_label: Label
var _banner: Label
var _toast: Label
var _perk_screen: PerkTreeScreen
var _pause_menu: PauseMenu
var _touches := {}      # індекс пальця -> роль ("stick", "attack", "skill0", "skill1")
var _overlay_open := false
var _toast_tween: Tween


func _init() -> void:
	layer = 10


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FolkTheme.fullscreen(_root)
	add_child(_root)
	_build_top_left()
	_build_top_right()
	_build_touch_controls()
	_build_overlays()
	_root.resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	GameState.changed.connect(_on_state_changed)
	_on_state_changed()


func bind(p_player: Player, p_world: Node) -> void:
	player = p_player
	world = p_world
	_refresh_attack_label()


# ---------- Побудова ----------

func _build_top_left() -> void:
	var panel := PanelContainer.new()
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
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_name_label = FolkTheme.label("", 22, Palette.LINEN)
	v.add_child(_name_label)
	_hp_bar = StatBar.new(Palette.HP_COLOR, Strings.HP, 26)
	v.add_child(_hp_bar)
	_mana_bar = StatBar.new(Palette.MANA_COLOR, Strings.MANA, 26)
	v.add_child(_mana_bar)
	_xp_bar = StatBar.new(Palette.XP_COLOR.darkened(0.15), Strings.XP, 20)
	_xp_bar.font_size = 14
	v.add_child(_xp_bar)


func _build_top_right() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = "Меню"
	FolkTheme.apply_button(_pause_btn, Palette.PANEL_LIGHT, 22)
	_pause_btn.custom_minimum_size = Vector2(120, 64)
	_pause_btn.pressed.connect(_open_pause)
	_root.add_child(_pause_btn)
	_perk_btn = Button.new()
	FolkTheme.apply_button(_perk_btn, Palette.TURQUOISE.darkened(0.25), 22)
	_perk_btn.custom_minimum_size = Vector2(190, 64)
	_perk_btn.pressed.connect(open_perks)
	_root.add_child(_perk_btn)


func _build_touch_controls() -> void:
	_stick = TouchStick.new()
	FolkTheme.fullscreen(_stick)
	_root.add_child(_stick)
	_attack = TouchButton.new(80.0, Palette.EMBROIDERY)
	_attack.font_size = 26
	_root.add_child(_attack)
	for i in range(2):
		var b := TouchButton.new(52.0, Palette.TURQUOISE.darkened(0.2))
		b.font_size = 19
		_root.add_child(b)
		_skills.append(b)


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
	_death_label = FolkTheme.label("", 36, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true)
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
	_toast = FolkTheme.label("", 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)
	# екрани
	_perk_screen = PerkTreeScreen.new()
	_perk_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_perk_screen.visible = false
	_perk_screen.closed.connect(_close_overlay)
	add_child(_perk_screen)
	_pause_menu = PauseMenu.new()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.visible = false
	_pause_menu.resume_pressed.connect(_close_overlay)
	_pause_menu.perks_pressed.connect(open_perks)
	_pause_menu.title_pressed.connect(_go_title)
	add_child(_pause_menu)


# ---------- Розкладка ----------

func _layout() -> void:
	var vs := _root.size
	if vs.x < 10.0:
		vs = get_viewport().get_visible_rect().size
	_pause_btn.position = Vector2(vs.x - 120 - 16, 12)
	_perk_btn.position = Vector2(vs.x - 120 - 16 - 190 - 12, 12)
	_attack.place(Vector2(vs.x - MARGIN - 80.0 - 20.0, vs.y - MARGIN - 80.0 - 10.0))
	_skills[0].place(_attack.center + Vector2(-150, 28))
	_skills[1].place(_attack.center + Vector2(-92, -120))
	_stick.home = Vector2(MARGIN + 110.0 + 40.0, vs.y - MARGIN - 110.0 - 20.0)
	if not _stick.active:
		_stick.base_center = _stick.home
		_stick.queue_redraw()
	_banner.size = Vector2(vs.x, 80)
	_banner.position = Vector2(0, vs.y * 0.2)
	_toast.size = Vector2(vs.x, 40)
	_toast.position = Vector2(0, vs.y * 0.62)


# ---------- Оновлення ----------

func _on_state_changed() -> void:
	_name_label.text = "%s · %s %d" % [GameState.hero_name, Strings.LEVEL, GameState.level]
	_xp_bar.set_values(float(GameState.xp), float(GameState.xp_needed()))
	var pts := GameState.perk_points
	_perk_btn.text = "Древо" if pts <= 0 else "Древо  (+%d)" % pts
	(_portrait as PortraitSlot).set_portrait(GameState.blessing, GameState.hero_class)
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
	for i in range(2):
		var b: TouchButton = _skills[i]
		var id := player.skill_id(i)
		if id == "":
			b.empty = true
			b.text = "—"
			b.sub_text = ""
			b.cooldown = 0.0
			b.usable = true
		else:
			var def: Dictionary = Skills.get_def(id)
			b.empty = false
			b.color = Color(def["color"]).darkened(0.35)
			b.text = def["short"]
			b.sub_text = "%d чару" % int(def["mana"])
			b.cooldown = player.skill_cd_ratio(i)
			b.usable = player.mana >= float(def["mana"])
			b.icon = FolkTheme.art_texture(FolkTheme.ICON_DIR + "skills/%s.png" % id)
		b.queue_redraw()


# ---------- Дотики (багатопальцеве керування) ----------

func _input(event: InputEvent) -> void:
	if player == null or _overlay_open:
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


func _touch_down(index: int, pos: Vector2) -> void:
	if _touches.has(index):
		return
	var vs := _root.size
	if _attack.hit(pos):
		_touches[index] = "attack"
		_attack.set_pressed(true)
		player.attack_held = true
		return
	for i in range(2):
		if (_skills[i] as TouchButton).hit(pos):
			_touches[index] = "skill%d" % i
			(_skills[i] as TouchButton).set_pressed(true)
			player.use_skill(i)
			return
	if pos.x < vs.x * 0.5 and pos.y > vs.y * 0.28 and not _has_role("stick"):
		_touches[index] = "stick"
		_stick.begin(pos)
		player.move_input = Vector2.ZERO


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
		"skill0":
			(_skills[0] as TouchButton).set_pressed(false)
		"skill1":
			(_skills[1] as TouchButton).set_pressed(false)


func _has_role(role: String) -> bool:
	return role in _touches.values()


func _release_all() -> void:
	for idx in _touches.keys().duplicate():
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

func open_perks() -> void:
	_release_all()
	_pause_menu.visible = false
	_overlay_open = true
	get_tree().paused = true
	_perk_screen.open()


func _open_pause() -> void:
	_release_all()
	_overlay_open = true
	get_tree().paused = true
	_pause_menu.open()


func _close_overlay() -> void:
	_perk_screen.visible = false
	_pause_menu.visible = false
	_overlay_open = false
	get_tree().paused = false
	GameState.save_game()
	_on_state_changed()


func _go_title() -> void:
	GameState.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
