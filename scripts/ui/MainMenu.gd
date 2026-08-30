class_name MainMenu
extends Control


func _ready() -> void:
	add_to_group("menu")
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_buttons()
	get_tree().paused = true


func _configure_buttons() -> void:
	var continue_button := get_node_or_null("Center/ContinueButton") as Button
	if continue_button:
		continue_button.disabled = not SaveManager.has_save()


func _on_continue_pressed() -> void:
	SaveManager.load_game()
	$".".visible = false
	get_tree().paused = false


func _on_new_game_pressed() -> void:
	SaveManager.delete_save()
	GameState._reset_session()
	$".".visible = false
	get_tree().paused = false


func _on_quit_pressed() -> void:
	get_tree().quit()
