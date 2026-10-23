extends SceneTree
## Developer helper: renders the *new* panel states — the folded task bar, the
## folded dialogue, the folded quiz — so the change can be looked at instead of
## only measured.
##
##   godot --path . --script tools/screenshot_fold.gd
##
## Images are written to res://_shots. A folded panel looks exactly like the
## game with a small pill in a corner, which is precisely the thing that has to
## be seen: a probe can prove the pill is clickable, but only a picture shows
## that it is not sitting on top of something the child needs.
##
## Autoloads are not bare identifiers inside a `--script` tool, so QuestManager
## is looked up through the scene tree.

var _frame := 0
var _main: Node
var _quest: Node


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	if _quest != null:
		_quest.set("persist", false)
		# Timers would fold panels mid-shot; every fold in this script is made
		# by hand so each picture shows exactly one deliberate state.
		_quest.call("set_auto_hide_ui", false)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 40:
		_main.call("begin_playing")
	if _frame == 70:
		_dismiss_intro()
	if _frame == 100:
		var story: Control = _main.get("story_screen")
		if story != null:
			story.visible = false
		_main.call("_begin_mission")
	# --- The on-screen pad, open then folded ------------------------------
	# Placed before the task-bar shots and closed again before them, because
	# the pad and the bar share the left half of the screen: a picture taken
	# with both changed would not say which one moved.
	if _frame == 140:
		_save("fold_pad_open")
	if _frame == 150:
		_pad().call("set_folded", true)
	if _frame == 165:
		_save("fold_pad_folded")
	if _frame == 172:
		_pad().call("set_folded", false)
	# --- The task bar, open then folded -----------------------------------
	if _frame == 175:
		_save("fold_bar_open")
	if _frame == 185:
		_hud().call("collapse_prompt")
	if _frame == 200:
		_save("fold_bar_folded")
	if _frame == 210:
		_hud().call("expand_prompt")
	# --- The dialogue, open then folded -----------------------------------
	if _frame == 220:
		_main.get("level").call("_replay_instruction")
	if _frame == 250:
		_save("fold_dialogue_open")
	if _frame == 260:
		_main.get("level").get("dialogue").call("fold")
	if _frame == 280:
		_save("fold_dialogue_folded")
	if _frame == 290:
		_main.get("level").get("dialogue").call("hide_box")
	# --- The quiz, open then folded ---------------------------------------
	if _frame == 300:
		_quest.call("start_mission", 5)
	if _frame == 400:
		_save("fold_quiz_open")
	if _frame == 410:
		_quiz().call("fold_away")
	if _frame == 430:
		_save("fold_quiz_folded")
	if _frame == 440:
		_quiz().call("unfold")
	# --- The settings page with the new switch ----------------------------
	if _frame == 450:
		_go_to(9)
		if _quest != null:
			_quest.call("set_auto_hide_ui", true)
	if _frame == 470:
		_main.call("_on_pause")
	if _frame == 500:
		_main.call("_on_sound_settings")
	if _frame == 530:
		_save("fold_settings")
	if _frame == 540:
		print("FOLD SHOTS DONE")
		quit()
	return false


func _hud() -> Node:
	return _main.get("hud")


func _pad() -> Node:
	return _main.get("touch_pad")


func _quiz() -> Node:
	var level: Node = _main.get("level")
	if level == null:
		return null
	var ctrl: Node = level.get("mission_controller")
	if ctrl == null:
		return null
	for child in ctrl.get_children():
		if child.name == "QuizManager":
			return child
	return null


func _dismiss_intro() -> void:
	var intro: Control = _main.get("zone_intro")
	if intro != null and intro.visible:
		intro.call("close")


func _go_to(mission_id: int) -> void:
	if _quest == null:
		_quest = root.get_node_or_null("QuestManager")
	if _quest != null:
		_quest.call("start_mission", mission_id)


func _save(tag: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		print("SHOT FAILED %s" % tag)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	var path := ProjectSettings.globalize_path("res://_shots/ui_%s.png" % tag)
	image.save_png(path)
	print("SHOT %s -> %s" % [tag, path])
