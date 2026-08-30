class_name NPC
extends Area3D

@export var npc_name: String = "Mael"
@export var npc_id: String = "mael"
@export var lines: Array[String] = [
	"Kaelis… enfin. Le vent est mort.",
	"Trois totems se sont corrompus. Ils retiennent la Résonance du Vent.",
	"Détruis-les, récupère les Éclats, et prépare le moulin.",
]

var _mat: StandardMaterial3D
var _lines_index: int = 0


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactables")
	collision_layer = 32
	collision_mask = 2
	monitoring = true
	body_entered.connect(
		func(body: Node) -> void:
			if body is Player:
				get_tree().call_group("world", "on_npc_entered", self)
	)
	body_exited.connect(
		func(body: Node) -> void:
			if body is Player:
				get_tree().call_group("world", "on_npc_exited", self)
	)
	_add_collision()
	_create_visual()


func _add_collision() -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 1.8
	cs.shape = shape
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)


func get_next_line() -> String:
	if _lines_index >= lines.size():
		return ""
	var line := lines[_lines_index]
	_lines_index += 1
	return line


func reset_dialogue() -> void:
	_lines_index = 0


func _create_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.52)
	mat.roughness = 0.7
	var capsule := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.32
	body.height = 1.5
	capsule.mesh = body
	capsule.material_override = mat
	capsule.position = Vector3(0, 0.75, 0)
	add_child(capsule)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head.mesh = sphere
	head.material_override = mat
	head.position = Vector3(0, 1.65, 0)
	add_child(head)
