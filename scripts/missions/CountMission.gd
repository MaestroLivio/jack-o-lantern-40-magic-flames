class_name CountMission
extends MissionController
## "Give exactly N" collection missions (9, 10, 23, 24).
##
## The world contains a pile of props: enough of the right kind, plus decoys.
## Each pickup goes into the bag. Handing the bag over compares it with the
## mission's requirements:
##
##   * exact match  -> solved
##   * too many     -> a friendly "Too many! Put some back." and one item is
##                     dropped back into the world in front of Jack
##   * too few      -> "We need more!" and play continues
##
## Nothing is destroyed on a wrong answer, so the child can always reach the
## goal by counting again.
##
## ## Two ways to hand the bag over
##
## **Walking to the character and tapping them** is the main route: the mission
## says "give the skeleton five candies", so the child walks to the skeleton and
## gives. It also means the last step of the mission is a walk through the world
## instead of a button, which is the part of these missions a 7-year-old enjoys.
##
## The **GIVE button** on the bag card stays as a second route, for a child who
## would rather not walk back — and because the QA harness drives it.

var _panel: CountingPanel
## key -> {kind, color, scale, label, count}
var _bag: Dictionary = {}
## Ordered list of picked-up keys, so "put back" is predictable (LIFO).
var _bag_order: Array = []
var _total_required: int = 0


func _setup() -> void:
	var requirements: Array = mission.get("requirements", [])
	for req in requirements:
		_total_required += int(req.get("count", 1))

	# The props in the world: the exact requirement plus extras, so the child
	# has to decide how many to take.
	var all_items: Array = []
	for req in requirements:
		for i in int(req.get("count", 1)):
			all_items.append((req as Dictionary).duplicate())
	for extra in mission.get("extras", []):
		for i in int(extra.get("count", 1)):
			all_items.append((extra as Dictionary).duplicate())

	var positions := scatter_positions(all_items.size(), arena_center, 3.2, 8.5, 1.9)
	for i in all_items.size():
		spawn_prop(all_items[i], positions[i], true, _on_prop_picked)

	_build_panel()


## The bag is built once and left on screen for the whole mission. It used to
## open a modal that had to be dismissed to look around, which is the bug this
## whole design exists to fix: the child could not see the candies they were
## supposed to collect.
func _build_panel() -> void:
	_panel = CountingPanel.new()
	_panel.name = "CountingPanel"
	add_child(_panel)
	_panel.submitted.connect(_on_submitted)
	_panel.start(mission, hud)
	QuestManager.step_changed.emit(0, _total_required)
	if hud != null:
		# The instruction bar stays visible: this mission is played *in* the
		# world, so hiding the task while the child walks around would leave
		# them with nothing to read.
		hud.set_prompt_visible(true)
		hud.hint_set("Pick up the candies, then tap the character.")

	# The character is the delivery point, so they have to be tappable. Their
	# `talked_to` signal was previously emitted and never listened to.
	if npc != null and not npc.talked_to.is_connected(_on_npc_talked_to):
		npc.talked_to.connect(_on_npc_talked_to)


## Stable identity for a requirement: kind + size bucket (+ colour when the
## requirement cares about colour).
func _key_of(kind: String, color_key: String, color_sensitive: bool, scale_value: float) -> String:
	if color_sensitive:
		return "%s|%s|%d" % [kind, color_key, int(round(scale_value * 10.0))]
	return "%s|any|%d" % [kind, int(round(scale_value * 10.0))]


func _requirement_key(req: Dictionary) -> String:
	var color_key := String(req.get("color", ""))
	return _key_of(String(req.get("kind", "")), color_key, not color_key.is_empty(), float(req.get("scale", 1.0)))


## The bag key a prop belongs to. A requirement that names a colour must match
## it; a requirement without a colour still pins the SIZE ("3 small spiders"
## must not accept a big one).
func _key_for_prop(prop: LearningProp) -> String:
	for req in mission.get("requirements", []):
		var requirement: Dictionary = req
		if String(requirement.get("kind", "")) != prop.kind:
			continue
		var required_color := String(requirement.get("color", ""))
		if not required_color.is_empty() and required_color != prop.color_key:
			continue
		if not is_equal_approx(float(requirement.get("scale", 1.0)), prop.prop_scale):
			continue
		return _requirement_key(requirement)
	return _key_of(prop.kind, prop.color_key, true, prop.prop_scale)


