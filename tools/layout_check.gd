extends SceneTree
## Layout regression probe.
##
## Builds the real game, opens every overlay panel and asserts two invariants
## that are independent of the window size:
##
##  1. every widget's *minimum* size fits inside the 1280x720 design viewport,
##     so nothing can be too big to ever be shown;
##  2. inside a framed dialog, every visible control sits within the frame.
##
## Together these catch the classic container bug where a wrapping `Label`
## advertises a 1 px minimum width, gets squeezed into a one-pixel column and
## grows a tower hundreds of pixels tall: the panel's minimum size explodes
## (invariant 1) and the cards are pushed outside the frame (invariant 2).
##
##   godot --path . --headless --script tools/layout_check.gd
##
## Exit code is 0 only when every panel passes, so the probe doubles as a
## regression test. Autoload singletons are not available as bare identifiers
## inside a `--script` tool, so they are looked up through the scene tree.
##
## Note on why rects are not compared with the window: `--headless` reports a
## square visible rect (1280x1280), so absolute positions there are meaningless.
## Minimum sizes and parent/child containment are not affected by that.

const DESIGN_W := 1280.0
const DESIGN_H := 720.0
const EPS := 1.5

var _failures: Array[String] = []
var _checked := 0
var _main: Node
var _quest: Node

const Shutdown := preload("res://tools/probe_shutdown.gd")


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	_run()


