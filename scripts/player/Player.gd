class_name Player
extends CharacterBody3D

signal died
signal respawned
signal stats_changed

enum State { MOVE, DODGE, ATTACK, GUARD, HURT, DEAD }

@export var max_hp: int = 120
@export var walk_speed: float = 5.2
@export var sprint_speed: float = 9.0
@export var acceleration: float = 14.0
@export var deceleration: float = 20.0
@export var jump_velocity: float = 7.5
@export var gravity_multiplier: float = 1.9
@export var dodge_speed: float = 13.0
@export var dodge_time: float = 0.34
@export var dodge_cost: float = 22.0
@export var stamina_regen: float = 24.0
@export var energy_regen: float = 4.0
@export var sprint_multiplier: float = 1.0

var hp: int = 120
var stamina: float = 100.0
var energy: float = 40.0
var burst_charge: float = 0.0

var state: int = State.MOVE
var movement_input: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO
var ground_yaw: float = 0.0
var is_on_ground := true
var dodge_timer: float = 0.0
var dodge_vector: Vector3 = Vector3.ZERO
var i_frames: float = 0.0
var guard_held := false
var guard_perfect_window: float = 0.18
var guard_cooldown: float = 0.0
var hurt_timer: float = 0.0
var dead := false
var _spawn_point: Vector3
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

@onready var targeting: TargetingSystem = $TargetingSystem
@onready var combat: CombatController = $CombatController
@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("player")
	add_to_group("debug")
	_spawn_point = global_position
	hp = max_hp
	stamina = GameState.max_stamina
	energy = GameState.energy
	burst_charge = GameState.player_burst
	GameState.player_hp = hp
	GameState.player_stamina = stamina
	GameState.player_energy = energy
	push_state()
	_configure_visual()


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event.is_action_pressed("attack_light"):
		combat.try_attack("light")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack_heavy"):
		combat.try_attack("heavy")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill"):
		combat.try_skill()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("burst"):
		combat.try_burst()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("guard"):
		guard_held = true
		_enter_guard()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dodge"):
		try_dodge()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if dead:
		return
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
	guard_perfect_window = maxf(0.0, guard_perfect_window - delta)
	i_frames = maxf(0.0, i_frames - delta)

	_update_state(delta)

	if state == State.DODGE:
		_process_dodge(delta)
	elif state == State.ATTACK:
		_process_attack(delta)
	elif state == State.HURT:
		_process_hurt(delta)
	elif state == State.GUARD:
		_process_guard(delta)
	elif state == State.MOVE:
		_process_move(delta)

	GameState.player_position = global_position
	GameState.player_facing_yaw = rotation.y
	if state != State.DODGE and is_on_ground():
		var regen := stamina_regen * delta
		stamina = minf(stamina + regen, GameState.max_stamina)
		energy = minf(energy + energy_regen * delta, GameState.max_energy)
		GameState.set_stamina(stamina)
		GameState.set_energy(energy)
		stats_changed.emit()


func _process_move(delta: float) -> void:
	movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint") and movement_input != Vector2.ZERO
	move_direction = _camera_relative_direction(movement_input)
	var target_speed := sprint_speed if sprinting else walk_speed
	var target_vel := move_direction * target_speed * sprint_multiplier

	var accel := acceleration if movement_input != Vector2.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	if Input.is_action_just_pressed("jump") and is_on_ground():
		velocity.y = jump_velocity
		AudioManager.play_sfx("jump", 1.0)

	if not is_on_ground():
		velocity.y -= gravity_multiplier * 9.8 * delta
	else:
		velocity.y = clampf(velocity.y, -2.0, 2.0)

	_update_visual_heading()
	move_and_slide()


func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	var t := clampf(dodge_timer / dodge_time, 0.0, 1.0)
	var damp := lerpf(3.5, 1.0, 1.0 - t)
	velocity = dodge_vector * damp
	velocity.y = 0.0
	move_and_slide()
	if dodge_timer <= 0.0:
		_enter_state(State.MOVE)


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if not is_on_ground():
		velocity.y -= gravity_multiplier * 9.8 * delta
	move_and_slide()


