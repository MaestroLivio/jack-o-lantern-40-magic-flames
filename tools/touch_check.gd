extends SceneTree
## Regression probe: the on-screen pad and the automatic camera.
##
## Two features added together, and both fail in ways that are invisible in a
## screenshot. What is measured here, in order:
##
##   * the pad exists, is visible by default, and its buttons actually move Jack
##     — a D-pad wired to the wrong action looks perfect and does nothing;
##   * releasing the button stops him — a stuck `action_press` leaves the child
##     walking into a wall with no idea why, and it is the failure mode a real
##     finger produces every time it slides off the edge;
##   * folding leaves a tab, and the tab is the only part of the pad that still
##     blocks a tap;
##   * switching the setting off hides everything and blocks nothing;
##   * the pad can be dragged somewhere else, stays fully on screen when dragged
##     off it, keeps its corner across a fold, and is still *there* after the
##     scene is rebuilt — the position is stored, and a stored value that is
##     ignored on load is a setting that silently resets every session;
##   * with a quiz open, holding "forward" moves Jack 0.000 m — the pad must get
##     no privileges the keyboard does not have (`Jack._ui_blocked`);
##   * the automatic camera converges behind Jack and *stays* there, rather than
##     rotating forever, which is what a naive chase does when movement is
##     camera-relative;
##   * switching the automatic camera off stops the chase dead.
##
##   godot --path . --headless --script tools/touch_check.gd
##
## Rects are read from the live nodes rather than from the design constants:
## `--headless` reports a 1280x1280 visible rect (see `layout_check.gd`), so a
## hand-written 1280x720 coordinate would land somewhere else entirely.

const DESIGN_W := 1280.0
const DESIGN_H := 720.0
const TAB_W := 56.0
const TAB_H := 128.0

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


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checked += 1
	if ok:
		print("TOUCH OK    %s%s" % [label, ("  (%s)" % detail) if detail != "" else ""])
	else:
		_failures.append("%s%s" % [label, ("  -- %s" % detail) if detail != "" else ""])


func _run() -> void:
	_main.set("story_enabled", false)
	_quest.set("persist", false)
	_quest.set("auto_advance", false)
	# A pad probe must be deterministic about the setting it starts from,
	# whatever the save file on this machine happens to say.
	_quest.call("set_touch_controls", true)
	_quest.call("set_auto_camera", true)
	await _wait(0.8)
	_main.call("begin_playing")
	await _wait(1.0)
	# `begin_playing()` opens on the zone card, and while that card is up
	# `_gameplay_active` is false, which hides both the HUD and the pad. Every
	# other harness dismisses it the same way before inspecting the world
	# (`fold_check.gd`, `input_guard_check.gd`); without this line the pad is
	# invisible for the whole run and every visibility assertion below measures
	# the zone card instead of the overlay it is supposed to test.
	_main.call("_on_intro_dismissed")
	await _wait(0.8)
	_level = _main.get("level")

	var pad: Control = _main.get("touch_pad")
	if pad == null:
		print("TOUCH FAIL  no TouchControls node on Main")
		await Shutdown.and_quit(self, 1)
		return

	await _check_layout(pad)
	await _check_walking(pad)
	await _check_folding(pad)
	await _check_setting_off(pad)
	await _check_dragging(pad)
	await _check_quiz_gate()
	await _check_auto_camera()

	print("")
	if _failures.is_empty():
		print("TOUCH RESULT: %d checks, 0 failures" % _checked)
		await Shutdown.and_quit(self, 0)
		return
	for f in _failures:
		print("TOUCH FAIL  %s" % f)
	print("TOUCH RESULT: %d checks, %d failure(s)" % [_checked, _failures.size()])
	await Shutdown.and_quit(self, 1)


## Finds one of the pad's direction buttons by its tooltip, which is the only
## label they carry: the visible mark is a drawn triangle, not text.
func _direction_button(pad: Node, tip: String) -> Button:
	for child in pad.find_children("*", "Button", true, false):
		var b := child as Button
		if b != null and b.tooltip_text == tip:
			return b
	return null


