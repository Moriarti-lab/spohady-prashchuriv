## Предмети: слоти, рідкість, випадкові властивості. Предмет — звичайний словник
## {uid, base, rarity, ilvl, name, stats{}}, тож легко зберігається в JSON.
##
## Слоти спорядження (ключі GameState.equipment):
##   main — права рука (одноручна зброя або дворучна), off — ліва рука (щит або одноручна зброя),
##   head, hands, body, feet, ring1, ring2, amulet.
## Тип предмета (type в BASES): hand1 (одноручна зброя), hand2 (дворучна), shield, head, hands, body, feet, ring, amulet.
class_name Items

const SLOTS := ["main", "off", "head", "hands", "body", "feet", "ring1", "ring2", "amulet"]
const SLOT_NAMES := {
	"main": "Права рука", "off": "Ліва рука", "head": "Голова", "hands": "Руки", "body": "Тіло",
	"feet": "Ноги", "ring1": "Перстень 1", "ring2": "Перстень 2", "amulet": "Оберіг",
}
## Куди можна покласти предмет кожного типу.
const TYPE_SLOTS := {
	"hand1": ["main", "off"], "hand2": ["main"], "shield": ["off"], "head": ["head"], "hands": ["hands"],
	"body": ["body"], "feet": ["feet"], "ring": ["ring1", "ring2"], "amulet": ["amulet"],
}
const TYPE_NAMES := {
	"hand1": "Одноручна зброя", "hand2": "Дворучна зброя", "shield": "Щит", "head": "Шолом", "hands": "Рукавиці",
	"body": "Броня", "feet": "Чоботи", "ring": "Перстень", "amulet": "Оберіг",
	"nauz": "Науз", "thread": "Нитка",
}
## Вага випадіння типів із ворогів.
const TYPE_WEIGHTS := {
	"hand1": 14.0, "hand2": 10.0, "shield": 8.0, "head": 9.0, "hands": 8.0, "body": 10.0, "feet": 8.0, "ring": 7.0, "amulet": 5.0,
}

## Рівні рідкості: назва, колір, кількість додаткових властивостей, множник базових чисел, вага випадіння.
const RARITIES := [
	{"id": "common", "name": "Звичайний", "color": Color("D8D2C4"), "affixes": 0, "mult": 1.0, "weight": 70.0},
	{"id": "fine", "name": "Добротний", "color": Color("7CBF5A"), "affixes": 1, "mult": 1.1, "weight": 22.0},
	{"id": "rare", "name": "Рідкісний", "color": Color("5FA8F0"), "affixes": 2, "mult": 1.2, "weight": 7.0},
	{"id": "legend", "name": "Заповітний", "color": Color("F0A83A"), "affixes": 4, "mult": 1.35, "weight": 1.0},
]

