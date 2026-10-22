class_name FindNumbersMission
extends MissionController
## "Find these numbers" challenges (the ten number missions of the bonus set).
##
## The story's number missions ask for one thing at a time ("find five", "count
## three spiders"). These ask for a *set*: "find 3, 7 and 12", in any order. That
## is a harder skill than it looks, and it is the reason the set is spelled out
## instead of being shown:
##
##   * the child has to hold three number words in their head at once, which is
##     working memory, not reading;
##   * the words are heard as English ("three, seven, twelve") and read as
##     digits on the props, so the mapping between the two has to be known —
##     exactly the pre-A1 objective;
##   * order is *explicitly* free. A child who finds 12 first must not be told
##     they did it wrong, because they did not.
##
## Nothing here can fail. A number that is not in the set wobbles, says "not
## this one", and stays on the board: the child can keep tapping until the set
## is complete, and wrong picks cost nothing but a moment.
##
## The set is complete when every wanted number has been picked once. Duplicates
## on the board are allowed and are *distractors*: two 7s, one of which is the
## one you need, is a legitimate trap that costs the child nothing to explore.

## Numbers still to be found, in the order they were asked for.
var _remaining: Array[int] = []
## Numbers already found, so a second copy of the same digit cannot count twice.
var _found: Array[int] = []


func _setup() -> void:
	_remaining.clear()
	_found.clear()
	for value in mission.get("numbers", []):
		var number := int(value)
		if not _remaining.has(number):
			_remaining.append(number)

	var pool: Array = mission.get("pool", [])
	if pool.is_empty():
		# A mission that forgot its pool still has to be playable: the wanted
		# numbers plus the next three, which is the smallest board that is not
		# a give-away.
		for number in _remaining:
			pool.append(number)
			pool.append(number + 3)
	QuestManager.step_changed.emit(0, _remaining.size())

	var positions := scatter_positions(pool.size(), arena_center, 3.4, 8.0, 2.2)
	# Colours cycle so the board looks like a pile of Halloween props rather
	# than a row of identical cards. The colour is decoration: only the digit
	# decides what is correct, and the mission text never mentions colour.
	var colors := ["orange", "purple", "green", "blue", "yellow", "pink"]
	for i in pool.size():
		var number := int(pool[i])
		spawn_prop({
			"kind": "pumpkin",
			"color": colors[i % colors.size()],
			"number": number,
			"scale": 1.0,
		}, positions[i], _remaining.has(number), _on_number_picked)

	if hud != null:
		# "Any order" is in the hint as well as the prompt because it is the one
		# rule a child can get wrong without realising: they may otherwise
		# assume the first number named has to be found first and stop trying
		# when the nearest prop is a different one.
		#
		# The digits themselves are only repeated at the lower levels: the task
		# in the prompt bar already names them, and reprinting "3, 7, 12" at
		# level 3 would hand back exactly the matching shortcut that level is
		# meant to remove. The rule ("any order") stays at every level, because
		# it is an instruction, not a hint.
		hud.hint_set(_hint_line())


## The one-line hint, at whatever detail the difficulty setting allows.
func _hint_line() -> String:
	if not Hints.number_hints_show_digits():
		return "Tap the numbers — any order!"
	return "Tap the numbers %s — any order!" % _spoken_list()


## "3, 7 and 12" with the last joined by "and", the way the prompt says it, so
## the hint and the spoken instruction cannot drift apart.
##
## Built with a loop instead of `String.join()`: the natural argument here is an
## `Array[String]`, and `join()` wants a `PackedStringArray`. The conversion is
## not guaranteed, and a failed conversion in a hint is a runtime error in the
## middle of a mission — the most expensive possible place to discover it.
func _spoken_list() -> String:
	var text := ""
	for i in _remaining.size():
		if i > 0:
			text += " and " if i == _remaining.size() - 1 else ", "
		text += str(_remaining[i])
	return text


func _on_number_picked(prop: LearningProp) -> void:
	if is_resolving or prop == null:
		return
	var number := prop.number
	# `_found` is checked as well as `_remaining`: a board may carry the same
	# digit twice, and the second copy must behave like any other distractor
	# once the number has been collected.
	if _remaining.has(number) and not _found.has(number):
		_found.append(number)
		_remaining.erase(number)
		prop.celebrate_and_free()
		AudioFx.play_sfx("pickup")
		QuestManager.step_changed.emit(_found.size(), _found.size() + _remaining.size())
		QuestManager.feedback.emit(str(number), str(number), "success")
		# Say the digit in English: the repetition is the lesson, and it also
		# confirms to the child which number they just claimed.
		AudioFx.speak(str(number))
		if hud != null and not _remaining.is_empty():
			hud.hint_set("Good! Now tap %s." % _spoken_list())
		if _remaining.is_empty():
			praise("You found them all!", "Li hai trovati tutti!")
			solve()
		return

	# Not in the set: gentle, never destructive. The prop stays where it is.
	prop.wobble()
	AudioFx.play_sfx("wrong")
	var message := "Not this one."
	if not _remaining.is_empty():
		message = "Not this one. Look for %s." % _spoken_list()
	AudioFx.speak(message)
	QuestManager.feedback.emit("Not this one. Try again!", "Non questo. Riprova!", "gentle")
	wrong_attempt.emit(message, "Non questo. Riprova.")


## True when `number` is still wanted. Used by the QA harness, which walks the
## board the way a child would; keeping the test on this method means the test
## cannot disagree with the mission about what counts.
func is_wanted(number: int) -> bool:
	return _remaining.has(number) and not _found.has(number)