## Real timers, not frame counts: `--headless` does not run at a fixed rate, so
## counting frames made the probe race the animations it was measuring.
func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	# The story page is measured explicitly below. It is switched off for the
	# rest of the probe so a chapter can never land on top of the mission panel
	# being measured — `Main` guards every story path on this flag.
	_main.set("story_enabled", false)
	# Starting missions from a probe must not overwrite the save file.
	_quest.set("persist", false)
	await _wait(1.2)
	_report("title", _main.get("title_screen"))

	_main.call("begin_playing")
	await _wait(0.7)
	_main.call("_on_intro_dismissed")
	await _wait(0.4)
	_report("zone_intro", _main.get("zone_intro"))

	await _mission(5, "quiz")
	await _mission(33, "mirror")
	await _mission(9, "counting")
	await _mission(32, "tpr")

	await _mission(1, "")
	_report("hud", _main.get("hud"))

	# The bilingual dialogue box is only shown on demand (E near the NPC), so
	# it is opened explicitly here.
	var level: Node = _main.get("level")
	if level != null:
		level.call("_replay_instruction")
		await _wait(0.8)
		_report("dialogue", level.get("dialogue"))

	_main.call("_on_pause")
	await _wait(0.6)
	_report("pause", _main.get("pause_menu"))

	# The controls page is a full-screen modal opened from the pause menu; it
	# replaces the pause panel instead of stacking on top of it.
	_main.call("_on_controls")
	await _wait(0.6)
	_report("controls", _main.get("controls_panel"))
	_main.call("_on_controls_back")
	await _wait(0.3)

	# The volume page, measured at every step of both steppers: the value text
	# grows from "OFF" to "MAX" and the arrows disable at each end, so a wide
	# value at one end is a real failure the middle setting would hide.
	_main.call("_on_sound_settings")
	await _wait(0.5)
	_report("sound", _main.get("sound_panel"))
	# The VIEW row reuses the same panel, so it is measured at all three values
	# for the same reason: "ALWAYS" is the widest name in `CAMERA_MODES`.
	_quest.call("set_camera_mode", 0)
	await _wait(0.15)
	_report("view0", _main.get("sound_panel"))
	_quest.call("set_camera_mode", 1)
	await _wait(0.15)
	_report("view1", _main.get("sound_panel"))
	_quest.call("set_camera_mode", 2)
	await _wait(0.15)
	_report("view2", _main.get("sound_panel"))
	_quest.call("set_camera_mode", 0)
	await _wait(0.15)
	var saved_music: float = _quest.get("music_volume")
	var saved_sfx: float = _quest.get("sfx_volume")
	for step in range(5):
		_quest.call("set_volume", "music", step)
		_quest.call("set_volume", "sfx", step)
		await _wait(0.15)
		_report("soundV%d" % step, _main.get("sound_panel"))
	# Restored to what was there before: the probe must not leave the machine
	# quieter than it found it if someone runs it on the child's copy.
	_quest.set("music_volume", saved_music)
	_quest.set("sfx_volume", saved_sfx)
	# Autoloads are not bare identifiers inside a `--script` tool: same reason
	# `_quest` is looked up through the tree at the top of this file.
	root.get_node("Music").call("apply_settings")
	root.get_node("AudioFx").call("apply_settings")
	_main.call("_on_sound_back")
	await _wait(0.3)
	_main.call("_on_resume")
	await _wait(0.3)

	# Every story page, at every difficulty. The page is the largest in the game
	# and the one whose content changes with the level (keyword chips gain or
	# lose their pictures), so it is the panel most likely to overflow.
	await _story_pages()

	# The HUD and the pause menu also change with the level: at 1 the keyword
	# chips carry pictures, at 3 they disappear and the pause panel still has to
	# fit with its difficulty row.
	for help_level in [1, 2, 3]:
		_quest.call("set_difficulty", help_level)
		await _wait(0.3)
		_report("hudL%d" % help_level, _main.get("hud"))
		_main.call("_on_pause")
		await _wait(0.35)
		_report("pauseL%d" % help_level, _main.get("pause_menu"))
		_main.call("_on_resume")
		await _wait(0.25)
	_quest.call("set_difficulty", 1)

	_main.call("_on_all_completed")
	await _wait(4.5)
	_report("ending", _main.get("ending_screen"))

	# The bonus challenge list. It is the only page with forty buttons on it and
	# the one that gains a three-character "OK · " prefix once a challenge is
	# solved, so it is measured before and after a solve: the prefix is exactly
	# the kind of thing that widens a fixed-size button past the panel edge.
	# Every difficulty is measured too, because the entry text is built from
	# `GameData` and the titles do not depend on the level — a title that only
	# overflows at level 3 would be invisible to a single-level probe.
	var hub: Control = _main.get("challenge_hub")
	if hub == null:
		_fail("hub", "node missing")
	else:
		_main.call("_on_title_challenges")
		await _wait(0.5)
		for help_level in [1, 2, 3]:
			_quest.call("set_difficulty", help_level)
			await _wait(0.2)
			_report("hubL%d" % help_level, hub)
		# One challenge marked solved: the "OK · " prefix is the widest the entry
		# text ever gets, and this is the only way to measure it honestly. No
		# mission is started: `complete_current()` on the bonus branch only edits
		# the tally and emits `extra_completed_changed`, which is what repaints
		# the hub. `persist` is already false, so nothing is written.
		_quest.set("extra_active", true)
		_quest.set("extra_index", 1)
		_quest.call("complete_current")
		await _wait(0.3)
		_report("hubSolved", hub)
		# The second page. Forty entries are paged twenty at a time, and the
		# spelling and meaning titles ("Spell: Pumpkin", "Meanings: The Big
		# Review") are the longest in the list, so measuring only the first page
		# would leave exactly the labels most likely to overflow unmeasured.
		hub.call("_turn_page", 1)
		await _wait(0.3)
		_report("hubPage2", hub)
		hub.call("_turn_page", -1)
		await _wait(0.2)
		_quest.set("extra_active", false)
		_quest.set("extra_index", 0)
		_quest.get("extra_completed").clear()
		_quest.call("set_difficulty", 1)
		hub.call("close")
		await _wait(0.3)
	# The teacher's page: forty mission buttons, measured at every difficulty for
	# the same reason as the hub — the entry text comes from `GameData`, and a
	# title that only overflows at level 3 would be invisible to a single run.
	# It is opened through the pause menu (`_on_teacher`) rather than by calling
	# `open()` directly, so what is measured is the page as a teacher really
	# reaches it, pause menu hidden and all.
	var teacher: Control = _main.get("teacher_menu")
	if teacher == null:
		_fail("teacher", "node missing")
	else:
		for help_level in [1, 2, 3]:
			_quest.call("set_difficulty", help_level)
			_main.call("_on_pause")
			await _wait(0.3)
			_main.call("_on_teacher")
			await _wait(0.4)
			_report("teacherL%d" % help_level, teacher)
			_main.call("_on_teacher_back")
			await _wait(0.2)
			_main.call("_on_resume")
			await _wait(0.2)
		_quest.call("set_difficulty", 1)
	_finish()


## Opens every page of the book once and measures it. Doing all of them (rather
## than one sample) is what catches a beat whose longer title or extra line
## pushes the footer past the panel bottom.
func _story_pages() -> void:
	var screen: Control = _main.get("story_screen")
	if screen == null:
		_fail("story", "node missing")
		return
	var quest: Node = _quest
	var pages: Array = _story_pages_list()
	for i in pages.size():
		var page: Dictionary = pages[i]
		# Each page is measured at the level that renders the most content: the
		# keyword pictures only appear at level 1.
		for help_level in [1, 2, 3]:
			quest.call("set_difficulty", help_level)
			screen.call("open", page)
			await _wait(0.35)
			_report("story%dL%d" % [i + 1, help_level], screen)
			# The Italian teacher note is a second, longer text in the same
			# reserved line: it must fit too or the page re-flows under a finger.
			# Its wording does not depend on the level, so once is enough.
			if help_level == 1:
				screen.call("_toggle_notes")
				await _wait(0.2)
				_report("notes%d" % (i + 1), screen)
				screen.call("_toggle_notes")
			screen.visible = false
	quest.call("set_difficulty", 1)
	if screen.has_signal("finished"):
		screen.visible = false


