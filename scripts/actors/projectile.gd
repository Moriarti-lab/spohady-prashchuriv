## Снаряд: стріла, магічна куля героя або холодна куля привида.
class_name Projectile
extends Node3D

var velocity := Vector3.ZERO
var damage := 1.0
var team := "player"            # "player" б'є ворогів, "enemy" б'є героя
var radius := 0.45
var life := 2.0
var hit_callback := Callable()  # викликається з ціллю при влучанні
var spark_color := Color.WHITE
var _dead := false


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		_finish(false)
		return
	var from_node := global_position
	if team == "player":
		for e in get_tree().get_nodes_in_group("enemies"):
			var en: Enemy = e
			if en.dead:
				continue
			var d := Vector2(en.global_position.x - from_node.x, en.global_position.z - from_node.z).length()
			if d < radius + en.body_radius:
				_hit(en)
				return
	else:
		for p in get_tree().get_nodes_in_group("player"):
			var pl: Player = p
			if pl.dead:
				continue
			var d2 := Vector2(pl.global_position.x - from_node.x, pl.global_position.z - from_node.z).length()
			if d2 < radius + pl.body_radius:
				_hit(pl)
				return


func _hit(target: Node) -> void:
	if hit_callback.is_valid():
		hit_callback.call(target)
	_finish(true)


func _finish(hit: bool) -> void:
	_dead = true
	if hit:
		Fx.sparks(get_parent(), global_position, spark_color, 8)
	queue_free()
