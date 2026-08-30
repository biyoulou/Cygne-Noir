class_name Mondholm
extends Node3D
## Mondholm — Vallée de la Résonance. This node builds the whole vertical slice at
## runtime from deterministic primitives plus a fixed layout of POIs, totems,
## missions, enemies and the boss arena.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/EnemyBase.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/boss/Boss.tscn")

var _builder := TerrainBuilder.new()

var _player: Player
var _camera: CombatCamera
var _totem_nodes: Dictionary = {}
var _totem_positions: Array[Vector3] = []
var _fragment_nodes: Dictionary = {}
var _npc: NPC
var _boss: BossVaelith

var _mill_zone: MissionZone
var _boss_zone: MissionZone
var _mill_wave_active: bool = false
var _mill_wave_index: int = 0
var _mill_wave_members: Array[Node] = []
var _mill_wave_timer: float = 0.0
var _boss_started: bool = false
var _npc_talked: bool = false
var _has_persist_state: bool = false


func _ready() -> void:
	add_to_group("world")
	_build_environment()
	_spawn_player_and_camera()
	_spawn_totems()
	_spawn_npc()
	_spawn_fragments()
	_spawn_boss()
	_spawn_initial_enemies()
	_setup_zones()
	_reflect_state()


func _process(delta: float) -> void:
	_process_mill_waves(delta)


func _build_environment() -> void:
	_build_lighting_and_environment()
	add_child(_builder.build_terrain(64, 104729))

	var main_path: Array = [
		Vector3(0, 0, 8),
		Vector3(0, 0, 2),
		Vector3(-6, 0, 0),
		Vector3(-10, 0, -4),
		Vector3(-12, 0, -9),
		Vector3(-8, 0, -13),
		Vector3(-2, 0, -16),
	]
	add_child(_builder.build_path(4.0, main_path, TerrainBuilder.FLOOR_TOP + 0.04))

	var to_ruins: Array = [
		Vector3(0, 0, 8),
		Vector3(4, 0, 4),
		Vector3(10, 0, 0),
		Vector3(14, 0, -7),
		Vector3(18, 0, -13),
	]
	add_child(_builder.build_path(3.2, to_ruins, TerrainBuilder.FLOOR_TOP + 0.04))

	var forest_path: Array = [
		Vector3(-10, 0, -4),
		Vector3(-16, 0, -6),
		Vector3(-21, 0, -11),
		Vector3(-25, 0, -14),
	]
	add_child(_builder.build_path(2.6, forest_path, TerrainBuilder.FLOOR_TOP + 0.04))

	add_child(_builder.build_water(30.0, Vector3(0, TerrainBuilder.WATER_LEVEL, -14)))
	add_child(_builder.build_river(52.0, Vector3(0, TerrainBuilder.WATER_LEVEL + 0.02, -14)))
	_build_bridge()
	_build_village()
	_build_forest()
	_build_ruins()
	_build_grass()
	_build_boss_arena_decor()


func _build_lighting_and_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_color = Color(1.0, 0.94, 0.8)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.5, 0.52)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.7, 0.75)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.62, 0.65)
	env.fog_density = 0.012
	env_node.environment = env
	add_child(env_node)

	var moon_light := OmniLight3D.new()
	moon_light.light_color = Color(0.5, 0.8, 1.0)
	moon_light.light_energy = 0.35
	moon_light.omni_range = 30.0
	moon_light.position = Vector3(-10, 12, -6)
	add_child(moon_light)


func _build_bridge() -> void:
	add_child(_builder.build_bridge(4.5, 6.0, Vector3(-5, TerrainBuilder.FLOOR_TOP + 0.15, -14)))


func _build_village() -> void:
	var buildings := [
		[Vector3(-13, TerrainBuilder.FLOOR_TOP, -7), Vector3(1.1, 1.0, 1.1)],
		[Vector3(-9, TerrainBuilder.FLOOR_TOP, -9), Vector3(0.9, 0.95, 0.9)],
		[Vector3(-13, TerrainBuilder.FLOOR_TOP, -11), Vector3(1.0, 1.05, 1.0)],
		[Vector3(-6, TerrainBuilder.FLOOR_TOP, -11), Vector3(0.9, 0.9, 0.95)],
	]
	for b in buildings:
		add_child(_builder.build_building(b[0], b[1]))

	# Windmill: a taller house with a rotating wheel.
	var mill := _builder.build_building(
		Vector3(-3, TerrainBuilder.FLOOR_TOP, -16), Vector3(1.2, 1.6, 1.2)
	)
	add_child(mill)
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 1.4
	cyl.height = 0.16
	wheel.mesh = cyl
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.45, 0.31, 0.2)
	wheel.material_override = wmat
	wheel.position = Vector3(-3, 1.8, -13.1)
	wheel.rotation_degrees = Vector3(0, 0, 0)
	add_child(wheel)
	var wheel_tween := create_tween().set_loops()
	wheel_tween.tween_property(wheel, "rotation:y", TAU, 6.0)


