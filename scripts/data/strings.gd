## Усі основні тексти інтерфейсу (лише українська, зі словами старої Русі).
class_name Strings

const GAME_TITLE := "Спогади пращурів"
const VERSION := "Пробна версія 0.3.1"

const STAT_NAMES := {"str": "Сила", "agi": "Спритність", "faith": "Віра"}

const HP := "Життя"
const MANA := "Чар"
const XP := "Звитяга"
const LEVEL := "Рівень"
const PERKS := "Перки"
const TREE := "Древо"

const BLESSING_PROMPT := "У тобі тече кров усіх богів. Обери ту, що тобі найближча."
const CLASS_PROMPT := "Обери, ким ти станеш. Це лише зброя, броня й місце старту на Древі: далі підеш куди завгодно."
const NAME_PROMPT := "Як тебе звати, гостю?"

const MOKOSH_INTRO := "Прокинься, %s.\nТи не випадково відкрив цю гру: твоя кров пам'ятає нас.\nСьогодні, у цю мить, ті, хто не знає наших імен, стирають нашу пам'ять.\nЗгадай нас, і допоможи."
const MOKOSH_SIGN := "— Голос Мокоші"

static func stat_name(id: String) -> String:
	return STAT_NAMES.get(id, id)

## Число з комою як у українській: 0,5 замість 0.5
static func num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return ("%.1f" % v).replace(".", ",")


## +5 або −3 (справжній мінус), число з комою.
static func signed(v: float) -> String:
	var t := num(absf(v))
	return ("−" if v < 0.0 else "+") + t


## Кличний відмінок імені: «Ярослав» → «Ярославе». Лише для кирилиці, перше слово.
## Правило наближене: українські імена бувають винятками, тому на крайній випадок ім'я лишається як є.
static func vocative(full: String) -> String:
	var name := full.strip_edges()
	if name == "":
		return name
	var parts := name.split(" ", false)
	var first: String = parts[0]
	var v := _vocative_word(first)
	parts[0] = v
	return " ".join(parts)


const _VOWELS := "аеєиіїоуюя"
const _VOC_EXCEPT := {
	"Лев": "Леве", "Олег": "Олеже", "Ігор": "Ігорю", "Петро": "Петре", "Дмитро": "Дмитре",
	"Павло": "Павле", "Данило": "Даниле", "Богдан": "Богдане", "Любов": "Любове",
	"Марко": "Марку", "Тарас": "Тарасе", "Ярослав": "Ярославе", "Святослав": "Святославе",
}


static func _vocative_word(w: String) -> String:
	if w == "":
		return w
	# лише кирилиця
	for i in range(w.length()):
		var c := w.unicode_at(i)
		var cyr := (c >= 0x0400 and c <= 0x04FF)
		if not cyr and c != 0x2019 and c != 0x27 and c != 0x2D:
			return w
	if _VOC_EXCEPT.has(w):
		var ex: String = _VOC_EXCEPT[w]
		if w == "Ігор":
			ex = "Ігоре"
		return ex
	var low := w.to_lower()
	var n := low.length()
	var last := low.substr(n - 1, 1)
	var prev := low.substr(n - 2, 1) if n >= 2 else ""
	var stem := w.substr(0, n - 1)
	if low.ends_with("ій"):
		return w.substr(0, n - 1) + "ю"
	if low.ends_with("ий") or low.ends_with("ей") or last == "й":
		return stem + "ю"
	if last == "ь":
		return stem + "ю"
	if last == "я":
		return stem + ("є" if prev != "" and _VOWELS.contains(prev) else "ю")
	if last == "а":
		return stem + "о"
	if last == "о":
		if low.ends_with("ко"):
			return stem + "у"
		if low.ends_with("ро") or low.ends_with("ло"):
			return stem + "е"
		return w
	if last == "г":
		return stem + "же"
	if last == "ж" or last == "ч" or last == "ш" or last == "щ" or last == "ц":
		return w + "у"
	if _VOWELS.contains(last):
		return w
	if last == "к":
		return w + "у"
	return w + "е"
