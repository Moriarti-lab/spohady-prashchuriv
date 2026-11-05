## Тепла народна палітра гри (з дизайн-документа).
class_name Palette

# Русь: тепла й казкова
const EMBROIDERY := Color("B3261E")  # Вишивка
const LINEN := Color("F2EBDD")       # Льон
const GOLD := Color("E0A526")        # Золото
const TURQUOISE := Color("1F8F8B")   # Бірюза
const LEAF := Color("4C8C3A")        # Листя
const NIGHT := Color("1E1A1A")       # Ніч

# Вороги: холодні й моторошні
const ASH := Color("6B7480")         # Попіл
const STEEL := Color("2F3E52")       # Сталь
const GLOOM := Color("5F7A6C")       # Морок
const BLOOD := Color("6E1B1B")       # Кров
const DARKNESS := Color("0E0F12")    # Тьма

# Службові
const PANEL := Color("2A2222")
const PANEL_LIGHT := Color("3A2E2C")
const TEXT_DIM := Color("B9AE9A")
const HP_COLOR := Color("C7352B")
const MANA_COLOR := Color("2AA8A2")
const XP_COLOR := Color("E0A526")

const STAT_COLORS := {
	"str": Color("D8574B"),
	"agi": Color("7CBF5A"),
	"faith": Color("E0A526"),
}

## Кольори для BBCode в описах (t60).
const LIFE := Color("8B1E2D")       # кармін — життя
const CHARM := Color("5EC8FF")      # небесний — чар
const ARMOR_C := Color("9AA3AD")    # сталево-сірий
const DMG_C := Color("E08A4B")      # помаранчевий
const CRIT_C := Color("F5E6A3")     # жовто-білий
const SPEED_C := Color("1F8F8B")    # бірюзовий
const RESIST_C := Color("9B6BC7")   # фіолетовий
const PEN_C := Color("C73A9B")      # пурпурний/magenta
const GOLD_C := Color("E8C84A")     # гривні
const XP_C := Color("A8D84A")       # досвід/звитяга

const STAT_BB := {
	"str": "D8574B", "agi": "7CBF5A", "faith": "E0A526",
	"hp": "8B1E2D", "hp_pct": "8B1E2D", "life_on_kill": "8B1E2D", "lifesteal_pct": "8B1E2D", "hp_regen_pct": "8B1E2D",
	"mana_pct": "5EC8FF", "mana_regen": "5EC8FF", "mana_regen_pct": "5EC8FF", "mana_on_kill": "5EC8FF",
	"armor": "9AA3AD", "dr_pct": "9AA3AD", "block_pct": "9AA3AD", "block_power_pct": "9AA3AD",
	"dmg_pct": "E08A4B", "thorns_pct": "E08A4B",
	"crit_pct": "F5E6A3", "crit_dmg_pct": "F5E6A3",
	"atk_speed_pct": "1F8F8B", "move_pct": "1F8F8B", "cdr_pct": "1F8F8B", "proj_speed_pct": "1F8F8B",
	"res_all_pct": "9B6BC7", "res_fire_pct": "9B6BC7", "res_frost_pct": "9B6BC7", "res_thunder_pct": "9B6BC7",
	"res_nature_pct": "9B6BC7", "res_light_pct": "9B6BC7", "res_fate_pct": "9B6BC7",
	"pen_all_pct": "C73A9B", "pen_fire_pct": "C73A9B", "pen_frost_pct": "C73A9B", "pen_thunder_pct": "C73A9B",
	"pen_nature_pct": "C73A9B", "pen_light_pct": "C73A9B", "pen_fate_pct": "C73A9B", "armor_pen_pct": "C73A9B",
	"gold_pct": "E8C84A", "drop_pct": "E8C84A",
	"xp_pct": "A8D84A", "nauz_xp_pct": "A8D84A",
}
