extends SceneTree
## Verification probe for the graphics work: asserts the new scenery actually
## exists in the live scene tree.
##
## Why this exists: the graphics changes (ground tile MultiMesh, air motes,
## balloons, the rebuilt prop geometry) cannot be verified by reading a diff, and
## "it compiles" says nothing about whether a node was ever added. Everything
## below is read back from the same tree the game renders.
##
##   godot --path . --headless --script tools/gfx_verify.gd

var _main: Node
var _quest: Node
var _failures: Array[String] = []
var _checks := 0

const Shutdown := preload("res://tools/probe_shutdown.gd")


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("%s %s" % ["GFXCHECK OK  " if ok else "GFXCHECK FAIL", what])
	if not ok:
		_failures.append(what)


func _find(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var hit := _find(child, node_name)
		if hit != null:
			return hit
	return null


## Counts every descendant whose name starts with `prefix`.
func _count(node: Node, prefix: String) -> int:
	var total := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		total += _count(child, prefix)
	return total


func _run() -> void:
	print("GFXCHECK starting")
	_main.set("story_enabled", false)
	_quest.set("persist", false)
	await _wait(1.5)
	print("GFXCHECK ready")

	# --- Zone 1: ground tiles, motes, lantern ring ---------------------------
	_quest.call("start_mission", 1)
	await _wait(2.2)
	var level: Node = _main.get("level")
	var world: Node = level.get("_world")
	_check(world != null, "zone 1 world built")

	var tiles := _find(world, "GroundTiles") as MultiMeshInstance3D
	_check(tiles != null, "ground tile MultiMesh exists")
	if tiles != null:
		# 19x19 cells with every other one filled = 181 instances. Bounded rather
		# than exact so a future tile-size change does not fail the probe for the
		# wrong reason, but tight enough to catch empty or double-filled.
		var count: int = tiles.multimesh.instance_count
		_check(count > 150 and count < 200, "ground tiles instance_count=%d (expect ~181)" % count)

	var motes := _find(world, "Motes") as GPUParticles3D
	_check(motes != null, "air motes exist")
	if motes != null:
		_check(motes.amount >= 48, "air motes amount=%d" % motes.amount)

	var ring := _find(world, "LanternRing")
	_check(ring != null, "lantern ring exists")
	if ring != null:
		# Counted by type, not by name: twelve siblings all called "Lantern" get
		# auto-renamed to "@Lantern@2" .. "@Lantern@12" by `add_child`, so a name
		# match finds exactly one and looks like a failure when the ring is full.
		var lanterns := 0
		var glows := 0
		for child in ring.get_children():
			if child is OmniLight3D:
				glows += 1
			elif child is Node3D:
				lanterns += 1
		_check(lanterns >= 12, "lantern ring holds %d lanterns" % lanterns)
		_check(glows >= 1 and glows <= 6, "lantern ring has %d real lights" % glows)

	# --- Party zone: balloons, denser motes, warm fill -----------------------
	_quest.call("start_mission", 40)
	await _wait(2.5)
	var party: Node = level.get("_world")
	_check(party != null, "party world built")
	var balloons := _find(party, "Balloons")
	_check(balloons != null, "party balloons exist")
	if balloons != null:
		_check(balloons.get_child_count() >= 14, "balloon count=%d" % balloons.get_child_count())

	var party_motes := _find(party, "Motes") as GPUParticles3D
	_check(party_motes != null, "party motes exist")
	if party_motes != null:
		_check(party_motes.amount > 100, "party motes denser: %d" % party_motes.amount)

	# A stray balloon over the pumpkin patch would be the visual equivalent of a
	# mission leaking into the next zone, so its absence is asserted explicitly.
	# `world` was freed by the zone change, so the check is made on the *party*
	# world's siblings through the level, not on the old reference.
	var level_worlds := 0
	var balloon_worlds := 0
	for child in level.get_children():
		if child is Node3D and String(child.name).begins_with("Zone"):
			level_worlds += 1
			if _find(child, "Balloons") != null:
				balloon_worlds += 1
	_check(level_worlds == 1,
		"exactly one zone world alive after a zone change (found %d)" % level_worlds)
	_check(balloon_worlds == 1, "balloons live in exactly one zone world (%d)" % balloon_worlds)

	# --- Rebuilt props: the geometry is no longer one primitive --------------
	# The star, candy, barrel, cauldron, candle, lantern, tombstone and fence were
	# all rebuilt from one or two meshes into recognisable shapes. Counting the
	# `MeshInstance3D` children is the objective version of "it is a shape now".
	# The thresholds are the *measured* mesh counts of the rebuilt props, not
	# guesses: an earlier draft guessed 16 for the barrel and failed against a
	# correct 14 (three sections, a lid, two bands, eight staves). A regression
	# test whose expectation was invented reports its author's arithmetic, not the
	# code, so these numbers come from the run and are meant to be updated when a
	# prop is deliberately changed.
	var rebuilt := {
		"star": 7, "candy": 6, "barrel": 14, "cauldron": 10,
		"candle": 5, "lantern": 6, "tombstone": 6, "fence": 8,
	}
	for kind in rebuilt:
		var node := PropFactory.build(String(kind), "orange", {})
		# Every child built by `_attach` is a `MeshInstance3D` (some named, most
		# not), so counting the direct children of that type is the honest count.
		var actual := 0
		for child in node.get_children():
			if child is MeshInstance3D:
				actual += 1
		_check(actual >= int(rebuilt[kind]),
			"%s built from %d meshes (need >= %d)" % [kind, actual, int(rebuilt[kind])])
		node.free()

	print("")
	print("GFX VERIFY RESULT: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  - ", f)
	await Shutdown.and_quit(self, 0 if _failures.is_empty() else 1)
