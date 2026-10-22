class_name Jack
extends CharacterBody3D
## Jack-o'-Lantern, the player avatar.
##
## Simple, forgiving WASD movement for small hands: high acceleration, a low
## top speed and no fall damage. The character is built out of primitive
## meshes at runtime so the project needs no rigged models.
##
## An `InteractionArea` (Area3D) watches for nearby `Interactable` objects;
## the nearest one becomes the "focused" object and can be triggered with E.

signal focus_changed(target: Node)

## Movement tuning.
@export var speed: float = 4.4
@export var acceleration: float = 22.0
@export var friction: float = 26.0
@export var turn_speed: float = 10.0
@export var gravity: float = 22.0
## How far Jack can reach to interact with a prop.
@export var reach: float = 2.6

var interaction_area: Area3D
var focused: Node = null
## Set by `Main` from the screen flow: false while the game is not playing at all
## (a story page, the pause menu, the ending). It is the *coarse* gate.
var can_move: bool = true
## Set by `Level` while a mission panel (quiz, mirror) or the dialogue box owns
## the screen. Deliberately a second, independent gate.
##
## The bug this answers: "while I answer the questions with the children, my key
## presses still drive the character around". `can_move` alone could not fix it,
## because it belongs to the screen flow — the quiz opens *inside* `PLAYING`, so
## `can_move` is legitimately true when the panel appears, and `Main` would have
## to be told about every mechanic's panel to lower it. Worse, the two owners
## would then fight: `Main` sets it true on resume, `Level` sets it false while
## the quiz is up, and the last writer of the frame wins.
##
## Splitting the two means neither can undo the other: movement is live only
## when both say so (`can_move and not _ui_blocked`), and the level recomputes
## its half every frame from what is actually on screen.
var _ui_blocked := false

var _body: Node3D
var _head: Node3D
var _lantern_light: OmniLight3D
var _bob_time: float = 0.0
var _nearby: Array[Node] = []
## False while the camera is inside Jack's head. Only the *model* goes away: the
## body node still exists (so the bob, the lantern light and the interaction
## sphere keep running) but stops drawing, otherwise the inside of the pumpkin
## fills the screen in first person.
var _visual_visible := true