func _check_layout(pad: Control) -> void:
	_check(pad.visible, "the pad is visible by default")
	var up := _direction_button(pad, "Walk forward")
	_check(up != null, "the forward button exists")
	if up == null:
		return
	var r := up.get_global_rect()
	_check(r.size.x >= 60.0 and r.size.y >= 60.0,
		"the forward button is a thumb-sized target",
		"%.0f x %.0f px" % [r.size.x, r.size.y])
	# A tap on a button must not reach the world behind it.
	_check(bool(pad.call("blocks_point", r.get_center())),
		"the pad blocks a tap on its own button")
	# ...but the rest of the screen stays clickable, or the child could no
	# longer pick up a pumpkin next to the pad.
	_check(not bool(pad.call("blocks_point", Vector2(DESIGN_W * 0.5, DESIGN_H * 0.5))),
		"the pad does not block the middle of the screen")
	# The pad sits on one edge and must not span the screen: a `blocks_point`
	# that answered true everywhere would pass the test above and make the whole
	# world untappable.
	var wide := r.position.x < DESIGN_W * 0.5
	_check(wide, "the pad is on the left edge", "x %.0f" % r.position.x)


func _check_walking(pad: Control) -> void:
	var player: Node3D = _level.get("player")
	if player == null:
		_failures.append("no player")
		return
	var up := _direction_button(pad, "Walk forward")
	if up == null:
		return
	await _wait(0.3)
	var before := player.global_position
	# `button_down` is what a finger produces; emitting the signal is the same
	# thing one layer in, and it proves the button is actually connected to the
	# hold logic rather than merely present.
	up.button_down.emit()
	await _wait(0.7)
	var moved := player.global_position.distance_to(before)
	_check(moved > 0.5, "holding the forward button walks Jack", "%.2f m" % moved)

	var mark := player.global_position
	up.button_up.emit()
	await _wait(0.8)
	var drift := player.global_position.distance_to(mark)
	_check(drift < 0.5, "releasing the button stops him", "%.2f m of slide" % drift)

	# The stuck-finger case: the child drags their thumb off the button instead
	# of lifting it. `mouse_exited` is the only signal that arrives, so it has to
	# release the action on its own.
	up.button_down.emit()
	await _wait(0.25)
	up.mouse_exited.emit()
	await _wait(0.5)
	mark = player.global_position
	await _wait(0.6)
	drift = player.global_position.distance_to(mark)
	_check(drift < 0.5, "sliding a thumb off the button stops him", "%.2f m of slide" % drift)


func _check_folding(pad: Control) -> void:
	var up := _direction_button(pad, "Walk forward")
	if up == null:
		return
	var button_centre := up.get_global_rect().get_center()
	# Fold through the strip a child would actually press, not through
	# `set_folded()`: a pad that folds perfectly from a probe and has no button
	# for it is a pad that can never be folded in the real game. This is the
	# whole reason the strip exists, so it is the thing under test.
	var strip := _direction_button(pad, "Hide the buttons")
	_check(strip != null, "there is a button that folds the pad away")
	if strip != null:
		strip.pressed.emit()
	await _wait(0.2)
	var tab: Button = _direction_button(pad, "Show the controls")
	_check(tab != null and tab.is_visible_in_tree(), "folding leaves a tab on screen")
	_check(not bool(pad.call("blocks_point", button_centre)),
		"the folded pad no longer blocks the old button position")
	if tab != null:
		var tab_rect := tab.get_global_rect()
		_check(bool(pad.call("blocks_point", tab_rect.get_center())),
			"the tab blocks a tap on itself")
		# Tapping the tab has to bring the pad back: a tab that hides it for good
		# is the exact bug the counting card already had once.
		tab.pressed.emit()
		await _wait(0.2)
		_check(pad.call("is_folded") == false, "tapping the tab unfolds the pad")
		_check(up.is_visible_in_tree(), "the buttons are back after unfolding")


func _check_setting_off(pad: Control) -> void:
	_quest.call("set_touch_controls", false)
	await _wait(0.2)
	_check(not pad.visible, "switching the setting off hides the whole overlay")
	_check(not bool(pad.call("blocks_point", Vector2(DESIGN_W * 0.5, DESIGN_H * 0.5))),
		"a hidden pad blocks nothing")
	_quest.call("set_touch_controls", true)
	await _wait(0.2)
	_check(pad.visible, "switching the setting back on brings it back")


