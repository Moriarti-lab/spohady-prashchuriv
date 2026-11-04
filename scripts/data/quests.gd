## Завдання селища Липівка. Кроки: collect (зібрати предмет), kill_boss, kill (вбити N ворогів виду).
## Стан у GameState.quests: {id: {state: active|ready|done, progress: N}}.
class_name Quests

const REWARD_RESPAWN := 0

const DATA := {
	"herbs": {
		"name": "Цілющі трави", "giver": "herbalist", "turn_in": "herbalist", "requires": "",
		"kind": "collect", "item": "herb", "need": 5, "place": "Темний ліс",
		"intro": "Лихо в селищі: люди хворіють, а трави в мене скінчилися. У Темному лісі ростуть цілющі трави — принеси мені п'ять пучків, дитино. Тільки обережно: там тепер ходять послушники.",
		"progress_text": "Зібрати цілющі трави (Темний ліс)",
		"done_text": "Дякую! Ти врятував не одну душу. Візьми гривні й зілля — я зварила їх сама.",
		"reward": {"gold": 70, "xp": 90, "hp_potions": 2, "mana_potions": 1},
	},
	"alpha": {
		"name": "Вовкулака-ватажок", "giver": "elder", "turn_in": "elder", "requires": "herbs",
		"kind": "kill_boss", "boss": "alpha", "need": 1, "place": "Темний ліс",
		"intro": "Послушники привели до лісу перевертня. Він ватажок: за ним ходять інші. Поки він живий — стежка не безпечна. Убий його, і ми повернемо ліс.",
		"progress_text": "Здолати Вовкулаку-ватажка (Темний ліс)",
		"done_text": "Ліс зітхнув. Це добра звістка. Нехай оберіг і гривні послужать тобі.",
		"reward": {"gold": 160, "xp": 220, "item": {"type": "", "rarity": 2, "ilvl_add": 1}},
	},
	"rushnyk": {
		"name": "Рушник із покинутої хати", "giver": "merchant", "turn_in": "merchant", "requires": "",
		"kind": "collect", "item": "rushnyk", "need": 1, "place": "Покинута хата лісника",
		"intro": "Мій брат утік із хати лісника, коли прийшли послушники, і лишив там материн вишитий рушник. Він мені дорожчий за гроші. Знайдеш у скрині покинутої хати в лісі?",
		"progress_text": "Знайти рушник у покинутій хаті (Темний ліс)",
		"done_text": "Мамин рушник… Дякую. Я знижу ціни для тебе, а поки візьми це.",
		"reward": {"gold": 110, "xp": 140, "perk_points": 1},
	},
	"wraiths": {
		"name": "Страх болота", "giver": "elder", "turn_in": "elder", "requires": "alpha",
		"kind": "kill", "enemy": "wraith", "need": 6, "place": "Гнила твань",
		"intro": "За лісом болото. Там блукають привиди тих, кого Орден не пустив у вирій. Вони не дають ходити стежками. Заспокой шістьох — і дорога до руїн стане вільнішою.",
		"progress_text": "Розвіяти привидів (Гнила твань)",
		"done_text": "Тихіше стало. Ти справжній оберіг роду. Прийми цю дяку.",
		"reward": {"gold": 220, "xp": 380, "item": {"type": "amulet", "rarity": 2, "ilvl_add": 2}},
	},
	"letter": {
		"name": "Лист мисливця", "giver": "herbalist", "turn_in": "elder", "requires": "herbs",
		"kind": "collect", "item": "letter", "need": 1, "place": "Покинута хатина мисливця",
		"intro": "Мисливець із болота обіцяв передати старійшині вістку про Орден, але зник. Його хатина стоїть біля болота. Може, лист ще там, у скрині?",
		"progress_text": "Знайти лист у хатині мисливця (Гнила твань), віднести Богданові",
		"done_text": "Лист… Орден збирає сили в руїнах застави. Отже, час настав. Дякую, що дістав його.",
		"reward": {"gold": 180, "xp": 300, "hp_potions": 3, "mana_potions": 3},
	},
	"inquisitor": {
		"name": "Великий інквізитор", "giver": "elder", "turn_in": "elder", "requires": "letter",
		"kind": "kill_boss", "boss": "inquisitor", "need": 1, "place": "Руїни застави",
		"intro": "Він стирає наші імена. Великий інквізитор сидить у руїнах застави. Якщо його не стане — Орден відступить. Іди, і хай пам'ять предків буде з тобою.",
		"progress_text": "Здолати Великого інквізитора (Руїни застави)",
		"done_text": "Пам'ять роду жива. Ти повернув її нам. Це не кінець, але це велика звитяга!",
		"reward": {"gold": 500, "xp": 900, "perk_points": 2, "item": {"type": "", "rarity": 3, "ilvl_add": 2}},
	},
}

const ORDER := ["herbs", "rushnyk", "alpha", "letter", "wraiths", "inquisitor"]

## Назви квестових предметів: icon_id той самий, що в реєстрі іконок.
const ITEMS := {
	"herb": {"name": "Цілюща трава", "icon": "herb"},
	"rushnyk": {"name": "Вишитий рушник", "icon": "rushnyk"},
	"letter": {"name": "Лист мисливця", "icon": "letter"},
}


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})


static func item_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id))


static func reward_text(id: String) -> String:
	var r: Dictionary = get_def(id).get("reward", {})
	var parts: Array = []
	if r.has("gold"):
		parts.append("%d грн" % int(r["gold"]))
	if r.has("xp"):
		parts.append("%d звитяги" % int(r["xp"]))
	if r.has("hp_potions"):
		parts.append("%d зілля життя" % int(r["hp_potions"]))
	if r.has("mana_potions"):
		parts.append("%d зілля чару" % int(r["mana_potions"]))
	if r.has("perk_points"):
		parts.append("%d перк" % int(r["perk_points"]))
	if r.has("item"):
		var rr := Items.rarity(int(r["item"].get("rarity", 1)))
		parts.append("предмет (%s)" % str(rr["name"]).to_lower())
	return ", ".join(parts)
