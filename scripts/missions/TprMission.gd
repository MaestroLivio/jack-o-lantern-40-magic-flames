class_name TprMission
extends MissionController
## "Franky Says" — body-part TPR mini-game (mission 32).
##
## A 2D cut-out of Jack appears on screen; the child taps the named body part
## in the given order (HEAD, SHOULDERS, KNEES, TOES). Tapping the wrong part is
## never punished — the part wiggles and the correct one pulses.

signal solved_tpr

var _overlay: Control
var _parts: Dictionary = {}      # part name -> Control
var _order: Array = []
var _step: int = 0
var _prompt: Label


func _setup() -> void:
	_order = mission.get("targets", [])
	_step = 0
	_build_overlay()
	QuestManager.step_changed.emit(0, _order.size())
	await get_tree().create_timer(0.4).timeout
	if is_inside_tree():
		_announce()
	if hud != null:
		hud.set_prompt_visible(false)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TprLayer"
	add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = UiKit.theme()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_overlay)

	_overlay.add_child(UiKit.scrim(0.5))

	# The body: a big 2D Jack drawn from panels, so each part is tappable.
	var body := Control.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body.custom_minimum_size = Vector2(420, 520)
	body.size = Vector2(420, 520)
	body.position = Vector2(-210, -190)
	_overlay.add_child(body)

	var skin := Color("f28c1e")
	# Head
	_parts["head"] = _make_part(body, "HEAD", Vector2(150, 130), Vector2(140, 20), skin, 40)
	# Shoulders
	_parts["shoulders"] = _make_part(body, "SHOULDERS", Vector2(150, 165), Vector2(140, 170), Color("ffb347"), 18)
	# Torso (decorative, not a target)
	var torso := Panel.new()
	var torso_style := StyleBoxFlat.new()
	torso_style.bg_color = Color("3a2154")
	torso_style.set_corner_radius_all(18)
	torso.add_theme_stylebox_override("panel", torso_style)
	torso.position = Vector2(150, 240)
	torso.custom_minimum_size = Vector2(120, 150)
	torso.size = Vector2(120, 150)
	torso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(torso)
	# Knees
	_parts["knees"] = _make_part(body, "KNEES", Vector2(160, 130), Vector2(130, 360), Color("ffb347"), 26)
	# Toes
	_parts["toes"] = _make_part(body, "TOES", Vector2(190, 70), Vector2(115, 450), skin, 20)

	# Prompt bar at the top.
	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = 30
	panel.offset_bottom = 150
	_overlay.add_child(panel)
	var m := UiKit.margin(16)
	panel.add_child(m)
	_prompt = UiKit.label("Tap: HEAD", 38, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(_prompt)


## Creates a tappable rounded rectangle for one body part.
func _make_part(parent: Control, label_text: String, part_size: Vector2, pos: Vector2, color: Color, radius: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = part_size
	b.size = part_size
	b.position = pos
	b.theme = UiKit.theme()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = Color("8a4a10")
	style.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.14)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", style)
	b.text = label_text
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color("3b1d00"))
	b.pressed.connect(_on_part_pressed.bind(String(label_text).to_lower()))
	parent.add_child(b)
	return b


func _announce() -> void:
	if _step >= _order.size():
		return
	var part := String(_order[_step].get("word", ""))
	_prompt.text = "Tap: " + part.to_upper()
	AudioFx.speak(part)
	_pulse(part)


## The hands-on panel says its first part name 0.4 s after the build, so the
## level must leave the task line alone. See
## `MissionController.defers_prompt_speech()`.
func defers_prompt_speech() -> bool:
	return true


func _on_part_pressed(part: String) -> void:
	if _step >= _order.size() or is_resolving:
		return
	var wanted := String(_order[_step].get("word", "")).to_lower()
	if part == wanted:
		AudioFx.play_sfx("correct")
		AudioFx.speak("%s. Yes!" % part)
		_step += 1
		QuestManager.step_changed.emit(_step, _order.size())
		QuestManager.feedback.emit(part.to_upper() + "!", part.to_upper() + "!", "success")
		if _step >= _order.size():
			_prompt.text = "Well done!"
			AudioFx.speak("Head, shoulders, knees and toes. Well done!")
			await get_tree().create_timer(1.2).timeout
			if is_inside_tree():
				_close()
				solve()
				solved_tpr.emit()
			return
		_announce()
	else:
		# Wrong part: wiggle it and highlight the right one. Nothing is lost.
		AudioFx.play_sfx("wrong")
		AudioFx.speak("%s! Tap %s." % [wanted, wanted])
		var control: Control = _parts.get(part)
		if control != null:
			var tween := create_tween()
			tween.tween_property(control, "position:x", control.position.x + 10, 0.07)
			tween.tween_property(control, "position:x", control.position.x - 10, 0.1)
			tween.tween_property(control, "position:x", control.position.x, 0.07)
		_pulse(wanted)


## Makes the correct part pulse so the child can find it by sight.
func _pulse(part: String) -> void:
	var control: Control = _parts.get(part)
	if control == null:
		return
	var tween := create_tween().set_loops(3)
	tween.tween_property(control, "modulate", Color(1, 1, 0.5, 1), 0.22)
	tween.tween_property(control, "modulate", Color.WHITE, 0.22)


func _close() -> void:
	if hud != null:
		hud.set_prompt_visible(true)
	if _overlay != null:
		_overlay.queue_free()
