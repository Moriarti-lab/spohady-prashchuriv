## Регресійний тест (з 0.3.1): справжній шлях нового гравця без скорочень
## (створення героя → бог → клас → «Вирушити в дорогу» → світ із прогрівом → вибір стартового науза).
## У 0.3.0 тут був чорний екран: Древо ставило гру на паузу, і заслона прогріву не зникала.
## Запуск: godot --path . res://tests/flow_test.tscn  (бажано не headless: xvfb-run … --rendering-driver opengl3)
extends Node

var fails := 0


func ok(c: bool, m: String) -> void:
	print(("  ok   " if c else "  FAIL ") + m)
	if not c:
		fails += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# лишаємося живими після зміни сцени
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0, true).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(2))
	print("== Шлях нового гравця ==")
	GameState.has_hero = false
	tree.change_scene_to_file("res://scenes/create_hero.tscn")
	for i in 8:
		await tree.process_frame
	var ch = tree.current_scene
	ok(ch != null and ch.has_method("_on_next"), "відкрито створення героя")
	ch._on_next()
	await tree.process_frame
	ch._on_next()
	await tree.process_frame
	ch._pick_blessing("perun")
	await tree.process_frame
	ch._on_next()
	await tree.process_frame
	ch._pick_class("druzhynnyk")
	await tree.process_frame
	ok(not ch._next.disabled, "кнопка «Вирушити в дорогу» доступна")
	ch._next.pressed.emit()
	var w: Node = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await tree.process_frame
		w = tree.current_scene
		if w != null and w is GameWorld and w.is_warmed:
			break
	ok(w is GameWorld, "відкрито світ")
	ok(w is GameWorld and w.is_warmed, "прогрів завершено")
	await tree.create_timer(2.0, true).timeout
	if w is GameWorld:
		ok(w._fade_rect.modulate.a <= 0.01, "темна заслона зникла (a=%.2f)" % w._fade_rect.modulate.a)
		ok(not w.has_node("WarmUp"), "екран прогріву прибрано")
		ok(w.hud._perk_screen.visible and w.hud._perk_screen._modal.visible, "одразу показано вибір стартового науза")
		var picks: Array = GameState.starter_choices()
		w.hud._perk_screen._on_starter_picked(str(picks[0]["node"]))
		await tree.create_timer(0.3, true).timeout
		ok(not GameState.starter_pending(), "стартовий науз обрано")
		w.hud._close_overlay()
		await tree.create_timer(0.3, true).timeout
		ok(not tree.paused, "гра знята з паузи")
	ok(GameState.load_guard != null and not GameState.load_guard._shown, "запобіжник не спрацював")
	# запобіжник показує повідомлення замість чорного екрана
	GameState.load_guard.show_failure("Перевірка запобіжника.")
	await tree.process_frame
	var found := false
	for c in tree.root.get_children():
		if c is CanvasLayer and c.layer == 120:
			found = true
	ok(found, "запобіжник показує повідомлення про помилку")
	if DisplayServer.get_name() != "headless":
		await tree.create_timer(0.2, true).timeout
	print("== Підсумок шляху: %d помилок ==" % fails)
	tree.quit(0 if fails == 0 else 1)
