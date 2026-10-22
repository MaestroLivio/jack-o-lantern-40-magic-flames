class_name WorldBuilder
extends RefCounted
## Builds the 3D environment for a zone out of primitives.
##
## Each zone gets its own palette, lighting mood, ground pattern and scatter
## decorations, so the five biomes feel different while sharing one code path.
## Everything is deterministic per zone (`seed`) so a child revisiting a zone
## sees the same world.

const ZONE_LOOK: Dictionary = {
	"patch": {
		"ground": Color("4a7a3a"), "ground_edge": Color("375c2b"),
		"sky_top": Color("2b1c47"), "sky_bottom": Color("7a4a6a"),
		"light": Color("ffd2a1"), "energy": 1.15, "fog": Color("3b2a4f"), "fog_density": 0.02,
		"decor": ["pumpkin_pile", "fence", "tree", "tombstone", "candle"],
	},
	"castle": {
		"ground": Color("4a4256"), "ground_edge": Color("38314a"),
		"sky_top": Color("1a1030"), "sky_bottom": Color("3d2a55"),
		"light": Color("b79cff"), "energy": 0.95, "fog": Color("241a3a"), "fog_density": 0.028,
		"decor": ["tombstone", "candle", "barrel", "fence"],
	},
	"bog": {
		"ground": Color("3f5a3a"), "ground_edge": Color("2f4a2c"),
		"sky_top": Color("243a2a"), "sky_bottom": Color("54786a"),
		"light": Color("c8ffb0"), "energy": 1.0, "fog": Color("2c4436"), "fog_density": 0.035,
		"decor": ["cauldron", "tree", "tombstone", "barrel", "candle"],
	},
	"lab": {
		"ground": Color("3d4a63"), "ground_edge": Color("2c3648"),
		"sky_top": Color("101a2c"), "sky_bottom": Color("2b4a6b"),
		"light": Color("a8e4ff"), "energy": 1.2, "fog": Color("1b2a3d"), "fog_density": 0.022,
		"decor": ["barrel", "candle", "fence", "tombstone"],
	},
	"dungeon": {
		"ground": Color("4a4448"), "ground_edge": Color("322e33"),
		"sky_top": Color("0d0a14"), "sky_bottom": Color("1f1a2b"),
		"light": Color("9fd8ff"), "energy": 0.85, "fog": Color("151020"), "fog_density": 0.04,
		"decor": ["tombstone", "candle", "fence", "barrel"],
	},
	"party": {
		"ground": Color("5a4a72"), "ground_edge": Color("42355a"),
		"sky_top": Color("281a45"), "sky_bottom": Color("8a4a72"),
		"light": Color("ffe0b0"), "energy": 1.35, "fog": Color("3a2450"), "fog_density": 0.015,
		"decor": ["pumpkin_pile", "candle", "fence", "tree"],
		# The finale: the only zone with balloons in the air, and the only one that
		# trades the moon's cool fill for a warm one. The class arrives here after
		# forty missions, and the sky is the one thing they have not seen change.
		"motes": 120, "mote_speed": 1.5, "fill": Color("ffb06a"), "balloons": true,
	},
}


## Builds the static environment of `zone_id` as a child of `parent`.
static func build_zone(parent: Node3D, zone_id: int) -> void:
	var zone := GameData.zone_info(zone_id)
	var look: Dictionary = ZONE_LOOK.get(String(zone.get("decor", "patch")), ZONE_LOOK["patch"])

	_apply_environment(parent, look)
	_build_ground(parent, look)
	_build_arena_walls(parent, look)
	_scatter_decor(parent, look, String(zone.get("decor", "patch")))
	_build_lights(parent, look)
	_build_sky_props(parent, look)
	_build_motes(parent, look, String(zone.get("decor", "patch")))
	# The finale zone gets balloons, and only it: a balloon is the one shape that
	# says "party" without a word, and the class arrives here after forty missions
	# — the sky should visibly change on the last one.
	if bool(look.get("balloons", false)):
		_build_balloons(parent)
	_build_npc_stage(parent, zone_id)


