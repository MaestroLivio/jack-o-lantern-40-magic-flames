class_name ZoneIntroCard
extends Control
## The "welcome to this zone" card.
##
## Every time Jack enters a new biome, this card names the zone, shows the
## topic and the character he is about to meet, and reads it aloud. It closes
## on its own after a few seconds (or when tapped), so it never blocks play.

signal dismissed

const AUTO_CLOSE_TIME := 5.0

## Panel geometry and the inner width its wrapped text is laid out at (see
## `UiKit.label` for why that width must be explicit).
const PANEL_W := 780.0
const PANEL_H := 500.0
const WRAP_WIDTH := 660.0

var _zone: Dictionary = {}
var _mission: Dictionary = {}
var _auto_timer := 0.0
var _open := false

var _number: Label
var _name: Label
var _topic: Label
var _character: Label
var _task: Label
var _go: Button


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	add_child(UiKit.scrim(0.55))
	var panel := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 7, 38))
	add_child(panel)

	var m := UiKit.margin(26)
	panel.add_child(m)
	var v := UiKit.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	_number = UiKit.label("ZONE 1", 26, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(_number)

	_name = UiKit.label("", 44, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(_name)

	_topic = UiKit.label("", 27, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(_topic)

	var divider := ColorRect.new()
	divider.color = UiKit.COL_ACCENT
	divider.custom_minimum_size = Vector2(0, 4)
	v.add_child(divider)

	_character = UiKit.label("", 27, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	v.add_child(_character)

	_task = UiKit.label("", 31, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true, WRAP_WIDTH)
	_task.custom_minimum_size = Vector2(WRAP_WIDTH, 84)
	_task.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_task)

	_go = UiKit.button("GO!", UiKit.icon_texture("flame", "green", 96), Vector2(240, 92))
	_go.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.45), UiKit.COL_GREEN, 5, 26))
	_go.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.3), UiKit.COL_GREEN.lightened(0.25), 6, 26))
	_go.pressed.connect(close)
	v.add_child(_go)


## Opens the card for a zone, announcing its mission.
func open(zone_id: int, mission: Dictionary) -> void:
	_zone = GameData.zone_info(zone_id)
	_mission = mission
	_open = true
	visible = true
	modulate.a = 0.0
	_auto_timer = AUTO_CLOSE_TIME
	# Without a focused control a gamepad user sees a card whose only button is
	# unreachable; focusing GO also gives keyboard users a visible "press to
	# continue" affordance instead of having to guess that any key dismisses.
	UiKit.focus_first_button(self)

	_number.text = "ZONE %d" % zone_id
	_name.text = String(_zone.get("name_en", ""))
	_topic.text = "%s · %s" % [String(_zone.get("topic_en", "")), String(_zone.get("topic_it", ""))]
	_character.text = "You meet: " + String(_zone.get("npc", ""))
	_task.text = String(mission.get("prompt_en", ""))

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	AudioFx.speak(String(_zone.get("name_en", "")) + ". " + String(_zone.get("topic_en", "")))


func _process(delta: float) -> void:
	if not _open:
		return
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		close()


func _input(event: InputEvent) -> void:
	# A tap anywhere closes the card early: no waiting required.
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed:
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if not _open:
		return
	_open = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		visible = false
		dismissed.emit()
	)