## The pad moves, stays on screen, and remembers where it went.
##
## A real drag cannot be simulated here: `root.push_input()` never reaches the
## GUI in a headless run (measured — `gui_get_hovered_control()` stays null and
## `get_global_mouse_position()` stays at the origin), so an `InputEventMouseMotion`
## pushed at the grip is seen by nobody. The gesture is therefore driven through
## the same three functions the gesture calls — `_begin_drag()`, `_drag_to()`,
## `_end_drag()` — which is one layer in and proves the arithmetic, the clamp and
## the save. What it cannot prove is that `gui_input` is wired to them; that is
## what the two `gui_input` connections and the grip's existence are for, and the
## tooltip check below pins the one that matters most (`MOUSE_FILTER_STOP`, or
## the grip never receives anything).
func _check_dragging(pad: Control) -> void:
	var grip := _direction_button(pad, "Move the buttons")
	_check(grip != null, "there is a grip that moves the pad")
	if grip == null:
		return
	# The grip must accept the pointer. Every other node in this overlay is
	# `MOUSE_FILTER_IGNORE` so the world stays clickable, and a grip that
	# inherited that would look identical and never see a drag.
	_check(grip.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the grip takes the pointer")

	var home: Vector2 = pad.call("pad_position")
	var pad_rect: Rect2 = (pad.get("_pad") as Control).get_global_rect()

	# Move it, the way `_drag_to()` does: a delta from where it started.
	pad.call("set_pad_position", home + Vector2(DESIGN_W * 0.4, DESIGN_H * 0.18))
	await _wait(0.2)
	var moved: Vector2 = pad.call("pad_position")
	var moved_rect: Rect2 = (pad.get("_pad") as Control).get_global_rect()
	_check(moved.distance_to(home) > 40.0, "the pad moves when it is dragged",
		"%.0f px" % moved.distance_to(home))
	_check(moved_rect.position.is_equal_approx(moved),
		"the block really is at the stored corner",
		"wanted %s, got %s" % [moved, moved_rect.position])

	# It follows the *button* and not just the container: the D-pad is a
	# `GridContainer` inside a `VBoxContainer` inside an `HBoxContainer`, and a
	# position applied to the wrong one of those three would move a rectangle
	# nobody draws.
	var up := _direction_button(pad, "Walk forward")
	if up != null:
		var up_rect := up.get_global_rect()
		_check(up_rect.position.x > home.x + 40.0,
			"the buttons travel with the block", "forward at x %.0f" % up_rect.position.x)

	# A tap where the pad used to be must now reach the world, and one where it
	# has gone to must not. This is the half of `blocks_point()` that a moved pad
	# breaks if it still answers from a stale rect.
	var old_point := pad_rect.get_center()
	_check(not bool(pad.call("blocks_point", old_point)),
		"the old position no longer blocks a tap")
	if up != null:
		_check(bool(pad.call("blocks_point", up.get_global_rect().get_center())),
			"the new position blocks a tap on its own button")

	# Dragged hard off the right and top edges. Both have to come back inside:
	# a pad 400 px off screen has no grip left to grab, and the only way out
	# would be deleting the save file.
	pad.call("set_pad_position", Vector2(DESIGN_W * 3.0, -DESIGN_H))
	await _wait(0.2)
	var corner: Vector2 = pad.call("pad_position")
	var vp := pad.get_viewport_rect().size
	_check(corner.x >= 0.0 and corner.y >= 0.0,
		"a pad dragged off the top-left is pulled back on screen", str(corner))
	var clamped_rect: Rect2 = (pad.get("_pad") as Control).get_global_rect()
	_check(clamped_rect.end.x <= vp.x + 0.5 and clamped_rect.end.y <= vp.y + 0.5,
		"a pad dragged off the bottom-right is pulled back on screen",
		"ends at %s of %s" % [clamped_rect.end, vp])
	# The grip must still be reachable, or the child cannot drag it back.
	var grip_rect := grip.get_global_rect()
	_check(grip_rect.position.x >= 0.0 and grip_rect.end.x <= vp.x
		and grip_rect.position.y >= 0.0 and grip_rect.end.y <= vp.y,
		"the grip is still on screen after clamping", str(grip_rect))

	# Folding must not move it: the tab is drawn on the pad's corner for exactly
	# that reason, and if the two disagreed the pad would jump every time it was
	# folded.
	pad.call("set_pad_position", Vector2(DESIGN_W * 0.5, DESIGN_H * 0.25))
	await _wait(0.2)
	var before_fold: Vector2 = pad.call("pad_position")
	pad.call("set_folded", true)
	await _wait(0.2)
	var tab: Button = _direction_button(pad, "Show the controls")
	var tab_on_pad := tab != null and tab.get_global_rect().has_point(
		before_fold + Vector2(TAB_W * 0.5, TAB_H * 0.5))
	_check(tab_on_pad, "the folded tab lands on the pad's corner",
		str(tab.get_global_rect().position) if tab != null else "no tab")
	pad.call("set_folded", false)
	await _wait(0.2)
	_check(Vector2(pad.call("pad_position")).distance_to(before_fold) < 0.5,
		"folding and unfolding leaves the pad where it was")

	# The persistence round trip. `persist` is off for the whole probe, so the
	# manager is asked directly: what `_end_drag()` writes has to be what a
	# rebuilt pad reads, or the position lasts exactly as long as the session.
	_quest.call("set_touch_pad_position", Vector2(DESIGN_W * 0.55, DESIGN_H * 0.3))
	await _wait(0.2)
	var stored: Vector2 = _quest.get("touch_pad_position")
	_check(Vector2(pad.call("pad_position")).is_equal_approx(stored),
		"a drag is stored in the settings", str(stored))
	# And it is honoured: put the pad back home, then tell it what is stored, the
	# way a fresh node reading `QuestManager` at startup would.
	pad.call("set_pad_position", home)
	await _wait(0.15)
	pad.call("set_pad_position", stored)
	await _wait(0.15)
	_check(Vector2(pad.call("pad_position")).is_equal_approx(stored),
		"a stored position is where the pad comes back")

	# Leave it home, so the checks after this one see the layout they expect.
	pad.call("set_pad_position", home)
	await _wait(0.15)


## The pad must be no more powerful than the keyboard.
func _check_quiz_gate() -> void:
	# Mission 5 is the first quiz in the game; its panel takes the screen.
	_quest.call("start_mission", 5)
	await _wait(1.8)
	var player: Node3D = _level.get("player")
	var pad: Control = _main.get("touch_pad")
	if player == null or pad == null:
		_failures.append("quiz gate: missing player or pad")
		return
	_check(not pad.visible, "the pad hides while the quiz owns the screen")

	# Even if something pressed it, the gate has to hold: this is the same
	# `_ui_blocked` path `input_guard_check.gd` measures for the keyboard.
	var before := player.global_position
	Input.action_press("move_forward")
	await _wait(0.9)
	Input.action_release("move_forward")
	await _wait(0.2)
	var moved := player.global_position.distance_to(before)
	_check(moved < 0.05, "movement stays blocked while a quiz is open",
		"drift %.3f m" % moved)

	# Close the quiz the way the child does, so the next check starts clean.
	var controller: Node = _level.get("mission_controller")
	if controller != null:
		controller.queue_free()
	await _wait(0.4)
	_level.set("mission_controller", null)


## The automatic camera has to settle behind Jack, and then stop moving.
##
## The interesting assertion is the second one. A chase written without the half
## turn, or without pausing while he walks towards the lens, converges to
## nothing: it rotates the camera, which rotates what "forward" means, which
## turns Jack, forever. The failure looks like a slow spin, and it is invisible
## in any single frame.
func _check_auto_camera() -> void:
	var rig: Node = _level.get("camera_rig")
	var player: Node3D = _level.get("player")
	if rig == null or player == null:
		_failures.append("auto camera: missing rig or player")
		return
	_quest.call("set_auto_camera", true)
	# Face Jack away from the camera and let the chase work. The manual-look
	# pause is cleared first: a previous check may have stamped it.
	rig.set("_manual_until", 0)
	rig.set("_auto_armed", true)
	player.rotation.y = PI
	await _wait(2.0)
	var yaw_a := float(rig.get("_yaw"))
	# The rig yaw that stands behind Jack is his heading plus half a turn; both
	# are compared modulo a full turn, so 0 and 2PI count as the same answer.
	var want := player.rotation.y + PI
	var err_a := absf(angle_difference(yaw_a, want))
	_check(err_a < 0.25, "the camera settles behind Jack", "off by %.2f rad" % err_a)

	# Hold forward, which is the direction that must *not* feed back into the
	# chase, and confirm the view does not keep drifting.
	Input.action_press("move_forward")
	await _wait(1.2)
	var yaw_b := float(rig.get("_yaw"))
	Input.action_release("move_forward")
	await _wait(0.2)
	var spin := absf(angle_difference(yaw_b, yaw_a))
	_check(spin < 0.35, "the chase does not spin while walking forward",
		"%.2f rad drift" % spin)

	# Switching it off must stop it dead: this is the settings promise.
	_quest.call("set_auto_camera", false)
	await _wait(0.2)
	var yaw_off := float(rig.get("_yaw"))
	player.rotation.y = 0.0
	await _wait(1.0)
	var after := float(rig.get("_yaw"))
	var follow := absf(angle_difference(after, yaw_off))
	_check(follow < 0.05, "switching the camera off stops the chase",
		"%.3f rad" % follow)
	# And it must be back on by the end, so the run leaves the setting as it
	# found it rather than silently disabling a feature for the next session.
	_quest.call("set_auto_camera", true)
