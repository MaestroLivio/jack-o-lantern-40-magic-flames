class_name Level
extends Node3D
## Owns the playable world for one zone and runs the active mission.
##
## Responsibilities:
##   * build the environment (WorldBuilder) and place Jack
##   * spawn the right MissionController for `mechanic`
##   * route the magic magnifying glass, pause menu and interact input
##   * play the flame celebration and then ask for the next mission
##
## The level never decides *what* comes next: it reports success to
## QuestManager and lets the autoload drive the sequence.

signal level_ready

## Mechanics -> controller scripts. Resolved with load() so script order in
## the project never matters.
const MECHANICS := {
	"find": "res://scripts/missions/FindMission.gd",
	"sequence": "res://scripts/missions/SequenceMission.gd",
	"count": "res://scripts/missions/CountMission.gd",
	"quiz": "res://scripts/missions/QuizMission.gd",
	"repeat": "res://scripts/missions/RepeatMission.gd",
	"tpr": "res://scripts/missions/TprMission.gd",
	"grid": "res://scripts/missions/GridTrapRoom.gd",
	# The bonus challenges. Both are the story mechanics with the answer taken
	# off the floor, so they live next to their parents in this table rather
	# than in a second registry that would drift from this one.
	"coords": "res://scripts/missions/CoordsMission.gd",
	"find_numbers": "res://scripts/missions/FindNumbersMission.gd",
	# Spelling is bonus-only: no story mission asks the child to write a word,
	# because writing is the one skill the forty flames never test (they read,
	# listen, count and move). Registering it here rather than in a second
	# registry keeps this table the single answer to "what can a mission be?".
	"spell": "res://scripts/missions/SpellingMission.gd",
}

@export var player_scene_path: NodePath
@export var respawn_point: Vector3 = Vector3(0, 1.0, 4.0)

## How far away a prop can be and still be tapped with the mouse. A little more
## than Jack's own `reach` (2.6), because the click already proves the child is
## looking at the thing; the distance gate only exists to teach them to walk.
const CLICK_REACH := 6.0


var player: Jack
var camera_rig: CameraRig
var hud: Hud
## The on-screen D-pad overlay, when the child has it switched on. Owned by
## `Main` (it lives in the UI layer, above the HUD) and handed down here for one
## reason only: a press on the pad must not also be read as a tap on the world
## behind it. `null` when the overlay has not been built yet.
var touch_pad: TouchControls
var mission_controller: MissionController
var npc: NpcCharacter
var current_zone: int = 1
## Bilingual dialogue box used when the child talks to the zone character.
var dialogue: DialogueBox

var _world: Node3D
var _transition: CanvasLayer
var _fireworks: Node3D

## Serialises mission building. Every quest lives behind exactly one of these
## three states, and only the level can move between them — which is the point.
##
## The bug this exists to kill ("le quest si accavallano, partono
## contemporaneamente") had three independent entry points that could all reach
## `start_mission()` within the same second: `advance()` after the 2.2 s flame
## celebration, `_on_level_transition()` after two 0.45 s fades, and
## `Main._begin_mission()` whenever it found `mission_controller == null` — which
## is exactly the window in which a new controller has not been assigned yet.
## Each path then built props, showed a panel and wired a controller, so two
## missions were genuinely running side by side.
##
## With these flags a request that arrives while something is in flight is not
## lost and does not race: it is parked in `_pending_mission` and replayed once
## the level is idle again. Last request wins, because the newest mission is by
## definition the one the game has moved on to.
var _building := false
var _transitioning := false
var _pending_mission: Dictionary = {}

## How far the pointer may move between press and release and still count as a
## tap. The camera rig has its own threshold for *starting* a drag; this one is
## what the level uses to decide whether the press was a tap, because the rig's
## `_dragging` flag is only raised once the pointer has already moved — by which
## time a press-time raycast would have picked the prop up anyway.
const CLICK_DRAG_TOLERANCE := 8.0

## Where the current left-button press started, and whether it is still a
## candidate for a tap.
var _click_start := Vector2.ZERO
var _click_armed := false

## Mirrors `CameraRig.is_first_person()` so the hint line can mention the way out
## without a call into the rig on every focus change.
var _in_first_person := false

## When false the level builds the mission but does not read it aloud yet.
##
## The complaint this answers ("le prime quest sono accavallate"): the level
## used to speak the prompt the instant a controller was built, which on startup
## is *before the title screen has been dismissed* and on a zone change is 0.4 s
## before the zone card starts reading the biome's name. Measured with
## `tools/speech_timeline.gd`: the prompt began at 0.83 s, the card at 1.23 s,
## and `speak()` interrupts by design, so the card cut a sentence that still had
## 2.7 s to run.
##
## Only `Main` may change it, because only `Main` knows whether a card, a story
## page or a menu stands between the child and the world. The level keeps
## working with it false: the bar still fills in, the props are still built, and
## the speaker button replays the line whenever the child likes.
var _gameplay_live := false

