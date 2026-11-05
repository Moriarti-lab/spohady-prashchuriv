## Активні навички (чотири швидкі слоти). Усе описано даними: вид (kind) + числа.
## Поліпшення з Древа (вузли `mod_skill` + `mods`) змінюють числа через Skills.params().
##
## Види: nova (коло навколо героя, може бити кілька разів), cone (кілька ударів зброєю по сектору),
## strike (один удар по найближчому ворогу з приголомшенням), volley (снаряди), zone (ділянка на землі, з затримкою й тіками),
## chain (блискавка між ворогами), buff (посилення), shield (поглинає шкоду), heal, dash.
## Ключі mods: dmg_pct, radius_pct, range_pct, cd_pct (мінус = швидше), mana_pct (мінус = дешевше),
## count (+снарядів/ударів/стрибків), duration_pct, power_pct (сила посилення), heal_pct, stun (+секунди).
class_name Skills

const MOD_TEXT := {
	"dmg_pct": "%s%% шкоди", "radius_pct": "%s%% радіуса", "range_pct": "%s%% дальності", "cd_pct": "%s%% часу відновлення",
	"mana_pct": "%s%% вартості Чару", "count": "%s до кількості", "duration_pct": "%s%% тривалості",
	"power_pct": "%s%% сили ефекту", "heal_pct": "%s%% лікування", "stun": "%s с приголомшення",
}