func _build_forest() -> void:
	var positions := [
		[-27, -8],
		[-29, -12],
		[-24, -17],
		[-31, -18],
		[-20, -20],
		[-28, -22],
		[-24, -24],
		[-32, -26],
		[-18, -26],
		[-26, -30],
	]
	for i in range(positions.size()):
		var pos := positions[i]
		var tree := _builder.build_tree(
			Vector3(pos[0], TerrainBuilder.FLOOR_TOP, pos[1]), 1.15, i % 3 == 0
		)
		add_child(tree)
	# A few trees around the map edges for framing.
	add_child(_builder.build_tree(Vector3(-34, TerrainBuilder.FLOOR_TOP, 8), 1.2, false))
	add_child(_builder.build_tree(Vector3(30, TerrainBuilder.FLOOR_TOP, 6), 1.25, true))
	add_child(_builder.build_tree(Vector3(34, TerrainBuilder.FLOOR_TOP, -20), 1.2, false))


func _build_ruins() -> void:
	var positions := [
		Vector3(12, TerrainBuilder.FLOOR_TOP, -5),
		Vector3(16, TerrainBuilder.FLOOR_TOP, -9),
		Vector3(19, TerrainBuilder.FLOOR_TOP, -13),
		Vector3(13, TerrainBuilder.FLOOR_TOP, -14),
	]
	for pos in positions:
		add_child(_builder.build_rock(pos, 1.6))
	add_child(
		_builder.build_building(Vector3(16, TerrainBuilder.FLOOR_TOP, -10), Vector3(0.9, 0.6, 0.9))
	)


func _build_grass() -> void:
	add_child(_builder.build_grass(TerrainBuilder.FLOOR_TOP, 20240830, 240))


func _build_boss_arena_decor() -> void:
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var pos := Vector3(
			22 + cos(angle) * 10.5, TerrainBuilder.FLOOR_TOP, -16 + sin(angle) * 10.5
		)
		add_child(_builder.build_rock(pos, 1.0 + (i % 3) * 0.3))
	# A corrupted pedestal at the edge of the arena.
	add_child(_builder.build_totem(Vector3(28, TerrainBuilder.FLOOR_TOP, -12)))


func _spawn_player_and_camera() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	var spawn_pos := (
		GameState.player_position if _has_persist_state else Vector3(0, _ground(0, 8) + 1.8, 8)
	)
	_player.set_entry_position(spawn_pos)

	if _camera == null:
		_camera = CombatCamera.new()
		add_child(_camera)
		_camera.global_position = spawn_pos + Vector3(0, 3, 6)


func _spawn_totems() -> void:
	_totem_positions = [
		Vector3(-16, _ground(-16, -5), -5),
		Vector3(15, _ground(15, 4), 4),
		Vector3(-25, _ground(-25, -14), -14),
	]
	for i in range(_totem_positions.size()):
		var totem := Totem.new()
		totem.index = i
		add_child(totem)
		totem.global_position = _totem_positions[i]
		_totem_nodes[i] = totem


func _spawn_npc() -> void:
	_npc = NPC.new()
	_npc.npc_name = "Mael"
	_npc.npc_id = "mael"
	add_child(_npc)
	_npc.global_position = Vector3(-11, _ground(-11, -8), -8)


func _spawn_fragments() -> void:
	for i in range(3):
		var fragment := FragmentPickup.new()
		fragment.index = i
		add_child(fragment)
		fragment.global_position = Vector3(0, -1000, 0)
		fragment.visible = false
		fragment.monitoring = false
		_fragment_nodes[i] = fragment


func _spawn_boss() -> void:
	_boss = BOSS_SCENE.instantiate()
	add_child(_boss)
	_boss.global_position = Vector3(22, _ground(22, -16) + 0.4, -16)


func _spawn_initial_enemies() -> void:
	_spawn_enemy("warrior", Vector3(6, _ground(6, -8), -8))
	_spawn_enemy("warrior", Vector3(8, _ground(8, -6), -6))
	_spawn_enemy("archer", Vector3(15, _ground(15, -6), -6))
	_spawn_enemy("archer", Vector3(18, _ground(18, 0), 0))
	_spawn_enemy("corrupted", Vector3(-22, _ground(-22, -12), -12))
	_spawn_enemy("corrupted", Vector3(-26, _ground(-26, -17), -17))
	_spawn_enemy("brute", Vector3(-30, _ground(-30, -20), -20))


