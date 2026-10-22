class_name CameraRig
extends Node3D
## Third-person camera that follows Jack with smoothing, plus a first-person
## view you can step into by scrolling forward.
##
## The view is a gentle 3/4 angle: high enough that a 7-year-old can read the
## whole play area, low enough that Jack stays a recognisable character.
##
## Looking around is deliberately over-generous, because a child should never
## have to discover "the right button":
##   * **drag with the left mouse button** anywhere on the world orbits the view,
##   * dragging with the right or middle button does the same, for a child who
##     learned it that way,
##   * the arrow-free Q/E keys turn and R/F tilt (trackpad-friendly),
##   * the wheel zooms,
##   * on a gamepad the right stick looks around and LB / RB zoom, so the whole
##     camera is reachable without a mouse at all.
##
## A *click* (press and release without dragging) is never swallowed: it is left
## for `Level` to interpret as "tap that prop", so looking around and picking
## things up can share the same mouse button.
##
## ## First person
##
## Scrolling forward far enough brings the camera *into* Jack's head: the rig
## stops orbiting and sits at eye height, looking wherever the child points it.
## Scrolling back once steps out again — deliberately a single notch, because a
## mode you can only leave by performing the exact reverse of the gesture that
## entered it is a trap for a 7-year-old. The transition is blended over a third
## of a second and `first_person_changed` lets the level hide Jack's model (in
## first person his pumpkin head would fill the screen) and tell the HUD to
## explain how to come back.

## Raised whenever the view crosses between third and first person. `true` means
## the camera is now inside Jack's head.
signal first_person_changed(in_first_person: bool)

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 5.4, 7.2)
@export var follow_speed: float = 5.0
@export var mouse_orbit_speed: float = 0.006
## The wheel may travel all the way to zero: that *is* the first-person mode.
@export var zoom_min: float = 0.0
@export var zoom_max: float = 14.0
## How far the mouse (or finger) must travel, in pixels, before a press counts
## as a drag instead of a click. Below this, the press is passed on untouched.
@export var drag_threshold: float = 6.0
## Height of the camera above Jack's feet when standing inside his head. Slightly
## below the top of the pumpkin so the view matches where his face is drawn.
@export var eye_height: float = 1.28

## Pitch is the camera's elevation: negative values put the camera above Jack.
## The old ceiling of -0.15 made vertical looking feel dead (only ~0.6 rad of
## travel in total), so the range now reaches from almost straight down to just
## above eye level. In third person it stops short of positive angles on purpose:
## those would sink the camera under the ground plane, and a child looking *up*
## through the floor tiles sees the world from inside out. First person is free
## to look up, because there the camera is at eye height and what is above is
## the sky — the moon and the stars are worth looking at.
const PITCH_MIN := -1.32
const PITCH_MAX := -0.08
const PITCH_MAX_FIRST_PERSON := 1.15
## Distance below which a further zoom-in steps into first person, and the
## distance the camera is pushed back out to when leaving it. Leaving jumps
## straight to a framing distance instead of creeping out of Jack's neck: one
## scroll and the child is looking at him again.
const FP_ENTER_DISTANCE := 0.55
const FP_EXIT_DISTANCE := 2.6
## How fast the blend between the two views runs, in "fraction per second".
const FP_BLEND_SPEED := 3.2
## Pitch the view eases towards when stepping inside Jack, so the first thing a
## child sees is the horizon and the props ahead, not the floor at their feet.
const FP_PITCH := -0.14
const PAD_LOOK_SPEED := 1.9
const PAD_ZOOM_SPEED := 3.4
## The orbit camera is never allowed under the ground, whatever the maths say.
const MIN_CAMERA_HEIGHT := 0.6
const MIN_WHEEL_STEP := 0.7


var target: Node3D
var _yaw: float = 0.0
var _pitch: float = -0.55
var _distance: float = 9.0
var _camera: Camera3D
var _shake_time: float = 0.0
var _shake_strength: float = 0.0

## True while a drag is in progress, and false for a plain click. This is what
## lets `Level` treat a click as an interaction without stealing the drag.
var _dragging := false
var _press_position := Vector2.ZERO
var _pressed_button := MOUSE_BUTTON_NONE

var _first_person := false
## 0 = orbit, 1 = first person. Animated towards `_first_person` so the change
## of view reads as a step forward rather than a cut.
var _fp_blend: float = 0.0

## What the settings page allows: 0 = auto (scroll decides), 1 = always first
## person, 2 = never. Mirrors `QuestManager.CAMERA_MODES`.
##
## Enforced here rather than in the input handlers because there are three ways
## into first person (the wheel, the shoulder buttons, `enter_first_person()`),
## and a policy that only covered the wheel would be silently broken on a
## gamepad. Every path ends in `_set_first_person()`, so the check lives there
## and in `_apply_zoom()` — the two places that can raise the mode.
var first_person_policy: int = 0

## Distance the camera keeps from Jack when first person is forbidden. Slightly
## past the entry threshold, so the wheel stops on the near side of it instead
## of sitting exactly on the line where one more notch would trip the mode.
const FP_BLOCKED_DISTANCE := 1.2