const DATA := {
	# ---------- Дружинник (Сила) ----------
	"power_strike": {"name": "Могутній удар", "kind": "nova", "stat": "str", "short": "Удар", "color": Color("D8574B"),
		"base": 30.0, "radius": 4.2, "cd": 5.0, "mana": 14.0, "knock": 9.0, "role": "Площа"},
	"shield_bash": {"name": "Удар щитом", "kind": "strike", "stat": "str", "short": "Щит", "color": Color("C9A45A"),
		"base": 100.0, "range": 3.6, "cd": 11.0, "mana": 16.0, "stun": 1.2, "knock": 8.0, "role": "Одна ціль"},
	"triple_slash": {"name": "Потрійний розріз", "kind": "cone", "stat": "str", "short": "Різ", "color": Color("E8C27A"),
		"base": 20.0, "range": 3.2, "arc": 150.0, "count": 3, "delay": 0.13, "cd": 2.4, "mana": 22.0, "knock": 3.0, "role": "Швидка"},
	"whirlwind": {"name": "Вихор лез", "kind": "nova", "stat": "str", "short": "Вихор", "color": Color("E08A4B"),
		"base": 15.0, "radius": 3.3, "ticks": 4, "tick": 0.22, "cd": 8.0, "mana": 16.0, "knock": 3.5},
	"battle_cry": {"name": "Бойовий клич", "kind": "buff", "stat": "str", "short": "Клич", "color": Color("F0B36A"),
		"buff": {"dmg_pct": 25.0, "atk_speed_pct": 15.0}, "dur": 10.0, "cd": 24.0, "mana": 18.0, "radius": 5.0, "fear": 0.0},
	"ground_slam": {"name": "Удар об землю", "kind": "nova", "stat": "str", "short": "Грім", "color": Color("B98A52"),
		"base": 55.0, "radius": 5.0, "cd": 12.0, "mana": 24.0, "stun": 1.0, "knock": 11.0},
	"chain_lightning": {"name": "Перунів ланцюг", "kind": "chain", "stat": "str", "short": "Ланцюг", "color": Color("8FC8FF"),
		"base": 38.0, "range": 12.0, "jump": 6.0, "count": 4, "cd": 7.0, "mana": 20.0},
	"iron_wall": {"name": "Залізна стіна", "kind": "buff", "stat": "str", "short": "Стіна", "color": Color("9AA3AD"),
		"buff": {"dr_pct": 35.0, "armor": 40.0}, "dur": 7.0, "cd": 20.0, "mana": 16.0},
	# ---------- Стрілець (Спритність) ----------
	"arrow_volley": {"name": "Град стріл", "kind": "volley", "stat": "agi", "short": "Стріли", "color": Color("7CBF5A"),
		"base": 12.0, "count": 6, "spread": 70.0, "speed": 22.0, "life": 0.9, "cd": 5.0, "mana": 14.0, "role": "Площа"},
	"piercing_shot": {"name": "Влучний постріл", "kind": "volley", "stat": "agi", "short": "Постріл", "color": Color("B7E07A"),
		"base": 105.0, "count": 1, "spread": 0.0, "speed": 32.0, "life": 0.9, "pierce": true, "big": true, "cd": 10.0, "mana": 14.0, "role": "Одна ціль"},
	"rapid_shot": {"name": "Швидкий приціл", "kind": "volley", "stat": "agi", "short": "Приціл", "color": Color("DDE69A"),
		"base": 20.0, "count": 3, "spread": 6.0, "delay": 0.1, "speed": 28.0, "life": 0.8, "cd": 2.0, "mana": 20.0, "role": "Швидка"},
	"arrow_rain": {"name": "Злива стріл", "kind": "zone", "stat": "agi", "short": "Злива", "color": Color("8FD06A"),
		"base": 11.0, "radius": 4.2, "ticks": 6, "tick": 0.4, "delay": 0.3, "at": "target", "range": 12.0, "cd": 12.0, "mana": 26.0},
	"poison_cloud": {"name": "Отруйна хмара", "kind": "zone", "stat": "agi", "short": "Отрута", "color": Color("9BCB4F"),
		"base": 9.0, "radius": 3.6, "ticks": 8, "tick": 0.75, "delay": 0.0, "at": "self", "slow": 0.35, "slow_t": 1.2, "cd": 14.0, "mana": 22.0},
	"wolf_spirit": {"name": "Дух вовка", "kind": "buff", "stat": "agi", "short": "Вовк", "color": Color("A9B7C7"),
		"buff": {"move_pct": 30.0, "atk_speed_pct": 20.0, "lifesteal_pct": 6.0}, "dur": 9.0, "cd": 26.0, "mana": 20.0},
	"stribog_dash": {"name": "Подих Стрибога", "kind": "dash", "stat": "agi", "short": "Ривок", "color": Color("9FE3E0"),
		"dist": 6.0, "radius": 3.5, "knock": 12.0, "cd": 30.0, "mana": 10.0},
	"hunters_trap": {"name": "Мисливська пастка", "kind": "zone", "stat": "agi", "short": "Пастка", "color": Color("C9A06A"),
		"base": 55.0, "radius": 3.0, "ticks": 1, "tick": 0.1, "delay": 1.2, "at": "ahead", "stun": 2.0, "cd": 15.0, "mana": 14.0},
	# ---------- Волхв (Віра) ----------
	"element_wave": {"name": "Хвиля стихії", "kind": "nova", "stat": "faith", "short": "Хвиля", "color": Color("3FB9B3"),
		"base": 26.0, "radius": 6.0, "cd": 6.0, "mana": 18.0, "knock": 5.0, "role": "Площа"},
	"sun_beam": {"name": "Сонячний промінь", "kind": "strike", "stat": "faith", "short": "Промінь", "color": Color("FFD97A"),
		"base": 110.0, "range": 14.0, "cd": 11.0, "mana": 20.0, "stun": 0.0, "knock": 2.0, "ranged": true, "role": "Одна ціль"},
	"ice_shards": {"name": "Крижані уламки", "kind": "volley", "stat": "faith", "short": "Крига", "color": Color("9FD8FF"),
		"base": 21.0, "count": 3, "spread": 8.0, "delay": 0.1, "speed": 24.0, "life": 0.8, "slow": 0.4, "slow_t": 2.0, "magic": true, "cd": 2.2, "mana": 24.0, "role": "Швидка"},
	"ancestral_heal": {"name": "Поклик пращурів", "kind": "heal", "stat": "faith", "short": "Поклик", "color": Color("F2D58A"),
		"heal_pct": 0.30, "cd": 14.0, "mana": 22.0},
	"fire_wave": {"name": "Вогняний вал", "kind": "cone", "stat": "faith", "short": "Вогонь", "color": Color("FF8B3D"),
		"base": 28.0, "range": 7.0, "arc": 80.0, "count": 2, "delay": 0.25, "cd": 8.0, "mana": 20.0, "knock": 4.0},
	"raven_swarm": {"name": "Круки Мари", "kind": "volley", "stat": "faith", "short": "Круки", "color": Color("8A7FB5"),
		"base": 15.0, "count": 8, "spread": 360.0, "speed": 18.0, "life": 0.9, "magic": true, "cd": 9.0, "mana": 22.0},
	"earth_spikes": {"name": "Земляні списи", "kind": "zone", "stat": "faith", "short": "Списи", "color": Color("B08A5A"),
		"base": 24.0, "radius": 3.0, "ticks": 3, "tick": 0.5, "delay": 0.4, "at": "target", "range": 12.0, "stun": 0.7, "cd": 11.0, "mana": 22.0},
	"ancestral_ward": {"name": "Оберіг пращурів", "kind": "shield", "stat": "faith", "short": "Оберіг", "color": Color("F5E3A8"),
		"absorb": 60.0, "per_faith": 3.0, "dur": 10.0, "cd": 22.0, "mana": 22.0},
	# ---------- Кульмінація Древа ----------
	"ancestors_wrath": {"name": "Гнів пращурів", "kind": "nova", "stat": "best", "short": "Гнів", "color": Color("FFD060"),
		"base": 150.0, "radius": 11.0, "cd": 40.0, "mana": 60.0, "stun": 2.0, "knock": 14.0, "ultimate": true},
}