func _setup_zones() -> void:
	_mill_zone = MissionZone.new()
	_mill_zone.setup("mill", "Le Moulin", "mill", "Protège le moulin")
	_mill_zone.export_radius = 6.0
	add_child(_mill_zone)
	_mill_zone.global_position = Vector3(-3, _ground(-3, -16) + 0.4, -16)
	_mill_zone.set_enabled(false)

	_boss_zone = MissionZone.new()
	_boss_zone.setup("boss_arena", "Zone du Boss", "boss", "L'Éveil")
	_boss_zone.export_radius = 9.0
	add_child(_boss_zone)
	_boss_zone.global_position = Vector3(22, _ground(22, -16) + 0.4, -16)
	_boss_zone.set_enabled(false)


func _reflect_state() -> void:
	for i in range(3):
		if GameState.totem_status[i]:
			_force_break_totem_visual(i)
		if GameState.fragments_collected[i] and _fragment_nodes.has(i):
			_fragment_nodes[i].queue_free()
			_fragment_nodes.erase(i)
	if GameState.boss_defeated:
		if _boss and is_instance_valid(_boss):
			_boss.queue_free()
			_boss = null
	if _has_persist_state:
		MissionManager._reset_counters_from_state()


func _ground(x: float, z: float) -> float:
	return TerrainBuilder.height_at(x, z)


func _spawn_enemy(type: String, pos: Vector3) -> Node3D:
	var enemy := ENEMY_SCENE.instantiate() as Node3D
	enemy.set("enemy_type", type)
	add_child(enemy)
	enemy.global_position = pos
	return enemy


func on_zone_entered(zone: MissionZone) -> void:
	match zone.zone_kind:
		"mill":
			if GameState.current_mission_id == "m3_mill" and not _mill_wave_active:
				start_mill_defense()
			else:
				_notify("Le moulin attend que les 3 totems et les Éclats soient réunis.", "info")
		"boss":
			if (
				GameState.current_mission_id == "m4_boss"
				and not _boss_started
				and _boss
				and is_instance_valid(_boss)
			):
				_start_boss()
			elif not GameState.boss_defeated and _boss and is_instance_valid(_boss):
				_notify("Une présence ancienne dort ici… réunis d'abord les Éclats.", "warning")
		_:
			_notify(zone.zone_title, "info")


func on_totem_entered(_totem: Totem) -> void:
	if GameState.current_mission_id == "prologue":
		MissionManager.start_mission("m1_totems")
		_notify("Mission 1 : Les Totems — attaque les totems pour briser la corruption.", "mission")
	else:
		_notify("Totem corrompu : enchaîne tes attaques pour le détruire.", "info")


func on_npc_entered(_npc: NPC) -> void:
	_notify("Mael : [F] parler", "hint")


func on_npc_exited(_npc: NPC) -> void:
	_clear_prompt()


func request_npc_dialogue(npc: NPC) -> void:
	var line := npc.get_next_line()
	if line.is_empty():
		finish_npc_dialogue(npc)
	else:
		_show_dialogue(npc.npc_name, line)


func finish_npc_dialogue(npc: NPC) -> void:
	npc.reset_dialogue()
	_clear_prompt()
	if not _npc_talked:
		_npc_talked = true
		MissionManager.start_mission("m1_totems")
		_notify("Mael a parlé. Les Totems attendent.", "mission")


func spawn_fragment_for_totem(index: int) -> void:
	if _fragment_nodes.has(index) and is_instance_valid(_fragment_nodes[index]):
		var fragment := _fragment_nodes[index] as FragmentPickup
		fragment.visible = true
		fragment.global_position = _totem_positions[index] + Vector3(1.2, 1.0, 0.8)
		fragment.monitoring = true
		_notify("Un Éclat de Résonance est apparu près du totem détruit.", "info")


func open_mill_defense() -> void:
	if _mill_zone:
		_mill_zone.set_enabled(true)
	_notify("Mission 3 : Le Moulin — entre dans la zone du moulin.", "mission")


func start_mill_defense() -> void:
	if _mill_wave_active:
		return
	_mill_wave_active = true
	_mill_wave_index = 0
	_mill_wave_members.clear()
	MissionManager.start_mill_defense()
	_begin_next_wave()


