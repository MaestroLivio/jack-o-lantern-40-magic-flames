class_name PropFactory
extends RefCounted
## Builds every 3D prop of the game out of primitive meshes.
##
## The whole game is "toy-store" low poly on purpose: bright colours, soft
## shapes and big silhouettes read well for 7-year-olds and cost nothing to
## import. Every builder returns a plain Node3D so it can be used both as
## scenery and as an interactable (see LearningProp).
##
## Usage:
##     var node := PropFactory.build("pumpkin", "red", {"scale": 1.2})
##     add_child(node)

## Bright, high-contrast palette shared by the whole game.
const PALETTE: Dictionary = {
	"red": Color("d93b3b"),
	"blue": Color("3b6fd9"),
	"yellow": Color("f2d13b"),
	"green": Color("4fb84f"),
	"purple": Color("8b4fd6"),
	"orange": Color("f28c1e"),
	"black": Color("23232b"),
	"white": Color("f5f2ea"),
	"pink": Color("f28cc0"),
	"brown": Color("8a5a2b"),
	"gold": Color("ffc94d"),
	"slime": Color("7ee06a"),
	"grey": Color("9a9aa5"),
	"skin": Color("a9d98a"),
	"wood": Color("6b4324"),
	"stone": Color("6f6a78"),
	"night": Color("241737"),
	"purple_dark": Color("3a2154"),
	"sky": Color("1b2a4a"),
}


static func color_of(key: String) -> Color:
	return PALETTE.get(key.to_lower(), Color.WHITE)


