## Стан героя: рівень, Древо, сумка, спорядження, гривні, зілля, швидкі навички.
## Автозбереження в user://.
extends Node

signal changed
signal leveled_up(new_level: int)
signal quest_changed
signal location_changed

## Старе (до v0.4) єдине збереження: при першому запуску переноситься в комірку 1.
const SAVE_PATH := "user://spohady_save.json"
const SLOT_COUNT := 3
const SETTINGS_PATH := "user://settings.cfg"
## Поточна комірка збереження (1..SLOT_COUNT).
var slot := 1
const SAVE_VERSION := 3
const MAX_LEVEL := 50
const PERKS_PER_LEVEL := 3
const START_PERKS := 3
const DEATH_XP_LOSS := 0.10
const BAG_SIZE := 48
const QUICK_SLOTS := 4
const START_HP_POTIONS := 3
const START_MANA_POTIONS := 2
## Мапа: клітинка 1 м, сітка MAP_GRID×MAP_GRID із центром у (0,0).
const MAP_GRID := 96
## Торговець: нова пропозиція раз на стільки секунд; запас — стільки предметів.
const STOCK_SIZE := 10
const STOCK_REFRESH_SECONDS := 300
## Міні-боси оживають через стільки секунд (час світовий, зберігається).
const BOSS_RESPAWN_SECONDS := 600
const HP_POTION_PRICE := 25
const MANA_POTION_PRICE := 30

var has_hero := false
var hero_name := ""
var blessing := "perun"
var hero_class := "druzhynnyk"
var level := 1
var xp := 0
var perk_points := 0
var unlocked: Array = []
var skills_learned: Array = []
var gold := 0
var hp_potions := 0
var mana_potions := 0
var bag: Array = []
var equipment: Dictionary = {}
var quick: Array = ["", "", "", ""]
## Досліджена мапа для кожної локації: {id: PackedByteArray}.
var explored_by: Dictionary = {}
var item_seq := 0
## Вузол стартової навички з Древа. Порожньо — гравець ще не обирав.
var starter_node := ""
var location := "village"
## Звідки прийшов у цю локацію (id локації; порожньо — зайшов із меню або після смерті).
var arrive_from := ""
## Печера: з якої локації зайшли, її рівень і де на поверхні був вхід.
var cave_from := ""
var cave_level := 1
var cave_pos := Vector2.ZERO
var cave_pos_loc := ""
## Завдання: {id: {state: "active"|"ready"|"done", progress: N}}.
var quests: Dictionary = {}
var quest_items: Dictionary = {}
var opened_chests: Array = []
var boss_killed_at: Dictionary = {}
var bonus_perks := 0
var merchant_stock: Array = []
var merchant_refresh_at := 0
var last_error := ""
## Повідомлення для гравця після оновлення старого збереження (показує світ).
var notice := ""


var load_guard: LoadGuard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LoadGuard.install()
	load_guard = LoadGuard.new()
	load_guard.name = "LoadGuard"
	add_child(load_guard)
	InputSetup.ensure()
	PerkTree.ensure_loaded()
	migrate_old_save()
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		slot = clampi(int(cf.get_value("save", "slot", 1)), 1, SLOT_COUNT)
	has_hero = load_game()


func _notification(what: int) -> void:
	# Android: гра згортається або закривається: зберігаємо.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if has_hero:
			save_game()


# ---------- Створення героя ----------

func new_hero(p_name: String, p_blessing: String, p_class: String) -> void:
	hero_name = p_name.strip_edges()
	if hero_name == "":
		hero_name = "Мандрівник"
	blessing = p_blessing
	hero_class = p_class
	level = 1
	xp = 0
	perk_points = START_PERKS
	unlocked = [PerkTree.class_start(p_class)]
	starter_node = ""
	location = Locations.START
	arrive_from = ""
	quests = {}
	quest_items = {}
	opened_chests = []
	boss_killed_at = {}
	bonus_perks = 0
	merchant_stock = []
	merchant_refresh_at = 0
	skills_learned = []
	gold = 0
	hp_potions = START_HP_POTIONS
	mana_potions = START_MANA_POTIONS
	bag = []
	equipment = Items.starter(p_class)
	for it in equipment.values():
		it["uid"] = _next_uid()
	quick = ["", "", "", ""]
	explored_by = {}
	notice = ""
	auto_fill_quick()
	has_hero = true
	save_game()
	changed.emit()


