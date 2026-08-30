class_name BossVaelith
extends CharacterBody3D

signal died
signal phase_changed(phase: int)
signal hp_changed(hp: int, max_hp: int)

enum BossState { DORMANT, INTRO, FIGHT, HURT, DEAD }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

const _PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/Projectile.tscn")

@export var name_display: String = "VAELITH"
@export var max_hp: int = 1500

var hp: int = 1500
var phase: int = 1
var is_alive: bool = true
var lock_height: float = 2.6
var boss_state: int = BossState.DORMANT

var _player: Player
var _visual: Node3D
var _mat: StandardMaterial3D
var _base_scale: Vector3 = Vector3.ONE
var _attack_id: String = ""
var _attack_phase: int = AttackPhase.WINDUP
var _attack_timer: float = 0.0
var _attack_windup: float = 0.6
var _attack_active: float = 0.4
var _attack_recovery: float = 0.3
var _cooldown: float = 1.0
var _hit_applied: bool = false
var _phase_switch_pending: int = 0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	add_to_group("debug")
	hp = max_hp
	_configure_visual()
	_emit_hp()


func begin_intro() -> void:
	boss_state = BossState.INTRO
	_visual.scale = Vector3(0.01, 0.01, 0.01)
	AudioManager.play_music("music_boss")
	AudioManager.play_sfx("boss_roar", 1.0)
	VFXManager.spawn_arena_transform(global_position + Vector3.UP * 1.0)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", _base_scale, 1.6).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_callback(func(): boss_state = BossState.FIGHT)


func respawn_boss() -> void:
	hp = max_hp
	phase = 1
	is_alive = true
	boss_state = BossState.DORMANT
	_visual.scale = _base_scale
	_attack_id = ""
	_cooldown = 1.0
	_emit_hp()
	phase_changed.emit(1)


func _physics_process(delta: float) -> void:
	if not is_alive or boss_state != BossState.FIGHT:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
			move_and_slide()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	if _attack_id == "" and _cooldown <= 0.0:
		_choose_attack()
	elif _attack_id != "":
		_update_attack(delta)
	else:
		_glide_toward_player(delta)


func _glide_toward_player(delta: float) -> void:
	if _player == null:
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var dir := to.normalized()
	velocity.x = dir.x * 2.5
	velocity.z = dir.z * 2.5
	velocity.y += -9.8 * delta
	_face_player()
	move_and_slide()


func _choose_attack() -> void:
	var roll := randf()
	match phase:
		1:
			if roll < 0.45:
				_start_attack("phase1_dash", 0.55, 0.45, 0.4)
			else:
				_start_attack("phase1_swipe", 0.6, 0.3, 0.4)
		2:
			if roll < 0.35:
				_start_attack("projectile_fan", 0.8, 0.2, 0.5)
			elif roll < 0.75:
				_start_attack("hazard_field", 0.7, 0.25, 0.6)
			else:
				_start_attack("phase2_dash", 0.55, 0.4, 0.35)
		3:
			if roll < 0.35:
				_start_attack("combo_dash", 0.55, 0.5, 0.3)
			elif roll < 0.65:
				_start_attack("projectile_fan", 0.75, 0.25, 0.4)
			elif roll < 0.9:
				_start_attack("hazard_field", 0.65, 0.3, 0.5)
			else:
				_start_attack("charged_swipe", 0.85, 0.3, 0.5)
		_:
			if roll < 0.28:
				_start_attack("awakened_burst", 1.2, 0.4, 0.7)
			elif roll < 0.6:
				_start_attack("combo_dash", 0.5, 0.5, 0.3)
			elif roll < 0.85:
				_start_attack("hazard_field", 0.6, 0.3, 0.5)
			else:
				_start_attack("charged_swipe", 0.8, 0.3, 0.45)


func _start_attack(
	id: String, windup: float, active: float, recovery: float, _hit_zone: float = 0.0
) -> void:
	_attack_id = id
	_attack_phase = AttackPhase.WINDUP
	_attack_timer = 0.0
	_attack_windup = windup
	_attack_active = active
	_attack_recovery = recovery
	_hit_applied = false
	velocity = Vector3.ZERO
	AudioManager.play_sfx("skill", 0.8)
	_visual_telegraph(true)