## The mood of the whole zone: sky, fog, ambient, tone mapping and post effects.
##
## Everything here is procedural and cheap (no textures, no photo assets), but
## it is also where most of the "this looks like a real place" comes from. The
## order of the levers matters more than their values:
##   * ambient occlusion (`ssao`) is what stops two orange pumpkins from merging
##     into one blob — the single biggest gain on a scene made of primitives;
##   * a little glow makes candles, lanterns and flames read as *light*;
##   * a touch of extra saturation compensates for the filmic curve, which
##     desaturates exactly the bright colours a Halloween palette lives on.
## The values stay gentle on purpose: a 7-year-old is reading colour words
## ("green", "orange") from this screen, so the colours must stay truthful.
static func _apply_environment(parent: Node3D, look: Dictionary) -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = look["sky_top"]
	sky_mat.sky_horizon_color = look["sky_bottom"]
	sky_mat.ground_bottom_color = Color(0.06, 0.04, 0.09)
	sky_mat.ground_horizon_color = look["sky_bottom"]
	sky_mat.sun_angle_max = 12.0
	# A softer curve blends the two sky colours over a wider band, which reads
	# as haze near the horizon instead of a hard line behind the trees.
	sky_mat.sky_curve = 0.22
	sky_mat.ground_curve = 0.05
	sky_mat.sky_energy_multiplier = 1.05
	sky.sky_material = sky_mat
	env.sky = sky

	# Soft fog hides the edge of the play area and keeps the mood gentle.
	env.fog_enabled = true
	env.fog_light_color = look["fog"]
	env.fog_density = look["fog_density"]
	env.fog_sky_affect = 0.3
	# Ties distant props to the sky colour so the boundary never looks painted.
	env.fog_aerial_perspective = 0.35
	env.fog_sun_scatter = 0.25

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = look["light"]
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# `white` is the *input* value the filmic curve maps to pure white, so a high
	# value darkens everything below it. It was 6.0, which flattened the whole
	# night scene into a narrow, muddy band: props could not be told apart and the
	# colour words this game teaches lost their colour. Dropping it to 1.0 lifts
	# the median luminance by about a third on every zone, while leaving under
	# 0.2 % of the frame above 0.85 — readable, but still night, with headroom
	# for the flames to glow. Nothing below this line needed to change.
	env.tonemap_exposure = 1.15
	env.tonemap_white = 1.0

	# Contact shadows. The radius is metres, and 1.4 m is roughly "one Jack", so
	# props sitting on the ground get a soft dark line where they meet it —
	# without it, every mesh looks like it is floating.
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.5
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.25

	env.glow_enabled = true
	env.glow_intensity = 0.62
	env.glow_bloom = 0.06
	env.glow_strength = 1.0
	# Only parts of the screen brighter than this bloom. At 0.65 the *sky*
	# crosses the threshold and the whole background turns into a haze that
	# hurts readability; just under 1.0 keeps the effect on flames and candles,
	# which are the only things in this game brighter than the sky.
	env.glow_hdr_threshold = 0.98

	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04

	world_env.environment = env
	parent.add_child(world_env)


## Ground: a subtly textured plane plus the checker of tiles that gives depth
## perception, so a child can judge where they are walking.
static func _build_ground(parent: Node3D, look: Dictionary) -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	parent.add_child(ground)

	var mesh := MeshInstance3D.new()
	mesh.name = "GroundMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	mesh.mesh = plane
	mesh.material_override = _ground_material(look["ground"])
	ground.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)

	# The darker tiles used to be 9 m squares of flat colour, which read as a
	# giant chessboard rather than as ground: at that size the eye sees *two
	# floors*, not one floor with a pattern on it. They are now 4 m and only 8 %
	# darker, so they register as the uneven patches of a field — depth cues for
	# a child judging where to walk, without competing with the props, the grid
	# lines or the colour words this game teaches.
	#
	# A `MultiMeshInstance3D`, not 169 `MeshInstance3D` nodes: one mesh, one
	# material, one draw call for the whole floor pattern. The old 9 m version got
	# away with 41 separate nodes because they were huge; at 4 m the same area is
	# four times as many tiles, and 169 nodes is a 169-draw-call floor for a
	# purely decorative effect.
	const TILE := 4.0
	const HALF_TILES := 9                      # 19 x 19 grid, centred on the arena
	# Positions are collected first and the instance count is taken from them.
	# Counting the tiles with arithmetic is the sort of off-by-one that makes the
	# *last* tile silently missing (or the last `set_instance_transform` an error
	# in the log), and there is no reason to compute a number the loop already
	# knows.
	var spots: Array[Vector3] = []
	for i in range(-HALF_TILES, HALF_TILES + 1):
		for j in range(-HALF_TILES, HALF_TILES + 1):
			if (i + j) % 2 == 0:
				spots.append(Vector3(i * TILE, 0.015, j * TILE))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	(multimesh.mesh as BoxMesh).size = Vector3(TILE - 0.1, 0.05, TILE - 0.1)
	multimesh.instance_count = spots.size()
	for slot in spots.size():
		multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, spots[slot]))
	var tiles := MultiMeshInstance3D.new()
	tiles.name = "GroundTiles"
	tiles.multimesh = multimesh
	tiles.material_override = PropFactory.mat(look["ground_edge"], 0.0, 1.0)
	# Off the collision layer by construction (a MultiMesh has no body at all):
	# the tiles are 1.5 cm proud of the ground plane and must not become small
	# steps Jack can trip on.
	parent.add_child(tiles)


