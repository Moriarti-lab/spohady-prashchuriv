## Чистий GDScript-генератор Древа v7-сумісний за валідаторами (не байт-ідентичний з Python).
## Seed детермінує силует і розклад; метрики: crossings=0, orphans=0, mindist, own tops 80–88, desc==stats, unwired=0.
class_name TreeGenV7Core
extends RefCounted

const SCALE := 10
const MIN_DIST := 18.0
const STEP := 26.0
const MAX_DEG := 5
const BR := ["str", "agi", "faith"]
const START_ID := {"str": "s_root", "agi": "a_root", "faith": "f_root"}
const CLASS_STARTS := {"druzhynnyk": "s_root", "strilets": "a_root", "volkhv": "f_root"}
const REGIONS := [
	{"id": "str", "name": "Сила", "color": "#C62828"},
	{"id": "agi", "name": "Спритність", "color": "#2E7D32"},
	{"id": "faith", "name": "Віра", "color": "#F9A825"},
]
const WIRED := {
	"str": true, "agi": true, "faith": true, "hp": true, "hp_pct": true, "mana_pct": true,
	"mana_regen": true, "mana_regen_pct": true, "armor": true, "dmg_pct": true, "atk_speed_pct": true,
	"crit_pct": true, "crit_dmg_pct": true, "cdr_pct": true, "lifesteal_pct": true, "thorns_pct": true,
	"hp_regen_pct": true, "dr_pct": true, "move_pct": true, "dodge_pct": true, "block_pct": true,
	"block_power_pct": true, "aoe_pct": true, "effect_dur_pct": true, "skill_cost_pct": true,
	"nauz_xp_pct": true, "one_path": true, "free_skills": true, "block_no_shield": true,
}
const THEMES := {
	"str": {"life": ["hp", "hp_pct", "lifesteal_pct"], "melee": ["dmg_pct", "atk_speed_pct", "str"], "armour": ["armor", "dr_pct", "block_pct"]},
	"agi": {"evasion": ["dodge_pct", "move_pct", "agi"], "ranged": ["dmg_pct", "atk_speed_pct", "agi"], "crit": ["crit_pct", "crit_dmg_pct", "atk_speed_pct"]},
	"faith": {"spell": ["dmg_pct", "aoe_pct", "faith"], "resource": ["mana_pct", "mana_regen", "cdr_pct"], "support": ["hp_regen_pct", "effect_dur_pct", "faith"]},
}
const TRAVEL := {"str": ["str", "hp", "armor"], "agi": ["agi", "move_pct", "hp"], "faith": ["faith", "mana_regen", "hp"]}
const STAT_NAMES := {
	"str": "Сила", "agi": "Спритність", "faith": "Віра", "dmg_pct": "шкоди", "hp_pct": "життя",
	"armor": "броні", "atk_speed_pct": "швидкості атаки", "hp": "життя", "lifesteal_pct": "лічі",
	"crit_pct": "крита", "dodge_pct": "ухилення", "move_pct": "руху", "crit_dmg_pct": "критичної шкоди",
	"cdr_pct": "відновлення", "mana_pct": "чару", "mana_regen": "відновлення чару", "aoe_pct": "площі",
	"block_pct": "блоку", "dr_pct": "захисту", "thorns_pct": "шипів", "hp_regen_pct": "регенерації",
	"effect_dur_pct": "тривалості", "nauz_xp_pct": "росту наузів", "skill_cost_pct": "вартості",
	"block_power_pct": "сили блоку", "one_path": "один шлях", "free_skills": "вільні вміння",
	"block_no_shield": "блок без щита", "mana_regen_pct": "відн. чару",
}
const NK := [
	["Один шлях", "str", {"dmg_pct": 25, "one_path": 1}],
	["Серце війни", "str", {"dmg_pct": 20, "armor": -12}],
	["Кривава данина", "str", {"lifesteal_pct": 8, "hp_pct": -10}],
	["Смертельна тінь", "agi", {"crit_dmg_pct": 30, "armor": -8}],
	["Серце полювання", "agi", {"crit_pct": 12, "hp_pct": -10}],
	["Гнів пращурів", "agi", {"aoe_pct": 20, "atk_speed_pct": -10}],
	["Вільні вміння", "faith", {"cdr_pct": 25, "free_skills": 1, "mana_pct": -15}],
	["Серце віри", "faith", {"dmg_pct": 20, "move_pct": -12}],
	["Щит без щита", "str", {"block_no_shield": 1, "block_pct": 12, "move_pct": -8}],
]
const NS := {
	"str": ["Жила сили", "Криця роду", "Міць предка", "Удар молота", "Щит стін", "Корінь дуба"],
	"agi": ["Тінь кроку", "Гостре око", "Сагайдак вітру", "Слід рисі", "Тетіва ясена", "Легкий крок"],
	"faith": ["Нитка долі", "Шепіт волхва", "Коло пращурів", "Іскра Сварога", "Чаша роси", "Світло капища"],
}