## Основи предметів. type — див. вище; tier 1–3 (відкривається з рівня предмета 1 / 5 / 10);
## для зброї kind: melee, arrow (лук), magic. icon — icon_id із реєстру іконок.
const BASES := {
	# одноручна зброя
	"sword": {"type": "hand1", "tier": 1, "icon": "w_sword", "name": "Дружинний меч", "kind": "melee", "dmg": 12.0, "interval": 0.55, "range": 2.7, "arc": 150.0, "stat": "str"},
	"axe": {"type": "hand1", "tier": 1, "icon": "w_axe", "name": "Бойова сокира", "kind": "melee", "dmg": 15.0, "interval": 0.68, "range": 2.6, "arc": 130.0, "stat": "str"},
	"dagger": {"type": "hand1", "tier": 1, "icon": "w_dagger", "name": "Кинджал", "kind": "melee", "dmg": 8.0, "interval": 0.38, "range": 2.2, "arc": 110.0, "stat": "agi"},
	"mace": {"type": "hand1", "tier": 2, "icon": "w_mace", "name": "Шестопер", "kind": "melee", "dmg": 17.0, "interval": 0.74, "range": 2.5, "arc": 120.0, "stat": "str"},
	"hammer": {"type": "hand1", "tier": 3, "icon": "w_hammer", "name": "Бойовий молот", "kind": "melee", "dmg": 22.0, "interval": 0.82, "range": 2.5, "arc": 120.0, "stat": "str"},
	"wand": {"type": "hand1", "tier": 1, "icon": "w_wand", "name": "Жезл волхва", "kind": "magic", "dmg": 7.0, "interval": 0.55, "range": 10.0, "arc": 0.0, "stat": "faith"},
	# дворучна зброя
	"spear": {"type": "hand2", "tier": 1, "icon": "w_spear", "name": "Спис", "kind": "melee", "dmg": 20.0, "interval": 0.7, "range": 3.6, "arc": 60.0, "stat": "str"},
	"greatsword": {"type": "hand2", "tier": 2, "icon": "w_greatsword", "name": "Дворучний меч", "kind": "melee", "dmg": 25.0, "interval": 0.8, "range": 3.0, "arc": 160.0, "stat": "str"},
	"greataxe": {"type": "hand2", "tier": 3, "icon": "w_greataxe", "name": "Дворучна сокира", "kind": "melee", "dmg": 34.0, "interval": 0.96, "range": 2.9, "arc": 150.0, "stat": "str"},
	"bow": {"type": "hand2", "tier": 1, "icon": "w_bow", "name": "Мисливський лук", "kind": "arrow", "dmg": 14.0, "interval": 0.75, "range": 13.0, "arc": 0.0, "stat": "agi"},
	"longbow": {"type": "hand2", "tier": 2, "icon": "w_longbow", "name": "Складний лук", "kind": "arrow", "dmg": 18.0, "interval": 0.9, "range": 15.0, "arc": 0.0, "stat": "agi"},
	"crossbow": {"type": "hand2", "tier": 3, "icon": "w_crossbow", "name": "Важкий арбалет", "kind": "arrow", "dmg": 30.0, "interval": 1.3, "range": 14.0, "arc": 0.0, "stat": "agi"},
	"staff": {"type": "hand2", "tier": 1, "icon": "w_staff", "name": "Посох-кий", "kind": "magic", "dmg": 12.0, "interval": 0.8, "range": 11.5, "arc": 0.0, "stat": "faith"},
	"magic_staff": {"type": "hand2", "tier": 2, "icon": "w_magic_staff", "name": "Посох із кристалом", "kind": "magic", "dmg": 18.0, "interval": 0.85, "range": 12.0, "arc": 0.0, "stat": "faith"},
	# щити
	"shield_round": {"type": "shield", "tier": 1, "icon": "sh_round", "name": "Круглий щит", "armor": 14.0, "base_stats": {}},
	"shield_kite": {"type": "shield", "tier": 2, "icon": "sh_kite", "name": "Червоний щит", "armor": 24.0, "base_stats": {"move_pct": -2.0}},
	"shield_sun": {"type": "shield", "tier": 3, "icon": "sh_sun", "name": "Щит із сонцем", "armor": 32.0, "base_stats": {"faith": 2.0}},
	# голова, руки, тіло, ноги
	"cap": {"type": "head", "tier": 1, "icon": "h_leather", "name": "Шкіряна шапка", "armor": 5.0, "base_stats": {}},
	"helm": {"type": "head", "tier": 2, "icon": "h_iron", "name": "Шолом із наносником", "armor": 12.0, "base_stats": {}},
	"helm_ornate": {"type": "head", "tier": 3, "icon": "h_ornate", "name": "Ошатний шолом", "armor": 18.0, "base_stats": {"faith": 1.0}},
	"gloves": {"type": "hands", "tier": 1, "icon": "g_leather", "name": "Шкіряні рукавиці", "armor": 4.0, "base_stats": {"atk_speed_pct": 2.0}},
	"gauntlets": {"type": "hands", "tier": 2, "icon": "g_chain", "name": "Кольчужні рукавиці", "armor": 10.0, "base_stats": {"str": 1.0}},
	"leather": {"type": "body", "tier": 1, "icon": "b_gambeson", "name": "Стьобаний каптан", "armor": 22.0, "base_stats": {"agi": 1.0}},
	"cloth": {"type": "body", "tier": 1, "icon": "b_robe", "name": "Балахон із оберегами", "armor": 10.0, "base_stats": {"faith": 2.0, "mana_regen": 0.5}},
	"mail": {"type": "body", "tier": 2, "icon": "b_mail", "name": "Кольчуга", "armor": 35.0, "base_stats": {}},
	"plate": {"type": "body", "tier": 3, "icon": "b_lamellar", "name": "Ламелярний обладунок", "armor": 60.0, "base_stats": {"move_pct": -5.0}},
	"boots": {"type": "feet", "tier": 1, "icon": "f_leather", "name": "Шкіряні чоботи", "armor": 4.0, "base_stats": {"move_pct": 2.0}},
	"boots_iron": {"type": "feet", "tier": 2, "icon": "f_iron", "name": "Окуті чоботи", "armor": 11.0, "base_stats": {}},
	# прикраси
	"ring": {"type": "ring", "tier": 1, "icon": "r_silver", "name": "Срібний перстень", "min_affixes": 1, "base_stats": {}},
	"ring_ruby": {"type": "ring", "tier": 2, "icon": "r_ruby", "name": "Перстень із рубіном", "min_affixes": 1, "base_stats": {"hp": 12.0}},
	"ring_emerald": {"type": "ring", "tier": 2, "icon": "r_emerald", "name": "Смарагдовий перстень", "min_affixes": 1, "base_stats": {"mana_regen": 0.3}},
	"amulet": {"type": "amulet", "tier": 1, "icon": "a_sun", "name": "Сонячний оберіг", "min_affixes": 1, "base_stats": {}},
	"amulet_wolf": {"type": "amulet", "tier": 2, "icon": "a_wolf", "name": "Вовче ікло", "min_affixes": 1, "base_stats": {"dmg_pct": 3.0}},
	"amulet_crystal": {"type": "amulet", "tier": 3, "icon": "a_crystal", "name": "Кришталевий оберіг", "min_affixes": 1, "base_stats": {"mana_pct": 6.0}},
}