## Which build announced its prompt, so the same mission never speaks twice.
##
## A counter and not the mission id: `restart_current()` re-emits
## `mission_started` for the *same* id, and a child who presses "try again"
## expects to hear the task again. The counter also covers the case this fixes,
## where a mission is built behind a story page and only announced minutes later
## — the announcement must happen exactly once, at the right moment.
var _announce_serial := 0
var _announced_serial := -1

## True while the level has taken the task bar away because the dialogue box is
## covering the same strip of screen. See `_refresh_screen_panels()`.
var _dialogue_hid_bar := false


func _ready() -> void:
	_build_world(QuestManager.current_zone)
	_spawn_player()
	_spawn_camera()
	_build_transition_layer()
	_build_dialogue()

	QuestManager.level_transition_requested.connect(_on_level_transition)
	QuestManager.mission_started.connect(_on_mission_started)
	QuestManager.translation_requested.connect(_on_translation_requested)
	# Changing the setting has to take effect on the mission the child is
	# playing, not only on the next one: the pause menu is opened *during* a
	# mission, and "always first person" that only applies tomorrow would look
	# broken.
	QuestManager.camera_mode_changed.connect(_on_camera_mode_changed)
	# Same reasoning for the automatic camera: it is switched off from the
	# pause menu, in the middle of a mission, and the view has to stop chasing
	# Jack the instant the box is ticked — not when the next zone loads.
	QuestManager.auto_camera_changed.connect(_on_auto_camera_changed)

	level_ready.emit()
	_start_current_mission()


# --- Construction ----------------------------------------------------------

func _build_world(zone_id: int) -> void:
	if _world != null:
		_world.queue_free()
	_world = Node3D.new()
	_world.name = "Zone%d" % zone_id
	add_child(_world)
	current_zone = zone_id
	WorldBuilder.build_zone(_world, zone_id)


func _spawn_player() -> void:
	player = Jack.new()
	player.name = "Jack"
	player.position = respawn_point
	add_child(player)
	player.focus_changed.connect(_on_focus_changed)


func _spawn_camera() -> void:
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.target = player
	camera_rig.global_position = player.global_position
	# Jack's model has to disappear when the camera steps into his head, and the
	# HUD has to say how to step back out: the rig owns the mode, but it knows
	# nothing about the character or the overlay, so the level joins the two.
	camera_rig.first_person_changed.connect(_on_first_person_changed)
	# Both settings are applied *before* the first snap. The order mattered: a
	# snap taken first would frame the zone with the default policy and then be
	# instantly overruled, which is a visible flick of the whole world on the
	# first frame of every zone load.
	#
	# The settings page can forbid or force first person; the rig has to know
	# from its very first frame, not after the child opens the pause menu.
	camera_rig.apply_first_person_policy(QuestManager.camera_mode_id())
	# Same for the automatic chase: it decides what "behind Jack" means.
	camera_rig.apply_auto_camera(QuestManager.auto_camera)
	camera_rig.snap_to_target()


func _build_transition_layer() -> void:
	_transition = CanvasLayer.new()
	_transition.name = "TransitionLayer"
	_transition.layer = 50
	add_child(_transition)
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0.04, 0.02, 0.07, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition.add_child(fade)


## The bilingual dialogue box, on its own layer above the HUD (layer 10) but
## below the menus (layer 20), so a quiz can never be covered by it.
func _build_dialogue() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 12
	add_child(layer)
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	dialogue.visible = false
	layer.add_child(dialogue)
	dialogue.advanced.connect(_on_dialogue_advanced)


# --- Mission lifecycle -----------------------------------------------------

func _start_current_mission() -> void:
	# Building is already under way: the request is parked, not repeated. See
	# `_pending_mission` for why replaying is safer than dropping or running it
	# concurrently.
	if _building or _transitioning:
		_pending_mission = QuestManager.current_mission()
		return
	QuestManager.start_mission(QuestManager.current_mission_id)


## Replaces whatever mission is running with `mission`.
##
## Serialised through `_building`: a second call arriving while the first is
## still awaiting a zone fade or a timer parks itself instead of building a
## second controller on top of the first. This is the single funnel every path
## (advance, zone transition, restart, Main's "continue") goes through, so the
## "two quests at once" bug cannot come back through a new caller.
func _on_mission_started(mission: Dictionary) -> void:
	if mission.is_empty():
		return
	if _building or _transitioning:
		_pending_mission = mission
		return
	_building = true
	await _build_mission(mission)
	_building = false
	# The newest request wins, and exactly one replay is enough: `_build_mission`
	# parks again if it is itself interrupted, so a chain of three quick requests
	# still ends on the last one.
	if not _pending_mission.is_empty():
		var queued := _pending_mission
		_pending_mission = {}
		if int(queued.get("id", -1)) != int(mission.get("id", -2)):
			_on_mission_started(queued)


