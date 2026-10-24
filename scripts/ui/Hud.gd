class_name Hud
extends Control
## The always-on game overlay.
##
## Layout (safe-area aware, scales with the window because it lives on a
## CanvasLayer with `canvas_items` stretch):
##   * top bar    – flames collected, zone + mission, magnifier, pause
##   * bottom     – the spoken instruction, with a speaker and a translation
##   * middle     – a gentle toast ("Well done!", "Not this one, try again")
##
## Text is never the only channel: every important word comes with a picture.

signal help_pressed
signal pause_pressed
signal repeat_audio_pressed

var _flame_label: Label
var _zone_label: Label
var _mission_label: Label
var _prompt_label: Label
var _italian_label: Label
var _toast: Label
var _toast_panel: PanelContainer
var _toast_tween: Tween
var _prompt_panel: PanelContainer
var _step_label: Label
var _hint: Label
var _word_row: HBoxContainer
var _flame_icon: TextureRect
var _help_button: Button
## The small floating tab shown while the instruction bar is folded away.
var _prompt_tab: Button
## True while the instruction bar is folded (the tab is showing instead).
var _prompt_collapsed: bool = false
## The "–" button that folds the bar, kept so it can give its focus back.
var _collapse_button: Button
## Bumped on every `show_mission()` so a pending auto-fold timer from the
## previous mission cannot fold the bar of the mission that just started.
var _prompt_token: int = 0
## True while a mission has asked for the bar to be hidden outright (a quiz,
## the mirror, the counting card). Distinct from `_prompt_collapsed`: a hidden
## bar must not leave a TASK tab behind, a folded one must.
var _prompt_suppressed: bool = false
## True while the dialogue box is covering the same strip of screen as this bar.
##
## A second reason to hide, kept apart from `_prompt_suppressed` because the two
## have different owners and different lifetimes: the *mission* owns the
## suppression (it goes away when the quiz closes) and the *level* owns this one
## (it goes away when the conversation ends). Folding them into one flag meant
## the second writer to run re-showed a bar the first had hidden — measured as
## the task bar appearing underneath the dialogue box, and as a quiz getting its
## task line back halfway through the questions.
var _dialogue_hidden: bool = false

## The prompt bar is anchored full-width with 16 px side margins and 14 px of
## inner margin, so the wrapped text is laid out at roughly this width. See
## `UiKit.label` for why wrapped labels need an explicit minimum width.
const PROMPT_WRAP_WIDTH := 1000.0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_top_bar()
	_build_prompt_panel()
	_build_toast()
	_build_hint()

	QuestManager.flames_changed.connect(_on_flames_changed)
	QuestManager.feedback.connect(show_feedback)
	QuestManager.step_changed.connect(_on_step_changed)
	# The keyword row is the one part of the HUD that depends on the difficulty
	# setting, so it redraws itself when the level changes instead of waiting for
	# the next mission. `show_mission()` is deliberately not called again: it
	# replays the prompt fade and would look like a page the child missed.
	QuestManager.difficulty_changed.connect(_on_difficulty_changed)
	# Turning the setting off while a mission is running must put the bar back
	# immediately: a child who just said "do not hide my task" cannot be asked
	# to wait for the next mission to see the result.
	QuestManager.auto_hide_ui_changed.connect(_on_auto_hide_changed)
	_set_flames(QuestManager.flames)


# --- Construction ----------------------------------------------------------

