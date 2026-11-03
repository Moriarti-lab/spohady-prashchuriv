## Формули характеристик (з дизайн-документа). Читає стан із GameState.
class_name HeroStats

const BASE_MOVE_SPEED := 5.0


static func tree_sum(key: String) -> float:
	var total := 0.0
	for id in GameState.unlocked:
		total += float(PerkTree.NODES[id].get(key, 0))
	return total


static func armor_def() -> Dictionary:
	return Gear.ARMORS[Gear.class_def(GameState.hero_class)["armor"]]


static func weapon_id() -> String:
	return Gear.class_def(GameState.hero_class)["weapon"]


static func weapon_def() -> Dictionary:
	return Gear.WEAPONS[weapon_id()]


## Стат = 5 + бонус крові × (рівень − 1) + вузли дерева + предмети
static func stat(id: String) -> float:
	var b: Dictionary = Blessings.get_def(GameState.blessing)
	var v := 5.0
	if b["main"] == id:
		v += float(b["main_bonus"]) * (GameState.level - 1)
	if b["sub"] == id:
		v += float(b["sub_bonus"]) * (GameState.level - 1)
	v += tree_sum(id)
	v += float(armor_def().get(id, 0.0))
	return v


static func stat_shown(id: String) -> int:
	return int(floor(stat(id)))


## Життя = 50 + 10 × рівень + 5 × Сила
static func max_hp() -> float:
	var base := 50.0 + 10.0 * GameState.level + 5.0 * stat("str")
	return base * (1.0 + tree_sum("hp_pct") / 100.0)


## Чар = 20 + 5 × рівень + 5 × Віра
static func max_mana() -> float:
	return 20.0 + 5.0 * GameState.level + 5.0 * stat("faith")


## Відновлення чару = 1 + Віра / 20 за секунду
static func mana_regen() -> float:
	return 1.0 + stat("faith") / 20.0 + tree_sum("mana_regen") + float(armor_def().get("mana_regen", 0.0))


## Шанс крита = 5% + 0,3% × Спритність
static func crit_chance() -> float:
	return 0.05 + 0.003 * stat("agi")


static func crit_mult() -> float:
	return 1.5


static func armor() -> float:
	var a := float(armor_def()["armor"])
	if GameState.blessing == "svarog":
		a *= 1.10
	return a


## Зменшення шкоди бронею = Броня / (Броня + 200), максимум 75%
static func damage_reduction() -> float:
	var a := armor()
	return minf(0.75, a / (a + 200.0))


static func move_speed() -> float:
	var m := 1.0 + tree_sum("move_pct") / 100.0 + float(armor_def().get("move", 0.0))
	return BASE_MOVE_SPEED * m


static func attack_interval() -> float:
	return float(weapon_def()["interval"]) / (1.0 + 0.01 * stat("agi"))


## Шкода = шкода зброї × (1 + 0,02 × головний стат зброї)
static func weapon_damage() -> float:
	var w := weapon_def()
	var d := float(w["dmg"]) * (1.0 + 0.02 * stat(w["stat"]))
	d *= 1.0 + tree_sum("dmg_pct") / 100.0
	if GameState.blessing == "svarog":
		d *= 1.05
	return d


## Шкода навички: база × (1 + 0,02 × стат навички)
static func skill_damage(skill_id: String) -> float:
	var s: Dictionary = Skills.get_def(skill_id)
	var d := float(s.get("base", 0.0)) * (1.0 + 0.02 * stat(s["stat"]))
	d *= 1.0 + tree_sum("dmg_pct") / 100.0
	if GameState.blessing == "svarog":
		d *= 1.05
	return d


static func heal_mult() -> float:
	return 1.2 if GameState.blessing == "dazhbog" else 1.0
