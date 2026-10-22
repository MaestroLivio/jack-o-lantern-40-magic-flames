class_name LearningProp
extends Area3D
## A 3D object children can walk up to and interact with (click / press E).
##
## The mission spawner (MissionSpawner) creates these for `find`, `count` and
## `sequence` missions. A prop knows its own answer:
##
##   * mission.targets   -> `is_correct == true`, picking it solves the task
##   * mission.distractors or extra copies -> wrong, and an error-free
##     "not this one, try again" response is played
##
## Props never disappear on a wrong answer: they wobble and the child learns
## from the contrast.

signal picked(prop: LearningProp)

## Set by the spawner from the mission dictionary entry.
@export var kind: String = "pumpkin"
@export var color_key: String = "orange"
@export var word: String = ""
@export var is_correct: bool = false
## Optional text floating above the prop ("BIG", "UNDER", "12"...).
@export var label: String = ""
## Visual scale, used by size missions.
@export var prop_scale: float = 1.0
@export var face: String = "happy"
@export var motion: String = "still"
## Number used by counting missions (0 = not a number prop).
@export var number: int = 0
## Anchors used by preposition missions ("on_tree", "under_bench"...).
@export var anchor: String = ""

var _visual: Node3D
var _ring: MeshInstance3D
var _focused := false
var _consumed := false
var _t := 0.0
var _base_y := 0.0
var _home: Vector3
var _label3d: Label3D


func _ready() -> void:
	add_to_group("learning_prop")
	collision_layer = 1 << 2   # Interactables
	collision_mask = 0
	monitoring = false

	_visual = PropFactory.build(kind, color_key, {
		"scale": prop_scale,
		"face": face,
		"label": label,
	})
	add_child(_visual)

	# Collision pickup radius scales with the prop, so tiny spiders are still
	# easy to tap with a small finger.
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = clampf(0.85 * prop_scale, 0.55, 1.6)
	shape.shape = sphere
	shape.position = Vector3(0, 0.8 * prop_scale, 0)
	add_child(shape)

	# A soft gold ring says "I am something you can pick up".
	_ring = PropFactory.add_ring(self, Color("ffd15c"), 0.7 * maxf(prop_scale, 0.8))
	_ring.visible = false
	_base_y = position.y
	_home = position

	# Numbered props (counting missions) show their digit in big type.
	if number > 0:
		var number_label := Label3D.new()
		number_label.text = str(number)
		number_label.font_size = 128
		number_label.pixel_size = 0.008
		number_label.outline_size = 24
		number_label.outline_modulate = Color(0.05, 0.03, 0.09, 0.95)
		number_label.modulate = Color(1, 0.97, 0.85)
		number_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number_label.no_depth_test = true
		number_label.position = Vector3(0, 1.5 * prop_scale, 0)
		number_label.render_priority = 3
		add_child(number_label)
		_label3d = number_label


func _process(delta: float) -> void:
	if _consumed:
		return
	_t += delta
	# Bobbing and spinning make the props feel alive and catch the eye.
	if motion == "slow":
		# The slow cat just breathes in place.
		if _visual != null:
			_visual.position.y = sin(_t * 1.2) * 0.015
		return
	var float_amount := 0.07 if motion == "fast" else 0.05
	if _visual != null:
		_visual.position.y = sin(_t * 1.8) * float_amount
		if motion == "fast":
			_visual.rotation.y += delta * 1.6
	if _ring != null and _ring.visible:
		_ring.scale = Vector3.ONE * (1.0 + sin(_t * 4.0) * 0.07)
	if _label3d != null:
		_label3d.modulate.a = 0.85 + sin(_t * 3.0) * 0.15
	# Occasionally drift the prop toward Jack so "catch the fast cat" works.
	if motion == "fast" and anchor == "wander":
		_home.x += cos(_t * 0.7) * 0.004
		position.x = move_toward(position.x, _home.x, 0.02)


## Called by Jack when he needs to know if this prop can be used right now.
func can_interact() -> bool:
	return not _consumed


## Highlight when Jack is close enough.
func set_focused(value: bool) -> void:
	_focused = value
	if _ring != null:
		_ring.visible = value
	if value:
		scale = Vector3.ONE * 1.06
	else:
		scale = Vector3.ONE


## Jack (or a mouse click) interacted with this prop.
func interact(_by: Node = null) -> void:
	if _consumed:
		return
	picked.emit(self)


## Plays the "you got it" animation and removes the prop from play.
func celebrate_and_free() -> void:
	_consumed = true
	if _visual == null:
		queue_free()
		return
	set_focused(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "position:y", 1.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_visual, "rotation_degrees:y", 360.0, 0.35)
	tween.chain().tween_callback(queue_free)


## Gentle "not this one" wobble. Never an error state — just information.
func wobble() -> void:
	if _consumed or _visual == null:
		return
	var tween := create_tween()
	tween.tween_property(_visual, "rotation_degrees:z", 8.0, 0.07)
	tween.tween_property(_visual, "rotation_degrees:z", -8.0, 0.1)
	tween.tween_property(_visual, "rotation_degrees:z", 0.0, 0.07)