func _build_top_bar() -> void:
	var bar := UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ACCENT)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = 12
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ACCENT, 4, 26))
	add_child(bar)

	var margin := UiKit.margin(10)
	bar.add_child(margin)
	var row := UiKit.hbox(18)
	margin.add_child(row)

	# Flames
	var flame_box := UiKit.hbox(8)
	_flame_icon = TextureRect.new()
	_flame_icon.texture = UiKit.icon_texture("flame", "orange", 96)
	_flame_icon.custom_minimum_size = Vector2(52, 52)
	_flame_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flame_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flame_icon.pivot_offset = Vector2(26, 26)
	_flame_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flame_box.add_child(_flame_icon)
	_flame_label = UiKit.label("0 / 40", 32, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, false)
	flame_box.add_child(_flame_label)
	row.add_child(flame_box)

	# Zone + mission
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_label = UiKit.label("Zone 1", 20, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, false)
	_mission_label = UiKit.label("Mission 1", 28, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	info.add_child(_zone_label)
	info.add_child(_mission_label)
	row.add_child(info)

	# Step counter (quiz progress, counting progress...)
	_step_label = UiKit.label("", 24, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	row.add_child(_step_label)

	# Translation: the "Magic Italian Magnifying Glass".
	_help_button = UiKit.button("", UiKit.icon_texture("star", "purple", 96), Vector2(76, 64))
	_help_button.tooltip_text = "Magic magnifying glass (H)"
	_help_button.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_PANEL.lightened(0.12), UiKit.COL_PINK, 4, 22))
	_help_button.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_PANEL.lightened(0.22), UiKit.COL_PINK, 5, 22))
	_help_button.add_theme_stylebox_override("pressed", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_PINK, 4, 22))
	_help_button.pressed.connect(func(): help_pressed.emit())
	row.add_child(_help_button)

	# Pause
	var pause := UiKit.button("II", null, Vector2(76, 64))
	pause.add_theme_font_size_override("font_size", 30)
	pause.tooltip_text = "Pause"
	pause.pressed.connect(func(): pause_pressed.emit())
	row.add_child(pause)


func _build_prompt_panel() -> void:
	_prompt_panel = UiKit.panel(UiKit.COL_PANEL, UiKit.COL_ORANGE)
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_panel.offset_left = 16
	_prompt_panel.offset_right = -16
	_prompt_panel.offset_bottom = -12
	_prompt_panel.offset_top = -190
	_prompt_panel.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ORANGE, 5, 30))
	# The prompt bar is not a modal: it is a strip of scenery laid over the
	# world. A `PanelContainer` defaults to `MOUSE_FILTER_STOP`, and a STOP parent
	# swallows the press *before* `CameraRig._unhandled_input` can start an orbit,
	# so dragging the view from the bottom third of the screen silently did
	# nothing (measured with tools/_probe_look.gd: yaw 0.000 exactly here, while
	# every other screen area turned). `IGNORE` removes only this control from
	# picking: the speaker `Button` inside it is still picked on its own and stays
	# clickable, which is exactly the split we want.
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)

	var margin := UiKit.margin(14)
	_prompt_panel.add_child(margin)
	var row := UiKit.hbox(16)
	margin.add_child(row)

	# Speaker button: replays the spoken instruction at any time.
	var speaker := UiKit.button("", UiKit.icon_texture("speaker", "white", 96), Vector2(84, 84))
	speaker.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.COL_BLUE.darkened(0.3), UiKit.COL_BLUE, 4, 24))
	speaker.add_theme_stylebox_override("hover", UiKit.panel_style(UiKit.COL_BLUE.darkened(0.15), UiKit.COL_BLUE.lightened(0.2), 5, 24))
	speaker.add_theme_stylebox_override("pressed", UiKit.panel_style(UiKit.COL_BLUE.darkened(0.4), UiKit.COL_BLUE, 4, 24))
	speaker.tooltip_text = "Listen again"
	speaker.pressed.connect(func(): repeat_audio_pressed.emit())
	row.add_child(speaker)

	var text_box := UiKit.vbox(2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_label = UiKit.label("", 33, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true, PROMPT_WRAP_WIDTH)
	_italian_label = UiKit.label("", 26, UiKit.COL_PINK, HORIZONTAL_ALIGNMENT_LEFT, true, PROMPT_WRAP_WIDTH)
	_italian_label.visible = false
	text_box.add_child(_prompt_label)
	text_box.add_child(_italian_label)

	# Picture-word row: the key words of the mission, each with its icon.
	_word_row = UiKit.hbox(10)
	text_box.add_child(_word_row)
	row.add_child(text_box)

	# --- Fold button ---------------------------------------------------------
	# The bar is wide and sits over the bottom third of the world, which is
	# exactly where the candies of "find five orange ones" tend to lie. One
	# press folds it into a small tab; the tab brings it back.
	_collapse_button = UiKit.button("–", null, Vector2(54, 84))
	_collapse_button.add_theme_font_size_override("font_size", 30)
	_collapse_button.tooltip_text = "Hide the task bar"
	_collapse_button.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.12), UiKit.COL_ORANGE.darkened(0.35), 4, 24))
	_collapse_button.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.12), UiKit.COL_ORANGE, 5, 24))
	_collapse_button.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.2), UiKit.COL_ORANGE.darkened(0.2), 4, 24))
	_collapse_button.pressed.connect(collapse_prompt)
	row.add_child(_collapse_button)

	# --- The tab left behind when the bar is folded --------------------------
	# Anchored to the bottom-left corner with the same margins the bar uses, so
	# it reads as the folded remains of the bar rather than as a new control.
	_prompt_tab = UiKit.button("TASK", UiKit.icon_texture("star", "orange", 64), Vector2(168, 52))
	_prompt_tab.add_theme_font_size_override("font_size", 22)
	_prompt_tab.tooltip_text = "Show the task again"
	_prompt_tab.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_prompt_tab.offset_left = 16
	_prompt_tab.offset_right = 184
	_prompt_tab.offset_top = -64
	_prompt_tab.offset_bottom = -12
	_prompt_tab.add_theme_stylebox_override("normal",
		UiKit.panel_style(UiKit.COL_PANEL, UiKit.COL_ORANGE, 4, 24))
	_prompt_tab.add_theme_stylebox_override("hover",
		UiKit.panel_style(UiKit.COL_PANEL.lightened(0.14), UiKit.COL_ORANGE.lightened(0.25), 5, 24))
	_prompt_tab.add_theme_stylebox_override("pressed",
		UiKit.panel_style(UiKit.COL_PANEL.darkened(0.08), UiKit.COL_ORANGE, 4, 24))
	_prompt_tab.visible = false
	_prompt_tab.pressed.connect(expand_prompt)
	add_child(_prompt_tab)