var seed: int = 0
var sil
var nodes: Array = []
var links: Array = []
var by: Dictionary = {}
var deg: Dictionary = {}
var occ: Array = []
var _rng: RandomNumberGenerator
var _uidc: int = 0
var _progress: Callable = Callable()
var _cancel: bool = false
var _nm: Dictionary = {}


func request_cancel() -> void:
	_cancel = true


func build(p_seed: int, progress: Callable = Callable()) -> String:
	seed = p_seed
	_progress = progress
	_cancel = false
	_rng = RandomNumberGenerator.new()
	_rng.seed = p_seed
	_uidc = 0
	nodes.clear()
	links.clear()
	by.clear()
	deg.clear()
	occ.clear()
	_nm.clear()
	sil = SilhouetteV7.new(p_seed)
	_report(0.05, "Силует…")
	_place_structure()
	if _cancel:
		return "Скасовано"
	_report(0.55, "Зв’язки…")
	_connect_all()
	if _cancel:
		return "Скасовано"
	_report(0.75, "Довжина шляхів…")
	_tune_paths()
	_report(0.82, "Довжина шляхів…")
	_force_own_tops()
	_report(0.9, "Перевірка…")
	_ensure_validators()
	_report(1.0, "Готово")
	return ""


func tree_dict() -> Dictionary:
	return {
		"format": "spohady-perk-tree",
		"version": 4,
		"title": "Древо звитяги",
		"comment": "Згенеровано на пристрої",
		"regions": REGIONS,
		"class_starts": CLASS_STARTS,
		"nodes": nodes.duplicate(true),
		"links": links.duplicate(true),
		"meta": {
			"generator": "tree_gen_v7_core.gd",
			"seed": seed,
			"scale": SCALE,
			"version_tag": "v7-gd",
		},
	}


func _report(f: float, msg: String) -> void:
	if _progress.is_valid():
		_progress.call(f, msg)


func _uid(p: String) -> String:
	_uidc += 1
	return "n%d_%s" % [_uidc, p]


func _pick_name(rg: String) -> String:
	var pool: Array = NS[rg]
	var best: String = pool[0]
	var best_c := 999
	for n in pool:
		var c: int = int(_nm.get(n, 0))
		if c < best_c:
			best_c = c
			best = n
	_nm[best] = best_c + 1
	return best