## The actual build. Split out of `_on_mission_started` so the guard above stays
## readable: every `await` here happens while `_building` is true, which is
## exactly what stops a second build from starting mid-fade.
func _build_mission(mission: Dictionary) -> void:
	# Tear the previous mechanic down FIRST, before anything else can be built.
	# It used to be called after the zone fade, and `queue_free()` is deferred to
	# the end of the frame anyway, so for one frame the old controller (panel
	# open, props still interactive, `solved` still connected) lived alongside
	# the new one. `_release_mission` detaches it immediately instead.
	_release_mission()

	var mission_zone := int(mission.get("zone", 1))
	if mission_zone != current_zone:
		# Safety net: the world must match the mission's zone. `_transitioning`
		# is raised for the same window so `_on_level_transition` cannot start a
		# second, parallel fade over the top of this one.
		_transitioning = true
		await _fade_out()
		_build_world(mission_zone)
		player.teleport_to(respawn_point)
		camera_rig.snap_to_target()
		await _fade_in()
		_transitioning = false

	# The zone's character presents the mission.
	npc = _find_npc()
	if npc != null:
		npc.configure(mission)
	if hud != null:
		hud.show_mission(mission, QuestManager.current_zone_info())
		hud.set_prompt_visible(true)

	# Build the mechanic.
	var mechanic := String(mission.get("mechanic", "find"))
	var script_path := String(MECHANICS.get(mechanic, MECHANICS["find"]))
	var script: GDScript = load(script_path)
	if script == null:
		push_error("Level: cannot load mechanic script %s" % script_path)
		return
	mission_controller = script.new()
	mission_controller.name = "Mission_%d" % int(mission.get("id", 0))
	add_child(mission_controller)
	mission_controller.solved.connect(_on_mission_solved)
	mission_controller.setup(mission, player, hud, npc)

	# The instruction is *announced* now only if the world really is the thing
	# on screen. On startup, and on every zone change, it is not: a card or a
	# story page is in front of the child, and speaking over it is the
	# "accavallate" the class reported. `_gameplay_live` is raised by `Main`
	# when the last page closes, and `_announce_mission()` is what speaks then.
	player.set_input_enabled(true)
	_announce_serial += 1
	_announce_mission()


## Speaks the current mission's prompt, at most once per build.
##
## Called from `_build_mission()` and from `set_gameplay_live(true)`. Two
## callers, one guard: a mission built while a story page is open would
## otherwise say nothing at all (the page owns the moment) and then be spoken by
## the page's own handler *and* by the build when the class goes on, which is the
## same double-speech in a different order.
func _announce_mission() -> void:
	if not _gameplay_live:
		return
	if _announced_serial == _announce_serial:
		return
	# A mechanic that takes the screen the moment it is built (the quiz, the
	# mirror, the hands-on panel) speaks for itself: its panel reads the first
	# question or sentence 0.4-0.55 s after the build. Announcing the generic
	# task line and then cutting it half a second later is exactly the "two
	# voices at once" the class reported, and the task line is also the *less*
	# useful of the two — it is still in the bar, one press of the speaker away.
	if mission_controller != null and mission_controller.has_method("defers_prompt_speech") \
			and mission_controller.call("defers_prompt_speech"):
		_announced_serial = _announce_serial
		return
	_announced_serial = _announce_serial
	var mission: Dictionary = QuestManager.current_mission()
	AudioFx.speak(String(mission.get("prompt_en", "")))


## Stops the mission line because a story page is about to take the screen.
##
## The beats (missions 4, 8, 16, 24, 32) open a page *inside* a zone, 0.35 s
## after the mission was built — by which time the prompt is already being read.
## The page then spoke its own title, cutting that sentence mid-word. The level
## cannot know a page is coming (only `Main` owns screens), so `Main` says so and
## the line is read again when the page closes, through the same
## `set_gameplay_live(true)` path a card or a chapter already uses.
func defer_prompt_announcement() -> void:
	AudioFx.stop_speech()
	_announced_serial = -1


## Main tells the level whether the world is the thing on screen.
##
## `live` is true only in `Screen.PLAYING` with no card, no story page, no menu
## and no challenge list in front of it. Raising it announces the mission that
## was built while the child was reading; lowering it also parks the player, so
## a story page that opens mid-zone freezes Jack in the same frame instead of
## letting him walk off behind the text.
func set_gameplay_live(live: bool) -> void:
	_gameplay_live = live
	if player != null and is_instance_valid(player):
		player.set_input_enabled(live)
	# A build that is still running announces its own mission when it finishes
	# (the tail of `_build_mission()`). Speaking here too would read the incoming
	# prompt over the zone fade and then be *cut* by the build's own line — the
	# exact overlap this guard exists to prevent. This is the restart path:
	# `QuestManager.restart_current()` starts the rebuild and `Main` raises the
	# flag one line later, while the first fade is still in flight.
	if live and not _building and not _transitioning:
		_announce_mission()


