extends Node
## Convenience node for connecting world/player events after the world spawns.
## Kept intentionally small so it can be dropped into Main.tscn.


func _ready() -> void:
	call_deferred("_connect")
	var player := get_tree().get_first_node_in_group("player")
	if player is Player:
		var p := player as Player
		if not p.died.is_connected(_on_died):
			p.died.connect(_on_died)


func _connect() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player is Player and not player.died.is_connected(_on_died):
		player.died.connect(_on_died)


func _on_died() -> void:
	AudioManager.play_music("music_exploration")
