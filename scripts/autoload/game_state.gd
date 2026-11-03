## Стан героя: рівень, звитяга, перки. Автозбереження в user://.
extends Node

signal changed
signal leveled_up(new_level: int)

const SAVE_PATH := "user://spohady_save.json"
const SAVE_VERSION := 1
const MAX_LEVEL := 50
const PERKS_PER_LEVEL := 3
const START_PERKS := 3
const DEATH_XP_LOSS := 0.10

var has_hero := false
var hero_name := ""
var blessing := "perun"
var hero_class := "druzhynnyk"
var level := 1
var xp := 0
var perk_points := 0
var unlocked: Array = []
var skills_learned: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure()
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
	unlocked = [Gear.class_def(p_class)["start_node"]]
	skills_learned = []
	has_hero = true
	save_game()
	changed.emit()


# ---------- Звитяга й рівні ----------

func xp_needed(lvl: int = -1) -> int:
	if lvl < 0:
		lvl = level
	return 50 * lvl * lvl


## Додає звитягу. Повертає, скільки нових рівнів отримано.
func add_xp(amount: int) -> int:
	var gained := 0
	xp += amount
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
	if not PerkTree.NODES.has(node_id):
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
	if d.has("skill") and not (d["skill"] in skills_learned):
		skills_learned.append(d["skill"])
	changed.emit()
	save_game()
	return true


## Активні навички на кнопках С1 і С2: спершу вміння благословення (якщо активне),
## далі навички з дерева в порядку вивчення.
func active_skills() -> Array:
	var out: Array = []
	var b: Dictionary = Blessings.get_def(blessing)
	if b.get("skill_kind", "") == "active":
		out.append(b["skill"])
	for s in skills_learned:
		out.append(s)
	return out.slice(0, 2)


# ---------- Збереження ----------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "name": hero_name, "blessing": blessing, "class": hero_class,
		"level": level, "xp": xp, "perk_points": perk_points,
		"unlocked": unlocked, "skills": skills_learned,
	}


func from_dict(d: Dictionary) -> bool:
	if not d.has("name") or not Blessings.DATA.has(str(d.get("blessing", ""))) \
			or not Gear.CLASSES.has(str(d.get("class", ""))):
		return false
	hero_name = str(d["name"])
	blessing = str(d["blessing"])
	hero_class = str(d["class"])
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(0, int(d.get("xp", 0)))
	perk_points = maxi(0, int(d.get("perk_points", 0)))
	unlocked = []
	for id in d.get("unlocked", []):
		if PerkTree.NODES.has(str(id)):
			unlocked.append(str(id))
	if unlocked.is_empty():
		unlocked = [Gear.class_def(hero_class)["start_node"]]
	skills_learned = []
	for s in d.get("skills", []):
		if Skills.DATA.has(str(s)):
			skills_learned.append(str(s))
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
