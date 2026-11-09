## GDScript-порт G з generate_perk_tree_v7.py.
class_name TreeGenV7Core
extends RefCounted

const SCALE := 10
const MAX_DEG := 6
const MIN_DIST := 18.0
const STEP := 26.0
const START_ID := {
	"str": "s_root",
	"agi": "a_root",
	"faith": "f_root"
}
const BR := ["str", "agi", "faith"]
const CLASS_STARTS := {
	"druzhynnyk": "s_root",
	"strilets": "a_root",
	"volkhv": "f_root"
}
const REGIONS := [
	{
		"id": "str",
		"name": "Сила",
		"color": "#C62828"
	},
	{
		"id": "agi",
		"name": "Спритність",
		"color": "#2E7D32"
	},
	{
		"id": "faith",
		"name": "Віра",
		"color": "#F9A825"
	}
]
const WIRED := {
	"agi": true,
	"aoe_pct": true,
	"armor": true,
	"atk_speed_pct": true,
	"block_no_shield": true,
	"block_pct": true,
	"block_power_pct": true,
	"cdr_pct": true,
	"crit_dmg_pct": true,
	"crit_pct": true,
	"dmg_pct": true,
	"dodge_pct": true,
	"dr_pct": true,
	"effect_dur_pct": true,
	"faith": true,
	"free_skills": true,
	"hp": true,
	"hp_pct": true,
	"hp_regen_pct": true,
	"lifesteal_pct": true,
	"mana_pct": true,
	"mana_regen": true,
	"mana_regen_pct": true,
	"move_pct": true,
	"nauz_xp_pct": true,
	"one_path": true,
	"skill_cost_pct": true,
	"str": true,
	"thorns_pct": true
}
const NEEDS_WIRING := ["proj_speed_pct", "double_hit_pct", "armor_pen_pct", "pen_all_pct", "res_all_pct"]
const THEMES := {
	"str": {
		"life": ["hp", "hp_pct", "lifesteal_pct"],
		"melee": ["dmg_pct", "atk_speed_pct", "str"],
		"armour": ["armor", "dr_pct", "block_pct", "thorns_pct", "block_power_pct"]
	},
	"agi": {
		"evasion": ["dodge_pct", "move_pct", "agi"],
		"ranged": ["dmg_pct", "atk_speed_pct", "agi"],
		"crit": ["crit_pct", "crit_dmg_pct", "atk_speed_pct"]
	},
	"faith": {
		"spell": ["dmg_pct", "aoe_pct", "faith"],
		"resource": ["mana_pct", "mana_regen", "cdr_pct", "skill_cost_pct"],
		"support": ["hp_regen_pct", "effect_dur_pct", "nauz_xp_pct", "faith"]
	}
}
const TRAVEL := {
	"str": ["str", "hp", "armor"],
	"agi": ["agi", "move_pct", "hp"],
	"faith": ["faith", "mana_regen", "hp"]
}
const STAT_NAMES := {
	"str": "Сила",
	"agi": "Спритність",
	"faith": "Віра",
	"dmg_pct": "шкоди",
	"hp_pct": "життя",
	"armor": "броні",
	"atk_speed_pct": "швидкості атаки",
	"hp": "життя",
	"lifesteal_pct": "лічі",
	"thorns_pct": "шипів",
	"block_pct": "блоку",
	"dr_pct": "захисту",
	"crit_pct": "крита",
	"dodge_pct": "ухилення",
	"move_pct": "руху",
	"crit_dmg_pct": "критичної шкоди",
	"cdr_pct": "відновлення",
	"mana_pct": "чару",
	"mana_regen": "відновлення чару",
	"mana_regen_pct": "відн. чару",
	"effect_dur_pct": "тривалості",
	"hp_regen_pct": "регенерації",
	"nauz_xp_pct": "росту наузів",
	"skill_cost_pct": "вартості",
	"aoe_pct": "площі",
	"block_power_pct": "сили блоку",
	"one_path": "один шлях",
	"free_skills": "вільні вміння",
	"block_no_shield": "блок без щита"
}
const NS := {
	"str": [
		"Жила сили",
		"Криця роду",
		"Міць предка",
		"Кістка ведмедя",
		"Удар молота",
		"Щит стін",
		"Брусок гарту",
		"Кров воїна",
		"Плече дружини",
		"Корінь дуба",
		"Ланцюг клятви",
		"Лезо сокири",
		"Вага щита",
		"Рев полку",
		"Слід тура",
		"Загартований кулак",
		"Обруч сили",
		"Нитка сили",
		"Камінь опори",
		"Хват заліза",
		"Шлях ратника",
		"Знак вепра",
		"Тиск строю",
		"Клич бою",
		"Броня предків",
		"Стовбур сили",
		"Кіготь ведмедя",
		"Удар щитом",
		"Гудок рогу",
		"Плита гарту",
		"Ребро щита",
		"Крок велетня",
		"Залізний обруч",
		"Стяг полку",
		"Тиснява",
		"Кістяний щит",
		"Важкий крок",
		"Гартоване рамено",
		"Зуб вепра",
		"Клинок варти"
	],
	"agi": [
		"Тінь кроку",
		"Гостре око",
		"Сагайдак вітру",
		"Слід рисі",
		"Тетіва ясена",
		"Шепіт листя",
		"Стрибок сарни",
		"Нитка влучності",
		"Подих швидкості",
		"Кіготь яструба",
		"Слід на воді",
		"Змах крила",
		"Точка прицілу",
		"Шлях ловця",
		"Легкий крок",
		"Кільце спритності",
		"Змах кинджала",
		"Свист стріли",
		"Тінь у траві",
		"Око сокола",
		"Пружність тятиви",
		"Знак вовка",
		"Хід по гілках",
		"Мить удару",
		"Плин річки",
		"Лист ясена",
		"Стрімкий крок",
		"Змах сагайдака",
		"Тінь гілки",
		"Нитка вітру",
		"Роса на тятиві",
		"Крок по моху",
		"Зір рисі",
		"Шип стріли",
		"Подих листя",
		"Тінь осоки",
		"Хижий змах",
		"Слід роси",
		"Нитка стежки",
		"Око вітру"
	],
	"faith": [
		"Нитка долі",
		"Шепіт волхва",
		"Коло пращурів",
		"Іскра Сварога",
		"Дихання Вію",
		"Знак Перуна",
		"Чаша роси",
		"Світло капища",
		"Пісня Мокоші",
		"Корені роду",
		"Сліди ярила",
		"Крила віри",
		"Слово оберегу",
		"Прядка часу",
		"Дзвін дзвоника",
		"Світло рун",
		"Подих капища",
		"Струмок сили",
		"Око відуна",
		"Круг сонця",
		"Нитка Мокоші",
		"Знак Лади",
		"Тінь капища",
		"Жар вогнища",
		"Голос предків",
		"Крила Лади",
		"Руна шляху",
		"Свіча роду",
		"Пісня вітру",
		"Коло сонця",
		"Роса капища",
		"Тихе слово",
		"Знак Дажбога",
		"Нитка оберегу",
		"Світло роси",
		"Подих рун",
		"Коло вогнища",
		"Пісня роду",
		"Чаша сонця",
		"Слід волхва"
	]
}
const NN := {
	"str": {
		"life": ["Кривавий удар", "Серце вепра", "Жила роду", "Кров предків", "Дихання ведмедя"],
		"melee": ["Удар дружини", "Молот предків", "Гнів тура", "Криця серця", "Важкий замах"],
		"armour": ["Залізна шкіра", "Щит роду", "Стіна ратників", "Плита гарту", "Броня дуба"]
	},
	"agi": {
		"evasion": ["Тінь вовка", "Стрибок рисі", "Тінь лисиці", "Легкий крок", "Танок вітру"],
		"ranged": ["Град стріл", "Сагайдак бурі", "Стрімкий вітер", "Око бурі", "Тятива грози"],
		"crit": ["Влучне око", "Ясне око", "Зір яструба", "Мить удару", "Гострий зір"]
	},
	"faith": {
		"spell": ["Вогонь Сварога", "Жар капища", "Коло Мокоші", "Іскра Перуна", "Слово вогню"],
		"resource": ["Нитка долі", "Сила науза", "Чаша роси", "Вільні вміння", "Джерело чару"],
		"support": ["Оберіг", "Коло пращурів", "Дихання світу", "Світло капища", "Покров роду"]
	}
}
const NK := [
	["Один шлях", "str", {
		"dmg_pct": 25,
		"one_path": 1
	}],
	["Серце війни", "str", {
		"dmg_pct": 20,
		"armor": -12
	}],
	["Кривава данина", "str", {
		"lifesteal_pct": 8,
		"hp_pct": -10
	}],
	["Смертельна тінь", "agi", {
		"crit_dmg_pct": 30,
		"armor": -8
	}],
	["Серце полювання", "agi", {
		"crit_pct": 12,
		"hp_pct": -10
	}],
	["Гнів пращурів", "agi", {
		"aoe_pct": 20,
		"atk_speed_pct": -10
	}],
	["Вільні вміння", "faith", {
		"cdr_pct": 25,
		"free_skills": 1,
		"mana_pct": -15
	}],
	["Серце віри", "faith", {
		"dmg_pct": 20,
		"move_pct": -12
	}],
	["Щит без щита", "str", {
		"block_no_shield": 1,
		"block_pct": 12,
		"move_pct": -8
	}]
]


var seed: int = 0
var sil
var nodes: Dictionary = {}
var links: Array = []
var occ: Array = []
var by: Dictionary = {}
var deg: Dictionary = {}
var nm: Dictionary = {}
var uidc: int = 0
var nti: Dictionary = {}
var clusters: Array = []
var top: Dictionary = {}
var seglinks: Array = []
var site_edges: Array = []
var _rng: RandomNumberGenerator
var _uid_i: int = 0
var _progress: Callable = Callable()


func _items(d: Dictionary) -> Array:
	var out: Array = []
	for k in d.keys():
		out.append([k, d[k]])
	return out
func _keys(d: Dictionary) -> Array:
	return d.keys()
func _values(d: Dictionary) -> Array:
	var out: Array = []
	for k in d.keys():
		out.append(d[k])
	return out
func _to_set(arr) -> Dictionary:
	var s: Dictionary = {}
	for x in arr:
		s[x] = true
	return s
func _sum(arr) -> float:
	var t := 0.0
	for x in arr:
		t += float(x)
	return t