## True when this prop is one the mission actually asks for.
func matches_requirement(prop: LearningProp) -> bool:
	for req in mission.get("requirements", []):
		if _requirement_key(req) == _key_for_prop(prop):
			return true
	return false


func _on_prop_picked(prop: LearningProp) -> void:
	if is_resolving or prop == null:
		return
	AudioFx.play_sfx("pickup")
	var key := _key_for_prop(prop)

	if not _bag.has(key):
		_bag[key] = {
			"kind": prop.kind, "color": prop.color_key,
			"scale": prop.prop_scale, "label": prop.label, "count": 0,
		}
	_bag[key]["count"] = int(_bag[key]["count"]) + 1
	_bag_order.append(key)

	if _panel != null:
		_panel.add_item(prop.kind, prop.color_key, prop.prop_scale)
		_panel.clear_hint()
	prop.celebrate_and_free()
	QuestManager.step_changed.emit(_bag_size(), _total_required)


func _bag_size() -> int:
	var total := 0
	for key in _bag:
		total += int(_bag[key]["count"])
	return total


func _on_submitted(_panel_counts: Dictionary) -> void:
	if is_resolving:
		return
	var requirements: Array = mission.get("requirements", [])
	# How much of each thing is over the target, as {bag key -> extra count}.
	# Keys are what identifies an item; the *word* is only what is said out
	# loud, and conflating the two was a dead end (see `_return_surplus()`).
	var surplus: Dictionary = {}
	var surplus_total := 0
	var surplus_word := ""
	for req in requirements:
		var key := _requirement_key(req)
		var extra := int(_bag.get(key, {}).get("count", 0)) - int(req.get("count", 1))
		if extra <= 0:
			continue
		surplus[key] = extra
		surplus_total += extra
		if surplus_word.is_empty():
			surplus_word = String(req.get("word", req.get("kind", "")))

	# Anything not in the requirements is surplus too, however much of it there is.
	var requirement_keys: Array = []
	for req in requirements:
		requirement_keys.append(_requirement_key(req))
	for key in _bag:
		if requirement_keys.has(key):
			continue
		var count := int(_bag[key]["count"])
		surplus[key] = count
		surplus_total += count
		if surplus_word.is_empty():
			surplus_word = String(_bag[key].get("label", _bag[key]["kind"]))

	var missing_word := ""
	for req in requirements:
		if int(_bag.get(_requirement_key(req), {}).get("count", 0)) < int(req.get("count", 1)):
			missing_word = String(req.get("word", req.get("kind", "")))
			break

	if surplus_total > 0:
		# The whole surplus goes back in one correction, not one item per tap.
		# A child who grabbed eleven candies for a five-candy mission used to
		# have to press the character six times and hear "Too many!" six times
		# before the bag agreed with the task; the counting that matters — how
		# many did I take? — already happened while picking them up.
		var message := ("Too many %s! I put it back." % surplus_word.to_upper()) if surplus_total == 1 \
			else "Too many! I put %d back." % surplus_total
		if _panel != null:
			_panel.show_hint(message)
		AudioFx.play_sfx("wrong")
		AudioFx.speak("Too many! I put one back." if surplus_total == 1 else "Too many! I put them back.")
		QuestManager.feedback.emit("Too many!", "Troppi!", "gentle")
		_return_surplus(surplus)
		return

	if not missing_word.is_empty():
		if _panel != null:
			_panel.show_hint("Not enough yet. Keep collecting!")
		AudioFx.play_sfx("soft")
		AudioFx.speak("We need more!")
		QuestManager.feedback.emit("We need more!", "Ne servono altri!", "gentle")
		return

	# Exact match: the pedagogical goal of the mission.
	if _panel != null:
		_panel.clear_hint()
	praise("Exactly right! %d!" % _total_required, "Esatto! %d!" % _total_required)
	AudioFx.speak("Exactly right!")
	solve()