func _build_toast() -> void:
	_toast_panel = UiKit.panel(UiKit.COL_GREEN.darkened(0.55), UiKit.COL_GREEN)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_top = 130
	_toast_panel.offset_left = -260
	_toast_panel.offset_right = 260
	_toast_panel.offset_bottom = 50
	_toast_panel.modulate.a = 0.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_panel)

	var m := UiKit.margin(14)
	_toast_panel.add_child(m)
	_toast = UiKit.label("", 33, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true, 480.0)
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(_toast)


func _build_hint() -> void:
	_hint = UiKit.label("", 23, UiKit.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true, 620.0)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -220
	_hint.offset_left = -320
	_hint.offset_right = 320
	_hint.offset_bottom = -198
	add_child(_hint)


# --- Public API ------------------------------------------------------------

## Shows a mission: header, prompt and the icon row for its keywords.
##
## A bonus challenge is announced as itself ("CHALLENGE 3/20"), not as mission
## 41/40. The story counter is the number in the game's title, and printing
## "101/40" above a task would be the kind of detail a seven-year-old notices
## immediately and a teacher then has to explain.
func show_mission(mission: Dictionary, zone: Dictionary) -> void:
	_zone_label.text = "Zone %d · %s" % [int(zone.get("id", 1)), String(zone.get("short_en", ""))]
	if mission.has("extra_index"):
		_mission_label.text = "Challenge %d/%d · %s" % [
			int(mission["extra_index"]), GameData.EXTRA_CHALLENGES.size(), String(mission.get("title", ""))]
	else:
		_mission_label.text = "%d/%d · %s" % [int(mission.get("id", 1)), 40, String(mission.get("title", ""))]
	_prompt_label.text = String(mission.get("prompt_en", ""))
	_italian_label.text = String(mission.get("prompt_it", ""))
	_italian_label.visible = false
	_set_step_text("")
	_build_word_row(mission)
	# Every new mission starts with the bar open: a folded bar handed down from
	# the previous mission would hide the sentence that just changed.
	_prompt_token += 1
	_prompt_collapsed = false
	_prompt_suppressed = false
	# A new mission starts with whatever conversation was open already closed by
	# the level, so the dialogue half of the visibility rule is cleared here as
	# well. Leaving it set would keep the bar invisible until the next
	# conversation opened and closed again.
	_dialogue_hidden = false
	_apply_prompt_visibility()
	_prompt_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.3)
	# Fire-and-forget: `_schedule_auto_fold` awaits its own timer, so awaiting it
	# here would stall the caller (the level) for five seconds.
	_schedule_auto_fold(_prompt_token)


