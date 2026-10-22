class_name SequenceMission
extends MissionController
## "Step on them in order" missions (6, 13, 14, 15).
##
## Pads are laid out in a single readable arc *between Jack and the zone
## character*. Touching the next pad in the sequence lights it and advances;
## touching a later pad gives a gentle nudge (and the next pad flashes) rather
## than resetting progress — the child keeps everything they have already
## earnt.
##
## A pad can be triggered in three ways, because a 7-year-old should never have
## to guess which one is "right":
##   * walking onto it (a proximity check, so the hint "walk onto the pad" is
##     literally true),
##   * clicking it with the mouse,
##   * pressing the interact key while standing next to it.
##
## The row deliberately stays clear of the zone character. In the first version
## the *middle* pad of the arc landed at z = -5, barely 0.8 m from Mr. Barnaby:
## the leaf was buried inside his body (invisible from the camera) and, because
## he was the nearest interactable, the interact key talked to him instead of
## stepping on the leaf. Missions 6 and 13-15 all use this layout, which is why
## the bug read as "I cannot take the green leaf".

## Centre-to-centre spacing of the pads, and the widest the whole row may get.
## Three pads get a roomy 3.4 m apart; ten pads share the available width.
const PAD_GAP_MIN := 2.3
const PAD_GAP_MAX := 3.4
const PAD_ROW_MAX := 21.0

## z of the middle of the row, relative to the arena centre. Jack spawns at
## z = +4.2 and the zone character stands at z = -4.2, so a row whose middle is
## at z = -0.4 ends up 3.8 m from him: comfortably clear of his 1.5 m area, and
## still 4.4 m in front of Jack, so it is the first thing he sees.
const PAD_ARC_MID_Z := -0.4
## How far the *ends* of the row curl back towards Jack. The curl makes the
## outer pads a little nearer to the camera, so they are easier to read than a
## perfectly straight line of dots would be.
const PAD_ARC_CURL := 1.2

## How close Jack has to be to a pad for it to count as "stepped on", relative
## to the spacing. Below half the spacing, so one step can never trigger two
## pads in a row.
const PAD_TRIGGER_RATIO := 0.44
const PAD_TRIGGER_MIN := 0.85
const PAD_TRIGGER_MAX := 1.25

## Minimum distance between a pad and the zone character, in metres. The pad
## sensor is ~1.3 wide and the character's own area 1.5 wide, so 3.3 keeps a
## clear gap between the two hitboxes.
const PAD_NPC_CLEARANCE := 3.3

## Seconds before a second "not yet" nudge is allowed, so walking across the
## wrong pad cannot spam the voice line.
const NUDGE_COOLDOWN := 1.6

var _order: Array = []
var _step: int = 0
var _pads: Array = []
var _glow: Array = []
## Breathing loop on the pad the child must step on next (killed on cleanup).
var _pulse: Tween
## Counts down after a "find it first" nudge.
var _nudge_guard: float = 0.0
## Walk-over radius of this mission's pads, fixed once in `_setup()` so the
## per-frame proximity check is a single comparison.
var _trigger_radius: float = 1.15
## True once a mistake has been made: at the hardest level this is what puts the
## next pad's glow back on screen, so being wrong is *informative* rather than a
## dead end. Cleared as soon as the child steps on the right pad.
var _revealed: bool = false



func _setup() -> void:
	_order = mission.get("targets", [])
	var numbered := bool(mission.get("numbered", false))
	QuestManager.step_changed.emit(0, _order.size())

	var count := _order.size()
	var gap := _spacing_for(count)
	var half_width := gap * float(count - 1) * 0.5
	_trigger_radius = _walk_radius(gap)

	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		# The middle of the row sits furthest from Jack and the ends curl back
		# towards him, which reads as one arc and keeps every pad in the open.
		var curl := pow(2.0 * t - 1.0, 2.0)
		var pos := arena_center + Vector3(
			lerpf(-half_width, half_width, t),
			0.0,
			PAD_ARC_MID_Z + PAD_ARC_CURL * curl
		)
		pos = _clear_of_npc(pos)
		var data: Dictionary = _order[i].duplicate()
		if numbered:
			# The digit is what the child actually recognises: read it off the
			# prop instead of counting pads from the left.
			data["label"] = str(int(data.get("number", i + 1)))
		var pad := spawn_prop(data, pos, true, Callable())
		pad.motion = "still"
		_make_pad(pad, data, _trigger_radius)
		_pads.append(pad)

	_refresh_glow()
	_start_pulse()
	if hud != null:
		# Built from the live binding: after a rebind the hint must name the key the
		# child actually chose, not a remembered "E".
		hud.hint_set("Step on the glowing pad, tap it, or press %s." % Controls.key_label("interact"))


