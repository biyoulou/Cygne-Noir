class_name EnemyBase
extends CharacterBody3D

signal died(enemy: Node)
signal defeated

enum AiState { IDLE, PATROL, CHASE, ATTACK, DODGE, STAGGER, HURT, RETREAT, DEAD }

const _PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/Projectile.tscn")

@export var enemy_type: String = "warrior"
@export var hp: int = 40
@export var max_hp: int = 40
@export var damage: int = 10
@export var move_speed: float = 4.2
@export var attack_range: float = 2.2
@export var detect_range: float = 22.0
@export var attack_cooldown: float = 1.1

var is_alive: bool = true
var state: int = AiState.IDLE
var target: Player
var attack_cooldown_timer: float = 0.0
var hurt_timer: float = 0.0
var stagger_timer: float = 0.0
var dodge_timer: float = 0.0
var stuck_timer: float = 0.0
var patrol_a: Vector3
var patrol_b: Vector3
var _patrol_target: Vector3
var lock_height: float = 1.2
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D
var _visual: Node3D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("enemy")
	add_to_group("debug")
	hp = max_hp
	patrol_a = global_position
	patrol_b = global_position + Vector3(8, 0, 0)
	_patrol_target = patrol_b
	_configure_visual()
	_setup_type_stats()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	if target == null or not is_instance_valid(target):
		target = _find_player()

	if state == AiState.STAGGER:
		_process_stagger(delta)
	elif state == AiState.HURT:
		_process_hurt(delta)
	elif state == AiState.DODGE:
		_process_dodge(delta)
	else:
		_process_ai(delta)


func _process_ai(delta: float) -> void:
	if target == null:
		_state_idle(delta)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if not is_alive or target.dead:
		_state_idle(delta)
		return

	if dist <= detect_range or state == AiState.CHASE or state == AiState.ATTACK:
		if dist <= attack_range and attack_cooldown_timer <= 0.0:
			_attack(target, to.normalized())
		else:
			_chase(delta, to)
	else:
		_state_idle(delta)


func _state_idle(delta: float) -> void:
	state = AiState.IDLE
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()


func _chase(delta: float, to: Vector3) -> void:
	state = AiState.CHASE
	var dir := to.normalized()
	var speed := move_speed * 0.9
	if enemy_type == "brute":
		speed *= 0.75
	velocity.x = move_toward(velocity.x, dir.x * speed, 6.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 6.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	_look_at_player()
	move_and_slide()
	_check_stuck(delta, dir)


func _check_stuck(delta: float, dir: Vector3) -> void:
	if velocity.length() < 0.2 and is_on_floor():
		stuck_timer += delta
		if stuck_timer > 0.8:
			var side := Vector3(-dir.z, 0, dir.x)
			velocity += side * 6.0
			_move_random()
			stuck_timer = 0.0
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta)


func _move_random() -> void:
	var angle := randf_range(-1.5, 1.5)
	var dir := -global_transform.basis.z
	dir = dir.rotated(Vector3.UP, angle)
	velocity = dir * move_speed


func _attack(player: Player, dir: Vector3) -> void:
	state = AiState.ATTACK
	attack_cooldown_timer = attack_cooldown
	_look_at_player()
	if enemy_type == "archer" or enemy_type == "corrupted" or enemy_type == "elite":
		_ranged_attack(dir)
		return
	# Melee: brief wind-up then a short lunge + hit check.
	var lunge := dir * move_speed * 1.6
	velocity = lunge
	if not is_on_floor():
		velocity.y -= 9.8 * 0.016
	move_and_slide()
	_apply_melee_hit(player, dir)


func _apply_melee_hit(player: Player, _dir: Vector3) -> void:
	if not is_instance_valid(player):
		return
	var pos := player.global_position
	if global_position.distance_to(pos) <= attack_range + 0.5:
		var result: String = player.apply_damage(damage, global_position, {"knockback": 6.0})
		if result == "perfect":
			stagger(0.8)
	else:
		VFXManager.spawn_spark(global_position + Vector3.UP * 1.2, Color(1.0, 0.6, 0.3), 4)


func _ranged_attack(dir: Vector3) -> void:
	var projectile := _PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.owner = get_tree().current_scene
	projectile.global_position = global_position + Vector3.UP * 1.2
	projectile.setup(dir, damage if enemy_type != "corrupted" else damage + 6, enemy_type)
	VFXManager.spawn_spark(projectile.global_position, Color(1.0, 0.4, 0.3), 6)


