## Силует дерева v7 (порт Sil).
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

func _init(seed):
	self.seed = seed
	self.phase = (((seed % 997) / 997.0) * TAU)
	var ph = self.phase
	self.crx = (720 + (90 * sin(ph)))
	self.cry = (400 + (35 * cos((ph * 1.3))))
	var _tu_173 = [0.0, (1320 + (50 * sin((ph * 0.7))))]
	self.cx = _tu_173[0]
	self.cy = _tu_173[1]
	self.trunk_top = (self.cy - (self.cry * 0.92))
	self.trunk_bot = (430 + (30 * sin((ph * 1.2))))
	self.th_top = (150 + (18 * sin((ph * 1.1))))
	self.th_bot = (168 + (18 * cos((ph * 0.9))))
	self.root_y0 = (70 + (20 * cos((ph * 0.5))))
	var spread = (1.0 + (0.14 * sin((ph * 0.55))))
	self.fans = [[((-290) * spread), 250, (270 * spread), 240, "str"], [0.0, 200, (230 * spread), 230, "agi"], [(290 * spread), 250, (270 * spread), 240, "faith"]]
	self.collar_hw = (260 * spread)
	self.collar_y0 = (self.trunk_bot - 40)
	self.collar_y1 = 340

func crown_r(ang):
	var _tu_194 = [self.crx, self.cry]
	var a = _tu_194[0]
	var b = _tu_194[1]
	var den = sqrt((pow((b * cos(ang)), 2) + pow((a * sin(ang)), 2)))
	var r = (((a * b) / den) if (den > 1e-09) else a)
	r *= ((1.0 + (0.09 * sin(((3 * ang) + self.phase)))) + (0.05 * sin(((5 * ang) + (self.phase * 1.7)))))
	return r

func in_crown(x, y, margin = 1.0):
	var _tu_201 = [(x - self.cx), (y - self.cy)]
	var dx = _tu_201[0]
	var dy = _tu_201[1]
	var ang = atan2(dy, dx)
	var r = sqrt((dx)*(dx)+(dy)*(dy))
	return (r <= (self.crown_r(ang) * margin))

func trunk_hw(y):
	if (self.trunk_bot == self.trunk_top):
		return self.th_bot
	var t = ((y - self.trunk_top) / (self.trunk_bot - self.trunk_top))
	t = max(0.0, min(1.0, t))
	var wave = (8 * sin((((t * PI) * 3) + self.phase)))
	return ((((1 - t) * self.th_top) + (t * self.th_bot)) + wave)

func in_trunk(x, y, margin = 1.0):
	if ((y > (self.trunk_top + 30)) or (y < (self.trunk_bot - 40))):
		return false
	return (abs(x) <= (self.trunk_hw(y) * margin))

func in_roots(x, y, margin = 1.0):
	if ((self.trunk_bot + 50) >= y) and (y >= (min(self.collar_y1, self.trunk_bot) - 80)):
		var t = ((self.trunk_bot - y) / 160.0)
		t = max(0.0, min(1.0, t))
		var hw = (self.th_bot + ((self.collar_hw - self.th_bot) * t))
		if (abs(x) <= (hw * margin)):
			return true
	for _it in self.fans:
		var cx = _it[0]
		var cy = _it[1]
		var rx = _it[2]
		var ry = _it[3]
		var _ = _it[4]
		if ((pow(((x - cx) / (rx * margin)), 2) + pow(((y - cy) / (ry * margin)), 2)) <= 1.0):
			return true
	return false

func inside(x, y, margin = 1.0):
	return (self.in_crown(x, y, margin) or self.in_trunk(x, y, margin) or self.in_roots(x, y, margin))

func zone(x, y):
	if (self.in_crown(x, y, 1.04) and (y >= (self.trunk_top - 50))):
		return "crown"
	if (self.in_roots(x, y, 1.04) and (y <= (self.trunk_bot + 50))):
		return "roots"
	if self.in_trunk(x, y, 1.08):
		return "trunk"
	if self.in_crown(x, y, 1.06):
		return "crown"
	return "roots"

func region(x, y):
	"Return (region, is_junction). Junctions are mixed corridors."
	var z = self.zone(x, y)
	if (z == "roots"):
		var d = []
		for _it in self.fans:
			var cx = _it[0]
			var cy = _it[1]
			var rx = _it[2]
			var ry = _it[3]
			var rg = _it[4]
			var e = sqrt((((x - cx) / rx))*(((x - cx) / rx))+(((y - cy) / ry))*(((y - cy) / ry)))
			d.append([e, rg])
		d.sort()
		if ((d[1][0] < 1.05) and (abs((d[0][0] - d[1][0])) < 0.28)):
			return [d[0][1], true]
		return [d[0][1], false]
	if (z == "crown"):
		var dy = (y - self.cy)
		if ((self.cry > 1) and (abs(dy) < self.cry)):
			var hw = (self.crx * sqrt(max(0.05, (1.0 - pow((dy / self.cry), 2)))))
		else:
			hw = max(80.0, (abs(x) + 30))
		var wave = (18 * sin(((y / 200.0) + self.phase)))
		var b1 = (((-0.4) * hw) + wave)
		var b2 = ((0.4 * hw) + (wave * 0.6))
		var band = (0.08 * hw)
		if (x < (b1 - band)):
			return ["str", false]
		if (x > (b2 + band)):
			return ["faith", false]
		if (abs((x - b1)) <= band):
			return ["str", true]
		if (abs((x - b2)) <= band):
			return ["faith", true]
		return ["agi", false]
	hw = self.trunk_hw(y)
	wave = (10 * sin(((y / 90.0) + self.phase)))
	b1 = (((-0.36) * hw) + wave)
	b2 = ((0.36 * hw) + (wave * 0.6))
	band = (0.1 * hw)
	if (x < (b1 - band)):
		return ["str", false]
	if (x > (b2 + band)):
		return ["faith", false]
	if (abs((x - b1)) <= band):
		return ["str", true]
	if (abs((x - b2)) <= band):
		return ["faith", true]
	return ["agi", false]

func bbox():
	var xs = [(self.crx + 20)]
	for _it in self.fans:
		var cx = _it[0]
		var _cy = _it[1]
		var rx = _it[2]
		var _ry = _it[3]
		var _ = _it[4]
		xs.append((abs(cx) + rx))
	var W = (max(xs) + 40)
	return [(-W), W, (self.root_y0 - 40), ((self.cy + self.cry) + 40)]

func outline(n = 240):
	"Sample boundary points for preview (not exact)."
	var pts = []
	for i in range(n):
		var ang = ((i * TAU) / n)
		var r = self.crown_r(ang)
		var _tu_309 = [(self.cx + (r * cos(ang))), (self.cy + (r * sin(ang)))]
		var x = _tu_309[0]
		var y = _tu_309[1]
		pts.append([x, y, "crown"])
	return pts