## `Story.all_pages()` through the scene tree: a `--script` tool cannot use the
## autoload identifier directly.
func _story_pages_list() -> Array:
	var story: Node = root.get_node_or_null("Story")
	if story == null:
		return []
	return story.call("all_pages")


func _mission(id: int, tag: String) -> void:
	_quest.call("start_mission", id)
	await _wait(1.8)
	if tag.is_empty():
		return  # start-only: the caller will report a different node
	_report(tag, _find_tpr_overlay() if tag == "tpr" else _find_panel())


## The quiz / mirror / counting panels are children of the mission controller.
func _find_panel() -> Node:
	var level: Node = _main.get("level")
	if level == null:
		return null
	var ctrl: Node = level.get("mission_controller")
	if ctrl == null:
		return null
	for child in ctrl.get_children():
		if child is Control and (child as Control).visible:
			return child
	return null


## The "Franky Says" mini-game draws its body on a CanvasLayer instead of being
## a child of the controller, so it needs its own lookup.
func _find_tpr_overlay() -> Node:
	var level: Node = _main.get("level")
	if level == null:
		return null
	var ctrl: Node = level.get("mission_controller")
	if ctrl == null:
		return null
	var layer := ctrl.get_node_or_null("TprLayer")
	if layer == null:
		return null
	for child in layer.get_children():
		if child is Control:
			return child
	return null


func _report(tag: String, node: Node) -> void:
	if node == null:
		_fail(tag, "node missing")
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		_fail(tag, "not visible")
		return
	_checked += 1
	var bad: Array[String] = []

	# The frame the child actually sees. HUD-style overlays have no single
	# frame, so they are only checked for minimum sizes.
	var frame := _find_framed_panel(node)
	if frame != null:
		var min_size := frame.get_combined_minimum_size()
		if min_size.x > DESIGN_W + EPS or min_size.y > DESIGN_H + EPS:
			bad.append("%s needs %s but the viewport is %dx%d"
				% [tag, str(min_size), int(DESIGN_W), int(DESIGN_H)])
		_scan_contained(frame, frame.get_global_rect(), bad)

	_check_minimum_sizes(node, bad)

	if bad.is_empty():
		var frame_size := frame.get_global_rect().size if frame != null else Vector2.ZERO
		var frame_min := frame.get_combined_minimum_size() if frame != null else Vector2.ZERO
		print("LAYOUT OK   %-11s frame=%s min=%s" % [tag, str(frame_size), str(frame_min)])
	else:
		for msg in bad:
			print("LAYOUT FAIL ", msg)
			_failures.append(msg)


func _find_framed_panel(node: Node) -> Control:
	# The first PanelContainer that is a direct child of the overlay is the
	# dialog frame; a HUD has none and is handled separately.
	for child in node.get_children():
		if child is PanelContainer and (child as Control).visible:
			return child as Control
	return null


## Invariant 1: a widget that cannot shrink below the screen size can never be
## laid out sensibly, whatever the window is. Allows unlimited height for the
## few controls that are *meant* to scroll or fill (none, currently).
func _check_minimum_sizes(node: Node, bad: Array[String]) -> void:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			var m := c.get_combined_minimum_size()
			if m.x > DESIGN_W + EPS or m.y > DESIGN_H + EPS:
				bad.append("%s wants a minimum of %s, bigger than the %dx%d screen"
					% [String(c.name), str(m), int(DESIGN_W), int(DESIGN_H)])
		_check_minimum_sizes(child, bad)


## Invariant 2: everything drawn inside a dialog frame must be inside it.
## Zero-size controls are layout helpers and are skipped.
func _scan_contained(node: Node, frame: Rect2, bad: Array[String]) -> void:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			var r := c.get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0:
				if r.end.y > frame.end.y + EPS:
					bad.append("%s bottom=%.0f passes the frame bottom %.0f"
						% [String(c.name), r.end.y, frame.end.y])
				if r.end.x > frame.end.x + EPS:
					bad.append("%s right=%.0f passes the frame right %.0f"
						% [String(c.name), r.end.x, frame.end.x])
				if r.position.y < frame.position.y - EPS:
					bad.append("%s top=%.0f is above the frame top %.0f"
						% [String(c.name), r.position.y, frame.position.y])
				if r.position.x < frame.position.x - EPS:
					bad.append("%s left=%.0f is left of the frame %.0f"
						% [String(c.name), r.position.x, frame.position.x])
		_scan_contained(child, frame, bad)


func _fail(tag: String, reason: String) -> void:
	var msg := "%s: %s" % [tag, reason]
	print("LAYOUT FAIL ", msg)
	_failures.append(msg)


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("LAYOUT RESULT: %d panels checked, 0 failures" % _checked)
	else:
		print("LAYOUT RESULT: %d panels checked, %d failures" % [_checked, _failures.size()])
		for f in _failures:
			print("  - ", f)
	await Shutdown.and_quit(self, 0 if _failures.is_empty() else 1)
