## Предмети: слоти, рідкість, випадкові властивості. Предмет — звичайний словник
## {uid, base, rarity, ilvl, name, stats{}}, тож легко зберігається в JSON.
class_name Items

const SLOTS := ["weapon", "armor", "amulet", "ring"]
const SLOT_NAMES := {"weapon": "Зброя", "armor": "Броня", "amulet": "Оберіг", "ring": "Перстень"}
const SLOT_ICONS := {"weapon": "⚔", "armor": "▣", "amulet": "◈", "ring": "○"}

## Рівні рідкості: назва, колір, кількість додаткових властивостей, множник базових чисел, вага випадіння.
const RARITIES := [
	{"id": "common", "name": "Звичайний", "color": Color("D8D2C4"), "affixes": 0, "mult": 1.0, "weight": 70.0},
	{"id": "fine", "name": "Добротний", "color": Color("7CBF5A"), "affixes": 1, "mult": 1.1, "weight": 22.0},
	{"id": "rare", "name": "Рідкісний", "color": Color("5FA8F0"), "affixes": 2, "mult": 1.2, "weight": 7.0},
	{"id": "legend", "name": "Заповітний", "color": Color("F0A83A"), "affixes": 4, "mult": 1.35, "weight": 1.0},
]

## Основи предметів. Для зброї kind: melee (ближній бій), arrow (лук), magic (магічна куля).
const BASES := {
	"sword": {"slot": "weapon", "name": "Дружинний меч", "kind": "melee", "dmg": 12.0, "interval": 0.55, "range": 2.7, "arc": 150.0, "stat": "str"},
	"axe": {"slot": "weapon", "name": "Бойова сокира", "kind": "melee", "dmg": 15.0, "interval": 0.68, "range": 2.6, "arc": 130.0, "stat": "str"},
	"bow": {"slot": "weapon", "name": "Мисливський лук", "kind": "arrow", "dmg": 10.0, "interval": 0.75, "range": 13.0, "arc": 0.0, "stat": "agi"},
	"longbow": {"slot": "weapon", "name": "Складний лук", "kind": "arrow", "dmg": 13.0, "interval": 0.9, "range": 15.0, "arc": 0.0, "stat": "agi"},
	"staff": {"slot": "weapon", "name": "Посох-кий", "kind": "magic", "dmg": 9.0, "interval": 0.8, "range": 11.5, "arc": 0.0, "stat": "faith"},
	"wand": {"slot": "weapon", "name": "Жезл волхва", "kind": "magic", "dmg": 7.0, "interval": 0.55, "range": 10.0, "arc": 0.0, "stat": "faith"},
	"plate": {"slot": "armor", "name": "Цільнометалева броня", "armor": 60.0, "base_stats": {"move_pct": -5.0}},
	"mail": {"slot": "armor", "name": "Кольчуга", "armor": 35.0, "base_stats": {}},
	"leather": {"slot": "armor", "name": "Шкіряний обладунок", "armor": 22.0, "base_stats": {"agi": 1.0}},
	"cloth": {"slot": "armor", "name": "Балахон із оберегами", "armor": 10.0, "base_stats": {"faith": 2.0, "mana_regen": 0.5}},
	"amulet": {"slot": "amulet", "name": "Оберіг", "min_affixes": 1},
	"ring": {"slot": "ring", "name": "Перстень", "min_affixes": 1},
}

const FISTS := {"name": "Голі руки", "kind": "melee", "dmg": 4.0, "interval": 0.6, "range": 2.0, "arc": 120.0, "stat": "str"}

## Можливі властивості: стартове значення (на рівні предмета 1) і назва-суфікс.
const AFFIXES := {
	"str": {"base": 2.0, "suffix": "Сили"},
	"agi": {"base": 2.0, "suffix": "Спритності"},
	"faith": {"base": 2.0, "suffix": "Віри"},
	"hp": {"base": 16.0, "suffix": "Життя"},
	"armor": {"base": 8.0, "suffix": "Захисту"},
	"crit_pct": {"base": 1.5, "suffix": "Влучності"},
	"move_pct": {"base": 3.0, "suffix": "Вітру"},
	"mana_regen": {"base": 0.4, "suffix": "Джерела"},
	"dmg_pct": {"base": 4.0, "suffix": "Люті"},
	"atk_speed_pct": {"base": 4.0, "suffix": "Швидкості"},
}
const AFFIX_KEYS := ["str", "agi", "faith", "hp", "armor", "crit_pct", "move_pct", "mana_regen", "dmg_pct", "atk_speed_pct"]
const WEAPON_AFFIXES := ["dmg_pct", "atk_speed_pct", "crit_pct", "str", "agi", "faith"]

const STARTER := {"druzhynnyk": ["sword", "plate"], "strilets": ["bow", "mail"], "volkhv": ["staff", "cloth"]}


static func rarity(r: int) -> Dictionary:
	return RARITIES[clampi(r, 0, RARITIES.size() - 1)]


static func rarity_color(item: Dictionary) -> Color:
	return rarity(int(item.get("rarity", 0)))["color"]


static func slot_of(item: Dictionary) -> String:
	return str(BASES.get(str(item.get("base", "")), {}).get("slot", ""))


