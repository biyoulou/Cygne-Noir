class_name MissionZone
extends Area3D

@export var zone_id: String = ""
@export var zone_title: String = ""
@export var zone_subtitle: String = ""
@export var zone_kind: String = "explore"
@export var export_radius: float = 4.0

var enabled: bool = true


func _ready() -> void:
	add_to_group("mission_zone")
	collision_layer = 32
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_add_shape()


func _add_shape() -> void:
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = export_radius
	cs.shape = shape
	add_child(cs)


func setup(id: String, title: String, kind: String, subtitle: String = "") -> void:
	zone_id = id
	zone_title = title
	zone_kind = kind
	zone_subtitle = subtitle


func set_enabled(enabled_value: bool) -> void:
	enabled = enabled_value
	monitoring = enabled_value


func _on_body_entered(body: Node) -> void:
	if not enabled:
		return
	if body is Player:
		get_tree().call_group("world", "on_zone_entered", self)
