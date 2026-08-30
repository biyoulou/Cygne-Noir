extends Node
## Mission/story director. Keeps the narrative hooks out of the combat code so
## enemies/totems only report events and this singleton decides what happens.

signal mission_changed(mission_id: String, title: String, objective: String)
signal objective_updated(objective: String)
signal mission_completed(mission_id: String)
signal notification(text: String, kind: String)

const MISSIONS := {
	"prologue":
	{"title": "Prologue — Mondholm", "objective": "Découvre le village et parle à Mael"},
	"m1_totems": {"title": "Mission 1 — Les Totems", "objective": "Détruis les 3 totems corrompus"},
	"m2_fragments":
	{"title": "Mission 2 — Les Éclats", "objective": "Récupère les 3 Éclats de Résonance"},
	"m3_mill":
	{
		"title": "Mission 3 — Le Moulin",
		"objective": "Protège le moulin contre les vagues d'ennemis"
	},
	"m4_boss":
	{"title": "Mission 4 — L'Éveil", "objective": "Affronte Vaelith dans la zone du boss"},
	"epilogue": {"title": "Chapitre 1 terminé", "objective": "Mondholm respire de nouveau"},
}

var _totems_destroyed: int = 0
var _fragments_collected: int = 0
var _mill_started: bool = false
var _boss_mission_started: bool = false


func _ready() -> void:
	_reset_counters_from_state()


func _reset_counters_from_state() -> void:
	_totems_destroyed = 0
	_fragments_collected = 0
	for v in GameState.totem_status:
		if v:
			_totems_destroyed += 1
	for v in GameState.fragments_collected:
		if v:
			_fragments_collected += 1
	_mill_started = GameState.mill_defended
	_boss_mission_started = GameState.boss_defeated
	_broadcast_current()


func _broadcast_current() -> void:
	var m := MISSIONS.get(GameState.current_mission_id, MISSIONS["prologue"])
	mission_changed.emit(GameState.current_mission_id, m["title"], m["objective"])


func get_mission_id() -> String:
	return GameState.current_mission_id


func get_mission_title() -> String:
	var m: Dictionary = MISSIONS.get(GameState.current_mission_id, MISSIONS["prologue"])
	return m["title"]


func get_mission_objective() -> String:
	var m: Dictionary = MISSIONS.get(GameState.current_mission_id, MISSIONS["prologue"])
	return m["objective"]


func start_mission(mission_id: String) -> void:
	GameState.set_mission(mission_id)
	_broadcast_current()


func on_totem_destroyed(index: int) -> void:
	GameState.set_totem_destroyed(index)
	_totems_destroyed += 1
	notification.emit("Totem corrompu détruit  (%d/3)" % _totems_destroyed, "success")
	_spawn_fragment_for_totem(index)
	if not GameState.current_mission_id == "m1_totems":
		start_mission("m1_totems")
	_update_totem_objective()
	if _totems_destroyed >= 3:
		_complete_and_advance()


func _update_totem_objective() -> void:
	objective_updated.emit("Détruis les 3 totems corrompus  (%d/3)" % _totems_destroyed)


func _spawn_fragment_for_totem(index: int) -> void:
	get_tree().call_group("world", "spawn_fragment_for_totem", index)


func on_fragment_collected(index: int) -> void:
	GameState.set_fragment_collected(index)
	_fragments_collected += 1
	notification.emit("Éclat de Résonance récupéré  (%d/3)" % _fragments_collected, "info")
	if GameState.current_mission_id == "m1_totems" and _totems_destroyed >= 3:
		start_mission("m2_fragments")
	elif GameState.current_mission_id == "m2_fragments":
		objective_updated.emit("Récupère les 3 Éclats de Résonance  (%d/3)" % _fragments_collected)
	if _totems_destroyed >= 3 and _fragments_collected >= 3:
		_complete_and_advance()


func _complete_and_advance() -> void:
	if _totems_destroyed >= 3 and _fragments_collected >= 3:
		mission_completed.emit("m2_fragments")
		notification.emit("Le moulin est prêt à être défendu", "info")
		start_mission("m3_mill")
		get_tree().call_group("world", "open_mill_defense")
		return
	if _totems_destroyed >= 3 and GameState.current_mission_id == "m1_totems":
		start_mission("m2_fragments")


func start_mill_defense() -> void:
	if _mill_started:
		return
	_mill_started = true
	mission_completed.emit("m3_mill")


func on_mill_wave_completed() -> void:
	mission_completed.emit("m3_mill")
	GameState.mill_defended = true
	notification.emit("Le moulin est sauvé… quelque chose s'éveille.", "warning")
	start_mission("m4_boss")
	_boss_mission_started = true
	get_tree().call_group("world", "open_boss_arena")


func on_boss_defeated() -> void:
	if GameState.boss_defeated:
		return
	GameState.boss_defeated = true
	mission_completed.emit("m4_boss")
	notification.emit("VAELITH est vaincue. Chapitre 1 terminé.", "victory")
	start_mission("epilogue")


func request_mill_defense() -> void:
	get_tree().call_group("world", "start_mill_defense")


func debug_complete_current_mission() -> void:
	var current := GameState.current_mission_id
	match current:
		"prologue":
			start_mission("m1_totems")
		"m1_totems":
			for i in range(3):
				if not GameState.totem_status[i]:
					get_tree().call_group("world", "debug_break_totem", i)
		"m2_fragments":
			for i in range(3):
				if not GameState.fragments_collected[i]:
					get_tree().call_group("world", "debug_collect_fragment", i)
		"m3_mill":
			on_mill_wave_completed()
		"m4_boss":
			get_tree().call_group("world", "debug_slay_boss")
		"epilogue":
			notification.emit("Aucune mission à terminer.", "info")


func _on_save_state_invalid() -> void:
	_reset_counters_from_state()
