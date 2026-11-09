extends SceneTree
## ≥10 seeds must pass GDScript v7 validators (crossings/orphans/mindist/own/desc/unwired).

const SEEDS := [1, 7, 42, 99, 123, 777, 2024, 555, 88, 99991, 314159, 2026]

func _init() -> void:
	var scr = load("res://scripts/editor/gen/tree_gen_v7_core.gd")
	if scr == null:
		print("FAIL load core")
		quit(1)
		return
	var pass_n := 0
	var fail_n := 0
	for s in SEEDS:
		var g = scr.new()
		var err: String = str(g.build(int(s), Callable()))
		var m: Dictionary = g.metrics()
		var ok: bool = (err == "" or err == "null") and g.validators_ok(m)
		print("SEED ", s, " ok=", ok, " N=", m.get("N"), " cross=", m.get("crossings"),
			" orphan=", m.get("orphans"), " mind=", "%.1f" % float(m.get("min_node_dist", 0.0)),
			" own=", m.get("own"))
		if ok:
			pass_n += 1
		else:
			fail_n += 1
	print("GEN_SEEDS pass=", pass_n, " fail=", fail_n, " total=", SEEDS.size())
	if fail_n == 0 and pass_n >= 10:
		print("TREE_GEN_V7_OK")
		quit(0)
	else:
		print("TREE_GEN_V7_FAILED")
		quit(1)
