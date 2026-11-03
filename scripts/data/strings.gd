## Усі основні тексти інтерфейсу (лише українська, зі словами старої Русі).
class_name Strings

const GAME_TITLE := "Спогади пращурів"
const VERSION := "Пробна версія 0.1.0"

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
