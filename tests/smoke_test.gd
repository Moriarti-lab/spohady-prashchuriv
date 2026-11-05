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
	get_tree().create_timer(900.0).timeout.connect(func() -> void:
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
	ok(nn >= 250 and nn <= 600, "вузлів 250–600 (є %d)" % nn)
	ok(Nauzi.STARTER_IDS.size() == 9, "стартових id наузів: %d" % Nauzi.STARTER_IDS.size())
	ok(Nauzi.max_level() == 20, "рівень науза 1–20")
	ok(Nauzi.thread_ids().size() >= 3, "каталог ниток")
	ok(Nauzi.socket_count() == 4, "4 сокети")
	ok(GameState.SAVE_VERSION >= 4, "збереження v4+")

	var types := {}
	var regions := {}
	for id in PerkTree.nodes():
		var nd: Dictionary = PerkTree.get_def(id)
		types[nd["type"]] = int(types.get(nd["type"], 0)) + 1
		regions[nd.get("region", "")] = true
	ok(types.get("notable", 0) >= 12 and types.get("keystone", 0) >= 6 and types.get("core", 0) == 1, "є значущі та ключові вузли: %s" % str(types))
	ok(types.get("skill", 0) == 0, "пасивне Древо: 0 вузлів-умінь (%d)" % int(types.get("skill", 0)))
	ok(types.get("notable", 0) >= 12, "notable вузлів ≥12 (%d)" % int(types.get("notable", 0)))
	ok(regions.has("str") and regions.has("agi") and regions.has("faith"), "три регіони: Сила / Спритність / Віра")
	for c in Gear.CLASS_IDS:
		ok(PerkTree.has_node(PerkTree.class_start(c)), "старт класу %s: %s" % [c, PerkTree.class_start(c)])
	# розгалуження: у дереві є вузли з ≥3 сусідами
	var forks := 0
	for id in PerkTree.nodes():
		if PerkTree.neighbors(id).size() >= 3:
			forks += 1
	ok(forks >= 40, "розгалужень (≥3 сусіди): %d" % forks)
	# стартові наузи: рівно три на клас (не вузли Древа)
	for c in Gear.CLASS_IDS:
		var found: int = int(Gear.STARTER_SKILLS[c].size())
		ok(found == 3, "клас %s: три стартові наузи (%d)" % [c, found])
		for sk in Gear.STARTER_SKILLS[c]:
			ok(Skills.DATA.has(sk), "стартовий науз %s існує для %s" % [sk, c])
	# пасивне Древо: без skill/mod_skill на вузлах
	var with_skill := 0
	for id in PerkTree.nodes():
		if str(PerkTree.get_def(id).get("skill", "")) != "":
			with_skill += 1
	ok(with_skill == 0, "пасивне Древо без умінь на вузлах (%d)" % with_skill)
	ok(PerkTree.VERSION >= 4, "формат Древа v4+")
	# жодних перехресних зв'язків біля старту: 5 кроків від старту класу — лише власний регіон
	for c in Gear.CLASS_IDS:
		var st4: String = PerkTree.class_start(c)
		var reg: String = str(PerkTree.get_def(st4).get("region", ""))
		var dist := {st4: 0}
		var qq: Array = [st4]
		var foreign := 0
		while not qq.is_empty():
			var cc: String = qq.pop_front()
			if int(dist[cc]) >= 5:
				continue
			for nb2 in PerkTree.neighbors(cc):
				if not dist.has(nb2):
					dist[nb2] = int(dist[cc]) + 1
					if str(PerkTree.get_def(nb2).get("region", "")) != reg:
						foreign += 1
					qq.append(nb2)
		ok(foreign <= 6, "біля старту %s мало чужих стиків (≤6, є %d) — суміш на межах як у PoE" % [c, foreign])
	# кожен вузол має опис або ефект із числами
	var no_text := 0
	for id in PerkTree.nodes():
		if PerkTree.effect_text(id) == "" and str(PerkTree.get_def(id).get("description", "")) == "":
			no_text += 1
	ok(no_text == 0, "кожен вузол має опис (без опису: %d)" % no_text)
	# круговий обмін JSON: зберегти → прочитати → перевірити
	var again: Variant = JSON.parse_string(JSON.stringify(rawd, "\t"))
	ok((PerkTree.validate(again)["errors"] as Array).is_empty(), "JSON переживає запис і читання")
	# негативні перевірки
	var bad: Dictionary = (JSON.parse_string(JSON.stringify(rawd)) as Dictionary)
	(bad["nodes"] as Array).append({"id": "s_root", "name": "Дубль", "x": 0, "y": 0, "type": "small", "stats": {}})
	ok(not (PerkTree.validate(bad)["errors"] as Array).is_empty(), "дублікат id відхилено")
	bad = JSON.parse_string(JSON.stringify(rawd))
	(bad["links"] as Array).append(["s_root", "немає_такого"])
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
	ok(gs.starter_pending() and gs.starter_choices().size() == 3, "новий герой: є вибір з трьох стартових навичок")
	ok(gs.learned_skills().is_empty() or gs.learned_skills().size() == 1, "до вибору навичок майже немає")
	var far := ""
	for id in PerkTree.nodes():
		if not (id in nb) and id != start:
			far = id
			break
	ok(not gs.unlock(far), "не можна відкрити не сусідній вузол (%s)" % far)
	ok(not gs.unlock(nb[0]), "поки не обрано стартову навичку, Древо закрите")
	var choices: Array = gs.starter_choices()
	ok(gs.choose_starter(choices[1]["node"]), "стартову навичку обрано: %s" % choices[1]["skill"])
	ok(choices[1]["skill"] in gs.learned_skills() and gs.perk_points == GameState.START_PERKS, "навичка вивчена безкоштовно, перки на місці")
	ok(not gs.choose_starter(choices[0]["node"]), "вдруге стартову навичку обрати не можна")
	ok(not gs.unlock(choices[0]["node"]), "id науза не є вузлом Древа — відкрити не можна")
	ok(gs.quick_skill(0) == choices[1]["skill"], "навичка потрапила в перший швидкий слот")
	var str0: float = HeroStats.stat("str")
	var first_nb := ""
	for id in nb:
		if PerkTree.stat_of(id, "str") > 0.0:
			first_nb = id
			break
	if first_nb == "":
		first_nb = str(nb[0]) if nb.size() > 0 else ""
	if first_nb == "":
		for id in PerkTree.neighbors(choices[1]["node"]):
			if id != start and not gs.is_unlocked(id):
				first_nb = id
				break
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
		ok(float(EnemyDefs.get_def(id)["hp"]) >= 60.0, "ворог %s: життя %d" % [id, int(EnemyDefs.get_def(id)["hp"])])
	var hits_to_die := HeroStats.max_hp() / float(EnemyDefs.get_def("novice")["dmg"])
	ok(hits_to_die >= 8.0 and hits_to_die <= 40.0, "героя вбиває ≈%d ударів послушника" % int(hits_to_die))
	ok(Strings.vocative("Ярослав") == "Ярославе" and Strings.vocative("Марія") == "Маріє", "кличний відмінок: %s, %s" % [Strings.vocative("Ярослав"), Strings.vocative("Марія")])

	print("== 5. Предмети, слоти, торгівля ==")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen_r := {}
	var bad_items := 0
	var seen_t := {}
	for i in range(300):
		var it := Items.generate(rng.randi_range(1, 20), rng)
		seen_r[it["rarity"]] = true
		seen_t[Items.type_of(it)] = true
		if Items.type_of(it) == "" or Items.slots_for(it).is_empty() or str(it["name"]) == "" or not it.has("stats"):
			bad_items += 1
	ok(bad_items == 0, "300 випадкових предметів коректні")
	ok(seen_r.size() >= 3, "рідкість: %d різних ступенів" % seen_r.size())
	ok(seen_t.size() >= 8, "випадкові типи предметів: %s" % str(seen_t.keys()))
	for t in Items.TYPE_SLOTS:
		var ti := Items.generate(6, rng, t, 2)
		ok(Items.type_of(ti) == t and str(Items.icon_of(ti)) != "", "генерація типу %s → %s" % [t, ti["name"]])
	gs.new_hero("Тест", "perun", "druzhynnyk")
	gs.choose_starter(gs.starter_choices()[0]["node"])
	ok(HeroStats.attack_kind() == "melee", "дружинник стартує з ближнім боєм")
	ok(gs.equipment.get("main", null) != null and gs.equipment.get("off", null) != null and gs.equipment.get("body", null) != null, "стартовий набір: меч, щит, кольчуга")
	var dmg_before: float = HeroStats.weapon_damage()
	var bow := Items.make("bow", 5, 2, rng)
	ok(Items.is_two_handed(bow) and Items.type_of(bow) == "hand2", "лук — дворучний")
	ok(gs.add_item(bow), "лук у сумці")
	ok(gs.equip_from_bag(gs.bag.size() - 1), "лук одягнено")
	ok(HeroStats.attack_kind() == "arrow", "з луком атака — стріли")
	ok(gs.equipment.get("main") != null and not (typeof(gs.equipment.get("off", null)) == TYPE_DICTIONARY and not (gs.equipment["off"] as Dictionary).is_empty()), "дворучна зброя вільнить ліву руку (щит знято)")
	ok(gs.bag.size() == 2, "меч і щит повернулися в сумку (%d)" % gs.bag.size())
	# щит назад: дворучна повертається в сумку
	var shield_i := -1
	for i in range(gs.bag.size()):
		if Items.type_of(gs.bag[i]) == "shield":
			shield_i = i
	ok(shield_i >= 0 and gs.equip_from_bag(shield_i), "щит одягається в ліву руку")
	ok(not _is_filled(gs.equipment.get("main", null)), "щит витіснив дворучну зброю з правої руки")
	# дві одноручні (парна зброя)
	var sw1 := Items.make("sword", 5, 1, rng)
	var sw2 := Items.make("axe", 5, 1, rng)
	gs.bag = []
	gs.equipment["main"] = null
	gs.equipment["off"] = null
	gs.add_item(sw1)
	gs.add_item(sw2)
	ok(gs.equip_from_bag(0, "main") and gs.equip_from_bag(0, "off"), "дві одноручні: права й ліва рука")
	ok(_is_filled(gs.equipment["main"]) and _is_filled(gs.equipment["off"]) and Items.type_of(gs.equipment["off"]) == "hand1", "парна зброя (dual wield) стоїть в обох руках")
	var dmg_dual := HeroStats.weapon_damage()
	gs.unequip("off")
	ok(HeroStats.weapon_damage() < dmg_dual, "друга зброя в лівій руці додає шкоди")
	# дворучна поверх двох одноручних
	gs.equip_from_bag(0, "off")
	var gsw := Items.make("greatsword", 6, 2, rng)
	gs.add_item(gsw)
	var bag_before: int = gs.bag.size()
	ok(gs.equip_from_bag(gs.bag.size() - 1), "дворучний меч одягнено")
	ok(Items.is_two_handed(gs.equipment["main"]) and not _is_filled(gs.equipment.get("off", null)), "дворучний меч очистив обидві руки")
	ok(gs.bag.size() == bag_before + 1, "дві одноручні повернулися в сумку (%d)" % gs.bag.size())
	var dmg2: float = HeroStats.weapon_damage()
	ok(dmg2 != dmg_before, "шкода змінилась від зброї")
	ok(not gs.equip_from_bag(0, "off") or Items.type_of(gs.equipment.get("off", {})) != "hand2", "дворучну в ліву руку не покласти")
	var staff := Items.make("staff", 5, 2, rng)
	gs.add_item(staff)
	gs.equip_from_bag(gs.bag.size() - 1)
	ok(HeroStats.attack_kind() == "magic", "з посохом атака — магічна куля")
	# кільця, амулет, броня
	gs.bag = []
	var r1 := Items.make("ring", 4, 1, rng)
	var r2 := Items.make("ring_ruby", 4, 1, rng)
	var r3 := Items.make("ring_emerald", 4, 1, rng)
	gs.add_item(r1)
	gs.add_item(r2)
	gs.add_item(r3)
	gs.equip_from_bag(0)
	gs.equip_from_bag(0)
	ok(_is_filled(gs.equipment["ring1"]) and _is_filled(gs.equipment["ring2"]), "два персні — у двох слотах")
	var hp_r := HeroStats.max_hp()
	gs.equip_from_bag(0)
	ok(gs.bag.size() == 1 and HeroStats.max_hp() > 0.0 and hp_r > 0.0, "третій перстень замінює перший, старий — у сумку")
	var armor_a := HeroStats.armor()
	var plate := Items.make("plate", 8, 3, rng)
	gs.add_item(plate)
	gs.equip_from_bag(gs.bag.size() - 1)
	ok(HeroStats.armor() >= armor_a, "броня не зменшилась від кращих лат")
	for base in ["cap", "gloves", "boots"]:
		var pc := Items.make(base, 5, 1, rng)
		gs.add_item(pc)
		var armor_b := HeroStats.armor()
		gs.equip_from_bag(gs.bag.size() - 1)
		ok(HeroStats.armor() > armor_b, "%s додає броню" % base)
	var hp_a := HeroStats.max_hp()
	var amu := Items.make("amulet", 10, 3, rng)
	amu["stats"]["hp"] = 100.0
	gs.add_item(amu)
	gs.equip_from_bag(gs.bag.size() - 1)
	ok(HeroStats.max_hp() > hp_a, "оберіг додає життя")
	ok(gs.unequip("amulet") and HeroStats.max_hp() <= hp_a + 0.01, "оберіг знято — життя повернулось")
	# продаж і купівля
	var gold0: int = gs.gold
	var sold: int = gs.sell(0)
	ok(sold > 0 and gs.gold == gold0 + sold, "продаж за гривні: +%d" % sold)
	ok(gs.refresh_stock(true) and gs.merchant_stock.size() == GameState.STOCK_SIZE, "торговець: асортимент %d предметів" % gs.merchant_stock.size())
	ok(not gs.refresh_stock(false), "асортимент не оновлюється раніше строку (лишилось %d с)" % gs.stock_seconds_left())
	var stock_types := {}
	for it in gs.merchant_stock:
		stock_types[Items.type_of(it)] = true
	ok(stock_types.size() >= 6, "у крамниці різні типи: %s" % str(stock_types.keys()))
	var item0: Dictionary = gs.merchant_stock[0]
	var price0: int = gs.price_of(item0)
	ok(price0 > Items.sell_value(item0), "купити дорожче, ніж продати (%d > %d)" % [price0, Items.sell_value(item0)])
	gs.gold = price0 - 1
	var bagn: int = gs.bag.size()
	ok(not gs.buy(0) and gs.last_error != "" and gs.bag.size() == bagn, "без гривень не купити: «%s»" % gs.last_error)
	gs.gold = price0 + 10
	ok(gs.buy(0) and gs.gold == 10 and gs.bag.size() == bagn + 1 and gs.merchant_stock.size() == GameState.STOCK_SIZE - 1, "купівля: гривні списано, предмет у сумці")
	gs.gold = 100
	var hpp0: int = gs.hp_potions
	ok(gs.buy_potion("hp") and gs.hp_potions == hpp0 + 1 and gs.gold == 100 - gs.potion_price("hp"), "купівля зілля життя")
	gs.merchant_refresh_at = 1
	ok(gs.refresh_stock(false) and gs.merchant_stock.size() == GameState.STOCK_SIZE, "після закінчення строку асортимент оновився")
	# сумка заповнюється
	gs.bag = []
	for i in range(GameState.BAG_SIZE):
		gs.add_item(Items.generate(1, rng))
	ok(gs.bag.size() == GameState.BAG_SIZE and not gs.add_item(Items.generate(1, rng)), "сумка на 48 місць, повна не приймає")
	gs.gold = 9999
	ok(not gs.buy(0) and gs.last_error != "", "повна сумка: купівля відхилена")
	gs.bag = []

	print("== 6. Збереження: міграція v1, v2 → v3 ==")
	var v1 := {"version": 1, "name": "Старий", "blessing": "veles", "class": "strilets", "level": 7, "xp": 30,
		"unlocked": ["a1", "a2", "s2"], "skills": ["arrow_volley"], "perk_points": 4}
	ok(gs.from_dict(v1), "старе збереження читається")
	ok(gs.level == 7 and gs.hero_name == "Старий" and gs.unlocked[0] == PerkTree.class_start("strilets"), "рівень збережено, Древо скинуто до старту")
	ok(gs.perk_points == GameState.START_PERKS + 3 * 6, "перки повернено: %d" % gs.perk_points)
	ok(gs.notice != "", "є пояснення для гравця")
	ok(gs.starter_pending(), "після міграції треба обрати стартову навичку")
	ok(HeroStats.attack_kind() == "arrow", "стрілець після міграції зі луком")
	ok(gs.location == Locations.START, "після міграції герой у селищі")
	var rt := gs.to_dict()
	ok(int(rt["version"]) == GameState.SAVE_VERSION, "версія збереження %d" % GameState.SAVE_VERSION)
	gs.from_dict(JSON.parse_string(JSON.stringify(rt)))
	ok(gs.level == 7 and gs.equipment.size() >= 2, "v3 переживає запис і читання")
	var v2 := {"version": 2, "name": "Двійка", "blessing": "perun", "class": "druzhynnyk", "level": 4, "xp": 5,
		"unlocked": ["s_t0"], "perk_points": 5,
		"equipment": {"weapon": Items.make("sword", 3, 1, rng), "armor": Items.make("mail", 3, 1, rng), "amulet": Items.make("amulet", 3, 1, rng), "offhand": Items.make("shield_round", 3, 1, rng)},
		"bag": [Items.make("cap", 3, 1, rng)]}
	ok(gs.from_dict(v2), "збереження v2 читається")
	ok(_is_filled(gs.equipment.get("main", null)) and _is_filled(gs.equipment.get("body", null)) and _is_filled(gs.equipment.get("amulet", null)), "v2: зброя, броня й оберіг на нових слотах")
	ok(_is_filled(gs.equipment.get("off", null)) or gs.bag.size() >= 2, "v2: щит не втрачено")
	ok(gs.bag.size() >= 1, "v2: сумка збережена")
	ok(not gs.from_dict({"version": 3, "name": "x"}), "пошкоджене збереження відхилено")
	# повний круг v3: локація, завдання, крамниця
	gs.new_hero("Коло", "perun", "volkhv")
	gs.choose_starter(gs.starter_choices()[2]["node"])
	gs.location = "swamp"
	gs.quests = {"herbs": {"state": "done", "progress": 0}}
	gs.refresh_stock(true)
	gs.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	ok(gs.location == "swamp" and gs.quest_state("herbs") == "done" and gs.merchant_stock.size() == GameState.STOCK_SIZE and not gs.starter_pending(), "v3: локація, завдання, крамниця, стартова навичка збережені")

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
	gs.choose_starter(gs.starter_choices()[0]["node"])
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

	var combo_i := 0
	for combo in [["perun", "druzhynnyk"], ["veles", "strilets"], ["stribog", "volkhv"], ["svarog", "druzhynnyk"], ["mokosh", "volkhv"], ["dazhbog", "strilets"]]:
		print("== 9. Світ: %s / %s ==" % combo)
		gs.new_hero("Тест", combo[0], combo[1])
		gs.choose_starter(gs.starter_choices()[combo_i % 3]["node"])
		combo_i += 1
		gs.location = "forest"
		gs.perk_points = 30
		# відкриваємо ланцюжок від стартової навички
		var cur: String = gs.starter_node
		for step in range(12):
			var nxt := ""
			for cand in PerkTree.neighbors(cur):
				if gs.can_unlock(cand):
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
		p.invuln = 0.0
		p.shield_hp = 0.0
		p.take_damage(999999.0, p.global_position + Vector3(1, 0, 0), 0.0)
		await frames(3)
		ok(p.dead, "гравець помер")
		await get_tree().create_timer(3.4).timeout
		ok(not p.dead and p.hp > 0, "гравець відроджений")
		ok(gs.xp <= xp_before, "звитяга не зросла після смерті")
		ok(gs.gold >= gold_b and gs.bag.size() >= bag_b and gs.equipment.size() == eq_b, "після смерті гривні й речі на місці")
		gs.add_xp(gs.xp_needed())
		await frames(5)
		world.hud._close_overlay()
		await _drop_world(w)

	print("== 10. Здобич, зілля, швидкі слоти, мапа, вихід ==")
	gs.new_hero("Тест", "stribog", "druzhynnyk")
	gs.choose_starter(gs.starter_choices()[0]["node"])
	gs.location = "forest"
	gs.perk_points = 400
	# наузи з каталогу — одягаємо у сокети (активні вміння більше не з Древа)
	var extra_nauzi: Array = ["stribog_dash", "ancestral_heal", "whirlwind", "battle_cry", "ancestral_ward"]
	for sk in extra_nauzi:
		var it: Dictionary = Nauzi.make_nauz(sk, 1)
		gs.add_item(it)
		var slot := -1
		for i in range(4):
			if gs.sockets[i] == null:
				slot = i
				break
		if slot >= 0:
			gs.equip_nauz(slot, int(it.get("uid", 0)))
	var learned: Array = gs.learned_skills()
	ok(learned.size() >= 4, "наузів у сокетах: %d (%s)" % [learned.size(), ", ".join(learned)])
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
	hud._inventory._refresh()
	var bow_slot: ItemSlot = null
	for sl in hud._inventory._bag_slots:
		var bi: int = sl.index
		if bi >= 0 and bi < gs.bag.size() and str(gs.bag[bi].get("base", "")).begins_with("bow"):
			bow_slot = sl
			break
	ok(bow_slot != null, "лук у сумці видно в сітці")
	if bow_slot != null:
		hud._inventory._on_slot_tapped(bow_slot)
	ok(hud._inventory._btn_equip.visible, "після вибору предмета є кнопка «Одягти»")
	hud._inventory._on_equip()
	await frames(2)
	ok(HeroStats.attack_kind() == "arrow", "екран сумки: лук одягнено")
	hud._inventory._show_tab(InventoryScreen.TAB_NAUZI)
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
	ok(not hud._perk_screen._modal.visible, "стартова навичка вже обрана — вікно вибору сховане")
	hud._close_overlay()
	await frames(2)
	var saved_starter: String = gs.starter_skill
	var saved_node: String = gs.starter_node
	gs.starter_skill = ""
	gs.starter_node = ""
	hud.open_perks()
	await frames(3)
	ok(hud._perk_screen._modal.visible and hud._perk_screen._modal_row.get_child_count() == 3, "без стартової навички Древо показує вибір із трьох")
	gs.starter_skill = saved_starter
	gs.starter_node = saved_node
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
	for v in gs.explored_cells():
		cells_a += 1 if v != 0 else 0
	p2.global_position = Vector3(15, 0, -12)
	await get_tree().create_timer(0.7).timeout
	var cells_b := 0
	for v in gs.explored_cells():
		cells_b += 1 if v != 0 else 0
	ok(cells_b > cells_a, "мапа відкривається за ходом: %d → %d клітинок" % [cells_a, cells_b])
	ok(gs.is_explored(gs.map_cell(Vector2(15, -12))), "клітинка під героєм досліджена")
	ok(not gs.is_explored(gs.map_cell(Vector2(-30, 25))), "далека клітинка ще темна")
	# вихід: брама в скелях веде в іншу локацію
	ok(w2.exit_gates.size() >= 2 and is_instance_valid(w2.exit_gates[0]), "брами у скелях є (%d)" % w2.exit_gates.size())
	var to_v: int = w2.exit_index_to("village")
	ok(to_v >= 0 and w2.exit_index_to("swamp") >= 0, "ліс має виходи до селища й болота")
	w2.instant_transition = true
	var ep: Vector2 = w2.exit_trigger_pos(to_v)
	p2.global_position = Vector3(ep.x, 0, ep.y)
	await get_tree().create_timer(0.8).timeout
	ok(gs.location == "village" and gs.arrive_from == "forest", "перехід через браму: ліс → селище (%s ← %s)" % [gs.location, gs.arrive_from])
	gs.location = "forest"
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

	print("== 11. Селище: НПС, діалоги, торгівля ==")
	gs.new_hero("Тест", "perun", "druzhynnyk")
	gs.choose_starter(gs.starter_choices()[0]["node"])
	gs.location = "village"
	gs.gold = 500
	gs.refresh_stock(true)
	var wv := _make_world(true)
	await frames(15)
	ok(wv.loc_id == "village" and get_tree().get_nodes_in_group("enemies").is_empty(), "селище — безпечна зона без ворогів")
	var npc_ids: Array = []
	for it in wv.interactables:
		if it["kind"] == "npc":
			npc_ids.append(it["id"])
	ok("merchant" in npc_ids and "herbalist" in npc_ids and "elder" in npc_ids, "у селищі НПС: %s" % str(npc_ids))
	ok(wv.exits.size() >= 1 and wv.exit_index_to("forest") >= 0, "вихід із селища веде до лісу")
	var hv: Hud = wv.hud
	for it in wv.interactables:
		if it["id"] == "herbalist":
			wv.player.global_position = it["pos"] + Vector3(1.0, 0, 0)
	await frames(4)
	var near: Dictionary = wv.nearest_interactable()
	ok(not near.is_empty() and near["id"] == "herbalist" and wv.interact_prompt(near).begins_with("Говорити"), "біля травниці з'являється «%s»" % wv.interact_prompt(near))
	wv.interact(near)
	await frames(3)
	ok(hv._dialog.visible and get_tree().paused, "діалог із травницею відкрито")
	hv._close_overlay()
	await frames(2)
	ok(not hv._dialog.visible and not get_tree().paused, "діалог закрито, гра триває")
	hv.open_dialog("merchant")
	await frames(2)
	hv._dialog.shop_requested.emit()
	await frames(3)
	ok(hv._shop.visible, "крамниця відкривається з розмови з торговцем")
	hv._close_overlay()
	await frames(2)
	ok(not hv._shop.visible and not hv._dialog.visible and not get_tree().paused, "після закриття крамниці гра відновлюється")
	hv.open_shop()
	await frames(3)
	ok(hv._shop.visible and get_tree().paused, "крамницю відкрито напряму")
	var gold_s: int = gs.gold
	var stock_n: int = gs.merchant_stock.size()
	ok(gs.buy(0) and gs.merchant_stock.size() == stock_n - 1 and gs.gold < gold_s, "купівля в крамниці працює")
	hv._close_overlay()
	await frames(2)
	hv.open_quests()
	await frames(3)
	ok(hv._quest_screen.visible, "журнал завдань відкривається")
	hv._close_overlay()
	await frames(2)
	# меню героя за портретом
	var port_c: Vector2 = hv._portrait.global_position + hv._portrait.size * 0.5
	hv._touch_down(5, port_c)
	hv._touch_up(5)
	await frames(3)
	ok(hv._submenu != null and hv._submenu.visible, "портрет розкриває меню героя")
	hv.open_inventory(InventoryScreen.TAB_STATS)
	await frames(3)
	ok(hv._inventory.visible, "вкладка «Характеристики» відкривається")
	hv._close_overlay()
	await frames(2)
	await _drop_world(wv)

	print("== 12. Завдання ==")
	gs.new_hero("Тест", "perun", "druzhynnyk")
	ok(gs.quest_available("herbs") and not gs.quest_available("alpha") and not gs.quest_available("wraiths"), "на початку доступні лише перші завдання")
	ok("herbs" in gs.quests_of("herbalist") and "rushnyk" in gs.quests_of("merchant"), "травниця й торговець мають завдання")
	ok(gs.accept_quest("herbs") and gs.quest_state("herbs") == "active" and not gs.accept_quest("herbs"), "завдання про трави взято")
	for i in range(4):
		gs.quest_event("item", "herb", 1)
	ok(gs.quest_progress("herbs") == 4 and gs.quest_state("herbs") == "active", "4 з 5 трав: ще не виконано")
	ok(gs.turn_in_quest("herbs") == "", "до виконання здати не можна")
	gs.quest_event("item", "herb", 1)
	ok(gs.quest_state("herbs") == "ready" and "herbs" in gs.quests_to_turn_in("herbalist"), "5 з 5 трав: можна здавати")
	var g_q: int = gs.gold
	var hp_q: int = gs.hp_potions
	var rew: String = gs.turn_in_quest("herbs")
	ok(rew != "" and gs.quest_state("herbs") == "done" and gs.gold == g_q + 70 and gs.hp_potions == hp_q + 2, "нагорода за трави: «%s»" % rew)
	ok(gs.quest_available("alpha") and gs.quest_available("letter"), "після трав відкрились нові завдання")
	gs.accept_quest("alpha")
	gs.boss_killed("alpha")
	ok(gs.quest_state("alpha") == "ready", "вбивство боса виконує завдання")
	gs.turn_in_quest("alpha")
	gs.accept_quest("wraiths")
	gs.quest_event("kill", "wraith", 5)
	ok(gs.quest_state("wraiths") == "active" and gs.quest_progress("wraiths") == 5, "5 з 6 привидів")
	gs.quest_event("kill", "novice", 3)
	ok(gs.quest_progress("wraiths") == 5, "інші вороги не рахуються")
	gs.quest_event("kill", "wraith", 1)
	ok(gs.quest_state("wraiths") == "ready", "6 привидів: готово")
	gs.accept_quest("rushnyk")
	var pm0: float = gs.price_mult()
	gs.quest_event("item", "rushnyk", 1)
	var perks0: int = gs.perk_points
	gs.turn_in_quest("rushnyk")
	ok(gs.price_mult() < pm0 and gs.perk_points == perks0 + 1, "рушник: знижка в торговця й +1 перк")
	gs.bag = []
	for i in range(GameState.BAG_SIZE):
		gs.add_item(Items.generate(1, rng))
	ok(gs.turn_in_quest("wraiths") == "" and gs.last_error != "" and gs.quest_state("wraiths") == "ready", "повна сумка: нагороду предметом не видати (%s)" % gs.last_error)
	gs.bag = []
	ok(gs.turn_in_quest("wraiths") != "" and gs.quest_state("wraiths") == "done", "після звільнення місця — нагорода видана")

	print("== 13. Локації, мініборси, дороги, будинки ==")
	var avg_lvl := {}
	var boss_hp := {}
	for loc_id in ["forest", "swamp", "ruins"]:
		gs.new_hero("Тест", "perun", "druzhynnyk")
		gs.choose_starter(gs.starter_choices()[0]["node"])
		gs.location = loc_id
		var wl := _make_world(true)
		await frames(15)
		var ens := get_tree().get_nodes_in_group("enemies")
		ok(wl.loc_id == loc_id and ens.size() >= 8, "%s: ворогів %d" % [loc_id, ens.size()])
		var sum := 0.0
		var cnt := 0
		for e3 in ens:
			if not (e3 as Enemy).is_boss:
				sum += float((e3 as Enemy).level)
				cnt += 1
		avg_lvl[loc_id] = sum / maxf(1.0, float(cnt))
		ok(wl.boss != null and is_instance_valid(wl.boss) and wl.boss.is_boss, "%s: є міні-бос «%s»" % [loc_id, wl.boss.boss_name if wl.boss != null else "—"])
		boss_hp[loc_id] = wl.boss.max_hp if wl.boss != null else 0.0
		ok(wl.exits.size() >= 1 and wl.exit_gates.size() == wl.exits.size(), "%s: брами на краях карти (%d)" % [loc_id, wl.exits.size()])
		ok(Locations.get_def(loc_id).has("roads") and not (Locations.get_def(loc_id)["roads"] as Array).is_empty(), "%s: є дороги" % loc_id)
		var lights_ok := true
		for n in wl.find_children("*", "Light3D", true, false):
			if (n as Light3D).shadow_enabled or n is OmniLight3D or n is SpotLight3D:
				lights_ok = false
		ok(lights_ok, "%s: без тіней і точкових джерел світла" % loc_id)
		if loc_id == "forest":
			var chest := {}
			for it in wl.interactables:
				if it["kind"] == "chest":
					chest = it
			ok(not chest.is_empty() and wl.interact_prompt(chest) == "Відкрити скриню", "ліс: у покинутій хаті є скриня")
			gs.accept_quest("rushnyk")
			wl.player.global_position = chest["pos"] + Vector3(1, 0, 0)
			wl.interact(chest)
			await frames(3)
			ok(gs.quest_state("rushnyk") == "ready" and gs.chest_opened("forest_house_chest"), "скриня дає рушник — завдання готове")
			# бос: сильніший, довго відроджується, більша нагорода
			var normal_hp := 0.0
			for e4 in ens:
				if not (e4 as Enemy).is_boss:
					normal_hp = (e4 as Enemy).max_hp
					break
			ok(wl.boss.max_hp > normal_hp * 3.0, "бос значно міцніший (%d проти %d)" % [int(wl.boss.max_hp), int(normal_hp)])
			var loot0 := get_tree().get_nodes_in_group("loot").size()
			gs.quests["herbs"] = {"state": "done", "progress": 0}
			gs.accept_quest("alpha")
			var boss_ref: Enemy = wl.boss
			boss_ref.take_damage(9999999.0, wl.player.global_position, false, 0.0)
			await frames(6)
			ok(boss_ref.dead and not gs.boss_ready("alpha") and gs.boss_seconds_left("alpha") > 300, "бос повалений, відродиться через %d с" % gs.boss_seconds_left("alpha"))
			ok(get_tree().get_nodes_in_group("loot").size() >= loot0 + 4, "бос дав багату здобич (+%d)" % (get_tree().get_nodes_in_group("loot").size() - loot0))
			ok(gs.quest_state("alpha") == "ready", "квест на вовкулаку виконано")
		await _drop_world(wl)
	ok(avg_lvl["forest"] < avg_lvl["swamp"] and avg_lvl["swamp"] < avg_lvl["ruins"], "рівень ворогів росте: ліс %.1f < болото %.1f < руїни %.1f" % [avg_lvl["forest"], avg_lvl["swamp"], avg_lvl["ruins"]])
	ok(boss_hp["forest"] < boss_hp["swamp"] and boss_hp["swamp"] < boss_hp["ruins"], "боси міцнішають від локації до локації (%d, %d, %d)" % [int(boss_hp["forest"]), int(boss_hp["swamp"]), int(boss_hp["ruins"])])
	# мапа кожної локації
	for loc_id in Locations.IDS:
		var def := Locations.get_def(loc_id)
		for ex in def["exits"]:
			ok(Locations.has(str(ex["to"])), "вихід %s → %s існує" % [loc_id, ex["to"]])

	print("== 13б. Нові землі, зграї, печера ==")
	ok(Locations.IDS.size() >= 5 and Locations.has("steppe") and Locations.has("kurgan"), "є Дике поле й Чорні кургани")
	ok(int(Locations.get_def("steppe")["levels"][0]) > int(Locations.get_def("ruins")["levels"][0]) and int(Locations.get_def("kurgan")["levels"][0]) > int(Locations.get_def("steppe")["levels"][0]), "рівень росте після Руїн")
	ok(float(Locations.get_def("forest")["radius"]) >= 50.0, "локації більші (ліс %d)" % int(Locations.get_def("forest")["radius"]))
	gs.new_hero("Тест", "perun", "druzhynnyk")
	gs.choose_starter(gs.starter_choices()[0]["node"])
	gs.level = 8
	gs.location = "forest"
	var wf := _make_world(true)
	await frames(15)
	var leaders := 0
	for e5 in get_tree().get_nodes_in_group("enemies"):
		if (e5 as Enemy).is_leader:
			leaders += 1
	ok(leaders >= 2, "зграї з ватажками (%d)" % leaders)
	var cave_it := {}
	for it in wf.interactables:
		if it["kind"] == "cave":
			cave_it = it
	ok(not cave_it.is_empty() and wf.interact_prompt(cave_it) != "", "у лісі є вхід до печери")
	wf.instant_transition = true
	wf.enter_cave()
	ok(gs.location == "cave" and gs.cave_from == "forest" and gs.cave_level >= 8, "вхід у печеру (рівень %d)" % gs.cave_level)
	await _drop_world(wf)
	var wc := _make_world(true)
	await frames(15)
	ok(wc.is_cave and wc.boss != null and wc.boss.is_cave_boss and wc.boss.level >= gs.cave_level + 3, "у печері Кощій %d рів." % (wc.boss.level if wc.boss != null else 0))
	var kb: Enemy = wc.boss
	kb.take_damage(kb.max_hp * 0.4, wc.player.global_position, false, 0.0)
	await frames(2)
	ok(kb.phase >= 2, "у Кощія змінюється фаза (%d)" % kb.phase)
	kb.take_damage(9999999.0, wc.player.global_position, false, 0.0)
	await frames(6)
	var portal_it := {}
	for it in wc.interactables:
		if it["kind"] == "portal":
			portal_it = it
	ok(kb.dead and not portal_it.is_empty(), "після перемоги з'являється портал")
	wc.instant_transition = true
	wc.interact(portal_it)
	ok(gs.location == "forest", "портал веде назад до лісу")
	await _drop_world(wc)
	gs.save_game()
	print("== 13в. Комірки збереження ==")
	ok(GameState.SLOT_COUNT >= 3, "комірок: %d" % GameState.SLOT_COUNT)
	var cur_slot: int = gs.slot
	ok(not gs.slot_info(cur_slot).is_empty(), "поточна комірка має збереження")
	gs.select_slot(3 if cur_slot != 3 else 2)
	ok(not gs.has_hero, "інша комірка порожня")
	gs.select_slot(cur_slot)
	ok(gs.has_hero and gs.hero_name == "Тест", "повернення до своєї комірки")
	print("== 14. Редактор Древа ==")
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


func _is_filled(v: Variant) -> bool:
	return typeof(v) == TYPE_DICTIONARY and not (v as Dictionary).is_empty()


## Відкриває вузли найкоротшим шляхом від уже відкритих до цілі (BFS за можливими вузлами).
func _unlock_path_to(gs: Node, target: String) -> void:
	for guard in range(120):
		if gs.is_unlocked(target):
			return
		var prev := {}
		var q: Array = []
		for u in gs.unlocked:
			prev[u] = ""
			q.append(u)
		var found := false
		while not q.is_empty() and not found:
			var c: String = q.pop_front()
			for nb in PerkTree.neighbors(c):
				if prev.has(nb):
					continue
				prev[nb] = c
				if nb == target:
					found = true
					break
				q.append(nb)
		if not found:
			return
		var cur := target
		while prev[cur] != "" and not gs.is_unlocked(str(prev[cur])):
			cur = str(prev[cur])
		if not gs.unlock(cur):
			return