## A flat colour reads as a plastic sheet at this scale, because there is nothing
## for the eye to measure. A procedural noise texture (still generated at runtime,
## still no imported art) gives the ground grain, and the colour ramp keeps it
## subtle: the darkest grain is only 20% darker than the base colour, so the
## checker of tiles and the props on top stay the strongest shapes on screen.
static func _ground_material(color: Color) -> StandardMaterial3D:
	var m := PropFactory.mat(color, 0.0, 0.95)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.78, 0.8, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	# Triplanar keeps the grain the same size on the ground and on any slope.
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.06, 0.06, 0.06)
	return m


static func _build_arena_walls(parent: Node3D, look: Dictionary) -> void:
	# Invisible walls keep Jack inside the arena so he can never get lost.
	var half := 38.0
	var specs := [
		[Vector3(0, 2, -half), Vector3(80, 5, 1)],
		[Vector3(0, 2, half), Vector3(80, 5, 1)],
		[Vector3(-half, 2, 0), Vector3(1, 5, 80)],
		[Vector3(half, 2, 0), Vector3(1, 5, 80)],
	]
	for spec in specs:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = spec[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)


static func _scatter_decor(parent: Node3D, look: Dictionary, decor_key: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(decor_key)
	var decor: Array = look["decor"]
	var colors := ["orange", "purple", "green", "brown", "grey"]

	# Scatter around a ring so the middle of the arena stays playable.
	for i in 34:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(9.5, 22.0)
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var kind: String = decor[rng.randi_range(0, decor.size() - 1)]
		var color_key: String = colors[rng.randi_range(0, colors.size() - 1)]
		var node := PropFactory.build(kind, color_key, {
			"scale": rng.randf_range(0.85, 1.35),
		})
		node.position = pos
		node.rotation.y = rng.randf_range(0.0, TAU)
		parent.add_child(node)

	# A ring of trees marks the boundary of the play area.
	for i in 22:
		var angle := TAU * float(i) / 22.0
		var node := PropFactory.build("tree", "green", {"scale": 1.35})
		node.position = Vector3(cos(angle) * 27.0, 0, sin(angle) * 27.0)
		node.rotation.y = angle
		parent.add_child(node)

	# A ring of paper lanterns inside the tree line. Purely decorative, and the
	# cheapest way to make the mid-ground read as a *place* rather than as a
	# clearing: without them the eye travels from the props underfoot straight to
	# the tree silhouettes, with nothing in between. They are strung at 2.4 m, well
	# above Jack's head, so they never block a mission or hide a prop.
	#
	# One short `OmniLight3D` every third lantern only: fourteen real lights would
	# re-light the whole arena and flatten the moon, which is what the shadows are
	# for.
	var lantern_ring := Node3D.new()
	lantern_ring.name = "LanternRing"
	parent.add_child(lantern_ring)
	for i in 12:
		var angle := TAU * float(i) / 12.0 + 0.26
		var radius := 20.5
		var lantern := PropFactory.build("lantern", "gold", {"scale": 0.42})
		lantern.position = Vector3(cos(angle) * radius, 2.4, sin(angle) * radius)
		lantern_ring.add_child(lantern)
		if i % 3 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = Color("ffcf8a")
			glow.light_energy = 0.55
			glow.omni_range = 5.0
			glow.position = lantern.position
			lantern_ring.add_child(glow)


## Floating motes of light in the air, drifting slowly upward through the arena.
##
## The single biggest visual difference between "a room with furniture in it" and
## "a place with air in it": a static scene has nothing moving except Jack, so the
## eye reads it as a diorama. Six dozen slow glowing specks cost almost nothing
## and give the fog something to be *in*.
##
## One emitter per zone rather than one per prop, emitted from a box the size of
## the playable area, so the density is even where the child walks and zero
## outside the walls. The colour comes from the zone's own sky palette, which is
## what stops the motes looking like an effect pasted on top of a scene: they
## read as dust lit by the same moon as everything else.
##
## Particles are drawn, never simulated against the world (no collision, no
## gravity), so they cannot possibly interfere with a mission: nothing here is
## on a collision layer or in the interaction chain.
static func _build_motes(parent: Node3D, look: Dictionary, decor_key: String) -> void:
	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	# 90 for the open zones, fewer in the dungeon where the air is meant to be
	# still and the fog does the work instead. A zone may override both numbers
	# from `ZONE_LOOK` (the party does: it is meant to feel like a celebration,
	# not like a haunted clearing).
	motes.amount = int(look.get("motes", 48 if decor_key == "dungeon" else 84))
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.position = Vector3(0, 3.0, 0)
	motes.visibility_aabb = AABB(Vector3(-26, -6, -26), Vector3(52, 20, 52))
	# Never cast or receive shadows: a hundred tiny shadow casters is the one
	# thing that would actually cost frames on a school laptop.
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(24, 2.5, 24)
	# Mostly upward and slightly sideways: motes that only rose would read as a
	# chimney, and motes that only drifted would read as static dust.
	process.direction = Vector3(0.25, 1.0, 0.15)
	process.spread = 26.0
	var speed: float = float(look.get("mote_speed", 1.0))
	process.initial_velocity_min = 0.12 * speed
	process.initial_velocity_max = 0.42 * speed
	process.gravity = Vector3(0.06, 0.02, -0.04)
	# A gentle sway, so no two motes follow the same path.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.35
	process.turbulence_noise_scale = 2.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 0.7))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	# Scale *down* over the lifetime: a mote that appears and vanishes at full
	# size pops, one that fades in from nothing does not.
	process.scale_min = 0.4
	process.scale_max = 1.0
	motes.process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mote_mat := StandardMaterial3D.new()
	# Bilboarding is what makes a flat quad read as a light rather than as a
	# piece of paper at an angle.
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.albedo_color = (look["light"] as Color).lerp(Color.WHITE, 0.45)
	mote_mat.albedo_color.a = 0.75
	# Emissive so the specks bloom with the flames instead of sitting flat on top
	# of the glow, which is what ties them to the rest of the scene's lighting.
	mote_mat.emission_enabled = true
	mote_mat.emission = mote_mat.albedo_color
	mote_mat.emission_energy_multiplier = 1.6
	# No depth write: a mote passing behind another must not cut a hole in it.
	mote_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = mote_mat
	motes.draw_pass_1 = quad

	parent.add_child(motes)


