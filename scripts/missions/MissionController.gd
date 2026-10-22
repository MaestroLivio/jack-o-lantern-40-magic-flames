class_name MissionController
extends Node3D
## Base class for the nine mission mechanics.
##
## A mission controller is spawned fresh for every mission, owns the props it
## puts in the world, and reports success through `solved`. When the mission
## changes it is freed, so no state can ever leak between missions.
##
## Subclasses implement `_setup()` and call `solve()` when the child succeeds.

signal solved
signal wrong_attempt(message_en: String, message_it: String)

## The mission dictionary this controller is running.
var mission: Dictionary = {}
## The player node (set by the level).
var player: Jack
## The HUD, for prompts and hints.
var hud: Hud
## The NPC who presents the mission.
var npc: NpcCharacter
## Where the mission's props should be placed.
var arena_center: Vector3 = Vector3.ZERO
## True while the mission is being solved, to block duplicate triggers.
var is_resolving := false


func setup(mission_data: Dictionary, jack: Jack, hud_ref: Hud, npc_ref: NpcCharacter) -> void:
	mission = mission_data
	player = jack
	hud = hud_ref
	npc = npc_ref
	arena_center = Vector3.ZERO
	_setup()


## Override in subclasses.
func _setup() -> void:
	pass


## Called when the mission ends (success or level change) so props can clean up.
func cleanup() -> void:
	for child in get_children():
		child.queue_free()


## True when the mechanic has a full-screen panel open (quiz, mirror, counting).
## The level uses it to avoid covering that panel with the dialogue box.
func is_panel_open() -> bool:
	return false


## True when the mechanic reads the mission's task aloud by itself, a moment
## after it is built, because its own panel is the thing on screen.
##
## The level asks this before announcing the prompt: a quiz that starts reading
## question 1 half a second after the build would otherwise cut the task line
## mid-word, and the child hears two voices at once — measured on the first quiz
## of the game, which is exactly the "le quest si accavallano" complaint. The
## task line is not lost: it stays in the bar, one press of the speaker away.
func defers_prompt_speech() -> bool:
	return false


## Makes a finished mission inert *without* removing it from the tree.
##
## The level needs this in the 2.2 s between the flame and the next mission. It
## cannot simply free the controller there: `solved` is emitted from inside the
## controller's own signal, and at that instant the panels it owns may still be
## inside a coroutine (`await get_tree().create_timer(...)`). Freeing a node
## whose coroutine is parked on a timer leaves that coroutine pointing at freed
## memory — measured here as `Invalid access ... 'previously freed'` and, twice,
## as a hard `signal 11` crash of the engine. Nothing is lost by waiting: the
## props are removed at the start of the *next* build, which `Level` already does
## before it creates anything new, so only one mission is ever live.
##
## `is_resolving` is the flag every subclass already checks at the top of its
## tap handlers, so setting it is enough to make a late tap a no-op.
##
## The panels are hidden, not freed, for the same reason: a hidden `Control` is
## inert without being destroyed. Hiding is also what makes the reward readable
## again — the bag card and the quiz used to sit on screen for the whole 2.2 s
## celebration, which is exactly the "the quest is still there while the next
## one starts" the children reported.
func retire() -> void:
	is_resolving = true
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false


# --- Helpers shared by every mechanic --------------------------------------

## Small positive message + sound.
func praise(text_en: String = "Well done!", text_it: String = "Ben fatto!") -> void:
	QuestManager.feedback.emit(text_en, text_it, "success")
	AudioFx.play_sfx("correct")


## Kind correction. Never called "wrong" in front of the child.
func gentle(text_en: String = "Not this one. Try again!", text_it: String = "Non questo. Riprova!") -> void:
	QuestManager.feedback.emit(text_en, text_it, "gentle")
	AudioFx.play_sfx("wrong")
	AudioFx.speak(text_en)
	wrong_attempt.emit(text_en, text_it)


## Builds a prop at `position` inside the arena and wires it to `on_pick`.
func spawn_prop(data: Dictionary, position_3d: Vector3, is_correct: bool, on_pick: Callable) -> LearningProp:
	var prop := LearningProp.new()
	prop.name = "%s_%s" % [String(data.get("kind", "prop")), str(randi() % 1000)]
	prop.kind = String(data.get("kind", "pumpkin"))
	prop.color_key = String(data.get("color", "orange"))
	prop.word = String(data.get("word", ""))
	prop.is_correct = is_correct
	prop.label = String(data.get("label", ""))
	prop.prop_scale = float(data.get("scale", 1.0))
	prop.face = String(data.get("face", "happy"))
	prop.motion = String(data.get("motion", "still"))
	prop.number = int(data.get("number", 0))
	prop.anchor = String(data.get("anchor", ""))
	prop.position = position_3d
	add_child(prop)
	# `on_pick` may be an empty Callable when the mechanic connects later
	# (the sequence pads do their own wiring).
	if on_pick.is_valid():
		prop.picked.connect(on_pick)
	return prop


## Scatters `count` positions over a ring around `center`, never closer than
## `min_distance` to an existing point. Deterministic per call so props never
## land on top of each other.
func scatter_positions(count: int, center: Vector3, radius_min: float = 3.2, radius_max: float = 7.5, min_distance: float = 2.0) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mission.get("id", 1)) * 7919
	var result: Array[Vector3] = []
	var tries := 0
	while result.size() < count and tries < 400:
		tries += 1
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(radius_min, radius_max)
		var candidate := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var ok := true
		for other in result:
			if candidate.distance_to(other) < min_distance:
				ok = false
				break
		if ok:
			result.append(candidate)
	# If the ring was too crowded, fall back to a simple circle.
	while result.size() < count:
		var i := result.size()
		var angle := TAU * float(i) / float(maxi(count, 1))
		result.append(center + Vector3(cos(angle) * radius_max, 0, sin(angle) * radius_max))
	return result


## Puts a "!" bubble / mission icon above a prop.
func mark_prop(prop: LearningProp, icon_text: String) -> void:
	if prop == null:
		return
	var label := Label3D.new()
	label.text = icon_text
	label.font_size = 96
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 1.8, 0)
	label.modulate = UiKit.COL_ACCENT
	prop.add_child(label)


## Completes the mission. Cooldown-guarded so a double tap can't double-fire.
func solve() -> void:
	if is_resolving:
		return
	is_resolving = true
	await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		solved.emit()