const FISTS := {"name": "Голі руки", "kind": "melee", "dmg": 4.0, "interval": 0.6, "range": 2.0, "arc": 120.0, "stat": "str", "type": "hand1"}

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
	"lifesteal_pct": {"base": 1.0, "suffix": "Крові"},
	"thorns_pct": {"base": 5.0, "suffix": "Шипів"},
	"cdr_pct": {"base": 2.0, "suffix": "Часу"},
	"crit_dmg_pct": {"base": 6.0, "suffix": "Нищення"},
	"hp_regen_pct": {"base": 0.15, "suffix": "Відновлення"},
	"dr_pct": {"base": 1.5, "suffix": "Стійкості"},
	"gold_pct": {"base": 6.0, "suffix": "Статку"},
}
const AFFIX_KEYS := ["str", "agi", "faith", "hp", "armor", "crit_pct", "move_pct", "mana_regen", "dmg_pct", "atk_speed_pct",
	"lifesteal_pct", "thorns_pct", "cdr_pct", "crit_dmg_pct", "hp_regen_pct", "dr_pct", "gold_pct"]
## Властивості, які можуть випасти на предметі кожного типу.
const TYPE_AFFIXES := {
	"hand1": ["dmg_pct", "atk_speed_pct", "crit_pct", "crit_dmg_pct", "lifesteal_pct", "str", "agi", "faith"],
	"hand2": ["dmg_pct", "atk_speed_pct", "crit_pct", "crit_dmg_pct", "lifesteal_pct", "str", "agi", "faith"],
	"shield": ["armor", "hp", "dr_pct", "thorns_pct", "str", "hp_regen_pct"],
	"head": ["hp", "armor", "faith", "crit_pct", "mana_regen", "cdr_pct"],
	"hands": ["atk_speed_pct", "dmg_pct", "crit_pct", "str", "agi", "lifesteal_pct"],
	"body": ["hp", "armor", "dr_pct", "str", "agi", "faith", "hp_regen_pct", "thorns_pct"],
	"feet": ["move_pct", "hp", "agi", "armor", "dr_pct", "gold_pct"],
	"ring": AFFIX_KEYS,
	"amulet": AFFIX_KEYS,
}
const DECIMAL_AFFIXES := ["mana_regen", "crit_pct", "hp_regen_pct"]

const SELL_TO_BUY := 4.0


static func rarity(r: int) -> Dictionary:
	return RARITIES[clampi(r, 0, RARITIES.size() - 1)]


static func rarity_color(item: Dictionary) -> Color:
	return rarity(int(item.get("rarity", 0)))["color"]


