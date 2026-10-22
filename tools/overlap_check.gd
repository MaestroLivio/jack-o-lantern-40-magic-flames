extends SceneTree
## Regression probe: do two "read it with the children" panels overlap?
##
## The complaint this answers: "the first quests feel piled up". The geometry
## says why -- every one of these is anchored independently and none of them
## knows about the others:
##
##   HUD task bar     bottom, y 530..708 on a 720 screen  (offset_top -190)
##   DialogueBox      centred bottom, y 384..684
##   QuizManager      centred, y  80..640
##   RepeatPanel      centred, y  90..630
##
## So the task bar sits *under* the dialogue box and *under* the bottom of the
## quiz, and a child reading with the teacher sees two frames of text on top of
## each other. This probe opens each combination in the real game and reports
## the overlapping area, in px², for every pair that is visible at once.
##
##   godot --path . --headless --script tools/overlap_check.gd
##
## Two things it learned the hard way:
##
##  * A panel that exists but is *hidden* is not an overlay. `get_global_rect()`
##    on a hidden Control still returns a rect, and the first version of this
##    probe reported a 0x0 "hud prompt bar" next to a quiz -- a phantom overlay
##    that made every run look clean. Everything is filtered through
##    `is_visible_in_tree()` here, so a suppressed bar cannot be counted.
##  * The zone card owns the screen at startup: the HUD is deliberately hidden
##    while it is up (`Main._set_gameplay_active(false)`), so a probe that starts
##    a mission without dismissing the card measures an empty screen. The card
##    is closed first, the same way the class closes it.
##
## Exit code 0 only when no two visible panels overlap by more than TOLERANCE_PX2.

const TOLERANCE_PX2 := 400.0

var _failures: Array[String] = []
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
	# The zone card is up and the HUD is hidden behind it on purpose. Read it
	# for a moment, then press GO ON like a child: only then does the world (and
	# the task bar) exist.
	await _wait(0.8)
	var card: Node = root.get_node_or_null("/root/Main/MenuLayer/ZoneIntro")
	if card is CanvasItem and (card as CanvasItem).visible:
		card.call("close")
	await _wait(1.4)
	_level = _main.get("level")

	# --- A. mission start: HUD bar + task, nothing else -------------------
	_quest.call("start_mission", 1)
	await _wait(1.4)
	_report("mission 1 start")

	# --- B. the dialogue box, opened the way a child opens it -------------
	_level.call("_replay_instruction")
	await _wait(0.6)
	_report("mission 1 + dialogue box")
	# The bar must be *gone* here, not merely behind the box: this is the
	# "si accavallano" the class reported, and hiding is the fix.
	_expect_no_bar("mission 1 + dialogue box")
	_level.get("dialogue").call("hide_box")
	await _wait(0.8)
	_report("after the dialogue closed")
	_expect_bar("after the dialogue closed")

	# --- C. a quiz panel, sampled *during* its intro delay and after ------
	_quest.call("start_mission", 5)
	await _wait(0.30)
	_report("quiz, 0.3 s after start (intro delay still running)")
	await _wait(1.6)
	_report("quiz, settled")
	_expect_no_bar("quiz, settled")

	# --- D. the listen-and-repeat panel, same two samples -----------------
	_quest.call("start_mission", 4)
	await _wait(0.30)
	_report("repeat, 0.3 s after start")
	await _wait(1.6)
	_report("repeat, settled")
	_expect_no_bar("repeat, settled")

	print("")
	if _failures.is_empty():
		print("OVERLAP RESULT: no overlapping panels, 4 bar checks")
		await Shutdown.and_quit(self, 0)
		return
	for f in _failures:
		print("OVERLAP FAIL  %s" % f)
	print("OVERLAP RESULT: %d failure(s)" % _failures.size())
	await Shutdown.and_quit(self, 1)


## Snapshot of every overlay that is *actually on screen* right now, with its
## rect. Hidden controls are excluded, not reported as empty rects.
func _snapshot() -> Dictionary:
	var found := {}
	# Duck-typed on purpose: a `--script` tool does not resolve project class
	# names (`Hud`, `QuizManager`) as identifiers, so asking the node tree is the
	# only way to find these overlays from here. `layout_check.gd` does the same.
	var hud: Control = _main.get("hud") as Control
	if hud != null and hud.visible:
		_add(found, "hud prompt bar", _member_rect(hud, "_prompt_panel"))
		_add(found, "hud task tab", _member_rect(hud, "_prompt_tab"))
		_add(found, "hud top bar", _rect_of(_find_child_named(hud, "PanelContainer")))
	var dialogue: Control = _level.get("dialogue")
	if dialogue != null and dialogue.visible and not bool(dialogue.call("is_folded")):
		_add(found, "dialogue box", _member_rect(dialogue, "_panel"))
	var controller: Node = _level.get("mission_controller")
	if controller != null:
		for child in controller.get_children():
			if child is Control and (child as Control).is_visible_in_tree():
				var name := String(child.name)
				if name.contains("Quiz"):
					_add(found, "quiz panel", _member_rect(child, "_panel"))
				elif name.contains("Repeat"):
					_add(found, "repeat panel", _member_rect(child, "_panel"))
	return found


func _add(found: Dictionary, key: String, rect: Rect2) -> void:
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		found[key] = rect


func _member_rect(owner_node: Node, member: String) -> Rect2:
	return _rect_of(owner_node.get(member) as Control)


func _rect_of(target: Control) -> Rect2:
	if target == null or not target.is_visible_in_tree():
		return Rect2()
	return target.get_global_rect()


func _find_child_named(node: Node, cls: String) -> Control:
	for child in node.get_children():
		if child is Control and child.get_class() == cls:
			return child as Control
	return null


## The bar must be invisible: a panel owns the screen.
func _expect_no_bar(label: String) -> void:
	var hud: Control = _main.get("hud") as Control
	if hud == null:
		_failures.append("%s: no HUD to check" % label)
		return
	var bar := _member_rect(hud, "_prompt_panel")
	if bar.size.x > 1.0 and bar.size.y > 1.0:
		_failures.append("%s: the task bar is still on screen (%.0f x %.0f px) under a panel"
			% [label, bar.size.x, bar.size.y])


## The bar must be back: the panel that owned the screen has closed.
func _expect_bar(label: String) -> void:
	var hud: Control = _main.get("hud") as Control
	if hud == null:
		_failures.append("%s: no HUD to check" % label)
		return
	var bar := _member_rect(hud, "_prompt_panel")
	if bar.size.x <= 1.0 or bar.size.y <= 1.0:
		_failures.append("%s: the task bar did not come back after the panel closed" % label)


func _report(label: String) -> void:
	var snap := _snapshot()
	var names: Array = snap.keys()
	names.sort()
	print("")
	print("--- %s: %d overlay(s) visible" % [label, names.size()])
	for n in names:
		var r: Rect2 = snap[n]
		print("    %-18s x %.0f..%.0f  y %.0f..%.0f" % [n, r.position.x, r.end.x, r.position.y, r.end.y])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = snap[names[i]]
			var b: Rect2 = snap[names[j]]
			var inter := a.intersection(b)
			var area := inter.size.x * inter.size.y
			if area > TOLERANCE_PX2:
				_failures.append("%s: '%s' and '%s' overlap by %.0f px2"
					% [label, names[i], names[j], area])
