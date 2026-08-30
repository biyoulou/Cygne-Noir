class_name CombatController
extends Node

const ATTACK_DATA := {
	"light":
	{
		"damage": 14,
		"range": 2.5,
		"arc": 78,
		"dur": 0.30,
		"impact": 0.12,
		"kb": 4.0,
		"energy": 3.0,
		"stop": 0.045
	},
	"heavy":
	{
		"damage": 26,
		"range": 2.7,
		"arc": 120,
		"dur": 0.46,
		"impact": 0.20,
		"kb": 8.0,
		"energy": 5.0,
		"stop": 0.09
	},
	"air":
	{
		"damage": 18,
		"range": 2.6,
		"arc": 140,
		"dur": 0.34,
		"impact": 0.14,
		"kb": 6.0,
		"energy": 4.0,
		"stop": 0.07
	},
	"charge":
	{
		"damage": 38,
		"range": 3.0,
		"arc": 150,
		"dur": 0.62,
		"impact": 0.34,
		"kb": 11.0,
		"energy": 0.0,
		"stop": 0.12
	},
}

var _player: Player
var _current_attack: String = ""
var _attack_timer: float = 0.0
var _impact_done: bool = false
var _combo_index: int = 0
var _combo_reset_timer: float = 0.0
var _queued_attack: String = ""
var _hit_stop_active: bool = false
var _hit_stop_timer: float = 0.0
var _stagger_window: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player


func _process(delta: float) -> void:
	_combo_reset_timer = maxf(0.0, _combo_reset_timer - delta)
	if _combo_reset_timer <= 0.0 and _combo_index > 0:
		_combo_index = 0

	if _stagger_window > 0.0:
		_stagger_window = maxf(0.0, _stagger_window - delta)

	if _hit_stop_active:
		_hit_stop_timer -= delta
		if _hit_stop_timer <= 0.0:
			_hit_stop_active = false
			Engine.time_scale = 1.0
		return

	if _player.state != Player.State.ATTACK:
		return

	_attack_timer += delta
	if _current_attack == "skill":
		if _attack_timer >= 0.32:
			_player._enter_state(Player.State.MOVE)
		return
	if _current_attack == "burst":
		if _attack_timer >= 0.6:
			_player._enter_state(Player.State.MOVE)
		return

	if not _impact_done and _attack_timer >= float(ATTACK_DATA[_current_attack]["impact"]):
		_impact_done = true
		_apply_attack_hit()

	var dur := float(ATTACK_DATA[_current_attack]["dur"])
	if _attack_timer >= dur:
		if _queued_attack != "":
			var queued := _queued_attack
			_queued_attack = ""
			_start_attack(queued)
		else:
			_player._enter_state(Player.State.MOVE)


func try_attack(kind: String) -> void:
	if _player.dead or _player.state == Player.State.DEAD:
		return
	if _player.state == Player.State.ATTACK:
		if (
			kind == "light"
			and _combo_index < 2
			and _attack_timer > float(ATTACK_DATA["light"]["impact"])
		):
			_queued_attack = "light"
			return
		return
	if _player.state != Player.State.MOVE and _player.state != Player.State.GUARD:
		return
	if kind == "light" and not _player.is_on_ground():
		_start_attack("air")
	else:
		_start_attack(kind)


func try_skill() -> void:
	if (
		_player.dead
		or _player.state == Player.State.ATTACK
		or _player.state == Player.State.DODGE
		or _player.state == Player.State.HURT
	):
		return
	if _player.energy < 30.0:
		return
	_player.energy -= 30.0
	GameState.set_energy(_player.energy)
	_player._enter_state(Player.State.ATTACK)
	_current_attack = "skill"
	_attack_timer = -0.29
	_impact_done = false
	_player.guard_held = false
	AudioManager.play_sfx("skill", 1.0)
	VFXManager.spawn_impact(_player.global_position + Vector3.UP * 1.5, Color(0.25, 0.85, 1.0), 3.2)
	_apply_skill()


func _apply_skill() -> void:
	var center := _player.global_position + (-_player.global_transform.basis.z) * 2.0
	for e in _targets_in_range(4.5, 320.0):
		e.receive_hit(
			34,
			(e.global_position - _player.global_position).normalized(),
			{"stagger": 0.9, "knockback": 7.0}
		)
		VFXManager.spawn_spark(e.global_position + Vector3.UP, Color(0.25, 0.9, 1.0), 12)
	for b in _breakables_in_range(4.5):
		if b.has_method("break_totem"):
			b.break_totem()
	_camera_shake(0.5)
	_finish_fake_timed_action()


