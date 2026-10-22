extends SceneTree
## Developer helper: renders the running game for a few seconds and saves
## screenshots, so the UI can be checked without a human at the keyboard.
##
##   godot --path . --script tools/screenshot.gd
##
## Images land in user:// (next to the save file).

var _frames := 0
var _shots := 0
var _main: Node


func _initialize() -> void:
	# Load the real game scene exactly as the engine would.
	var scene: PackedScene = load("res://scenes/Main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	# Let the title screen settle, then capture a series of moments.
	if _frames == 60:
		_capture("title")
	if _frames == 120:
		# Simulate pressing Start so we can see the first mission in-game.
		if _main != null and _main.has_method("begin_playing"):
			_main.begin_playing()
	if _frames == 200:
		_capture("zone_intro")
	if _frames == 230:
		if _main != null and _main.has_method("_on_intro_dismissed"):
			_main._on_intro_dismissed()
	if _frames == 320:
		_capture("mission_1")
	if _frames == 400:
		_capture("mission_1_late")
	if _frames >= 420:
		print("SHOTS: %d" % _shots)
		quit()
	return false


func _capture(tag: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		return
	# Saved inside the project so it works even when user:// is unavailable
	# (read-only or sandboxed environment).
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	var path := "res://_shots/shot_%s.png" % tag
	image.save_png(ProjectSettings.globalize_path(path))
	_shots += 1
	print("SHOT %s -> %s" % [tag, ProjectSettings.globalize_path(path)])