func receive_hit(
	damage: int, knockback_dir: Vector3 = Vector3.ZERO, options: Dictionary = {}
) -> void:
	if not is_alive:
		return
	if damage > 0:
		hp = maxi(0, hp - damage)
		AudioManager.play_sfx("hit_heavy" if damage >= 24 else "hit", randf_range(0.85, 1.1))
		VFXManager.spawn_spark(global_position + Vector3.UP * 1.1, Color(1.0, 0.7, 0.3), 8)
		var kb := float(options.get("knockback", 5.0))
		if knockback_dir != Vector3.ZERO:
			var flat := knockback_dir
			flat.y = 0.0
			velocity += flat * kb
		if options.get("launch", false):
			velocity.y = 7.0
		var stagger := float(options.get("stagger", 0.0))
		if stagger > 0.0:
			stagger(stagger)
		else:
			state = AiState.HURT
			hurt_timer = 0.22
		if hp <= 0:
			die()
	else:
		if options.get("launch", false):
			velocity.y = 7.0
			state = AiState.HURT
			hurt_timer = 0.3


func stagger(duration: float) -> void:
	stagger_timer = duration
	state = AiState.STAGGER
	velocity.x *= 0.2
	velocity.z *= 0.2


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	state = AiState.DEAD
	hp = 0
	died.emit(self)
	defeated.emit()
	AudioManager.play_sfx("totem_break", 0.9)
	VFXManager.spawn_poof(global_position + Vector3.UP, Color(0.7, 0.9, 1.0))
	_spawn_drop()
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(_finish_death)


func _finish_death() -> void:
	queue_free()


func _spawn_drop() -> void:
	var drop := FocusPickup.new()
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position + Vector3.UP * 1.0
	drop.energy_value = 6 if enemy_type != "elite" else 14
	drop.setup_color(Color(0.35, 0.95, 1.0))


func _process_stagger(delta: float) -> void:
	stagger_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if stagger_timer <= 0.0:
		state = AiState.CHASE


func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if hurt_timer <= 0.0:
		state = AiState.CHASE


func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	velocity += -global_transform.basis.z * 18.0 * delta
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if dodge_timer <= 0.0:
		state = AiState.CHASE


func _look_at_player() -> void:
	if target == null:
		return
	var to := target.global_position - global_position
	if to.length() > 0.1:
		rotation.y = atan2(to.x, to.z)


func _find_player() -> Player:
	var p := get_tree().get_first_node_in_group("player")
	return p as Player


func _setup_type_stats() -> void:
	match enemy_type:
		"warrior":
			hp = 40
			damage = 10
			move_speed = 4.4
			attack_range = 2.1
			attack_cooldown = 0.9
		"brute":
			hp = 95
			damage = 22
			move_speed = 2.8
			attack_range = 2.6
			attack_cooldown = 1.7
			_scale_visual(1.45, 1.5)
		"archer":
			hp = 32
			damage = 9
			move_speed = 3.8
			attack_range = 11.0
			attack_cooldown = 1.4
		"corrupted":
			hp = 55
			damage = 12
			move_speed = 3.6
			attack_range = 9.0
			attack_cooldown = 1.3
		"elite":
			hp = 150
			damage = 18
			move_speed = 3.9
			attack_range = 2.4
			attack_cooldown = 0.7
			_scale_visual(1.2, 1.3)
	max_hp = hp
	lock_height = 1.2 * (_visual.scale.y if _visual else 1.0)


func _configure_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.5
	_mesh.mesh = capsule
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.75
	match enemy_type:
		"warrior":
			_mat.albedo_color = Color(0.5, 0.3, 0.3)
		"brute":
			_mat.albedo_color = Color(0.45, 0.28, 0.24)
		"archer":
			_mat.albedo_color = Color(0.28, 0.5, 0.35)
		"corrupted":
			_mat.albedo_color = Color(0.4, 0.18, 0.65)
			_mat.emission_enabled = true
			_mat.emission = Color(0.5, 0.2, 1.0)
		"elite":
			_mat.albedo_color = Color(0.62, 0.42, 0.18)
			_mat.emission_enabled = true
			_mat.emission = Color(0.8, 0.5, 0.1)
	_mesh.material_override = _mat
	_mesh.position = Vector3(0, 0.8, 0)
	_visual.add_child(_mesh)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head.mesh = sphere
	head.position = Vector3(0, 1.7, 0)
	head.material_override = _mat
	_visual.add_child(head)


func _scale_visual(sx: float, sy: float) -> void:
	_visual.scale = Vector3(sx, sy, sx)
	(($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D).height *= sy
	(($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D).radius *= sx