func _begin_next_wave() -> void:
	if _mill_wave_index >= 3:
		_on_mill_cleared()
		return
	var center := Vector3(-3, 0, -16)
	var members := 2 + _mill_wave_index
	for i in range(members):
		var angle := randf_range(0.0, TAU)
		var radius := 5.0 + randf_range(0.0, 3.0)
		var pos := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var kind := "warrior"
		if _mill_wave_index >= 1 and i % 2 == 0:
			kind = "archer"
		if _mill_wave_index >= 2 and i % 3 == 0:
			kind = "brute"
		var enemy := _spawn_enemy(kind, Vector3(pos.x, _ground(pos.x, pos.z), pos.z))
		_mill_wave_members.append(enemy)
	_notify("Vague %d/%d — protège le moulin !" % [_mill_wave_index + 1, 3], "warning")


func _process_mill_waves(delta: float) -> void:
	if not _mill_wave_active:
		return
	var alive := 0
	for node in _mill_wave_members:
		if is_instance_valid(node) and node.get("is_alive"):
			alive += 1
	if alive <= 0:
		_mill_wave_index += 1
		if _mill_wave_index >= 3:
			_on_mill_cleared()
		else:
			_mill_wave_timer = 1.2
			_mill_wave_members.clear()
	if _mill_wave_timer > 0.0:
		_mill_wave_timer -= delta
		if _mill_wave_timer <= 0.0 and _mill_wave_active:
			_begin_next_wave()


func _on_mill_cleared() -> void:
	_mill_wave_active = false
	MissionManager.on_mill_wave_completed()
	_notify("Le moulin est sauvé. L'Éveil approche…", "mission")
	_notify("Rends-toi à la zone du boss à l'est des ruines.", "hint")
	if _boss_zone:
		_boss_zone.set_enabled(true)


func open_boss_arena() -> void:
	if _boss_zone:
		_boss_zone.set_enabled(true)
	if _boss and is_instance_valid(_boss):
		_boss.respawn_boss()


func _start_boss() -> void:
	_boss_started = true
	if _boss and is_instance_valid(_boss):
		_boss.begin_intro()
		_notify("VAELITH s'éveille. Chapitre 1 — Boss.", "boss")


func on_boss_defeated() -> void:
	_notify("VAELITH est tombée. La Résonance du Vent revient à Mondholm.", "victory")
	GameState.boss_defeated = true


func debug_spawn_enemy(type: String) -> void:
	var pos := _player.global_position + _player.global_transform.basis.z * -4.0
	_spawn_enemy(type, Vector3(pos.x, _ground(pos.x, pos.z) + 0.4, pos.z))


func debug_break_totem(index: int) -> void:
	if _totem_nodes.has(index) and is_instance_valid(_totem_nodes[index]):
		_totem_nodes[index].break_totem()


func debug_collect_fragment(index: int) -> void:
	if not GameState.fragments_collected[index]:
		MissionManager.on_fragment_collected(index)


func debug_spawn_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		_spawn_boss()
	if _boss:
		_boss.visible = true
		_boss.global_position = _player.global_position + _player.global_transform.basis.z * -8.0
		_boss.respawn_boss()
		_start_boss()


func debug_reset_boss() -> void:
	if _boss and is_instance_valid(_boss):
		_boss.respawn_boss()
		_boss.global_position = Vector3(22, _ground(22, -16) + 0.4, -16)
		_boss.visible = true
	_boss_started = false


func debug_slay_boss() -> void:
	if _boss and is_instance_valid(_boss) and _boss.is_alive:
		_boss.begin_intro()
		_boss.die()
	else:
		MissionManager.on_boss_defeated()
		on_boss_defeated()


func apply_state() -> void:
	_has_persist_state = true
	if _player == null:
		return
	_player.set_entry_position(GameState.player_position)
	_player.set_facing_yaw(GameState.player_facing_yaw)
	_player.hp = GameState.player_hp
	_player.stamina = GameState.player_stamina
	_player.energy = GameState.player_energy
	_player.burst_charge = GameState.player_burst
	_reflect_state()


func _force_break_totem_visual(index: int) -> void:
	if _totem_nodes.has(index) and is_instance_valid(_totem_nodes[index]):
		var totem := _totem_nodes[index]
		_totem_nodes.erase(index)
		totem.is_alive = false
		totem.queue_free()


func _notify(text: String, kind: String) -> void:
	for ui in get_tree().get_nodes_in_group("hud"):
		if ui.has_method("notify"):
			ui.notify(text, kind)


func _show_dialogue(name_text: String, line: String) -> void:
	for ui in get_tree().get_nodes_in_group("hud"):
		if ui.has_method("show_dialogue"):
			ui.show_dialogue(name_text, line)


func _clear_prompt() -> void:
	for ui in get_tree().get_nodes_in_group("hud"):
		if ui.has_method("clear_prompt"):
			ui.clear_prompt()