func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	if not is_on_ground():
		velocity.y -= gravity_multiplier * 9.8 * delta
	move_and_slide()
	if hurt_timer <= 0.0:
		_enter_state(State.MOVE)


func _process_guard(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	if not is_on_ground():
		velocity.y -= gravity_multiplier * 9.8 * delta
	if not Input.is_action_pressed("guard"):
		guard_held = false
		_enter_state(State.MOVE)
		return
	_face_target_or_input()
	move_and_slide()


func _enter_guard() -> void:
	if state == State.ATTACK or state == State.DODGE or state == State.HURT or state == State.DEAD:
		return
	guard_held = true
	guard_perfect_window = 0.18
	_enter_state(State.GUARD)
	AudioManager.play_sfx("guard", 0.9)


func try_dodge() -> void:
	if state == State.ATTACK or state == State.DODGE or state == State.HURT or state == State.DEAD:
		return
	if stamina < dodge_cost:
		return
	stamina -= dodge_cost
	GameState.set_stamina(stamina)
	var dir := _dodge_direction()
	dodge_vector = dir.normalized() * dodge_speed
	dodge_timer = dodge_time
	i_frames = dodge_time + 0.10
	guard_held = false
	_enter_state(State.DODGE)
	AudioManager.play_sfx("dash", 0.9)
	VFXManager.spawn_dash_trail(global_position + Vector3.UP * 0.8, Color(0.3, 0.9, 1.0), 0.8)


func apply_damage(
	amount: int, from_position: Vector3 = Vector3.ZERO, attack_options: Dictionary = {}
) -> String:
	if dead or i_frames > 0.0:
		return "invulnerable"

	var final_damage := amount
	var result := "hit"

	if state == State.GUARD and guard_cooldown <= 0.0:
		var facing := -global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		var to_source := Vector3(
			from_position.x - global_position.x, 0.0, from_position.z - global_position.z
		)
		var in_front := to_source.length() > 0.01 and facing.dot(to_source.normalized()) > 0.45
		if in_front:
			if guard_perfect_window > 0.0:
				final_damage = 0
				result = "perfect"
				stance_bonus(28.0, 15.0)
				guard_perfect_window = 0.0
				AudioManager.play_sfx("perfect_guard", 1.0)
				VFXManager.spawn_impact(
					global_position + Vector3.UP * 1.2, Color(1.0, 0.85, 0.4), 1.5
				)
				if attack_options.has("stagger"):
					combat.open_stagger_window(0.8)
			else:
				final_damage = maxi(1, int(final_damage * 0.3))
				result = "guard"
				stamina = maxf(0.0, stamina - 10.0)
				GameState.set_stamina(stamina)
				guard_cooldown = 0.25
				guard_perfect_window = 0.18
				AudioManager.play_sfx("guard", 1.0)
			_stats_changed()
			return result

	hp = maxi(0, hp - final_damage)
	GameState.set_hp(hp)
	AudioManager.play_sfx("hurt", 1.0)
	VFXManager.spawn_impact(global_position + Vector3.UP * 1.1, Color(1.0, 0.3, 0.25), 1.0)
	combat.reset_attack()
	if hp <= 0:
		die()
		return "dead"
	var dir := from_position - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	velocity += dir * float(attack_options.get("knockback", 5.0))
	hurt_timer = 0.22
	_enter_state(State.HURT)
	return result


func stance_bonus(energy_gain: float, stamina_gain: float) -> void:
	energy = minf(energy + energy_gain, GameState.max_energy)
	GameState.set_energy(energy)
	stamina = minf(stamina + stamina_gain, GameState.max_stamina)
	GameState.set_stamina(stamina)
	burst_charge = minf(burst_charge + energy_gain * 0.5, GameState.max_burst)
	GameState.set_burst(burst_charge)
	_stats_changed()


func die() -> void:
	dead = true
	state = State.DEAD
	GameState.set_hp(0)
	AudioManager.play_sfx("death", 1.0)
	GameState.state_changed.emit()
	died.emit()


func respawn(_show_ui: bool = true) -> void:
	dead = false
	hp = max_hp
	stamina = GameState.max_stamina
	energy = 40.0
	burst_charge = 0.0
	global_position = _spawn_point
	velocity = Vector3.ZERO
	GameState.player_position = _spawn_point
	_enter_state(State.MOVE)
	GameState.set_hp(hp)
	GameState.set_stamina(stamina)
	GameState.set_energy(energy)
	GameState.set_burst(0.0)
	AudioManager.play_sfx("ui", 1.0)
	respawned.emit()


func heal_full() -> void:
	hp = max_hp
	stamina = GameState.max_stamina
	energy = GameState.max_energy
	burst_charge = GameState.max_burst
	GameState.set_hp(hp)
	GameState.set_stamina(stamina)
	GameState.set_energy(energy)
	GameState.set_burst(burst_charge)
	_stats_changed()


func set_entry_position(pos: Vector3) -> void:
	global_position = pos
	_spawn_point = pos
	GameState.player_position = pos
	GameState.state_changed.emit()


func set_facing_yaw(yaw: float) -> void:
	ground_yaw = yaw
	rotation.y = yaw
	_update_visual_heading()


func get_target() -> Node3D:
	if targeting and targeting.current_target:
		return targeting.current_target
	return null


func is_attacking() -> bool:
	return state == State.ATTACK


func is_dodging() -> bool:
	return state == State.DODGE


func _enter_state(new_state: int) -> void:
	state = new_state
	push_state()


func push_state() -> void:
	rotation.y = ground_yaw


func _face_target_or_input() -> void:
	var target := get_target()
	if target:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			rotation.y = atan2(to.x, to.z)
			ground_yaw = rotation.y
		return
	movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if movement_input != Vector2.ZERO:
		var dir := _camera_relative_direction(movement_input)
		if dir.length() > 0.01:
			rotation.y = atan2(dir.x, dir.z)
			ground_yaw = rotation.y


func _update_visual_heading() -> void:
	if state == State.MOVE and move_direction.length() > 0.05:
		ground_yaw = atan2(move_direction.x, move_direction.z)
	elif state != State.DODGE:
		rotation.y = lerp_angle(rotation.y, ground_yaw, 0.22)
	_update_visual_anim()


func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	var cam := get_tree().get_first_node_in_group("camera")
	var basis: Basis
	if cam is Camera3D:
		basis = cam.global_transform.basis
	else:
		basis = global_transform.basis
	var forward := -basis.z
	var right := basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (
		(forward * -input_dir.y + right * input_dir.x).normalized()
		if input_dir != Vector2.ZERO
		else Vector3.ZERO
	)


func _dodge_direction() -> Vector3:
	movement_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if movement_input != Vector2.ZERO:
		return _camera_relative_direction(movement_input)
	var target := get_target()
	if target:
		var to := global_position - target.global_position
		to.y = 0.0
		if to.length() > 0.01:
			return to.normalized()
	return -global_transform.basis.z


func _update_visual_anim() -> void:
	if visual == null or _mesh == null:
		return
	if state == State.DODGE:
		_scale_visual(1.05, 0.85)
	elif state == State.GUARD:
		_scale_visual(1.0, 0.92)
	elif state == State.ATTACK:
		_scale_visual(1.08, 0.95)
	elif state == State.MOVE and movement_input != Vector2.ZERO and is_on_ground():
		var t := sinf(Time.get_ticks_msec() * 0.02)
		_scale_visual(1.0, 0.96 + t * 0.04)
	else:
		_scale_visual(1.0, 1.0)


func _scale_visual(x: float, y: float) -> void:
	visual.scale = visual.scale.lerp(Vector3(x, y, x), 0.25)


func _stats_changed() -> void:
	stats_changed.emit()


func _configure_visual() -> void:
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.55
	_mesh.mesh = capsule
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.22, 0.55, 0.7)
	_mat.roughness = 0.6
	_mat.emission_enabled = true
	_mat.emission = Color(0.05, 0.2, 0.3)
	_mesh.material_override = _mat
	visual.add_child(_mesh)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	head.mesh = sphere
	head.position = Vector3(0, 0.98, 0)
	head.material_override = _mat
	visual.add_child(head)