func try_burst() -> void:
	if (
		_player.dead
		or _player.state == Player.State.ATTACK
		or _player.state == Player.State.DODGE
		or _player.state == Player.State.HURT
	):
		return
	if GameState.player_burst < 55.0:
		return
	GameState.set_burst(0.0)
	_player._enter_state(Player.State.ATTACK)
	_current_attack = "burst"
	_attack_timer = -0.55
	_impact_done = false
	_player.guard_held = false
	AudioManager.play_sfx("burst", 1.0)
	VFXManager.spawn_burst_ring(_player.global_position, Color(0.5, 0.95, 1.0), 7.0)
	VFXManager.spawn_impact(_player.global_position + Vector3.UP * 1.2, Color(0.7, 1.0, 1.0), 4.5)
	_apply_burst()


func _apply_burst() -> void:
	for e in _targets_in_range(8.0, 360.0):
		e.receive_hit(
			52,
			(e.global_position - _player.global_position).normalized(),
			{"stagger": 1.4, "knockback": 12.0, "launch": true}
		)
		VFXManager.spawn_spark(e.global_position + Vector3.UP, Color(1.0, 0.95, 0.6), 18)
	for b in _breakables_in_range(8.0):
		if b.has_method("break_totem"):
			b.break_totem()
	_camera_shake(0.8)
	_finish_fake_timed_action()


func _start_attack(kind: String) -> void:
	if kind == "light":
		_combo_index = mini(_combo_index + 1, 3)
		_combo_reset_timer = 1.1
	_current_attack = kind
	_attack_timer = 0.0
	_impact_done = false
	_queued_attack = ""
	_player._enter_state(Player.State.ATTACK)
	_player.guard_held = false
	AudioManager.play_sfx("swing", _attack_pitch(kind))
	_player._face_target_or_input()


func _attack_pitch(kind: String) -> float:
	match kind:
		"heavy":
			return 0.72
		"charge":
			return 0.6
		_:
			return 1.0 + _combo_index * 0.12


func _apply_attack_hit() -> void:
	var data: Dictionary = ATTACK_DATA[_current_attack]
	var damage := int(data["damage"])
	var range_f := float(data["range"])
	var arc := float(data["arc"])
	var opts := {
		"knockback": float(data["kb"]),
		"stagger": 0.35 if _current_attack != "heavy" else 0.6,
		"launch": _current_attack == "air",
	}
	var any_hit := false
	for e in _targets_in_range(range_f, arc):
		var dir := e.global_position - _player.global_position
		dir.y = 0.0
		dir = dir.normalized()
		e.receive_hit(damage, dir, opts)
		any_hit = true
		if _current_attack == "air":
			e.receive_hit(0, Vector3.UP, {"launch": true})
		VFXManager.spawn_spark(e.global_position + Vector3.UP * 1.0, Color(0.5, 0.9, 1.0), 10)

	for b in _breakables_in_range(range_f):
		if b.has_method("break_totem"):
			b.break_totem()
			any_hit = true

	_player.energy = minf(_player.energy + float(data["energy"]), GameState.max_energy)
	GameState.set_energy(_player.energy)
	_player.burst_charge = minf(
		_player.burst_charge + float(data["energy"]) * 0.45, GameState.max_burst
	)
	GameState.set_burst(_player.burst_charge)

	if any_hit:
		_hit_stop_effect(float(data["stop"]))
		_camera_shake(0.25 if _current_attack != "heavy" else 0.45)
		_apply_combo_feedback()


func _breakables_in_range(range_f: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for b in get_tree().get_nodes_in_group("breakables"):
		if (
			b is Node3D
			and (b as Node3D).global_position.distance_to(_player.global_position) <= range_f
		):
			out.append(b as Node3D)
	return out


func _targets_in_range(range_f: float, arc: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D):
			continue
		var to: Vector3 = (e as Node3D).global_position - _player.global_position
		var dist := to.length()
		if dist > range_f:
			continue
		if arc < 359.0:
			var flat := to
			flat.y = 0.0
			flat = flat.normalized()
			var dot := forward.dot(flat)
			var cos_half := cos(deg_to_rad(arc * 0.5))
			if dot < cos_half:
				continue
		out.append(e as Node3D)
	return out


func _apply_combo_feedback() -> void:
	if _combo_index >= 3:
		AudioManager.play_sfx("hit_heavy", 1.0)
		_camera_shake(0.35)


func open_stagger_window(duration: float) -> void:
	_stagger_window = duration


func reset_attack() -> void:
	_current_attack = ""
	_queued_attack = ""
	_combo_index = 0
	if _player.state == Player.State.ATTACK:
		_player._enter_state(Player.State.MOVE)


func toggle_hitbox_view() -> void:
	_camera_shake(0.0)


func _hit_stop_effect(duration: float) -> void:
	if duration > 0.0 and not _hit_stop_active:
		_hit_stop_active = true
		_hit_stop_timer = duration
		Engine.time_scale = 0.18


func _camera_shake(amount: float) -> void:
	for c in get_tree().get_nodes_in_group("camera"):
		if c.has_method("shake"):
			c.shake(amount)


func _finish_fake_timed_action() -> void:
	_attack_timer = float(ATTACK_DATA["light"]["dur"]) - 0.2
	_impact_done = true
