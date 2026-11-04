## Формули характеристик. Читає стан із GameState: рівень, Древо, спорядження та тимчасові посилення.
class_name HeroStats

const BASE_MOVE_SPEED := 5.0
const BASE_HP := 120.0
const HP_PER_LEVEL := 20.0
const HP_PER_STR := 8.0
## Друга зброя в лівій руці додає стільки від своєї шкоди (подвійний хват).
const DUAL_WIELD_RATIO := 0.45
const CDR_CAP := 45.0
const DR_CAP := 0.80

## Тимчасові посилення (бойовий клич тощо): {назва: {stats: {ключ: число}, t: секунди}}.
static var buffs: Dictionary = {}
static var _cache: Dictionary = {}
static var _cache_on := false


static func invalidate() -> void:
	_cache.clear()


static func _ensure_cache_hook() -> void:
	if _cache_on:
		return
	_cache_on = true
	if not GameState.changed.is_connected(invalidate):
		GameState.changed.connect(invalidate)


static func tree_sum(key: String) -> float:
	var ck := "t:" + key
	if _cache.has(ck):
		return float(_cache[ck])
	var total := 0.0
	for id in GameState.unlocked:
		total += PerkTree.stat_of(str(id), key)
	_ensure_cache_hook()
	_cache[ck] = total
	return total


## Сума властивості на всьому одягненому спорядженні.
static func gear_sum(key: String) -> float:
	var ck := "g:" + key
	if _cache.has(ck):
		return float(_cache[ck])
	var total := 0.0
	for slot in GameState.equipment:
		var it: Variant = GameState.equipment[slot]
		if typeof(it) == TYPE_DICTIONARY and not it.is_empty():
			total += float(it.get("stats", {}).get(key, 0.0))
	_ensure_cache_hook()
	_cache[ck] = total
	return total


static func buff_sum(key: String) -> float:
	var total := 0.0
	for name in buffs:
		total += float(buffs[name]["stats"].get(key, 0.0))
	return total


## Сума з Древа, спорядження й посилень (для відсоткових і плоских бонусів).
static func bonus(key: String) -> float:
	return tree_sum(key) + gear_sum(key) + buff_sum(key)


static func add_buff(name: String, stats: Dictionary, seconds: float) -> void:
	buffs[name] = {"stats": stats.duplicate(), "t": seconds}


static func clear_buffs() -> void:
	buffs.clear()


static func tick_buffs(delta: float) -> void:
	for name in buffs.keys():
		buffs[name]["t"] = float(buffs[name]["t"]) - delta
		if float(buffs[name]["t"]) <= 0.0:
			buffs.erase(name)


static func buff_time(name: String) -> float:
	return float(buffs.get(name, {}).get("t", 0.0))


# ---------- Зброя ----------

## Права рука (зброя для звичайної атаки).
static func weapon_item() -> Variant:
	return GameState.equipment.get("main", null)


static func weapon_def() -> Dictionary:
	return Items.weapon_def(weapon_item())


static func off_item() -> Variant:
	return GameState.equipment.get("off", null)


## Зброя в лівій руці (не щит). Порожній словник, якщо її немає.
static func off_weapon_def() -> Dictionary:
	var it: Variant = off_item()
	if typeof(it) == TYPE_DICTIONARY and not it.is_empty() and Items.type_of(it) == "hand1":
		return Items.weapon_def(it)
	return {}


static func has_dual_wield() -> bool:
	return not off_weapon_def().is_empty()


static func has_shield() -> bool:
	var it: Variant = off_item()
	return typeof(it) == TYPE_DICTIONARY and not it.is_empty() and Items.type_of(it) == "shield"


## Тип звичайної атаки: melee, arrow або magic. Залежить від зброї в правій руці.
static func attack_kind() -> String:
	return str(weapon_def()["kind"])


# ---------- Основні характеристики ----------

## Стат = 5 + бонус крові × (рівень − 1) + вузли Древа + предмети
static func stat(id: String) -> float:
	var b: Dictionary = Blessings.get_def(GameState.blessing)
	var v := 5.0
	if b["main"] == id:
		v += float(b["main_bonus"]) * (GameState.level - 1)
	if b["sub"] == id:
		v += float(b["sub_bonus"]) * (GameState.level - 1)
	v += bonus(id)
	return v


static func stat_shown(id: String) -> int:
	return int(floor(stat(id)))


