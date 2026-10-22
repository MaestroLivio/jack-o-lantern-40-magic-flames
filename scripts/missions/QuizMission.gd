class_name QuizMission
extends MissionController
## Missions played entirely through the QuizManager UI (5, 7, 16, 25-31, 40).
##
## The 3D world stays visible (the child keeps a sense of place) while the
## quiz panel takes over input. On the final party mission the quiz runs all
## ten review questions and then hands over to the fireworks.

var _quiz: QuizManager


func _setup() -> void:
	# A small stage prop so the quiz has a physical anchor in the world.
	_build_stage()

	_quiz = QuizManager.new()
	_quiz.name = "QuizManager"
	add_child(_quiz)
	_quiz.finished.connect(_on_quiz_finished)
	# Let the child read the scene for a moment before the quiz slides in.
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	if hud != null:
		hud.set_prompt_visible(false)
		_quiz.start(mission)


func _build_stage() -> void:
	# The NPC's "desk": three plinths showing the shape/colour props.
	var kinds := ["pumpkin", "skeleton", "cauldron"]
	var colors := ["orange", "white", "green"]
	for i in 3:
		var prop := PropFactory.build(kinds[i], colors[i], {"scale": 0.9})
		prop.position = Vector3(-3.0 + i * 3.0, 0, -6.5)
		add_child(prop)


func _on_quiz_finished() -> void:
	if hud != null:
		hud.set_prompt_visible(true)
	if bool(mission.get("final_party", false)):
		# The last mission ends in the fireworks sequence, handled by Main.
		solve()
		return
	solve()


## The quiz reads its first question 0.55 s after the build, so the level must
## not read the task line over the top of it. See
## `MissionController.defers_prompt_speech()` for the measurement.
func defers_prompt_speech() -> bool:
	return true


## The magic magnifying glass while a quiz is open reveals the translation.
##
## It translates the question the child is looking at, not the mission's task
## line: a review quiz asks ten different things, and hearing the generic
## "answer the questions" while the screen says "which word means house?" is
## worse than hearing nothing. `current_italian()` returns "" when no question
## is up, and the mission's own line is the right fallback then.
func reveal_translation() -> void:
	if _quiz == null or not _quiz.visible:
		return
	var italian := _quiz.current_italian()
	if italian.is_empty():
		italian = String(mission.get("prompt_it", ""))
	if italian.is_empty():
		return
	AudioFx.speak(italian, "it")
	QuestManager.feedback.emit(italian, italian, "info")

## The quiz panel owns the screen, so the dialogue box must stay out of its way.
##
## A folded quiz does *not* own it: folding is the child asking to look at the
## world, and the dialogue box is part of that world.
func is_panel_open() -> bool:
	return _quiz != null and _quiz.visible and not _quiz.is_folded()


## True when a screen point lands on the pill a folded quiz leaves behind.
func blocks_fold_point(at: Vector2) -> bool:
	return _quiz != null and _quiz.visible and _quiz.blocks_point(at)


## Brings a folded quiz back so its Italian line can be read.
func unfold_panel() -> void:
	if _quiz != null and _quiz.visible:
		_quiz.unfold()
