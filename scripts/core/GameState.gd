extends Node
## Global runtime state. Kept deliberately small: real actor state lives on the
## player/enemies, this singleton only stores the "session" level state which
## save/load and the mission director need to share.

signal state_changed

@export var max_hp: int = 120
@export var max_stamina: float = 100.0
@export var max_energy: float = 100.0
@export var max_burst: float = 100.0

var player_hp: int = 100
var player_stamina: float = 100.0
var player_energy: float = 100.0
var player_burst: float = 40.0

var player_position: Vector3 = Vector3(0, 1.2, 8)
var player_facing_yaw: float = 0.0

var boss_defeated: bool = false
var totem_status: Array[bool] = [false, false, false]
var fragments_collected: Array[bool] = [false, false, false]
var mill_defended: bool = false
var world_state: Dictionary = {}

var current_mission_id: String = "prologue"
var settings: Dictionary = {
	"master_volume": 0.8,
	"sfx_volume": 0.8,
	"music_volume": 0.6,
	"camera_sensitivity": 1.0,
	"camera_distance": 6.5,
	"camera_height": 2.0,
}


func _ready() -> void:
	_reset_session()


func _reset_session() -> void:
	player_hp = max_hp
	player_stamina = max_stamina
	player_energy = max_energy
	player_burst = 40.0
	boss_defeated = false
	totem_status = [false, false, false]
	fragments_collected = [false, false, false]
	mill_defended = false
	current_mission_id = "prologue"
	world_state = {}
	state_changed.emit()


func set_hp(value: int) -> void:
	player_hp = clampi(value, 0, max_hp)
	state_changed.emit()


func set_stamina(value: float) -> void:
	player_stamina = clampf(value, 0.0, max_stamina)
	state_changed.emit()


func set_energy(value: float) -> void:
	player_energy = clampf(value, 0.0, max_energy)
	state_changed.emit()


func set_burst(value: float) -> void:
	player_burst = clampf(value, 0.0, max_burst)
	state_changed.emit()


func set_mission(mission_id: String) -> void:
	current_mission_id = mission_id
	state_changed.emit()


func set_totem_destroyed(index: int) -> void:
	if index >= 0 and index < totem_status.size():
		totem_status[index] = true
		state_changed.emit()


func set_fragment_collected(index: int) -> void:
	if index >= 0 and index < fragments_collected.size():
		fragments_collected[index] = true
		state_changed.emit()


func to_save_dict() -> Dictionary:
	return {
		"version": 1,
		"player_hp": player_hp,
		"player_stamina": player_stamina,
		"player_energy": player_energy,
		"player_burst": player_burst,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"player_facing_yaw": player_facing_yaw,
		"boss_defeated": boss_defeated,
		"totem_status": totem_status.duplicate(),
		"fragments_collected": fragments_collected.duplicate(),
		"mill_defended": mill_defended,
		"current_mission_id": current_mission_id,
		"settings": settings.duplicate(true),
	}


func from_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	player_hp = int(data.get("player_hp", max_hp))
	player_stamina = float(data.get("player_stamina", max_stamina))
	player_energy = float(data.get("player_energy", max_energy))
	player_burst = float(data.get("player_burst", 40.0))

	var pos: Array = data.get("player_position", [0, 1.2, 8])
	if pos is Array and pos.size() >= 3:
		player_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player_facing_yaw = float(data.get("player_facing_yaw", 0.0))

	boss_defeated = bool(data.get("boss_defeated", false))
	var t: Array = data.get("totem_status", [false, false, false])
	var f: Array = data.get("fragments_collected", [false, false, false])
	for i in range(3):
		totem_status[i] = bool(t[i]) if i < t.size() else false
		fragments_collected[i] = bool(f[i]) if i < f.size() else false
	mill_defended = bool(data.get("mill_defended", false))
	current_mission_id = str(data.get("current_mission_id", "prologue"))
	var s: Dictionary = data.get("settings", {})
	for k in settings.keys():
		if s.has(k):
			settings[k] = s[k]
	state_changed.emit()