func _ready() -> void:
	add_to_group("player")
	# --- Collision ---
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.5
	shape.shape = capsule
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)
	floor_snap_length = 0.3

	# --- Interaction sensor ---
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 1 << 2  # layer 3 = Interactables
	interaction_area.monitorable = false
	var reach_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	reach_shape.shape = sphere
	reach_shape.position = Vector3(0, 0.7, 0)
	interaction_area.add_child(reach_shape)
	add_child(interaction_area)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

	_build_visual()


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "Visual"
	add_child(_body)

	var costume := PropFactory.mat(Color("3a2154"))
	var skin := PropFactory.mat(Color("f28c1e"))

	# Torso: a little purple tunic.
	var torso := MeshInstance3D.new()
	var torso_mesh := CylinderMesh.new()
	torso_mesh.top_radius = 0.3
	torso_mesh.bottom_radius = 0.42
	torso_mesh.height = 0.62
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.62, 0)
	torso.material_override = costume
	_body.add_child(torso)

	# Legs
	var leg_mat := PropFactory.mat(Color("2a1b3d"))
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.11
		leg_mesh.height = 0.34
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.15, 0.2, 0)
		leg.material_override = leg_mat
		_body.add_child(leg)

	# Arms
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.08
		arm_mesh.height = 0.42
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.38, 0.7, 0)
		arm.rotation_degrees = Vector3(0, 0, side * 12)
		arm.material_override = skin
		_body.add_child(arm)

	# Pumpkin head (a sphere with a stem), the character's whole identity.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.18, 0)
	_body.add_child(_head)

	var head_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.36
	sphere.height = 0.68
	sphere.radial_segments = 20
	sphere.rings = 10
	head_mesh.mesh = sphere
	head_mesh.material_override = skin
	_head.add_child(head_mesh)

	# Ribs that make the pumpkin read as a pumpkin.
	for x in [-0.19, 0.0, 0.19]:
		var rib := MeshInstance3D.new()
		var rib_mesh := SphereMesh.new()
		rib_mesh.radius = 0.25
		rib_mesh.height = 0.66
		rib.mesh = rib_mesh
		rib.position = Vector3(x, 0, 0.02)
		rib.scale = Vector3(0.42, 1.0, 1.02)
		rib.material_override = PropFactory.mat(Color("e07b12"))
		_head.add_child(rib)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.035
	stem_mesh.bottom_radius = 0.06
	stem_mesh.height = 0.2
	stem.mesh = stem_mesh
	stem.position = Vector3(0, 0.4, 0)
	stem.rotation_degrees = Vector3(0, 0, 12)
	stem.material_override = PropFactory.mat(Color("4f7a28"))
	_head.add_child(stem)

	# Face: triangles carved into the pumpkin.
	var face_mat := PropFactory.mat(Color("241737"))
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := PrismMesh.new()
		eye_mesh.size = Vector3(0.13, 0.15, 0.05)
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.14, 0.07, 0.33)
		eye.rotation_degrees = Vector3(90, 0, 0)
		eye.material_override = face_mat
		_head.add_child(eye)
	var mouth := MeshInstance3D.new()
	var mouth_mesh := PrismMesh.new()
	mouth_mesh.size = Vector3(0.26, 0.1, 0.05)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0, -0.12, 0.33)
	# PrismMesh is a wedge: its wide edge points one way and its point the other,
	# so the Z rotation decides whether the wedge reads as a smile or a frown.
	# Jack used to carry 180°, i.e. a permanent frown, while every pumpkin in
	# the game defaults to "happy" — so the character the child controls never
	# matched the happy pumpkins they were asked to find. 0° makes him smile,
	# which is the mood of the whole game.
	mouth.rotation_degrees = Vector3(90, 0, 0)
	mouth.material_override = face_mat
	_head.add_child(mouth)

	# The lantern Jack carries: the source of the warm light around him.
	var lantern := Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0.46, 0.62, 0.12)
	_body.add_child(lantern)

	# The light hangs off Jack himself, not off the lantern mesh. It used to be a
	# child of `Lantern`, which meant hiding the model in first person (the whole
	# point of `set_first_person`) also switched off the one light that makes the
	# world readable around him. Parented here it survives, and it no longer bobs
	# with the walk cycle, which was making the whole ground pulse.
	_lantern_light = OmniLight3D.new()
	_lantern_light.name = "LanternLight"
	_lantern_light.light_color = Color("ffc06a")
	_lantern_light.light_energy = 1.6
	_lantern_light.omni_range = 8.0
	_lantern_light.omni_attenuation = 1.4
	_lantern_light.position = lantern.position
	add_child(_lantern_light)

	var cage := MeshInstance3D.new()
	var cage_mesh := BoxMesh.new()
	cage_mesh.size = Vector3(0.2, 0.28, 0.2)
	cage.mesh = cage_mesh
	cage.material_override = PropFactory.mat(Color("5a4632"))
	lantern.add_child(cage)

	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.07
	glow_mesh.height = 0.14
	glow.mesh = glow_mesh
	glow.material_override = PropFactory.mat(Color("ffd98a"), 2.4)
	lantern.add_child(glow)


func _process(delta: float) -> void:
	# Gentle idle/walk bob. Purely cosmetic, so it runs every frame.
	if _body != null:
		var moving := Vector2(velocity.x, velocity.z).length() > 0.4
		_bob_time += delta * (7.0 if moving else 2.2)
		var amplitude := 0.05 if moving else 0.018
		_body.position.y = sin(_bob_time) * amplitude
		_head.rotation_degrees.z = sin(_bob_time * 0.8) * (5.0 if moving else 2.0)
	# Keep the lantern's light steady when the sound is off.
	if _lantern_light != null:
		_lantern_light.light_energy = 1.5 + sin(_bob_time * 0.6) * 0.12


