extends Node
## Lightweight debug tool accessible with F1. It also exposes a small QA console
## (you can write 'help' for the command list) so an empty level is testable
## without opening the editor.

var _enabled: bool = false
var _ui: Control
var _log: RichTextLabel
var _input: LineEdit
var _overlay: Label
var _hud: Label


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		_toggle()
		get_viewport().set_input_as_handled()
	if not _enabled:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_run_command(_input.text)
		_input.text = ""
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _hud and _hud.visible:
		_hud.text = (
			"FPS %d  |  Player %s"
			% [
				int(Engine.get_frames_per_second()),
				_get_player_state(),
			]
		)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_hud = Label.new()
	_hud.position = Vector2(12, 12)
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.modulate = Color(0.7, 0.9, 1.0, 0.9)
	_hud.visible = false
	layer.add_child(_hud)

	_ui = PanelContainer.new()
	_ui.anchors_preset = Control.PRESET_FULL_RECT
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.visible = false
	layer.add_child(_ui)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_ui.add_child(vbox)

	var title := Label.new()
	title.text = "TENKAI DEBUG CONSOLE"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log)

	_input = LineEdit.new()
	_input.placeholder_text = "help, tp, heal, spawn, boss_reset, mission, fps, save"
	vbox.add_child(_input)


func _toggle() -> void:
	_enabled = not _enabled
	_ui.visible = _enabled
	_hud.visible = _enabled
	if _enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_input.grab_focus()
		_print("Console activée. Tape 'help'.")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _print(text: String) -> void:
	var previous := _log.text
	_log.text = "%s\n%s" % [previous, text] if previous else text


func _run_command(cmd: String) -> void:
	var parts := cmd.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var key := parts[0].to_lower()
	var args := parts.slice(1)
	match key:
		"help":
			_print(
				(
					"[code]tp [x y z] / heal / spawn [type] / boss / boss_reset "
					+ "/ complete_mission / fps / hitboxes / save / load / quit[/code]"
				)
			)
		"tp":
			_teleport(args)
		"heal":
			var player := get_tree().get_first_node_in_group("player")
			if player is Player:
				player.heal_full()
			else:
				GameState.set_hp(GameState.max_hp)
				GameState.set_stamina(GameState.max_stamina)
				GameState.set_energy(GameState.max_energy)
				GameState.set_burst(GameState.max_burst)
			_print("Player soigné.")
		"spawn":
			_spawn(args)
		"boss":
			get_tree().call_group("world", "debug_spawn_boss")
			_print("Boss appelé.")
		"boss_reset":
			get_tree().call_group("world", "debug_reset_boss")
			_print("Boss réinitialisé.")
		"complete_mission":
			MissionManager.debug_complete_current_mission()
			_print("Mission avancée par debug.")
		"fps":
			_print(
				"FPS: %d, nodes: %d" % [int(Engine.get_frames_per_second()), get_tree().node_count]
			)
		"hitboxes":
			get_tree().call_group("targeting", "toggle_hitbox_view")
			get_tree().call_group("camera", "toggle_hitbox_view")
			_print("Hitboxes / debug toggled.")
		"save":
			_print("Sauvegarde: %s" % ("OK" if SaveManager.save() else "ÉCHEC"))
		"load":
			_print("Chargement: %s" % ("OK" if SaveManager.load_game() else "AUCUNE SAUVEGARDE"))
		"quit":
			get_tree().quit()
		_:
			_print("Commande inconnue: %s" % key)


func _teleport(args: PackedStringArray) -> void:
	if args.size() < 3:
		_print("Usage: tp x y z")
		return
	var p := get_tree().get_first_node_in_group("player")
	if p is Node3D:
		p.global_position = Vector3(float(args[0]), float(args[1]), float(args[2]))
		_print("Téléporté.")


func _spawn(args: PackedStringArray) -> void:
	var type := args[0] if args.size() > 0 else "warrior"
	get_tree().call_group("world", "debug_spawn_enemy", type)


func _get_player_state() -> String:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return "player absent"
	var hp: int = (
		p.get("hp") if p.has_method("get") and p.get("hp") != null else GameState.player_hp
	)
	var stamina: float = (
		p.get("stamina")
		if p.has_method("get") and p.get("stamina") != null
		else GameState.player_stamina
	)
	var targeting := get_tree().get_first_node_in_group("targeting")
	return "HP %d  STA %.0f  target:%s" % [hp, stamina, "on" if targeting else "?"]