## The pitch limits that apply to the *current* mode. Every clamp in the file
## goes through here: hard-coding `PITCH_MAX` in the mouse handler is exactly how
## the first-person view ended up unable to look up at the moon.
func _pitch_limits() -> Vector2:
	return Vector2(PITCH_MIN, PITCH_MAX_FIRST_PERSON if _first_person else PITCH_MAX)


func _ready() -> void:
	_camera = get_node_or_null("Camera3D")
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	_camera.fov = 62.0
	_camera.near = 0.15
	_camera.far = 180.0
	_camera.current = true
	if not target_path.is_empty():
		target = get_node_or_null(target_path)


## Places the camera behind Jack immediately (used after a teleport so the
## view never sweeps across the level).
func snap_to_target() -> void:
	if target == null:
		return
	global_position = target.global_position
	_fp_blend = 1.0 if _first_person else 0.0
	_update_camera(0.0)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var desired := target.global_position
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	_process_gamepad(delta)
	_update_camera(delta)


## Right stick looks, LB / RB zoom.
##
## Read straight from `Input` instead of through actions: the camera is already
## outside `InputMap` (Q/E/R/F are matched by keycode), and adding two more
## rebindable actions would put rows in the settings page that a child has no
## reason to touch. The axes and buttons used here are the ones `project.godot`
## leaves free, so nothing can ever fire twice.
func _process_gamepad(delta: float) -> void:
	var device := _first_pad()
	if device < 0:
		return
	var look := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
	if absf(look.x) > 0.18:
		_yaw -= look.x * PAD_LOOK_SPEED * delta
	if absf(look.y) > 0.18:
		var lim := _pitch_limits()
		_pitch = clampf(_pitch - look.y * PAD_LOOK_SPEED * 0.75 * delta, lim.x, lim.y)
	var zoom := 0.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER):
		zoom -= 1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
		zoom += 1.0
	if not is_zero_approx(zoom):
		_apply_zoom(zoom * PAD_ZOOM_SPEED * delta)


func _first_pad() -> int:
	var devices := Input.get_connected_joypads()
	return int(devices[0]) if not devices.is_empty() else -1


func _update_camera(delta: float) -> void:
	if _camera == null:
		return

	var blend_target := 1.0 if _first_person else 0.0
	if delta <= 0.0:
		_fp_blend = blend_target
	else:
		_fp_blend = move_toward(_fp_blend, blend_target, FP_BLEND_SPEED * delta)
	var smooth := smoothstep(0.0, 1.0, _fp_blend)

	var basis3 := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))

	# --- Orbit pose ---
	# A floor of 0.4 m keeps `looking_at` well-defined: at exactly zero the
	# camera and the point it looks at are the same place and the basis becomes
	# garbage. The blend to first person is what covers the last few centimetres.
	var orbit_pos := global_position + basis3 * Vector3(0, 0, maxf(_distance, 0.4))
	orbit_pos.y = maxf(orbit_pos.y, MIN_CAMERA_HEIGHT)
	var focus := global_position + Vector3(0, 1.1, 0)
	var orbit_basis := Basis.looking_at(focus - orbit_pos, _stable_up(orbit_pos, focus))

	# --- Eye pose ---
	# Taken from Jack himself rather than from the rig: the rig lags behind him
	# by design, and a first-person camera that trails its own head by 20 cm
	# while walking is the classic way to make a child feel sick.
	var eye := global_position + Vector3(0, eye_height, 0)
	if target != null and is_instance_valid(target):
		eye = target.global_position + Vector3(0, eye_height, 0)
	var eye_basis := basis3

	var pos := orbit_pos.lerp(eye, smooth)
	var rot := orbit_basis.get_rotation_quaternion().slerp(eye_basis.get_rotation_quaternion(), smooth)

	if _shake_time > 0.0:
		_shake_time -= delta
		var amount := _shake_strength * (_shake_time / 0.3)
		pos += Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0)

	_camera.global_transform = Transform3D(Basis(rot), pos)


## A "up" vector that never becomes parallel to the view direction.
##
## `Basis.looking_at` returns a degenerate basis (and Godot prints a flood of
## errors) when the direction it is given is parallel to the up vector. The rig
## clamps the camera to a minimum height above the floor, so the moment the
## pitch is pushed to its steepest value the direction can line up with `UP`.
## Falling back to `-Z` for the up axis keeps the basis orthonormal; the camera
## then rolls instead of breaking, and the pitch clamp means the roll only lasts
## for the one frame at the very top of the range.
func _stable_up(from: Vector3, to: Vector3) -> Vector3:
	var dir := (to - from).normalized()
	if absf(dir.dot(Vector3.UP)) > 0.999:
		return Vector3.FORWARD
	return Vector3.UP


## A small celebratory shake when a flame is earned.
func shake(strength: float = 0.18, duration: float = 0.3) -> void:
	_shake_strength = strength
	_shake_time = duration


## True while the child is dragging the view. `Level` uses it to avoid treating
## the end of a drag as a tap on whatever happens to be under the cursor.
func is_dragging() -> bool:
	return _dragging


func is_first_person() -> bool:
	return _first_person


