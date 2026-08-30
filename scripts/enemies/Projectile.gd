class_name Projectile
extends Area3D

@export var speed: float = 13.0
@export var damage: int = 8
@export var life: float = 3.0

var direction: Vector3 = Vector3.FORWARD
var from_corrupted: bool = false


func _ready() -> void:
	add_to_group("enemy_projectile")
	collision_layer = 16
	collision_mask = 2 | 1
	monitoring = true
	monitorable = false
	_create_visual()


func setup(dir: Vector3, dmg: int, kind: String) -> void:
	direction = dir.normalized()
	damage = dmg
	from_corrupted = kind == "corrupted"


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.apply_damage(damage, global_position, {"knockback": 5.0})
		VFXManager.spawn_spark(
			global_position,
			Color(1.0, 0.45, 0.3) if not from_corrupted else Color(0.6, 0.2, 1.0),
			10
		)
	elif body.has_method("apply_damage"):
		body.apply_damage(damage, global_position, {"knockback": 4.0})
	queue_free()


func _create_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.25) if not from_corrupted else Color(0.6, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 3.0
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	mesh.mesh = sphere
	mesh.material_override = mat
	add_child(mesh)
