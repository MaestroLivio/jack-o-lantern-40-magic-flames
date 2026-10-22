class_name RepeatMission
extends MissionController
## Listen & repeat missions (4, 33-36) driven by the RepeatPanel.
##
## The three trees of mission 4 wake up as the child repeats each greeting;
## in the dungeon Echo's mirror glows. Either way the world reacts, so the
## feedback is visual as well as spoken.

var _panel: RepeatPanel
var _trees: Array[Node3D] = []


func _setup() -> void:
	_build_scenery()
	_panel = RepeatPanel.new()
	_panel.name = "RepeatPanel"
	add_child(_panel)
	_panel.line_completed.connect(_on_line_completed)
	_panel.finished.connect(_on_finished)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	if hud != null:
		hud.set_prompt_visible(false)
		_panel.start(mission)


## For mission 4 the landmark is sleeping trees that wake one by one.
func _build_scenery() -> void:
	if int(mission.get("zone", 1)) != 1:
		# Dungeon zones get a mirror column instead of trees.
		var mirror := PropFactory.build("lantern", "blue", {"scale": 1.2})
		mirror.position = Vector3(0, 0, -7.5)
		add_child(mirror)
		return
	for i in 3:
		var tree := PropFactory.build("tree", "green", {"sleeping": true, "scale": 1.4})
		tree.position = Vector3(-5.0 + i * 5.0, 0, -7.0)
		add_child(tree)
		_trees.append(tree)


func _on_line_completed(index: int, _total: int) -> void:
	# Wake up the tree that matches this line.
	var tree_index := index - 1
	if tree_index >= 0 and tree_index < _trees.size():
		var tree := _trees[tree_index]
		var tween := create_tween()
		tween.tween_property(tree, "scale", Vector3.ONE * 1.7, 0.22).set_trans(Tween.TRANS_BACK)
		tween.tween_property(tree, "scale", Vector3.ONE * 1.4, 0.22)
		# Rebuild the tree awake: swap the visual for smiling eyes.
		for child in tree.get_children():
			if child is Node3D and child.name.to_lower().contains("tree"):
				for sub in child.get_children():
					if sub is MeshInstance3D and (sub.mesh as BoxMesh) != null:
						sub.queue_free()


func _on_finished() -> void:
	if hud != null:
		hud.set_prompt_visible(true)
	praise("Beautiful speaking!", "Ottima pronuncia!")
	solve()


## The mirror reads its first sentence 0.5 s after the build: the task line
## would be cut off mid-word. See `MissionController.defers_prompt_speech()`.
func defers_prompt_speech() -> bool:
	return true


## True when a screen point lands on the pill a folded mirror leaves behind.
func blocks_fold_point(at: Vector2) -> bool:
	return _panel != null and _panel.visible and _panel.blocks_point(at)


## A folded mirror does not own the screen: the child folded it to look around.
func is_panel_open() -> bool:
	return _panel != null and _panel.visible and not _panel.is_folded()


## Brings a folded mirror back so its Italian line can be read.
func unfold_panel() -> void:
	if _panel != null and _panel.visible:
		_panel.unfold()
