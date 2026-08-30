class_name TargetingSystem
extends Node

@export var max_lock_range: float = 26.0
@export var auto_break_range: float = 34.0
@export var max_side_angle_deg: float = 140.0

var current_target: Node3D
var lock_active: bool = false

var _player: Player
var _marker: Node3D
var _marker_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("targeting")
	add_to_group("debug")
	_player = get_parent() as Player
	_marker = _create_marker()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on"):
		_toggle_lock()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_next"):
		_cycle_target(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_prev"):
		_cycle_target(-1)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_lock(delta)
	_update_marker()


func _update_lock(_delta: float) -> void:
	if current_target and is_instance_valid(current_target):
		if (
			not current_target.is_in_group("enemies")
			or (
				current_target.global_position.distance_to(_player.global_position)
				> auto_break_range
			)
		):
			_clear_target()
	else:
		current_target = null
	if lock_active and current_target == null:
		var found := _find_best_target()
		if found:
			_set_target(found)


func _toggle_lock() -> void:
	if lock_active:
		lock_active = false
		_clear_target()
	else:
		lock_active = true
		var found := _find_best_target()
		if found:
			_set_target(found)


func _cycle_target(direction: int) -> void:
	if not lock_active:
		lock_active = true
	var candidates := _candidate_targets()
	var found: Node3D
	if candidates.is_empty():
		return
	if current_target and is_instance_valid(current_target):
		var idx := candidates.find(current_target)
		if idx < 0:
			idx = 0
		idx = posmod(idx + direction, candidates.size())
		found = candidates[idx]
	elif direction > 0:
		found = candidates[0]
	else:
		found = candidates[candidates.size() - 1]
	_set_target(found)


func _find_best_target() -> Node3D:
	var best: Node3D
	var best_score := -1.0
	var player_pos := _player.global_position
	for c in _candidate_targets():
		var to: Vector3 = c.global_position - player_pos
		var dist := to.length()
		if dist > max_lock_range:
			continue
		var dir := -_player.global_transform.basis.z
		dir.y = 0.0
		dir = dir.normalized()
		var forward: Vector3 = to
		forward.y = 0.0
		forward = forward.normalized()
		var score := 1000.0 - dist * 10.0
		if forward.length() > 0.01:
			score += dir.dot(forward) * 300.0
		if score > best_score:
			best_score = score
			best = c
	return best


func _candidate_targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node3D and n.get("is_alive") != false:
			out.append(n as Node3D)
	return out


func _set_target(target: Node3D) -> void:
	current_target = target
	lock_active = true


func _clear_target() -> void:
	current_target = null


func get_camera_target_override() -> Vector3:
	if current_target and is_instance_valid(current_target):
		var point := (
			current_target.global_position
			+ (
				Vector3.UP
				* float(
					(
						current_target.get("lock_height")
						if current_target.get("lock_height") != null
						else 1.2
					)
				)
			)
		)
		return point
	return Vector3.INF


func _create_marker() -> Node3D:
	var node := Node3D.new()
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.albedo_color = Color(0.9, 0.3, 0.35)
	_marker_mat.emission_enabled = true
	_marker_mat.emission = Color(0.9, 0.2, 0.3)
	_marker_mat.emission_energy_multiplier = 2.0
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.36
	ring.mesh = torus
	ring.material_override = _marker_mat
	ring.rotation_degrees = Vector3(90, 0, 0)
	node.add_child(ring)
	add_child(node)
	return node


func _update_marker() -> void:
	if current_target and is_instance_valid(current_target):
		_marker.visible = true
		_marker.global_position = current_target.global_position + Vector3.UP * 0.2
		_marker.rotation.y += 0.04
	else:
		_marker.visible = false
		lock_active = false


func toggle_hitbox_view() -> void:
	_marker.visible = not _marker.visible