static func base_of(item: Dictionary) -> Dictionary:
	return BASES.get(str(item.get("base", "")), {})


## Тип предмета (hand1, hand2, shield, head, ...). Порожньо — невідомий.
static func type_of(item: Dictionary) -> String:
	if Nauzi.is_nauz(item):
		return "nauz"
	if Nauzi.is_thread(item):
		return "thread"
	return str(base_of(item).get("type", ""))


static func is_weapon_type(t: String) -> bool:
	return t == "hand1" or t == "hand2"


static func is_two_handed(item: Variant) -> bool:
	return typeof(item) == TYPE_DICTIONARY and not item.is_empty() and type_of(item) == "hand2"


## Слоти, куди предмет можна покласти.
static func slots_for(item: Dictionary) -> Array:
	return TYPE_SLOTS.get(type_of(item), [])


static func can_equip_slot(slot: String, item: Dictionary) -> bool:
	return slot in slots_for(item)


static func icon_of(item: Dictionary) -> String:
	return str(base_of(item).get("icon", ""))


## Іконка порожнього слота спорядження (підказка, що там має лежати).
static func slot_icon(slot: String) -> String:
	match slot:
		"main": return "w_sword"
		"off": return "sh_round"
		"head": return "h_leather"
		"hands": return "g_leather"
		"body": return "b_mail"
		"feet": return "f_leather"
		"ring1", "ring2": return "r_silver"
		_: return "a_sun"


## Створює предмет. type_hint: "" — будь-який тип; max_tier обмежує основи (за рівнем предмета).
static func generate(ilvl: int, rng: RandomNumberGenerator, type_hint: String = "", rarity_idx: int = -1) -> Dictionary:
	var max_tier := tier_for_level(ilvl)
	var ids: Array = []
	var weights: Array = []
	for id in BASES:
		var b: Dictionary = BASES[id]
		if int(b["tier"]) > max_tier:
			continue
		if type_hint != "" and b["type"] != type_hint:
			continue
		ids.append(id)
		# рідкісні типи викидаються рідше; важча основа — трохи рідше
		weights.append(float(TYPE_WEIGHTS.get(b["type"], 5.0)) / float(_count_type(b["type"], max_tier)))
	if ids.is_empty():
		ids = BASES.keys()
		weights = []
		for _i in ids:
			weights.append(1.0)
	var total := 0.0
	for w in weights:
		total += float(w)
	var x := rng.randf() * total
	var base_id: String = ids[0]
	for i in range(ids.size()):
		x -= float(weights[i])
		if x <= 0.0:
			base_id = ids[i]
			break
	if rarity_idx < 0:
		rarity_idx = roll_rarity(rng)
	return make(base_id, ilvl, rarity_idx, rng)


static func _count_type(t: String, max_tier: int) -> int:
	var n := 0
	for id in BASES:
		if BASES[id]["type"] == t and int(BASES[id]["tier"]) <= max_tier:
			n += 1
	return maxi(n, 1)


static func tier_for_level(ilvl: int) -> int:
	if ilvl >= 10:
		return 3
	if ilvl >= 5:
		return 2
	return 1


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
	if is_weapon_type(str(b["type"])):
		stats["dmg"] = snappedf(float(b["dmg"]) * lvl_mult * float(rd["mult"]), 0.1)
	elif b.has("armor"):
		stats["armor"] = snappedf(float(b["armor"]) * lvl_mult * float(rd["mult"]), 1.0)
	for k in b.get("base_stats", {}):
		stats[k] = float(b["base_stats"][k])
	var n := maxi(int(rd["affixes"]), int(b.get("min_affixes", 0)))
	var pool: Array = (TYPE_AFFIXES[b["type"]] as Array).duplicate()
	var first_affix := ""
	for i in range(n):
		if pool.is_empty():
			break
		var k: String = pool[rng.randi() % pool.size()]
		pool.erase(k)
		var a: Dictionary = AFFIXES[k]
		var v := float(a["base"]) * (1.0 + 0.08 * float(maxi(ilvl, 1) - 1)) * rng.randf_range(0.8, 1.2) * (1.0 if rarity_idx < 3 else 1.3)
		if k in DECIMAL_AFFIXES:
			v = maxf(snappedf(v, 0.1), 0.1)
		else:
			v = maxf(snappedf(v, 1.0), 1.0)
		stats[k] = float(stats.get(k, 0.0)) + v
		if first_affix == "":
			first_affix = k
	var nm: String = b["name"]
	if rarity_idx >= 1 and first_affix != "":
		nm += " «%s»" % AFFIXES[first_affix]["suffix"]
	return {"uid": 0, "base": base_id, "rarity": rarity_idx, "ilvl": maxi(ilvl, 1), "name": nm, "stats": stats}