func _update_attack(delta: float) -> void:
	_attack_timer += delta
	_face_player()
	match _attack_phase:
		AttackPhase.WINDUP:
			if _attack_timer >= _attack_windup:
				_attack_phase = AttackPhase.ACTIVE
				_attack_timer = 0.0
				_fire_attack()
		AttackPhase.ACTIVE:
			_process_active(delta)
			if _attack_timer >= _attack_active:
				_attack_phase = AttackPhase.RECOVERY
				_attack_timer = 0.0
				_visual_telegraph(false)
				velocity = Vector3.ZERO
		AttackPhase.RECOVERY:
			if _attack_timer >= _attack_recovery:
				_attack_id = ""
				_cooldown = _next_cooldown()
	move_and_slide()


func _fire_attack() -> void:
	match _attack_id:
		"phase1_dash":
			_dash_velocity(1.0)
		"phase1_swipe":
			_melee_arc_hit(2.8, 100.0, 1.0)
		"combo_dash":
			_dash_velocity(1.25)
			_melee_arc_hit(3.2, 120.0, 0.9)
		"phase2_dash":
			_dash_velocity(1.4)
			_melee_arc_hit(3.2, 140.0, 1.1)
		"charged_swipe":
			pass
		"projectile_fan":
			_projectile_fan()
		"hazard_field":
			_hazard_field()
		"awakened_burst":
			_awakened_burst()


func _process_active(_delta: float) -> void:
	if _attack_id == "phase1_dash" or _attack_id == "combo_dash" or _attack_id == "phase2_dash":
		velocity.y = 0.0
		if (
			not _hit_applied
			and _player
			and global_position.distance_to(_player.global_position) <= 3.0
		):
			_hit_applied = true
			_apply_melee(damage_for_phase(1.0))
	elif _attack_id == "charged_swipe":
		if _attack_timer >= _attack_active * 0.5 and not _hit_applied:
			_hit_applied = true
			_melee_arc_hit(3.8, 180.0, 1.5)


func _dash_velocity(multiplier: float) -> void:
	if _player == null:
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	var dir := to.normalized()
	var speed := 11.0 * multiplier
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0
	VFXManager.spawn_dash_trail(global_position + Vector3.UP * 1.2, Color(1.0, 0.5, 0.8), 1.2)


func _melee_arc_hit(range_f: float, arc: float, mult: float) -> void:
	if _player == null:
		return
	var to := _player.global_position - global_position
	var dist := to.length()
	if dist > range_f:
		return
	var forward := _facing()
	var flat := to
	flat.y = 0.0
	flat = flat.normalized()
	if forward.dot(flat) >= cos(deg_to_rad(arc * 0.5)):
		_apply_melee(mult)
		VFXManager.spawn_impact(_player.global_position + Vector3.UP, Color(1.0, 0.45, 0.9), 1.7)


func _apply_melee(mult: float) -> void:
	if _player == null:
		return
	var result := _player.apply_damage(
		int(round(damage_for_phase(mult))), global_position, {"knockback": 7.0}
	)
	if result == "perfect":
		_attack_id = ""
		_cooldown = 1.8
		_visual_telegraph(false)
		phase_changed.emit(phase)


func damage_for_phase(mult: float) -> float:
	var base := [16.0, 18.0, 22.0, 26.0][maxi(0, phase - 1)]
	return base * mult


func _projectile_fan() -> void:
	var dir := _facing()
	var count := 5 + phase * 2
	for i in range(count):
		var t := -0.55 + (float(i) / float(count - 1)) * 1.1
		var d := dir.rotated(Vector3.UP, t)
		var projectile := _PROJECTILE_SCENE.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.owner = get_tree().current_scene
		projectile.global_position = global_position + Vector3.UP * 2.0
		projectile.setup(d, 12 + phase * 2, "corrupted")
	VFXManager.spawn_impact(global_position + Vector3.UP * 2.0, Color(0.7, 0.3, 1.0), 2.2)


func _hazard_field() -> void:
	var count := 3 + phase
	for i in range(count):
		var random_offset := Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		if _player:
			random_offset += (_player.global_position - global_position) * 0.35
		_spawn_hazard(
			global_position + random_offset,
			2.4 + phase * 0.3,
			13 + phase * 2,
			1.2,
			Color(0.75, 0.25, 1.0)
		)