## Життя = (120 + 20 × рівень + 8 × Сила + предмети) × (1 + % з Древа й предметів)
static func max_hp() -> float:
	var base := BASE_HP + HP_PER_LEVEL * GameState.level + HP_PER_STR * stat("str") + bonus("hp")
	return base * (1.0 + bonus("hp_pct") / 100.0)


## Чар = (20 + 5 × рівень + 5 × Віра) × (1 + % з Древа)
static func max_mana() -> float:
	return (20.0 + 5.0 * GameState.level + 5.0 * stat("faith")) * (1.0 + bonus("mana_pct") / 100.0)


## Відновлення чару = 1 + Віра / 20 за секунду + бонуси
static func mana_regen() -> float:
	return maxf(0.2, 1.0 + stat("faith") / 20.0 + bonus("mana_regen"))


## Відновлення життя за секунду: % від максимуму.
static func hp_regen() -> float:
	return maxf(0.0, bonus("hp_regen_pct")) / 100.0 * max_hp()


## Шанс крита = 5% + 0,3% × Спритність + бонуси
static func crit_chance() -> float:
	return minf(0.95, 0.05 + 0.003 * stat("agi") + bonus("crit_pct") / 100.0)


static func crit_mult() -> float:
	return 1.5 + bonus("crit_dmg_pct") / 100.0


static func armor() -> float:
	var a := bonus("armor")
	if GameState.blessing == "svarog":
		a *= 1.10
	return maxf(0.0, a)


## Зменшення шкоди бронею = Броня / (Броня + 200); окремо множиться на «менше шкоди» (dr_pct). Максимум 80%.
static func damage_reduction() -> float:
	var a := armor()
	var by_armor := minf(0.75, a / (a + 200.0))
	var extra := clampf(bonus("dr_pct") / 100.0, 0.0, 0.7)
	return minf(DR_CAP, 1.0 - (1.0 - by_armor) * (1.0 - extra))


static func move_speed() -> float:
	return BASE_MOVE_SPEED * maxf(0.4, 1.0 + bonus("move_pct") / 100.0)


## Скорочення відновлення навичок, %
static func cdr_pct() -> float:
	return clampf(bonus("cdr_pct"), 0.0, CDR_CAP)


static func lifesteal() -> float:
	return clampf(bonus("lifesteal_pct"), 0.0, 40.0) / 100.0


static func thorns() -> float:
	return maxf(0.0, bonus("thorns_pct")) / 100.0


static func gold_mult() -> float:
	return 1.0 + bonus("gold_pct") / 100.0


static func drop_mult() -> float:
	return 1.0 + bonus("drop_pct") / 100.0


static func attack_interval() -> float:
	return float(weapon_def()["interval"]) / ((1.0 + 0.01 * stat("agi")) * (1.0 + bonus("atk_speed_pct") / 100.0))


static func dmg_mult() -> float:
	var m := 1.0 + bonus("dmg_pct") / 100.0
	if GameState.blessing == "svarog":
		m *= 1.05
	return m


## Шкода = шкода зброї × (1 + 0,02 × головний стат зброї) × бонуси (+ друга зброя з коефіцієнтом)
static func weapon_damage() -> float:
	var w := weapon_def()
	var d := float(w["dmg"]) * (1.0 + 0.02 * stat(str(w["stat"])))
	var ow := off_weapon_def()
	if not ow.is_empty():
		d += float(ow["dmg"]) * (1.0 + 0.02 * stat(str(ow["stat"]))) * DUAL_WIELD_RATIO
	return d * dmg_mult()


## Підсумкові числа навички: база, радіус, відновлення… з урахуванням Древа й скорочення відновлення.
static func skill_params(skill_id: String) -> Dictionary:
	return Skills.params(skill_id, Skills.mods_for(skill_id), cdr_pct())


## Шкода навички: база (з поліпшеннями) × (1 + 0,02 × стат навички) × бонуси
static func skill_damage(skill_id: String) -> float:
	var p := skill_params(skill_id)
	return float(p.get("base", 0.0)) * (1.0 + 0.02 * stat(Skills.stat_for(skill_id))) * dmg_mult()


static func heal_mult() -> float:
	return 1.2 if GameState.blessing == "dazhbog" else 1.0


static func xp_mult() -> float:
	return 1.0 + tree_sum("xp_pct") / 100.0