## Стартове спорядження класу: {slot: item}.
static func starter(class_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var out := {}
	var c: Dictionary = Gear.class_def(class_id)
	var ids: Array = c.get("kit", ["sword", "mail"])
	for base_id in ids:
		var it := make(base_id, 1, 0, rng)
		var slot := ""
		match type_of(it):
			"hand1", "hand2": slot = "main"
			"shield": slot = "off"
			"ring": slot = "ring1"
			_: slot = str(slots_for(it)[0])
		out[slot] = it
	return out


## Параметри атаки зброї (kind, dmg, interval, range, arc, stat).
static func weapon_def(item: Variant) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY or item.is_empty():
		return FISTS
	var b: Dictionary = BASES.get(str(item.get("base", "")), {})
	if b.is_empty() or not is_weapon_type(str(b["type"])):
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
	if Nauzi.is_nauz(item):
		return int((8.0 + 4.0 * float(item.get("level", 1))) * (1.0 + 1.6 * float(r)))
	if Nauzi.is_thread(item):
		return int((6.0 + 3.0 * float(r + 1)) * (1.0 + 1.2 * float(r)))
	return int((4.0 + 2.5 * float(item.get("ilvl", 1))) * (1.0 + 1.5 * float(r)))


## Ціна покупки в торговця (у гривнях).
static func buy_value(item: Dictionary) -> int:
	return int(round(float(sell_value(item)) * SELL_TO_BUY))


## Рядки опису властивостей (без назви).
static func stat_lines(item: Dictionary) -> Array:
	var out: Array = []
	if Nauzi.is_nauz(item):
		var sk := str(item.get("skill", ""))
		var lv := int(item.get("level", 1))
		var req := Nauzi.requirements(sk, lv)
		out.append("Науз · рів. %d (сила %d) · звитяга %d/%d" % [lv, Nauzi.power_level(item), int(item.get("xp", 0)), Nauzi.xp_to_next(lv)])
		out.append("Вимоги: герой %d, %s %d" % [int(req["hero_level"]), Strings.stat_name(str(req["stat"])), int(req["stat_min"])])
		out.append("Нитки: %d/%d" % [item.get("threads", []).size() if typeof(item.get("threads", [])) == TYPE_ARRAY else 0, Nauzi.thread_slots(lv)])
		var reason := Nauzi.can_use(item)
		if reason != "":
			out.append("⚠ %s" % reason)
		out.append(Skills.describe(sk, true))
		return out
	if Nauzi.is_thread(item):
		var tid := str(item.get("thread", ""))
		var td: Dictionary = Nauzi.THREADS.get(tid, {})
		out.append("Нитка · %s" % Nauzi.COLOR_NAMES.get(str(item.get("color", "white")), ""))
		out.append(str(td.get("desc", td.get("name", tid))))
		return out
	var st: Dictionary = item.get("stats", {})
	var b: Dictionary = base_of(item)
	if is_weapon_type(str(b.get("type", ""))):
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
	var head := "%s · %s · рів. %d" % [r["name"], TYPE_NAMES.get(type_of(item), ""), int(item.get("ilvl", 1))]
	return head + "\n" + "\n".join(stat_lines(item))


static func is_nauz(item: Variant) -> bool:
	return Nauzi.is_nauz(item)


static func is_thread(item: Variant) -> bool:
	return Nauzi.is_thread(item)


static func bag_kind(item: Variant) -> String:
	if typeof(item) != TYPE_DICTIONARY or item.is_empty():
		return "other"
	if Nauzi.is_nauz(item):
		return "nauz"
	if Nauzi.is_thread(item):
		return "thread"
	var tp := type_of(item)
	if tp in ["hand1", "hand2"]:
		return "weapon"
	if tp in ["shield", "head", "hands", "body", "feet"]:
		return "armor"
	return "other"
