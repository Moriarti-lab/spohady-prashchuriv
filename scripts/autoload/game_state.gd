## Стан героя: рівень, Древо, сумка, спорядження, гривні, зілля, швидкі навички.
## Автозбереження в user://.
extends Node

signal changed
signal leveled_up(new_level: int)

const SAVE_PATH := "user://spohady_save.json"
const SAVE_VERSION := 2
const MAX_LEVEL := 50
const PERKS_PER_LEVEL := 3
const START_PERKS := 3
const DEATH_XP_LOSS := 0.10
const BAG_SIZE := 30
const QUICK_SLOTS := 4
const START_HP_POTIONS := 3
const START_MANA_POTIONS := 2
## Мапа: клітинка 1 м, сітка MAP_GRID×MAP_GRID із центром у (0,0).
const MAP_GRID := 96

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
var explored := PackedByteArray()
var item_seq := 0
## Повідомлення для гравця після оновлення старого збереження (показує світ).
var notice := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure()
	PerkTree.ensure_loaded()
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
	skills_learned = []
	gold = 0
	hp_potions = START_HP_POTIONS
	mana_potions = START_MANA_POTIONS
	bag = []
	equipment = Items.starter(p_class)
	for it in equipment.values():
		it["uid"] = _next_uid()
	quick = ["", "", "", ""]
	explored = PackedByteArray()
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
	if perk_points <= 0:
		return "Немає вільних перків"
	for nb in PerkTree.neighbors(node_id):
		if is_unlocked(nb):
			return ""
	return "Спершу відкрий сусідній вузол"


func unlock(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	perk_points -= 1
	unlocked.append(node_id)
	var d: Dictionary = PerkTree.get_def(node_id)
	if str(d.get("skill", "")) != "" and not (d["skill"] in skills_learned):
		skills_learned.append(d["skill"])
		auto_fill_quick()
	changed.emit()
	save_game()
	return true


## Скільки перків має бути вільно за рівнем і відкритими вузлами.
func expected_perk_points() -> int:
	var total := START_PERKS + PERKS_PER_LEVEL * (level - 1)
	return maxi(0, total - maxi(0, unlocked.size() - 1))


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
	changed.emit()
	return true


func equipped(slot: String) -> Variant:
	return equipment.get(slot, null)


## Одягає предмет із сумки; зняте лягає на його місце.
func equip_from_bag(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var item: Dictionary = bag[index]
	var slot := Items.slot_of(item)
	if slot == "":
		return false
	var old: Variant = equipment.get(slot, null)
	equipment[slot] = item
	if typeof(old) == TYPE_DICTIONARY and not old.is_empty():
		bag[index] = old
	else:
		bag.remove_at(index)
	changed.emit()
	save_game()
	return true


func unequip(slot: String) -> bool:
	var it: Variant = equipment.get(slot, null)
	if typeof(it) != TYPE_DICTIONARY or it.is_empty() or bag.size() >= BAG_SIZE:
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
	changed.emit()
	save_game()
	return v


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

func _ensure_explored() -> void:
	if explored.size() != MAP_GRID * MAP_GRID:
		explored = PackedByteArray()
		explored.resize(MAP_GRID * MAP_GRID)


func map_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)) + MAP_GRID / 2, int(floor(p.y)) + MAP_GRID / 2)


func is_explored(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= MAP_GRID or c.y >= MAP_GRID or explored.size() != MAP_GRID * MAP_GRID:
		return false
	return explored[c.y * MAP_GRID + c.x] != 0


## Позначає круг навколо точки (x, z у метрах) дослідженим. Повертає true, якщо щось змінилось.
func mark_explored(p: Vector2, radius: float) -> bool:
	_ensure_explored()
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
			if explored[i] == 0:
				explored[i] = 1
				changed_any = true
	return changed_any


# ---------- Збереження ----------

func to_dict() -> Dictionary:
	_ensure_explored()
	return {
		"version": SAVE_VERSION, "name": hero_name, "blessing": blessing, "class": hero_class,
		"level": level, "xp": xp, "perk_points": perk_points,
		"unlocked": unlocked, "skills": skills_learned,
		"gold": gold, "hp_potions": hp_potions, "mana_potions": mana_potions,
		"bag": bag, "equipment": equipment, "quick": quick, "item_seq": item_seq,
		"explored": Marshalls.raw_to_base64(explored),
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


func from_dict(d: Dictionary) -> bool:
	if not d.has("name") or not Blessings.DATA.has(str(d.get("blessing", ""))) \
			or not Gear.CLASSES.has(str(d.get("class", ""))):
		return false
	PerkTree.ensure_loaded()
	var version := int(d.get("version", 1))
	hero_name = str(d["name"])
	blessing = str(d["blessing"])
	hero_class = str(d["class"])
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(0, int(d.get("xp", 0)))
	notice = ""
	var start := PerkTree.class_start(hero_class)
	if version < 2:
		# У v0.2 Древо інше: старі вузли не підходять. Скидаємо їх, перки повертаються.
		unlocked = [start]
		if (d.get("unlocked", []) as Array).size() > 1:
			notice = "Древо звитяги стало більшим, тому відкриті вузли скинуто. Усі перки повернено: розподіляй наново."
	else:
		unlocked = PerkTree.sanitize_unlocked(d.get("unlocked", []), start)
		if unlocked.is_empty():
			unlocked = [start]
	perk_points = expected_perk_points()
	skills_learned = []
	for id in unlocked:
		var sk := str(PerkTree.get_def(id).get("skill", ""))
		if sk != "" and Skills.DATA.has(sk) and not (sk in skills_learned):
			skills_learned.append(sk)
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
		for slot in Items.SLOTS:
			var it := _clean_item(eq.get(slot, null))
			if not it.is_empty() and Items.slot_of(it) == slot:
				equipment[slot] = it
	if version < 2 or equipment.is_empty():
		equipment = Items.starter(hero_class)
		for it in equipment.values():
			it["uid"] = _next_uid()
	quick = ["", "", "", ""]
	var q: Variant = d.get("quick", [])
	if typeof(q) == TYPE_ARRAY:
		for i in range(mini(QUICK_SLOTS, q.size())):
			quick[i] = str(q[i])
	auto_fill_quick()
	explored = PackedByteArray()
	if d.has("explored"):
		explored = Marshalls.base64_to_raw(str(d["explored"]))
	_ensure_explored()
	return true


func save_game() -> bool:
	if not has_hero:
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Не вдалося зберегти гру: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return from_dict(parsed)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	has_hero = false
	changed.emit()
