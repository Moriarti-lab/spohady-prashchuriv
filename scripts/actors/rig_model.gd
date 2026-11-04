## Анімована модель KayKit (CC0, Kay Lousberg): герої, селяни, кістяки.
## Обгортка дивиться в бік −Z, як і решта моделей гри. Зброю чіпляємо до кістки handslot_r / handslot_l.
class_name RigModel
extends Node3D

const LOOPS := ["Idle", "Idle_Combat", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_D_Skeletons", "2H_Melee_Idle", "Unarmed_Idle", "Spellcasting", "Sit_Floor_Idle", "Lie_Idle"]
static var _scenes := {}

var anim: AnimationPlayer
var skeleton: Skeleton3D
var right_hand: Node3D
var left_hand: Node3D
var idle_anim := "Idle"
var run_anim := "Running_A"
var walk_anim := "Walking_A"
var _busy := 0.0
var _dead := false


static func create(file: String, height_scale: float = 0.8, keep_props: Array = []) -> RigModel:
	var path := "res://models/kaykit/%s.glb" % file
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	if _scenes[path] == null:
		return null
	var r := RigModel.new()
	r.name = "Model"
	var inst: Node3D = (_scenes[path] as PackedScene).instantiate()
	inst.rotation.y = PI
	inst.scale = Vector3.ONE * height_scale
	r.add_child(inst)
	r.anim = inst.find_child("AnimationPlayer", true, false)
	r.skeleton = inst.find_child("Skeleton3D", true, false)
	for ba in inst.find_children("*", "BoneAttachment3D", true, false):
		if true:
			var nm := str(ba.name)
			if nm.begins_with("handslot"):
				for m in ba.get_children():
					if m is MeshInstance3D and not keep_props.has(str(m.name)):
						m.visible = false
				var pivot := Node3D.new()
				pivot.name = "Grip"
				ba.add_child(pivot)
				if nm == "handslot_r":
					r.right_hand = pivot
				else:
					r.left_hand = pivot
	for side in ["right_hand", "left_hand"]:
		if r.get(side) == null:
			var g := Node3D.new()
			g.name = "Grip"
			g.position = Vector3(0.35 if side == "right_hand" else -0.35, 0.9, 0)
			r.add_child(g)
			r.set(side, g)
	if r.anim != null:
		for n in LOOPS:
			if r.anim.has_animation(n):
				r.anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		r.anim.playback_default_blend_time = 0.15
	return r


## Ховає меші-аксесуари (капелюх, плащ…) за частиною імені.
func hide_parts(names: Array) -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		for n in names:
			if str(m.name).contains(n):
				m.visible = false


func show_prop(prop_name: String) -> void:
	var m := find_child(prop_name, true, false)
	if m != null:
		m.visible = true


func _ready() -> void:
	if anim != null and anim.has_animation(idle_anim):
		anim.play(idle_anim)


func _process(delta: float) -> void:
	if _busy > 0.0:
		_busy -= delta


## speed — 0..1 від максимальної швидкості.
func set_move(speed: float) -> void:
	if anim == null or _dead or _busy > 0.0:
		return
	var want := idle_anim
	if speed > 0.55:
		want = run_anim
	elif speed > 0.08:
		want = walk_anim
	if anim.current_animation != want and anim.has_animation(want):
		anim.play(want)
	if want == run_anim:
		anim.speed_scale = clampf(speed * 1.1, 0.8, 1.4)
	else:
		anim.speed_scale = 1.0


func play_once(n: String, speed: float = 1.3) -> void:
	if anim == null or _dead or not anim.has_animation(n):
		return
	anim.play(n, 0.08, speed)
	anim.seek(0.0, true)
	_busy = anim.get_animation(n).length / speed * 0.85


func attack(kind: String, two_handed: bool = false) -> void:
	match kind:
		"melee":
			play_once("2H_Melee_Attack_Slice" if two_handed else ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal"][randi() % 3], 1.8)
		"arrow":
			play_once("2H_Ranged_Shoot" if two_handed else "1H_Ranged_Shoot", 1.6)
		"cast":
			play_once("Spellcast_Raise", 1.6)
		_:
			play_once("Spellcast_Shoot", 1.7)


func hit() -> void:
	if _busy <= 0.0:
		play_once("Hit_A", 1.6)


func die() -> void:
	if anim == null:
		return
	_dead = true
	anim.speed_scale = 1.0
	anim.play("Death_A", 0.1)


func revive() -> void:
	_dead = false
	_busy = 0.0
	if anim != null:
		anim.play(idle_anim)
