class_name FragmentPickup
extends Area3D

@export var index: int = 0

var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("collectibles")
	collision_layer = 32
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_add_collision()
	_create_visual()


func _add_collision() -> void:
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	cs.shape = shape
	add_child(cs)


func setup(fragment_index: int) -> void:
	index = fragment_index


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if GameState.fragments_collected[index]:
		return
	MissionManager.on_fragment_collected(index)
	AudioManager.play_sfx("pickup", 1.2)
	VFXManager.spawn_heal(global_position)
	VFXManager.spawn_spark(global_position, Color(0.4, 0.95, 1.0), 16)
	queue_free()


func _create_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.95, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.9, 1.0)
	_mat.emission_energy_multiplier = 3.0
	var mesh := MeshInstance3D.new()
	var oct := CylinderMesh.new()
	oct.top_radius = 0.16
	oct.bottom_radius = 0.16
	oct.height = 0.5
	mesh.mesh = oct
	mesh.material_override = _mat
	add_child(mesh)