## Hides the instruction bar (used during quizzes, which have their own panel).
##
## A folded bar is remembered: when the quiz closes and asks for the bar back,
## a bar the child had folded stays folded and only the tab returns, so the
## quiz cannot undo a choice the child made.
func set_prompt_visible(value: bool) -> void:
	_prompt_suppressed = not value
	_apply_prompt_visibility()
	# The bar comes back when the quiz closes, so the auto-fold has to be armed
	# again: otherwise a mission made only of quizzes would keep its task bar
	# open for ever, which is the exact complaint this feature answers.
	if value:
		_prompt_token += 1
		_schedule_auto_fold(_prompt_token)


## The dialogue box is (or is no longer) covering the strip this bar sits in.
##
## The geometry, measured with `tools/overlap_check.gd` at the design size: the
## bar occupies y 530..708 of 720 and the dialogue box y 384..684, so they share
## 154 px — the bar is *entirely* behind the box, and its speaker button and task
## line both sit underneath a panel that ignores the mouse. Nothing of it is
## readable, so nothing of it should be shown: a task line peeking out under a
## dialogue reads as two messages talking at once, which is what the class
## described as "le quest si accavallano".
##
## Handled here rather than by `set_prompt_visible(false)` because the two
## reasons must be able to coexist: a quiz that opens while a dialogue is up must
## not be able to re-show the bar when it closes, and a conversation that ends
## during a quiz must not put the bar back over the question.
func set_dialogue_hidden(hidden: bool) -> void:
	if hidden == _dialogue_hidden:
		return
	_dialogue_hidden = hidden
	_apply_prompt_visibility()


## Single place that decides whether the bar is on screen.
func _apply_prompt_visibility() -> void:
	var show_bar := not _prompt_suppressed and not _dialogue_hidden and not _prompt_collapsed
	if _prompt_panel != null:
		_prompt_panel.visible = show_bar
	# A quiz hides the bar outright: the tab must not appear next to it, or the
	# child would tap it and get a task line printed over the question. Talking
	# to the character is not that case — the bar is only *out of the way*, so
	# the TASK tab keeps its place and the sentence stays one tap away.
	if _prompt_tab != null:
		_prompt_tab.visible = not _prompt_suppressed and _prompt_collapsed


## Folds the instruction bar into its small tab.
##
## The bar stays in the tree: folding only changes visibility, so `show_mission()`
## can put the same node back without rebuilding any of its children and the
## speaker button keeps its connections.
func collapse_prompt() -> void:
	if _prompt_collapsed:
		return
	# A panel that owns the screen (a quiz, the mirror) has already taken the
	# bar away. Folding now would leave a TASK tab floating over its cards.
	if _prompt_suppressed:
		return
	_prompt_collapsed = true
	# The fold button is about to disappear under the pointer, so the focus has
	# to move with it. A hidden `Button` that still owns the focus keeps
	# `ui_accept` and the child's next A press would land nowhere.
	if _collapse_button != null and _collapse_button.has_focus():
		_collapse_button.release_focus()
	_apply_prompt_visibility()
	# The contextual hint line sits just above the bar. With the bar gone it
	# would hang in mid-air pointing at nothing, so it drops into the space the
	# bar has just freed — that also keeps it clear of the TASK tab.
	if _hint != null:
		_hint.offset_top = -58
		_hint.offset_bottom = -36


