## Силует дерева v7 (коріння / стовбур / крона).
class_name SilhouetteV7
extends RefCounted

var seed: int
var phase: float
var crx: float
var cry: float
var cx: float
var cy: float
var trunk_top: float
var trunk_bot: float
var th_top: float
var th_bot: float
var root_y0: float
var fans: Array
var collar_hw: float
var collar_y0: float
var collar_y1: float


func _init(p_seed: int = 0) -> void:
	seed = p_seed
	phase = ((p_seed % 997) / 997.0) * TAU
	var ph := phase
	crx = 720.0 + 90.0 * sin(ph)
	cry = 400.0 + 35.0 * cos(ph * 1.3)
	cx = 0.0
	cy = 1320.0 + 50.0 * sin(ph * 0.7)
	trunk_top = cy - cry * 0.92
	trunk_bot = 430.0 + 30.0 * sin(ph * 1.2)
	th_top = 150.0 + 18.0 * sin(ph * 1.1)
	th_bot = 168.0 + 18.0 * cos(ph * 0.9)
	root_y0 = 70.0 + 20.0 * cos(ph * 0.5)
	var spread := 1.0 + 0.14 * sin(ph * 0.55)
	fans = [
		[-290.0 * spread, 250.0, 270.0 * spread, 240.0, "str"],
		[0.0, 200.0, 230.0 * spread, 230.0, "agi"],
		[290.0 * spread, 250.0, 270.0 * spread, 240.0, "faith"],
	]
	collar_hw = 260.0 * spread
	collar_y0 = trunk_bot - 40.0
	collar_y1 = 340.0


func crown_r(ang: float) -> float:
	var a := crx
	var b := cry
	var den := sqrt(pow(b * cos(ang), 2.0) + pow(a * sin(ang), 2.0))
	var r: float = (a * b / den) if den > 1e-9 else a
	r *= 1.0 + 0.09 * sin(3.0 * ang + phase) + 0.05 * sin(5.0 * ang + phase * 1.7)
	return r


func in_crown(x: float, y: float, margin: float = 1.0) -> bool:
	var dx := x - cx
	var dy := y - cy
	var ang := atan2(dy, dx)
	var r := sqrt(dx * dx + dy * dy)
	return r <= crown_r(ang) * margin


func trunk_hw(y: float) -> float:
	if is_equal_approx(trunk_bot, trunk_top):
		return th_bot
	var t := clampf((y - trunk_top) / (trunk_bot - trunk_top), 0.0, 1.0)
	var wave := 8.0 * sin(t * PI * 3.0 + phase)
	return (1.0 - t) * th_top + t * th_bot + wave


func in_trunk(x: float, y: float, margin: float = 1.0) -> bool:
	if y > trunk_top + 30.0 or y < trunk_bot - 40.0:
		return false
	return abs(x) <= trunk_hw(y) * margin


func in_roots(x: float, y: float, margin: float = 1.0) -> bool:
	if trunk_bot + 50.0 >= y and y >= minf(collar_y1, trunk_bot) - 80.0:
		var t := clampf((trunk_bot - y) / 160.0, 0.0, 1.0)
		var hw := th_bot + (collar_hw - th_bot) * t
		if abs(x) <= hw * margin:
			return true
	for f in fans:
		var fcx: float = f[0]
		var fcy: float = f[1]
		var frx: float = f[2]
		var fry: float = f[3]
		if pow((x - fcx) / (frx * margin), 2.0) + pow((y - fcy) / (fry * margin), 2.0) <= 1.0:
			return true
	return false


func inside(x: float, y: float, margin: float = 1.0) -> bool:
	return in_crown(x, y, margin) or in_trunk(x, y, margin) or in_roots(x, y, margin)


func zone(x: float, y: float) -> String:
	if in_crown(x, y, 1.04) and y >= trunk_top - 50.0:
		return "crown"
	if in_roots(x, y, 1.04) and y <= trunk_bot + 50.0:
		return "roots"
	if in_trunk(x, y, 1.08):
		return "trunk"
	if in_crown(x, y, 1.06):
		return "crown"
	return "roots"


func region(x: float, y: float) -> Array:
	var z := zone(x, y)
	if z == "roots":
		var d: Array = []
		for f in fans:
			var fcx: float = f[0]
			var fcy: float = f[1]
			var frx: float = f[2]
			var fry: float = f[3]
			var rg: String = f[4]
			var e := sqrt(pow((x - fcx) / frx, 2.0) + pow((y - fcy) / fry, 2.0))
			d.append([e, rg])
		d.sort_custom(func(a, b): return a[0] < b[0])
		if d.size() >= 2 and d[1][0] < 1.05 and abs(d[0][0] - d[1][0]) < 0.28:
			return [d[0][1], true]
		return [d[0][1], false]
	var hw: float
	var wave: float
	var b1: float
	var b2: float
	var band: float
	if z == "crown":
		var dy := y - cy
		if cry > 1.0 and abs(dy) < cry:
			hw = crx * sqrt(maxf(0.05, 1.0 - pow(dy / cry, 2.0)))
		else:
			hw = maxf(80.0, abs(x) + 30.0)
		wave = 18.0 * sin(y / 200.0 + phase)
		b1 = -0.4 * hw + wave
		b2 = 0.4 * hw + wave * 0.6
		band = 0.08 * hw
	else:
		hw = trunk_hw(y)
		wave = 10.0 * sin(y / 90.0 + phase)
		b1 = -0.36 * hw + wave
		b2 = 0.36 * hw + wave * 0.6
		band = 0.1 * hw
	if x < b1 - band:
		return ["str", false]
	if x > b2 + band:
		return ["faith", false]
	if abs(x - b1) <= band:
		return ["str", true]
	if abs(x - b2) <= band:
		return ["faith", true]
	return ["agi", false]


func bbox() -> Array:
	var W := crx + 40.0
	for f in fans:
		W = maxf(W, abs(float(f[0])) + float(f[2]) + 40.0)
	return [-W, W, root_y0 - 40.0, cy + cry + 40.0]
