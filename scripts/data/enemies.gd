## Вороги Ордену Єдиного: моторошна темна казка.
class_name EnemyDefs

const IDS := ["novice", "werewolf", "wraith"]

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
		"ranged": true, "height": 2.1, "keep_min": 5.5, "keep_max": 9.0, "mana_drain": 4.0,
	},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})

## Характеристики ворога зростають із рівнем.
static func level_mult(level: int) -> float:
	return 1.0 + 0.15 * float(level - 1)
