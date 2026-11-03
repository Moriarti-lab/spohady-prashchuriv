## Стартова зброя й броня, а також три стартові класи.
class_name Gear

const WEAPONS := {
	"sword": {
		"name": "Дружинний меч", "kind": "melee", "dmg": 12.0, "interval": 0.55,
		"range": 2.7, "arc": 150.0, "stat": "str",
	},
	"bow": {
		"name": "Мисливський лук", "kind": "arrow", "dmg": 10.0, "interval": 0.75,
		"range": 13.0, "arc": 0.0, "stat": "agi",
	},
	"staff": {
		"name": "Посох-кий", "kind": "magic", "dmg": 9.0, "interval": 0.8,
		"range": 11.5, "arc": 0.0, "stat": "faith",
	},
}

const ARMORS := {
	"plate": {"name": "Цільнометалева броня", "armor": 60.0, "move": -0.05, "faith": 0.0, "mana_regen": 0.0},
	"mail": {"name": "Кольчуга", "armor": 35.0, "move": 0.0, "faith": 0.0, "mana_regen": 0.0},
	"cloth": {"name": "Балахон із вишитими оберегами", "armor": 10.0, "move": 0.0, "faith": 2.0, "mana_regen": 0.5},
}

const CLASS_IDS := ["druzhynnyk", "strilets", "volkhv"]

const CLASSES := {
	"druzhynnyk": {
		"name": "Дружинник", "weapon": "sword", "offhand": "Щит", "armor": "plate",
		"start_node": "s1", "start_near": "Сили",
		"desc": "Воїн ближнього бою. Бʼє мечем, ховається за щитом.",
	},
	"strilets": {
		"name": "Стрілець", "weapon": "bow", "offhand": "Сагайдак", "armor": "mail",
		"start_node": "a1", "start_near": "Спритності",
		"desc": "Влучний мисливець. Стріляє по найближчому ворогові.",
	},
	"volkhv": {
		"name": "Волхв", "weapon": "staff", "offhand": "", "armor": "cloth",
		"start_node": "f1", "start_near": "Віри",
		"desc": "Заклинач. Магічний снаряд має стихію твого бога.",
	},
}

static func class_def(id: String) -> Dictionary:
	return CLASSES.get(id, {})

static func kit_text(class_id: String) -> String:
	var c: Dictionary = class_def(class_id)
	var w: Dictionary = WEAPONS[c["weapon"]]
	var a: Dictionary = ARMORS[c["armor"]]
	var s: String = w["name"]
	if c["offhand"] != "":
		s += " + " + str(c["offhand"]).to_lower()
	return s + "\n" + a["name"]
