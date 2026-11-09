extends Node
## Кожен базовий предмет / науз / нитка / зілля рендериться без RAW_KEY.

var _fail := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var n := 0
	# All bases at each rarity
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for base_id in Items.BASES.keys():
		for r in range(Items.RARITIES.size()):
			var it: Dictionary = Items.make(str(base_id), 5, r, rng)
			var err := DescFormat.validate_tooltip(it)
			ok(err == "", "gear %s r%d: %s" % [base_id, r, err if err != "" else "ok"])
			n += 1
			# must contain rarity-coloured name pattern
			var bb := DescFormat.item_tooltip(it, {"where": "bag"})
			ok(bb.contains("[b][color="), "has name color %s" % base_id)
			ok(not bb.contains("RAW_KEY:"), "no raw %s" % base_id)
	# Consumables
	for it2 in [Items.make_oblivion_water(1)]:
		ok(DescFormat.validate_tooltip(it2) == "", "oblivion")
		n += 1
	# Nauzi + threads
	for sk in ["iron_wall", "rapid_shot", "power_strike"]:
		if not Skills.DATA.has(sk) and not Skills.has(sk):
			# try common ids
			pass
	var skills_try: Array = []
	for k in Skills.DATA.keys():
		skills_try.append(k)
		if skills_try.size() >= 5:
			break
	for sk2 in skills_try:
		var nauz: Dictionary = Nauzi.make_nauz(str(sk2), 8, 2)
		ok(DescFormat.validate_tooltip(nauz) == "", "nauz %s" % sk2)
		var bb2 := DescFormat.item_tooltip(nauz, {"where": "nauz"})
		ok(bb2.contains("Нитки:"), "nauz sockets %s" % sk2)
		ok(bb2.contains("Вимоги:"), "nauz reqs %s" % sk2)
		n += 1
	for tid in Nauzi.THREADS.keys():
		for col in Nauzi.COLOR_NAMES.keys():
			var th: Dictionary = Nauzi.make_thread(str(tid), str(col), 2)
			ok(DescFormat.validate_tooltip(th) == "", "thread %s %s" % [tid, col])
			n += 1
	# Rarity names match Items.RARITIES
	for i in range(4):
		ok(DescFormat.rarity_name(i) == str(Items.RARITIES[i]["name"]), "rarity name %d" % i)
	# Unmet requirements turn red: low-level hero vs high nauz
	var old_lvl: int = GameState.level
	GameState.level = 1
	if not skills_try.is_empty():
		var hard: Dictionary = Nauzi.make_nauz(str(skills_try[0]), 20, 3)
		var bb3 := DescFormat.item_tooltip(hard, {"where": "nauz"})
		ok(bb3.contains("не вистачає") or bb3.contains(DescFormat.UNMET), "unmet req red")
	GameState.level = old_lvl
	# Shop/loot contexts
	var sword: Dictionary = Items.make("sword", 3, 2, rng)
	ok(DescFormat.item_tooltip(sword, {"where": "shop", "buy": true}).contains("Купити"), "shop hint")
	ok(DescFormat.item_tooltip(sword, {"where": "loot"}).contains("Підібрати"), "loot hint")
	print("ITEM_TOOLTIP_CHECKED ", n)
	if _fail == 0:
		print("ITEM_TOOLTIP_OK")
		get_tree().quit(0)
	else:
		print("ITEM_TOOLTIP_FAIL ", _fail)
		get_tree().quit(1)


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("OK ", msg)
	else:
		print("FAIL ", msg)
		_fail += 1
