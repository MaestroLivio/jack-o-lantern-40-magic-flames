class_name GridTrapRoom
extends MissionController
## The 10x10 coordinate room (missions 37, 38, 39).
##
## Jack walks freely on a 10 x 10 board. His 3D position is converted into a
## chess-style coordinate (A1 to J10) every frame and shown on the HUD. The
## mission defines a `path` of coordinates to visit in order and optional
## `traps` to avoid.
##
## Coordinate maths
## ----------------
##   column = floor((x + half) / cell)   -> 0..9  -> letter 'A'..'J'
##   row    = floor((half - z) / cell)   -> 0..9  -> number 1..10
## with `half = size * cell / 2`. Row 1 is the far edge (north), so the
## numbers grow toward the player exactly like a treasure map.
##
## Traps are never punishing: stepping on one plays a soft "boing", shows
## "Careful! That is a trap." and puts Jack back on the last safe tile.

const GRID_SIZE := 10
const CELL := 2.0

## Coordinate the child is currently standing on, e.g. "B3".
var current_coord: String = ""
## Set to true while the level itself owns the HUD coordinate label.
@export var report_to_hud: bool = true

var _path: Array = []
var _traps: Array = []
var _step: int = 0
var _last_safe := ""
var _trap_cooldown := 0.0
var _target_markers: Array[MeshInstance3D] = []
var _trap_markers: Array[MeshInstance3D] = []
var _coord_label: Label3D
var _half := GRID_SIZE * CELL * 0.5


func _setup() -> void:
	_path = mission.get("path", [])
	_traps = mission.get("traps", [])
	_step = 0

	_build_room()
	_build_markers()

	# Place Jack on the requested start tile (missions 37/38 start at A1).
	var start_coord := String(mission.get("start", "A1"))
	if player != null:
		var start_pos := coord_to_position(start_coord)
		player.teleport_to(start_pos + Vector3(0, 0.6, 0))
		_last_safe = start_coord
	current_coord = start_coord

	QuestManager.step_changed.emit(0, _path.size())
	_refresh_markers()
	if hud != null:
		hud.hint_set("Walk to the yellow square! Watch the coordinate.")

	# The start tile itself can be the first target (mission 37 starts on A1),
	# and `_on_coord_changed` only fires on a *change*. Register it explicitly so
	# that tile counts.
	_on_coord_changed(current_coord)


func _build_room() -> void:
	WorldBuilder.build_grid_room(self, GRID_SIZE, CELL)


## Floating "walk here" markers and spiky trap tiles.
func _build_markers() -> void:
	# Target markers: a glowing frame on each tile of the path. Frames rather
	# than filled squares so the grid lines stay readable underneath them.
	for coord in _path:
		var marker := _make_tile_marker(String(coord), Color("ffc94d"))
		_paint_marker(marker, Color("ffc94d"), 0.5)
		_target_markers.append(marker)

	# Trap markers: a red frame plus red spikes, unmistakably not to be stepped on.
	for coord in _traps:
		var marker := _make_tile_marker(String(coord), Color("e2704f"))
		_paint_marker(marker, Color("e2704f"), 0.55)
		_trap_markers.append(marker)
		var spikes := Node3D.new()
		spikes.position = coord_to_position(String(coord)) + Vector3(0, 0.02, 0)
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

	# A floating coordinate label that follows Jack, so the HUD is duplicated
	# right above his head for children who look at the character, not the UI.
	_coord_label = Label3D.new()
	_coord_label.font_size = 96
	_coord_label.pixel_size = 0.007
	_coord_label.outline_size = 22
	_coord_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_coord_label.no_depth_test = true
	_coord_label.modulate = Color("9fe8ff")
	add_child(_coord_label)


func _make_tile_marker(coord: String, color: Color) -> MeshInstance3D:
	# A *frame*, not a filled square.
	#
	# The old marker was a 1.84 m glowing slab lifted 3 cm — higher than the
	# grid strips (1 cm) and nearly as wide as the cell. It did not merely
	# decorate the tile, it painted over the two grid lines that define it, so
	# the board read as an unfinished chessboard. A hollow frame marks the same
	# tile while leaving the coordinate lines visible inside it, which is the
	# information the child actually navigates by.
	#
	# The returned node is the parent of the four bars so `_refresh_markers()`
	# can recolour all of them with one material assignment.
	var marker := MeshInstance3D.new()
	marker.name = "Marker_%s" % coord
	marker.position = coord_to_position(coord) + Vector3(0, 0.012, 0)
	# An invisible 1-pixel mesh keeps the node visible/invisible-able as a unit;
	# the actual drawing is done by the four bars below it, which is also what
	# lets one material recolour the whole frame.
	var hub := MeshInstance3D.new()
	var tiny := BoxMesh.new()
	tiny.size = Vector3(0.001, 0.001, 0.001)
	hub.mesh = tiny
	hub.visible = false
	marker.add_child(hub)

	var outer := CELL * 0.9
	var bar_w := 0.11
	var bar_h := 0.02
	# [size, offset] for the four sides of the square.
	for spec in [
		[Vector3(outer, bar_h, bar_w), Vector3(0, 0, -outer * 0.5 + bar_w * 0.5)],
		[Vector3(outer, bar_h, bar_w), Vector3(0, 0, outer * 0.5 - bar_w * 0.5)],
		[Vector3(bar_w, bar_h, outer), Vector3(-outer * 0.5 + bar_w * 0.5, 0, 0)],
		[Vector3(bar_w, bar_h, outer), Vector3(outer * 0.5 - bar_w * 0.5, 0, 0)],
	]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[0]
		bar.mesh = box
		bar.position = spec[1]
		marker.add_child(bar)
	marker.set_meta("marker_color", color)
	add_child(marker)
	return marker