## Порядок для списків (за класами).
const ORDER := ["power_strike", "shield_bash", "triple_slash", "whirlwind", "battle_cry", "ground_slam", "chain_lightning", "iron_wall",
	"arrow_volley", "piercing_shot", "rapid_shot", "arrow_rain", "poison_cloud", "wolf_spirit", "stribog_dash", "hunters_trap",
	"element_wave", "sun_beam", "ice_shards", "ancestral_heal", "fire_wave", "raven_swarm", "earth_spikes", "ancestral_ward", "ancestors_wrath"]


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})


static func has(id: String) -> bool:
	return DATA.has(id)


## icon_id навички в реєстрі (sk_*). «Хвиля стихії» залежить від благословення.
static func icon_id(id: String, blessing: String = "") -> String:
	if id == "element_wave" and blessing != "" and blessing != "stribog":
		return "sk_element_wave_" + blessing
	if id == "element_wave" and blessing == "stribog":
		return "sk_stribog_dash"
	return "sk_" + id


## Поліпшення вміння: з вставленого науза (рівень + нитки). node_ids лишається для сумісності тестів старого формату.
static func mods_for(id: String, node_ids: Array = []) -> Dictionary:
	var out := {}
	# v0.5: науз у гнізді
	for s in GameState.sockets:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("skill", "")) == id:
			return Nauzi.mods_for_nauz(s)
	# сумісність: старі mod_skill вузли (якщо ще є в тестовому Древі)
	var list: Array = node_ids if not node_ids.is_empty() else GameState.unlocked
	for nid in list:
		var d: Dictionary = PerkTree.get_def(str(nid))
		if d.is_empty() or str(d.get("mod_skill", "")) != id:
			continue
		var m: Dictionary = d.get("mods", {})
		for k in m:
			out[k] = float(out.get(k, 0.0)) + float(m[k])
	return out


## Підсумкові числа навички з урахуванням поліпшень і загального скорочення відновлення.
static func params(id: String, mods: Dictionary = {}, cdr_pct: float = 0.0) -> Dictionary:
	var d: Dictionary = DATA.get(id, {})
	var p: Dictionary = d.duplicate(true)
	if d.is_empty():
		return p
	var dm := 1.0 + float(mods.get("dmg_pct", 0.0)) / 100.0
	if p.has("base"):
		p["base"] = float(d["base"]) * dm
	if p.has("radius"):
		p["radius"] = float(d["radius"]) * (1.0 + float(mods.get("radius_pct", 0.0)) / 100.0)
	if p.has("range"):
		p["range"] = float(d["range"]) * (1.0 + float(mods.get("range_pct", 0.0)) / 100.0)
	if p.has("count"):
		p["count"] = int(d["count"]) + int(round(float(mods.get("count", 0.0))))
	if p.has("dur"):
		p["dur"] = float(d["dur"]) * (1.0 + float(mods.get("duration_pct", 0.0)) / 100.0)
	if p.has("ticks") and mods.has("duration_pct"):
		p["ticks"] = maxi(1, int(round(float(d["ticks"]) * (1.0 + float(mods["duration_pct"]) / 100.0))))
	if p.has("buff"):
		var pw := 1.0 + float(mods.get("power_pct", 0.0)) / 100.0
		for k in d["buff"]:
			p["buff"][k] = float(d["buff"][k]) * pw
	if p.has("absorb"):
		p["absorb"] = float(d["absorb"]) * (1.0 + float(mods.get("power_pct", 0.0)) / 100.0)
		p["per_faith"] = float(d["per_faith"]) * (1.0 + float(mods.get("power_pct", 0.0)) / 100.0)
	if p.has("heal_pct"):
		p["heal_pct"] = float(d["heal_pct"]) * (1.0 + float(mods.get("heal_pct", 0.0)) / 100.0)
	p["stun"] = float(d.get("stun", 0.0)) + float(mods.get("stun", 0.0))
	var cd_mult := maxf(0.25, 1.0 + float(mods.get("cd_pct", 0.0)) / 100.0) * maxf(0.4, 1.0 - cdr_pct / 100.0)
	p["cd"] = maxf(0.4, float(d["cd"]) * cd_mult)
	p["mana"] = maxf(1.0, float(d["mana"]) * maxf(0.2, 1.0 + float(mods.get("mana_pct", 0.0)) / 100.0))
	return p


