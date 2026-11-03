## Запуск: godot --headless --path . res://tests/smoke_test.tscn
## Перевіряє: усі скрипти компілюються, сцени створюються, світ живе кілька сотень кадрів,
## бій, навички, рівні, перки, смерть/відродження, збереження.
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


func _run() -> void:
	print("== 1. Скрипти ==")
	var list: Array = []
	_scripts("res://scripts", list)
	for p in list:
		var s := load(p) as GDScript
		ok(s != null and s.can_instantiate(), p)
	var gs = GameState
	gs.delete_save()

	print("== 2. Формули ==")
	gs.new_hero("Тест", "perun", "druzhynnyk")
	ok(HeroStats.stat_shown("str") >= 5, "Сила ≥ 5 (є %d)" % HeroStats.stat_shown("str"))
	var str1: int = HeroStats.stat_shown("str")
	ok(gs.unlock("s2"), "перк s2 відкрито")
	ok(HeroStats.stat_shown("str") == str1 + 2, "s2 дає +2 Сили")
	ok(not gs.unlock("a3"), "a3 не можна без сусіда")
	ok(gs.perk_points == 3 - 1 - 0, "перків лишилось 2")
	var gained: int = gs.add_xp(50)
	ok(gained == 1 and gs.level == 2 and gs.perk_points == 5, "рівень 2: +3 перки")
	gs.xp = 100
	var lost: int = gs.apply_death_penalty()
	ok(lost == int(round(0.1 * gs.xp_needed())) and gs.xp == 100 - lost, "смерть: −10%% звитяги (%d)" % lost)
	ok(gs.save_game() and gs.load_game(), "збереження/завантаження")

	print("== 3. Сцени ==")
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

	for combo in [["perun", "druzhynnyk"], ["veles", "strilets"], ["stribog", "volkhv"], ["svarog", "druzhynnyk"], ["mokosh", "volkhv"], ["dazhbog", "strilets"]]:
		print("== 4. Світ: %s / %s ==" % combo)
		gs.new_hero("Тест", combo[0], combo[1])
		gs.perk_points = 20
		for n in ["s2", "s3", "a2", "a3", "f2", "f3"]:
			if gs.can_unlock(n):
				gs.unlock(n)
		var w: Node = load("res://scenes/world.tscn").instantiate()
		add_child(w)
		await frames(20)
		var world := w as GameWorld
		ok(world.player != null and world.hud != null, "гравець і HUD створені")
		var enemies := get_tree().get_nodes_in_group("enemies")
		ok(enemies.size() >= 5, "вороги: %d" % enemies.size())
		var p: Player = world.player
		# підставляємо ворога поруч
		var e: Enemy = enemies[0] as Enemy
		e.global_position = p.global_position + Vector3(1.2, 0, 0)
		p.basic_attack()
		await frames(10)
		p.mana = p.mana + 100.0
		p.use_skill(0)
		await frames(10)
		p.use_skill(1)
		await frames(10)
		# бій: гравець атакує 6 секунд
		p.attack_held = true
		for i in range(240):
			p.mana = 99999.0
			await get_tree().physics_frame
		p.attack_held = false
		ok(p.hp > 0 or p.dead, "гравець живий або відроджується")
		# смерть і відродження
		var xp_before: int = gs.xp
		p.take_damage(99999.0, p.global_position + Vector3(1, 0, 0), 0.0)
		await frames(3)
		ok(p.dead, "гравець помер")
		await get_tree().create_timer(3.4).timeout
		ok(not p.dead and p.hp > 0, "гравець відроджений")
		ok(gs.xp <= xp_before, "звитяга не зросла після смерті")
		# рівень
		gs.add_xp(gs.xp_needed())
		await frames(5)
		# відкрити меню та Древо
		world.hud.open_perks()
		await frames(3)
		ok(world.hud._perk_screen.visible and get_tree().paused, "Древо відкрито, гра на паузі")
		world.hud._perk_screen._on_node_selected("s4")
		world.hud._perk_screen._on_unlock()
		await frames(2)
		world.hud._close_overlay()
		await frames(2)
		world.queue_free()
		await frames(3)
		get_tree().paused = false

	gs.delete_save()
	print("== Підсумок: %d перевірок, %d помилок ==" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)