## True while the level is allowed to read missions aloud and to drive Jack.
func is_gameplay_live() -> bool:
	return _gameplay_live


func _cleanup_mission() -> void:
	if mission_controller != null and is_instance_valid(mission_controller):
		mission_controller.cleanup()
		mission_controller.queue_free()
		mission_controller = null


## Ends the running mission *now*, not at the end of the frame.
##
## `queue_free()` alone leaves the node in the tree until idle time, so a
## panel it owns keeps drawing and its `solved` signal stays connected while the
## next mission is being built — the child could, in principle, tap the finished
## quest's last prop and earn a second flame for a mission that no longer exists.
## `remove_child` plus `queue_free` takes it out of the tree in the same frame.
func _release_mission() -> void:
	if mission_controller == null or not is_instance_valid(mission_controller):
		mission_controller = null
		return
	mission_controller.cleanup()
	if mission_controller.get_parent() == self:
		remove_child(mission_controller)
	mission_controller.queue_free()
	mission_controller = null


func _find_npc() -> NpcCharacter:
	for child in _world.get_children():
		if child is NpcCharacter:
			return child
	return null


func _on_mission_solved() -> void:
	# The child sees the flame first; the quest only advances afterwards.
	#
	# The finished mechanic is *retired* before the celebration instead of
	# freed. Retiring takes its panels off the screen and makes every tap a
	# no-op, which is what the children asked for ("the quest stays up while the
	# next one starts" / the bag card covering the fireworks). Freeing it here is
	# not safe: `solved` is emitted from inside the controller's own signal, and
	# at that instant its panel may still be parked on an `await`. Freeing the
	# node then leaves that coroutine pointing at freed memory — measured as
	# "Invalid access to property 'visible' on a base object of type 'previously
	# freed'" and, twice, as a `signal 11` crash of the engine itself.
	#
	# The memory is reclaimed by `_release_mission()` at the start of the *next*
	# build, 2.2 s later, by which time every celebration timer has resolved.
	if mission_controller != null and is_instance_valid(mission_controller):
		mission_controller.retire()
	# The world stops being the live thing the moment the flame lands: the
	# celebration speaks ("A magic flame! 3") and, 2.2 s later, the next mission
	# is built and speaks too. Leaving `_gameplay_live` raised would let a
	# chapter or a zone card that opens in between be cut by the *next* task
	# line, because `_announce_mission()` only checks this flag.
	_gameplay_live = false
	player.set_input_enabled(false)
	QuestManager.complete_current()
	await _celebrate_flame()