## Створює предмет. slot_hint: "" — будь-який слот.
static func generate(ilvl: int, rng: RandomNumberGenerator, slot_hint: String = "", rarity_idx: int = -1) -> Dictionary:
	var ids: Array = []
	for id in BASES:
		if slot_hint == "" or BASES[id]["slot"] == slot_hint:
			ids.append(id)
	var base_id: String = ids[rng.randi() % ids.size()]
	if rarity_idx < 0:
		rarity_idx = roll_rarity(rng)
	return make(base_id, ilvl, rarity_idx, rng)


static func roll_rarity(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for r in RARITIES:
		total += float(r["weight"])
	var x := rng.randf() * total
	for i in range(RARITIES.size()):
		x -= float(RARITIES[i]["weight"])
		if x <= 0.0:
			return i
	return 0


static func make(base_id: String, ilvl: int, rarity_idx: int, rng: RandomNumberGenerator) -> Dictionary:
	var b: Dictionary = BASES[base_id]
	var rd := rarity(rarity_idx)
	var lvl_mult := 1.0 + 0.10 * float(maxi(ilvl, 1) - 1)
	var stats := {}
	if b["slot"] == "weapon":
		stats["dmg"] = snappedf(float(b["dmg"]) * lvl_mult * float(rd["mult"]), 0.1)
	elif b["slot"] == "armor":
		stats["armor"] = snappedf(float(b["armor"]) * lvl_mult * float(rd["mult"]), 1.0)
		for k in b.get("base_stats", {}):
			stats[k] = float(b["base_stats"][k])
	var n := maxi(int(rd["affixes"]), int(b.get("min_affixes", 0)))
	var pool: Array = (WEAPON_AFFIXES if b["slot"] == "weapon" else AFFIX_KEYS).duplicate()
	var first_affix := ""
	for i in range(n):
		if pool.is_empty():
			break
		var k: String = pool[rng.randi() % pool.size()]
		pool.erase(k)
		var a: Dictionary = AFFIXES[k]
		var v := float(a["base"]) * (1.0 + 0.08 * float(maxi(ilvl, 1) - 1)) * rng.randf_range(0.8, 1.2) * (1.0 if rarity_idx < 3 else 1.3)
		v = snappedf(v, 0.1) if k == "mana_regen" or k == "crit_pct" else snappedf(v, 1.0)
		v = maxf(v, 0.1 if k == "mana_regen" else 1.0)
		stats[k] = float(stats.get(k, 0.0)) + v
		if first_affix == "":
			first_affix = k
	var nm: String = b["name"]
	if rarity_idx >= 1 and first_affix != "":
		nm += " «%s»" % AFFIXES[first_affix]["suffix"]
	return {"uid": 0, "base": base_id, "rarity": rarity_idx, "ilvl": maxi(ilvl, 1), "name": nm, "stats": stats}


static func starter(class_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var out := {}
	for base_id in STARTER.get(class_id, ["sword", "plate"]):
		var it := make(base_id, 1, 0, rng)
		out[BASES[base_id]["slot"]] = it
	return out


## Параметри атаки зброї (kind, dmg, interval, range, arc, stat).
static func weapon_def(item: Variant) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY or item.is_empty():
		return FISTS
	var b: Dictionary = BASES.get(str(item.get("base", "")), {})
	if b.is_empty() or b["slot"] != "weapon":
		return FISTS
	var d := b.duplicate()
	d["dmg"] = float(item["stats"].get("dmg", b["dmg"]))
	d["name"] = item.get("name", b["name"])
	return d


static func kind_name(kind: String) -> String:
	match kind:
		"melee": return "ближній бій"
		"arrow": return "стріли"
		_: return "магічна куля"


static func sell_value(item: Dictionary) -> int:
	var r := int(item.get("rarity", 0))
	return int((4.0 + 2.5 * float(item.get("ilvl", 1))) * (1.0 + 1.5 * float(r)))


## Рядки опису властивостей (без назви).
static func stat_lines(item: Dictionary) -> Array:
	var out: Array = []
	var st: Dictionary = item.get("stats", {})
	var b: Dictionary = BASES.get(str(item.get("base", "")), {})
	if b.get("slot", "") == "weapon":
		var w := weapon_def(item)
		out.append("Шкода %s · %s" % [Strings.num(float(w["dmg"])), Items.kind_name(str(w["kind"]))])
		out.append("Швидкість %s уд/с · дальність %s м" % [Strings.num(snappedf(1.0 / float(w["interval"]), 0.01)), Strings.num(float(w["range"]))])
	for k in PerkTree.STAT_ORDER:
		if k == "dmg":
			continue
		if st.has(k) and not is_zero_approx(float(st[k])):
			out.append(PerkTree.stat_line(k, float(st[k])))
	return out


static func summary(item: Dictionary) -> String:
	var r := rarity(int(item.get("rarity", 0)))
	var head := "%s · %s · рів. %d" % [r["name"], SLOT_NAMES.get(slot_of(item), ""), int(item.get("ilvl", 1))]
	return head + "\n" + "\n".join(stat_lines(item))
