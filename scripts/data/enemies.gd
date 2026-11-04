## Вороги Ордену Єдиного: моторошна темна казка.
class_name EnemyDefs

const IDS := ["novice", "werewolf", "wraith", "hound", "archer", "brute", "skel_minion", "skel_warrior", "skel_rogue", "skel_mage"]

const DATA := {
	"novice": {
		"name": "Послушник Ордену", "hp": 95.0, "dmg": 9.0, "speed": 3.1, "xp": 16.0,
		"aggro": 10.0, "range": 1.7, "cooldown": 1.3, "windup": 0.45, "radius": 0.45,
		"ranged": false, "height": 2.0,
	},
	"werewolf": {
		"name": "Перевертень", "hp": 130.0, "dmg": 10.0, "speed": 3.6, "xp": 26.0,
		"aggro": 11.0, "range": 1.8, "cooldown": 1.0, "windup": 0.35, "radius": 0.5,
		"ranged": false, "height": 2.0, "beast_speed": 1.8, "beast_dmg": 1.3,
	},
	"wraith": {
		"name": "Привид", "hp": 66.0, "dmg": 9.0, "speed": 2.4, "xp": 24.0,
		"aggro": 13.0, "range": 11.0, "cooldown": 2.4, "windup": 0.55, "radius": 0.4,
		"ranged": true, "height": 2.1, "keep_min": 5.5, "keep_max": 9.0, "mana_drain": 4.0, "bolt": "A8F0FF",
	},
	"hound": {
		"name": "Цепний пес Ордену", "hp": 62.0, "dmg": 8.0, "speed": 4.9, "xp": 14.0,
		"aggro": 12.0, "range": 1.5, "cooldown": 0.9, "windup": 0.25, "radius": 0.4,
		"ranged": false, "height": 1.0,
	},
	"archer": {
		"name": "Лучник Ордену", "hp": 80.0, "dmg": 12.0, "speed": 2.9, "xp": 24.0,
		"aggro": 14.0, "range": 12.0, "cooldown": 2.0, "windup": 0.5, "radius": 0.42,
		"ranged": true, "height": 2.0, "keep_min": 6.5, "keep_max": 10.0, "mana_drain": 0.0, "bolt": "E8D9A6",
	},
	"brute": {
		"name": "Кат Ордену", "hp": 240.0, "dmg": 20.0, "speed": 2.5, "xp": 42.0,
		"aggro": 9.0, "range": 2.2, "cooldown": 1.9, "windup": 0.7, "radius": 0.65,
		"ranged": false, "height": 2.7,
	},
	# ---- нежить (руїни, печери) ----
	"skel_minion": {
		"name": "Мрець", "hp": 85.0, "dmg": 9.0, "speed": 3.3, "xp": 16.0,
		"aggro": 11.0, "range": 1.7, "cooldown": 1.1, "windup": 0.4, "radius": 0.45,
		"ranged": false, "height": 2.0,
	},
	"skel_warrior": {
		"name": "Кістяний вій", "hp": 210.0, "dmg": 16.0, "speed": 2.8, "xp": 36.0,
		"aggro": 10.0, "range": 2.0, "cooldown": 1.5, "windup": 0.55, "radius": 0.55,
		"ranged": false, "height": 2.2,
	},
	"skel_rogue": {
		"name": "Кістяний стрілець", "hp": 75.0, "dmg": 12.0, "speed": 3.0, "xp": 24.0,
		"aggro": 14.0, "range": 12.0, "cooldown": 1.9, "windup": 0.5, "radius": 0.42,
		"ranged": true, "height": 2.0, "keep_min": 6.0, "keep_max": 10.0, "mana_drain": 0.0, "bolt": "D8D0B0",
	},
	"skel_mage": {
		"name": "Мертвий чаклун", "hp": 90.0, "dmg": 13.0, "speed": 2.5, "xp": 30.0,
		"aggro": 13.0, "range": 11.0, "cooldown": 2.2, "windup": 0.6, "radius": 0.42,
		"ranged": true, "height": 2.1, "keep_min": 5.5, "keep_max": 9.0, "mana_drain": 5.0, "bolt": "9BFF7A",
	},
}

## Рівень ворога в локації: від мінімального до максимального, залежно від відстані до входу (0..1) і трохи випадково.
static func level_in(loc: Dictionary, t: float, rng: RandomNumberGenerator) -> int:
	var lo := int(loc["levels"][0])
	var hi := int(loc["levels"][1])
	var x := clampf(t + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
	var base := clampi(lo + int(round(x * float(hi - lo))), lo, hi)
	# вороги ростуть разом із героєм: max(рівень місцини, рівень героя) + 0..2
	return maxi(base, GameState.level) + rng.randi_range(0, 2)


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})

## Характеристики ворога зростають із рівнем.
static func level_mult(level: int) -> float:
	return 1.0 + 0.15 * float(level - 1)