## Distance between neighbours: as roomy as the row allows, never so tight that
## the tiles (and their triggers) touch.
func _spacing_for(count: int) -> float:
	if count <= 1:
		return PAD_GAP_MAX
	var ideal := PAD_GAP_MAX
	var total := ideal * float(count - 1)
	if total > PAD_ROW_MAX:
		ideal = PAD_ROW_MAX / float(count - 1)
	return clampf(ideal, PAD_GAP_MIN, PAD_GAP_MAX)


## Walk-over radius of a pad, tied to the spacing so a tight row stays usable.
func _walk_radius(gap: float) -> float:
	return clampf(gap * PAD_TRIGGER_RATIO, PAD_TRIGGER_MIN, PAD_TRIGGER_MAX)


## Keeps a pad away from the zone character. Defensive: the row maths already
## leaves room, but a future zone could move the character, and a pad hidden
## inside him is exactly the bug this mission must never have again.
func _clear_of_npc(pos: Vector3) -> Vector3:
	if npc == null or not is_instance_valid(npc):
		return pos
	var offset := pos - npc.global_position
	offset.y = 0.0
	if offset.length() >= PAD_NPC_CLEARANCE:
		return pos
	# Straight out of the character, towards wherever the pad already was.
	if offset.length() < 0.01:
		offset = Vector3(0, 0, 1)
	var pushed := npc.global_position + offset.normalized() * PAD_NPC_CLEARANCE
	pushed.y = pos.y
	return pushed


## Turns a prop into a floor pad with a big walk-over trigger.
func _make_pad(pad: LearningProp, data: Dictionary, radius: float) -> void:
	# Rebuild the collision as a flat cylinder so stepping counts, not bumping.
	for child in pad.get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius + 0.15
	cylinder.height = 1.8
	shape.shape = cylinder
	shape.position = Vector3(0, 0.9, 0)
	pad.add_child(shape)

	# A wide coloured tile on the ground under the prop.
	var tile := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.12
	tile.mesh = cyl
	tile.position = Vector3(0, 0.06, 0)
	tile.material_override = PropFactory.mat(
		PropFactory.color_of(String(data.get("color", "gold"))).darkened(0.15))
	pad.add_child(tile)

	var glow := MeshInstance3D.new()
	var glow_cyl := CylinderMesh.new()
	glow_cyl.top_radius = radius + 0.09
	glow_cyl.bottom_radius = radius + 0.09
	glow_cyl.height = 0.04
	glow.mesh = glow_cyl
	glow.position = Vector3(0, 0.14, 0)
	glow.material_override = PropFactory.glow_mat(Color("ffe08a"), 0.5)
	glow.visible = false
	pad.add_child(glow)
	_glow.append(glow)

	# `picked` already carries the prop, so bind the pad through a lambda instead
	# of `.bind()` (which would append a second argument).
	pad.picked.connect(func(_who: LearningProp) -> void: _on_pad_touched(pad))


## Stepping onto a pad counts.
##
## This is a plain distance check rather than an `Area3D` signal: the pads keep
## `monitoring` off (they are interactables, not sensors), so relying on their
## own collision signals would make the hint "walk onto the pad" a lie. The
## check is cheap — at most ten pads, and only the next one is measured first.
func _process(delta: float) -> void:
	if _nudge_guard > 0.0:
		_nudge_guard -= delta
	if is_resolving or player == null or not is_instance_valid(player):
		return
	if _pads.is_empty():
		return

	# 1. The pad the child needs right now: always checked, so standing on it
	#    (or landing on it while the celebration still plays) counts.
	if _step < _pads.size():
		var next = _pads[_step]
		if next != null and is_instance_valid(next) and _is_under_player(next):
			_on_pad_touched(next)
			return

	# 2. A pad further along the row: answer with a nudge, not silence, so the
	#    child learns that order matters. Rate-limited so walking across it
	#    does not repeat the voice line every frame.
	if _nudge_guard > 0.0:
		return
	for i in range(_step + 1, _pads.size()):
		var pad = _pads[i]
		if pad == null or not is_instance_valid(pad):
			continue
		if _is_under_player(pad):
			_nudge_guard = NUDGE_COOLDOWN
			_on_pad_touched(pad)
			return


