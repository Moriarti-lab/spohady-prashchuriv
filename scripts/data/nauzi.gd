## Наузи (активні вміння-предмети) і нитки (підсилення). Див. дизайн-сторінку v0.5.
class_name Nauzi

const MAX_LEVEL := 20
const SOCKETS := 4
const THREAD_SLOTS_AT := [1, 8, 15]  # рівні науза, що відкривають 1-ше / 2-ге / 3-тє гніздо нитки
const STASH_SIZE := 32

## Мітки вміння для сумісності ниток.
const TAGS := {
	"power_strike": ["area", "melee", "str"],
	"shield_bash": ["strike", "melee", "shield", "str"],
	"triple_slash": ["melee", "cone", "str"],
	"whirlwind": ["area", "melee", "str"],
	"battle_cry": ["buff", "str"],
	"ground_slam": ["area", "melee", "str"],
	"chain_lightning": ["chain", "str"],
	"iron_wall": ["buff", "shield", "str"],
	"arrow_volley": ["projectile", "area", "arrow", "agi"],
	"piercing_shot": ["projectile", "arrow", "agi"],
	"rapid_shot": ["projectile", "arrow", "agi"],
	"arrow_rain": ["area", "arrow", "agi"],
	"poison_cloud": ["area", "duration", "agi"],
	"wolf_spirit": ["buff", "agi"],
	"stribog_dash": ["dash", "agi"],
	"hunters_trap": ["area", "duration", "agi"],
	"element_wave": ["area", "magic", "faith"],
	"sun_beam": ["strike", "magic", "faith"],
	"ice_shards": ["projectile", "magic", "faith"],
	"ancestral_heal": ["heal", "faith"],
	"fire_wave": ["cone", "magic", "faith"],
	"raven_swarm": ["projectile", "magic", "faith"],
	"earth_spikes": ["area", "magic", "faith"],
	"ancestral_ward": ["shield", "duration", "faith"],
	"ancestors_wrath": ["area", "ultimate"],
}

## Жорстка вимога зброї: "" = гнучкий; інакше kind зброї або "shield".
const WEAPON_REQ := {
	"power_strike": "melee", "shield_bash": "shield", "triple_slash": "melee",
	"whirlwind": "melee", "ground_slam": "melee",
	"arrow_volley": "arrow", "piercing_shot": "arrow", "rapid_shot": "arrow", "arrow_rain": "arrow",
	"element_wave": "magic", "sun_beam": "magic", "ice_shards": "magic",
	"fire_wave": "magic", "raven_swarm": "magic", "earth_spikes": "magic",
}

const COLORS := ["red", "green", "blue", "white"]
const COLOR_NAMES := {"red": "Червона", "green": "Зелена", "blue": "Синя", "white": "Біла"}
const COLOR_STAT := {"red": "str", "green": "agi", "blue": "faith", "white": ""}

## Каталог ниток: id -> {name, color, mods{}, tags[] (порожньо = будь-який бойовий), rarities allowed}.
const THREADS := {
	"fury": {"name": "Нитка люті", "mods": {"dmg_pct": 18.0}, "tags": []},
	"circle": {"name": "Нитка кола", "mods": {"radius_pct": 20.0}, "tags": ["area"]},
	"far": {"name": "Нитка далі", "mods": {"range_pct": 20.0}, "tags": ["projectile", "strike"]},
	"time": {"name": "Нитка часу", "mods": {"cd_pct": -15.0}, "tags": []},
	"thrift": {"name": "Нитка ощадливості", "mods": {"mana_pct": -18.0}, "tags": []},
	"many": {"name": "Нитка множини", "mods": {"count": 1.0}, "tags": ["projectile", "cone", "chain"]},
	"lasting": {"name": "Нитка тривалості", "mods": {"duration_pct": 25.0}, "tags": ["buff", "duration", "shield"]},
	"thunder": {"name": "Нитка грому", "mods": {"stun": 0.4}, "tags": ["strike", "area", "melee"]},
}

