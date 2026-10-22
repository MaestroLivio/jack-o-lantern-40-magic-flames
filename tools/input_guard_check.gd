extends SceneTree
## Regression probe: does the world still take input while a mission panel owns
## the screen?
##
## The complaint this answers: "while I answer the questions with the children,
## my key presses still drive the character around". The quiz panel is a
## `Control` that stops the pointer, but nothing stops the *player*: WASD reaches
## `Jack._physics_process` through `Input.get_vector`, and the interact key
## reaches `Level._unhandled_input`, because neither is routed through the GUI.
##
## Measured here, for every mechanic that owns the screen:
##   * movement      -- hold "move_right" for a second, read Jack's position
##   * camera drag   -- drag the mouse across the middle of the panel, read yaw
##   * interact key  -- press "interact" while standing next to a target prop
##
##   godot --path . --headless --script tools/input_guard_check.gd
##
## Exit code 0 only when every check passes, like the other harnesses.

const DESIGN_W := 1280.0
const DESIGN_H := 720.0

var _failures: Array[String] = []
var _checked := 0
var _main: Node
var _quest: Node
var _level: Node


const Shutdown := preload("res://tools/probe_shutdown.gd")

func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	_main.set("story_enabled", false)
	_quest.set("persist", false)
	_quest.set("auto_advance", false)
	await _wait(0.8)
	_main.call("begin_playing")
	await _wait(1.0)
	_level = _main.get("level")

	# Mission 5 is the first quiz in the game; mission 4 is the first listen-and-
	# repeat panel. Both are "the child is reading with the teacher" moments.
	await _check_panel(5, "quiz")
	await _check_panel(4, "repeat")

	print("")
	if _failures.is_empty():
		print("INPUT RESULT: %d checks, 0 failures" % _checked)
		await Shutdown.and_quit(self, 0)
		return
	for f in _failures:
		print("INPUT FAIL  %s" % f)
	print("INPUT RESULT: %d checks, %d failure(s)" % [_checked, _failures.size()])
	await Shutdown.and_quit(self, 1)


func _check_panel(mission_id: int, label: String) -> void:
	_quest.call("start_mission", mission_id)
	# Long enough for the panel's own 0.4-0.55 s intro delay.
	await _wait(1.6)
	var player: Node3D = _level.get("player")
	if player == null:
		_failures.append("%s: no player" % label)
		return

	# --- 1. movement -------------------------------------------------------
	var before := player.global_position
	Input.action_press("move_right")
	await _wait(0.9)
	Input.action_release("move_right")
	await _wait(0.15)
	var moved := player.global_position.distance_to(before)
	_checked += 1
	if moved > 0.25:
		_failures.append("%s: the character walked %.2f m while the panel was open" % [label, moved])
	else:
		print("INPUT OK    %s: movement blocked (drift %.3f m)" % [label, moved])

	# --- 2. camera drag ----------------------------------------------------
	var rig: Node = _level.get("camera_rig")
	var yaw_before := float(rig.get("yaw")) if rig != null and rig.get("yaw") != null else 0.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(DESIGN_W * 0.5, DESIGN_H * 0.5)
	root.push_input(press)
	for i in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(DESIGN_W * 0.5 + (i + 1) * 40.0, DESIGN_H * 0.5)
		motion.relative = Vector2(40.0, 0.0)
		root.push_input(motion)
		await _wait(0.03)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(DESIGN_W * 0.5 + 240.0, DESIGN_H * 0.5)
	root.push_input(release)
	await _wait(0.2)
	var yaw_moved := 0.0
	if rig != null and rig.get("yaw") != null:
		yaw_moved = absf(float(rig.get("yaw")) - yaw_before)
	_checked += 1
	if yaw_moved > 0.02:
		_failures.append("%s: the camera turned %.3f rad while the panel was open" % [label, yaw_moved])
	else:
		print("INPUT OK    %s: camera drag blocked" % label)

	# --- 3. interact key ---------------------------------------------------
	# Stand next to the zone character and press E. Talking to the NPC is the
	# one interaction that is always in reach, whatever the mechanic spawned
	# (a quiz spawns no props at all), and it is exactly the one a child would
	# trigger by accident while the teacher is reading: "the game said the task
	# again and opened a speech bubble over the question".
	var character: Node3D = _level.get("npc")
	var dialogue: Control = _level.get("dialogue")
	if character == null or dialogue == null:
		print("INPUT --    %s: no character to test the interact key with" % label)
		return
	player.global_position = character.global_position + Vector3(0, 0, 2.0)
	await _wait(0.35)
	var said_before := dialogue.visible
	var press_e := InputEventAction.new()
	press_e.action = "interact"
	press_e.pressed = true
	root.push_input(press_e)
	await _wait(0.45)
	var release_e := InputEventAction.new()
	release_e.action = "interact"
	release_e.pressed = false
	root.push_input(release_e)
	await _wait(0.35)
	_checked += 1
	if dialogue.visible and not said_before:
		_failures.append("%s: the interact key opened the dialogue box behind the panel" % label)
	else:
		print("INPUT OK    %s: interact key ignored" % label)