func _desc(st: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in st.keys():
		if not WIRED.has(k):
			continue
		var v: int = int(st[k])
		var nm: String = str(STAT_NAMES.get(k, k))
		if k in ["one_path", "free_skills", "block_no_shield"]:
			parts.append(nm)
		elif v >= 0:
			parts.append("+%d %s" % [v, nm])
		else:
			parts.append("%d %s" % [v, nm])
	return " · ".join(parts)


func _stats(rg: String, notable: bool = false) -> Dictionary:
	var themes: Dictionary = THEMES[rg]
	var keys: Array = themes.keys()
	var th: String = keys[_rng.randi_range(0, keys.size() - 1)]
	var pool: Array = themes[th]
	var st: Dictionary = {}
	var n: int = 2 if notable else (1 if _rng.randf() < 0.65 else 2)
	for i in range(mini(n, pool.size())):
		var k: String = pool[_rng.randi_range(0, pool.size() - 1)]
		var base := 4 if notable else 2
		st[k] = int(st.get(k, 0)) + _rng.randi_range(base, base + 3)
	# travel sprinkle
	if _rng.randf() < 0.35:
		var tk: String = TRAVEL[rg][_rng.randi_range(0, 2)]
		st[tk] = int(st.get(tk, 0)) + 1
	# filter wired only
	var out: Dictionary = {}
	for k in st.keys():
		if WIRED.has(k):
			out[k] = st[k]
	return out


func _free(x: float, y: float, m: float = MIN_DIST) -> bool:
	var md2 := m * m
	for p in occ:
		var dx: float = x - p[0]
		var dy: float = y - p[1]
		if dx * dx + dy * dy < md2:
			return false
	return true


func _add(nid: String, name: String, x: float, y: float, typ: String, st: Dictionary, rg: String, mind: float = MIN_DIST) -> String:
	if not _free(x, y, mind):
		# jitter
		var ok := false
		for _i in range(16):
			var jx := x + _rng.randf_range(-mind, mind)
			var jy := y + _rng.randf_range(-mind, mind)
			if sil.inside(jx, jy, 0.98) and _free(jx, jy, mind * 0.9):
				x = jx
				y = jy
				ok = true
				break
		if not ok:
			return ""
	var clean: Dictionary = {}
	for k in st.keys():
		if WIRED.has(k):
			clean[k] = st[k]
	var node := {
		"id": nid, "name": name, "description": _desc(clean),
		"x": x * SCALE, "y": -y * SCALE,  # game y-down-ish like v4 export
		"type": typ, "stats": clean, "skill": "", "icon": "", "region": rg,
	}
	nodes.append(node)
	by[nid] = node
	occ.append([x, y])
	deg[nid] = 0
	return nid


func _ln(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	if not by.has(a) or not by.has(b):
		return false
	if int(deg.get(a, 0)) >= MAX_DEG or int(deg.get(b, 0)) >= MAX_DEG:
		return false
	for L in links:
		if (L[0] == a and L[1] == b) or (L[0] == b and L[1] == a):
			return false
	# crossing check
	var ax: float = by[a]["x"] / SCALE
	var ay: float = -by[a]["y"] / SCALE
	var bx: float = by[b]["x"] / SCALE
	var byy: float = -by[b]["y"] / SCALE
	for L in links:
		var u: String = L[0]
		var v: String = L[1]
		if u == a or u == b or v == a or v == b:
			continue
		var ux: float = by[u]["x"] / SCALE
		var uy: float = -by[u]["y"] / SCALE
		var vx: float = by[v]["x"] / SCALE
		var vy: float = -by[v]["y"] / SCALE
		if _seg_intersect(Vector2(ax, ay), Vector2(bx, byy), Vector2(ux, uy), Vector2(vx, vy)):
			return false
	links.append([a, b])
	deg[a] = int(deg.get(a, 0)) + 1
	deg[b] = int(deg.get(b, 0)) + 1
	return true


func _ln_force(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	if not by.has(a) or not by.has(b):
		return false
	for L in links:
		if (L[0] == a and L[1] == b) or (L[0] == b and L[1] == a):
			return false
	links.append([a, b])
	deg[a] = int(deg.get(a, 0)) + 1
	deg[b] = int(deg.get(b, 0)) + 1
	return true


func _seg_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1 := b - a
	var d2 := d - c
	var cross := d1.x * d2.y - d1.y * d2.x
	if abs(cross) < 1e-8:
		return false
	var t := ((c.x - a.x) * d2.y - (c.y - a.y) * d2.x) / cross
	var u := ((c.x - a.x) * d1.y - (c.y - a.y) * d1.x) / cross
	return t > 0.02 and t < 0.98 and u > 0.02 and u < 0.98


func _place_structure() -> void:
	# Roots / starts
	var fans: Array = sil.fans
	for i in range(3):
		var rg: String = BR[i]
		var f: Array = fans[i]
		var x: float = f[0]
		var y: float = maxf(sil.root_y0 + 30.0, f[1] - 40.0)
		_add(START_ID[rg], {"str": "Корінь · Сила", "agi": "Корінь · Спритність", "faith": "Корінь · Віра"}[rg],
			x, y, "start", {rg: 5}, rg, MIN_DIST)
	# Crown keystones near tops of regions
	var ks_i := {"str": 0, "agi": 0, "faith": 0}
	for rg in BR:
		var cand: Array = []
		for row in NK:
			if row[1] == rg:
				cand.append(row)
		for k in range(mini(3, cand.size())):
			var ang: float = -PI * 0.5 + ([-0.9, 0.0, 0.9][BR.find(rg)]) + _rng.randf_range(-0.15, 0.15)
			var rr: float = float(sil.crown_r(ang)) * (0.55 + 0.12 * k)
			var x: float = sil.cx + cos(ang) * rr
			var y: float = sil.cy + sin(ang) * rr
			var row: Array = cand[k]
			_add(_uid("ks"), row[0], x, y, "keystone", row[2].duplicate(), rg)
	# Scaffold columns through trunk
	var ycol: float = float(sil.trunk_bot) + 16.0
	while ycol < float(sil.trunk_top) - 12.0 and not _cancel:
		var hw: float = float(sil.trunk_hw(ycol))
		for pair in [["str", -0.62], ["agi", 0.0], ["faith", 0.62]]:
			var rg2: String = pair[0]
			var xf: float = float(pair[1])
			_add(_uid("sc"), _pick_name(rg2), xf * hw * 0.78, ycol, "small", _stats(rg2), rg2)
		ycol += 38.0
	# Dense fill inside silhouette (hex-ish random)
	var target := 780 + (_rng.randi() % 80)
	var tries := 0
	while nodes.size() < target and tries < 40000 and not _cancel:
		tries += 1
		if tries % 800 == 0:
			_report(0.05 + 0.45 * float(nodes.size()) / float(target), "Вузли…")
		var bb: Array = sil.bbox()
		var x: float
		var y: float
		if _rng.randf() < 0.55:
			var ang := _rng.randf() * TAU
			var rad: float = float(sil.crown_r(ang)) * sqrt(_rng.randf()) * 0.96
			x = float(sil.cx) + cos(ang) * rad
			y = float(sil.cy) + sin(ang) * rad
		elif _rng.randf() < 0.5:
			y = _rng.randf_range(float(sil.trunk_bot), float(sil.trunk_top))
			x = _rng.randf_range(-1.0, 1.0) * float(sil.trunk_hw(y)) * 0.88
		else:
			x = _rng.randf_range(bb[0], bb[1])
			y = _rng.randf_range(bb[2], float(sil.trunk_bot) + 20.0)
		if not sil.inside(x, y, 0.96):
			continue
		if not _free(x, y, MIN_DIST):
			continue
		var reg: Array = sil.region(x, y)
		var rg: String = reg[0]
		var notable := _rng.randf() < (0.12 if sil.zone(x, y) == "crown" else 0.05)
		var typ := "notable" if notable else "small"
		var st := _stats(rg, notable)
		_add(_uid("n"), _pick_name(rg), x, y, typ, st, rg)
	# Core near trunk top
	var cx := 0.0
	var cy: float = float(sil.trunk_top) + 20.0
	_add("core_heart", "Серце роду", cx, cy, "core", {"hp_pct": 8, "dmg_pct": 6}, "agi")



func _connect_all() -> void:
	# 1) Explicit corridors start → top keystone (guarantees own path length)
	for rg in BR:
		if _cancel:
			return
		_build_own_corridor(rg, 86)
	# 2) Attach remaining nodes to nearest same-region linked node
	_attach_orphans_to_nearest()
	# 3) Core to three region hubs near trunk top
	if by.has("core_heart"):
		for rg in BR:
			var best := ""
			var bd := 1e18
			for n in nodes:
				if n["region"] != rg:
					continue
				var d := _dist_id("core_heart", n["id"])
				if d < bd:
					bd = d
					best = n["id"]
			if best != "":
				if not _ln(best, "core_heart"):
					_ln_force(best, "core_heart")


func _build_own_corridor(rg: String, target_hops: int) -> void:
	var sid: String = START_ID[rg]
	var tid := pick_top(rg)
	if tid == "" or not by.has(sid):
		return
	var ax: float = by[sid]["x"] / SCALE
	var ay: float = -by[sid]["y"] / SCALE
	var bx: float = by[tid]["x"] / SCALE
	var byy: float = -by[tid]["y"] / SCALE
	var prev := sid
	var need := target_hops - 1  # nodes between start and top
	for k in range(1, need + 1):
		var tt := float(k) / float(need + 1)
		var zig := sin(tt * PI * 2.0) * (MIN_DIST * 0.55) * float(BR.find(rg) - 1)
		var dx := bx - ax
		var dy := byy - ay
		var length := maxf(1.0, sqrt(dx * dx + dy * dy))
		var px := -dy / length
		var py := dx / length
		var mx := ax + dx * tt + px * zig
		var my := ay + dy * tt + py * zig
		if not sil.inside(mx, my, 1.15):
			mx = ax + dx * tt
			my = ay + dy * tt
		var mid := ""
		for attempt in range(8):
			var jx := mx + _rng.randf_range(-MIN_DIST, MIN_DIST) * float(attempt)
			var jy := my + _rng.randf_range(-MIN_DIST * 0.3, MIN_DIST * 0.3) * float(attempt)
			mid = _add(_uid("cr"), _pick_name(rg), jx, jy, "small", _stats(rg), rg, MIN_DIST * 0.85)
			if mid != "":
				break
		if mid == "":
			continue
		_ln_force(prev, mid)
		prev = mid
	_ln_force(prev, tid)


func _attach_orphans_to_nearest() -> void:
	for _pass in range(30):
		var starts: Dictionary = {}
		for rg in BR:
			if by.has(START_ID[rg]):
				starts[START_ID[rg]] = true
		if by.has("core_heart"):
			starts["core_heart"] = true
		var seen: Dictionary = {}
		var q: Array = []
		for s in starts.keys():
			seen[s] = true
			q.append(s)
		var adj := _adj()
		var qi := 0
		while qi < q.size():
			var u: String = q[qi]
			qi += 1
			for v in adj.get(u, []):
				if seen.has(v):
					continue
				seen[v] = true
				q.append(v)
		var orphans: Array = []
		for n in nodes:
			if not seen.has(n["id"]):
				orphans.append(n["id"])
		if orphans.is_empty():
			return
		var linked_any := false
		for oid in orphans:
			var rg: String = str(by[oid]["region"])
			var cand: Array = []
			for sid in seen.keys():
				var penalty := 0.0 if str(by[sid].get("region", rg)) == rg else 400.0
				cand.append([_dist_id(oid, sid) + penalty, sid])
			cand.sort_custom(func(a, b): return a[0] < b[0])
			var did := false
			for c in cand:
				if _ln(oid, c[1]):
					did = true
					linked_any = true
					seen[oid] = true
					break
			if not did:
				for c in cand:
					if str(by[c[1]].get("region", "")) != rg and c[1] != "core_heart":
						continue
					if _ln_force(oid, c[1]):
						linked_any = true
						seen[oid] = true
						break
		if not linked_any:
			return


func _dist_id(a: String, b: String) -> float:
	var pa := Vector2(by[a]["x"], by[a]["y"])
	var pb := Vector2(by[b]["x"], by[b]["y"])
	return pa.distance_to(pb)


func _connect_nearest(id: String, want: int, rg: String) -> void:
	var cand: Array = []
	for n in nodes:
		var oid: String = n["id"]
		if oid == id:
			continue
		if rg != "" and str(n["region"]) != rg and id != "core_heart" and oid != "core_heart":
			continue
		cand.append([_dist_id(id, oid), oid])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var added := 0
	for c in cand:
		if added >= want:
			break
		if int(deg.get(id, 0)) >= MAX_DEG:
			break
		if _ln(id, c[1]):
			added += 1


func _tune_paths() -> void:
	# Corridors already set own ≈ target; fine-tune into [80,88]
	_force_own_tops(80, 88)
	_shorten_own_tops(88)


func _hops(src: String, dst: String) -> int:
	if not by.has(src) or not by.has(dst):
		return -1
	var adj := _adj()
	var q: Array = [src]
	var prev: Dictionary = {src: ""}
	var i := 0
	while i < q.size():
		var u: String = q[i]
		i += 1
		if u == dst:
			break
		for v in adj.get(u, []):
			if prev.has(v):
				continue
			prev[v] = u
			q.append(v)
	if not prev.has(dst):
		return -1
	var cost := 0
	var cur: String = dst
	while cur != src and cur != "":
		if str(by[cur].get("type", "")) != "start":
			cost += 1
		cur = str(prev.get(cur, ""))
	return cost


func _adj() -> Dictionary:
	var a: Dictionary = {}
	for L in links:
		var u: String = L[0]
		var v: String = L[1]
		if not a.has(u):
			a[u] = []
		if not a.has(v):
			a[v] = []
		a[u].append(v)
		a[v].append(u)
	return a


func _pad_path(src: String, dst: String) -> bool:
	var path := _path_ids(src, dst)
	if path.size() < 2:
		return false
	var best_a := ""
	var best_b := ""
	var best_d := -1.0
	for i in range(path.size() - 1):
		var d := _dist_id(path[i], path[i + 1])
		if d > best_d:
			best_d = d
			best_a = path[i]
			best_b = path[i + 1]
	if best_a == "" or best_d < STEP * SCALE * 0.55:
		return false
	_unlink(best_a, best_b)
	var ax: float = by[best_a]["x"] / SCALE
	var ay: float = -by[best_a]["y"] / SCALE
	var bx: float = by[best_b]["x"] / SCALE
	var byy: float = -by[best_b]["y"] / SCALE
	var mx := (ax + bx) * 0.5
	var my := (ay + byy) * 0.5
	var rg: String = by[best_a]["region"]
	var mid := _add(_uid("pd"), _pick_name(rg), mx, my, "small", _stats(rg), rg, MIN_DIST * 0.9)
	if mid == "":
		_ln_force(best_a, best_b)
		return false
	_ln_force(best_a, mid)
	_ln_force(mid, best_b)
	return true


func _unlink(a: String, b: String) -> void:
	for i in range(links.size() - 1, -1, -1):
		var L: Array = links[i]
		if (L[0] == a and L[1] == b) or (L[0] == b and L[1] == a):
			links.remove_at(i)
			deg[a] = max(0, int(deg.get(a, 0)) - 1)
			deg[b] = max(0, int(deg.get(b, 0)) - 1)


func _ensure_validators() -> void:
	for _i in range(3):
		_attach_orphans_to_nearest()
	_force_own_tops(80, 88)
	_shorten_own_tops(88)
	_strip_crossings_safe()
	for _i2 in range(3):
		_attach_orphans_to_nearest()
	_force_own_tops(80, 88)
	_shorten_own_tops(88)
	_strip_crossings_safe()
	_kill_remaining_crossings()
	_force_own_tops(80, 88)
	_shorten_own_tops(88)
	_attach_orphans_to_nearest()
	_force_link_all_orphans()
	if by.has("core_heart") and int(deg.get("core_heart", 0)) == 0:
		for rg in BR:
			var best2 := ""
			var bd2 := 1e18
			for n2 in nodes:
				if n2["region"] != rg:
					continue
				var d3 := _dist_id("core_heart", n2["id"])
				if d3 < bd2:
					bd2 = d3
					best2 = n2["id"]
			if best2 != "":
				_ln_force("core_heart", best2)
				break
	_force_link_all_orphans()
	_kill_remaining_crossings()
	_force_own_tops(80, 88)
	_shorten_own_tops(88)
	for n in nodes:
		var st: Dictionary = n["stats"]
		var clean: Dictionary = {}
		for k in st.keys():
			if WIRED.has(k):
				clean[k] = st[k]
		n["stats"] = clean
		n["description"] = _desc(clean)


func _strip_crossings_safe() -> void:
	var guard := 0
	while guard < 300:
		guard += 1
		var found := false
		for i in range(links.size()):
			for j in range(i + 1, links.size()):
				var a: String = links[i][0]
				var b: String = links[i][1]
				var c: String = links[j][0]
				var d2: String = links[j][1]
				if a == c or a == d2 or b == c or b == d2:
					continue
				if not by.has(a) or not by.has(b) or not by.has(c) or not by.has(d2):
					continue
				if not _seg_intersect(Vector2(by[a]["x"], by[a]["y"]), Vector2(by[b]["x"], by[b]["y"]), Vector2(by[c]["x"], by[c]["y"]), Vector2(by[d2]["x"], by[d2]["y"])):
					continue
				var order: Array = [[_dist_id(a, b), a, b], [_dist_id(c, d2), c, d2]]
				order.sort_custom(func(x, y): return x[0] > y[0])
				for cand in order:
					var u: String = cand[1]
					var v: String = cand[2]
					_unlink(u, v)
					var ok := true
					for rg in BR:
						var tid := pick_top(rg)
						if tid != "" and _hops(START_ID[rg], tid) < 0:
							ok = false
							break
					if ok:
						found = true
						break
					_ln_force(u, v)
				if found:
					break
			if found:
				break
		if not found:
			break


func _shorten_own_tops(hi: int = 88) -> void:
	for rg in BR:
		var sid: String = START_ID[rg]
		var tid := pick_top(rg)
		if tid == "" or not by.has(sid):
			continue
		var guard := 0
		while _hops(sid, tid) > hi and guard < 40 and not _cancel:
			guard += 1
			if not _add_shortcut(sid, tid):
				break


func _add_shortcut(src: String, dst: String) -> bool:
	var path := _path_ids(src, dst)
	for a_i in range(path.size()):
		for span in [5, 4, 3]:
			var b_i: int = a_i + span
			if b_i >= path.size():
				continue
			if _ln(path[a_i], path[b_i]):
				return true
	return false


func _force_own_tops(lo: int = 80, hi: int = 88) -> void:
	for rg in BR:
		if _cancel:
			return
		var sid: String = START_ID[rg]
		var tid := pick_top(rg)
		if tid == "" or not by.has(sid):
			continue
		var guard := 0
		while guard < 200 and not _cancel:
			guard += 1
			var hops := _hops(sid, tid)
			if hops < 0:
				_ln_force(sid, tid)
				continue
			if hops >= lo:
				break
			if _pad_path(sid, tid):
				continue
			if _insert_detour_chain(sid, tid, mini(10, lo - hops)):
				continue
			if _remove_path_chord(sid, tid):
				continue
			break


func _path_ids(src: String, dst: String) -> Array:
	var adj := _adj()
	var q: Array = [src]
	var prev: Dictionary = {src: ""}
	var i := 0
	while i < q.size():
		var u: String = q[i]
		i += 1
		if u == dst:
			break
		for v in adj.get(u, []):
			if prev.has(v):
				continue
			prev[v] = u
			q.append(v)
	if not prev.has(dst):
		return []
	var path: Array = []
	var cur: String = dst
	while cur != "":
		path.push_front(cur)
		if cur == src:
			break
		cur = str(prev.get(cur, ""))
	return path


func _remove_path_chord(src: String, dst: String) -> bool:
	var path := _path_ids(src, dst)
	if path.size() < 4:
		return false
	var idx: Dictionary = {}
	for i in range(path.size()):
		idx[path[i]] = i
	var candidates: Array = []
	for L in links:
		var a: String = L[0]
		var b: String = L[1]
		if not idx.has(a) or not idx.has(b):
			continue
		var span: int = abs(int(idx[a]) - int(idx[b]))
		if span >= 3:
			candidates.append([-span, a, b])
	candidates.sort_custom(func(x, y): return x[0] < y[0])
	for c in candidates:
		var a: String = c[1]
		var b: String = c[2]
		_unlink(a, b)
		if _hops(src, dst) >= 0:
			return true
		_ln_force(a, b)
	return false


func _insert_detour_chain(src: String, dst: String, count: int) -> bool:
	var path := _path_ids(src, dst)
	if path.size() < 2:
		return false
	var best_a: String = path[0]
	var best_b: String = path[1]
	var best_d := _dist_id(best_a, best_b)
	for i in range(path.size() - 1):
		var d := _dist_id(path[i], path[i + 1])
		if d > best_d:
			best_d = d
			best_a = path[i]
			best_b = path[i + 1]
	_unlink(best_a, best_b)
	var ax: float = by[best_a]["x"] / SCALE
	var ay: float = -by[best_a]["y"] / SCALE
	var bx: float = by[best_b]["x"] / SCALE
	var byy: float = -by[best_b]["y"] / SCALE
	var dx := bx - ax
	var dy := byy - ay
	var length := sqrt(dx * dx + dy * dy)
	if length < 1.0:
		_ln_force(best_a, best_b)
		return false
	var px := -dy / length
	var py := dx / length
	var rg: String = by[best_a]["region"]
	var prev_id := best_a
	var placed := 0
	for k in range(count):
		var tt: float = (float(k) + 1.0) / (float(count) + 1.0)
		var amp: float = (MIN_DIST + 4.0) * (1.0 if (k % 2) == 0 else -1.0)
		var mx := ax + dx * tt + px * amp
		var my := ay + dy * tt + py * amp
		if not sil.inside(mx, my, 1.12):
			mx = ax + dx * tt
			my = ay + dy * tt
		var mid := _add(_uid("dt"), _pick_name(rg), mx, my, "small", _stats(rg), rg, MIN_DIST * 0.95)
		if mid == "":
			continue
		_ln_force(prev_id, mid)
		prev_id = mid
		placed += 1
	_ln_force(prev_id, best_b)
	return placed > 0



func _force_link_all_orphans() -> void:
	for _pass in range(50):
		var starts: Dictionary = {}
		for rg in BR:
			if by.has(START_ID[rg]):
				starts[START_ID[rg]] = true
		var seen: Dictionary = {}
		var q: Array = []
		for s in starts.keys():
			seen[s] = true
			q.append(s)
		var adj := _adj()
		var qi := 0
		while qi < q.size():
			var u: String = q[qi]
			qi += 1
			for v in adj.get(u, []):
				if seen.has(v):
					continue
				seen[v] = true
				q.append(v)
		var orphan_ids: Array = []
		for n in nodes:
			if not seen.has(n["id"]):
				orphan_ids.append(n["id"])
		if orphan_ids.is_empty():
			return
		var oid: String = orphan_ids[0]
		var rg: String = str(by[oid]["region"])
		var best := ""
		var bd := 1e18
		for sid in seen.keys():
			if str(by[sid].get("region", "")) != rg and sid != "core_heart":
				continue
			var d := _dist_id(oid, sid)
			if d < bd:
				bd = d
				best = sid
		if best == "":
			for sid2 in seen.keys():
				var d2 := _dist_id(oid, sid2)
				if d2 < bd:
					bd = d2
					best = sid2
		if best == "":
			return
		_ln_force(oid, best)


func _kill_remaining_crossings() -> void:
	var guard := 0
	while guard < 80:
		guard += 1
		if int(metrics().get("crossings", 0)) == 0:
			return
		var fixed := false
		for i in range(links.size()):
			for j in range(i + 1, links.size()):
				var a: String = links[i][0]
				var b: String = links[i][1]
				var c: String = links[j][0]
				var d2: String = links[j][1]
				if a == c or a == d2 or b == c or b == d2:
					continue
				if not by.has(a) or not by.has(b) or not by.has(c) or not by.has(d2):
					continue
				if not _seg_intersect(Vector2(by[a]["x"], by[a]["y"]), Vector2(by[b]["x"], by[b]["y"]), Vector2(by[c]["x"], by[c]["y"]), Vector2(by[d2]["x"], by[d2]["y"])):
					continue
				# Uncross: replace AB,CD with AC,BD or AD,BC
				_unlink(a, b)
				_unlink(c, d2)
				var options: Array = [[[a, c], [b, d2]], [[a, d2], [b, c]]]
				var restored := false
				for opt in options:
					var e1: Array = opt[0]
					var e2: Array = opt[1]
					_ln_force(e1[0], e1[1])
					_ln_force(e2[0], e2[1])
					var ok_own := true
					for rg in BR:
						var o := _hops(START_ID[rg], pick_top(rg))
						if o < 80 or o > 100:
							ok_own = false
							break
					var ok_cross := int(metrics().get("crossings", 99)) < 1 or true  # accept if own ok; loop continues
					# Prefer option that reduces crossings
					var cx := int(metrics().get("crossings", 99))
					if ok_own and cx < 99:
						# keep this; if crossings still >0 outer loop continues
						fixed = true
						restored = true
						break
					_unlink(e1[0], e1[1])
					_unlink(e2[0], e2[1])
				if not restored:
					_ln_force(a, b)
					_ln_force(c, d2)
				else:
					break
			if fixed:
				break
		if not fixed:
			# Last resort: insert junction at midpoint of one edge and rewire
			for i in range(links.size()):
				for j in range(i + 1, links.size()):
					var a: String = links[i][0]
					var b: String = links[i][1]
					var c: String = links[j][0]
					var d2: String = links[j][1]
					if a == c or a == d2 or b == c or b == d2:
						continue
					if not by.has(a) or not by.has(b) or not by.has(c) or not by.has(d2):
						continue
					if not _seg_intersect(Vector2(by[a]["x"], by[a]["y"]), Vector2(by[b]["x"], by[b]["y"]), Vector2(by[c]["x"], by[c]["y"]), Vector2(by[d2]["x"], by[d2]["y"])):
						continue
					# Approximate intersection as average of endpoints
					var mx: float = (by[a]["x"] + by[b]["x"] + by[c]["x"] + by[d2]["x"]) * 0.25 / SCALE
					var my: float = -(by[a]["y"] + by[b]["y"] + by[c]["y"] + by[d2]["y"]) * 0.25 / SCALE
					var rg: String = by[a]["region"]
					var mid := _add(_uid("x"), _pick_name(rg), mx, my, "small", _stats(rg), rg, MIN_DIST * 0.5)
					if mid == "":
						continue
					_unlink(a, b)
					_unlink(c, d2)
					_ln_force(a, mid)
					_ln_force(b, mid)
					_ln_force(c, mid)
					_ln_force(d2, mid)
					fixed = true
					break
				if fixed:
					break
			if not fixed:
				return


func pick_top(rg: String) -> String:
	var best := ""
	var byy := -1e18
	for n in nodes:
		if n["type"] != "keystone" or n["region"] != rg:
			continue
		var gy: float = float(n["y"])
		if gy < byy or best == "":
			byy = gy
			best = n["id"]
	return best


func metrics() -> Dictionary:
	var md := 1e18
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var dx: float = (nodes[i]["x"] - nodes[j]["x"]) / SCALE
			var dy: float = (nodes[i]["y"] - nodes[j]["y"]) / SCALE
			var d := sqrt(dx * dx + dy * dy)
			if d < md:
				md = d
	var cross := 0
	for i in range(links.size()):
		for j in range(i + 1, links.size()):
			var a: String = links[i][0]
			var b: String = links[i][1]
			var c: String = links[j][0]
			var d2: String = links[j][1]
			if a == c or a == d2 or b == c or b == d2:
				continue
			if not by.has(a) or not by.has(b) or not by.has(c) or not by.has(d2):
				continue
			if _seg_intersect(Vector2(by[a]["x"], by[a]["y"]), Vector2(by[b]["x"], by[b]["y"]), Vector2(by[c]["x"], by[c]["y"]), Vector2(by[d2]["x"], by[d2]["y"])):
				cross += 1
	var starts: Array = []
	for rg in BR:
		if by.has(START_ID[rg]):
			starts.append(START_ID[rg])
	var seen: Dictionary = {}
	var q: Array = []
	for s in starts:
		seen[s] = true
		q.append(s)
	var adj := _adj()
	var qi := 0
	while qi < q.size():
		var u: String = q[qi]
		qi += 1
		for v in adj.get(u, []):
			if seen.has(v):
				continue
			seen[v] = true
			q.append(v)
	var orphans: int = nodes.size() - seen.size()
	var mism := 0
	var unwired := 0
	for n in nodes:
		if n["type"] != "start" and str(n.get("description", "")) != _desc(n["stats"]):
			mism += 1
		for k in n["stats"].keys():
			if not WIRED.has(k):
				unwired += 1
	var owns: Dictionary = {}
	for rg in BR:
		var tid := pick_top(rg)
		owns[rg] = _hops(START_ID[rg], tid) if tid != "" else -1
	return {
		"N": nodes.size(),
		"links": links.size(),
		"crossings": cross,
		"orphans": orphans,
		"min_node_dist": md if md < 1e17 else 0.0,
		"desc_mismatch": mism,
		"unwired": unwired,
		"own": owns,
	}


func validators_ok(m: Dictionary = {}) -> bool:
	if m.is_empty():
		m = metrics()
	if int(m.get("crossings", 1)) != 0:
		return false
	if int(m.get("orphans", 1)) != 0:
		return false
	if int(m.get("desc_mismatch", 1)) != 0:
		return false
	if int(m.get("unwired", 1)) != 0:
		return false
	var md: float = float(m.get("min_node_dist", 0.0))
	if md < MIN_DIST * 0.72:
		return false
	var owns: Dictionary = m.get("own", {})
	for rg in BR:
		var o: int = int(owns.get(rg, -1))
		if o < 80 or o > 88:
			return false
	return true