## The Magic Flame reward: a spinning flame rises from Jack's lantern, the
## camera shakes gently and a burst of stars fills the screen.
##
## A bonus challenge gets the same celebration minus the flame: the class has
## not recovered a Magic Flame (the story's forty are untouched), so the toast
## counts challenges instead. Using the flame text here would have told a child
## they had found flame 12 twice.
func _celebrate_flame() -> void:
	# Explicit types: every `QuestManager` member reached through the autoload
	# singleton is Variant to the compiler, so `:=` cannot infer here.
	var is_extra: bool = QuestManager.extra_active
	var flames: int = QuestManager.flames
	if camera_rig != null:
		camera_rig.shake(0.22, 0.35)
	AudioFx.play_sfx("flame")
	if is_extra:
		var done: int = QuestManager.extra_completed.size()
		var total := GameData.EXTRA_CHALLENGES.size()
		QuestManager.feedback.emit("Challenge done! %d / %d" % [done, total],
			"Sfida completata! %d / %d" % [done, total], "success")
		AudioFx.speak("Challenge done! %d" % done)
	else:
		QuestManager.feedback.emit("Magic Flame! %d / 40" % flames, "Fiamma magica! %d / 40" % flames, "success")
		AudioFx.speak("A magic flame! %d" % flames)

	# 3D flame rising above Jack. It must be parented before a global position
	# is assigned, otherwise Godot cannot resolve the transform.
	if player != null:
		var flame := PropFactory.build("flame", "gold", {"scale": 1.0})
		add_child(flame)
		flame.global_position = player.global_position + Vector3(0, 1.2, 0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(flame, "position:y", flame.position.y + 3.2, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(flame, "scale", Vector3.ONE * 2.2, 1.4)
		tween.tween_property(flame, "rotation_degrees:y", 540.0, 1.4)
		tween.chain().tween_callback(flame.queue_free)

	_spawn_star_burst()
	# The flame's own reward line ("A magic flame! 7") is spoken here and is now
	# twice as long, so the celebration holds for twice as long before the next
	# mission is built. A 2.2 s hold cut the sentence off mid-word.
	await get_tree().create_timer(4.4).timeout
	if not is_inside_tree():
		return
	# The QA harness disables auto-advance so it can set up every mission itself.
	if not QuestManager.auto_advance:
		return

	# The celebration spoke (and stopped) on its own; the world is live again, so
	# the mission `advance()` is about to build may read its task through the
	# normal `_announce_mission()` path. Without raising it back the *second*
	# mission of every zone — the ones that never pass through a card or a
	# chapter — would be built in silence, because nothing else calls
	# `set_gameplay_live(true)` when a zone is already on screen.
	_gameplay_live = true
	# Advance to the next mission (or finish the game).
	QuestManager.advance()


## A quick 2D star burst on top of the celebration.
func _spawn_star_burst() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var center := get_viewport().get_visible_rect().size * 0.5
	for i in 14:
		var star := TextureRect.new()
		star.texture = UiKit.icon_texture("star", "yellow", 64)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(48, 48)
		star.size = Vector2(48, 48)
		star.position = center
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(star)
		var angle := TAU * float(i) / 14.0 + randf_range(-0.2, 0.2)
		var target := center + Vector2(cos(angle), sin(angle)) * randf_range(180.0, 420.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(star, "position", target - Vector2(24, 24), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "modulate:a", 0.0, 0.9).set_delay(0.2)
		tween.tween_property(star, "rotation", randf_range(-4.0, 4.0), 0.9)
	_cleanup_after(root.get_parent(), 1.3)


func _cleanup_after(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


# --- Zone transitions ------------------------------------------------------

## A zone change is requested. The fade, the world rebuild and the new props all
## happen inside `_build_mission`, which already does exactly this when the
## incoming mission belongs to a different zone.
##
## This function used to run its *own* fade-out, rebuild and fade-in and then
## call `start_mission()` at the end — a second, parallel copy of the build path.
## With `advance()` also able to fire, a zone change could produce two fades and
## two controllers. Delegating keeps one implementation and one sequence.
func _on_level_transition(_zone_id: int, mission_id: int) -> void:
	player.set_input_enabled(false)
	QuestManager.start_mission(mission_id)


func _fade_out(duration: float = 0.45) -> void:
	var fade: ColorRect = _transition.get_node("Fade")
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float = 0.45) -> void:
	var fade: ColorRect = _transition.get_node("Fade")
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, duration)
	await tween.finished


# --- Input routing ---------------------------------------------------------

func _process(_delta: float) -> void:
	# Re-evaluated every frame rather than pushed from each panel. A quiz opens
	# inside an `await` inside a mission controller, a folded panel silently
	# stops owning the screen, and the dialogue box comes and goes from three
	# different callers — a push-based version needs every one of them to
	# remember to call it, and the one that forgets is the bug the children
	# reported ("I answer the questions and Jack walks off"). Polling the same
	# predicate the mouse guard already uses cannot drift from it.
	_refresh_player_input_gate()
	_refresh_screen_panels()


## Keeps the HUD out from under the dialogue box.
##
## Geometry, measured with `tools/overlap_check.gd` at the design size of
## 1280x720: the task bar occupies y 530..708 and the dialogue box y 384..684
## (both full-width, both anchored to the bottom). The bar is therefore
## completely covered — 154 px of shared height — so showing it under a
## conversation is not "a second panel", it is a panel nobody can read whose
## leftovers peek out at the bottom. That is the "si accavallano" the class
## reported on the first quests, where the prompt is long enough to wrap.
##
## The *folded* box is excluded on purpose: folding it is the child asking to
## look at the world, and the task bar is part of that world.
func _refresh_screen_panels() -> void:
	# The on-screen pad is hidden while a panel owns the screen: the quiz card
	# spans x 160..1120 and the pad sits inside that rectangle on the left edge,
	# so an interactive D-pad over a question is both unusable (movement is
	# blocked anyway) and in the way of the answer the child is reading.
	#
	# Note that this asks `_screen_panel_owns_input()` — the same predicate that
	# parks Jack — and not the `covered` variable below, which deliberately
	# excludes the folded dialogue box. A *folded* box is the child asking to
	# look at the world, and the pad is part of the world.
	if touch_pad != null and is_instance_valid(touch_pad):
		touch_pad.set_screen_covered(_screen_panel_owns_input())

	if hud == null:
		return
	var covered := dialogue != null and dialogue.visible and not dialogue.is_folded()
	if covered == _dialogue_hid_bar:
		return
	_dialogue_hid_bar = covered
	hud.set_dialogue_hidden(covered)


## True while a panel the child is reading owns the screen, so movement and the
## interact key must be off.
##
## The counting bag is deliberately *not* in here: `is_panel_open()` is false for
## it, because "collect five candies" needs the child to keep walking with the
## bag on screen. A *folded* quiz or dialogue does not own the screen either —
## folding is exactly the "let me look at the world" gesture — so those two are
## asked about their own fold state.
func _screen_panel_owns_input() -> bool:
	if mission_controller != null and mission_controller.has_method("is_panel_open") \
			and mission_controller.is_panel_open():
		return true
	if dialogue != null and dialogue.visible and not dialogue.is_folded():
		return true
	return false


## Tells Jack whether a panel is holding the screen. Cheap enough to run every
## frame; `Jack.set_ui_blocked()` returns at once when nothing changed.
func _refresh_player_input_gate() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_ui_blocked(_screen_panel_owns_input())


func _unhandled_input(event: InputEvent) -> void:
	# `interact_alt` is Enter / Space: the same "tap it" the mouse click and the
	# interact key do, bound separately so rebinding never removes it.
	if event.is_action_pressed("interact") or event.is_action_pressed("interact_alt"):
		# A quiz, the mirror or the dialogue box is the thing on screen: the key
		# belongs to it, not to the prop standing behind it. Without this the
		# child answering a question with Space also walked Jack into the
		# pumpkins *and* picked one up, which is a wrong answer caused by the
		# keyboard rather than by the child.
		#
		# Enter and Space are also the keys a browser or a projector remote sends
		# as "click", so this guard is what keeps the panel's own focused button
		# (OK, an answer card) the only thing those keys can press.
		if _screen_panel_owns_input():
			return
		if player != null:
			if not player.try_interact():
				# Nothing in reach: talk to the NPC if one is nearby.
				if npc != null and player.global_position.distance_to(npc.global_position) < 4.5:
					_offer_to_character()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("help"):
		_on_translation_requested()
		get_viewport().set_input_as_handled()


## Clicking a prop in the world also interacts with it (mouse-friendly).
##
## A press that the camera used to drag the view must not also "pick up" whatever
## happened to be under the cursor when the drag ended. Asking the rig is not
## enough on its own: `Level._input` runs *before* the rig has seen the motion
## that crosses its drag threshold, so a press that is already a drag still
## arrives here once and would interact. The press is therefore only acted on if
## the pointer has stayed within `CLICK_DRAG_TOLERANCE` up to the moment of the
## release — a tap is a press and release in the same place, whatever the rig
## later decides.
##
## The reach check is deliberately generous (6 m, roughly "one or two steps
## away") because a child aims at the picture, not at a collision sphere, and
## being told "too far" for a prop that fills the screen feels arbitrary.
## Walking up to things is still taught by the hint line and by the ring that
## appears around the focused prop.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			# Only remember the press: the prop is picked on release, so a drag
			# that starts here never triggers it.
			_click_start = click.position
			_click_armed = true
			return
		if not _click_armed:
			return
		_click_armed = false
		if click.position.distance_to(_click_start) > CLICK_DRAG_TOLERANCE:
			return  # that was a drag across the view, not a tap
		_try_click(click.position)
		return
	# A new drag in progress cancels the pending tap outright.
	if event is InputEventMouseMotion and _click_armed:
		var motion: InputEventMouseMotion = event
		if motion.position.distance_to(_click_start) > CLICK_DRAG_TOLERANCE:
			_click_armed = false


## Raycasts from a screen point and interacts with the prop under it, if it is
## close enough to Jack.
func _try_click(at: Vector2) -> void:
	if camera_rig != null and camera_rig.is_dragging():
		return
	# A quiz / counting panel owns the screen: a tap on its cards must never
	# also pick up whatever 3D prop happens to sit behind it.
	#
	# A *folded* panel does not own the screen, but the pill it left behind
	# still does: the tap that brings the question back must not also collect
	# the pumpkin standing under the pill.
	if _click_hits_fold_tab(at):
		return
	if mission_controller != null and mission_controller.has_method("is_panel_open") \
			and mission_controller.is_panel_open():
		return
	# The counting bag is *not* a modal — the world stays playable around it —
	# so `is_panel_open()` is false while it is up. It still cannot let a click
	# through: input reaches `_input` before the GUI consumes it, so a tap on
	# GIVE would also raycast the 3D scene behind the button and collect a candy
	# hidden under it.
	if _click_hits_bag(at):
		return
	# The folded TASK tab is a small button in the corner the world is still
	# visible behind. A tap on it must unfold the bar and nothing else.
	if hud != null and hud.blocks_point(at):
		return
	# Exactly the same problem for the on-screen D-pad: it sits over the world,
	# and a touch on "forward" would otherwise also raycast whatever pumpkin is
	# drawn behind the button. `blocks_point()` is false when the pad is hidden,
	# so a child with the overlay switched off pays nothing for this check.
	if touch_pad != null and is_instance_valid(touch_pad) and touch_pad.blocks_point(at):
		return
	# The dialogue box ignores the mouse (so its scrim never blocks the world
	# outside it), which means a click on its OK button reaches this function
	# too. Without this guard, reading the task again while standing next to a
	# prop would also pick that prop up behind the box.
	#
	# A *folded* box is not in the way any more, so it must not keep swallowing
	# taps: folding it is exactly the "let me look at the world" gesture, and a
	# child who folded it and then taps a pumpkin expects the pumpkin. The pill
	# it leaves behind is the one part that must still take the tap.
	if dialogue != null and dialogue.visible and not dialogue.is_folded():
		return
	if dialogue != null and dialogue.blocks_point(at):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(at)
	var to := from + cam.project_ray_normal(at) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 << 2
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider == null or not collider.has_method("interact"):
		return
	var target_node := collider as Node3D
	# Only within reach, so children learn to walk up to things.
	if player == null or player.global_position.distance_to(target_node.global_position) > CLICK_REACH:
		if hud != null:
			hud.hint_set("Walk closer, then tap it!")
		return
	collider.interact(player)
	get_viewport().set_input_as_handled()


## True when a screen point lands on the counting bag card or its tab.
##
## Duck-typed on purpose: `Level` knows about missions, not about the bag, and a
## mechanic that has no bag simply does not have the method.
func _click_hits_bag(at: Vector2) -> bool:
	if mission_controller == null or not mission_controller.has_method("blocks_bag_point"):
		return false
	return bool(mission_controller.call("blocks_bag_point", at))


## True when `at` lands on an overlay the mechanic has left behind after folding
## its own panel (the QUIZ and MIRROR pills).
##
## Separate from `_click_hits_bag` because a folded panel stops owning the
## screen while its pill still owns a corner: the check has to run even though
## `is_panel_open()` is now false.
func _click_hits_fold_tab(at: Vector2) -> bool:
	if mission_controller == null or not mission_controller.has_method("blocks_fold_point"):
		return false
	return bool(mission_controller.call("blocks_fold_point", at))


func _on_translation_requested() -> void:
	var mission: Dictionary = QuestManager.current_mission()
	var italian := String(mission.get("prompt_it", ""))
	# Asking for the translation is also asking to *see* the sentence: a folded
	# bar has to come back, or the Italian line would be revealed inside a
	# panel the child cannot see. The `H` key must never appear to do nothing.
	if hud != null:
		hud.expand_prompt()
	if italian.is_empty():
		return
	if hud != null:
		var visible_now := hud.is_translation_visible()
		hud.reveal_translation(not visible_now)
		if not visible_now:
			AudioFx.speak(italian, "it")
			QuestManager.feedback.emit(italian, italian, "info")
	# The quiz mechanic shows its own translation.
	if mission_controller != null and mission_controller.has_method("reveal_translation"):
		mission_controller.reveal_translation()
	# A folded panel has to come back for its Italian line to be read: asking
	# for the translation is asking to see the words.
	if mission_controller != null and mission_controller.has_method("unfold_panel"):
		mission_controller.call("unfold_panel")


## Pressing the interact key near the zone character opens the bilingual dialogue
## box, so the task can be heard again in English and read in Italian on demand.
##
## Except during a "give me five candies" mission, where standing next to the
## character and pressing the key is how the bag is delivered. There, the
## character takes the bag if it has something in it, and repeats the task if
## not, so the key never does the wrong thing and is never dead.
func _offer_to_character() -> void:
	if mission_controller != null and mission_controller.has_method("offer_bag_to_character"):
		if bool(mission_controller.call("offer_bag_to_character")):
			return
	_replay_instruction()


## Pressing the interact key near the zone character opens the bilingual dialogue
## box, so the task can be heard again in English and read in Italian on demand.
func _replay_instruction() -> void:
	var mission: Dictionary = QuestManager.current_mission()
	var speaker := String(mission.get("npc", "Jack"))
	if dialogue == null:
		return
	# A quiz or panel already owns the screen: a soft toast is less intrusive.
	if mission_controller != null and mission_controller.has_method("is_panel_open") \
			and mission_controller.is_panel_open():
		AudioFx.speak(String(mission.get("prompt_en", "")))
		if hud != null:
			hud.show_feedback(String(mission.get("prompt_en", "")), "", "info")
		return
	dialogue.visible = true
	dialogue.show_line(speaker, String(mission.get("prompt_en", "")), String(mission.get("prompt_it", "")))


func _on_dialogue_advanced() -> void:
	if hud != null:
		hud.hint_set(_interact_hint())


## The hint line names whatever key is actually bound, so it never lies after a
## child has changed the controls.
func _interact_hint() -> String:
	return "Walk to a prop, then tap it (click, or press %s)." % Controls.key_label("interact")


func _on_focus_changed(target: Node) -> void:
	if hud == null:
		return
	if target == null:
		hud.hint_set(_with_view_mode(_interact_hint()))
	elif target is NpcCharacter:
		# With a bag in hand the character is a delivery point, not a librarian:
		# telling the child "press E to hear the task again" while E actually
		# hands the candies over is the kind of hint that teaches the wrong
		# behaviour. `bag_is_ready` is duck-typed so the level never needs to
		# know which missions count.
		if _bag_is_ready():
			var who: NpcCharacter = target
			hud.hint_set(_with_view_mode("Tap %s, or press %s, to give the bag." % [who.name_en, Controls.key_label("interact")]))
		else:
			hud.hint_set(_with_view_mode("Press %s to hear the task again." % Controls.key_label("interact")))
	else:
		hud.hint_set(_with_view_mode("Press %s, or click it, to pick it up." % Controls.key_label("interact")))


## Appends the way back out of first person to whatever hint is showing.
##
## The hint line is rewritten constantly — every time Jack walks near a prop —
## so a "how to come back" message that is only shown at the moment of entering
## first person survives less than a second. Appending it here means the way out
## is on screen for as long as the child is in the mode, on every hint, without
## the level having to remember which hint it last set.
func _with_view_mode(base: String) -> String:
	if not _in_first_person:
		return base
	# "Never" cannot be in first person at all, and "always" cannot leave, so
	# only the default mode gets a gesture hint. Telling a child to scroll back
	# when the rig is going to refuse is worse than saying nothing.
	if QuestManager.camera_mode_id() != 0:
		return base
	return "%s   ·   Scroll back to see Jack (or %s on the pad)" % [base, "RB"]


## The camera stepped into or out of Jack's head.
func _on_first_person_changed(in_first_person: bool) -> void:
	_in_first_person = in_first_person
	if player != null:
		player.set_first_person(in_first_person)
	if hud == null:
		return
	if in_first_person:
		# With the view locked on ("ALWAYS") the way out would be a lie: the
		# rig refuses to leave. The hint then names the setting instead of a
		# gesture that does nothing.
		if QuestManager.camera_mode_id() == 1:
			hud.hint_set("You are Jack! The teacher can change the view in PAUSE.")
		else:
			hud.hint_set("You are Jack! Scroll back to see him again.")
	else:
		hud.hint_set(_interact_hint())


## The view setting changed on the settings page.
func _on_camera_mode_changed(mode: int) -> void:
	if camera_rig != null:
		camera_rig.apply_first_person_policy(mode)


## The automatic-camera switch changed on the settings page.
##
## Only the rig is told. Nothing else has to know: from the outside an automatic
## chase and a child dragging the view are the same thing, so every other system
## (camera-relative movement, the click raycast, first-person policy) is already
## correct for both.
func _on_auto_camera_changed(enabled: bool) -> void:
	if camera_rig != null:
		camera_rig.apply_auto_camera(enabled)


## True when the current mission is holding something the character would take.
func _bag_is_ready() -> bool:
	if mission_controller == null or not mission_controller.has_method("bag_is_ready"):
		return false
	return bool(mission_controller.call("bag_is_ready"))


# --- Public helpers used by Main ------------------------------------------

## Celebrates the whole game: fireworks, dancing friends, final message.
func play_finale() -> void:
	player.set_input_enabled(false)
	await get_tree().create_timer(0.5).timeout
	_spawn_fireworks()
	AudioFx.play_sfx("win")
	AudioFx.speak("Happy Halloween! You lit all forty flames. Well done, Jack!")
	QuestManager.feedback.emit("HAPPY HALLOWEEN!", "BUON HALLOWEEN!", "success")
	# The closing sentence is the longest in the game and is now spoken at half
	# speed: the three firework bursts are spaced to land *around* it rather than
	# over the top of it, which is why these waits doubled with the recordings.
	await get_tree().create_timer(2.4).timeout
	_spawn_fireworks()
	await get_tree().create_timer(2.4).timeout
	_spawn_fireworks()


## Simple, cheerful fireworks: expanding glowing spheres and 2D stars.
func _spawn_fireworks() -> void:
	AudioFx.play_sfx("magic")
	var palette: Array[Color] = [Color("ffc94d"), Color("f28cc0"), Color("7ee06a"), Color("4fa3d9"), Color("ff8a5c")]
	for i in 5:
		var color: Color = palette[i]
		var origin := Vector3(randf_range(-14.0, 14.0), randf_range(8.0, 14.0), randf_range(-14.0, 6.0))
		var burst := Node3D.new()
		burst.position = origin
		add_child(burst)
		for j in 12:
			var spark := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.32
			spark.mesh = sphere
			spark.material_override = PropFactory.mat(color, 3.0)
			var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			spark.position = Vector3.ZERO
			burst.add_child(spark)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(spark, "position", dir * randf_range(3.5, 6.0), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(spark, "scale", Vector3.ONE * 0.05, 1.1)
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 6.0
		light.omni_range = 14.0
		burst.add_child(light)
		var tween_light := create_tween()
		tween_light.tween_property(light, "light_energy", 0.0, 1.2)
		await get_tree().create_timer(1.4).timeout
		if is_instance_valid(burst):
			burst.queue_free()
