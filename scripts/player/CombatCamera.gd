class_name CombatCamera
extends Camera3D

@export var default_distance: float = 6.5
@export var default_height: float = 1.8
@export var default_pitch_deg: float = 32.0
@export var look_height: float = 1.25

var yaw: float = 0.0
var pitch_deg: float = 32.0
var distance: float = 6.5
var sensitivity: float = 1.0
var _targeting: TargetingSystem
var _shake_intensity: float = 0.0


func _ready() -> void:
	add_to_group("camera")
	add_to_group("debug")
	current = true
	distance = GameState.settings["camera_distance"]
	sensitivity = GameState.settings["camera_sensitivity"]
	pitch_deg = default_pitch_deg


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.004 * sensitivity
		pitch_deg = clampf(pitch_deg - event.relative.y * 0.0035 * sensitivity, -25.0, 75.0)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.4, 3.5, 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.4, 3.5, 12.0)


func _process(delta: float) -> void:
	if _targeting == null:
		_targeting = _find_targeting()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	var target_point: Vector3
	if _targeting and _targeting.current_target and is_instance_valid(_targeting.current_target):
		var target: Node3D = _targeting.current_target
		var midpoint := (player.global_position + target.global_position) * 0.5
		midpoint.y = lerpf(
			player.global_position.y + look_height, target.global_position.y + 1.2, 0.6
		)
		var dir_to_target := player.global_position - target.global_position
		dir_to_target.y = 0.0
		if dir_to_target.length() > 0.01:
			var desired_yaw := atan2(dir_to_target.x, dir_to_target.z)
			yaw = lerp_angle(yaw, desired_yaw, 0.12)
		target_point = midpoint
		pitch_deg = lerpf(pitch_deg, 24.0, 0.08)
	else:
		target_point = player.global_position + Vector3.UP * look_height

	var offset := _orbit_offset()
	var cam_pos := target_point + offset
	var look_target := target_point

	global_position = cam_pos
	look_at(look_target, Vector3.UP)

	if _shake_intensity > 0.0:
		_shake_intensity = maxf(0.0, _shake_intensity - delta * 2.0)
		global_position += (
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			* _shake_intensity
			* 0.08
		)
		rotation.z += randf_range(-1, 1) * _shake_intensity * 0.008


func _orbit_offset() -> Vector3:
	var pitch := deg_to_rad(pitch_deg)
	var horizontal := distance * cos(pitch)
	var up := distance * sin(pitch)
	return Vector3(sin(yaw) * horizontal, up + default_height * 0.18, cos(yaw) * horizontal)


func _find_targeting() -> TargetingSystem:
	return get_tree().get_first_node_in_group("targeting") as TargetingSystem


func shake(amount: float) -> void:
	_shake_intensity = maxf(_shake_intensity, amount)


func toggle_hitbox_view() -> void:
	pass