func _sorted(arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort()
	return a
func _sorted_with_key(arr: Array, key_fn: Callable, reverse: bool = false) -> Array:
	var decorated: Array = []
	for i in range(arr.size()):
		decorated.append([key_fn.call(arr[i]), i, arr[i]])
	decorated.sort_custom(func(a, b):
		if reverse:
			return a[0] > b[0]
		return a[0] < b[0]
	)
	var out: Array = []
	for d in decorated:
		out.append(d[2])
	return out
func _any(arr) -> bool:
	for x in arr:
		if x: return true
	return false
func _all(arr) -> bool:
	for x in arr:
		if not x: return false
	return true
func _zip(a: Array, b: Array) -> Array:
	var out: Array = []
	var n: int = mini(a.size(), b.size())
	for i in range(n):
		out.append([a[i], b[i]])
	return out
func _counter(arr) -> Dictionary:
	var c: Dictionary = {}
	for x in arr:
		c[x] = int(c.get(x, 0)) + 1
	return c
func _dict_update(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		dst[k] = src[k]
func _setdefault(d: Dictionary, k, default_v):
	if not d.has(k):
		d[k] = default_v
	return d[k]
func _pop(obj, key):
	if typeof(obj) == TYPE_DICTIONARY:
		var v = obj[key]
		obj.erase(key)
		return v
	return obj.pop_at(int(key))
func _make_rng(p_seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = p_seed
	return r
func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
func _sample(rng: RandomNumberGenerator, arr: Array, k: int) -> Array:
	var a := arr.duplicate()
	_shuffle(rng, a)
	return a.slice(0, mini(k, a.size()))
func _gauss(rng: RandomNumberGenerator, mu: float, sigma: float) -> float:
	var u1: float = maxf(rng.randf(), 1e-12)
	var u2: float = rng.randf()
	return mu + sigma * sqrt(-2.0 * log(u1)) * cos(TAU * u2)
func _heappush(heap: Array, item) -> void:
	heap.append(item)
	var i: int = heap.size() - 1
	while i > 0:
		var p: int = int((i - 1) / 2)
		if heap[i] < heap[p]:
			var t = heap[i]; heap[i] = heap[p]; heap[p] = t
			i = p
		else:
			break
func _heappop(heap: Array):
	if heap.is_empty():
		return null
	var top = heap[0]
	var last = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n: int = heap.size()
		while true:
			var l: int = 2 * i + 1
			var r: int = 2 * i + 2
			var smallest: int = i
			if l < n and heap[l] < heap[smallest]:
				smallest = l
			if r < n and heap[r] < heap[smallest]:
				smallest = r
			if smallest == i:
				break
			var t = heap[i]; heap[i] = heap[smallest]; heap[smallest] = t
			i = smallest
	return top
func _heapify(heap: Array) -> void:
	for i in range(int(heap.size() / 2) - 1, -1, -1):
		# reuse down via heappush pattern: simple rebuild
		pass
	var tmp := heap.duplicate()
	heap.clear()
	for x in tmp:
		_heappush(heap, x)
func lerp_f(a: float, b: float, t: float) -> float:
	return a + (b - a) * t

func _set_and(a, b) -> Dictionary:
	var out: Dictionary = {}
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for k in a.keys():
			if b.has(k):
				out[k] = true
	return out
func _set_or(a, b) -> Dictionary:
	var out: Dictionary = {}
	if typeof(a) == TYPE_DICTIONARY:
		for k in a.keys(): out[k] = true
	if typeof(b) == TYPE_DICTIONARY:
		for k in b.keys(): out[k] = true
	return out


func _choice(arr: Array):
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]

func dist(a, b):
	return sqrt(((a[0] - b[0]))*((a[0] - b[0]))+((a[1] - b[1]))*((a[1] - b[1])))

func lerp(a, b, t):
	return (a + ((b - a) * t))

func seg_intersect(a, b, c, d, share_ok = true):
	"Proper intersection of open/closed segments. Endpoints sharing is not a crossing."
	var ori = func(p, q, r):
		return (((q[0] - p[0]) * (r[1] - p[1])) - ((q[1] - p[1]) * (r[0] - p[0])))
	var on_seg = func(p, q, r):
		return (((min(p[0], r[0]) - 1e-09) <= q[0]) and (q[0] <= (max(p[0], r[0]) + 1e-09)) and ((min(p[1], r[1]) - 1e-09) <= q[1]) and (q[1] <= (max(p[1], r[1]) + 1e-09)))
	var _tu_336 = [ori(a, b, c), ori(a, b, d)]
	var o1 = _tu_336[0]
	var o2 = _tu_336[1]
	var _tu_337 = [ori(c, d, a), ori(c, d, b)]
	var o3 = _tu_337[0]
	var o4 = _tu_337[1]
	for p in [a, b]:
		for q in [c, d]:
			if (dist(p, q) < 1e-06):
				return false
	if (((o1 * o2) < 0) and ((o3 * o4) < 0)):
		return true
	return false

func point_seg_dist(p, a, b):
	var _tu_349 = a
	var ax = _tu_349[0]
	var ay = _tu_349[1]
	var _tu_350 = b
	var bx = _tu_350[0]
	var by = _tu_350[1]
	var _tu_351 = p
	var px = _tu_351[0]
	var py = _tu_351[1]
	var _tu_352 = [(bx - ax), (by - ay)]
	var vx = _tu_352[0]
	var vy = _tu_352[1]
	var l2 = ((vx * vx) + (vy * vy))
	if (l2 < 1e-12):
		return sqrt(((px - ax))*((px - ax))+((py - ay))*((py - ay)))
	var t = max(0.0, min(1.0, ((((px - ax) * vx) + ((py - ay) * vy)) / l2)))
	return sqrt(((px - (ax + (t * vx))))*((px - (ax + (t * vx))))+((py - (ay + (t * vy))))*((py - (ay + (t * vy)))))


func _g_init(seed):
	self.seed = seed
	_rng = _make_rng(seed)
	self.sil = SilhouetteV7.new(seed)
	self.nodes = {}
	self.links = []
	self.occ = []
	self.by = {}
	self.deg = {}
	self.nm = {}
	self.uidc = 0
	var _dc1 = {}
	for r in BR:
		var _inner = {}
		for th in THEMES[r].keys():
			_inner[th] = 0
		_dc1[r] = _inner
	self.nti = _dc1
	self.clusters = []
	self.top = {}
	self.seglinks = []

func rnd(a, b):
	return _rng.randf_range(a, b)

func uid(p):
	self.uidc += 1
	return "n%s_%s" % [self.uidc, p]

func free(x, y, m = MIN_DIST):
	var md2 = (m * m)
	for _it in self.occ:
		var ox = _it[0]
		var oy = _it[1]
		if ((pow((x - ox), 2) + pow((y - oy), 2)) < md2):
			return false
	return true

func pick_name(pool):
	for n in _sorted_with_key(pool, func(n): return [self.nm[n], _rng.randf()], false):
		if (self.nm[n] < 6):
			self.nm[n] += 1
			return n
	var n = "Вузол ·%s" % [self.uidc]
	self.nm[n] += 1
	return n

func nname(rg, theme):
	var p = NN[rg][theme]
	var i = self.nti[rg][theme]
	self.nti[rg][theme] = (i + 1)
	var n = p[(i % p.size())]
	if (self.nm[n] > 0):
		n = "%s ·%s" % [n, (i + 1)]
	self.nm[n] += 1
	return n

func power(y):
	var t = ((y - 100) / 1600.0)
	t = max(0.0, min(1.0, t))
	if (t < 0.25):
		return [1, 2]
	if (t < 0.55):
		return [2, 3]
	return [3, 4]

func desc(st):
	var out = []
	for _it in _items(st):
		var k = _it[0]
		var v = _it[1]
		if (not (k in WIRED)):
			continue
		var nm = STAT_NAMES.get(k, k)
		if (k in ["str", "agi", "faith", "hp", "armor", "mana_regen", "one_path", "free_skills", "block_no_shield"]):
			out.append("%s%s%s" % [nm, ("+" if (v >= 0) else ""), v])
		else:
			out.append("%s%s%s%%" % [nm, ("+" if (v >= 0) else ""), v])
	return ((", ".join(PackedStringArray(out)) + ".") if out else "—")

func themed_stats(rg, theme, y, notable = false, travel = false, mixed = false):
	var _tu_438 = self.power(y)
	var base = _tu_438[0]
	var spr = _tu_438[1]
	var _lc1 = []
	for o in BR:
		if (o != rg):
			_lc1.append(o)
	if travel:
		var keys = TRAVEL[rg].slice(0, 2147483647)
		if mixed:
			var other = _lc1[_rng.randi_range(0, (2) - 1)]
			keys = (keys + TRAVEL[other])
		var k = _choice(keys)
		return {k: _rng.randi_range(base, (base + spr))}
	var pool = THEMES[rg][theme].slice(0, 2147483647)
	_lc1 = []
	for o in BR:
		if (o != rg):
			_lc1.append(o)
	if mixed:
		other = _lc1[0]
		var otheme = _choice(THEMES[other])
		pool = (pool + THEMES[other][otheme])
	var n = (2 if notable else (1 if (_rng.randf() < 0.7) else 2))
	var ks = (pool if (pool.size() <= n) else _sample(_rng, pool, n))
	var st = {}
	for i in range(ks.size()):
		var k = ks[i]
		var lo = (base + (2 if notable else 0))
		var hi = ((lo + spr) + (2 if (notable and (i == 0)) else 0))
		st[k] = (st.get(k, 0) + _rng.randi_range(lo, hi))
	if (notable and (_rng.randf() < 0.45)):
		var k2 = _choice(pool)
		st[k2] = (st.get(k2, 0) + _rng.randi_range(1, 2))
	if (("skill_cost_pct" in st) and (st["skill_cost_pct"] > 0)):
		st["skill_cost_pct"] = (-st["skill_cost_pct"])
	var _dc1 = {}
	for _it in _items(st):
		k = _it[0]
		var v = _it[1]
		if (k in WIRED):
			_dc1[k] = v
	return _dc1

func add(nid, name, x, y, typ, st, rg, dsc = null, mind = null):
	var mind = (MIN_DIST if (mind == null) else mind)
	if (not self.free(x, y, mind)):
		return null
	var _dc1 = {}
	for _it in _items(st):
		var k = _it[0]
		var v = _it[1]
		if (k in WIRED):
			_dc1[k] = v
	var st = _dc1
	var node = {"id": nid, "name": name, "description": (dsc if (dsc != null) else self.desc(st)), "x": x, "y": y, "type": typ, "stats": st, "skill": "", "icon": "", "region": rg}
	self.occ.append([x, y])
	self.nodes.append(node)
	self.by[nid] = node
	return nid

func pos(nid):
	var n = self.by[nid]
	return [n["x"], n["y"]]

func ln(a, b, force = false, max_len = null):
	if ((not a) or (not b) or (a == b) or (not (a in self.by)) or (not (b in self.by))):
		return false
	if ((self.deg[a] >= MAX_DEG) or (self.deg[b] >= MAX_DEG)):
		return false
	var _ge1 = []
	for L in self.links:
		_ge1.append((_sorted(L) == _sorted([a, b])))
	if _any(_ge1):
		return false
	var _tu_492 = self.pos(a)
	var ax = _tu_492[0]
	var ay = _tu_492[1]
	var _tu_493 = self.pos(b)
	var bx = _tu_493[0]
	var by = _tu_493[1]
	var d = sqrt(((bx - ax))*((bx - ax))+((by - ay))*((by - ay)))
	var cap = (max_len if (max_len != null) else (STEP * 1.7))
	if ((not force) and (d > cap)):
		return false
	if (d < (MIN_DIST * 0.45)):
		return false
	for _it in self.seglinks:
		var p = _it[0]
		var q = _it[1]
		var u = _it[2]
		var v = _it[3]
		if _set_and(_to_set([u, v]), _to_set([a, b])):
			continue
		if seg_intersect([ax, ay], [bx, by], p, q):
			return false
	self.links.append([a, b])
	self.deg[a] += 1
	self.deg[b] += 1
	self.seglinks.append([[ax, ay], [bx, by], a, b])
	return true

func r_site(x, y):
	var z = self.sil.zone(x, y)
	if (z == "crown"):
		return 88.0
	if (z == "roots"):
		return 92.0
	return 80.0

func sample_sites():
	var sil = self.sil
	var _tu_523 = sil.bbox()
	var xmin = _tu_523[0]
	var xmax = _tu_523[1]
	var ymin = _tu_523[2]
	var ymax = _tu_523[3]
	var sites = []
	var ok_site = func(x, y, r):
		if (not sil.inside(x, y, 0.98)):
			return false
		for s in sites:
			if (sqrt(((x - s["x"]))*((x - s["x"]))+((y - s["y"]))*((y - s["y"]))) < (max(r, s["r"]) * 0.82)):
				return false
		return true
	var add_site = func(x, y, kind, r, rg, junc, keep, theme, jitter):
		var r = (r or self.r_site(x, y))
		if (not ok_site(x, y, ((r * 0.85) if (kind != "fill") else r))):
			if (not jitter):
				return null
			for _ in range(12):
				var jx = (x + self.rnd(((-r) * 0.3), (r * 0.3)))
				var jy = (y + self.rnd(((-r) * 0.3), (r * 0.3)))
				if ok_site(jx, jy, (r * 0.8)):
					var _tu_544 = [jx, jy]
					var x = _tu_544[0]
					var y = _tu_544[1]
					break
		if (rg == null):
			var _tu_550 = sil.region(x, y)
			var rg = _tu_550[0]
			var junc = _tu_550[1]
		if (theme == null):
			var theme = _choice(THEMES[rg])
		var s = {"x": x, "y": y, "kind": kind, "rg": rg, "junc": junc, "theme": theme, "r": self.r_site(x, y), "id": sites.size(), "keep": (keep or (kind in ["start", "keystone"]))}
		sites.append(s)
		return s
	var _lc1 = []
	for f in sil.fans:
		_lc1.append(f[0])
	var fx = _lc1
	_lc1 = []
	for f in sil.fans:
		_lc1.append((f[1] - 70))
	var fy = _lc1
	add_site(fx[0], max((sil.root_y0 + 40), fy[0]), "start")
	add_site(fx[1], max((sil.root_y0 + 20), (fy[1] - 20)), "start")
	add_site(fx[2], max((sil.root_y0 + 40), fy[2]), "start")
	for _it in sil.fans:
		var cx = _it[0]
		var cy = _it[1]
		var rx = _it[2]
		var ry = _it[3]
		var rg = _it[4]
		for _it in [[0.46, 5], [0.76, 6]]:
			var radf = _it[0]
			var angs = _it[1]
			for i in range(angs):
				var ang = ((sil.phase * 0.3) + ((i * TAU) / angs))
				var x = (cx + ((rx * radf) * cos(ang)))
				var y = (cy + (((ry * radf) * sin(ang)) * 0.95))
				if (y < (sil.root_y0 + 8)):
					continue
				add_site(x, y, "fill")
	var ks_spec = [[deg_to_rad(125), "str"], [deg_to_rad(145), "str"], [deg_to_rad(165), "str"], [deg_to_rad(80), "agi"], [deg_to_rad(100), "agi"], [deg_to_rad(60), "agi"], [deg_to_rad(15), "faith"], [deg_to_rad(35), "faith"], [deg_to_rad((-5)), "faith"]]
	for _it in ks_spec:
		ang = _it[0]
		rg = _it[1]
		var r = (sil.crown_r(ang) * 0.9)
		x = (sil.cx + (r * cos(ang)))
		y = (sil.cy + (r * sin(ang)))
		add_site(x, y, "keystone")
	var col = [["str", (-0.62)], ["agi", 0.0], ["faith", 0.62]]
	y = (sil.trunk_bot + 16)
	while (y < (sil.trunk_top - 12)):
		var hw = sil.trunk_hw(y)
	for _it in [["str", (-0.72)], ["agi", (-0.22)], ["agi", 0.22], ["faith", 0.72]]:
		rg = _it[0]
		var xf = _it[1]
		add_site(((xf * sil.crx) * 0.5), (sil.trunk_top + 8), "fill")
	for _it in [["str", (-0.55), 55], ["agi", 0.0, 40], ["faith", 0.55, 55]]:
		rg = _it[0]
		var x0 = _it[1]
		var amp = _it[2]
		for t in [0.08, 0.16, 0.7, 0.82, 0.9]:
			y = lerp(200, (sil.cy + (sil.cry * 0.4)), t)
			var dy = (y - sil.cy)
			if (sil.in_crown(0, y, 1.02) and (abs(dy) < sil.cry)):
				hw = (sil.crx * sqrt(max(0.0, (1 - pow((dy / sil.cry), 2)))))
			elif sil.in_trunk(0, y, 1.2):
				hw = sil.trunk_hw(y)
			elif sil.in_roots((x0 * 200), y, 1.1):
				hw = 320
			else:
				continue
			x = ((x0 * hw) + (amp * sin(((((t * PI) * 2) + sil.phase) + ({"str": 1, "agi": 4, "faith": 7}[rg] * 0.3)))))
			add_site(x, y, "fill")
	var target = 78
	var tries = 0
	var max_tries = 16000
	while ((sites.size() < target) and (tries < max_tries)):
		tries += 1
	if (sites.size() < 84):
		for _ in range(4000):
			x = self.rnd(xmin, xmax)
			y = self.rnd(ymin, ymax)
			if sil.inside(x, y, 0.97):
				add_site(x, y, "fill")
			if (sites.size() >= 90):
				break
	var step = 92
	x = (xmin + 20)
	while (x <= (xmax - 20)):
		y = (ymin + 20)
	var nearest = func(s0):
		var best = 1000000000.0
		for s in sites:
			if (s == s0):
				continue
			var d = sqrt(((s0["x"] - s["x"]))*((s0["x"] - s["x"]))+((s0["y"] - s["y"]))*((s0["y"] - s["y"])))
			if (d < best):
				best = d
		return best
	_lc1 = []
	for s in sites:
		if ((s["kind"] != "fill") or (nearest(s) < 150)):
			_lc1.append(s)
	sites.slice(0, 2147483647) = _lc1
	var CAP = 102
	_lc1 = []
	for s in sites:
		if ((s["kind"] == "fill") and (not s.get("keep", null))):
			_lc1.append(s)
	var _lc2 = []
	for s in sites:
		if (not (id(s) in drop)):
			_lc2.append(s)
	if (sites.size() > CAP):
		var fill = _lc1
		fill.sort()
		var need_drop = (sites.size() - CAP)
		var drop = {}
		for s0 in fill:
			if (need_drop <= 0):
				break
			drop[id(s0)] = true
			need_drop -= 1
		sites.slice(0, 2147483647) = _lc2
	var seeds = [[90, 1280, "agi"], [150, 1380, "agi"], [70, 1480, "agi"], [200, 1220, "agi"], [130, 1540, "agi"], [40, 1350, "agi"], [310, 1160, "faith"], [390, 1080, "faith"], [260, 1240, "agi"], [50, 1600, "agi"], [190, 1520, "agi"], [270, 1480, "faith"], [250, 1400, "faith"], [230, 1320, "faith"], [(-160), 1360, "str"], [(-60), 1280, "agi"], [360, 1200, "faith"], [420, 1140, "faith"]]
	var added = 0
	for _it in seeds:
		x = _it[0]
		y = _it[1]
		rg = _it[2]
		if (not sil.inside(x, y, 0.94)):
			continue
		if ok_site(x, y, 78):
			var th = THEMES[rg][0]
			if add_site(x, y, "fill"):
				added += 1
	if (added < 8):
		var _tu_715 = [((-sil.crx) + 40), (sil.crx - 40)]
		var xmin2 = _tu_715[0]
		var xmax2 = _tu_715[1]
		var _tu_716 = [((sil.cy - sil.cry) + 40), ((sil.cy + sil.cry) - 20)]
		var ymin2 = _tu_716[0]
		var ymax2 = _tu_716[1]
		y = ymin2
		while ((y <= ymax2) and (added < 8)):
			x = xmin2
	for i in range(sites.size()):
		var s = sites[i]
		s["id"] = i
	self.sites = sites
	return sites

func site_graph():
	var sites = self.sites
	var n = sites.size()
	var _lc1 = []
	for s in sites:
		_lc1.append([s["x"], s["y"]])
	var pts = _lc1
	var edge_ok = func(i, j, slop):
		var _tu_744 = pts[i]
		var ax = _tu_744[0]
		var ay = _tu_744[1]
		var _tu_745 = pts[j]
		var bx = _tu_745[0]
		var by = _tu_745[1]
		var d = dist(pts[i], pts[j])
		if ((d < 40) or (d > 260)):
			return false
		var steps = max(3, int((d / 14)))
		for k in range(1, steps):
			var t = (k / steps)
			var _tu_752 = [lerp(ax, bx, t), lerp(ay, by, t)]
			var x = _tu_752[0]
			var y = _tu_752[1]
			if (not self.sil.inside(x, y, slop)):
				return false
		return true
	var gab = []
	for i in range(n):
		for j in range((i + 1), n):
			if (not edge_ok(i, j, 1.1)):
				continue
			var mx = ((pts[i][0] + pts[j][0]) / 2)
			var my = ((pts[i][1] + pts[j][1]) / 2)
			var r2 = pow((dist(pts[i], pts[j]) / 2), 2)
			var bad = false
			for k in range(n):
				if ((k == i) or (k == j)):
					continue
				if ((pow((pts[k][0] - mx), 2) + pow((pts[k][1] - my), 2)) < (r2 - 0.0001)):
					bad = true
					break
			if (not bad):
				gab.append([i, j, dist(pts[i], pts[j])])
	var cand = {}
	for _it in gab:
		var i = _it[0]
		var j = _it[1]
		var d = _it[2]
		cand[[i, j, d]] = true
	var _ge1 = []
	for j in range(n):
		if (j != i):
			_ge1.append([dist(pts[i], pts[j]), j])
	for i in range(n):
		var nb = _sorted(_ge1).slice(0, 7)
		for _it in nb:
			d = _it[0]
			j = _it[1]
			var _tu_783 = ([i, j] if (i < j) else [j, i])
			var a = _tu_783[0]
			var b = _tu_783[1]
			if edge_ok(a, b, 1.14):
				cand[[a, b, d]] = true
	var parent = range(n)
	var find = func(x):
		while (parent[x] != x):
			parent[x] = parent[parent[x]]
		return x
	var union = func(a, b):
		var _tu_797 = [find(a), find(b)]
		var ra = _tu_797[0]
		var rb = _tu_797[1]
		if (ra == rb):
			return false
		parent[rb] = ra
		return true
	var edges = []
	for _it in _sorted_with_key(cand, func(e): return e[2], false):
		i = _it[0]
		j = _it[1]
		d = _it[2]
		if union(i, j):
			edges.append([i, j, d])
	var comps = func():
		var c = {}
		for i in range(n):
			c[find(i)].append(i)
		return _values(c)
	for _ in range(20):
		var cc = comps()
		if (cc.size() == 1):
			break
		var best = null
		for a in range(cc.size()):
			for b in range((a + 1), cc.size()):
				for i in cc[a]:
					for j in cc[b]:
						d = dist(pts[i], pts[j])
						if ((best == null) or (d < best[0])):
							if (edge_ok(i, j, 1.22) or (d < 320)):
								best = [d, i, j]
		if (not best):
			break
		var _tu_830 = best
		var _d = _tu_830[0]
		i = _tu_830[1]
		j = _tu_830[2]
		if union(i, j):
			edges.append([i, j, _d])
	var deg = {}
	for _it in edges:
		i = _it[0]
		j = _it[1]
		var _ = _it[2]
		deg[i] += 1
		deg[j] += 1
	var crosses = func(i, j):
		var _tu_841 = [pts[i], pts[j]]
		a = _tu_841[0]
		b = _tu_841[1]
		for _it in edges:
			var u = _it[0]
			var v = _it[1]
			_ = _it[2]
			if (_to_set([i, j, u, v]).size() < 4):
				continue
			if seg_intersect(a, b, pts[u], pts[v]):
				return true
		return false
	for _it in _sorted_with_key(gab, func(e): return e[2], false):
		i = _it[0]
		j = _it[1]
		d = _it[2]
		if (([i, j, d] in edges) or ([j, i, d] in edges)):
			continue
		if ((deg[i] >= 4) or (deg[j] >= 4)):
			continue
		if (not edge_ok(i, j, 1.08)):
			continue
		if crosses(i, j):
			continue
		edges.append([i, j, d])
		deg[i] += 1
		deg[j] += 1
	var extra = []
	for i in range(n):
		for j in range((i + 1), n):
			d = dist(pts[i], pts[j])
			if (d > 180):
				continue
			if (not ((sites[i]["kind"] != "start") and self.sil.in_crown(sites[i]["x"], sites[i]["y"], 1.05))):
				continue
			extra.append([i, j, d])
	_shuffle(_rng, extra)
	_ge1 = []
	for e in edges:
		_ge1.append((((e[0] == i) and (e[1] == j)) or ((e[0] == j) and (e[1] == i))))
	for _it in extra:
		i = _it[0]
		j = _it[1]
		d = _it[2]
		if ((deg[i] >= 4) or (deg[j] >= 4)):
			continue
		if _any(_ge1):
			continue
		if ((not edge_ok(i, j, 1.06)) or crosses(i, j)):
			continue
		edges.append([i, j, d])
		deg[i] += 1
		deg[j] += 1
	var region_of = func(i):
		return sites[i]["rg"]
	_ge1 = []
	for e in edges:
		_ge1.append((((e[0] == i) and (e[1] == j)) or ((e[0] == j) and (e[1] == i))))
	var add_edge = func(i, j):
		d = dist(pts[i], pts[j])
		if _any(_ge1):
			return false
		if ((deg[i] >= 5) or (deg[j] >= 5)):
			return false
		if (crosses(i, j) and (d > 90)):
			return false
		if ((not edge_ok(i, j, 1.2)) and (d > 140)):
			return false
		edges.append([i, j, d])
		deg[i] += 1
		deg[j] += 1
		return true
	_lc1 = []
	for i in range(n):
		if ((sites[i]["rg"] == rg) or sites[i]["junc"]):
			_lc1.append(i)
	var _dc2 = {}
	for i in idx:
		_dc2[i] = i
	for rg in BR:
		var idx = _lc1
		if (not idx):
			continue
		parent = _dc2
		var find = func(x, parent):
			while (parent[x] != x):
				parent[x] = parent[parent[x]]
			return x
		for _it in edges:
			i = _it[0]
			j = _it[1]
			d = _it[2]
			if ((i in parent) and (j in parent)):
				var _tu_919 = [find(i), find(j)]
				a = _tu_919[0]
				b = _tu_919[1]
				if (a != b):
					parent[b] = a
		for _ in range(12):
			var comps = {}
			for i in idx:
				_setdefault(comps, find(i), []).append(i)
			if (comps.size() <= 1):
				break
			var keys = comps
			best = null
			for a in range(keys.size()):
				for b in range((a + 1), keys.size()):
					for i in comps[keys[a]]:
						for j in comps[keys[b]]:
							d = dist(pts[i], pts[j])
							if ((best == null) or (d < best[0])):
								best = [d, i, j]
			if (not best):
				break
			var _tu_940 = best
			_d = _tu_940[0]
			i = _tu_940[1]
			j = _tu_940[2]
			if add_edge(i, j):
				parent[find(j)] = find(i)
			else:
				parent[find(j)] = find(i)
	var Y_CROSS_MAX = 350.0
	var pruned = []
	var held = []
	for _it in edges:
		i = _it[0]
		j = _it[1]
		d = _it[2]
		my = ((sites[i]["y"] + sites[j]["y"]) / 2.0)
		if ((sites[i]["rg"] != sites[j]["rg"]) and (my > Y_CROSS_MAX)):
			held.append([i, j, d])
		else:
			pruned.append([i, j, d])
	parent = range(n)
	var find = func(x, parent):
		while (parent[x] != x):
			parent[x] = parent[parent[x]]
		return x
	var union = func(a, b, parent):
		var _tu_970 = [find(a), find(b)]
		var ra = _tu_970[0]
		var rb = _tu_970[1]
		if (ra == rb):
			return false
		parent[rb] = ra
		return true
	for _it in pruned:
		i = _it[0]
		j = _it[1]
		d = _it[2]
		union(i, j)
	held.sort()
	for _it in held:
		i = _it[0]
		j = _it[1]
		d = _it[2]
		if (find(i) != find(j)):
			pruned.append([i, j, d])
			union(i, j)
	deg = {}
	for _it in pruned:
		i = _it[0]
		j = _it[1]
		d = _it[2]
		deg[i] += 1
		deg[j] += 1
	edges = pruned
	self.site_edges = edges
	self.site_deg = deg
	return edges

func place_clusters():
	var order = _sorted_with_key(self.sites, func(s): return (0 if (s["kind"] != "fill") else 1), false)
	var _dc1 = {}
	for s in self.sites:
		_dc1[s["id"]] = s
	var id_map = _dc1
	var placed = {}
	var ks_used = {}
	var _lc1 = []
	for _it in self.occ:
		var ox = _it[0]
		var oy = _it[1]
		if (sqrt(((ox - cx))*((ox - cx))+((oy - cy))*((oy - cy))) > 1):
			_lc1.append([ox, oy])
	var _lc2 = []
	for k in NK:
		if (k[1] == rg):
			_lc2.append(k)
	for s in order:
		var _tu_1003 = [s["rg"], s["theme"], s["junc"]]
		var rg = _tu_1003[0]
		var theme = _tu_1003[1]
		var junc = _tu_1003[2]
		var _tu_1004 = [s["x"], s["y"]]
		var cx = _tu_1004[0]
		var cy = _tu_1004[1]
		var kind = s["kind"]
		var cl = {"site": s["id"], "rg": rg, "theme": theme, "junc": junc, "kind": kind, "ring": [], "center": null, "special": null, "cx": cx, "cy": cy}
		if (kind == "start"):
			var sid = START_ID[rg]
			var st = {rg: 5}
			var name = {"str": "Корінь · Сила", "agi": "Корінь · Спритність", "faith": "Корінь · Віра"}[rg]
			var nid = self[sid] = true
			if (not nid):
				self.occ = _lc1
				nid = self[sid] = true
			cl["special"] = nid
			cl["center"] = nid
			var _tu_1021 = [4, 28.0]
			var ring_n = _tu_1021[0]
			var rad = _tu_1021[1]
			var nodes = self._ring(cx, cy, rad, ring_n, rg, theme, junc)
			cl["ring"] = nodes
			for _it in _zip(nodes, (nodes.slice(1, 2147483647) + nodes.slice(0, 1))):
				var a = _it[0]
				var b = _it[1]
				self.ln(a, b)
			if nodes:
				self.ln(nid, nodes[0])
				self.ln(nid, nodes[int(nodes.size() / 2)])
		elif (kind == "keystone"):
			var idx = ks_used[rg]
			ks_used[rg] += 1
			var cand = _lc2
			var _tu_1035 = cand[(idx % cand.size())]
			var nm = _tu_1035[0]
			var _rg = _tu_1035[1]
			st = _tu_1035[2]
			var ang = atan2((cy - self.sil.cy), (cx - self.sil.cx))
			var kx = (cx + (cos(ang) * 10))
			var ky = (cy + (sin(ang) * 10))
			var kid = self[self.uid("ks")] = true
			if (not kid):
				kid = self[self.uid("ks")] = true
			cl["special"] = kid
			var ix = (cx - (cos(ang) * 28))
			var iy = (cy - (sin(ang) * 28))
			nodes = self._ring(ix, iy, 27.0, 4, rg, theme, junc)
			cl["ring"] = nodes
			cl["center"] = (nodes[0] if nodes else kid)
			for _it in _zip(nodes, (nodes.slice(1, 2147483647) + nodes.slice(0, 1))):
				a = _it[0]
				b = _it[1]
				self.ln(a, b)
			if nodes:
				self.ln(kid, nodes[0])
				if (nodes.size() > 1):
					self.ln(kid, nodes[1])
		else:
			var z = self.sil.zone(cx, cy)
			var t = ((cy - 100) / 1600.0)
			var want_notable = (((z == "crown") and (_rng.randf() < 0.62)) or ((z == "trunk") and (_rng.randf() < 0.38)) or ((z == "roots") and (_rng.randf() < 0.2)))
			if want_notable:
				var size = (5 if (z == "crown") else 5)
				rad = 28.0
				nodes = self._ring(cx, cy, rad, size, rg, theme, junc)
				if nodes:
					st = self.themed_stats(rg, theme, cy)
					nid = self[self.uid("nt")] = true
					cl["center"] = nid
					if (nid and nodes):
						self.ln(nid, nodes[0])
						self.ln(nid, nodes[1])
				cl["ring"] = nodes
				for _it in _zip(nodes, (nodes.slice(1, 2147483647) + nodes.slice(0, 1))):
					a = _it[0]
					b = _it[1]
					self.ln(a, b)
			else:
				size = (4 if (z != "roots") else _choice([3, 4]))
				rad = (26.0 if (size == 4) else 24.0)
				nodes = self._ring(cx, cy, rad, size, rg, theme, junc)
				cl["ring"] = nodes
				cl["center"] = (nodes[0] if nodes else null)
				for _it in _zip(nodes, (nodes.slice(1, 2147483647) + nodes.slice(0, 1))):
					a = _it[0]
					b = _it[1]
					self.ln(a, b)
				if ((size == 4) and (nodes.size() == 4) and (_rng.randf() < 0.25)):
					self.ln(nodes[0], nodes[2])
		if ((not cl["ring"]) and (not cl["special"])):
			continue
		placed[s["id"]] = cl
		self.clusters.append(cl)
	self.cl_by_site = placed
	return placed

func _ring(cx, cy, rad, n, rg, theme, junc, typ = "small", travel = false):
	var nodes = []
	var base = self.rnd(0, TAU)
	for i in range(n):
		var ang = ((base + (i * (TAU / n))) + self.rnd((-0.1), 0.1))
		var x = (cx + (cos(ang) * rad))
		var y = (cy + ((sin(ang) * rad) * 0.96))
		if (typ == "small"):
			var st = self.themed_stats(rg, theme, y)
			if travel:
				st = self.themed_stats(rg, theme, y)
			var nid = self[self.uid("sm")] = true
		else:
			nid = null
		if nid:
			nodes.append(nid)
		else:
			x = (cx + (cos(ang) * (rad * 0.8)))
			y = (cy + (sin(ang) * (rad * 0.8)))
			st = self.themed_stats(rg, theme, y)
			nid = self[self.uid("sm")] = true
			if nid:
				nodes.append(nid)
	return nodes

func _ports(cl, toward):
	"Ring (and special) nodes closest to a point."
	var ids = cl["ring"]
	if (cl.get("special", null) and (cl["kind"] != "keystone")):
		pass
	if ((cl["kind"] == "start") and cl.get("special", null)):
		ids = ids
		ids = (ids + [cl["special"]])
	var pts = []
	for nid in ids:
		if (not (nid in self.by)):
			continue
		var _tu_1142 = self.pos(nid)
		var x = _tu_1142[0]
		var y = _tu_1142[1]
		pts.append([dist([x, y], toward), nid])
	pts.sort()
	var _lc1 = []
	for p in pts:
		_lc1.append(p[1])
	return _lc1

func bezier_points(a, b, n):
	var _tu_1148 = a
	var ax = _tu_1148[0]
	var ay = _tu_1148[1]
	var _tu_1149 = b
	var bx = _tu_1149[0]
	var by = _tu_1149[1]
	var _tu_1150 = [((ax + bx) / 2), ((ay + by) / 2)]
	var mx = _tu_1150[0]
	var my = _tu_1150[1]
	var _tu_1151 = [(bx - ax), (by - ay)]
	var dx = _tu_1151[0]
	var dy = _tu_1151[1]
	var L = (sqrt((dx)*(dx)+(dy)*(dy)) or 1)
	var s = (self.rnd(0.1, 0.2) * (1 if (_rng.randf() < 0.5) else (-1)))
	var _tu_1155 = [(mx - (((dy / L) * s) * L)), (my + (((dx / L) * s) * L))]
	var cx = _tu_1155[0]
	var cy = _tu_1155[1]
	if (not self.sil.inside(cx, cy, 1.12)):
		s *= (-1)
		var _tu_1159 = [(mx - (((dy / L) * s) * L)), (my + (((dx / L) * s) * L))]
		cx = _tu_1159[0]
		cy = _tu_1159[1]
		if (not self.sil.inside(cx, cy, 1.16)):
			var _tu_1161 = [mx, my]
			cx = _tu_1161[0]
			cy = _tu_1161[1]
	var pts = []
	for i in range(1, (n + 1)):
		var t = (i / (n + 1))
		var x = (((pow((1 - t), 2) * ax) + (((2 * (1 - t)) * t) * cx)) + (pow(t, 2) * bx))
		var y = (((pow((1 - t), 2) * ay) + (((2 * (1 - t)) * t) * cy)) + (pow(t, 2) * by))
		pts.append([x, y])
	return pts

func connect_clusters():
	var placed = self.cl_by_site
	var _ge1 = []
	for p in pa:
		if (self.deg[p] < MAX_DEG):
			_ge1.append(p)
	var _ge2 = []
	for p in pb:
		if ((self.deg[p] < MAX_DEG) and (p != a_id)):
			_ge2.append(p)
	for _it in self.site_edges:
		var i = _it[0]
		var j = _it[1]
		var d = _it[2]
		if ((not (i in placed)) or (not (j in placed))):
			continue
		var _tu_1176 = [placed[i], placed[j]]
		var ca = _tu_1176[0]
		var cb = _tu_1176[1]
		var tb = [cb["cx"], cb["cy"]]
		var ta = [ca["cx"], ca["cy"]]
		var pa = self._ports(ca, tb)
		var pb = self._ports(cb, ta)
		if ((not pa) or (not pb)):
			continue
		var a_id = next(_ge1, null)
		var b_id = next(_ge2, null)
		if ((not a_id) or (not b_id)):
			continue
		var _tu_1188 = self.pos(a_id)
		var ax = _tu_1188[0]
		var ay = _tu_1188[1]
		var _tu_1189 = self.pos(b_id)
		var bx = _tu_1189[0]
		var by = _tu_1189[1]
		var gap = dist([ax, ay], [bx, by])
		var k = (int(round((gap / STEP))) - 1)
		k = max(0, min(4, k))
		if (k <= 0):
			self.ln(a_id, b_id)
			continue
		var pts = self.bezier_points([ax, ay], [bx, by], k)
		var mid = pts[int(pts.size() / 2)]
		if (ca["rg"] == cb["rg"]):
			var _tu_1200 = [ca["rg"], (ca["junc"] or cb["junc"])]
			var rg = _tu_1200[0]
			var junc = _tu_1200[1]
		else:
			var _tu_1202 = self.sil.region(mid)
			rg = _tu_1202[0]
			junc = _tu_1202[1]
			junc = true
		var theme = (ca["theme"] if (ca["rg"] == rg) else cb["theme"])
		var chain = [a_id]
		var ok = true
		for _it in pts:
			var x = _it[0]
			var y = _it[1]
			if (not self.free(x, y, MIN_DIST)):
				var found = false
				for _ in range(8):
					var nx = (x + self.rnd((-8), 8))
					var ny = (y + self.rnd((-8), 8))
					if (self.free(nx, ny, MIN_DIST) and self.sil.inside(nx, ny, 1.14)):
						var _tu_1215 = [nx, ny]
						x = _tu_1215[0]
						y = _tu_1215[1]
						found = true
						break
				if (not found):
					ok = false
					break
			var st = self.themed_stats(rg, theme, y)
			var nid = self[self.uid("tr")] = true
			if (not nid):
				ok = false
				break
			chain.append(nid)
		chain.append(b_id)
		if (not ok):
			var _tu_1230 = [((ax + bx) / 2), ((ay + by) / 2)]
			var mx = _tu_1230[0]
			var my = _tu_1230[1]
			if (gap <= (STEP * 2.0)):
				self.ln(a_id, b_id)
			elif (self.free(mx, my, MIN_DIST) and self.sil.inside(mx, my, 1.16)):
				st = self.themed_stats(rg, theme, my)
				mid = self[self.uid("tr")] = true
				if mid:
					self.ln(a_id, mid)
					self.ln(mid, b_id)
			continue
		for _it in _zip(chain, chain.slice(1, 2147483647)):
			var u = _it[0]
			var v = _it[1]
			if (not self.ln(u, v)):
				break

func place_core():
	var _tu_1248 = [0.0, (self.sil.trunk_top + 20)]
	var x = _tu_1248[0]
	var y = _tu_1248[1]
	if (not self.free(x, y, MIN_DIST)):
		for r in range(10, 60, 8):
			for k in range(8):
				var ang = ((k * TAU) / 8)
				if self.free((x + (r * cos(ang))), (y + (r * sin(ang))), MIN_DIST):
					x += (r * cos(ang))
					y += (r * sin(ang))
					break
	var st = {"hp_pct": 8, "dmg_pct": 6, "cdr_pct": 4}
	var nid = self["core_heart"] = true
	if (not nid):
		return
	var others = _sorted_with_key(self.nodes, func(n): return (dist([n["x"], n["y"]], [x, y]) if (n["id"] != nid) else 1000000000.0), false)
	var linked = 0
	for n in others:
		if (n["id"] == nid):
			continue
		if self.ln(nid, n["id"]):
			linked += 1
		if (linked >= 3):
			break

func adj():
	var a = {}
	for _it in self.links:
		var u = _it[0]
		var v = _it[1]
		a[u].append(v)
		a[v].append(u)
	return a

func hops(src, dst, allowed = null):
	"Hop count excluding src, including dst. Start costs 0 in game, every other node 1."
	if ((not (src in self.by)) or (not (dst in self.by))):
		return [null, []]
	var adj = self.adj()
	var q = ([src]).duplicate()
	var prev = {src: null}
	while q:
		var u = q.pop_front()
	if (not (dst in prev)):
		return [null, []]
	var path = []
	var cur = dst
	while (cur != null):
		path.append(cur)
	path.reverse()
	var _ge1 = []
	for i in path.slice(1, 2147483647):
		if (self.by[i]["type"] != "start"):
			_ge1.append(1)
	var cost = _sum(_ge1)
	return [cost, path]

func pick_tops():
	var tops = {}
	var _lc1 = []
	for n in self.nodes:
		if ((n["type"] == "keystone") and (n["region"] == rg)):
			_lc1.append(n)
	for rg in BR:
		var ks = _lc1
		if (not ks):
			tops[rg] = null
			continue
		var score = func(n):
			if (rg == "str"):
				return ((n["y"] * 1.0) - (n["x"] * 0.55))
			if (rg == "faith"):
				return ((n["y"] * 1.0) + (n["x"] * 0.55))
			return ((n["y"] * 1.15) - (abs(n["x"]) * 0.08))
		ks.sort()
		tops[rg] = ks[0]["id"]
	self.top = tops
	return tops

func reconnect_orphans():
	var adj = self.adj()
	var _lc1 = []
	for r in BR:
		if (START_ID[r] in self.by):
			_lc1.append(START_ID[r])
	var starts = _lc1
	var seen = {}
	var q = (starts).duplicate()
	for s in starts:
		seen[s] = true
	while q:
		var u = q.pop_front()
	_lc1 = []
	for n in self.nodes:
		if (not (n["id"] in seen)):
			_lc1.append(n)
	var orphans = _lc1
	for n in orphans:
		var _tu_1346 = [n["x"], n["y"]]
		var nx = _tu_1346[0]
		var ny = _tu_1346[1]
		var cands = _sorted_with_key(self.nodes, func(o): return dist([o["x"], o["y"]], [nx, ny]), false)
		for o in cands.slice(1, 30):
			if (not (o["id"] in seen)):
				continue
			if self.ln(n["id"], o["id"]):
				seen[n["id"]] = true
				break
	adj = self.adj()
	seen = {}
	q = (starts).duplicate()
	for s in starts:
		seen[s] = true
	while q:
		u = q.pop_front()
	var keep = []
	var drop = {}
	for n in self.nodes:
		if ((n["id"] in seen) or (n["type"] in ["start", "keystone", "core"])):
			keep.append(n)
		else:
			drop[n["id"]] = true
	var _dc1 = {}
	for n in self.nodes:
		_dc1[n["id"]] = n
	var _lc2 = []
	for L in self.links:
		if ((not (L[0] in drop)) and (not (L[1] in drop))):
			_lc2.append(L)
	var _lc3 = []
	for s in self.seglinks:
		if ((not (s[2] in drop)) and (not (s[3] in drop))):
			_lc3.append(s)
	var _lc4 = []
	for n in self.nodes:
		_lc4.append([n["x"], n["y"]])
	if drop:
		self.nodes = keep
		self.by = _dc1
		self.links = _lc2
		self.seglinks = _lc3
		self.deg = {}
		for _it in self.links:
			var a = _it[0]
			var b = _it[1]
			self.deg[a] += 1
			self.deg[b] += 1
		self.occ = _lc4
	return drop.size()

func add_shortcuts(want_reduce = true):
	"Add a few same-region short links to shorten long own-paths, or none."
	if (not want_reduce):
		return 0
	var added = 0
	var by_rg = {}
	for n in self.nodes:
		if (n["type"] == "small"):
			by_rg[n["region"]].append(n)
	for _it in _items(by_rg):
		var rg = _it[0]
		var arr = _it[1]
		_shuffle(_rng, arr)
		for n in arr.slice(0, 80):
			if (added >= 14):
				return added
			if (self.deg[n["id"]] >= 4):
				continue
			var cands = _sorted_with_key(arr, func(o): return dist([o["x"], o["y"]], [n["x"], n["y"]]), false).slice(1, 8)
			for o in cands:
				if (self.deg[o["id"]] >= 4):
					continue
				var d = dist([o["x"], o["y"]], [n["x"], n["y"]])
				if ((d < (MIN_DIST * 1.1)) or (d > (STEP * 1.55))):
					continue
				if self.ln(n["id"], o["id"]):
					added += 1
					break
	return added

func pad_long_corridors(extra = 1):
	"Subdivide mid-length links that aren't in a tight wheel, to lengthen paths."
	if (extra <= 0):
		return 0
	var old = self.links
	var added = 0
	var _lc1 = []
	for L in self.links:
		if (_sorted(L) != _sorted([a, b])):
			_lc1.append(L)
	var _lc2 = []
	for s in self.seglinks:
		if (_sorted([s[2], s[3]]) != _sorted([a, b])):
			_lc2.append(s)
	for _it in old:
		var a = _it[0]
		var b = _it[1]
		if ((not (a in self.by)) or (not (b in self.by))):
			continue
		var _tu_1424 = self.pos(a)
		var ax = _tu_1424[0]
		var ay = _tu_1424[1]
		var _tu_1425 = self.pos(b)
		var bx = _tu_1425[0]
		var by = _tu_1425[1]
		var d = dist([ax, ay], [bx, by])
		if ((d < (STEP * 1.05)) or (d > (STEP * 1.8))):
			continue
		if ((self.by[a]["type"] != "small") or (self.by[b]["type"] != "small")):
			continue
		var _tu_1432 = [((ax + bx) / 2), ((ay + by) / 2)]
		var mx = _tu_1432[0]
		var my = _tu_1432[1]
		if (not self.free(mx, my, MIN_DIST)):
			continue
		var rg = self.by[a]["region"]
		var st = self.themed_stats(rg, ("life" if (rg == "str") else ("evasion" if (rg == "agi") else "support")), my)
		var nid = self[self.uid("pd")] = true
		if (not nid):
			continue
		self.links = _lc1
		self.seglinks = _lc2
		self.deg[a] -= 1
		self.deg[b] -= 1
		if (self.ln(a, nid) and self.ln(nid, b)):
			added += 1
		else:
			self.ln(a, b)
	return added

func _insert_mid(a, b, mind = MIN_DIST):
	if ((not (a in self.by)) or (not (b in self.by))):
		return null
	var _tu_1456 = self.pos(a)
	var ax = _tu_1456[0]
	var ay = _tu_1456[1]
	var _tu_1457 = self.pos(b)
	var bx = _tu_1457[0]
	var by = _tu_1457[1]
	var _tu_1458 = [((ax + bx) / 2.0), ((ay + by) / 2.0)]
	var mx = _tu_1458[0]
	var my = _tu_1458[1]
	if (not self.free(mx, my, mind)):
		var _tu_1461 = [(bx - ax), (by - ay)]
		var dx = _tu_1461[0]
		var dy = _tu_1461[1]
		var L = (sqrt((dx)*(dx)+(dy)*(dy)) or 1)
		for s in [6, (-6), 10, (-10), 14, (-14)]:
			var _tu_1464 = [(mx - ((dy / L) * s)), (my + ((dx / L) * s))]
			var tx = _tu_1464[0]
			var ty = _tu_1464[1]
			if (self.free(tx, ty, mind) and self.sil.inside(tx, ty, 1.18)):
				var _tu_1466 = [tx, ty]
				mx = _tu_1466[0]
				my = _tu_1466[1]
				break
	var rg = self.by[a]["region"]
	var theme_key = THEMES[rg][0]
	var st = self.themed_stats(rg, theme_key, my)
	var nid = self[self.uid("sp")] = true
	if (not nid):
		return null
	var _lc1 = []
	for L in self.links:
		if (_sorted(L) != _sorted([a, b])):
			_lc1.append(L)
	self.links = _lc1
	_lc1 = []
	for s in self.seglinks:
		if (_sorted([s[2], s[3]]) != _sorted([a, b])):
			_lc1.append(s)
	self.seglinks = _lc1
	if (self.deg[a] > 0):
		self.deg[a] -= 1
	if (self.deg[b] > 0):
		self.deg[b] -= 1
	var ok1 = self.ln(a, nid)
	var ok2 = self.ln(nid, b)
	if (not (ok1 and ok2)):
		if (ok1 or ok2):
			return nid
		self.ln(a, b)
		return null
	return nid

func prune_high_cross_links(ymax = 350.0):
	"Drop mid/upper cross-region links so opposite tops stay expensive (C1)."
	var keep = []
	for _it in self.links:
		var a = _it[0]
		var b = _it[1]
		if ((not (a in self.by)) or (not (b in self.by))):
			continue
		if (self.by[a]["region"] != self.by[b]["region"]):
			var my = ((self.by[a]["y"] + self.by[b]["y"]) / 2.0)
			if (my > ymax):
				continue
		keep.append([a, b])
	self.links = keep
	self.deg = {}
	self.seglinks = []
	for _it in self.links:
		a = _it[0]
		b = _it[1]
		self.deg[a] += 1
		self.deg[b] += 1
		self.seglinks.append([self.pos(a), self.pos(b), a, b])

func split_long_links(cap = null):
	var cap = (cap or (STEP * 1.55))
	var guard = 0
	var _lc1 = []
	for _it in long.slice(1, 2147483647):
		var dd = _it[0]
		var aa = _it[1]
		var bb = _it[2]
		if (not (_sorted([aa, bb]) in self._split_skip)):
			_lc1.append(1)
	while (guard < 400):
		guard += 1

func lengthen_own_paths(lo = 80, hi = 88):
	self.pick_tops()
	var _ge1 = []
	for _it in _zip(path, path.slice(1, 2147483647)):
		var a = _it[0]
		var b = _it[1]
		if ((a in self.by) and (b in self.by) and (dist(self.pos(a), self.pos(b)) >= (STEP * 0.85))):
			_ge1.append([dist(self.pos(a), self.pos(b)), a, b])
	for rg in BR:
		var _tu_1543 = [START_ID[rg], self.top.get(rg, null)]
		var sid = _tu_1543[0]
		var tid = _tu_1543[1]
		if (not tid):
			continue
		for _ in range(50):
			var _tu_1547 = self.hops(sid, tid)
			var cost = _tu_1547[0]
			var path = _tu_1547[1]
			if ((cost == null) or (cost >= lo)):
				break
			var best = null
			for _it in _zip(path, path.slice(1, 2147483647)):
				var u = _it[0]
				var v = _it[1]
				if ((not (u in self.by)) or (not (v in self.by))):
					continue
				var d = dist(self.pos(u), self.pos(v))
				if (d < (STEP * 0.95)):
					continue
				if ((best == null) or (d > best[0])):
					best = [d, u, v]
			if (not best):
				break
			if (not self._insert_mid(best[1], best[2])):
				var inserted = false
				for _it in _sorted(_ge1).slice(1, 8):
					d = _it[0]
					u = _it[1]
					v = _it[2]
					if self._insert_mid(u, v):
						inserted = true
						break
				if (not inserted):
					break

func export_nodes():
	var out = []
	for n in self.nodes:
		var m = n
		m["x"] = round((n["x"] * SCALE))
		m["y"] = round(((-n["y"]) * SCALE))
		if (m["x"] == 0):
			m["x"] = 0.0
		if (m["y"] == 0):
			m["y"] = 0.0
		out.append(m)
	return out

func metrics():
	var _lc1 = []
	for n in self.nodes:
		_lc1.append(n["x"])
	var xs = _lc1
	_lc1 = []
	for n in self.nodes:
		_lc1.append(n["y"])
	var ys = _lc1
	var lens = []
	for _it in self.links:
		var a = _it[0]
		var b = _it[1]
		if ((a in self.by) and (b in self.by)):
			lens.append(dist(self.pos(a), self.pos(b)))
	var md = 1000000000.0
	_lc1 = []
	for n in self.nodes:
		_lc1.append([n["x"], n["y"]])
	var pts = _lc1
	for i in range(pts.size()):
		for j in range((i + 1), pts.size()):
			var d = dist(pts[i], pts[j])
			if (d < md):
				md = d
	var cross = 0
	_lc1 = []
	for _it in self.links:
		a = _it[0]
		b = _it[1]
		if ((a in self.by) and (b in self.by)):
			_lc1.append([[self.by[a]["x"], self.by[a]["y"]], [self.by[b]["x"], self.by[b]["y"]], a, b])
	var segs = _lc1
	for i in range(segs.size()):
		for j in range((i + 1), segs.size()):
			var _tu_1613 = segs[i]
			var a1 = _tu_1613[0]
			var b1 = _tu_1613[1]
			var u = _tu_1613[2]
			var v = _tu_1613[3]
			var _tu_1614 = segs[j]
			var a2 = _tu_1614[0]
			var b2 = _tu_1614[1]
			var p = _tu_1614[2]
			var q = _tu_1614[3]
			if _set_and(_to_set([u, v]), _to_set([p, q])):
				continue
			if seg_intersect(a1, b1, a2, b2):
				cross += 1
	var adj = self.adj()
	_lc1 = []
	for r in BR:
		if (START_ID[r] in self.by):
			_lc1.append(START_ID[r])
	var starts = _lc1
	var seen = _to_set(starts)
	q = (starts).duplicate()
	while q:
		u = q.pop_front()
	var orphans = (self.nodes.size() - seen.size())
	var _ge1 = []
	for n in self.nodes:
		if ((n["description"] != self.desc(n["stats"])) and (n["type"] != "start")):
			_ge1.append(1)
	var mism = _sum(_ge1)
	_ge1 = []
	for n in self.nodes:
		for k in n["stats"]:
			if (not (k in WIRED)):
				_ge1.append(1)
	var unwired = _sum(_ge1)
	var maxdeg = (max(_values(self.deg)) if self.deg else 0)
	var name_max = (max(_values(self.nm)) if self.nm else 0)
	self.pick_tops()
	var paths = {}
	for rg in BR:
		var _tu_1642 = [START_ID[rg], self.top.get(rg, null)]
		var sid = _tu_1642[0]
		var tid = _tu_1642[1]
		var _tu_1643 = self.hops(sid, tid)
		var own = _tu_1643[0]
		var op = _tu_1643[1]
		var _tu_1644 = self.hops(sid, tid)
		var locked = _tu_1644[0]
		var _lp = _tu_1644[1]
		var _tu_1645 = [own, op]
		var anyc = _tu_1645[0]
		var ap = _tu_1645[1]
		var hyb = {}
		for og in BR:
			if (og == rg):
				continue
			var ot = self.top.get(og, null)
			var _tu_1651 = self.hops(sid, ot)
			var hc = _tu_1651[0]
			var hp = _tu_1651[1]
			hyb[og] = [hc, hp]
		paths[rg] = {"own": own, "own_path": op, "any": anyc, "locked": locked, "hyb": hyb}
	var mean_l = ((_sum(lens) / lens.size()) if lens else 0)
	_ge1 = []
	for n in self.nodes:
		_ge1.append(n["type"])
	var _ge2 = []
	for n in self.nodes:
		_ge2.append(n["region"])
	return {"N": self.nodes.size(), "links": self.links.size(), "types": _counter(_ge1), "regions": _counter(_ge2), "link_min": (min(lens) if lens else 0), "link_mean": mean_l, "link_max": (max(lens) if lens else 0), "min_node_dist": md, "max_degree": maxdeg, "crossings": cross, "orphans": orphans, "desc_mismatch": mism, "name_max_repeat": name_max, "unwired": unwired, "paths": paths, "top": self.top, "bbox": [min(xs), max(xs), min(ys), max(ys)]}

func widen_crown(factor = 1.18, silhouette = 1.34):
	"Mild horizontal scale of the existing crown; enlarge the\n        silhouette so side space can be filled into a rounder canopy."
	var sil = self.sil
	self._old_crx = sil.crx
	var y_lo = sil.trunk_top
	var y_hi = (sil.cy + (sil.cry * 0.25))
	var fac = func(y):
		if (y <= y_lo):
			return 1.0
		var t = ((y - y_lo) / max(1.0, (y_hi - y_lo)))
		t = max(0.0, min(1.0, t))
		var sm = ((t * t) * (3.0 - (2.0 * t)))
		return (1.0 + ((factor - 1.0) * sm))
	for n in self.nodes:
		var f = fac(n["y"])
		if (f != 1.0):
			n["x"] *= f
	sil.crx = (self._old_crx * silhouette)
	var _lc1 = []
	for n in self.nodes:
		_lc1.append([n["x"], n["y"]])
	self.occ = _lc1
	self.seglinks = []
	for _it in self.links:
		var a = _it[0]
		var b = _it[1]
		if ((a in self.by) and (b in self.by)):
			self.seglinks.append([self.pos(a), self.pos(b), a, b])

func fill_crown_wings():
	"Grow compact wheels outward in 3 layers so the new side space\n        becomes a filled, rounded bulge rather than a long arm."
	var sil = self.sil
	var rng = _make_rng((self.seed + 72))
	var region_of = func(x, y):
		if (x < (sil.cx - 20)):
			return "str"
		if (x > (sil.cx + 20)):
			return "faith"
		return "agi"
	var cands = []
	for ang_deg in range(10, 171, 7):
		for radf in [0.64, 0.74, 0.83, 0.9, 0.95]:
			if ((80 <= ang_deg) and (ang_deg <= 100) and (radf < 0.85)):
				continue
			var ang = deg_to_rad(ang_deg)
			var r = (sil.crown_r(ang) * radf)
			var x = (sil.cx + (r * cos(ang)))
			var y = (sil.cy + (r * sin(ang)))
			if (y < (sil.trunk_top + 20)):
				continue
			if (not sil.in_crown(x, y, 0.99)):
				continue
			if (abs(x) < (self._old_crx * 0.48)):
				continue
			cands.append([x, y, region_of(x, y)])
	var nearest_same = func(x, y, rg, exclude):
		var best = null
		for n in self.nodes:
			if ((n["region"] != rg) or (n["id"] in exclude)):
				continue
			if (self.deg[n["id"]] >= MAX_DEG):
				continue
			var g = dist([x, y], [n["x"], n["y"]])
			if ((best == null) or (g < best[0])):
				best = [g, n]
		return best
	var placed = 0
	var max_place = 20
	for max_gap in [72, 88, 100]:
		_shuffle(_rng, cands)
		for _it in cands:
			x = _it[0]
			y = _it[1]
			var rg = _it[2]
			if (placed >= max_place):
				return
			if (not self.free(x, y, 58)):
				continue
			var near = nearest_same(x, y, rg)
			if ((near == null) or (near[0] > max_gap) or (near[0] < (MIN_DIST * 1.2))):
				continue
			var theme = THEMES[rg][rng.randi_range(0, (THEMES[rg].size()) - 1)]
			var ring = self._ring(x, y, 24.0, 4, rg, theme, false)
			if (ring.size() < 3):
				continue
			for _it in _zip(ring, (ring.slice(1, 2147483647) + ring.slice(0, 1))):
				var a = _it[0]
				var b = _it[1]
				self.ln(a, b)
			var best = null
			for pid in ring:
				if (self.deg[pid] >= MAX_DEG):
					continue
				var _tu_1774 = self.pos(pid)
				var px = _tu_1774[0]
				var py = _tu_1774[1]
				var g = dist([px, py], [near[1]["x"], near[1]["y"]])
				if ((best == null) or (g < best[0])):
					best = [g, pid]
			if (best == null):
				continue
			var _tu_1780 = best
			var gap = _tu_1780[0]
			var port = _tu_1780[1]
			var tgt = near[1]
			var _tu_1782 = self.pos(port)
			px = _tu_1782[0]
			py = _tu_1782[1]
			var _tu_1783 = [tgt["x"], tgt["y"]]
			var tx = _tu_1783[0]
			var ty = _tu_1783[1]
			var k = max(0, min(2, (int(round((gap / STEP))) - 1)))
			if (k <= 0):
				if (not self.ln(port, tgt["id"])):
					continue
			else:
				var chain = [port]
				var ok = true
				for i in range(1, (k + 1)):
					var t = (i / (k + 1))
					var wx = (px + ((tx - px) * t))
					var wy = (py + ((ty - py) * t))
					if ((not self.free(wx, wy, MIN_DIST)) or (not sil.inside(wx, wy, 1.15))):
						ok = false
						break
					var st = self.themed_stats(rg, theme, wy)
					var nid = self[self.uid("wg")] = true
					if (not nid):
						ok = false
						break
					chain.append(nid)
				chain.append(tgt["id"])
				if (not ok):
					continue
				for _it in _zip(chain, chain.slice(1, 2147483647)):
					var u = _it[0]
					var v = _it[1]
					self.ln(u, v)
			placed += 1

func thicken_lobe_skirts():
	"Grow one or two compact rows under each side lobe, attached\n        back into the dense canopy — fills the shoulder without a spur."
	var sil = self.sil
	var rng = _make_rng((self.seed + 74))
	var _lc1 = []
	for n in self.nodes:
		if ((n["region"] in ["str", "faith"]) and ((sil.cy - 40) <= n["y"]) and (n["y"] <= (sil.cy + 90)) and (abs(n["x"]) >= (self._old_crx * 0.5))):
			_lc1.append(n)
	var seeds = _lc1
	var placed = 0
	_shuffle(_rng, seeds)
	_lc1 = []
	for o in self.nodes:
		if ((o["region"] == n["region"]) and ((MIN_DIST * 1.15) <= dist([x, y], [o["x"], o["y"]])) and (dist([x, y], [o["x"], o["y"]]) <= 95)):
			_lc1.append(o)
	for n in seeds:
		for _it in [[55, 30], [95, 55], [70, 80]]:
			var down = _it[0]
			var out = _it[1]
			if (placed >= 8):
				return
			var x = (n["x"] + (out if (n["x"] > 0) else (-out)))
			var y = (n["y"] - down)
			if (y < (sil.trunk_top + 40)):
				continue
			if (not sil.inside(x, y, 1.08)):
				continue
			if (not self.free(x, y, 58)):
				continue
			var near = _lc1
			if (near.size() < 2):
				continue
			var rg = n["region"]
			var theme = THEMES[rg][rng.randi_range(0, (THEMES[rg].size()) - 1)]
			var ring = self._ring(x, y, 24.0, 4, rg, theme, false)
			if (ring.size() < 3):
				continue
			for _it in _zip(ring, (ring.slice(1, 2147483647) + ring.slice(0, 1))):
				var a = _it[0]
				var b = _it[1]
				self.ln(a, b)
			var made = 0
			near.sort()
			for o in near.slice(0, 6):
				if (made >= 2):
					break
				if (self.deg[o["id"]] >= MAX_DEG):
					continue
				var best = null
				for pid in ring:
					if (self.deg[pid] >= MAX_DEG):
						continue
					var g = dist(self.pos(pid), [o["x"], o["y"]])
					if ((MIN_DIST * 1.1) <= g) and (g <= 100):
						if ((best == null) or (g < best[0])):
							best = [g, pid]
				if (best and self.ln(best[1], o["id"])):
					made += 1
			if (made >= 1):
				placed += 1

func fill_armpits():
	"Fill the concave shoulders under the side lobes so the canopy\n        reads rounder, attaching both down to the collar and up to the lobe."
	var sil = self.sil
	var rng = _make_rng((self.seed + 73))
	var pts = [[(-0.58), 0.12, "str"], [(-0.72), 0.22, "str"], [(-0.65), 0.34, "str"], [0.58, 0.12, "faith"], [0.72, 0.22, "faith"], [0.65, 0.34, "faith"]]
	var _lc1 = []
	for n in self.nodes:
		if ((n["region"] == rg) and (not (n["id"] in ring))):
			_lc1.append(n)
	for _it in pts:
		var xf = _it[0]
		var yf = _it[1]
		var rg = _it[2]
		var x = (sil.cx + (sil.crx * xf))
		var y = (sil.trunk_top + (((sil.cy + (sil.cry * 0.15)) - sil.trunk_top) * yf))
		if (not sil.inside(x, y, 1.05)):
			continue
		if (not self.free(x, y, 56)):
			continue
		var theme = THEMES[rg][rng.randi_range(0, (THEMES[rg].size()) - 1)]
		var ring = self._ring(x, y, 24.0, 4, rg, theme, false)
		if (ring.size() < 3):
			continue
		for _it in _zip(ring, (ring.slice(1, 2147483647) + ring.slice(0, 1))):
			var a = _it[0]
			var b = _it[1]
			self.ln(a, b)
		var others = _lc1
		var attachments = []
		for pid in ring:
			var _tu_1895 = self.pos(pid)
			var px = _tu_1895[0]
			var py = _tu_1895[1]
			for n in others:
				if ((self.deg[n["id"]] >= MAX_DEG) or (self.deg[pid] >= MAX_DEG)):
					continue
				var g = dist([px, py], [n["x"], n["y"]])
				if ((MIN_DIST * 1.1) <= g) and (g <= 135):
					attachments.append([g, pid, n])
		attachments.sort()
		var used_tgt = {}
		var made = 0
		for _it in attachments:
			g = _it[0]
			var port = _it[1]
			var tgt = _it[2]
			if (made >= 2):
				break
			if (tgt["id"] in used_tgt):
				continue
			if ((self.deg[port] >= MAX_DEG) or (self.deg[tgt["id"]] >= MAX_DEG)):
				continue
			var _tu_1912 = self.pos(port)
			px = _tu_1912[0]
			py = _tu_1912[1]
			var _tu_1913 = [tgt["x"], tgt["y"]]
			var tx = _tu_1913[0]
			var ty = _tu_1913[1]
			var k = max(0, min(3, (int(round((g / STEP))) - 1)))
			if (k <= 0):
				if self.ln(port, tgt["id"]):
					used_tgt[tgt["id"]] = true
					made += 1
			else:
				var chain = [port]
				var ok = true
				for i in range(1, (k + 1)):
					var t = (i / (k + 1))
					var wx = (px + ((tx - px) * t))
					var wy = (py + ((ty - py) * t))
					if ((not self.free(wx, wy, MIN_DIST)) or (not sil.inside(wx, wy, 1.15))):
						ok = false
						break
					var st = self.themed_stats(rg, theme, wy)
					var nid = self[self.uid("ap")] = true
					if (not nid):
						ok = false
						break
					chain.append(nid)
				chain.append(tgt["id"])
				if (not ok):
					continue
				var good = true
				for _it in _zip(chain, chain.slice(1, 2147483647)):
					var u = _it[0]
					var v = _it[1]
					if (not self.ln(u, v)):
						good = false
						break
				if good:
					used_tgt[tgt["id"]] = true
					made += 1

func integrate_wings():
	"Add a second same-region link on new side clusters so they mesh\n        into the canopy instead of hanging off a single corridor."
	var _lc1 = []
	for n in self.nodes:
		if (n["y"] > (self.sil.trunk_top - 10)):
			_lc1.append(n)
	var crown = _lc1
	var added = 0
	for n in crown:
		if ((n["type"] != "small") or (abs(n["x"]) < (self._old_crx * 0.45))):
			continue
		if (self.deg[n["id"]] >= 4):
			continue
		var cands = []
		for o in crown:
			if ((o["id"] == n["id"]) or (o["region"] != n["region"])):
				continue
			if (self.deg[o["id"]] >= MAX_DEG):
				continue
			var g = dist([n["x"], n["y"]], [o["x"], o["y"]])
			if ((MIN_DIST * 1.15) <= g) and (g <= (STEP * 1.65)):
				cands.append([g, o])
		cands.sort()
		for _it in cands.slice(0, 6):
			g = _it[0]
			var o = _it[1]
			if self.ln(n["id"], o["id"]):
				added += 1
				break
		if (added >= 24):
			return

func cap_opposite(slack = 20):
	"If an opposite top is above own+slack, add a short same-region\n        chord that shaves a hop or two without dropping own below 80."
	var _lc1 = []
	for L in snap_links:
		_lc1.append(L)
	var rollback = func(u, v, snap_links, snap_deg, snap_seg):
		self.links = _lc1
		self.deg = snap_deg.duplicate(true)
		self.seglinks = snap_seg
	_lc1 = []
	for L in self.links:
		_lc1.append(L)
	for _try in range(6):
		var m = self.metrics()
		var over = []
		for rg in BR:
			var own = m["paths"][rg]["own"]
			for _it in _items(m["paths"][rg]["hyb"]):
				var og = _it[0]
				var pair = _it[1]
				var _tu_1990 = pair
				var hc = _tu_1990[0]
				var hp = _tu_1990[1]
				if ((own == null) or (hc == null) or (hp == null)):
					continue
				if ((rg in ["str", "faith"]) and (og in ["str", "faith"]) and (hc > (own + slack))):
					over.append([((hc - own) - slack), rg, og, hp, own, hc])
		if (not over):
			return
		over.sort()
		var _tu_1998 = over[0]
		var _ = _tu_1998[0]
		var rg = _tu_1998[1]
		og = _tu_1998[2]
		hp = _tu_1998[3]
		own = _tu_1998[4]
		hc = _tu_1998[5]
		var shaved = false
		for skip in [2, 3]:
			for i in range(0, max(0, (hp.size() - skip))):
				var _tu_2002 = [hp[i], hp[(i + skip)]]
				var u = _tu_2002[0]
				var v = _tu_2002[1]
				if ((not (u in self.by)) or (not (v in self.by))):
					continue
				if (self.by[u]["region"] != self.by[v]["region"]):
					continue
				if ((self.deg[u] >= MAX_DEG) or (self.deg[v] >= MAX_DEG)):
					continue
				var d = dist(self.pos(u), self.pos(v))
				if ((d < (MIN_DIST * 1.1)) or (d > (STEP * 1.7))):
					continue
				var snap_links = _lc1
				var snap_deg = self.deg.duplicate(true)
				var snap_seg = self.seglinks
				if (not self.ln(u, v)):
					continue
				var m2 = self.metrics()
				var bad = false
				for r2 in BR:
					var o2 = m2["paths"][r2]["own"]
					if ((o2 != null) and (o2 < 80)):
						bad = true
				if (m2["crossings"] > 0):
					bad = true
				if bad:
					rollback(u, v, snap_links, snap_deg, snap_seg)
					continue
				shaved = true
				break
			if shaved:
				break
		if (not shaved):
			return

func build_tree():
	self.sample_sites()
	self.site_graph()
	self.place_clusters()
	self.connect_clusters()
	self.place_core()
	self.reconnect_orphans()
	self.prune_high_cross_links(350.0)
	self.reconnect_orphans()
	self.split_long_links((STEP * 1.55))
	self.lengthen_own_paths(80, 88)
	self.split_long_links((STEP * 1.58))
	self.widen_crown()
	self.split_long_links((STEP * 1.55))
	self.fill_crown_wings()
	self.thicken_lobe_skirts()
	self.integrate_wings()
	self.split_long_links((STEP * 1.58))
	self.prune_high_cross_links(350.0)
	self.reconnect_orphans()
	self.lengthen_own_paths(80, 88)
	self.split_long_links((STEP * 1.58))
	self.cap_opposite()
	var m = self.metrics()
	var _lc1 = []
	for rg in BR:
		if (m["paths"][rg]["own"] != null):
			_lc1.append(m["paths"][rg]["own"])
	var owns = _lc1
	if (owns and (min(owns) > 95)):
		self.add_shortcuts(true)
		self.reconnect_orphans()
		m = self.metrics()
	return m


func build(p_seed: int, progress: Callable = Callable()) -> String:
	_progress = progress
	_g_init(p_seed)
	if progress.is_valid():
		progress.call(0.05, "Силует…")
	build_tree()
	return ""

func tree_dict() -> Dictionary:
	var exported = export_nodes()
	return {
		"format": "perk_tree_v4",
		"version": 4,
		"title": "Древо звитяги",
		"comment": "Згенеровано TreeGenV7Core (GDScript-порт v7)",
		"regions": REGIONS,
		"class_starts": CLASS_STARTS,
		"nodes": exported,
		"links": links,
		"meta": {
			"generator": "tree_gen_v7_core.gd",
			"seed": seed,
			"scale": SCALE,
			"needs_wiring": NEEDS_WIRING,
			"version_tag": "v7.2-gd",
		},
	}

func report(frac: float, msg: String) -> void:
	if _progress.is_valid():
		_progress.call(frac, msg)
