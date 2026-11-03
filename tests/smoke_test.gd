## Запуск: godot --headless --path . res://tests/smoke_test.tscn
## Перевіряє: усі скрипти компілюються, сцени створюються, світ живе кілька сотень кадрів,
## бій, навички, рівні, Древо з JSON, сумка й спорядження, здобич, зілля, мапа, вихід, швидкі слоти,
## розігрів шейдерів, міграція збереження.
extends Node

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _scripts(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(d), out)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		print("ТАЙМАУТ тесту")
		get_tree().quit(2))
	_run.call_deferred()


func _make_world(skip: bool = true) -> GameWorld:
	var w := load("res://scenes/world.tscn").instantiate() as GameWorld
	w.skip_warmup = skip
	add_child(w)
	return w


func _drop_world(w: Node) -> void:
	get_tree().paused = false
	w.queue_free()
	await frames(3)


func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _run() -> void:
	print("== 1. Скрипти ==")
	var list: Array = []
	_scripts("res://scripts", list)
	for p in list:
		var s := load(p) as GDScript
		ok(s != null and s.can_instantiate(), p)
	var gs = GameState
	gs.delete_save()

	print("== 2. Древо з res://data/perk_tree.json ==")
	var tree_errs := PerkTree.load_from_file()
	ok(tree_errs.is_empty(), "res://data/perk_tree.json читається без помилок %s" % str(tree_errs))
	var raw: Variant = _read_json(PerkTree.TREE_PATH)
	ok(typeof(raw) == TYPE_DICTIONARY, "файл — JSON-об'єкт")
	var rawd: Dictionary = raw
	var val := PerkTree.validate(rawd)
	ok((val["errors"] as Array).is_empty() and (val["warnings"] as Array).is_empty(), "перевірка формату: без помилок і застережень %s" % str(val))
	var nn := PerkTree.nodes().size()
	ok(nn >= 80 and nn <= 120, "вузлів 80–120 (є %d)" % nn)
	var types := {}
	var regions := {}
	for id in PerkTree.nodes():
		var nd: Dictionary = PerkTree.get_def(id)
		types[nd["type"]] = int(types.get(nd["type"], 0)) + 1
		regions[nd.get("region", "")] = true
	ok(types.get("notable", 0) >= 6 and types.get("keystone", 0) >= 3, "є значущі та ключові вузли: %s" % str(types))
	ok(types.get("skill", 0) >= 3, "є вузли навичок (%d)" % int(types.get("skill", 0)))
	ok(regions.has("str") and regions.has("agi") and regions.has("faith"), "три регіони: Сила / Спритність / Віра")
	for c in Gear.CLASS_IDS:
		ok(PerkTree.has_node(PerkTree.class_start(c)), "старт класу %s: %s" % [c, PerkTree.class_start(c)])
	# розгалуження: у дереві є вузли з ≥3 сусідами
	var forks := 0
	for id in PerkTree.nodes():
		if PerkTree.neighbors(id).size() >= 3:
			forks += 1
	ok(forks >= 8, "розгалужень (≥3 сусіди): %d" % forks)
	# круговий обмін JSON: зберегти → прочитати → перевірити
	var again: Variant = JSON.parse_string(JSON.stringify(rawd, "\t"))
	ok((PerkTree.validate(again)["errors"] as Array).is_empty(), "JSON переживає запис і читання")
	# негативні перевірки
	var bad: Dictionary = (JSON.parse_string(JSON.stringify(rawd)) as Dictionary)
	(bad["nodes"] as Array).append({"id": "s_t0", "name": "Дубль", "x": 0, "y": 0, "type": "small", "stats": {}})
	ok(not (PerkTree.validate(bad)["errors"] as Array).is_empty(), "дублікат id відхилено")
	bad = JSON.parse_string(JSON.stringify(rawd))
	(bad["links"] as Array).append(["s_t0", "немає_такого"])
	ok(not (PerkTree.validate(bad)["errors"] as Array).is_empty(), "зв'язок з невідомим вузлом відхилено")
	bad = JSON.parse_string(JSON.stringify(rawd))
	(bad["nodes"][3] as Dictionary)["type"] = "чарівний"
	ok(not (PerkTree.validate(bad)["errors"] as Array).is_empty(), "невідомий тип відхилено")
	bad = JSON.parse_string(JSON.stringify(rawd))
	(bad["nodes"][3] as Dictionary)["stats"] = {"літання": 5}
	ok(not (PerkTree.validate(bad)["errors"] as Array).is_empty(), "невідомий бонус відхилено")
	bad = JSON.parse_string(JSON.stringify(rawd))
	(bad["class_starts"] as Dictionary).erase("volkhv")
	ok(not (PerkTree.validate(bad)["errors"] as Array).is_empty(), "відсутній старт класу відхилено")
	ok(not (PerkTree.validate("це не JSON-об'єкт")["errors"] as Array).is_empty(), "не-об'єкт відхилено")
	# вбудована копія в редакторі збігається з грою
	var html := FileAccess.get_file_as_string("res://tools/tree-editor/index.html")
	var a := html.find('<script id="default-tree" type="application/json">')
	var b := html.find("</script>", a)
	ok(a >= 0 and b > a, "у редакторі є вбудоване стартове Древо")
	if a >= 0 and b > a:
		var emb: Variant = JSON.parse_string(html.substr(a + '<script id="default-tree" type="application/json">'.length(), b - a - '<script id="default-tree" type="application/json">'.length()))
		ok(typeof(emb) == TYPE_DICTIONARY and JSON.stringify(emb, "", true) == JSON.stringify(rawd, "", true), "вбудоване Древо в редакторі == res://data/perk_tree.json")
	ok(html.find("http://") < 0 or html.find("src=\"http") < 0, "редактор без зовнішніх ресурсів")

	print("== 3. Формули, перки, смерть ==")
	gs.new_hero("Тест", "perun", "druzhynnyk")
	var start: String = PerkTree.class_start("druzhynnyk")
	ok(gs.unlocked == [start], "клас починає зі свого вузла")
	ok(gs.perk_points == GameState.START_PERKS, "стартові перки: %d" % gs.perk_points)
	var nb: Array = PerkTree.neighbors(start)
	var far := ""
	for id in PerkTree.nodes():
		if not (id in nb) and id != start:
			far = id
			break
	ok(not gs.unlock(far), "не можна відкрити не сусідній вузол (%s)" % far)
	var str0: float = HeroStats.stat("str")
	var first_nb := ""
	for id in nb:
		if PerkTree.stat_of(id, "str") > 0.0:
			first_nb = id
			break
	if first_nb == "":
		first_nb = nb[0]
	ok(gs.unlock(first_nb), "сусідній вузол %s відкрито, 1 вузол = 1 перк" % first_nb)
	ok(gs.perk_points == GameState.START_PERKS - 1, "перків лишилось %d" % gs.perk_points)
	ok(HeroStats.stat("str") >= str0, "бонус вузла враховано")
	var gained: int = gs.add_xp(gs.xp_needed())
	ok(gained == 1 and gs.level == 2 and gs.perk_points == GameState.START_PERKS - 1 + 3, "рівень 2: +3 перки (%d)" % gs.perk_points)
	gs.xp = 100
	var lost: int = gs.apply_death_penalty()
	ok(lost == mini(100, int(round(0.1 * gs.xp_needed()))) and gs.xp == 100 - lost, "смерть: −10%% звитяги (%d)" % lost)
	ok(gs.save_game() and gs.load_game(), "збереження/завантаження")

	print("== 4. Баланс ==")
	gs.new_hero("Тест", "perun", "druzhynnyk")
	ok(HeroStats.max_hp() >= 180.0, "здоров'я героя 1 рівня ≥ 180, було ~60 (є %d)" % int(HeroStats.max_hp()))
	for id in EnemyDefs.IDS:
		ok(float(EnemyDefs.get_def(id)["hp"]) >= 90.0 or id == "wraith", "ворог %s: життя %d" % [id, int(EnemyDefs.get_def(id)["hp"])])
	var hits_to_die := HeroStats.max_hp() / float(EnemyDefs.get_def("novice")["dmg"])
	ok(hits_to_die >= 8.0 and hits_to_die <= 40.0, "героя вбиває ≈%d ударів послушника" % int(hits_to_die))
	ok(Strings.vocative("Ярослав") == "Ярославе" and Strings.vocative("Марія") == "Маріє", "кличний відмінок: %s, %s" % [Strings.vocative("Ярослав"), Strings.vocative("Марія")])

	print("== 5. Предмети і спорядження ==")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen_r := {}
	var bad_items := 0
	for i in range(300):
		var it := Items.generate(rng.randi_range(1, 20), rng)
		seen_r[it["rarity"]] = true
		if Items.slot_of(it) == "" or str(it["name"]) == "" or not it.has("stats"):
			bad_items += 1
	ok(bad_items == 0, "300 випадкових предметів коректні")
	ok(seen_r.size() >= 3, "рідкість: %d різних ступенів" % seen_r.size())
	gs.new_hero("Тест", "perun", "druzhynnyk")
	ok(HeroStats.attack_kind() == "melee", "дружинник стартує з ближнім боєм")
	var dmg_before: float = HeroStats.weapon_damage()
	var bow := Items.make("bow", 5, 2, rng)
	ok(gs.add_item(bow), "лук у сумці")
	ok(gs.equip_from_bag(gs.bag.size() - 1), "лук одягнено")
	ok(HeroStats.attack_kind() == "arrow", "зі луком атака — стріли")
	ok(gs.bag.size() == 1 and Items.slot_of(gs.bag[0]) == "weapon", "старий меч повернувся в сумку")
	var staff := Items.make("staff", 5, 2, rng)
	gs.add_item(staff)
	gs.equip_from_bag(gs.bag.size() - 1)
	ok(HeroStats.attack_kind() == "magic", "зі жезлом атака — магічна куля")
	ok(HeroStats.weapon_damage() != dmg_before, "шкода змінилась від зброї")
	var armor_a := HeroStats.armor()
	var plate := Items.make("plate", 8, 3, rng)
	gs.add_item(plate)
	gs.equip_from_bag(gs.bag.size() - 1)
	ok(HeroStats.armor() >= armor_a, "броня не зменшилась від кращих лат")
	var hp_a := HeroStats.max_hp()
	var amu := Items.make("amulet", 10, 3, rng)
	amu["stats"]["hp"] = 100.0
	gs.add_item(amu)
	gs.equip_from_bag(gs.bag.size() - 1)
	ok(HeroStats.max_hp() > hp_a, "оберіг додає життя")
	ok(gs.unequip("amulet") and HeroStats.max_hp() <= hp_a + 0.01, "оберіг знято — життя повернулось")
	var gold0: int = gs.gold
	var sold: int = gs.sell(0)
	ok(sold > 0 and gs.gold == gold0 + sold, "продаж за гривні: +%d" % sold)
	# сумка заповнюється
	gs.bag = []
	for i in range(GameState.BAG_SIZE):
		gs.add_item(Items.generate(1, rng))
	ok(gs.bag.size() == GameState.BAG_SIZE and not gs.add_item(Items.generate(1, rng)), "сумка на 30 місць, повна не приймає")
	gs.bag = []

	print("== 6. Збереження: міграція v1 → v2 ==")
	var v1 := {"version": 1, "name": "Старий", "blessing": "veles", "class": "strilets", "level": 7, "xp": 30,
		"unlocked": ["a1", "a2", "s2"], "skills": ["arrow_volley"], "perk_points": 4}
	ok(gs.from_dict(v1), "старе збереження читається")
	ok(gs.level == 7 and gs.hero_name == "Старий" and gs.unlocked[0] == PerkTree.class_start("strilets"), "рівень збережено, Древо скинуто до старту")
	ok(gs.perk_points == GameState.START_PERKS + 3 * 6, "перки повернено: %d" % gs.perk_points)
	ok(gs.notice != "", "є пояснення для гравця")
	ok(HeroStats.attack_kind() == "arrow", "стрілець після міграції зі луком")
	var rt := gs.to_dict()
	gs.from_dict(JSON.parse_string(JSON.stringify(rt)))
	ok(gs.level == 7 and gs.equipment.size() >= 2, "v2 переживає запис і читання")

	print("== 7. Сцени ==")
	var title: Node = load("res://scenes/main.tscn").instantiate()
	add_child(title)
	await frames(3)
	ok(is_instance_valid(title), "головний екран")
	title.queue_free()
	await frames(2)
	var ch: CreateHero = load("res://scenes/create_hero.tscn").instantiate()
	add_child(ch)
	await frames(2)
	ch._name_edit.text = "Ярослав"
	ch._on_next()
	await frames(2)
	ch._on_next()
	await frames(2)
	ok(ch.step == CreateHero.Step.BLESSING and ch._next.disabled, "вибір бога: «Далі» вимкнено")
	for id in Blessings.IDS:
		ch._pick_blessing(id)
	await frames(1)
	ch._on_next()
	await frames(2)
	for id in Gear.CLASS_IDS:
		ch._pick_class(id)
	ch._pick_class("strilets")
	ok(ch.hero_name == "Ярослав" and ch.blessing == "svarog" and ch.hero_class == "strilets", "створення героя: стан")
	ch.queue_free()
	await frames(2)

	print("== 8. Розігрів шейдерів (перший вхід у світ) ==")
	gs.new_hero("Тест", "perun", "druzhynnyk")
	var ww := _make_world(false)
	var t0 := Time.get_ticks_msec()
	var frames_n := 0
	while not ww.is_warmed and frames_n < 600:
		await get_tree().process_frame
		frames_n += 1
	ok(ww.is_warmed, "розігрів завершився за %d кадрів" % frames_n)
	await frames(5)
	ok(get_tree().get_nodes_in_group("loot").is_empty(), "після розігріву на землі немає зайвої здобичі")
	var sun_ok := true
	var omni := 0
	for n in ww.find_children("*", "Light3D", true, false):
		if (n as Light3D).shadow_enabled:
			sun_ok = false
		if n is OmniLight3D or n is SpotLight3D:
			omni += 1
	ok(sun_ok, "тіні вимкнено в усіх джерелах світла")
	ok(omni == 0, "немає точкових джерел світла (вони міняють шейдери в русі)")
	await _drop_world(ww)

	for combo in [["perun", "druzhynnyk"], ["veles", "strilets"], ["stribog", "volkhv"], ["svarog", "druzhynnyk"], ["mokosh", "volkhv"], ["dazhbog", "strilets"]]:
		print("== 9. Світ: %s / %s ==" % combo)
		gs.new_hero("Тест", combo[0], combo[1])
		gs.perk_points = 30
		# відкриваємо ланцюжок від старту
		var cur: String = PerkTree.class_start(combo[1])
		for step in range(12):
			var nxt := ""
			for cand in PerkTree.neighbors(cur):
				if not gs.is_unlocked(cand):
					nxt = cand
					break
			if nxt == "":
				break
			gs.unlock(nxt)
			cur = nxt
		var w := _make_world(true)
		await frames(20)
		var world := w
		ok(world.player != null and world.hud != null, "гравець і HUD створені")
		var enemies := get_tree().get_nodes_in_group("enemies")
		ok(enemies.size() >= 10, "вороги: %d" % enemies.size())
		var p: Player = world.player
		var e: Enemy = enemies[0] as Enemy
		e.global_position = p.global_position + Vector3(1.2, 0, 0)
		p.basic_attack()
		await frames(10)
		p.mana = 99999.0
		for slot in range(4):
			p.use_skill(slot)
			await frames(6)
		p.attack_held = true
		for i in range(240):
			p.mana = 99999.0
			await get_tree().physics_frame
		p.attack_held = false
		ok(p.hp > 0 or p.dead, "гравець живий або відроджується")
		# смерть: гривні й речі лишаються
		gs.add_gold(77)
		gs.add_item(Items.generate(3, rng))
		var gold_b: int = gs.gold
		var bag_b: int = gs.bag.size()
		var eq_b: int = gs.equipment.size()
		var xp_before: int = gs.xp
		p.take_damage(999999.0, p.global_position + Vector3(1, 0, 0), 0.0)
		await frames(3)
		ok(p.dead, "гравець помер")
		await get_tree().create_timer(3.4).timeout
		ok(not p.dead and p.hp > 0, "гравець відроджений")
		ok(gs.xp <= xp_before, "звитяга не зросла після смерті")
		ok(gs.gold == gold_b and gs.bag.size() == bag_b and gs.equipment.size() == eq_b, "після смерті гривні й речі на місці")
		gs.add_xp(gs.xp_needed())
		await frames(5)
		world.hud._close_overlay()
		await _drop_world(w)

	print("== 10. Здобич, зілля, швидкі слоти, мапа, вихід ==")
	gs.new_hero("Тест", "stribog", "druzhynnyk")
	gs.perk_points = 40
	var skill_nodes: Array = []
	for id in PerkTree.nodes():
		if str(PerkTree.get_def(id).get("skill", "")) != "":
			skill_nodes.append(id)
	ok(skill_nodes.size() >= 3, "у Древі навичок-вузлів: %d" % skill_nodes.size())
	# відкриваємо шлях до кількох навичок (BFS по сусідах)
	for sn in skill_nodes:
		var path: Array = _path_to(PerkTree.class_start("druzhynnyk"), sn)
		for id in path:
			if not gs.is_unlocked(id):
				gs.unlock(id)
	var learned: Array = gs.learned_skills()
	ok(learned.size() >= 4, "вивчено навичок: %d (%s)" % [learned.size(), ", ".join(learned)])
	var w2 := _make_world(true)
	await frames(10)
	var p2: Player = w2.player
	var hud: Hud = w2.hud
	# швидкі слоти
	var s3: String = gs.quick_skill(2)
	ok(s3 != "", "третій слот заповнений: %s" % s3)
	var other: String = ""
	for id in learned:
		if id != gs.quick_skill(0):
			other = id
			break
	gs.set_quick(0, other)
	ok(gs.quick_skill(0) == other, "навичку %s поставлено у слот 1" % other)
	gs.set_quick(3, gs.quick_skill(0))
	ok(gs.quick_skill(3) == other and gs.quick_skill(0) != other, "повторний вибір міняє слоти місцями")
	gs.set_quick(1, "")
	ok(gs.quick_skill(1) == "", "слот можна спорожнити")
	gs.set_quick(1, "ancestral_heal" if not ("ancestral_heal" in learned) else "stribog_dash")
	await frames(3)
	# екрани
	hud.open_inventory(InventoryScreen.TAB_BAG)
	await frames(3)
	ok(hud._inventory.visible and get_tree().paused, "сумка відкрита, гра на паузі")
	gs.add_item(Items.make("bow", 4, 1, rng))
	await frames(2)
	hud._inventory._on_slot_tapped(hud._inventory._bag_slots[0])
	ok(hud._inventory._btn_equip.visible, "після вибору предмета є кнопка «Одягти»")
	hud._inventory._on_equip()
	await frames(2)
	ok(HeroStats.attack_kind() == "arrow", "екран сумки: лук одягнено")
	hud._inventory._show_tab(InventoryScreen.TAB_SKILLS)
	await frames(2)
	hud._inventory._sel_quick = 2
	hud._inventory._on_skill_tapped(str(learned[0]))
	ok(gs.quick_skill(2) == str(learned[0]), "екран навичок: слот 3 = %s" % learned[0])
	hud._close_overlay()
	await frames(2)
	hud.open_map()
	await frames(3)
	ok(hud._map_screen.visible, "повна карта відкрита")
	hud._close_overlay()
	await frames(2)
	hud.open_perks()
	await frames(3)
	ok(hud._perk_screen.visible and get_tree().paused, "Древо відкрито")
	hud._close_overlay()
	await frames(2)
	# здобич на землі
	var loot_root: Node = w2.get_node("Loot")
	var pp: Vector3 = p2.global_position
	var g0: int = gs.gold
	var hp0: int = gs.hp_potions
	var mp0: int = gs.mana_potions
	var b0: int = gs.bag.size()
	LootDrop.make_drop(loot_root, pp + Vector3(2.5, 0, 0), LootDrop.KIND_GOLD, 25, {}, rng)
	LootDrop.make_drop(loot_root, pp + Vector3(-2.5, 0, 0), LootDrop.KIND_HP, 1, {}, rng)
	LootDrop.make_drop(loot_root, pp + Vector3(0, 0, 2.5), LootDrop.KIND_MANA, 1, {}, rng)
	var item_drop := LootDrop.make_drop(loot_root, pp + Vector3(0, 0, -2.5), LootDrop.KIND_ITEM, 1, Items.generate(3, rng), rng)
	await get_tree().create_timer(1.6).timeout
	ok(gs.gold == g0 + 25 and gs.hp_potions == hp0 + 1 and gs.mana_potions == mp0 + 1, "гривні та зілля підібрано автоматично (поруч)")
	ok(gs.bag.size() == b0, "предмет сам не підбирається здаля")
	# підбір дотиком: переносимо предмет-ціль на екранну точку
	var scr: Vector2 = w2.camera.unproject_position(item_drop.global_position)
	ok(w2.tap_world(scr), "дотик по предмету на землі спрацював")
	await get_tree().create_timer(2.5).timeout
	ok(gs.bag.size() == b0 + 1, "предмет підібрано дотиком і йдучи до героя")
	# бій дає здобич
	var killed := 0
	var before_loot := get_tree().get_nodes_in_group("loot").size()
	for e2 in get_tree().get_nodes_in_group("enemies"):
		var en := e2 as Enemy
		en.take_damage(99999.0, p2.global_position, false, 0.0)
		killed += 1
		if killed >= 12:
			break
	await frames(5)
	ok(get_tree().get_nodes_in_group("loot").size() > before_loot, "вбиті вороги лишили здобич (%d)" % (get_tree().get_nodes_in_group("loot").size() - before_loot))
	# зілля
	p2.hp = 10.0
	p2.potion_cd = 0.0
	var hpp: int = gs.hp_potions
	ok(p2.use_potion("hp") and p2.hp > 100.0 and gs.hp_potions == hpp - 1, "зілля життя лікує й витрачається")
	ok(not p2.use_potion("hp"), "друге зілля одразу — на перезарядці")
	p2.mana = 0.0
	p2.potion_cd = 0.0
	ok(p2.use_potion("mana") and p2.mana > 0.0, "зілля чару відновлює чар")
	# мапа
	var cells_a := 0
	for v in gs.explored:
		cells_a += 1 if v != 0 else 0
	p2.global_position = Vector3(15, 0, -12)
	await get_tree().create_timer(0.7).timeout
	var cells_b := 0
	for v in gs.explored:
		cells_b += 1 if v != 0 else 0
	ok(cells_b > cells_a, "мапа відкривається за ходом: %d → %d клітинок" % [cells_a, cells_b])
	ok(gs.is_explored(gs.map_cell(Vector2(15, -12))), "клітинка під героєм досліджена")
	ok(not gs.is_explored(gs.map_cell(Vector2(-30, 25))), "далека клітинка ще темна")
	# вихід: тригер із написом «Шлях закритий»
	var ep: Vector2 = w2.exit_trigger_pos(0)
	p2.global_position = Vector3(ep.x, 0, ep.y)
	await get_tree().create_timer(0.6).timeout
	ok(hud._toast.visible and hud._toast.text == "Шлях закритий", "вихід: напис «%s»" % hud._toast.text)
	ok(w2.exit_gates.size() >= 1 and is_instance_valid(w2.exit_gates[0]), "брама у скелях є")
	# HUD: 4 кнопки навичок і зілля
	ok(hud._skills.size() == 4, "чотири кнопки навичок")
	ok(hud._mini != null and hud._mini.visible, "міні-карта в куті HUD")
	# дотик по міні-карті відкриває карту
	var mc: Vector2 = hud._mini.position + hud._mini.size * 0.5
	hud._touch_down(5, mc)
	hud._touch_up(5)
	await frames(3)
	ok(hud._map_screen.visible, "дотик по міні-карті відкриває повну карту")
	hud._close_overlay()
	await frames(2)
	await _drop_world(w2)

	print("== 11. Вузол: перевірка редактора (JS) ==")
	ok(FileAccess.file_exists("res://tools/tree-editor/index.html"), "редактор у репозиторії")

	gs.delete_save()
	print("== Підсумок: %d перевірок, %d помилок ==" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


## Найкоротший шлях за зв'язками (BFS), для тестів.
func _path_to(from: String, to: String) -> Array:
	var prev := {from: ""}
	var q: Array = [from]
	while not q.is_empty():
		var c: String = q.pop_front()
		if c == to:
			break
		for nb in PerkTree.neighbors(c):
			if not prev.has(nb):
				prev[nb] = c
				q.append(nb)
	var out: Array = []
	var cur := to
	while prev.has(cur) and cur != "":
		out.push_front(cur)
		cur = prev[cur]
	return out