const THREAD_IDS := ["fury", "circle", "far", "time", "thrift", "many", "lasting", "thunder"]

const STARTER_IDS := ["power_strike", "shield_bash", "triple_slash", "arrow_volley", "piercing_shot", "rapid_shot", "element_wave", "sun_beam", "ice_shards"]


static func skill_stat(skill_id: String) -> String:
	return Skills.stat_for(skill_id) if Skills.has(skill_id) else "str"


static func tags_of(skill_id: String) -> Array:
	return TAGS.get(skill_id, [])


static func weapon_req(skill_id: String) -> String:
	return str(WEAPON_REQ.get(skill_id, ""))


## Вимоги науза на його власному рівні (не з урахуванням +рівень з Древа).
static func requirements(skill_id: String, level: int) -> Dictionary:
	var lv := clampi(level, 1, MAX_LEVEL)
	var st := skill_stat(skill_id)
	# орієнтир з дизайну: lvl1 → hero1/stat5; lvl8→8/22; lvl15→15/40; lvl20→20/55
	var hero_lv := lv
	var need := 5.0 + (lv - 1) * (50.0 / 19.0)  # ≈5..55
	return {"hero_level": hero_lv, "stat": st, "stat_min": int(round(need))}


static func thread_slots(level: int) -> int:
	var n := 0
	for need in THREAD_SLOTS_AT:
		if level >= int(need):
			n += 1
	return n


static func xp_to_next(level: int) -> int:
	return 8 + level * 6


## Створює словник-предмет науза.
static func make_nauz(skill_id: String, level: int = 1, rarity: int = 0, uid: int = 0) -> Dictionary:
	var d: Dictionary = Skills.get_def(skill_id)
	var name := str(d.get("name", skill_id))
	return {
		"uid": uid, "base": "nauz_" + skill_id, "kind": "nauz", "skill": skill_id,
		"rarity": clampi(rarity, 0, Items.RARITIES.size() - 1), "ilvl": clampi(level, 1, MAX_LEVEL),
		"level": clampi(level, 1, MAX_LEVEL), "xp": 0,
		"name": name, "stats": {}, "threads": [],  # [{id, color, rarity}]
	}


static func make_thread(thread_id: String, color: String, rarity: int = 0, uid: int = 0) -> Dictionary:
	var t: Dictionary = THREADS.get(thread_id, {})
	var c := color if color in COLORS else "white"
	var nm := "%s %s" % [COLOR_NAMES.get(c, c), str(t.get("name", thread_id))]
	return {
		"uid": uid, "base": "thread_" + thread_id, "kind": "thread",
		"thread": thread_id, "color": c,
		"rarity": clampi(rarity, 0, Items.RARITIES.size() - 1), "ilvl": 1,
		"name": nm, "stats": {},
	}


static func is_nauz(item: Variant) -> bool:
	return typeof(item) == TYPE_DICTIONARY and str(item.get("kind", "")) == "nauz"


static func is_thread(item: Variant) -> bool:
	return typeof(item) == TYPE_DICTIONARY and str(item.get("kind", "")) == "thread"


static func color_ok(nauz: Dictionary, color: String) -> bool:
	if color == "white":
		return true
	var st := skill_stat(str(nauz.get("skill", "")))
	return COLOR_STAT.get(color, "") == st


static func thread_fits(nauz: Dictionary, thread_item: Dictionary) -> bool:
	return thread_fit_reason(nauz, thread_item) == ""


