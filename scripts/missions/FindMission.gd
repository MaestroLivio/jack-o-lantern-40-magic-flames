class_name FindMission
extends MissionController
## "Find the X" missions (1, 2, 3, 8, 11, 12, 17-22).
##
## All targets are spawned alongside distractors. Picking a target pops it and
## counts up; picking a distractor makes it wobble and the child hears a kind
## "not this one". The mission ends when every target is collected, so the
## order the child finds them in never matters.

var _remaining: int = 0
var _required: int = 0


func _setup() -> void:
	var targets: Array = mission.get("targets", [])
	var distractors: Array = mission.get("distractors", [])
	_required = targets.size()
	_remaining = _required
	QuestManager.step_changed.emit(0, _required)

	var positions: Array[Vector3] = []
	if _has_anchors(targets + distractors):
		positions = _anchor_positions(targets + distractors)
	else:
		positions = scatter_positions(targets.size() + distractors.size(), arena_center, 3.4, 8.0, 2.4)

	var index := 0
	for t in targets:
		var data: Dictionary = t
		var pos: Vector3 = positions[index]
		index += 1
		var prop := spawn_prop(data, pos, true, _on_target_picked)
		_apply_anchor(prop, data)
	for d in distractors:
		var data: Dictionary = d
		var pos: Vector3 = positions[index]
		index += 1
		var prop := spawn_prop(data, pos, false, _on_distractor_picked)
		_apply_anchor(prop, data)

	if hud != null:
		# Built from the live binding so the hint never says "E" after a rebind.
		hud.hint_set("Walk to a prop, then tap it (click, or press %s)." % Controls.key_label("interact"))


## True when any prop of the mission declares a preposition anchor.
func _has_anchors(props: Array) -> bool:
	for p in props:
		if not String(p.get("anchor", "")).is_empty():
			return true
	return false


## Fixed "stage" positions for the preposition missions: a tree, a bench and
## a barrel stand in a row so ON / UNDER / IN are visually unmistakable.
func _anchor_positions(all_props: Array) -> Array[Vector3]:
	# Typed so the return value can be assigned to an Array[Vector3] (an untyped
	# Array would raise a runtime conversion error).
	var props: Array[Vector3] = []
	var anchors := {
		"on_tree": Vector3(-5.5, 0, -2.0),
		"under_bench": Vector3(0.0, 0, -2.0),
		"in_barrel": Vector3(5.5, 0, -2.0),
		"on_bench": Vector3(0.0, 0, -2.0),
	}
	# Build the landmark scenery once.
	_build_landmarks()
	for p in all_props:
		var anchor := String(p.get("anchor", "under_bench"))
		var base: Vector3 = anchors.get(anchor, Vector3(0, 0, -2))
		# A bat ON the tree sits high; IN the barrel sits low; UNDER the bench
		# sits on the ground beneath the seat.
		match anchor:
			"on_tree":
				props.append(base + Vector3(0, 4.2, 0.35))
			"in_barrel":
				props.append(base + Vector3(0, 0.95, 0))
			"on_bench":
				props.append(base + Vector3(0, 0.85, 0))
			_:
				props.append(base + Vector3(0, 0.05, 0.4))
	return props


## The tree / bench / barrel that a preposition mission refers to.
func _build_landmarks() -> void:
	var bench := PropFactory.build("bench", "brown", {"scale": 1.2})
	bench.position = Vector3(0, 0, -2.0)
	add_child(bench)

	var barrel := PropFactory.build("barrel", "brown", {"scale": 1.1})
	barrel.position = Vector3(5.5, 0, -2.0)
	add_child(barrel)

	var tree := PropFactory.build("tree", "green", {"scale": 1.5})
	tree.position = Vector3(-5.5, 0, -2.0)
	add_child(tree)

	# Floating anchor words make the spatial relation explicit.
	_add_world_word("ON", Vector3(-5.5, 5.4, -2.0))
	_add_world_word("UNDER", Vector3(0, 2.1, -2.0))
	_add_world_word("IN", Vector3(5.5, 2.0, -2.0))


func _add_world_word(text: String, position_3d: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 80
	label.pixel_size = 0.007
	label.outline_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = UiKit.COL_ACCENT
	label.position = position_3d
	add_child(label)


## Moves a prop to the visual spot its anchor describes (bats float).
func _apply_anchor(prop: LearningProp, data: Dictionary) -> void:
	var scale_value := float(data.get("scale", 1.0))
	if prop.kind == "bat":
		prop.position.y += 0.0 if String(data.get("anchor", "")).is_empty() else 0.0
		if scale_value > 1.3:
			prop.scale = Vector3.ONE * 1.3


func _on_target_picked(prop: LearningProp) -> void:
	if is_resolving:
		return
	_remaining -= 1
	var word := prop.word
	prop.celebrate_and_free()
	AudioFx.play_sfx("pickup")
	var found := _required - _remaining
	QuestManager.step_changed.emit(found, _required)
	# Say the word the child just found: that repetition is the lesson.
	if not word.is_empty():
		AudioFx.speak(word)
		QuestManager.feedback.emit(String(word).to_upper() + "!", String(word).to_upper() + "!", "success")
	if _remaining <= 0:
		solve()


func _on_distractor_picked(prop: LearningProp) -> void:
	if is_resolving:
		return
	prop.wobble()
	var word := prop.word if not prop.word.is_empty() else prop.color_key
	# Name the colour so the confusion itself becomes a teaching moment.
	AudioFx.speak("Not this one. Look for %s." % String(mission.get("prompt_en", "")).replace("Find the ", ""))
	QuestManager.feedback.emit("Almost! Try again.", "Quasi! Riprova.", "gentle")
	wrong_attempt.emit("Almost! Try again.", "Quasi! Riprova.")
