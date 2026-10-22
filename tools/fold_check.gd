extends SceneTree
## Runtime regression probe for the "panels move out of the way" feature.
##
## The layout probe (`tools/layout_check.gd`) measures sizes; this one measures
## *behaviour*, which is the part that cannot be seen in a screenshot: whether a
## folded panel really frees the screen, whether it really comes back, and
## whether the timers that fold panels automatically ever fire on the wrong
## mission.
##
##   godot --path . --headless --script tools/fold_check.gd
##
## Exit code 0 only when every check passes. Autoloads are not bare identifiers
## inside a `--script` tool, so they are looked up through the scene tree.

var _failures: Array[String] = []
var _checks := 0
var _main: Node
var _quest: Node

const Shutdown := preload("res://tools/probe_shutdown.gd")


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("FOLD OK   %s" % label)
	else:
		var msg := label if detail.is_empty() else "%s (%s)" % [label, detail]
		print("FOLD FAIL %s" % msg)
		_failures.append(msg)


func _run() -> void:
	_main.set("story_enabled", false)
	_quest.set("persist", false)

	# --- 1. The setting exists, defaults to ON, and round-trips ------------
	_check("auto_hide_ui defaults to ON", bool(_quest.get("auto_hide_ui")))

	_quest.call("set_auto_hide_ui", false)
	_check("set_auto_hide_ui(false) sticks", not bool(_quest.get("auto_hide_ui")))
	_quest.call("set_auto_hide_ui", true)
	_check("set_auto_hide_ui(true) sticks", bool(_quest.get("auto_hide_ui")))

	_main.call("begin_playing")
	await _wait(1.0)
	_main.call("_on_intro_dismissed")
	await _wait(0.8)
	var hud = _main.get("hud")
	var level: Node = _main.get("level")
	_check("hud exists", hud != null)
	_check("level exists", level != null)
	if hud == null or level == null:
		_finish()
		return

	# --- 2. A new mission opens the bar ------------------------------------
	_quest.call("start_mission", 1)
	await _wait(1.5)
	_check("bar starts expanded", not bool(hud.call("is_prompt_collapsed")))

	# --- 3. Folding frees the screen, and the tab exists to undo it --------
	hud.call("collapse_prompt")
	await _wait(0.2)
	_check("collapse_prompt folds the bar", bool(hud.call("is_prompt_collapsed")))
	var tab_point: Vector2 = _center_of(hud.get("_prompt_tab"))
	_check("a TASK tab is on screen while folded",
		tab_point != Vector2.ZERO and bool(hud.call("blocks_point", tab_point)),
		"tab rect %s" % str(_rect_of(hud.get("_prompt_tab"))))
	_check("the middle of the screen is free while folded",
		not bool(hud.call("blocks_point", Vector2(640, 400))),
		"a tap in the middle must reach the world")

	hud.call("expand_prompt")
	await _wait(0.2)
	_check("expand_prompt brings the bar back", not bool(hud.call("is_prompt_collapsed")))
	_check("the TASK tab is gone once expanded",
		tab_point == Vector2.ZERO or not bool(hud.call("blocks_point", tab_point)))

	# --- 4. Turning the setting off unfolds the bar at once ---------------
	hud.call("collapse_prompt")
	await _wait(0.1)
	_check("bar folded again before the setting test", bool(hud.call("is_prompt_collapsed")))
	_quest.call("set_auto_hide_ui", false)
	await _wait(0.3)
	_check("turning auto-hide off unfolds the bar",
		not bool(hud.call("is_prompt_collapsed")))
	_quest.call("set_auto_hide_ui", true)

	# --- 5. A new mission always starts with the bar open -----------------
	hud.call("collapse_prompt")
	await _wait(0.1)
	_quest.call("start_mission", 2)
	await _wait(1.2)
	_check("a new mission reopens a folded bar",
		not bool(hud.call("is_prompt_collapsed")))

	# --- 6. The quiz: folding it must free the pointer --------------------
	var ctrl: Node = null
	_quest.call("start_mission", 5)
	await _wait(2.2)
	ctrl = level.get("mission_controller")
	_check("mission 5 has a quiz controller", ctrl != null)
	if ctrl != null:
		var quiz = _find_child_named(ctrl, "QuizManager")
		_check("quiz panel exists", quiz != null)
		if quiz != null:
			_check("quiz starts unfolded", not bool(quiz.call("is_folded")))
			_check("quiz owns the screen while open",
				bool(ctrl.call("is_panel_open")))
			quiz.call("fold_away")
			await _wait(0.2)
			_check("fold_away folds the quiz", bool(quiz.call("is_folded")))
			_check("a folded quiz releases the screen",
				not bool(ctrl.call("is_panel_open")),
				"the dialogue box must be allowed back")
			_check("the QUIZ pill takes clicks",
				bool(ctrl.call("blocks_fold_point", Vector2(640, 130))),
				"pill is top-centre, 104..156 px down")
			quiz.call("unfold")
			await _wait(0.2)
			_check("unfold brings the quiz back", not bool(quiz.call("is_folded")))
			_check("an unfolded quiz owns the screen again",
				bool(ctrl.call("is_panel_open")))

	# --- 7. The dialogue box: folding must not answer it ------------------
	# `_replay_instruction` is the same path the E key uses.
	# The quiz is closed first: `_replay_instruction` deliberately falls back
	# to a toast while a panel owns the screen, so leaving it open would test
	# the fallback instead of the box.
	if ctrl != null:
		var open_quiz = _find_child_named(ctrl, "QuizManager")
		if open_quiz != null:
			open_quiz.call("close")
	_quest.call("start_mission", 1)
	await _wait(1.5)
	level.call("_replay_instruction")
	await _wait(0.5)
	var box = level.get("dialogue")
	_check("dialogue box opened", box != null and bool(box.visible))
	if box != null:
		_check("dialogue starts unfolded", not bool(box.call("is_folded")))
		var advanced := [false]
		box.advanced.connect(func() -> void: advanced[0] = true)
		box.call("fold")
		await _wait(0.3)
		_check("fold puts the dialogue away", bool(box.call("is_folded")))
		_check("folding a dialogue never advances the story",
			not advanced[0],
			"`advanced` must only ever come from OK")
		var pill: Vector2 = _center_of(box.get("_fold_tab"))
		_check("the SPEECH pill takes clicks",
			pill != Vector2.ZERO and bool(box.call("blocks_point", pill)),
			"pill rect %s" % str(_rect_of(box.get("_fold_tab"))))
		box.call("unfold")
		await _wait(0.2)
		_check("unfold brings the dialogue back", not bool(box.call("is_folded")))
		box.call("hide_box")
		await _wait(0.3)
		_check("a closed dialogue leaves no pill behind",
			pill == Vector2.ZERO or not bool(box.call("blocks_point", pill)))

	# --- 8. Fast mission churn cannot fold the wrong bar -------------------
	# This is the race the `_prompt_token` guard exists for: the smoke test
	# solves missions back to back, and a timer left over from mission N would
	# otherwise fold the bar of mission N+1 while the child read it.
	_quest.call("start_mission", 1)
	await _wait(0.4)
	_quest.call("start_mission", 2)
	await _wait(0.4)
	_quest.call("start_mission", 3)
	await _wait(0.6)
	_check("three missions in a row leave the last bar open",
		not bool(hud.call("is_prompt_collapsed")))

	# --- 9. The HUD hint does not overlap the folded bar ------------------
	hud.call("collapse_prompt")
	await _wait(0.2)
	var hint = hud.get("_hint")
	_check("hint line moved down while the bar is folded",
		hint != null and float(hint.offset_top) > -100.0,
		"expected offset_top near -58, got %s" % str(hint.offset_top if hint else null))
	hud.call("expand_prompt")
	await _wait(0.2)
	_check("hint line moved back up when the bar returns",
		hint != null and float(hint.offset_top) < -200.0)

	_finish()


func _find_child_named(node: Node, wanted: String) -> Node:
	for child in node.get_children():
		if child.name == wanted:
			return child
	return null


## Centre of a `Control`'s on-screen rectangle, or `ZERO` when it is missing or
## not visible. Probing the real rectangle instead of a guessed pixel is what
## makes these checks survive a change to the panel geometry — and it is the
## only honest way to test a tab that is anchored to a corner in a headless run,
## where the visible rect is square and no longer 1280x720.
func _center_of(control: Variant) -> Vector2:
	if control == null or not (control is Control):
		return Vector2.ZERO
	var c := control as Control
	if not c.is_visible_in_tree():
		return Vector2.ZERO
	return c.get_global_rect().get_center()


func _rect_of(control: Variant) -> Rect2:
	if control == null or not (control is Control):
		return Rect2()
	return (control as Control).get_global_rect()


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("FOLD RESULT: %d checks, 0 failures" % _checks)
	else:
		print("FOLD RESULT: %d checks, %d failures" % [_checks, _failures.size()])
		for f in _failures:
			print("  - ", f)
	await Shutdown.and_quit(self, 0 if _failures.is_empty() else 1)