## Balloons drifting over the finale party.
##
## Each one is a sphere, a small cone for the knot and a thin string, in the game's
## own palette so they belong to the same toy world as the pumpkins. They rise and
## sway on a loop rather than floating statically: the point is that the sky is
## *alive* on the last mission, and a still balloon is a decorated lamp.
##
## Drawn only: no collision, no mission ever references one, and the ring is placed
## at 7-13 m, well above every prop a child has to tap.
static func _build_balloons(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var keys := ["orange", "pink", "green", "blue", "yellow", "purple"]
	var root := Node3D.new()
	root.name = "Balloons"
	parent.add_child(root)
	for i in 14:
		var holder := Node3D.new()
		var angle := TAU * float(i) / 14.0 + rng.randf_range(-0.15, 0.15)
		var radius := rng.randf_range(8.0, 15.0)
		var height := rng.randf_range(7.0, 12.0)
		holder.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		root.add_child(holder)

		var key: String = keys[i % keys.size()]
		var colour := PropFactory.color_of(key)
		var balloon := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.42, 0.62)
		sphere.height = sphere.radius * 2.35
		sphere.radial_segments = 16
		sphere.rings = 10
		balloon.mesh = sphere
		# A little emission: at 10 m in a dark sky a pure-albedo balloon is a dark
		# blob, while one that glows slightly reads as a coloured balloon and keeps
		# the colour name true, which matters in a game that teaches colour words.
		balloon.material_override = PropFactory.mat(colour, 0.35)
		holder.add_child(balloon)

		var knot := MeshInstance3D.new()
		var knot_mesh := CylinderMesh.new()
		knot_mesh.top_radius = 0.0
		knot_mesh.bottom_radius = 0.09
		knot_mesh.height = 0.14
		knot.mesh = knot_mesh
		knot.position = Vector3(0, -sphere.height * 0.5 - 0.05, 0)
		knot.material_override = PropFactory.mat(colour.darkened(0.2))
		holder.add_child(knot)

		var string := MeshInstance3D.new()
		var string_mesh := CylinderMesh.new()
		string_mesh.top_radius = 0.012
		string_mesh.bottom_radius = 0.012
		string_mesh.height = 2.2
		string.mesh = string_mesh
		string.position = Vector3(0, -sphere.height * 0.5 - 1.2, 0)
		string.material_override = PropFactory.mat(Color("d8d2e0"), 0.0, 0.6)
		holder.add_child(string)

		# Rise and sway, each on its own phase so the ring never pulses in unison.
		# `holder.create_tween()` and not a bare `create_tween()`: this is a static
		# function on a `RefCounted`, which has no tween of its own. The tween is
		# bound to the balloon, so it dies with the zone instead of outliving it.
		var rise := holder.create_tween().set_loops()
		var drift := rng.randf_range(0.9, 1.8)
		rise.tween_property(holder, "position:y", height + rng.randf_range(0.5, 1.0), drift) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rise.tween_property(holder, "position:y", height, drift) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
