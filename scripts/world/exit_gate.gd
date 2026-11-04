## Брама в скелях: прохід до іншої локації (поки зачинений). Двері відчинені (прохід вільний). Тригер у GameWorld.
class_name ExitGate
extends Node3D

const WOOD_DARK := Color("4A3322")
const WOOD := Color("6B4A2E")


var label_text := "Стежка"


func _ready() -> void:
	var parts: Array = []
	# стовпи
	for sx in [-1.0, 1.0]:
		parts.append(LowPoly.box(Vector3(0.6, 4.4, 0.6), Vector3(sx * 2.7, 2.2, 0), WOOD_DARK))
		parts.append(LowPoly.cyl(0.42, 0.42, 0.25, Vector3(sx * 2.7, 4.5, 0), Palette.GOLD, 6))
		parts.append(LowPoly.box(Vector3(0.85, 0.35, 0.85), Vector3(sx * 2.7, 0.18, 0), Color("77767C")))
	# верхня балка з вишивкою
	parts.append(LowPoly.box(Vector3(6.4, 0.5, 0.55), Vector3(0, 4.1, 0), WOOD))
	parts.append(LowPoly.box(Vector3(5.4, 0.22, 0.6), Vector3(0, 3.7, 0), Palette.EMBROIDERY))
	for i in range(7):
		parts.append(LowPoly.box(Vector3(0.18, 0.18, 0.64), Vector3(-2.4 + i * 0.8, 3.7, 0), Palette.GOLD, Vector3(0, 0, 45)))
	# розчинені стулки: повернуті до стовпів
	for sx in [-1.0, 1.0]:
		parts.append(LowPoly.box(Vector3(0.2, 3.3, 2.2), Vector3(sx * 2.95, 1.8, 1.2), WOOD, Vector3(0, sx * 20.0, 0)))
		parts.append(LowPoly.box(Vector3(0.26, 0.12, 2.2), Vector3(sx * 2.95, 1.0, 1.2), Color("3A3A40"), Vector3(0, sx * 20.0, 0)))
		parts.append(LowPoly.box(Vector3(0.26, 0.12, 2.2), Vector3(sx * 2.95, 2.7, 1.2), Color("3A3A40"), Vector3(0, sx * 20.0, 0)))
	add_child(LowPoly.instance(parts))
	var l := Label3D.new()
	l.text = label_text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 36
	l.pixel_size = 0.011
	l.outline_size = 10
	l.modulate = Palette.LINEN
	l.outline_modulate = Palette.NIGHT
	l.position = Vector3(0, 5.5, 0)
	add_child(l)