## Порожньо = пасує; інакше причина українською (колір/теги/дублікат).
static func thread_fit_reason(nauz: Dictionary, thread_item: Dictionary) -> String:
	if not is_nauz(nauz):
		return "Немає цільового науза"
	if not is_thread(thread_item):
		return "Це не нитка"
	var color := str(thread_item.get("color", "white"))
	if not color_ok(nauz, color):
		var st := skill_stat(str(nauz.get("skill", "")))
		var need_c := ""
		for c in COLOR_STAT:
			if COLOR_STAT[c] == st:
				need_c = str(COLOR_NAMES.get(c, c))
				break
		return "Колір «%s» не пасує (потрібна %s або біла)" % [
			str(COLOR_NAMES.get(color, color)), need_c if need_c != "" else "відповідна"]
	var tid := str(thread_item.get("thread", ""))
	var tdef: Dictionary = THREADS.get(tid, {})
	var need: Array = tdef.get("tags", [])
	if not need.is_empty():
		var have := tags_of(str(nauz.get("skill", "")))
		var ok_tag := false
		for tag in need:
			if tag in have:
				ok_tag = true
				break
		if not ok_tag:
			return "Теги нитки не пасують до вміння"
	# дублікат того самого типу нитки
	for th in nauz.get("threads", []):
		if typeof(th) == TYPE_DICTIONARY and str(th.get("thread", "")) == tid:
			return "Така нитка вже вплетена"
	return ""


## Сума mods з вплетених ниток (з урахуванням thread_power_pct з Древа).
static func thread_mods(nauz: Dictionary, power_pct: float = 0.0) -> Dictionary:
	var out := {}
	var mult := 1.0 + power_pct / 100.0
	for th in nauz.get("threads", []):
		if typeof(th) != TYPE_DICTIONARY:
			continue
		var tdef: Dictionary = THREADS.get(str(th.get("thread", "")), {})
		var mods: Dictionary = tdef.get("mods", {})
		var rmult := 1.0 + 0.1 * float(th.get("rarity", 0))
		for k in mods:
			out[k] = float(out.get(k, 0.0)) + float(mods[k]) * mult * rmult
	return out


## Ефективний рівень для сили вміння (власний + бонус Древа), вимоги лишаються від власного.
static func power_level(nauz: Dictionary) -> int:
	var own := clampi(int(nauz.get("level", 1)), 1, MAX_LEVEL)
	var bonus := int(HeroStats.bonus("nauz_level"))
	return clampi(own + bonus, 1, MAX_LEVEL)


## Mods від рівня науза + ниток.
static func mods_for_nauz(nauz: Dictionary) -> Dictionary:
	var lv := power_level(nauz)
	var own := clampi(int(nauz.get("level", 1)), 1, MAX_LEVEL)
	# сила росте ~ +4% dmg за рівень понад 1, радіус/тривалість трохи
	var mods := {
		"dmg_pct": 4.0 * float(lv - 1),
		"radius_pct": 1.5 * float(lv - 1),
		"range_pct": 1.5 * float(lv - 1),
		"duration_pct": 1.5 * float(lv - 1),
		"mana_pct": 1.2 * float(own - 1),  # вартість від власного рівня
	}
	var tm := thread_mods(nauz, HeroStats.bonus("thread_power_pct"))
	for k in tm:
		mods[k] = float(mods.get(k, 0.0)) + float(tm[k])
	return mods


static func can_use(nauz: Dictionary) -> String:
	## Порожньо = можна; інакше причина українською.
	if not is_nauz(nauz):
		return "Це не науз"
	var skill := str(nauz.get("skill", ""))
	if not Skills.has(skill):
		return "Невідоме вміння"
	var req := requirements(skill, int(nauz.get("level", 1)))
	if GameState.level < int(req["hero_level"]):
		return "Потрібен рівень героя %d" % int(req["hero_level"])
	var st := str(req["stat"])
	if HeroStats.stat_shown(st) < int(req["stat_min"]):
		var names := {"str": "Сила", "agi": "Спритність", "faith": "Віра"}
		var nm: String = str(names.get(st, st))
		return "Потрібно: %s %d" % [nm, int(req["stat_min"])]
	var wreq := weapon_req(skill)
	if wreq != "":
		if wreq == "shield":
			if not HeroStats.has_shield():
				return "Потрібен щит"
		else:
			if HeroStats.attack_kind() != wreq:
				var wnames := {"melee": "холодна зброя", "arrow": "лук або арбалет", "magic": "магічна зброя"}
				var wn: String = str(wnames.get(wreq, wreq))
				return "Потрібен: %s" % wn
	if int(HeroStats.bonus("one_path")) > 0:
		var filled := 0
		for s in GameState.sockets:
			if typeof(s) == TYPE_DICTIONARY and not s.is_empty():
				filled += 1
		if filled > 1:
			return "Ключ «Один шлях»: лише один науз"
	return ""


