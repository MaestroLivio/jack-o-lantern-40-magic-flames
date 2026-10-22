class_name NpcCharacter
extends Area3D
## A friendly character who presents the mission and reacts to it.
##
## The NPC is a "living" quest board: walking up and pressing E (or clicking)
## replays the instruction. Characters never block the player and never say
## "no" — a wrong tap makes them say a gentle "not that one, try again".

signal talked_to(npc: NpcCharacter)

## Which character model to show. One of: barnaby, dracula, skeleton, wendy,
## franky, echo, bat, party.
@export var character: String = "barnaby"
## Mission text; set by the level when the mission starts.
@export var prompt_en: String = ""
@export var prompt_it: String = ""
@export var name_en: String = "Mr. Barnaby"
@export var name_it: String = "Signor Barnaby"

var _visual: Node3D
var _t: float = 0.0
var _ring: MeshInstance3D
var _bubble: Label3D


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 1 << 2
	collision_mask = 0
	monitoring = false

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	shape.shape = sphere
	shape.position = Vector3(0, 1.0, 0)
	add_child(shape)

	_visual = _build_character(character)
	add_child(_visual)

	_ring = PropFactory.add_ring(self, Color("ffe08a"), 1.15)
	_ring.visible = false

	# A floating speech bubble with the current task icon.
	_bubble = Label3D.new()
	_bubble.text = "!"
	_bubble.font_size = 128
	_bubble.pixel_size = 0.009
	_bubble.outline_size = 26
	_bubble.outline_modulate = Color(0.06, 0.03, 0.1, 0.95)
	_bubble.modulate = Color("ffd15c")
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0, 2.6, 0)
	_bubble.render_priority = 4
	add_child(_bubble)


func _process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = sin(_t * 1.4) * 0.04
		_visual.rotation.y = sin(_t * 0.5) * 0.12
	if _bubble != null:
		_bubble.position.y = 2.6 + sin(_t * 2.2) * 0.1


func can_interact() -> bool:
	return true


func set_focused(value: bool) -> void:
	if _ring != null:
		_ring.visible = value
	scale = Vector3.ONE * (1.05 if value else 1.0)


func interact(_by: Node = null) -> void:
	talked_to.emit(self)


## Applies the mission texts to this NPC.
func configure(mission: Dictionary) -> void:
	name_en = String(mission.get("npc", name_en))
	prompt_en = String(mission.get("prompt_en", ""))
	prompt_it = String(mission.get("prompt_it", ""))
	name_it = GameData.translate(name_en)
	if name_it.is_empty():
		name_it = name_en


func _build_character(kind: String) -> Node3D:
	match kind:
		"barnaby":
			return _barnaby()
		"dracula", "skeleton":
			return PropFactory.build("skeleton", "white", {"scale": 1.15})
		"wendy":
			return PropFactory.build("witch", "purple", {"scale": 1.1})
		"franky":
			return PropFactory.build("monster", "green", {"scale": 1.15})
		"echo":
			return PropFactory.build("ghost", "white", {"scale": 1.35})
		"bat":
			return PropFactory.build("bat", "purple", {"scale": 1.4})
		"party":
			return PropFactory.build("pumpkin", "orange", {"scale": 1.6})
		_:
			return PropFactory.build("skeleton", "white")


## Mr. Barnaby is hand-built: a scarecrow needs a hat, a post and a smile.
func _barnaby() -> Node3D:
	var root := Node3D.new()
	root.name = "Barnaby"
	var cloth := PropFactory.mat(Color("8a5a2b"))
	var straw := PropFactory.mat(Color("e0b96a"))
	var post := PropFactory.mat(Color("6b4324"))

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = 1.6
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 0.8, 0)
	pole.material_override = post
	root.add_child(pole)

	var arms := MeshInstance3D.new()
	var arms_mesh := BoxMesh.new()
	arms_mesh.size = Vector3(1.5, 0.09, 0.09)
	arms.mesh = arms_mesh
	arms.position = Vector3(0, 1.35, 0)
	arms.rotation_degrees = Vector3(0, 0, 6)
	arms.material_override = post
	root.add_child(arms)

	var torso := MeshInstance3D.new()
	var torso_mesh := CylinderMesh.new()
	torso_mesh.top_radius = 0.26
	torso_mesh.bottom_radius = 0.34
	torso_mesh.height = 0.7
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 1.25, 0)
	torso.material_override = cloth
	root.add_child(torso)

	# Straw sticking out of the sleeves and the collar.
	for side in [-1.0, 1.0]:
		for i in 3:
			var straw_piece := MeshInstance3D.new()
			var straw_mesh := BoxMesh.new()
			straw_mesh.size = Vector3(0.3, 0.025, 0.025)
			straw_piece.mesh = straw_mesh
			straw_piece.position = Vector3(side * 0.82, 1.4 + i * 0.04, 0)
			straw_piece.rotation_degrees = Vector3(0, 0, side * (10 + i * 12))
			straw_piece.material_override = straw
			root.add_child(straw_piece)

	# Burlap sack head with stitched features.
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.32
	head_mesh.height = 0.6
	head.mesh = head_mesh
	head.position = Vector3(0, 1.95, 0)
	head.material_override = straw
	root.add_child(head)

	var ink := PropFactory.mat(Color("3b2a1f"))
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.06
		eye_mesh.height = 0.12
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.12, 2.02, 0.28)
		eye.material_override = ink
		root.add_child(eye)

	var mouth := MeshInstance3D.new()
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.26, 0.03, 0.03)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0, 1.85, 0.3)
	mouth.material_override = ink
	root.add_child(mouth)

	# The hat he wants back in mission 5.
	var hat := PropFactory.build("hat", "brown", {"scale": 0.9})
	hat.position = Vector3(0, 2.28, 0)
	hat.name = "Hat"
	root.add_child(hat)

	return root
