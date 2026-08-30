class_name InteractSystem
extends Node
## Detects nearby NPCs / interactables and keeps the HUD prompt in sync.

var _active_area: Area3D
var _player: Player


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player


func _process(_delta: float) -> void:
	var player := _player
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		_player = player
	if player == null:
		return
	var found: Area3D
	for a in get_tree().get_nodes_in_group("interactables"):
		if a is Area3D and (a as Area3D).overlaps_body(player):
			found = a as Area3D
			break
	if found != _active_area:
		_active_area = found
		for ui in get_tree().get_nodes_in_group("hud"):
			if ui.has_method("set_near_npc"):
				ui.set_near_npc(null if found == null else found)
				if found == null:
					_clear_prompt(ui)
				else:
					_show_prompt(ui, found)


func _show_prompt(ui: Node, area: Area3D) -> void:
	if ui.has_method("get_prompt_node"):
		var prompt_label: Label = ui.get_prompt_node()
		if prompt_label:
			prompt_label.visible = true
			if area is NPC:
				prompt_label.text = "F — Parler à %s" % (area as NPC).npc_name
			else:
				prompt_label.text = "F — Interagir"


func _clear_prompt(ui: Node) -> void:
	if ui.has_method("clear_prompt"):
		ui.clear_prompt()
