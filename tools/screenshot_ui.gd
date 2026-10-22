extends SceneTree
## Developer helper: renders the overlay panels (quiz, magic mirror, counting,
## grid HUD) so their layout can be inspected without clicking through the
## game by hand.
##
##   godot --path . --script tools/screenshot_ui.gd
##
## Images are written to res://_shots.
##
## Note: autoload singletons are not available as bare identifiers while a
## `--script` runs, so QuestManager is looked up through the scene tree.

var _frame := 0
var _main: Node
var _quest: Node


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	# Jumping between missions for the screenshots must not touch the save file.
	if _quest != null:
		_quest.set("persist", false)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 40:
		_save("title")
	if _frame == 60:
		_main.call("begin_playing")
	# The zone card closes itself after 5 s; closing it here keeps the frame
	# budget predictable, and its `dismissed` signal is what opens the prologue.
	if _frame == 90:
		_dismiss_intro()
	if _frame == 130:
		_save("story")
	if _frame == 145:
		_story_close()
	if _frame == 175:
		_save("zone1_mission")
	if _frame == 185:
		# Enter first person through the same public call the camera itself uses
		# when the child scrolls all the way in: the shot must show the pose the
		# game actually reaches, not a hand-placed camera.
		_call_rig("enter_first_person")
	if _frame == 205:
		_save("first_person")
	if _frame == 215:
		_call_rig("exit_first_person")
	if _frame == 230:
		_go_to(5)          # quiz
	if _frame == 325:
		_save("quiz")
	if _frame == 345:
		_go_to(33)         # listen & repeat
	if _frame == 475:
		_save("mirror")
	if _frame == 495:
		_go_to(9)          # counting
	if _frame == 635:
		_save("counting")
	if _frame == 655:
		_go_to(37)         # 10x10 grid
	if _frame == 805:
		_save("grid")
	if _frame == 825:
		# The pause menu and the controls page are opened through Main so the
		# screenshot exercises the same path a child takes (Esc -> CHANGE
		# CONTROLS), not a hand-built copy of the panels.
		_main.call("_on_pause")
	if _frame == 845:
		_save("pause")
	if _frame == 855:
		_main.call("_on_controls")
	if _frame == 885:
		_save("controls")
	if _frame == 893:
		_main.call("_on_controls_back")
	if _frame == 903:
		# The volume page, the newest panel in the game and the one most likely
		# to be asked about ("where do I turn the music down?").
		_main.call("_on_sound_settings")
	if _frame == 925:
		_save("sound")
	if _frame == 933:
		print("UI SHOTS DONE")
		quit()
	return false


## Closes the zone card the way a tap does. Its own fade then emits `dismissed`,
## which is what makes `Main` open the prologue — calling `_on_intro_dismissed()`
## directly would show the story page *under* the card still on screen.
func _dismiss_intro() -> void:
	var intro: Control = _main.get("zone_intro")
	if intro != null and intro.visible:
		intro.call("close")


## Leaves the story page the way GO ON does, without waiting for the fade: the
## screenshot script drives on frame counts and a 0.2 s tween would land in the
## middle of the next shot.
func _story_close() -> void:
	var story: Control = _main.get("story_screen")
	if story == null:
		return
	story.visible = false
	_main.call("_begin_mission")


func _go_to(mission_id: int) -> void:
	if _quest == null:
		_quest = root.get_node_or_null("QuestManager")
	if _quest != null:
		_quest.call("start_mission", mission_id)


## The camera rig of the level that is currently playing. Looked up on demand
## because `_go_to()` rebuilds the level, and a cached reference would point at
## the camera of the previous mission. `--script` runs have no bare autoload
## names either, hence the lookup through `_main`.
func _call_rig(method: StringName) -> void:
	var level: Node = _main.get("level")
	if level == null:
		return
	var rig: Node = level.get("camera_rig")
	if rig != null:
		rig.call(method)


func _save(tag: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		print("SHOT FAILED %s" % tag)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	var path := ProjectSettings.globalize_path("res://_shots/ui_%s.png" % tag)
	image.save_png(path)
	print("SHOT %s -> %s" % [tag, path])