## Puts every item listed in `surplus` back into the world, most recently picked
## up first (which is what `_bag_order` exists for). Returns how many actually
## left the bag, so a mismatch would be visible rather than silent.
##
## The original version compared the requirement's *word* ("orange") with the
## bag entry's *kind* ("candy"), which never matches, so nothing was ever
## removed: a child who had collected a single extra candy was stuck on
## "Too many!" for the rest of the mission with no way to obey. Bag keys are
## now what is compared, because that is the identity the bag itself uses.
func _return_surplus(surplus: Dictionary) -> int:
	var returned := 0
	for i in range(_bag_order.size() - 1, -1, -1):
		var key := String(_bag_order[i])
		var remaining := int(surplus.get(key, 0))
		if remaining <= 0:
			continue
		_bag_order.remove_at(i)
		surplus[key] = remaining - 1
		if _decrement(key):
			returned += 1
	return returned


## Drops one item of `key` back into the bag's world. Returns false when the bag
## had none left, so `_return_surplus()` can count what it actually returned
## instead of trusting its own arithmetic.
func _decrement(key: String) -> bool:
	if not _bag.has(key):
		return false
	var info: Dictionary = _bag[key]
	info["count"] = int(info["count"]) - 1
	if int(info["count"]) <= 0:
		_bag.erase(key)
	if _panel != null:
		_panel.remove_item(String(info["kind"]), String(info["color"]), float(info["scale"]))
	QuestManager.step_changed.emit(_bag_size(), _total_required)

	# Spawn the returned prop next to Jack with a little pop.
	var base := Vector3.ZERO
	if player != null:
		base = player.global_position
	var spot := base + Vector3(randf_range(-1.8, 1.8), 0, randf_range(1.2, 2.6))
	var prop := spawn_prop({
		"kind": info["kind"], "color": info["color"], "scale": info["scale"], "label": info["label"],
	}, spot, true, _on_prop_picked)
	prop.scale = Vector3.ONE * 0.05
	var tween := create_tween()
	tween.tween_property(prop, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioFx.play_sfx("pop")
	return true


## Walking up to the character and tapping them hands the bag over.
##
## This is the route the mission text describes ("give the skeleton five
## candies") and the one a child tries first. It works with the mouse and with
## the interact key alike, because both end up calling `NpcCharacter.interact()`
## and that already emits `talked_to` — a signal nothing used to listen to.
##
## With an empty bag the character does what it does in every other mission:
## says the task again. Turning a hopeful tap into a correction would punish the
## child for trying the right thing at the wrong moment.
func _on_npc_talked_to(_who: NpcCharacter) -> void:
	if is_resolving:
		return
	if _bag_size() <= 0:
		var prompt := String(mission.get("prompt_en", ""))
		AudioFx.speak(prompt)
		if hud != null:
			hud.hint_set(prompt)
		return
	_on_submitted(_bag)


## True while the child is carrying anything the character would take.
##
## `Level` asks this before it writes the hint it shows when the character is in
## reach: "press E to hear the task again" would be a lie here, because the key
## delivers the bag. Keeping the question on the controller means the level never
## has to know which mission ids are counting missions.
func bag_is_ready() -> bool:
	return _bag_size() > 0


## True when a screen point lands on the bag card or its tab. `Level` calls this
## before raycasting the world, so a click on GIVE never also grabs a prop.
func blocks_bag_point(at: Vector2) -> bool:
	return _panel != null and _panel.blocks_point(at)


## Handles the interact key next to the character. Returns false when the key
## should fall back to "hear the task again" — with an empty bag the child is
## asking a question, not delivering anything, so the normal bilingual dialogue
## is the right answer and this mission does not claim the key.
##
## The only thing that decides this is what is in the bag. An earlier version
## also required the card to be on screen, which would have made the interact
## key stop working in exactly the state the child creates by folding the bag
## away to see the world better — a dead end built out of a cosmetic choice.
func offer_bag_to_character() -> bool:
	if _bag_size() <= 0:
		return false
	_on_npc_talked_to(npc)
	return true