func _physics_process(delta: float) -> void:
	# Gravity (there are no pits, but this keeps Jack on the ground).
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var input_dir := Vector2.ZERO
	if can_move and not _ui_blocked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Movement is camera-relative so "up" always means "away from the camera".
	var direction := Vector3.ZERO
	if input_dir.length() > 0.01:
		var cam := get_viewport().get_camera_3d()
		var basis_forward := Vector3.FORWARD
		var basis_right := Vector3.RIGHT
		if cam != null:
			basis_forward = -cam.global_transform.basis.z
			basis_forward.y = 0.0
			basis_forward = basis_forward.normalized()
			basis_right = cam.global_transform.basis.x
			basis_right.y = 0.0
			basis_right = basis_right.normalized()
		direction = (basis_right * input_dir.x - basis_forward * input_dir.y).normalized()

	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	if direction.length() < 0.01:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()

	# Face the walking direction, smoothly.
	if direction.length() > 0.05:
		var target_yaw := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	# Not while a panel owns the screen: `_update_focus()` runs every frame and
	# would happily re-acquire the prop behind the quiz, putting the "press E"
	# ring back on it half a second after `set_ui_blocked(true)` had cleared it.
	# The comment on `set_ui_blocked()` says that ring is a gameplay affordance;
	# this is the line that makes the claim true for the *whole* quiz, not just
	# for the frame the panel opened on.
	if not _ui_blocked:
		_update_focus()


func _update_focus() -> void:
	var best: Node = null
	var best_distance := INF
	for node in _nearby:
		if not is_instance_valid(node):
			continue
		if node.has_method("can_interact") and not node.can_interact():
			continue
		var d := global_position.distance_to((node as Node3D).global_position)
		if d < best_distance:
			best_distance = d
			best = node
	if best != focused:
		if focused != null and is_instance_valid(focused) and focused.has_method("set_focused"):
			focused.set_focused(false)
		focused = best
		if focused != null and focused.has_method("set_focused"):
			focused.set_focused(true)
		focus_changed.emit(focused)


func _on_area_entered(area: Area3D) -> void:
	if area.has_method("interact") and not _nearby.has(area):
		_nearby.append(area)
		_update_focus()


func _on_area_exited(area: Area3D) -> void:
	_nearby.erase(area)
	_update_focus()


## Called by Main when the interaction key is pressed.
func try_interact() -> bool:
	if _ui_blocked:
		return false
	if focused == null or not is_instance_valid(focused):
		return false
	if focused.has_method("can_interact") and not focused.can_interact():
		return false
	if focused.has_method("interact"):
		focused.interact(self)
		return true
	return false


## Freezes movement (used while a quiz or celebration is on screen).
func set_input_enabled(enabled: bool) -> void:
	can_move = enabled
	if not enabled:
		velocity = Vector3.ZERO


## A mission panel or the dialogue box took the screen (set by `Level`).
##
## Stopping is immediate, not on the next physics frame: the child who presses a
## key and then sees the quiz appear must not glide on for a third of a second
## into the props the quiz is asking about. Kept separate from
## `set_input_enabled()` so the two owners cannot overwrite each other — see the
## comment on `_ui_blocked`.
func set_ui_blocked(blocked: bool) -> void:
	if blocked == _ui_blocked:
		return
	_ui_blocked = blocked
	if blocked:
		velocity = Vector3.ZERO
		# The ring around the focused prop is a *gameplay* affordance: while a
		# quiz is asking the questions, "press E to pick it up" on the prop
		# behind the panel is a hint for an action that is deliberately off.
		if focused != null and is_instance_valid(focused) and focused.has_method("set_focused"):
			focused.set_focused(false)
			focus_changed.emit(null)
		focused = null
	else:
		_update_focus()


## True while a panel is holding the screen. Tools and hints use it instead of
## inferring the state from the flag itself.
func is_ui_blocked() -> bool:
	return _ui_blocked


## Shows or hides Jack's body for the first-person view.
##
## Only visibility is touched: the node stays in the tree so the interaction
## area, the collision capsule and the lantern light keep working, and the
## `_process()` bob keeps its phase instead of restarting on the way back out.
func set_first_person(in_first_person: bool) -> void:
	_visual_visible = not in_first_person
	if _body != null:
		_body.visible = _visual_visible


## Teleports Jack, e.g. when entering a new zone or resetting the grid.
func teleport_to(position_3d: Vector3) -> void:
	global_position = position_3d
	velocity = Vector3.ZERO
