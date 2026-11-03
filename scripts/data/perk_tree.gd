## Єдине радіальне Древо перків (19 вузлів у пробній версії).
## Клас визначає лише стартовий вузол. Позиції задано в одиничному колі:
## r — відстань від центру (0..1), a — кут у градусах (екранні координати, y вниз).
class_name PerkTree

# Сили: угорі (-90°), Спритність: праворуч-внизу (30°), Віра: ліворуч-внизу (150°)
const NODES := {
	# --- Сила ---
	"s1": {"name": "Міцні руки", "r": 1.0, "a": -90.0, "str": 2, "desc": "Початок шляху сили.", "links": ["s2", "h_sa_out", "h_fs_out"]},
	"s2": {"name": "Дружинна міць", "r": 0.72, "a": -90.0, "str": 2, "links": ["s1", "s3", "s4", "h_sa_in", "h_fs_in"]},
	"s3": {"name": "Могутній удар", "r": 0.45, "a": -90.0, "str": 3, "skill": "power_strike", "key": true, "links": ["s2", "core"]},
	"s4": {"name": "Міцна шкіра", "r": 0.6, "a": -64.0, "str": 1, "hp_pct": 10.0, "desc": "+10% до життя.", "links": ["s2"]},
	# --- Спритність ---
	"a1": {"name": "Влучне око", "r": 1.0, "a": 30.0, "agi": 2, "desc": "Початок шляху спритності.", "links": ["a2", "h_sa_out", "h_af_out"]},
	"a2": {"name": "Легка рука", "r": 0.72, "a": 30.0, "agi": 2, "links": ["a1", "a3", "a4", "h_sa_in", "h_af_in"]},
	"a3": {"name": "Град стріл", "r": 0.45, "a": 30.0, "agi": 3, "skill": "arrow_volley", "key": true, "links": ["a2", "core"]},
	"a4": {"name": "Швидкі ноги", "r": 0.6, "a": 56.0, "agi": 1, "move_pct": 8.0, "desc": "+8% до швидкості руху.", "links": ["a2"]},
	# --- Віра ---
	"f1": {"name": "Щире слово", "r": 1.0, "a": 150.0, "faith": 2, "desc": "Початок шляху віри.", "links": ["f2", "h_af_out", "h_fs_out"]},
	"f2": {"name": "Тиха молитва", "r": 0.72, "a": 150.0, "faith": 2, "links": ["f1", "f3", "f4", "h_af_in", "h_fs_in"]},
	"f3": {"name": "Хвиля стихії", "r": 0.45, "a": 150.0, "faith": 3, "skill": "element_wave", "key": true, "links": ["f2", "core"]},
	"f4": {"name": "Глибока криниця", "r": 0.6, "a": 176.0, "faith": 1, "mana_regen": 1.0, "desc": "+1 до відновлення чару за секунду.", "links": ["f2"]},
	# --- Гібриди між секторами ---
	"h_sa_out": {"name": "Воїнська хватка", "r": 1.0, "a": -30.0, "str": 1, "agi": 1, "links": ["s1", "a1", "h_sa_in"]},
	"h_sa_in": {"name": "Кров і вітер", "r": 0.72, "a": -30.0, "str": 2, "agi": 2, "links": ["s2", "a2", "h_sa_out"]},
	"h_af_out": {"name": "Лісова стежка", "r": 1.0, "a": 90.0, "agi": 1, "faith": 1, "links": ["a1", "f1", "h_af_in"]},
	"h_af_in": {"name": "Подих лісу", "r": 0.72, "a": 90.0, "agi": 2, "faith": 2, "links": ["a2", "f2", "h_af_out"]},
	"h_fs_out": {"name": "Оберіг-щит", "r": 1.0, "a": 210.0, "faith": 1, "str": 1, "links": ["f1", "s1", "h_fs_in"]},
	"h_fs_in": {"name": "Вогонь чаклуна", "r": 0.72, "a": 210.0, "faith": 2, "str": 2, "links": ["f2", "s2", "h_fs_out"]},
	# --- Ядро ---
	"core": {"name": "Серце роду", "r": 0.0, "a": 0.0, "str": 2, "agi": 2, "faith": 2, "dmg_pct": 5.0, "key": true,
		"desc": "+5% до всієї шкоди.", "links": ["s3", "a3", "f3"]},
}

const SECTOR_LABELS := [
	{"text": "Сила", "a": -90.0, "stat": "str"},
	{"text": "Спритність", "a": 30.0, "stat": "agi"},
	{"text": "Віра", "a": 150.0, "stat": "faith"},
]

static func get_def(id: String) -> Dictionary:
	return NODES.get(id, {})

static func unit_pos(id: String) -> Vector2:
	var d: Dictionary = NODES[id]
	var ang: float = deg_to_rad(float(d["a"]))
	return Vector2(cos(ang), sin(ang)) * float(d["r"])

## Усі вузли вважаються сусідніми, якщо хоч одна зі сторін згадує іншу.
static func are_linked(a: String, b: String) -> bool:
	return b in NODES[a]["links"] or a in NODES[b]["links"]

static func neighbors(id: String) -> Array:
	var out: Array = []
	for other in NODES.keys():
		if other != id and are_linked(id, other):
			out.append(other)
	return out

## Короткий опис ефектів вузла українською.
static func effect_text(id: String) -> String:
	var d: Dictionary = NODES[id]
	var parts: Array = []
	for st in ["str", "agi", "faith"]:
		if d.has(st):
			parts.append("+%d %s" % [int(d[st]), Strings.stat_name(st)])
	if d.has("skill"):
		parts.append("Навичка: " + str(Skills.get_def(d["skill"])["name"]))
	if d.has("hp_pct") or d.has("move_pct") or d.has("mana_regen") or d.has("dmg_pct"):
		parts.append(str(d.get("desc", "")))
	return "\n".join(parts)
