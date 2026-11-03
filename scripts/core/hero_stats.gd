## Формули характеристик. Читає стан із GameState: рівень, Древо й спорядження.
class_name HeroStats

const BASE_MOVE_SPEED := 5.0
const BASE_HP := 120.0
const HP_PER_LEVEL := 20.0
const HP_PER_STR := 8.0


static func tree_sum(key: String) -> float:
	var total := 0.0
	for id in GameState.unlocked:
		total += PerkTree.stat_of(str(id), key)
	return total


## Сума властивості на всьому одягненому спорядженні.
static func gear_sum(key: String) -> float:
	var total := 0.0
	for slot in GameState.equipment:
		var it: Variant = GameState.equipment[slot]
		if typeof(it) == TYPE_DICTIONARY and not it.is_empty():
			total += float(it.get("stats", {}).get(key, 0.0))
	return total


## Сума з Древа й спорядження (для відсоткових і плоских бонусів).
static func bonus(key: String) -> float:
	return tree_sum(key) + gear_sum(key)


static func weapon_item() -> Variant:
	return GameState.equipment.get("weapon", null)


static func weapon_def() -> Dictionary:
	return Items.weapon_def(weapon_item())


## Тип звичайної атаки: melee, arrow або magic. Залежить від одягненої зброї.
static func attack_kind() -> String:
	return str(weapon_def()["kind"])


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


## Шанс крита = 5% + 0,3% × Спритність + бонуси
static func crit_chance() -> float:
	return 0.05 + 0.003 * stat("agi") + bonus("crit_pct") / 100.0


static func crit_mult() -> float:
	return 1.5


static func armor() -> float:
	var a := bonus("armor")
	if GameState.blessing == "svarog":
		a *= 1.10
	return maxf(0.0, a)


## Зменшення шкоди бронею = Броня / (Броня + 200), максимум 75%
static func damage_reduction() -> float:
	var a := armor()
	return minf(0.75, a / (a + 200.0))


static func move_speed() -> float:
	return BASE_MOVE_SPEED * maxf(0.4, 1.0 + bonus("move_pct") / 100.0)


static func attack_interval() -> float:
	return float(weapon_def()["interval"]) / ((1.0 + 0.01 * stat("agi")) * (1.0 + bonus("atk_speed_pct") / 100.0))


static func dmg_mult() -> float:
	var m := 1.0 + bonus("dmg_pct") / 100.0
	if GameState.blessing == "svarog":
		m *= 1.05
	return m


## Шкода = шкода зброї × (1 + 0,02 × головний стат зброї) × бонуси
static func weapon_damage() -> float:
	var w := weapon_def()
	return float(w["dmg"]) * (1.0 + 0.02 * stat(str(w["stat"]))) * dmg_mult()


## Шкода навички: база × (1 + 0,02 × стат навички)
static func skill_damage(skill_id: String) -> float:
	var s: Dictionary = Skills.get_def(skill_id)
	return float(s.get("base", 0.0)) * (1.0 + 0.02 * stat(str(s["stat"]))) * dmg_mult()


static func heal_mult() -> float:
	return 1.2 if GameState.blessing == "dazhbog" else 1.0


static func xp_mult() -> float:
	return 1.0 + tree_sum("xp_pct") / 100.0
