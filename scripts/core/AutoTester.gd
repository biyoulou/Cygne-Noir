extends Node
## Headless QA test runner. Run with:
##   godot --headless --path . --scene res://scenes/main/AutoTest.tscn
## It exits with code 0 on pass and 1 on failure.

const REQUIRED_SCENES := [
	"res://scenes/main/Main.tscn",
	"res://scenes/main/AutoTest.tscn",
	"res://scenes/player/Player.tscn",
	"res://scenes/enemies/EnemyBase.tscn",
	"res://scenes/boss/Boss.tscn",
	"res://scenes/world/Mondholm.tscn",
]

const REQUIRED_SCRIPT_CLASSES := {
	"Player": "res://scripts/player/Player.gd",
	"EnemyBase": "res://scripts/enemies/EnemyBase.gd",
	"TargetingSystem": "res://scripts/player/TargetingSystem.gd",
	"BossVaelith": "res://scripts/boss/Boss.gd",
	"Mondholm": "res://scripts/world/MondholmWorld.gd",
	"CombatController": "res://scripts/player/CombatController.gd",
	"MissionZone": "res://scripts/world/MissionZone.gd",
	"Totem": "res://scripts/world/Totem.gd",
	"FragmentPickup": "res://scripts/world/FragmentPickup.gd",
}

const REQUIRED_ACTIONS := [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"sprint",
	"jump",
	"attack_light",
	"attack_heavy",
	"skill",
	"burst",
	"guard",
	"dodge",
	"lock_on",
	"interact",
	"target_next",
	"target_prev",
	"pause",
	"debug",
	"quick_save",
	"quick_load",
]

var _errors: Array[String] = []
var _warnings: Array[String] = []


func _ready() -> void:
	print("[AutoTester] Obtention de la liste des sources Godot...")
	var sources: PackedStringArray = Engine.get_source_files()
	for name in _required_script_classes.keys():
		_check_resource_exists(_required_script_classes[name])
	_check_scenes()
	_check_actions()
	_check_scripts(sources)
	_check_class_names(sources)
	_check_group_files()
	_report()


func _check_resource_exists(path: String) -> void:
	if not ResourceLoader.exists(path):
		_errors.append("Ressource absente: %s" % path)


func _check_scenes() -> void:
	for scene in REQUIRED_SCENES:
		if not ResourceLoader.exists(scene):
			_errors.append("Scène requise absente: %s" % scene)


func _check_actions() -> void:
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			_errors.append("Action InputMap absente: %s" % action)


func _check_scripts(sources: PackedStringArray) -> void:
	for source in sources:
		if not source.ends_with(".gd"):
			continue
		_check_references(source)
		_check_res_aliases(source)


func _check_class_names(_sources: PackedStringArray) -> void:
	for cls in _required_script_classes.keys():
		var path: String = _required_script_classes[cls]
		var text: String = FileAccess.get_file_as_string(path)
		if not text.contains("class_name " + cls):
			_warnings.append("Fichier %s ne déclare pas class_name %s." % [path, cls])


func _check_references(source: String) -> void:
	var text: String = FileAccess.get_file_as_string(source)
	if text.is_empty():
		return
	var ref_regex := RegEx.new()
	ref_regex.compile("res://[A-Za-z0-9_./\\-]+")
	var missing: Array[String] = []
	for match in ref_regex.search_all(text):
		var ref := match.get_string()
		if ref.ends_with("/"):
			continue
		if not ResourceLoader.exists(ref):
			missing.append(ref)
	for m in missing:
		_warnings.append("Référence res:// absente (%s): %s" % [source, m])


func _check_res_aliases(source: String) -> void:
	var text: String = FileAccess.get_file_as_string(source)
	for bad in ["res://scripts/", "res://scenes/"]:
		if (
			text.contains(bad)
			and not text.contains(bad + "scripts/")
			and not text.contains(bad + "scenes/")
		):
			_warnings.append("Alias suspect dans %s: %s" % [source, bad])


func _check_group_files() -> void:
	for dir in ["user://"]:
		pass


func _report() -> void:
	print("=".repeat(64))
	print("AUTOTESTER — %.0f erreurs, %.0f avertissements" % [_errors.size(), _warnings.size()])
	for e in _errors:
		print("  [ERREUR] " + e)
	for w in _warnings:
		print("  [AVERT] " + w)
	if _errors.is_empty():
		print("RÉSULTAT: OK")
	else:
		print("RÉSULTAT: ÉCHEC")
		get_tree().quit(1)