func _awakened_burst() -> void:
	for i in range(5):
		var angle := TAU * i / 5.0
		var offset := Vector3(cos(angle), 0, sin(angle)) * 4.5
		_spawn_hazard(global_position + offset, 3.0, 18, 0.9, Color(1.0, 0.4, 0.7))
	_spawn_hazard(global_position, 6.0, 26, 1.2, Color(1.0, 0.3, 0.8))
	VFXManager.spawn_burst_ring(global_position + Vector3.UP, Color(1.0, 0.4, 0.8), 6.0)
	AudioManager.play_sfx("burst", 0.9)


func _spawn_hazard(pos: Vector3, radius: float, damage: int, delay: float, color: Color) -> void:
	var hazard := BossHazard.new()
	get_tree().current_scene.add_child(hazard)
	hazard.owner = get_tree().current_scene
	hazard.global_position = pos + Vector3.UP * 0.05
	hazard.setup(radius, damage, delay, color)


func receive_hit(
	damage: int, _knockback_dir: Vector3 = Vector3.ZERO, options: Dictionary = {}
) -> void:
	if not is_alive or boss_state == BossState.DORMANT:
		return
	if damage > 0:
		hp = maxi(0, hp - damage)
		_emit_hp()
		AudioManager.play_sfx("hit_heavy", 1.0)
		VFXManager.spawn_spark(global_position + Vector3.UP * 2.0, Color(1.0, 0.7, 0.9), 12)
		_check_phase()
		if hp <= 0:
			die()
	else:
		if options.get("launch", false):
			velocity.y = 6.0


func _check_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	var target := 1
	if ratio <= 0.15:
		target = 4
	elif ratio <= 0.40:
		target = 3
	elif ratio <= 0.65:
		target = 2
	if target > phase:
		phase = target
		phase_changed.emit(phase)
		_visual_telegraph(true)
		_attack_id = ""
		_cooldown = 1.4
		AudioManager.play_sfx("boss_roar", 1.0)
		VFXManager.spawn_arena_transform(global_position + Vector3.UP)
		if phase == 4:
			AudioManager.play_music("music_boss")


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	boss_state = BossState.DEAD
	hp = 0
	_emit_hp()
	collision_layer = 0
	AudioManager.play_sfx("boss_roar", 0.7)
	VFXManager.spawn_burst_ring(global_position + Vector3.UP, Color(1.0, 0.6, 1.0), 10.0)
	VFXManager.spawn_impact(global_position + Vector3.UP * 2.0, Color(1.0, 0.5, 1.0), 6.0)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(
		func():
			died.emit()
			MissionManager.on_boss_defeated()
			queue_free()
	)


func is_fighting() -> bool:
	return boss_state == BossState.FIGHT


func _next_cooldown() -> float:
	var base := [1.3, 1.1, 0.9, 0.7][maxi(0, phase - 1)]
	return base * randf_range(0.85, 1.15)


func _facing() -> Vector3:
	return -global_transform.basis.z


func _face_player() -> void:
	if _player == null:
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = atan2(to.x, to.z)


func _visual_telegraph(on: bool) -> void:
	if _mat:
		_mat.emission_energy_multiplier = 4.5 if on else 1.8


func _configure_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.22, 0.1, 0.4)
	_mat.roughness = 0.45
	_mat.emission_enabled = true
	_mat.emission = Color(0.7, 0.25, 0.9)
	_mat.emission_energy_multiplier = 1.8

	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.8
	capsule.height = 3.6
	torso.mesh = capsule
	torso.material_override = _mat
	torso.position = Vector3(0, 1.9, 0)
	_visual.add_child(torso)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	head.mesh = sphere
	head.material_override = _mat
	head.position = Vector3(0, 4.1, 0)
	_visual.add_child(head)

	var crown := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.28
	cone.height = 0.7
	crown.mesh = cone
	crown.material_override = _mat
	crown.position = Vector3(0, 4.6, 0)
	_visual.add_child(crown)

	_base_scale = _visual.scale


func _emit_hp() -> void:
	hp_changed.emit(hp, max_hp)
