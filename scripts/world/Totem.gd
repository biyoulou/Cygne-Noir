class_name Totem
extends Area3D

signal broken(index: int)

@export var index: int = 0

var is_alive: bool = true
var _visual: Node3D


func _ready() -> void:
	add_to_group("breakables")
	add_to_group("totems")
	collision_layer = 32
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_add_collision()
	_build_visual()


func _add_collision() -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 3.2
	cs.shape = shape
	cs.position = Vector3(0, 1.6, 0)
	add_child(cs)


func break_totem() -> void:
	if not is_alive:
		return
	is_alive = false
	broken.emit(index)
	MissionManager.on_totem_destroyed(index)
	AudioManager.play_sfx("totem_break", 1.0)
	VFXManager.spawn_burst_ring(global_position + Vector3.UP * 1.5, Color(0.8, 0.3, 1.0), 3.2)
	VFXManager.spawn_impact(global_position + Vector3.UP * 1.8, Color(0.8, 0.4, 1.0), 3.0)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if not is_alive:
		return
	if body is Player:
		get_tree().call_group("world", "on_totem_entered", self)


func _build_visual() -> void:
	_visual = TerrainBuilder.new().build_totem(Vector3.ZERO)
	add_child(_visual)
