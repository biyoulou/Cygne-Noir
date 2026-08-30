class_name BossHazard
extends Node3D

@export var radius: float = 2.5
@export var damage: int = 14
@export var delay: float = 1.1
@export var life: float = 0.6
@export var color: Color = Color(0.8, 0.3, 1.0)

var _elapsed: float = 0.0
var _triggered: bool = false
var _node_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	add_to_group("debug")
	_create_visual()


func setup(radius_value: float, damage_value: int, delay_value: float, color_value: Color) -> void:
	radius = radius_value
	damage = damage_value
	delay = delay_value
	color = color_value


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / maxf(0.01, delay), 0.0, 1.0)
	_node_scale = Vector3(radius * 0.2 + radius * t, radius * 0.05, radius * 0.2 + radius * t)
	scale = _node_scale

	if _elapsed > delay * 1.6:
		queue_free()
		return
	if not _triggered and _elapsed >= delay:
		_triggered = true
		_trigger_damage()


func _trigger_damage() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D:
		var flat := (player as Node3D).global_position - global_position
		flat.y = 0.0
		if flat.length() <= radius:
			(player as Node3D).apply_damage(damage, global_position, {"knockback": 6.0})
	VFXManager.spawn_burst_ring(global_position + Vector3.UP * 0.1, color, radius)
	AudioManager.play_sfx("hit_heavy", 0.8)


func _create_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	mesh.mesh = disc
	mesh.material_override = mat
	add_child(mesh)

	var inner := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.82
	ring.outer_radius = 0.9
	inner.mesh = ring
	inner.material_override = mat
	inner.rotation_degrees = Vector3(90, 0, 0)
	add_child(inner)

	var point := OmniLight3D.new()
	point.light_color = color
	point.light_energy = 2.0
	point.omni_range = radius * 1.5
	add_child(point)
