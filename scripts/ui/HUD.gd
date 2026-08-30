class_name HUD
extends CanvasLayer

var _player: Player
var _near_npc: NPC
var _dialogue_open: bool = false
var _dialogue_text: String = ""
var _notification_queue: Array[Dictionary] = []
var _notification_label: Label
var _prompt_label: Label
var _mission_title: Label
var _mission_objective: Label
var _hp_bar: ProgressBar
var _sta_bar: ProgressBar
var _energy_bar: ProgressBar
var _burst_bar: ProgressBar
var _boss_bar: ProgressBar
var _boss_name: Label
var _death_panel: Control
var _pause_panel: Control
var _dialogue_panel: Control
var _dialogue_label: Label
var _region_banner: Label
var _region_timer: float = 0.0
var _window_timer: float = 0.0


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameState.state_changed.connect(_refresh_hud)
	MissionManager.notification.connect(notify)
	MissionManager.mission_changed.connect(_on_mission_changed)
	MissionManager.objective_updated.connect(_on_objective_updated)
	_show_banner("MONDHOLM — Vallée de la Résonance")
	_on_mission_changed(
		GameState.current_mission_id,
		MissionManager.get_mission_title(),
		MissionManager.get_mission_objective()
	)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		notify("Sauvegarde: %s" % ("OK" if SaveManager.save() else "ÉCHEC"), "success")
		AudioManager.play_sfx("save", 1.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_load"):
		notify(
			"Chargement: %s" % ("OK" if SaveManager.load_game() else "AUCUNE SAUVEGARDE"), "info"
		)
		AudioManager.play_sfx("ui", 1.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		var menu := get_tree().get_first_node_in_group("menu")
		if not (menu and (menu as Control).visible):
			_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _player == null:
		return
	if _player.dead:
		if event.is_action_pressed("jump") or event.is_action_pressed("attack_light"):
			_player.respawn()
			_death_panel.visible = false
			get_viewport().set_input_as_handled()
			return
	if _dialogue_open:
		if (
			event.is_action_pressed("interact")
			or event.is_action_pressed("attack_light")
			or event.is_action_pressed("jump")
		):
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and _near_npc:
		get_tree().call_group("world", "request_npc_dialogue", _near_npc)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	_refresh_hud()
	_update_notifications(delta)
	_update_banner(delta)
	_update_pause_visibility()


func notify(text: String, kind: String = "info") -> void:
	_notification_queue.append({"text": text, "kind": kind, "time": 2.8})
	if _notification_queue.size() > 4:
		_notification_queue.pop_front()
	_show_next_notification()


func show_dialogue(name_text: String, line: String) -> void:
	_dialogue_open = true
	_dialogue_panel.visible = true
	_dialogue_label.text = "%s\n\n%s" % [name_text, line]
	_dialogue_text = line


func clear_prompt() -> void:
	_prompt_label.visible = false


func set_near_npc(npc_value: NPC) -> void:
	_near_npc = npc_value


func is_dialogue_open() -> bool:
	return _dialogue_open


func get_prompt_node() -> Label:
	return _prompt_label


func _advance_dialogue() -> void:
	_dialogue_open = false
	_dialogue_panel.visible = false
	if _near_npc:
		get_tree().call_group("world", "request_npc_dialogue", _near_npc)


func _refresh_hud() -> void:
	if _player:
		_hp_bar.max_value = _player.max_hp
		_hp_bar.value = _player.hp
		_sta_bar.max_value = GameState.max_stamina
		_sta_bar.value = _player.stamina
		_energy_bar.max_value = GameState.max_energy
		_energy_bar.value = _player.energy
		_burst_bar.max_value = GameState.max_burst
		_burst_bar.value = GameState.player_burst
	else:
		_hp_bar.max_value = GameState.max_hp
		_hp_bar.value = GameState.player_hp
		_sta_bar.max_value = GameState.max_stamina
		_sta_bar.value = GameState.player_stamina
		_energy_bar.max_value = GameState.max_energy
		_energy_bar.value = GameState.player_energy
		_burst_bar.max_value = GameState.max_burst
		_burst_bar.value = GameState.player_burst

	if _player and _player.dead:
		_death_panel.visible = true
	else:
		_death_panel.visible = false

	var boss := get_tree().get_first_node_in_group("boss")
	var boss_box := _boss_bar.get_parent() as Control
	if boss and is_instance_valid(boss):
		var hp_value: int = boss.get("hp") if boss.get("hp") != null else 0
		var max_value: int = boss.get("max_hp") if boss.get("max_hp") != null else 1
		_boss_bar.max_value = max_value
		_boss_bar.value = hp_value
		_boss_name.text = str(
			boss.get("name_display") if boss.get("name_display") != null else "VAELITH"
		)
		if boss_box:
			boss_box.visible = hp_value > 0 and max_value > 0
	else:
		if boss_box:
			boss_box.visible = false


func _on_mission_changed(_id: String, title: String, objective: String) -> void:
	_mission_title.text = title.to_upper()
	_mission_objective.text = objective


func _on_objective_updated(objective: String) -> void:
	_mission_objective.text = objective


func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_pause_panel.visible = false
	else:
		_pause_panel.visible = true
		get_tree().paused = true


func _update_pause_visibility() -> void:
	if get_tree().paused and not _pause_panel.visible:
		_pause_panel.visible = true


func _update_notifications(delta: float) -> void:
	for n in _notification_queue:
		n["time"] -= delta
	_notification_queue = _notification_queue.filter(
		func(n: Dictionary) -> bool: return n["time"] > 0.0
	)
	_show_next_notification()


func _show_next_notification() -> void:
	if _notification_queue.is_empty():
		return
	var n := _notification_queue[0]
	var kind_color := Color.WHITE
	match n["kind"]:
		"success":
			kind_color = Color(0.55, 1.0, 0.6)
		"warning":
			kind_color = Color(1.0, 0.75, 0.3)
		"boss":
			kind_color = Color(1.0, 0.4, 0.8)
		"mission":
			kind_color = Color(0.6, 0.85, 1.0)
	_notification_label.text = n["text"]
	_notification_label.modulate = kind_color
	_notification_label.visible = true


func _update_banner(delta: float) -> void:
	if _region_timer > 0.0:
		_region_timer -= delta
		_region_banner.modulate.a = clampf(_region_timer / 2.2, 0.0, 1.0)
	else:
		_region_banner.visible = false


func _show_banner(text: String) -> void:
	_region_banner.text = text
	_region_banner.visible = true
	_region_timer = 3.2


func _build_ui() -> void:
	layer = 10

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Mission panel (top-left).
	var mission := PanelContainer.new()
	mission.position = Vector2(18, 18)
	mission.size = Vector2(320, 92)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	mission.add_child(mv)
	_mission_title = Label.new()
	_mission_title.add_theme_font_size_override("font_size", 15)
	_mission_title.modulate = Color(0.8, 0.9, 1.0)
	mv.add_child(_mission_title)
	_mission_objective = Label.new()
	_mission_objective.add_theme_font_size_override("font_size", 13)
	_mission_objective.modulate = Color(0.9, 0.9, 0.9)
	mv.add_child(_mission_objective)
	root.add_child(mission)

	# Player resources (bottom-left).
	var stats := VBoxContainer.new()
	stats.position = Vector2(18, 620)
	stats.size = Vector2(300, 88)
	root.add_child(stats)
	_hp_bar = _make_bar("HP", Color(0.9, 0.25, 0.25))
	_sta_bar = _make_bar("STA", Color(0.2, 0.85, 0.4))
	_energy_bar = _make_bar("ÉNE", Color(0.3, 0.75, 1.0))
	_burst_bar = _make_bar("BURST", Color(1.0, 0.8, 0.2))
	for bar in [_hp_bar, _sta_bar, _energy_bar, _burst_bar]:
		stats.add_child(bar)

	# Boss bar (top center).
	var boss_box := VBoxContainer.new()
	boss_box.position = Vector2(440, 32)
	boss_box.size = Vector2(400, 46)
	root.add_child(boss_box)
	_boss_name = Label.new()
	_boss_name.add_theme_font_size_override("font_size", 16)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.modulate = Color(1.0, 0.65, 0.9)
	boss_box.add_child(_boss_name)
	_boss_bar = _make_bar("BOSS", Color(1.0, 0.3, 0.8))
	_boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(_boss_bar)

	# Notifications (top-right).
	_notification_label = Label.new()
	_notification_label.position = Vector2(900, 24)
	_notification_label.size = Vector2(360, 80)
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification_label.add_theme_font_size_override("font_size", 17)
	_notification_label.visible = false
	root.add_child(_notification_label)

	# Controls hints (bottom-right).
	var hints := Label.new()
	hints.position = Vector2(920, 666)
	hints.text = (
		"WASD bouger | SHIFT courir | SPACE sauter | J attaque | K lourd | E compétence\n"
		+ "R burst | G garde | ALT esquive | L lock-on | F interagir | F5 save | F9 load"
	)
	hints.add_theme_font_size_override("font_size", 11)
	hints.modulate = Color(0.75, 0.8, 0.9, 0.8)
	root.add_child(hints)

	# Interaction prompt (center-bottom).
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(500, 500)
	_prompt_label.size = Vector2(280, 32)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.modulate = Color(1.0, 0.9, 0.6)
	_prompt_label.visible = false
	root.add_child(_prompt_label)

	# Dialogue (bottom-center).
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.position = Vector2(210, 470)
	_dialogue_panel.size = Vector2(860, 120)
	_dialogue_panel.visible = false
	_dialogue_label = Label.new()
	_dialogue_panel.add_child(_dialogue_label)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 16)
	_dialogue_label.modulate = Color(0.95, 0.95, 0.95)
	root.add_child(_dialogue_panel)

	# Region banner (center).
	_region_banner = Label.new()
	_region_banner.position = Vector2(360, 240)
	_region_banner.size = Vector2(560, 55)
	_region_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_banner.add_theme_font_size_override("font_size", 30)
	_region_banner.modulate = Color(1.0, 0.92, 0.7, 1.0)
	root.add_child(_region_banner)

	# Death overlay.
	_death_panel = PanelContainer.new()
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.visible = false
	root.add_child(_death_panel)
	var death_label := Label.new()
	death_label.text = "\n\nTU ES TOMBÉ\n\n[SPACE] Récupérer"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 30)
	death_label.modulate = Color(0.9, 0.3, 0.3)
	_death_panel.add_child(death_label)

	# Pause overlay.
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	root.add_child(_pause_panel)
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "PAUSE — TENKAI"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 32)
	pause_box.add_child(pause_title)
	var pause_text := Label.new()
	pause_text.text = (
		"ÉCHAP: reprendre\n\nJ : attaque légère   K : lourde\n"
		+ "E : compétence   R : burst   G : garde\n"
		+ "ALT : esquive   L : lock-on   F : interagir\n\n"
		+ "F5 : sauvegarder   F9 : recharger   F1 : console debug"
	)
	pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_text.add_theme_font_size_override("font_size", 15)
	pause_box.add_child(pause_text)


func _make_bar(_prefix: String, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 12)
	bar.add_theme_stylebox_override("fill", _bar_fill_style(color))
	bar.show_percentage = false
	bar.value = 0
	return bar


func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style