func _next_uid() -> int:
	item_seq += 1
	return item_seq


# ---------- Звитяга й рівні ----------

func xp_needed(lvl: int = -1) -> int:
	if lvl < 0:
		lvl = level
	return 50 * lvl * lvl


## Додає звитягу (з урахуванням бонусу Древа). Повертає, скільки нових рівнів отримано.
func add_xp(amount: int) -> int:
	var gained := 0
	xp += int(round(float(amount) * HeroStats.xp_mult()))
	while level < MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		perk_points += PERKS_PER_LEVEL
		gained += 1
		leveled_up.emit(level)
		Sound.play("sfx_levelup", 0.0, 0.0)
	if level >= MAX_LEVEL:
		xp = mini(xp, xp_needed() - 1)
	changed.emit()
	if gained > 0:
		save_game()
	return gained


## Смерть: −10% звитяги поточного рівня (від шкали рівня), але не нижче нуля.
## Рівень не падає, гривні й предмети не губляться. Повертає втрачене.
func apply_death_penalty() -> int:
	var lost := mini(xp, int(round(DEATH_XP_LOSS * xp_needed())))
	xp -= lost
	changed.emit()
	save_game()
	return lost


# ---------- Перки ----------

func is_unlocked(node_id: String) -> bool:
	return node_id in unlocked


func can_unlock(node_id: String) -> bool:
	return unlock_block_reason(node_id) == ""


## Порожній рядок, якщо вузол можна відкрити; інакше причина українською.
func unlock_block_reason(node_id: String) -> String:
	if not PerkTree.has_node(node_id):
		return "Невідомий вузол"
	if is_unlocked(node_id):
		return "Уже відкрито"
	if starter_pending():
		return "Спершу обери стартову навичку"
	if perk_points <= 0:
		return "Немає вільних перків"
	var is_starter := bool(PerkTree.get_def(node_id).get("starter", false))
	for nb in PerkTree.neighbors(node_id):
		if not is_unlocked(nb):
			continue
		# До інших стартових навичок не можна дійти просто зі стартового вузла: потрібен шлях Древом.
		if is_starter and PerkTree.is_class_start(nb):
			continue
		return ""
	if is_starter:
		return "Інші стартові навички відкриваються лише шляхом через Древо"
	return "Спершу відкрий сусідній вузол"