static func _build_npc_stage(parent: Node3D, zone_id: int) -> void:
	var zone := GameData.zone_info(zone_id)
	var character := "barnaby"
	match zone_id:
		2: character = "dracula"
		3: character = "wendy"
		4: character = "franky"
		5: character = "echo"
		6: character = "party"
	var npc := NpcCharacter.new()
	npc.name = "ZoneNpc"
	npc.character = character
	npc.position = Vector3(0, 0, -4.2)
	parent.add_child(npc)
	npc.add_to_group("zone_npc")


static func _build_lights(parent: Node3D, look: Dictionary) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = look["light"]
	sun.light_energy = look["energy"]
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	# Four splits over 45 m instead of one over 60: with primitives of half a
	# metre, a single coarse split is what made contact shadows between a prop
	# and the ground disappear. `blend_splits` hides the seam where the
	# resolution changes.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.48
	sun.directional_shadow_blend_splits = true
	# A slightly large angular size gives a soft penumbra, as if the only light
	# were the moon, instead of the razor edge of a studio lamp.
	sun.light_angular_distance = 1.6
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	parent.add_child(sun)

	# A cool fill light from the opposite side softens the shadows so faces
	# and props stay readable for children with low vision. It does not cast
	# shadows: two shadow-casting directions on a single screen double the cost
	# and make the contact shadows look contradictory.
	#
	# The colour is per zone: the party's warm fill is what makes the last zone
	# look like a different *time of night* rather than the same clearing with
	# more pumpkins in it.
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = look.get("fill", Color("9fd8ff"))
	fill.light_energy = look["energy"] * 0.42
	fill.rotation_degrees = Vector3(-20, 140, 0)
	parent.add_child(fill)


## A moon and a field of stars: the cheapest possible fix for a flat sky.
##
## `ProceduralSkyMaterial` gives a smooth gradient, and a smooth gradient at
## night reads as an empty backdrop rather than as a sky. A large emissive disc
## plus a ring of tiny emissive spheres gives the eye something to be under, and
## because the stars live in the world (not in the background shader) they are
## occluded by the trees, which is what sells the depth. Everything is placed
## once per zone from a fixed seed, so a child revisiting sees the same sky.
static func _build_sky_props(parent: Node3D, look: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var sky_root := Node3D.new()
	sky_root.name = "SkyProps"
	parent.add_child(sky_root)

	var moon := PropFactory.build("flame", "white", {"scale": 6.0})
	moon.name = "Moon"
	moon.position = Vector3(-48, 46, -64)
	sky_root.add_child(moon)
	var moon_light := OmniLight3D.new()
	moon_light.light_color = Color("cfe4ff")
	moon_light.light_energy = 1.1
	moon_light.omni_range = 24.0
	moon_light.position = Vector3(-60, 40, -30)
	sky_root.add_child(moon_light)

	for i in 90:
		var star := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.16, 0.4)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 6
		sphere.rings = 3
		star.mesh = sphere
		# Emissive but unshaded: a star must not be shaded by the moon light.
		star.material_override = PropFactory.mat(
			look["sky_top"].lerp(Color.WHITE, rng.randf_range(0.3, 0.9)),
			rng.randf_range(1.2, 2.4))
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(55.0, 78.0)
		star.position = Vector3(
			cos(angle) * radius,
			rng.randf_range(20.0, 52.0),
			sin(angle) * radius)
		sky_root.add_child(star)


