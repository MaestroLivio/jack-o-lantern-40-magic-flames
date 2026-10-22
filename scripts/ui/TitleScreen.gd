class_name TitleScreen
extends Control
## The title screen: a big friendly invitation to play.
##
## Shows Jack, the story in one short sentence, and two buttons (PLAY and
## CONTINUE). CONTINUE only appears when there is a save to continue.

signal start_pressed
signal continue_pressed
signal settings_pressed
## Opens the list of the twenty bonus challenges. Separate from PLAY because
## these are not part of the forty-flame story and must never look like it.
signal challenges_pressed

## Side and top margins of the title layout. The screen stacks an emblem, three
## lines of text, a button row and a credit line; their combined minimum height
## is a little over 500 px, which leaves room to spare inside the 720 px design
## height. `tools/layout_check.gd` asserts that this stays true.
const SIDE_MARGIN := 80.0
const TOP_MARGIN := 24.0

var _title: Label
var _subtitle: Label
var _flames: Label
var _continue_button: Button


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_theme_background()
	visible = false


func _theme_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.03, 0.11, 0.86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var v := UiKit.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = SIDE_MARGIN
	v.offset_right = -SIDE_MARGIN
	v.offset_top = TOP_MARGIN
	v.offset_bottom = -TOP_MARGIN
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)

	# Pumpkin emblem
	var emblem := TextureRect.new()
	emblem.texture = UiKit.icon_texture("pumpkin", "orange", 220)
	emblem.custom_minimum_size = Vector2(96, 96)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(emblem)

	_title = UiKit.label("JACK-O'-LANTERN", 60, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color("3b1d00"))
	v.add_child(_title)

	_subtitle = UiKit.label("The 40 Magic Flames", 34, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(_subtitle)

	var hook := UiKit.label("Help Jack light his lantern for the Grand Halloween Party!", 25,
		UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, 900.0)
	v.add_child(hook)

	_flames = UiKit.label("", 24, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(_flames)

	var row := UiKit.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)

	var play := UiKit.button("PLAY", UiKit.icon_texture("flame", "orange", 96), Vector2(300, 100))
	play.add_theme_font_size_override("font_size", 40)
	play.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.45), UiKit.COL_GREEN, 6, 30))
	play.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.3), UiKit.COL_GREEN.lightened(0.25), 7, 30))
	play.add_theme_stylebox_override("pressed", UiKit.panel_style(UiKit.COL_GREEN.darkened(0.55), UiKit.COL_GREEN, 6, 30))
	play.pressed.connect(func(): start_pressed.emit())
	row.add_child(play)

	_continue_button = UiKit.button("CONTINUE", null, Vector2(300, 100))
	_continue_button.add_theme_font_size_override("font_size", 36)
	_continue_button.pressed.connect(func(): continue_pressed.emit())
	row.add_child(_continue_button)

	# SETTINGS and CHALLENGES share one row instead of stacking. The title layout
	# is already within ~100 px of the 720 px design height (the layout probe
	# measures it), and a fourth full-width button would push the credit line
	# off the bottom on a 16:10 projector.
	var options := UiKit.hbox(20)
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(options)

	var settings := UiKit.button("SETTINGS", null, Vector2(240, 72))
	settings.pressed.connect(func(): settings_pressed.emit())
	options.add_child(settings)

	# The bonus challenges are reachable from the very first screen, not only
	# after the story: a class that has already played can open it on day one,
	# and a teacher can use challenge 6 as today's exercise without walking
	# through forty missions first.
	var challenges := UiKit.button("CHALLENGES", null, Vector2(260, 72))
	challenges.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.06), UiKit.COL_PINK, 5, 24))
	challenges.tooltip_text = "Twenty bonus puzzles with no glowing squares"
	challenges.pressed.connect(func(): challenges_pressed.emit())
	options.add_child(challenges)

	var credits := UiKit.label("Per la Seconda Primaria · English pre-A1", 20, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, false)
	v.add_child(credits)


## Shows the title screen with the current save state.
func open(flames: int) -> void:
	visible = true
	_flames.text = "%d / 40 magic flames collected" % flames
	_continue_button.visible = flames > 0
	modulate.a = 0.0
	# With a gamepad (or Tab) there is no pointer: PLAY must already be focused
	# or the first screen of the game is unusable.
	UiKit.focus_first_button(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func close() -> void:
	visible = false
