extends Node
## Set up the default InputMap at runtime so we do not have to hand-author
## serialized InputEventKey/InputEventJoypad objects in project.godot.
## This keeps the project portable across Godot 4.x minors.

const DEADZONE := 0.4


func _ready() -> void:
	_build_keyboard_actions()
	_build_gamepad_actions()


func _add_action(action: StringName, deadzone: float = DEADZONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _add_key(action: StringName, keycode: Key, physical: bool = true) -> void:
	_add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	if physical:
		ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _add_mouse(action: StringName, button: MouseButton) -> void:
	_add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: StringName, button: JoyButton) -> void:
	_add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: StringName, axis: JoyAxis, positive: bool) -> void:
	_add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = 1.0 if positive else -1.0
	InputMap.action_add_event(action, ev)


func _build_keyboard_actions() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP, false)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN, false)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT, false)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT, false)

	_add_key("sprint", KEY_SHIFT)
	_add_key("jump", KEY_SPACE)

	_add_key("attack_light", KEY_J)
	_add_key("attack_heavy", KEY_K)
	_add_key("skill", KEY_E)
	_add_key("burst", KEY_R)
	_add_key("guard", KEY_G)
	_add_key("dodge", KEY_ALT)
	_add_key("lock_on", KEY_L)
	_add_key("interact", KEY_F)
	_add_key("target_prev", KEY_Q)
	_add_key("target_next", KEY_TAB)
	_add_key("pause", KEY_ESCAPE)

	_add_action("debug", 0.1)
	_add_key("debug", KEY_F1)
	_add_key("quick_save", KEY_F5)
	_add_key("quick_load", KEY_F9)

	_add_action("camera_zoom_in", 0.1)
	_add_key("camera_zoom_in", KEY_PAGEUP, false)
	_add_action("camera_zoom_out", 0.1)
	_add_key("camera_zoom_out", KEY_PAGEDOWN, false)


func _build_gamepad_actions() -> void:
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, false)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, true)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, false)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, true)

	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("attack_light", JOY_BUTTON_X)
	_add_joy_button("attack_heavy", JOY_BUTTON_Y)
	_add_joy_button("skill", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("burst", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("guard", JOY_BUTTON_B)
	_add_joy_button("dodge", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button("lock_on", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("interact", JOY_BUTTON_BACK)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("target_next", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("target_prev", JOY_BUTTON_DPAD_LEFT)