## Unfolds the instruction bar and takes the tab away.
func expand_prompt() -> void:
	if not _prompt_collapsed:
		return
	_prompt_collapsed = false
	# A bar the mission has taken away stays away: the TASK tab is not allowed
	# to pop a task line over a quiz that is asking a question. `_apply_...`
	# holds that rule, together with the dialogue box's own hiding.
	_apply_prompt_visibility()
	# Put the hint line back over the bar it belongs to.
	if _hint != null:
		_hint.offset_top = -220
		_hint.offset_bottom = -198


func is_prompt_collapsed() -> bool:
	return _prompt_collapsed


## True when a screen point lands on a HUD control that owns the pointer.
##
## `Level._input` sees the press *before* the GUI consumes it, so without this
## check a tap on the folded TASK tab would also raycast the world behind it and
## pick up whatever prop happened to sit there — the bar itself used to be
## `MOUSE_FILTER_IGNORE` for look-dragging, and the small tab cannot be.
func blocks_point(at: Vector2) -> bool:
	if _prompt_tab == null or not _prompt_tab.visible:
		return false
	return _prompt_tab.get_global_rect().has_point(at)


## Seconds the instruction bar stays open before folding itself away, when the
## `auto_hide_ui` setting is on. See `_schedule_auto_fold()` for the reasoning.
##
## Named rather than written at the call site because it is tuned against the
## *length of the spoken task*: when the voice pack was re-recorded at half speed
## for 1.0.5 every clip doubled, and this is the number that had to double with
## it. A literal in the middle of an `await` is easy to miss when the next
## recording happens.
const AUTO_FOLD_TIME := 10.0

## Folds the bar after the child has had time to read it, when the setting is on.
##
## The delay is the whole design of this feature: folding the bar the instant a
## mission starts would hide the task before anybody read it, which is worse
## than covering the world. Ten seconds is about two readings of a one-line
## prompt at this reading level *and* one full hearing of it: the recorded voice
## was slowed to half speed for 1.0.5, which doubled the length of every clip the
## game speaks, so the five seconds this used to be would have started folding
## the bar while the task was still being said. The tab stays on screen the whole
## time, so nothing is lost — the child can bring the sentence back with one
## press.
##
## `token` guards against the obvious race: a mission can be solved and the next
## one started inside those ten seconds (`--smoke` does it forty times in a row),
## and a timer left over from the previous mission would fold the new bar while
## the child was still reading it.
func _schedule_auto_fold(token: int) -> void:
	if not QuestManager.auto_hide_ui:
		expand_prompt()
		return
	await get_tree().create_timer(AUTO_FOLD_TIME).timeout
	if not is_inside_tree() or token != _prompt_token:
		return
	collapse_prompt()


## Updates the small counter on the right of the top bar.
func set_step_text(text: String) -> void:
	_set_step_text(text)


func _set_step_text(text: String) -> void:
	if _step_label != null:
		_step_label.text = text


## Small contextual line above the prompt ("Walk with W A S D", "Tap a prop"...).
func hint_set(text: String) -> void:
	if _hint != null:
		_hint.text = text


## Big, friendly message. `kind` picks the colour: success / gentle / info.
func show_feedback(text_en: String, text_it: String = "", kind: String = "success") -> void:
	if _toast == null:
		return
	_toast.text = text_en
	var fill := UiKit.COL_GREEN.darkened(0.55)
	var border := UiKit.COL_GREEN
	match kind:
		"gentle":
			fill = UiKit.COL_SOFT_RED.darkened(0.62)
			border = UiKit.COL_SOFT_RED
		"info":
			fill = UiKit.COL_PANEL
			border = UiKit.COL_ACCENT
	_toast_panel.add_theme_stylebox_override("panel", UiKit.panel_style(fill, border, 5, 26))
	_toast_panel.modulate.a = 0.0
	_toast_panel.pivot_offset = _toast_panel.size * 0.5
	_toast_panel.scale = Vector2(0.92, 0.92)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(1.6)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.35)


## Turns on the Italian translation under the English sentence.
func reveal_translation(show_it: bool) -> void:
	if _italian_label != null:
		_italian_label.visible = show_it