## Standard material. `emission` > 0 makes the prop glow (stars, flames...).
##
## A low `metallic_specular` plus rim lighting is what stops these primitives
## from looking like flat cut-outs: with `metallic = 0` and a high roughness the
## only cue to a sphere being a sphere is the shading gradient, and at this
## polycount that is almost invisible. The rim is deliberately weak — it has to
## trace the silhouette of a pumpkin, not turn it into plastic.
static func mat(color: Color, emission: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = 0.0
	# 0.5 is the neutral default; a little more gives the specular lobe some
	# presence on the big rounded shapes without making anything shinier than
	# painted wood.
	m.metallic_specular = 0.62
	m.rim_enabled = true
	m.rim = 0.22
	m.rim_tint = 0.55
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## Translucent, self-lit material used for highlight rings and magic effects.
static func glow_mat(color: Color, alpha: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	return m


static func _attach(parent: Node3D, mesh: Mesh, pos: Vector3, rotation_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rotation_deg
	if material != null:
		mi.material_override = material
	parent.add_child(mi)
	return mi


static func _sphere(radius: float, height: float = -1.0, segments: int = 16, rings: int = 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height if height > 0.0 else radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(top: float, bottom: float, height: float, segments: int = 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


## Builds a prop of `kind` tinted with the palette key `color_key`.
## `opts` accepts: scale (float), label (String), face ("happy"/"sad"),
## arms ("long"/"short"), glow (float).
static func build(kind: String, color_key: String = "orange", opts: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	var c := color_of(color_key)
	var glow: float = float(opts.get("glow", 0.0))
	var body_mat := mat(c, glow)

	match kind:
		"pumpkin":
			_pumpkin(root, c, body_mat, String(opts.get("face", "happy")))
		"bat":
			_bat(root, c, body_mat)
		"ghost":
			_ghost(root, c, body_mat)
		"candy":
			_candy(root, c, body_mat)
		"star":
			_star(root, c, body_mat)
		"apple":
			_apple(root, c, body_mat)
		"leaf":
			_leaf(root, c, body_mat)
		"spider":
			_spider(root, c, body_mat)
		"cat":
			_cat(root, c, body_mat)
		"skeleton":
			_skeleton(root, c, body_mat)
		"witch":
			_witch(root, c, body_mat)
		"monster":
			_monster(root, c, body_mat)
		"arm":
			_arm(root, c, body_mat, String(opts.get("arms", "long")))
		"foot":
			_foot(root, c, body_mat)
		"hat":
			_hat(root, c, body_mat)
		"broom":
			_broom(root, c, body_mat)
		"cauldron":
			_cauldron(root, c, body_mat)
		"barrel":
			_barrel(root, c, body_mat)
		"bench":
			_bench(root, c, body_mat)
		"tree":
			_tree(root, c, body_mat, bool(opts.get("sleeping", false)))
		"door":
			_door(root, c, body_mat)
		"tombstone":
			_tombstone(root, c, body_mat)
		"lantern":
			_lantern(root, c, body_mat)
		"candle":
			_candle(root, c, body_mat)
		"flame":
			_flame(root, c, body_mat)
		"fence":
			_fence(root, c, body_mat)
		"pumpkin_pile":
			_pumpkin_pile(root, c, body_mat)
		_:
			# Unknown kind: a friendly glowing cube, never a hard failure.
			_attach(root, _box(Vector3(0.6, 0.6, 0.6)), Vector3(0, 0.5, 0), Vector3.ZERO, mat(Color("ff4fd8"), 1.0))

	var s: float = float(opts.get("scale", 1.0))
	if not is_equal_approx(s, 1.0):
		root.scale = Vector3.ONE * s

	var label: String = String(opts.get("label", ""))
	if not label.is_empty():
		_add_label(root, label, float(opts.get("label_y", 1.35)))

	return root


## Floating billboard label (used for numbers, colour words, coordinate hints).
static func _add_label(root: Node3D, text: String, y: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 18
	label.outline_modulate = Color(0.05, 0.03, 0.09, 0.95)
	label.modulate = Color(1, 0.96, 0.82)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, y, 0)
	label.render_priority = 2
	root.add_child(label)
	return label


## Soft glowing ring on the floor: tells children "this one can be picked up".
static func add_ring(parent: Node3D, color: Color, radius: float = 0.85) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 6
	var ring := _attach(parent, torus, Vector3(0, 0.05, 0), Vector3.ZERO, glow_mat(color, 0.55))
	ring.name = "Ring"
	return ring


# --- Individual props -------------------------------------------------------

static func _pumpkin(root: Node3D, c: Color, m: Material, face: String) -> void:
	var body := _attach(root, _sphere(0.5), Vector3(0, 0.45, 0), Vector3.ZERO, m)
	body.scale = Vector3(1.0, 0.86, 1.0)
	# Ribbing: three slightly darker slivers give the classic pumpkin shape.
	var dark := mat(c.darkened(0.22))
	for x in [-0.26, 0.0, 0.26]:
		var rib := _attach(root, _sphere(0.34), Vector3(x, 0.45, 0), Vector3.ZERO, dark)
		rib.scale = Vector3(0.42, 0.95, 1.0)
	# Stem
	_attach(root, _cyl(0.055, 0.085, 0.26), Vector3(0, 0.92, 0), Vector3(0, 0, 8), mat(color_of("wood"), 0.0, 0.9))
	# Face
	#
	# The face is a *learning cue*, not decoration: mission 20 asks a child to
	# find the HAPPY pumpkin and ignore the sad ones, and the final-party quiz
	# asks "Which one is HAPPY?". It used to be one small prism flipped 180°
	# about Z, which measured as a difference of twelve pixels on screen at
	# classroom distance — i.e. invisible, so the child had no way to answer
	# except by guessing. The mouth is therefore drawn as a *curve*: a row of
	# beads whose height follows a parabola, opening upward for a smile and
	# downward for a frown. The two shapes are unmistakably different from the
	# camera's normal distance, which is the only thing that matters here.
	var is_sad := face == "sad"
	var eye_mat := mat(Color("1a1420"))
	_attach(root, _sphere(0.075), Vector3(-0.16, 0.55, 0.42), Vector3.ZERO, eye_mat)
	_attach(root, _sphere(0.075), Vector3(0.16, 0.55, 0.42), Vector3.ZERO, eye_mat)

	# Eyebrows: the second signal. Slanted *inward and down* over the nose reads
	# as a scowl even if the child is too far away to resolve the mouth curve,
	# and a face that carries the same message twice is what makes the cue
	# survive a foggy dungeon and a projector that washes out contrast.
	var brow_y := 0.66 if is_sad else 0.655
	var brow_tilt := 16.0 if is_sad else -6.0
	for side in [-1, 1]:
		var brow := _attach(root, _box(Vector3(0.15, 0.032, 0.05)),
				Vector3(0.16 * side, brow_y, 0.44),
				Vector3(0, 0, brow_tilt * side), eye_mat)
		brow.name = "Brow"

	# The mouth. Seven beads on y = base + k * x^2 (smile) or base - k * x^2
	# (frown); `k` is small enough that the arc stays inside the pumpkin's
	# 0.5 m body and never pokes through the rim of the silhouette.
	var beads := 7
	var span := 0.20
	var curve := 0.13
	var base_y := 0.33
	for i in beads:
		var t := float(i) / float(beads - 1)          # 0 .. 1 across the mouth
		var x := lerpf(-span, span, t)
		# `4 * (t - 0.5)^2` is 1 at the corners and 0 in the middle, so the same
		# formula gives a valley (smile) and, negated, a hill (frown).
		var bend := 4.0 * pow(t - 0.5, 2.0)
		var y := base_y + (curve * bend if not is_sad else -curve * bend)
		var bead := _attach(root, _sphere(0.045), Vector3(x, y, 0.45), Vector3.ZERO, eye_mat)
		bead.name = "Mouth"


static func _bat(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _sphere(0.27), Vector3(0, 0.9, 0), Vector3.ZERO, m)
	var wing := mat(c.darkened(0.15))
	_attach(root, _box(Vector3(0.85, 0.06, 0.42)), Vector3(-0.55, 0.95, 0), Vector3(0, 0, -18), wing)
	_attach(root, _box(Vector3(0.85, 0.06, 0.42)), Vector3(0.55, 0.95, 0), Vector3(0, 0, 18), wing)
	# Ears
	_attach(root, _cyl(0.0, 0.09, 0.2), Vector3(-0.13, 1.16, 0), Vector3(0, 0, 10), m)
	_attach(root, _cyl(0.0, 0.09, 0.2), Vector3(0.13, 1.16, 0), Vector3(0, 0, -10), m)
	# Eyes
	var eye := mat(Color("ffe94d"), 1.0)
	_attach(root, _sphere(0.05), Vector3(-0.09, 0.95, 0.22), Vector3.ZERO, eye)
	_attach(root, _sphere(0.05), Vector3(0.09, 0.95, 0.22), Vector3.ZERO, eye)


static func _ghost(root: Node3D, c: Color, m: Material) -> void:
	var body := _attach(root, _sphere(0.45), Vector3(0, 0.85, 0), Vector3.ZERO, m)
	body.scale = Vector3(1.0, 1.25, 1.0)
	_attach(root, _cyl(0.42, 0.0, 0.55), Vector3(0, 0.42, 0), Vector3(180, 0, 0), m)
	var eye := mat(Color("1a1420"))
	_attach(root, _sphere(0.06), Vector3(-0.14, 0.95, 0.4), Vector3.ZERO, eye)
	_attach(root, _sphere(0.06), Vector3(0.14, 0.95, 0.4), Vector3.ZERO, eye)
	_attach(root, _sphere(0.07), Vector3(0, 0.78, 0.43), Vector3.ZERO, eye)


static func _candy(root: Node3D, c: Color, m: Material) -> void:
	# A wrapped sweet: a squat body plus a *twisted* wrapper at each end. The
	# wrapper was a single cone per side, which read as a bow tie; two cones per
	# side, angled apart and meeting at the body, is the shape a child recognises
	# as a candy — and mission 8 asks them to find exactly this.
	var body := _attach(root, _sphere(0.2), Vector3(0, 0.5, 0), Vector3.ZERO, m)
	body.scale = Vector3(1.25, 1.0, 1.25)
	# A pale stripe around the middle: a candy with a single flat colour is just a
	# coloured ball, while the stripe is what makes the two-colour reading clear.
	# The torus is configured before it is attached so the mesh is never briefly
	# rendered with `TorusMesh`'s default half-metre radius.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.185
	ring.outer_radius = 0.235
	ring.rings = 16
	ring.ring_segments = 8
	var stripe := _attach(root, ring, Vector3(0, 0.5, 0), Vector3.ZERO, mat(c.lightened(0.55)))
	stripe.scale = Vector3(1.3, 1.05, 1.3)
	var wrap := mat(c.lightened(0.25))
	# Two cones per side, fanned around the X axis. A cone's tip points along +Y,
	# so a `z` rotation of -90° aims it at +X and +90° aims it at -X; the extra
	# ±26° is the fan. Written as two nested loops rather than four literals
	# because the *symmetry* is the point: mismatched angles on the two sides
	# would be a lopsided sweet that a child reads as a mistake.
	for side in [-1.0, 1.0]:
		for fan in [-26.0, 26.0]:
			var aim: float = -90.0 if side > 0.0 else 90.0
			_attach(root, _cyl(0.0, 0.135, 0.24, 8),
					Vector3(side * 0.27, 0.5, 0),
					Vector3(0, 0, aim + fan), wrap)


static func _star(root: Node3D, c: Color, m: Material) -> void:
	# A real five-pointed star, not a spinning top: `SphereMesh` with five
	# segments and two rings is a cone-ish blob whose silhouette a child cannot
	# name. Five cones radiating from a small hub read as a star from any camera
	# angle, which matters because these sit in a ring the child walks through and
	# is therefore seen from the side as often as from the front.
	var center_y := 0.85
	_attach(root, _sphere(0.2, 0.4, 12, 6), Vector3(0, center_y, 0), Vector3.ZERO, m)
	var point_mat := mat(c.lightened(0.12))
	for i in 5:
		# Each point starts at the hub and sticks out in a different direction of
		# the vertical plane facing the camera. `-90` on Z lays the cone on its
		# side so its *tip* points outward instead of up.
		var angle := -PI * 0.5 + TAU * float(i) / 5.0
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		var point := _attach(root, _cyl(0.0, 0.13, 0.5, 6),
				Vector3(0, center_y, 0) + direction * 0.3,
				Vector3(0, 0, rad_to_deg(angle) - 90.0), point_mat)
		point.name = "StarPoint"
	# A glowing tip in the middle so the star reads as *magic* in a dark zone
	# instead of as a pale blob against the fog.
	_attach(root, _sphere(0.11), Vector3(0, center_y, 0.14), Vector3.ZERO, mat(color_of("gold"), 1.8))


static func _apple(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _sphere(0.28), Vector3(0, 0.6, 0), Vector3.ZERO, m)
	_attach(root, _cyl(0.02, 0.03, 0.2), Vector3(0, 0.88, 0), Vector3(0, 0, 6), mat(color_of("wood")))
	var leaf := _attach(root, _box(Vector3(0.2, 0.02, 0.1)), Vector3(0.08, 0.92, 0), Vector3(0, 0, 22), mat(color_of("green")))
	leaf.name = "Leaf"


static func _leaf(root: Node3D, c: Color, m: Material) -> void:
	var node := _attach(root, _box(Vector3(0.7, 0.05, 0.45)), Vector3(0, 0.06, 0), Vector3(0, 0, 0), m)
	node.name = "LeafMesh"


static func _spider(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _sphere(0.24), Vector3(0, 0.35, 0), Vector3.ZERO, m)
	_attach(root, _sphere(0.15), Vector3(0, 0.42, 0.24), Vector3.ZERO, m)
	var leg_mat := mat(c.darkened(0.2))
	for i in 4:
		var z := -0.16 + i * 0.11
		for side in [-1.0, 1.0]:
			_attach(root, _box(Vector3(0.34, 0.03, 0.03)), Vector3(side * 0.28, 0.33, z), Vector3(0, side * 22.0, side * 18.0), leg_mat)
	var eye := mat(Color("ffe94d"), 1.0)
	_attach(root, _sphere(0.035), Vector3(-0.06, 0.46, 0.36), Vector3.ZERO, eye)
	_attach(root, _sphere(0.035), Vector3(0.06, 0.46, 0.36), Vector3.ZERO, eye)


static func _cat(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _sphere(0.3), Vector3(0, 0.42, 0), Vector3.ZERO, m)
	_attach(root, _sphere(0.21), Vector3(0, 0.78, 0.12), Vector3.ZERO, m)
	_attach(root, _cyl(0.0, 0.08, 0.18), Vector3(-0.11, 0.96, 0.1), Vector3(0, 0, 12), m)
	_attach(root, _cyl(0.0, 0.08, 0.18), Vector3(0.11, 0.96, 0.1), Vector3(0, 0, -12), m)
	_attach(root, _cyl(0.035, 0.035, 0.5), Vector3(0, 0.62, -0.34), Vector3(62, 0, 0), m)
	var eye := mat(Color("1a1420"))
	_attach(root, _sphere(0.04), Vector3(-0.08, 0.82, 0.28), Vector3.ZERO, eye)
	_attach(root, _sphere(0.04), Vector3(0.08, 0.82, 0.28), Vector3.ZERO, eye)


static func _skeleton(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _sphere(0.22), Vector3(0, 1.25, 0), Vector3.ZERO, m)
	_attach(root, _box(Vector3(0.34, 0.5, 0.18)), Vector3(0, 0.85, 0), Vector3.ZERO, m)
	for i in 3:
		_attach(root, _box(Vector3(0.4, 0.06, 0.12)), Vector3(0, 1.02 - i * 0.14, 0), Vector3.ZERO, m)
	for side in [-1.0, 1.0]:
		_attach(root, _box(Vector3(0.1, 0.42, 0.1)), Vector3(side * 0.26, 0.85, 0), Vector3(0, 0, side * 14), m)
		_attach(root, _box(Vector3(0.12, 0.5, 0.12)), Vector3(side * 0.11, 0.3, 0), Vector3.ZERO, m)
	var eye := mat(Color("1a1420"))
	_attach(root, _sphere(0.055), Vector3(-0.08, 1.3, 0.19), Vector3.ZERO, eye)
	_attach(root, _sphere(0.055), Vector3(0.08, 1.3, 0.19), Vector3.ZERO, eye)


static func _witch(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _cyl(0.16, 0.42, 0.9), Vector3(0, 0.45, 0), Vector3.ZERO, m)
	_attach(root, _sphere(0.24), Vector3(0, 1.05, 0), Vector3.ZERO, mat(color_of("skin")))
	_attach(root, _cyl(0.0, 0.32, 0.85), Vector3(0, 1.45, 0), Vector3(0, 0, -8), mat(color_of("purple_dark")))
	_attach(root, _cyl(0.42, 0.42, 0.05), Vector3(0, 1.04, 0), Vector3(0, 0, -8), mat(color_of("purple_dark")))
	var eye := mat(Color("1a1420"))
	_attach(root, _sphere(0.04), Vector3(-0.08, 1.1, 0.21), Vector3.ZERO, eye)
	_attach(root, _sphere(0.04), Vector3(0.08, 1.1, 0.21), Vector3.ZERO, eye)


static func _monster(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _box(Vector3(0.8, 1.0, 0.45)), Vector3(0, 0.75, 0), Vector3.ZERO, m)
	_attach(root, _box(Vector3(0.55, 0.5, 0.42)), Vector3(0, 1.5, 0), Vector3.ZERO, m)
	_attach(root, _cyl(0.05, 0.05, 0.18), Vector3(-0.32, 1.52, 0), Vector3(0, 0, 90), mat(color_of("grey")))
	_attach(root, _cyl(0.05, 0.05, 0.18), Vector3(0.32, 1.52, 0), Vector3(0, 0, 90), mat(color_of("grey")))
	var eye := mat(Color("f5f2ea"), 0.4)
	_attach(root, _sphere(0.06), Vector3(-0.13, 1.56, 0.22), Vector3.ZERO, eye)
	_attach(root, _sphere(0.06), Vector3(0.13, 1.56, 0.22), Vector3.ZERO, eye)


static func _arm(root: Node3D, c: Color, m: Material, variant: String) -> void:
	var length := 0.55 if variant == "short" else 1.25
	_attach(root, _box(Vector3(0.2, length, 0.2)), Vector3(0, 1.6 - length * 0.5, 0), Vector3.ZERO, m)
	_attach(root, _sphere(0.16), Vector3(0, 1.6 - length, 0), Vector3.ZERO, mat(color_of("skin")))
	_attach(root, _box(Vector3(0.5, 0.35, 0.4)), Vector3(0, 1.75, 0), Vector3.ZERO, mat(color_of("purple_dark")))


static func _foot(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _box(Vector3(0.45, 0.3, 0.75)), Vector3(0, 0.15, 0), Vector3.ZERO, m)
	_attach(root, _box(Vector3(0.35, 0.5, 0.35)), Vector3(0, 0.5, -0.1), Vector3.ZERO, m)


static func _hat(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _cyl(0.38, 0.38, 0.05), Vector3(0, 0.05, 0), Vector3.ZERO, m)
	_attach(root, _cyl(0.0, 0.3, 0.7), Vector3(0, 0.42, 0), Vector3(0, 0, 6), mat(c.darkened(0.15)))


static func _broom(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _cyl(0.045, 0.045, 1.5), Vector3(0, 0.85, 0), Vector3(0, 0, 10), mat(color_of("wood")))
	var bristles := _attach(root, _cyl(0.18, 0.06, 0.5), Vector3(0.13, 0.25, 0), Vector3(0, 0, 12), m)
	bristles.name = "Bristles"


static func _cauldron(root: Node3D, c: Color, m: Material) -> void:
	# Three legs, a belly, a rim and the brew: a cauldron is the one prop in the
	# bog a child is asked to *find by name*, so its silhouette cannot be "a black
	# bowl". The legs are what make it a cauldron instead of a bucket.
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 0.5
		_attach(root, _cyl(0.07, 0.09, 0.34, 8),
				Vector3(cos(angle) * 0.38, 0.17, sin(angle) * 0.38),
				Vector3(rad_to_deg(sin(angle)) * 0.35, 0, rad_to_deg(cos(angle)) * -0.35),
				mat(c.darkened(0.35)))
	var belly := _attach(root, _sphere(0.48), Vector3(0, 0.5, 0), Vector3.ZERO, m)
	belly.scale = Vector3(1.0, 0.72, 1.0)
	belly.name = "Belly"
	var rim := TorusMesh.new()
	rim.inner_radius = 0.4
	rim.outer_radius = 0.5
	rim.rings = 24
	rim.ring_segments = 8
	_attach(root, rim, Vector3(0, 0.62, 0), Vector3.ZERO, mat(c.darkened(0.3)))
	# The brew sits *inside* the rim, glowing: a dark disc alone reads as a hole.
	var brew := _attach(root, _cyl(0.4, 0.4, 0.04), Vector3(0, 0.63, 0), Vector3.ZERO,
			mat(color_of("slime"), 1.3))
	brew.name = "Brew"
	# Two bubbles rising out of the brew, caught mid-pop.
	_attach(root, _sphere(0.07), Vector3(0.12, 0.76, 0.06), Vector3.ZERO, mat(color_of("slime"), 1.6))
	_attach(root, _sphere(0.045), Vector3(-0.1, 0.86, -0.05), Vector3.ZERO, mat(color_of("slime"), 1.6))
	# A hanging hook so the pot is not floating over its own legs.
	for side in [-1.0, 1.0]:
		_attach(root, _cyl(0.03, 0.03, 0.42), Vector3(side * 0.42, 0.82, 0),
				Vector3(0, 0, side * 42), mat(c.darkened(0.3)))


static func _barrel(root: Node3D, c: Color, m: Material) -> void:
	# A barrel with a *bulge*: three stacked cylinder sections, the middle one
	# wider. A single straight cylinder reads as a can, and the game asks children
	# to find barrels by name, so the silhouette has to be the one they know.
	_attach(root, _cyl(0.38, 0.42, 0.34, 20), Vector3(0, 0.17, 0), Vector3.ZERO, m)
	_attach(root, _cyl(0.44, 0.44, 0.34, 20), Vector3(0, 0.5, 0), Vector3.ZERO, m)
	_attach(root, _cyl(0.42, 0.38, 0.34, 20), Vector3(0, 0.83, 0), Vector3.ZERO, m)
	# An open top: a dark disc just under the rim, so the barrel reads as a
	# container instead of as a solid drum.
	_attach(root, _cyl(0.36, 0.36, 0.02, 20), Vector3(0, 0.98, 0), Vector3.ZERO, mat(Color("20161f")))
	var band := mat(color_of("grey").darkened(0.15), 0.0, 0.55)
	for y in [0.16, 0.84]:
		_attach(root, _cyl(0.455, 0.455, 0.055, 20), Vector3(0, y, 0), Vector3.ZERO, band)
	# Vertical staves on the widest section: the eye needs two directions of lines
	# to read a surface as curved wood.
	var stave := mat(c.darkened(0.3))
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_attach(root, _box(Vector3(0.035, 0.32, 0.02)),
				Vector3(cos(angle) * 0.435, 0.5, sin(angle) * 0.435),
				Vector3(0, -rad_to_deg(angle), 0), stave)


static func _bench(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _box(Vector3(1.9, 0.12, 0.6)), Vector3(0, 0.5, 0), Vector3.ZERO, m)
	_attach(root, _box(Vector3(1.9, 0.5, 0.1)), Vector3(0, 0.78, -0.28), Vector3.ZERO, m)
	for side in [-0.75, 0.75]:
		_attach(root, _box(Vector3(0.12, 0.5, 0.5)), Vector3(side, 0.25, 0), Vector3.ZERO, mat(c.darkened(0.2)))


static func _tree(root: Node3D, c: Color, m: Material, sleeping: bool) -> void:
	_attach(root, _cyl(0.26, 0.42, 2.6), Vector3(0, 1.3, 0), Vector3.ZERO, mat(color_of("wood")))
	# Two branches before the canopy: a trunk that goes straight from the ground
	# into a ball of leaves is a lollipop. The branches are what make the
	# silhouette read as a tree from the side, where most of the ring is seen.
	for side in [-1.0, 1.0]:
		_attach(root, _cyl(0.07, 0.13, 1.1), Vector3(side * 0.42, 2.1, 0),
				Vector3(0, 0, side * -38), mat(color_of("wood")))
	var leaves := mat(c.darkened(0.15))
	_attach(root, _sphere(0.95), Vector3(0, 2.8, 0), Vector3.ZERO, leaves)
	_attach(root, _sphere(0.7), Vector3(0.7, 2.5, 0.2), Vector3.ZERO, leaves)
	_attach(root, _sphere(0.65), Vector3(-0.65, 2.6, -0.15), Vector3.ZERO, leaves)
	# A lighter cap on top of the canopy: three same-coloured spheres merge into
	# one flat mass under a single moon light, and one brighter ball at the top
	# gives the eye a highlight to read the volume by.
	_attach(root, _sphere(0.55), Vector3(0.1, 3.35, -0.05), Vector3.ZERO, mat(c.lightened(0.12)))
	if sleeping:
		var eye := mat(Color("1a1420"))
		# Closed "sleeping" eyes: thin boxes.
		_attach(root, _box(Vector3(0.22, 0.035, 0.05)), Vector3(-0.24, 1.85, 0.4), Vector3.ZERO, eye)
		_attach(root, _box(Vector3(0.22, 0.035, 0.05)), Vector3(0.24, 1.85, 0.4), Vector3.ZERO, eye)


static func _door(root: Node3D, c: Color, m: Material) -> void:
	_attach(root, _box(Vector3(1.5, 2.4, 0.25)), Vector3(0, 1.2, 0), Vector3.ZERO, m)
	var frame := mat(c.darkened(0.35))
	_attach(root, _box(Vector3(1.75, 0.18, 0.32)), Vector3(0, 2.42, 0), Vector3.ZERO, frame)
	for side in [-0.82, 0.82]:
		_attach(root, _box(Vector3(0.16, 2.5, 0.32)), Vector3(side, 1.2, 0), Vector3.ZERO, frame)
	_attach(root, _sphere(0.07), Vector3(0.5, 1.2, 0.16), Vector3.ZERO, mat(color_of("gold"), 0.8))


static func _tombstone(root: Node3D, c: Color, m: Material) -> void:
	# A rounded headstone with a bevelled plinth, a carved cross and a crack. The
	# original was a slab plus a half-cylinder, which from any distance was a
	# grey rectangle: mission 21 asks the child to count tombstones, so each one
	# has to be recognisable *as one* in a row of six.
	var stone := _attach(root, _box(Vector3(0.7, 1.1, 0.22)), Vector3(0, 0.55, 0), Vector3.ZERO, m)
	stone.name = "Stone"
	var cap := _attach(root, _cyl(0.35, 0.35, 0.22), Vector3(0, 1.1, 0), Vector3(90, 0, 0), m)
	cap.name = "Cap"
	# Plinth: a slightly wider, darker base. Without it the stone looks pushed
	# into the ground rather than standing on it.
	_attach(root, _box(Vector3(0.86, 0.14, 0.36)), Vector3(0, 0.05, 0), Vector3.ZERO, mat(c.darkened(0.28)))
	# The cross, in the darker tone so it reads as carved rather than glued on.
	var carve := mat(c.darkened(0.42))
	_attach(root, _box(Vector3(0.085, 0.42, 0.03)), Vector3(0, 0.78, 0.115), Vector3.ZERO, carve)
	_attach(root, _box(Vector3(0.28, 0.085, 0.03)), Vector3(0, 0.86, 0.115), Vector3.ZERO, carve)
	# One crack, off-centre: six identical headstones in a row read as a texture,
	# while one that is broken reads as a *place*.
	_attach(root, _box(Vector3(0.035, 0.3, 0.03)), Vector3(0.19, 0.45, 0.115), Vector3(0, 0, 18), carve)


static func _lantern(root: Node3D, c: Color, m: Material) -> void:
	# The post, a hooked arm, a hanging cage and the light inside it. The original
	# was a post with a glowing ball balanced on top, which read as a streetlamp;
	# the hook is what makes it a *paper lantern* and matches the ring strung
	# around every zone.
	_attach(root, _cyl(0.05, 0.05, 2.2), Vector3(0, 1.1, 0), Vector3.ZERO, mat(color_of("stone")))
	# The arm: a short horizontal rod turning up into the hook.
	_attach(root, _box(Vector3(0.42, 0.05, 0.05)), Vector3(0.2, 2.18, 0), Vector3.ZERO, mat(color_of("stone")))
	_attach(root, _cyl(0.02, 0.02, 0.16), Vector3(0.4, 2.1, 0), Vector3.ZERO, mat(color_of("stone")))
	# The cage, hanging under the arm.
	var cage := _attach(root, _box(Vector3(0.3, 0.36, 0.3)), Vector3(0.4, 1.85, 0),
			Vector3.ZERO, mat(c.darkened(0.35), 0.0, 0.5))
	cage.name = "Cage"
	# The glow, as a sphere slightly *larger* than the cage: an emissive ball
	# inside an opaque box is invisible, which is exactly how the old lantern
	# managed to look unlit in the dark.
	_attach(root, _sphere(0.19), Vector3(0.4, 1.85, 0), Vector3.ZERO, mat(c, 1.9))
	# A little cone of light falling out of it, drawn as two translucent cones:
	# the ambient glow alone does not tell a child where the light on the ground
	# is coming from.
	var beam := _cyl(0.02, 0.34, 0.5, 12)
	_attach(root, beam, Vector3(0.4, 1.55, 0), Vector3.ZERO, PropFactory.glow_mat(c, 0.13))


static func _candle(root: Node3D, c: Color, m: Material) -> void:
	# A candle needs a *flame*, not a glowing bead: a bead on top of a cylinder
	# reads as a lollipop, and mission 23 asks the child to count candles. The
	# flame is a small cone in two tones plus a dark wick between it and the wax.
	_attach(root, _cyl(0.07, 0.085, 0.5, 12), Vector3(0, 0.25, 0), Vector3.ZERO, m)
	# A drip of wax down one side: the single detail that says "wax" rather than
	# "white cylinder".
	_attach(root, _sphere(0.045), Vector3(0.055, 0.42, 0.02), Vector3.ZERO, mat(c.lightened(0.1)))
	_attach(root, _cyl(0.014, 0.014, 0.09, 6), Vector3(0, 0.53, 0), Vector3.ZERO, mat(Color("1a1420")))
	_attach(root, _cyl(0.0, 0.06, 0.22, 10), Vector3(0, 0.68, 0), Vector3.ZERO, mat(color_of("orange"), 2.2))
	_attach(root, _sphere(0.035), Vector3(0, 0.63, 0), Vector3.ZERO, mat(Color("fff3c4"), 2.6))


static func _flame(root: Node3D, c: Color, m: Material) -> void:
	# Three nested cones instead of two meshes: the outer cone is the body of the
	# flame, the middle one is its brighter core, and the innermost bead is the
	# white-hot tip. Stacking three sizes of *the same* shape is what gives a
	# flame its gradient without a single texture, and it is also what makes the
	# moon (built from this prop at scale 6) read as a disc with an aura rather
	# than as a flat balloon.
	var flame := _attach(root, _cyl(0.0, 0.22, 0.6), Vector3(0, 0.35, 0), Vector3.ZERO, mat(c, 2.2))
	flame.name = "FlameMesh"
	_attach(root, _cyl(0.0, 0.14, 0.42), Vector3(0, 0.3, 0), Vector3.ZERO, mat(c.lightened(0.35), 2.6))
	_attach(root, _sphere(0.12), Vector3(0, 0.22, 0), Vector3.ZERO, mat(Color("fff3c4"), 2.4))
	# A thin dark wick, so the flame is attached to something. Without it the
	# fire appears to hover a few centimetres above every candle.
	_attach(root, _cyl(0.018, 0.018, 0.12), Vector3(0, 0.02, 0), Vector3.ZERO, mat(Color("1a1420")))


static func _fence(root: Node3D, c: Color, m: Material) -> void:
	# Posts with *pointed* tops and two rails, plus a brace at 45°: an X of
	# diagonals between the rails is what makes a fence read as a fence rather
	# than as two horizontal sticks, which is what it was.
	for side in [-1.0, 1.0]:
		var post := _attach(root, _box(Vector3(0.14, 1.1, 0.14)), Vector3(side, 0.55, 0), Vector3.ZERO, m)
		post.name = "Post"
		_attach(root, _cyl(0.0, 0.1, 0.16, 4), Vector3(side, 1.18, 0), Vector3(0, 45, 0), m)
	_attach(root, _box(Vector3(2.0, 0.12, 0.08)), Vector3(0, 0.8, 0), Vector3.ZERO, m)
	_attach(root, _box(Vector3(2.0, 0.12, 0.08)), Vector3(0, 0.4, 0), Vector3.ZERO, m)
	var brace := mat(c.darkened(0.2))
	_attach(root, _box(Vector3(1.9, 0.09, 0.06)), Vector3(0, 0.6, 0.01), Vector3(0, 0, 24), brace)
	_attach(root, _box(Vector3(1.9, 0.09, 0.06)), Vector3(0, 0.6, -0.01), Vector3(0, 0, -24), brace)


static func _pumpkin_pile(root: Node3D, c: Color, m: Material) -> void:
	for entry in [[Vector3(0.0, 0.0, 0.0), 0.55], [Vector3(0.55, 0.0, 0.15), 0.4], [Vector3(-0.5, 0.0, -0.1), 0.35]]:
		var p := _attach(root, _sphere(float(entry[1])), entry[0] + Vector3(0, float(entry[1]) * 0.9, 0), Vector3.ZERO, m)
		p.scale = Vector3(1.0, 0.88, 1.0)
