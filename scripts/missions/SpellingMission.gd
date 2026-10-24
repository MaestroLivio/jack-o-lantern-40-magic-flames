class_name SpellingMission
extends MissionController
## "Hear it, spell it" challenges (the ten spelling missions of the bonus set).
##
## Echo says the word, then its letters, and the child rebuilds the word on
## screen by tapping the right letters in order. This is the story's Magic
## Mirror with the hardest step added: the mirror asks the child to *say* a
## sentence, this asks them to hold the word long enough to write it.
##
## A word is never failed. A wrong letter wobbles, says "not this one", and at
## the lower difficulty levels lights the letter that is needed, so the exercise
## always ends with the word spelled out.
##
## The mission dictionary carries `word` (lower case, as it is spoken) and
## `bank` (the letters that are offered, including distractors). Both are
## written out by hand in `GameData`; see `GameData.EXTRA_CHALLENGES`.

var _panel: SpellingPanel


func _setup() -> void:
	_build_scenery()

	_panel = SpellingPanel.new()
	_panel.name = "SpellingPanel"
	add_child(_panel)
	_panel.letter_accepted.connect(_on_letter_accepted)
	_panel.finished.connect(_on_finished)
	# Let the child see the room before the panel slides in, the same beat the
	# quiz and the mirror use.
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	if hud != null:
		hud.set_prompt_visible(false)
		_panel.start(mission)


## A physical anchor for the word in the world, so the exercise is not a page
## floating over nothing. The prop is the word itself whenever it names one
## ("bat", "cat", "hat", "broom"...), and a lantern otherwise; either way its
## colour is decoration, never a clue.
func _build_scenery() -> void:
	var props := {
		"bat": "bat", "cat": "cat", "hat": "hat", "broom": "broom",
		"pumpkin": "pumpkin", "star": "star", "apple": "apple",
		"spider": "spider", "ghost": "ghost", "candle": "candle",
		"lantern": "lantern", "barrel": "barrel", "tree": "tree",
	}
	var kind := String(props.get(String(mission.get("word", "")).to_lower(), "lantern"))
	for i in 3:
		var prop := PropFactory.build(kind, ["orange", "purple", "green"][i], {"scale": 1.0})
		prop.position = Vector3(-3.0 + i * 3.0, 0, -6.5)
		add_child(prop)


func _on_letter_accepted(index: int, total: int) -> void:
	QuestManager.step_changed.emit(index, total)


func _on_finished() -> void:
	if hud != null:
		hud.set_prompt_visible(true)
	praise("%s. Well done!" % String(mission.get("word", "")).to_upper(), "Ben fatto!")
	solve()


## The panel reads the word itself 0.55 s after the build, so the level must not
## read the task line over the top of it. See
## `MissionController.defers_prompt_speech()`.
func defers_prompt_speech() -> bool:
	return true


## True while the panel owns the screen. A folded panel does not: folding is the
## child asking to look at the world.
func is_panel_open() -> bool:
	return _panel != null and _panel.visible and not _panel.is_folded()


## True when a screen point lands on the pill a folded panel leaves behind.
func blocks_fold_point(at: Vector2) -> bool:
	return _panel != null and _panel.visible and _panel.blocks_point(at)


## The magnifier translates the word being spelled, not the mission's task line.
func reveal_translation() -> void:
	if _panel == null or not _panel.visible:
		return
	var italian := _panel.current_italian()
	if italian.is_empty():
		italian = String(mission.get("prompt_it", ""))
	if italian.is_empty():
		return
	AudioFx.speak(italian, "it")
	QuestManager.feedback.emit(italian, italian, "info")


## Brings a folded panel back so its letters can be read again.
func unfold_panel() -> void:
	if _panel != null and _panel.visible:
		_panel.unfold()