static func add_nauz_xp(nauz: Dictionary, amount: int) -> bool:
	## true якщо науз підвищив рівень.
	if amount <= 0 or int(nauz.get("level", 1)) >= MAX_LEVEL:
		return false
	var mult := 1.0 + HeroStats.bonus("nauz_xp_pct") / 100.0
	nauz["xp"] = int(nauz.get("xp", 0)) + int(round(float(amount) * mult))
	var gained := false
	while int(nauz.get("level", 1)) < MAX_LEVEL and int(nauz["xp"]) >= xp_to_next(int(nauz["level"])):
		nauz["xp"] = int(nauz["xp"]) - xp_to_next(int(nauz["level"]))
		nauz["level"] = int(nauz["level"]) + 1
		nauz["ilvl"] = int(nauz["level"])
		gained = true
	return gained


static func random_thread(rng: RandomNumberGenerator, rarity: int = 0, prefer_stat: String = "") -> Dictionary:
	var tid: String = THREAD_IDS[rng.randi() % THREAD_IDS.size()]
	var color := "white"
	var roll := rng.randf()
	if prefer_stat == "str":
		color = "white" if roll < 0.12 else "red"
	elif prefer_stat == "agi":
		color = "white" if roll < 0.12 else "green"
	elif prefer_stat == "faith":
		color = "white" if roll < 0.12 else "blue"
	else:
		color = COLORS[rng.randi() % COLORS.size()]
	return make_thread(tid, color, rarity)


static func random_nauz(rng: RandomNumberGenerator, rarity: int = 0, level: int = 1) -> Dictionary:
	var ids: Array = Skills.ORDER.duplicate()
	var sid: String = ids[rng.randi() % ids.size()]
	return make_nauz(sid, level, rarity)


## Вартість розв'язати науз у Мокрини.
static func untie_cost(nauz: Dictionary) -> int:
	var r := int(nauz.get("rarity", 0))
	var lv := int(nauz.get("level", 1))
	if r >= 3:
		return 700 + 25 * lv
	if r == 2:
		return 350 + 15 * lv
	if r == 1:
		if lv <= 7: return 100
		if lv <= 14: return 180
		return 260
	if lv <= 7: return 40
	if lv <= 14: return 80
	return 120


static func untie_thread_chance(nauz: Dictionary) -> float:
	var r := int(nauz.get("rarity", 0))
	var lv := int(nauz.get("level", 1))
	if r >= 3: return 0.95
	if r == 2: return 0.85
	if r == 1:
		if lv <= 7: return 0.55
		if lv <= 14: return 0.70
		return 0.80
	if lv <= 7: return 0.35
	if lv <= 14: return 0.45
	return 0.55


static func extract_cost(nauz: Dictionary) -> int:
	return int(round(float(untie_cost(nauz)) * 0.6))


static func max_level() -> int:
	return MAX_LEVEL


static func socket_count() -> int:
	return SOCKETS


static func thread_ids() -> Array:
	return THREAD_IDS.duplicate()


static func starter_ids() -> Array:
	var out: Array = []
	for c in Gear.CLASS_IDS:
		for sk in Gear.STARTER_SKILLS[c]:
			if not (sk in out):
				out.append(sk)
	return out