## True when Jack is standing on `pad`, measured on the ground plane (his
## height above the tile must not matter, or a small hop would miss it).
func _is_under_player(pad: Node3D) -> bool:
	var pad_pos := pad.global_position
	var flat := Vector2(player.global_position.x - pad_pos.x, player.global_position.z - pad_pos.z)
	return flat.length() <= _trigger_radius


func _on_pad_touched(pad: LearningProp) -> void:
	if is_resolving:
		return
	var index := _pads.find(pad)
	if index < 0:
		return
	if index == _step:
		# Correct next pad.
		_step += 1
		# A new pad to find: at the hardest level the glow goes out again, which
		# is what turns "follow the light" into "remember the order".
		_revealed = false
		AudioFx.play_sfx("step")
		var word := String(_order[index].get("word", ""))
		var number := int(_order[index].get("number", 0))
		if number > 0:
			AudioFx.speak(str(number))
		elif not word.is_empty():
			AudioFx.speak(word)
		QuestManager.step_changed.emit(_step, _order.size())
		var tween := create_tween()
		tween.tween_property(pad, "scale", Vector3.ONE * 1.18, 0.1)
		tween.tween_property(pad, "scale", Vector3.ONE, 0.18)
		pad.celebrate_and_free()
		_pads[index] = null
		_refresh_glow()
		_start_pulse()
		if _step >= _order.size():
			solve()
	elif index > _step:
		# Jumped ahead: point at the right pad instead of punishing. At the
		# hardest level this is also what brings the glow back, so the nudge is
		# never a sentence the child cannot act on.
		_revealed = true
		AudioFx.play_sfx("soft")
		var next_word := String(_order[_step].get("word", ""))
		var next_number := int(_order[_step].get("number", 0))
		var said := str(next_number) if next_number > 0 else next_word
		QuestManager.feedback.emit("First %s!" % said, "Prima %s!" % said, "gentle")
		AudioFx.speak("Find %s first!" % said)
		_refresh_glow(true)
	else:
		# Going back to an already-solved pad is harmless: just a soft beep.
		AudioFx.play_sfx("pop")


## Highlights only the pad that comes next.
##
## At the easiest levels the next pad is always lit. At level 3 (`Hints`) only
## the *first* pad of the order is lit, so the sequence has to be remembered;
## a mistake puts the right pad back on screen (see `_on_pad_touched`), because a
## mission the child cannot finish is worse than a mission they had to think
## about.
func _refresh_glow(flash: bool = false) -> void:
	var visible_now := _shows_glow()
	for i in _glow.size():
		if not is_instance_valid(_glow[i]):
			continue
		_glow[i].visible = i == _step and visible_now
	if not flash or _step >= _glow.size() or not is_instance_valid(_glow[_step]):
		return
	# A nudge always reveals: being told "that one is not next" is worthless if
	# the child still has no way to see which one *is*.
	_glow[_step].visible = true
	# The flash and the breathing pulse both write to the same node's scale, so
	# the pulse is paused for the duration of the flash instead of fighting it.
	_stop_pulse()
	var target: MeshInstance3D = _glow[_step]
	target.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(target, "scale", Vector3.ONE * 1.18, 0.12)
	tween.tween_property(target, "scale", Vector3.ONE, 0.2)
	tween.tween_callback(_start_pulse)


## True when the pad the child needs right now is allowed to be lit.
func _shows_glow() -> bool:
	return Hints.sequence_always_glows() or _step == 0 or _revealed


## Makes the next glow breathe, so the child sees *where* to go without having
## to read the number. Only one pulse runs at a time, and a hidden glow is never
## pulsed: a tween writing to an invisible mesh just burns frames.
func _start_pulse() -> void:
	_stop_pulse()
	if _step >= _glow.size() or not is_instance_valid(_glow[_step]):
		return
	if not _glow[_step].visible:
		return
	var target: MeshInstance3D = _glow[_step]
	target.scale = Vector3.ONE
	_pulse = create_tween().set_loops()
	_pulse.tween_property(target, "scale", Vector3.ONE * 1.12, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(target, "scale", Vector3.ONE, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null


## The mission is over (or the level is changing): stop the pulse before the
## glow meshes are freed, otherwise the tween would keep writing to them.
func cleanup() -> void:
	_stop_pulse()
	super.cleanup()