func unlock(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	perk_points -= 1
	unlocked.append(node_id)
	_learn_node_skill(node_id)
	changed.emit()
	save_game()
	return true


func _learn_node_skill(node_id: String) -> void:
	var d: Dictionary = PerkTree.get_def(node_id)
	if str(d.get("skill", "")) != "" and not (d["skill"] in skills_learned):
		skills_learned.append(d["skill"])
		auto_fill_quick()


## Герой ще не обрав стартову навичку: при першому вході у світ показується вибір.
func starter_pending() -> bool:
	return has_hero and starter_node == ""


## Три стартові навички класу героя: вузли Древа {node_id, skill}.
func starter_choices() -> Array:
	var out: Array = []
	for nid in PerkTree.nodes():
		var d: Dictionary = PerkTree.get_def(nid)
		if bool(d.get("starter", false)) and str(d.get("skill", "")) in Gear.STARTER_SKILLS.get(hero_class, []) \
				and PerkTree.neighbors(nid).has(PerkTree.class_start(hero_class)):
			out.append({"node": nid, "skill": str(d["skill"])})
	out.sort_custom(func(a, b): return Gear.STARTER_SKILLS[hero_class].find(a["skill"]) < Gear.STARTER_SKILLS[hero_class].find(b["skill"]))
	return out


## Обирає одну зі стартових навичок безкоштовно (без перка).
func choose_starter(node_id: String) -> bool:
	if starter_node != "":
		return false
	var ok := false
	for c in starter_choices():
		if c["node"] == node_id:
			ok = true
	if not ok:
		return false
	starter_node = node_id
	if not (node_id in unlocked):
		unlocked.append(node_id)
	_learn_node_skill(node_id)
	perk_points = expected_perk_points()
	changed.emit()
	save_game()
	return true


## Скільки перків має бути вільно за рівнем, нагородами й відкритими вузлами.
func expected_perk_points() -> int:
	var total := START_PERKS + PERKS_PER_LEVEL * (level - 1) + bonus_perks
	var spent := maxi(0, unlocked.size() - 1 - (1 if starter_node != "" else 0))
	return maxi(0, total - spent)


# ---------- Навички ----------

## Усі вивчені активні навички: вміння благословення (якщо активне) і навички з Древа.
func learned_skills() -> Array:
	var out: Array = []
	var b: Dictionary = Blessings.get_def(blessing)
	if b.get("skill_kind", "") == "active":
		out.append(b["skill"])
	for s in skills_learned:
		if not (s in out):
			out.append(s)
	return out


## Розкладає нові навички по вільних швидких слотах і прибирає ті, що більше не вивчені.
func auto_fill_quick() -> void:
	var learned := learned_skills()
	while quick.size() < QUICK_SLOTS:
		quick.append("")
	for i in range(QUICK_SLOTS):
		if quick[i] != "" and not (quick[i] in learned):
			quick[i] = ""
	for s in learned:
		if not (s in quick):
			var idx := quick.find("")
			if idx >= 0 and idx < QUICK_SLOTS:
				quick[idx] = s


## Ставить навичку (або порожньо) у швидкий слот. Якщо вона вже в іншому слоті, вони міняються місцями.
func set_quick(slot: int, skill_id: String) -> void:
	if slot < 0 or slot >= QUICK_SLOTS:
		return
	if skill_id != "" and not (skill_id in learned_skills()):
		return
	var other := quick.find(skill_id) if skill_id != "" else -1
	if other >= 0 and other != slot:
		quick[other] = quick[slot]
	quick[slot] = skill_id
	changed.emit()
	save_game()


func quick_skill(slot: int) -> String:
	return str(quick[slot]) if slot >= 0 and slot < quick.size() else ""


# ---------- Сумка й спорядження ----------

func bag_free() -> int:
	return BAG_SIZE - bag.size()


## Кладе предмет у сумку. false — сумка повна.
func add_item(item: Dictionary) -> bool:
	if bag.size() >= BAG_SIZE:
		return false
	if int(item.get("uid", 0)) == 0:
		item["uid"] = _next_uid()
	bag.append(item)
	Sound.play("sfx_coins", -3.0)
	changed.emit()
	return true


func equipped(slot: String) -> Variant:
	return equipment.get(slot, null)


## Слот, куди предмет піде за замовчуванням (або pref, якщо він дозволений).
func target_slot(item: Dictionary, pref: String = "") -> String:
	var slots := Items.slots_for(item)
	if slots.is_empty():
		return ""
	if pref != "" and pref in slots:
		return pref
	if Items.type_of(item) == "ring":
		for sl in ["ring1", "ring2"]:
			if not _slot_filled(sl):
				return sl
		return "ring1"
	if Items.type_of(item) == "hand1":
		# одноручну зброю кладемо в праву руку; якщо там дворучна, вона замінюється
		return "main"
	return str(slots[0])


func _slot_filled(slot: String) -> bool:
	var it: Variant = equipment.get(slot, null)
	return typeof(it) == TYPE_DICTIONARY and not it.is_empty()


## Які предмети буде знято, якщо одягнути item у slot.
func displaced_by(item: Dictionary, slot: String) -> Array:
	var out: Array = []
	if _slot_filled(slot):
		out.append(equipment[slot])
	if Items.type_of(item) == "hand2" and slot == "main" and _slot_filled("off"):
		out.append(equipment["off"])
	if slot == "off" and Items.is_two_handed(equipment.get("main", null)):
		out.append(equipment["main"])
	return out


## Одягає предмет із сумки. Зняте повертається в сумку. Дворучна зброя займає обидві руки.
func equip_from_bag(index: int, pref_slot: String = "") -> bool:
	last_error = ""
	if index < 0 or index >= bag.size():
		return false
	var item: Dictionary = bag[index]
	var slot := target_slot(item, pref_slot)
	if slot == "":
		last_error = "Цей предмет не одягається"
		return false
	var displaced := displaced_by(item, slot)
	if bag.size() - 1 + displaced.size() > BAG_SIZE:
		last_error = "Сумка повна: немає місця для знятого"
		return false
	bag.remove_at(index)
	for d in displaced:
		for sl in Items.SLOTS:
			if equipment.get(sl, null) == d:
				equipment[sl] = null
		bag.append(d)
	equipment[slot] = item
	changed.emit()
	save_game()
	return true


func unequip(slot: String) -> bool:
	last_error = ""
	var it: Variant = equipment.get(slot, null)
	if typeof(it) != TYPE_DICTIONARY or it.is_empty():
		return false
	if bag.size() >= BAG_SIZE:
		last_error = "Сумка повна"
		return false
	bag.append(it)
	equipment[slot] = null
	changed.emit()
	save_game()
	return true


## Продає предмет із сумки за гривні. Повертає виручку (0 — не вийшло).
func sell(index: int) -> int:
	if index < 0 or index >= bag.size():
		return 0
	var v := Items.sell_value(bag[index])
	bag.remove_at(index)
	gold += v
	Sound.play("sfx_coins", -3.0)
	changed.emit()
	save_game()
	return v


# ---------- Торгівля ----------

func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Знижка торговця після виконаного завдання про рушник.
func price_mult() -> float:
	return 0.9 if quest_state("rushnyk") == "done" else 1.0


func price_of(item: Dictionary) -> int:
	return maxi(1, int(round(float(Items.buy_value(item)) * price_mult())))


func potion_price(kind: String) -> int:
	return maxi(1, int(round(float(HP_POTION_PRICE if kind == "hp" else MANA_POTION_PRICE) * price_mult())))


## Оновлює асортимент торговця, коли минув час (або якщо його ще немає). Повертає true, якщо оновлено.
func refresh_stock(force: bool = false) -> bool:
	var now := _now()
	if not force and not merchant_stock.is_empty() and now < merchant_refresh_at:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = now
	merchant_stock = []
	var types := ["hand1", "hand2", "shield", "head", "hands", "body", "feet", "ring", "amulet", "hand1", "body"]
	for i in range(STOCK_SIZE):
		var t: String = types[i % types.size()]
		var ilvl := maxi(1, level + rng.randi_range(0, 2))
		var rar := 0
		var x := rng.randf()
		if x > 0.93:
			rar = 2
		elif x > 0.60:
			rar = 1
		var it := Items.generate(ilvl, rng, t, rar)
		it["uid"] = _next_uid()
		merchant_stock.append(it)
	merchant_refresh_at = now + STOCK_REFRESH_SECONDS
	changed.emit()
	save_game()
	return true


func stock_seconds_left() -> int:
	return maxi(0, merchant_refresh_at - _now())


## Купує предмет зі складу торговця. false — немає гривень або місця (див. last_error).
func buy(index: int) -> bool:
	last_error = ""
	if index < 0 or index >= merchant_stock.size():
		return false
	var item: Dictionary = merchant_stock[index]
	var price := price_of(item)
	if gold < price:
		last_error = "Не вистачає гривень"
		return false
	if bag.size() >= BAG_SIZE:
		last_error = "Сумка повна"
		return false
	gold -= price
	merchant_stock.remove_at(index)
	bag.append(item)
	changed.emit()
	save_game()
	return true


func buy_potion(kind: String) -> bool:
	last_error = ""
	var price := potion_price(kind)
	if gold < price:
		last_error = "Не вистачає гривень"
		return false
	gold -= price
	add_potion(kind, 1)
	Sound.play("sfx_coins", -3.0)
	save_game()
	return true


func add_gold(n: int) -> void:
	gold += maxi(0, n)
	changed.emit()


## Зменшує запас зілля на одиницю. kind: "hp" або "mana".
func take_potion(kind: String) -> bool:
	if kind == "hp" and hp_potions > 0:
		hp_potions -= 1
	elif kind == "mana" and mana_potions > 0:
		mana_potions -= 1
	else:
		return false
	changed.emit()
	return true


func add_potion(kind: String, n: int = 1) -> void:
	if kind == "hp":
		hp_potions += n
	else:
		mana_potions += n
	changed.emit()


# ---------- Мапа ----------

func _explored_of(loc: String) -> PackedByteArray:
	var a: Variant = explored_by.get(loc, null)
	if typeof(a) != TYPE_PACKED_BYTE_ARRAY or (a as PackedByteArray).size() != MAP_GRID * MAP_GRID:
		var na := PackedByteArray()
		na.resize(MAP_GRID * MAP_GRID)
		explored_by[loc] = na
		return na
	return a


## Відкриті клітинки поточної локації (MAP_GRID × MAP_GRID, 1 — відкрито).
func explored_cells() -> PackedByteArray:
	return _explored_of(location)


func map_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)) + MAP_GRID / 2, int(floor(p.y)) + MAP_GRID / 2)


