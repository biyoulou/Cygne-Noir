extends Node
## Save/load singleton. Uses a single JSON file under user:// so it works on
## every desktop target without extra dependencies. Data validation is done
## before it is handed back to GameState.


func save() -> bool:
	var data: Dictionary = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"state": GameState.to_save_dict(),
	}
	var err := _write_json(_save_path(), data)
	return err == OK


func load_game() -> bool:
	var text: String = FileAccess.get_file_as_string(_save_path())
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	if not data.has("state"):
		return false
	var state: Dictionary = data["state"]
	if not (state is Dictionary):
		return false
	GameState.from_save_dict(state)
	AudioManager.set_volumes()
	get_tree().call_group("world", "apply_state")
	return true


func delete_save() -> void:
	var path := _save_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func has_save() -> bool:
	return FileAccess.file_exists(_save_path())


func _save_path() -> String:
	return "user://tenkai_save.json"


func _write_json(path: String, data: Dictionary) -> Error:
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json)
	file.close()
	return OK