## Recolours a marker frame. `MeshInstance3D.material_override` on the parent
## does not reach children, so each bar is set explicitly — but they all get the
## same material instance, which keeps it to one allocation per refresh.
func _paint_marker(marker: MeshInstance3D, color: Color, alpha: float) -> void:
	var mat := PropFactory.glow_mat(color, alpha)
	for child in marker.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_trap_cooldown = maxf(_trap_cooldown - delta, 0.0)

	# Convert Jack's world position into a coordinate.
	var coord := position_to_coord(player.global_position)
	if coord != current_coord:
		current_coord = coord
		_on_coord_changed(coord)

	if _coord_label != null:
		_coord_label.text = current_coord
		_coord_label.position = player.global_position + Vector3(0, 2.6, 0)

	if report_to_hud and hud != null:
		hud.set_step_text("Tile %s" % current_coord)


func _on_coord_changed(coord: String) -> void:
	if coord.is_empty():
		return
	# Mission complete when the last tile of the path is reached.
	if _step < _path.size() and coord == String(_path[_step]):
		_step += 1
		AudioFx.play_sfx("step")
		QuestManager.step_changed.emit(_step, _path.size())
		QuestManager.feedback.emit(coord + "!", coord + "!", "success")
		AudioFx.speak(coord)
		_refresh_markers()
		if _step >= _path.size():
			praise("You found it!", "L'hai trovata!")
			solve()
			return

	# Traps are checked after the target so a target always wins.
	if _traps.has(coord) and _trap_cooldown <= 0.0:
		_on_trap(coord)
		return

	if not _traps.has(coord):
		_last_safe = coord


func _on_trap(coord: String) -> void:
	_trap_cooldown = 1.2
	AudioFx.play_sfx("trap")
	QuestManager.feedback.emit("Careful! That is a trap.", "Attento! È una trappola.", "gentle")
	AudioFx.speak("Careful! That is a trap.")
	# Put Jack back on the last safe tile. Nothing is lost.
	if player != null:
		var safe := _last_safe if not _last_safe.is_empty() else String(mission.get("start", "A1"))
		var target := coord_to_position(safe) + Vector3(0, 0.6, 0)
		player.teleport_to(target)
		current_coord = safe


## Refreshes which target tile glows brightest.
func _refresh_markers() -> void:
	for i in _target_markers.size():
		if not is_instance_valid(_target_markers[i]):
			continue
		var is_next := i == _step
		_target_markers[i].visible = true
		# Next tile: bright and pulsing. Later tiles: dim, but always visible —
		# the child still has to know how many tiles remain, or the mission turns
		# into a memory test instead of a coordinate-reading exercise.
		_paint_marker(_target_markers[i], Color("ffc94d"), 0.55 if is_next else 0.16)


# --- Coordinate helpers (public: the HUD reuses them) ----------------------

## World position -> "A1".."J10" ("" when outside the board).
func position_to_coord(world_position: Vector3) -> String:
	var local := world_position
	var col := int(floor((local.x + _half) / CELL))
	var row := int(floor((_half - local.z) / CELL))
	if col < 0 or col >= GRID_SIZE or row < 0 or row >= GRID_SIZE:
		return ""
	return "%s%d" % [String.chr(65 + col), row + 1]


## "A1".."J10" -> centre of that tile in world space.
func coord_to_position(coord: String) -> Vector3:
	var clean := coord.strip_edges().to_upper()
	if clean.length() < 2:
		return Vector3.ZERO
	var col := clean.unicode_at(0) - 65
	var row := int(clean.substr(1)) - 1
	col = clampi(col, 0, GRID_SIZE - 1)
	row = clampi(row, 0, GRID_SIZE - 1)
	var x := -_half + CELL * (col + 0.5)
	var z := _half - CELL * (row + 0.5)
	return Vector3(x, 0, z)
