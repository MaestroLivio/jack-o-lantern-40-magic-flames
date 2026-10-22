class_name CoordsMission
extends GridTrapRoom
## "Find the coordinate with no help at all" challenges (the ten extra missions).
##
## This is `GridTrapRoom` with the training wheels taken off. The original grid
## missions light the target tiles up, which is exactly the crutch a teacher wants
## to remove once the class can read a coordinate: a child who can follow a
## glowing square is not yet reading "G7", they are following a light.
##
## So the *only* thing this class changes is the target markers: there are none.
## Everything else is inherited on purpose, because the parts that keep the
## challenge safe are the parts a rewrite would lose:
##
##   * the coordinate label above Jack still says where he is standing, so a
##     mistake is "I am on C4, I need D5" and never "I am lost";
##   * traps still bounce him back to the last safe tile instead of resetting the
##     mission, so there is no way to lose progress;
##   * the prompt is spoken and can be heard again with the magnifying glass or
##     by talking to the character, so the target list is never out of reach.
##
## The mission is the *same* walk with less help, which is what "aumentare il
## livello di difficoltà" means here: no child is asked to do something new, they
## are asked to do something they already know without the answer on the floor.
##
## Obstacles are the one addition: solid props placed on the board, so the route
## is not the straight line a child draws in their head. They are ordinary
## `StaticBody3D` boxes — Jack walks around them, and because they never sit on a
## path tile, walking around is always possible.

## Coordinates of the solid props. Declared in the mission as `obstacles`.
var _obstacles: Array = []


func _setup() -> void:
	_obstacles = mission.get("obstacles", [])
	super._setup()
	if hud != null:
		# The one hint this mission gives, and it is about the controls, not the
		# answer. Naming the coordinate that is written in the task would undo
		# the point of the challenge.
		hud.hint_set("Read the coordinates, then walk there. Watch for the traps!")


## Replaces the inherited marker builder.
##
## Traps keep their red frame and their spikes: they are hazards, not answers, and
## a trap the child cannot see is a trap that teaches nothing. The target frames
## are simply not built, which is the whole difference between this mission and
## the ones in zone 5.
func _build_markers() -> void:
	for coord in _traps:
		var marker := _make_tile_marker(String(coord), Color("e2704f"))
		_paint_marker(marker, Color("e2704f"), 0.55)
		_trap_markers.append(marker)
		_build_spikes(String(coord))

	_build_obstacles()

	# The coordinate label above Jack, kept from the parent: it is the child's
	# position report, and without it "walk to G7" would be guesswork.
	_coord_label = Label3D.new()
	_coord_label.font_size = 96
	_coord_label.pixel_size = 0.007
	_coord_label.outline_size = 22
	_coord_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_coord_label.no_depth_test = true
	_coord_label.modulate = Color("9fe8ff")
	add_child(_coord_label)


## The four red cones of a trap tile, exactly as the parent draws them.
func _build_spikes(coord: String) -> void:
	var spikes := Node3D.new()
	spikes.position = coord_to_position(coord) + Vector3(0, 0.02, 0)
	for i in 4:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.16
		cone.height = 0.5
		spike.mesh = cone
		spike.position = Vector3(cos(i * TAU / 4.0) * 0.4, 0.25, sin(i * TAU / 4.0) * 0.4)
		spike.material_override = PropFactory.mat(Color("e2704f"), 0.6)
		spikes.add_child(spike)
	add_child(spikes)


## Solid props the child has to walk around.
##
## A crate is deliberately taller than it is wide (1.5 m against 1.4 m) and sits
## on the tile centre: a low box would read as decoration, and Jack would look
## like he is walking *through* the level. The collision shape is the same size as
## the mesh, so what the child sees is what blocks them.
func _build_obstacles() -> void:
	for coord in _obstacles:
		var spot := coord_to_position(String(coord))
		var body := StaticBody3D.new()
		body.name = "Obstacle_%s" % String(coord)
		body.position = spot
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)

		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.35, 1.5, 1.35)
		mesh.mesh = box
		mesh.material_override = PropFactory.mat(Color("6b4a2f"), 0.1, 0.85)
		mesh.position = Vector3(0, 0.75, 0)
		body.add_child(mesh)

		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		shape.shape = box_shape
		shape.position = Vector3(0, 0.75, 0)
		body.add_child(shape)

		# A pumpkin sitting on the crate ties it to the rest of the world instead
		# of leaving a brown cube on the floor.
		var lid := PropFactory.build("pumpkin", "orange", {"scale": 0.55})
		lid.position = Vector3(0, 1.5, 0)
		body.add_child(lid)