func is_explored(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= MAP_GRID or c.y >= MAP_GRID:
		return false
	return _explored_of(location)[c.y * MAP_GRID + c.x] != 0


## Позначає круг навколо точки (x, z у метрах) дослідженим. Повертає true, якщо щось змінилось.
func mark_explored(p: Vector2, radius: float) -> bool:
	var arr := _explored_of(location)
	var c := map_cell(p)
	var r := int(ceil(radius))
	var changed_any := false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or y < 0 or x >= MAP_GRID or y >= MAP_GRID:
				continue
			var i := y * MAP_GRID + x
			if arr[i] == 0:
				arr[i] = 1
				changed_any = true
	if changed_any:
		explored_by[location] = arr
	return changed_any


# ---------- Локації ----------

func change_location(id: String, from_loc: String = "") -> void:
	if not Locations.has(id):
		return
	location = id
	arrive_from = from_loc
	location_changed.emit()
	save_game()


# ---------- Завдання ----------

func quest_state(id: String) -> String:
	return str(quests.get(id, {}).get("state", ""))


func quest_progress(id: String) -> int:
	var q: Dictionary = quests.get(id, {})
	if q.is_empty():
		return 0
	var d: Dictionary = Quests.get_def(id)
	if str(d.get("kind", "")) == "collect":
		return mini(int(d["need"]), int(quest_items.get(str(d["item"]), 0)))
	return mini(int(d["need"]), int(q.get("progress", 0)))


## Квест можна взяти в giver: ще не взятий, а попередній (requires) виконано.
func quest_available(id: String) -> bool:
	var d: Dictionary = Quests.get_def(id)
	if d.is_empty() or quests.has(id):
		return false
	var req := str(d.get("requires", ""))
	return req == "" or quest_state(req) == "done"


func quests_of(giver: String) -> Array:
	var out: Array = []
	for id in Quests.ORDER:
		if str(Quests.DATA[id]["giver"]) == giver and quest_available(id):
			out.append(id)
	return out


func quests_to_turn_in(npc: String) -> Array:
	var out: Array = []
	for id in Quests.ORDER:
		if str(Quests.DATA[id]["turn_in"]) == npc and quest_state(id) == "ready":
			out.append(id)
	return out


func quests_active_for(npc: String) -> Array:
	var out: Array = []
	for id in Quests.ORDER:
		if str(Quests.DATA[id]["turn_in"]) == npc and quest_state(id) == "active":
			out.append(id)
	return out


func active_quests() -> Array:
	var out: Array = []
	for id in Quests.ORDER:
		var st := quest_state(id)
		if st == "active" or st == "ready":
			out.append(id)
	return out


func accept_quest(id: String) -> bool:
	if not quest_available(id):
		return false
	quests[id] = {"state": "active", "progress": 0}
	_check_quest_ready(id)
	quest_changed.emit()
	changed.emit()
	save_game()
	return true


func _check_quest_ready(id: String) -> void:
	var q: Dictionary = quests.get(id, {})
	if q.is_empty() or str(q.get("state", "")) != "active":
		return
	if quest_progress(id) >= int(Quests.get_def(id)["need"]):
		q["state"] = "ready"


## Подія гри для завдань. kind: "kill" (id — вид ворога), "boss" (id — id боса), "item" (id — квестовий предмет).
func quest_event(kind: String, id: String, n: int = 1) -> void:
	if kind == "item":
		quest_items[id] = int(quest_items.get(id, 0)) + n
	for qid in quests.keys():
		var q: Dictionary = quests[qid]
		if str(q.get("state", "")) != "active":
			continue
		var d: Dictionary = Quests.get_def(str(qid))
		match str(d["kind"]):
			"kill":
				if kind == "kill" and str(d["enemy"]) == id:
					q["progress"] = int(q.get("progress", 0)) + n
			"kill_boss":
				if kind == "boss" and str(d["boss"]) == id:
					q["progress"] = int(q.get("progress", 0)) + n
		_check_quest_ready(str(qid))
	quest_changed.emit()
	changed.emit()


## Здає завдання й видає нагороду. Повертає текст нагороди (порожньо — не вдалося, див. last_error).
func turn_in_quest(id: String) -> String:
	last_error = ""
	if quest_state(id) != "ready":
		return ""
	var d: Dictionary = Quests.get_def(id)
	var r: Dictionary = d["reward"]
	var reward_item: Dictionary = {}
	if r.has("item"):
		if bag.size() >= BAG_SIZE:
			last_error = "Звільни місце в сумці для нагороди"
			return ""
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		reward_item = Items.generate(level + int(r["item"].get("ilvl_add", 0)), rng, str(r["item"].get("type", "")), int(r["item"].get("rarity", 2)))
		reward_item["uid"] = _next_uid()
		bag.append(reward_item)
	if str(d["kind"]) == "collect":
		quest_items[str(d["item"])] = maxi(0, int(quest_items.get(str(d["item"]), 0)) - int(d["need"]))
	quests[id]["state"] = "done"
	gold += int(r.get("gold", 0))
	hp_potions += int(r.get("hp_potions", 0))
	mana_potions += int(r.get("mana_potions", 0))
	bonus_perks += int(r.get("perk_points", 0))
	perk_points = expected_perk_points()
	var text := Quests.reward_text(id)
	if not reward_item.is_empty():
		text += " — " + str(reward_item["name"])
	if int(r.get("xp", 0)) > 0:
		add_xp(int(r["xp"]))
	quest_changed.emit()
	changed.emit()
	save_game()
	return text


func chest_opened(id: String) -> bool:
	return id in opened_chests


func mark_chest(id: String) -> void:
	if not (id in opened_chests):
		opened_chests.append(id)
		save_game()


func boss_ready(id: String) -> bool:
	return _now() - int(boss_killed_at.get(id, 0)) >= BOSS_RESPAWN_SECONDS or not boss_killed_at.has(id)


func boss_killed(id: String) -> void:
	boss_killed_at[id] = _now()
	quest_event("boss", id)
	save_game()


func boss_seconds_left(id: String) -> int:
	return maxi(0, BOSS_RESPAWN_SECONDS - (_now() - int(boss_killed_at.get(id, 0))))


# ---------- Збереження ----------

func to_dict() -> Dictionary:
	var ex := {}
	for loc in explored_by:
		ex[loc] = Marshalls.raw_to_base64(_explored_of(str(loc)))
	return {
		"version": SAVE_VERSION, "name": hero_name, "blessing": blessing, "class": hero_class,
		"level": level, "xp": xp, "perk_points": perk_points,
		"unlocked": unlocked, "skills": skills_learned, "starter_node": starter_node,
		"gold": gold, "hp_potions": hp_potions, "mana_potions": mana_potions,
		"bag": bag, "equipment": equipment, "quick": quick, "item_seq": item_seq,
		"explored": ex, "location": location,
		"cave_from": cave_from, "cave_level": cave_level,
		"quests": quests, "quest_items": quest_items, "opened_chests": opened_chests,
		"boss_killed_at": boss_killed_at, "bonus_perks": bonus_perks,
		"merchant_stock": merchant_stock, "merchant_refresh_at": merchant_refresh_at,
	}


func _clean_item(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var base := str(v.get("base", ""))
	if not Items.BASES.has(base):
		return {}
	var stats := {}
	var raw: Variant = v.get("stats", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			stats[str(k)] = float(raw[k])
	return {"uid": int(v.get("uid", 0)), "base": base, "rarity": clampi(int(v.get("rarity", 0)), 0, Items.RARITIES.size() - 1),
		"ilvl": maxi(1, int(v.get("ilvl", 1))), "name": str(v.get("name", Items.BASES[base]["name"])), "stats": stats}


## Старі ключі слотів (v0.2) -> нові.
const OLD_SLOTS := {"weapon": "main", "armor": "body", "offhand": "off", "ring": "ring1"}


func from_dict(d: Dictionary) -> bool:
	if not d.has("name") or not Blessings.DATA.has(str(d.get("blessing", ""))) \
			or not Gear.CLASSES.has(str(d.get("class", ""))):
		return false
	PerkTree.ensure_loaded()
	HeroStats.invalidate()
	var version := int(d.get("version", 1))
	hero_name = str(d["name"])
	blessing = str(d["blessing"])
	hero_class = str(d["class"])
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(0, int(d.get("xp", 0)))
	notice = ""
	var start := PerkTree.class_start(hero_class)
	bonus_perks = 0
	starter_node = ""
	if version < 3:
		# У v0.3 Древо інше (понад 300 вузлів і вибір стартової навички): старі вузли не підходять.
		unlocked = [start]
		skills_learned = []
		if (d.get("unlocked", []) as Array).size() > 1 or version == 2:
			notice = "Древо звитяги стало значно більшим, тому відкриті вузли скинуто. Усі перки повернено: обери стартову навичку й розподіляй наново."
	else:
		unlocked = PerkTree.sanitize_unlocked(d.get("unlocked", []), start)
		if unlocked.is_empty():
			unlocked = [start]
		starter_node = str(d.get("starter_node", ""))
		if starter_node != "" and not (starter_node in unlocked):
			starter_node = ""
		bonus_perks = maxi(0, int(d.get("bonus_perks", 0)))
	skills_learned = []
	for id in unlocked:
		var sk := str(PerkTree.get_def(id).get("skill", ""))
		if sk != "" and Skills.DATA.has(sk) and not (sk in skills_learned):
			skills_learned.append(sk)
	perk_points = expected_perk_points()
	gold = maxi(0, int(d.get("gold", 0)))
	hp_potions = maxi(0, int(d.get("hp_potions", START_HP_POTIONS if version < 2 else 0)))
	mana_potions = maxi(0, int(d.get("mana_potions", START_MANA_POTIONS if version < 2 else 0)))
	item_seq = maxi(0, int(d.get("item_seq", 0)))
	bag = []
	for v in d.get("bag", []):
		var it := _clean_item(v)
		if not it.is_empty() and bag.size() < BAG_SIZE:
			bag.append(it)
	equipment = {}
	var eq: Variant = d.get("equipment", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for key in eq:
			var slot := str(OLD_SLOTS.get(str(key), str(key))) if version < 3 else str(key)
			var it2 := _clean_item(eq[key])
			if it2.is_empty() or not (slot in Items.SLOTS):
				continue
			if Items.can_equip_slot(slot, it2) and not equipment.has(slot):
				equipment[slot] = it2
			elif bag.size() < BAG_SIZE:
				bag.append(it2)
	# дворучна зброя не може стояти разом зі щитом
	if Items.is_two_handed(equipment.get("main", null)) and equipment.get("off", null) != null:
		if bag.size() < BAG_SIZE:
			bag.append(equipment["off"])
		equipment.erase("off")
	if equipment.is_empty() and bag.is_empty():
		equipment = Items.starter(hero_class)
		for it3 in equipment.values():
			it3["uid"] = _next_uid()
	quick = ["", "", "", ""]
	var q: Variant = d.get("quick", [])
	if typeof(q) == TYPE_ARRAY:
		for i in range(mini(QUICK_SLOTS, q.size())):
			quick[i] = str(q[i])
	auto_fill_quick()
	explored_by = {}
	location = Locations.START
	arrive_from = ""
	quests = {}
	quest_items = {}
	opened_chests = []
	boss_killed_at = {}
	merchant_stock = []
	merchant_refresh_at = 0
	if version >= 3:
		var loc := str(d.get("location", Locations.START))
		location = loc if Locations.has(loc) else Locations.START
		cave_from = str(d.get("cave_from", ""))
		cave_level = maxi(1, int(d.get("cave_level", 1)))
		if location == "cave" and not Locations.has(cave_from):
			location = Locations.START
		var exd: Variant = d.get("explored", {})
		if typeof(exd) == TYPE_DICTIONARY:
			for k in exd:
				if Locations.has(str(k)):
					var raw := Marshalls.base64_to_raw(str(exd[k]))
					if raw.size() == MAP_GRID * MAP_GRID:
						explored_by[str(k)] = raw
		var qd: Variant = d.get("quests", {})
		if typeof(qd) == TYPE_DICTIONARY:
			for k in qd:
				if Quests.DATA.has(str(k)) and typeof(qd[k]) == TYPE_DICTIONARY:
					var st := str(qd[k].get("state", "active"))
					if st in ["active", "ready", "done"]:
						quests[str(k)] = {"state": st, "progress": int(qd[k].get("progress", 0))}
		var qi: Variant = d.get("quest_items", {})
		if typeof(qi) == TYPE_DICTIONARY:
			for k in qi:
				if Quests.ITEMS.has(str(k)):
					quest_items[str(k)] = maxi(0, int(qi[k]))
		var oc: Variant = d.get("opened_chests", [])
		if typeof(oc) == TYPE_ARRAY:
			for c in oc:
				opened_chests.append(str(c))
		var bk: Variant = d.get("boss_killed_at", {})
		if typeof(bk) == TYPE_DICTIONARY:
			for k in bk:
				boss_killed_at[str(k)] = int(bk[k])
		var ms: Variant = d.get("merchant_stock", [])
		if typeof(ms) == TYPE_ARRAY:
			for v in ms:
				var mi := _clean_item(v)
				if not mi.is_empty():
					merchant_stock.append(mi)
		merchant_refresh_at = int(d.get("merchant_refresh_at", 0))
	return true


# ---------- Комірки збереження ----------

static func slot_path(i: int) -> String:
	return "user://spohady_slot%d.json" % i


func save_path() -> String:
	return slot_path(slot)


## Старе збереження (одне на гру) стає коміркою 1.
func migrate_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(slot_path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(slot_path(1)))


## Короткі відомості про комірку для екрана вибору: {} — порожня.
func slot_info(i: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(i)):
		return {}
	var f := FileAccess.open(slot_path(i), FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("name"):
		return {}
	var loc := str(d.get("location", Locations.START))
	return {"name": str(d["name"]), "class": str(d.get("class", "")), "level": int(d.get("level", 1)),
		"location": Locations.get_def(loc).get("name", "") if Locations.has(loc) else ""}


## Обирає комірку: завантажує героя з неї (або порожньо — для нової гри).
func select_slot(i: int) -> void:
	slot = clampi(i, 1, SLOT_COUNT)
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("save", "slot", slot)
	cf.save(SETTINGS_PATH)
	has_hero = load_game()
	changed.emit()


func delete_slot(i: int) -> void:
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(i)))
	if i == slot:
		has_hero = false
		changed.emit()


func save_game() -> bool:
	if not has_hero:
		return false
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Не вдалося зберегти гру: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path()):
		return false
	var f := FileAccess.open(save_path(), FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return from_dict(parsed)


func delete_save() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
	has_hero = false
	changed.emit()


## Перехід у світ із запобіжником: якщо світ не з'явиться, гравець побачить повідомлення, а не чорний екран.
func go_to_world() -> void:
	load_guard.arm()
	var err := get_tree().change_scene_to_file("res://scenes/world.tscn")
	if err != OK:
		load_guard.show_failure("Не вдалося відкрити сцену світу (код %d)." % err)
