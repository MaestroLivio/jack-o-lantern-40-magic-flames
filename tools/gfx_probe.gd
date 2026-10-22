extends SceneTree
## One-off visual probe: opens a few scenes and writes PNGs to `_shots/`.
##
## Not part of the build and not referenced by anything. It exists because the
## graphics work in this session (new star / candy / barrel / cauldron / candle /
## lantern / tombstone / tree geometry, ground tiles, motes, balloons) was never
## looked at, and "it compiled" is not the same as "it looks like a pumpkin".
##
##   godot --path . --script tools/gfx_probe.gd
##
## Runs windowed, not `--headless`: a headless run has no renderer, so every
## captured frame is blank.

const OUT_DIR := "res://_shots"

var _main: Node
var _quest: Node


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_quest = root.get_node_or_null("QuestManager")
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		print("GFX FAIL %s: no image" % name)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := image.save_png(path)
	print("GFX %s %s -> %s" % ["OK  " if err == OK else "FAIL", name, path])


func _run() -> void:
	_main.set("story_enabled", false)
	_quest.set("persist", false)
	await _wait(1.5)

	# Zone 1 with a mission running, so props, grid and HUD are all on screen.
	_quest.call("start_mission", 1)
	await _wait(2.0)
	await _shot("gfx_zone1")

	# The party zone: balloons, warm fill, dense motes.
	_quest.call("start_mission", 40)
	await _wait(2.5)
	await _shot("gfx_party")

	# The grid room: line contrast and the hollow trap frames.
	_quest.call("start_mission", 37)
	await _wait(2.2)
	await _shot("gfx_grid")

	# A bonus coordinate challenge: no target frames at all, traps visible.
	_quest.call("start_extra", 1)
	await _wait(2.2)
	await _shot("gfx_coords")

	# The number board.
	_quest.call("start_extra", 11)
	await _wait(2.2)
	await _shot("gfx_numbers")

	# The challenge hub.
	_main.call("_on_title_challenges")
	await _wait(1.0)
	await _shot("gfx_hub")

	print("GFX DONE")
	quit(0)