## Головний стат ультимативної навички — найбільший із трьох.
static func stat_for(id: String) -> String:
	var s := str(DATA.get(id, {}).get("stat", "str"))
	if s != "best":
		return s
	var best := "str"
	for k in ["agi", "faith"]:
		if HeroStats.stat(k) > HeroStats.stat(best):
			best = k
	return best


## Текст навички українською з числами. with_mods — урахувати поліпшення з Древа.
static func describe(id: String, with_mods: bool = false) -> String:
	var d: Dictionary = DATA.get(id, {})
	if d.is_empty():
		return ""
	var mods := mods_for(id) if with_mods else {}
	var p := params(id, mods)
	var lines: Array = []
	match str(d["kind"]):
		"nova":
			var t := "Шкода %s" % _n(roundf(float(p["base"])))
			if int(p.get("ticks", 1)) > 1:
				t += " × %d удари" % int(p["ticks"])
			lines.append(t + ", радіус %s м" % _n(snappedf(float(p["radius"]), 0.1)))
		"cone":
			lines.append("Шкода %s × %d удари, дальність %s м, сектор %d°" % [_n(roundf(float(p["base"]))), int(p["count"]), _n(snappedf(float(p["range"]), 0.1)), int(d["arc"])])
		"strike":
			lines.append("Шкода %s по найближчому ворогові, дальність %s м" % [_n(roundf(float(p["base"]))), _n(snappedf(float(p["range"]), 0.1))])
		"volley":
			var c := int(p["count"])
			var t2 := "Шкода %s" % _n(roundf(float(p["base"])))
			if c > 1:
				t2 += " × %d %s" % [c, "снарядів" if float(d.get("spread", 0.0)) > 20.0 else "постріли"]
			if bool(d.get("pierce", false)):
				t2 += ", пробиває всіх на шляху"
			lines.append(t2)
		"zone":
			var tot := int(p["ticks"])
			var t3 := "Шкода %s" % _n(roundf(float(p["base"])))
			if tot > 1:
				t3 += " × %d тіків" % tot
			t3 += ", радіус %s м" % _n(snappedf(float(p["radius"]), 0.1))
			lines.append(t3)
		"chain":
			lines.append("Шкода %s, перескакує на %d ворогів" % [_n(roundf(float(p["base"]))), int(p["count"])])
		"buff":
			var parts: Array = []
			for k in p["buff"]:
				parts.append(PerkTree.stat_line(str(k), float(p["buff"][k])))
			lines.append("На %s с: %s" % [_n(snappedf(float(p["dur"]), 0.1)), "; ".join(parts)])
		"shield":
			lines.append("Поглинає %s шкоди (+%s за Віру) на %s с" % [_n(roundf(float(p["absorb"]))), _n(float(p["per_faith"])), _n(snappedf(float(p["dur"]), 0.1))])
		"heal":
			lines.append("Лікує %s%% життя" % _n(roundf(float(p["heal_pct"]) * 100.0)))
		"dash":
			lines.append("Ривок на %s м, відкидає ворогів поруч" % _n(float(p["dist"])))
	if float(p.get("stun", 0.0)) > 0.0:
		lines.append("Приголомшує на %s с" % _n(snappedf(float(p["stun"]), 0.1)))
	if float(d.get("slow", 0.0)) > 0.0:
		lines.append("Сповільнює на %d%%" % int(float(d["slow"]) * 100.0))
	lines.append("Відновлення %s с · Чар %s" % [_n(snappedf(float(p["cd"]), 0.1)), _n(roundf(float(p["mana"])))])
	return "\n".join(lines)


## «+12% шкоди, −10% вартості Чару» — для опису вузлів-поліпшень.
static func mods_text(mods: Dictionary) -> String:
	var parts: Array = []
	for k in MOD_TEXT:
		if mods.has(k) and not is_zero_approx(float(mods[k])):
			parts.append(str(MOD_TEXT[k]) % Strings.signed(float(mods[k])))
	return ", ".join(parts)


static func role_name(id: String) -> String:
	return str(DATA.get(id, {}).get("role", ""))


static func _n(v: float) -> String:
	return Strings.num(v)
