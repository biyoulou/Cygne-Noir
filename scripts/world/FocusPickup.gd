class_name FocusPickup
extends Area3D

@export var energy_value: int = 6

var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 32
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_add_collision()
	_create_visual()


func _add_collision() -> void:
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	cs.shape = shape
	add_child(cs)


func setup_color(color: Color) -> void:
	if _mat:
		_mat.albedo_color = color
		_mat.emission = color


func _physics_process(delta: float) -> void:
	rotation.y += delta * 2.5
	var t := _pickup_scale()
	scale = Vector3.ONE * t


func _pickup_scale() -> float:
	return 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.12


func _on_body_entered(body: Node) -> void:
	if body is Player:
		GameState.set_energy(minf(GameState.energy + energy_value, GameState.max_energy))
		var p := body as Player
		p.energy = GameState.energy
		AudioManager.play_sfx("pickup", 1.0)
		VFXManager.spawn_heal(global_position)
		queue_free()


func _create_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.95, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.9, 1.0)
	_mat.emission_energy_multiplier = 2.5
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	mesh.mesh = sphere
	mesh.material_override = _mat
	add_child(mesh)