## Steps into Jack's head. Public so the level can restore the view after a
## teleport, and so a future menu button has one obvious entry point.
func enter_first_person() -> void:
	_set_first_person(true)


## Steps back out to the framing camera.
func exit_first_person() -> void:
	_set_first_person(false)


func _set_first_person(value: bool) -> void:
	if _first_person == value:
		return
	# "Never" is a promise to the child, not a hint: the shoulder buttons, the
	# wheel and any future caller all go through here, so refusing at this one
	# point covers every route in. Refusing *entry* only — leaving is always
	# allowed, otherwise flipping the setting while inside Jack would trap the
	# camera in a view it is no longer permitted to use.
	if value and first_person_policy == 2:
		_distance = maxf(_distance, FP_BLOCKED_DISTANCE)
		return
	_first_person = value
	if value:
		_distance = zoom_min
		# Looking at the floor from inside a head is disorienting; ease up until
		# the horizon is on screen, without throwing away a child's own aim.
		_pitch = clampf(_pitch + 0.4, PITCH_MIN, FP_PITCH)
	else:
		_distance = maxf(_distance, FP_EXIT_DISTANCE)
	first_person_changed.emit(value)


## Applies the settings page's choice. Public because the level calls it when
## the setting changes and when a mission starts (a rebuild creates a new rig).
func apply_first_person_policy(mode: int) -> void:
	first_person_policy = clampi(mode, 0, 2)
	if first_person_policy == 1 and not _first_person:
		_set_first_person(true)
	elif first_person_policy == 2 and _first_person:
		_set_first_person(false)


## Zooms by `amount` metres; positive moves the camera away, negative pulls it
## in. The wheel step grows with the distance so the trip from the framing view
## to first person is about nine notches instead of thirty: a trackpad is slow.
func _apply_zoom(amount: float) -> void:
	if _first_person:
		# Any scroll away from Jack leaves first person in one gesture.
		if amount > 0.0:
			_distance = FP_EXIT_DISTANCE + amount
			_set_first_person(false)
		return
	_distance = clampf(_distance + amount, zoom_min, zoom_max)
	# "Never" stops the wheel on the near side of the threshold. Clamping the
	# distance here rather than ignoring the zoom keeps the gesture responsive:
	# the camera keeps coming in and simply stops where the mode would start.
	if first_person_policy == 2:
		_distance = maxf(_distance, FP_BLOCKED_DISTANCE)
		return
	if _distance <= FP_ENTER_DISTANCE:
		_set_first_person(true)


func _wheel_step() -> float:
	return maxf(MIN_WHEEL_STEP, _distance * 0.16)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_apply_zoom(-_wheel_step())
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_apply_zoom(_wheel_step())
			get_viewport().set_input_as_handled()
			return
		# Any of the three "grab" buttons orbits. `MOUSE_BUTTON_MASK_*` is what
		# `InputEventMouseMotion` reports, so all three are accepted there too.
		if button.pressed and button.button_index in [
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_pressed_button = button.button_index
			_press_position = button.position
			_dragging = false
			return
		if not button.pressed and button.button_index == _pressed_button:
			_pressed_button = MOUSE_BUTTON_NONE
			# A press that never moved is a click: another node (the level's
			# raycast) is allowed to see it, so nothing is marked as handled.
			_dragging = false
			return
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _pressed_button == MOUSE_BUTTON_NONE:
			return
		# Only start dragging after the pointer has really moved, so a slightly
		# shaky click on a prop is still a click.
		if not _dragging:
			if motion.position.distance_to(_press_position) < drag_threshold:
				return
			_dragging = true
		_yaw -= motion.relative.x * mouse_orbit_speed
		var lim := _pitch_limits()
		_pitch = clampf(_pitch - motion.relative.y * mouse_orbit_speed, lim.x, lim.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Never steal a gameplay key. The camera is the last thing to look at an
		# event, but it used to grab E for "turn right", which silently ate the
		# interact key: pressing E orbited the camera *and* marked the event as
		# handled, so Level never saw it. Skipping any key that is bound to a
		# gameplay action keeps that from ever happening again — including after
		# the child rebinds something onto Q, R or F in the settings.
		for action in ["interact", "help", "pause", "move_forward", "move_back", "move_left", "move_right"]:
			if event.is_action_pressed(action):
				return
		# Keyboard orbit: Q/E turn, R/F tilt. Handy on a laptop trackpad.
		match event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode:
			KEY_Q:
				_yaw += 0.12
				get_viewport().set_input_as_handled()
			KEY_E:
				_yaw -= 0.12
				get_viewport().set_input_as_handled()
			KEY_R:
				var up_lim := _pitch_limits()
				_pitch = clampf(_pitch + 0.08, up_lim.x, up_lim.y)
				get_viewport().set_input_as_handled()
			KEY_F:
				var down_lim := _pitch_limits()
				_pitch = clampf(_pitch - 0.08, down_lim.x, down_lim.y)
				get_viewport().set_input_as_handled()


## Points the camera at an angle that frames a mission area in front of Jack.
func frame_forward() -> void:
	_yaw = 0.0
	_pitch = -0.55