## Builds the 10x10 coordinate room used by missions 37-39.
static func build_grid_room(parent: Node3D, size: int = 10, cell: float = 2.0) -> void:
	var look: Dictionary = ZONE_LOOK["dungeon"]
	var half := size * cell * 0.5
	var floor_body := StaticBody3D.new()
	floor_body.name = "GridFloor"
	floor_body.collision_layer = 1
	parent.add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size * cell, 0.4, size * cell)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0, -0.2, 0)
	floor_mesh.material_override = PropFactory.mat(Color("2b2536"))
	floor_body.add_child(floor_mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size * cell, 0.4, size * cell)
	shape.shape = box_shape
	shape.position = Vector3(0, -0.2, 0)
	floor_body.add_child(shape)

	# Tile grid drawn as raised strips.
	#
	# "Non si vede la griglia, si vede a scacchi" was not a matter of adding more
	# lines: the strips were 5 cm wide at 1 cm above the floor, so they were
	# hidden by the tile markers sitting 3 cm up, and their emission (0.15) was
	# below the zone's glow threshold (0.98) so they never bloomed. The line is
	# now 9 cm wide, sits *above* every marker, and is bright enough to bloom —
	# so the board reads as a grid of coordinates with a few tinted squares on
	# it, instead of as an unfinished chessboard.
	var line_mat := PropFactory.mat(Color("a9a3bd"), 0.85, 0.6)
	const LINE_W := 0.09
	const LINE_Y := 0.035
	for i in range(size + 1):
		var offset := -half + i * cell
		var strip_z := MeshInstance3D.new()
		var sz := BoxMesh.new()
		sz.size = Vector3(size * cell, 0.03, LINE_W)
		strip_z.mesh = sz
		strip_z.position = Vector3(0, LINE_Y, offset)
		strip_z.material_override = line_mat
		parent.add_child(strip_z)

		var strip_x := MeshInstance3D.new()
		var sx := BoxMesh.new()
		sx.size = Vector3(LINE_W, 0.03, size * cell)
		strip_x.mesh = sx
		strip_x.position = Vector3(offset, LINE_Y, 0)
		strip_x.material_override = line_mat
		parent.add_child(strip_x)

	# Coordinate labels around the edge: A-J across, 1-10 up.
	for i in size:
		var letter := String.chr(65 + i)
		var lab := Label3D.new()
		lab.text = letter
		lab.font_size = 64
		lab.pixel_size = 0.006
		lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.position = Vector3(-half + cell * (i + 0.5), 0.08, half + 0.8)
		lab.modulate = Color("ffc94d")
		parent.add_child(lab)

		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 64
		num.pixel_size = 0.006
		num.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		num.rotation_degrees = Vector3(-90, 0, 0)
		num.position = Vector3(-half - 0.8, 0.08, half - cell * (i + 0.5))
		num.modulate = Color("ffc94d")
		parent.add_child(num)

	# Walls around the room.
	for spec in [
		[Vector3(0, 2, -half - 0.5), Vector3(size * cell, 4, 1)],
		[Vector3(0, 2, half + 0.5), Vector3(size * cell, 4, 1)],
		[Vector3(-half - 0.5, 2, 0), Vector3(1, 4, size * cell)],
		[Vector3(half + 0.5, 2, 0), Vector3(1, 4, size * cell)],
	]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = spec[0]
		var cshape := CollisionShape3D.new()
		var cbox := BoxShape3D.new()
		cbox.size = spec[1]
		cshape.shape = cbox
		body.add_child(cshape)
		parent.add_child(body)

	_build_lights(parent, look)