func is_translation_visible() -> bool:
	return _italian_label != null and _italian_label.visible


func _on_flames_changed(flames: int) -> void:
	_set_flames(flames)
	# The flame counter pulses on every gain so the reward is felt.
	var tween := create_tween()
	tween.tween_property(_flame_icon, "scale", Vector2(1.35, 1.35), 0.12)
	tween.tween_property(_flame_icon, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK)


func _set_flames(flames: int) -> void:
	if _flame_label != null:
		_flame_label.text = "%d / %d" % [flames, QuestManager.TOTAL_FLAMES]


func _on_step_changed(step: int, total: int) -> void:
	_set_step_text("%d / %d" % [step, total])


## The difficulty arrows were used: only the keyword chips change, so the HUD
## rebuilds just that row. Guarded on the row still being in the tree because
## `Hud` is freed and rebuilt when the easy-read font changes.
func _on_difficulty_changed(_level: int) -> void:
	if _word_row != null and is_instance_valid(_word_row):
		_build_word_row(QuestManager.current_mission())


## The auto-hide switch was moved. Off unfolds the bar at once (and cancels any
## pending fold, by bumping the token); on arms the timer again for the mission
## that is running, so a teacher who turns it back on does not have to finish
## the mission to see it work.
func _on_auto_hide_changed(enabled: bool) -> void:
	_prompt_token += 1
	if enabled:
		_schedule_auto_fold(_prompt_token)
	else:
		expand_prompt()


## Builds the picture-word row for the key words of a mission.
##
## The row is a *prompt* aid, so the difficulty setting decides how much of it
## survives (`Hints` does the deciding, so the HUD, the quiz and the story page
## can never disagree):
##   * level 1 — picture + word, so a child can decode "green" from the swatch
##     next to it without knowing the word;
##   * level 2 — the word alone, so the colour has to be known;
##   * level 3 — the row is hidden entirely and the spoken instruction is the
##     only clue left. That is still not a dead end: the task stays visible in
##     the prompt bar above and can be heard again with the speaker button.
func _build_word_row(mission: Dictionary) -> void:
	for child in _word_row.get_children():
		_word_row.remove_child(child)
		child.queue_free()
	if not Hints.prompt_shows_keywords():
		_word_row.visible = false
		return
	var words: Array = []
	if mission.has("targets"):
		for t in mission["targets"]:
			var word := String(t.get("word", ""))
			if word.is_empty():
				continue
			words.append({
				"word": word.to_upper(),
				"icon": String(t.get("kind", "circle")),
				"color": String(t.get("color", "orange")),
				"number": int(t.get("number", 0)),
			})
	elif mission.has("lines"):
		for line in mission["lines"]:
			words.append({"word": String(line.get("en", "")), "icon": "ghost", "color": "white", "number": 0})
	elif mission.has("requirements"):
		for r in mission["requirements"]:
			words.append({
				"word": str(r.get("count", 1)) + " x " + String(r.get("word", "")).to_upper(),
				"icon": String(r.get("kind", "circle")),
				"color": String(r.get("color", "orange")),
				"number": 0,
			})
	if words.is_empty():
		_word_row.visible = false
		return
	_word_row.visible = true
	# Level 1 gives the picture; from level 2 the chip is the word alone.
	var with_icons := Hints.word_chips_have_icons()
	# Cap at five cards so the bar never overflows on a small window.
	for i in mini(words.size(), 5):
		var w: Dictionary = words[i]
		var chip := UiKit.hbox(8)
		if with_icons:
			var icon := TextureRect.new()
			icon.texture = UiKit.icon_texture(String(w["icon"]), String(w["color"]), 80, int(w["number"]))
			icon.custom_minimum_size = Vector2(44, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(icon)
		# One- or two-word chips: wrapping here would collapse the chip to a
		# one-pixel column and stack the letters vertically.
		chip.add_child(UiKit.label(String(w["word"]), 23,
			UiKit.COL_ACCENT if with_icons else UiKit.COL_ACCENT.lightened(0.25),
			HORIZONTAL_ALIGNMENT_LEFT, false))
		_word_row.add_child(chip)
