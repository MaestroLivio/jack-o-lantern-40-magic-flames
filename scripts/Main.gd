class_name Main
extends Node
## Entry point. Owns the screen flow:
##
##     title -> zone_intro -> story -> playing  <-> pause
##                                        |
##                                        +-> ending (after mission 40)
##
## `story` only appears before the eight missions that open a chapter (see
## `Story.CHAPTERS`): the narration is a page to read together, never a timer.
## The 3D level lives under `GameLayer` and stays in the tree; menus are 2D
## layers that come and go, so the world keeps its state while a child pauses.

## Screens in the flow.
enum Screen { TITLE, ZONE_INTRO, PLAYING, PAUSE, ENDING, STORY, CHALLENGES }

@export var start_at_title: bool = true

var screen: Screen = Screen.TITLE

var game_layer: Node3D
var ui_layer: CanvasLayer
var menu_layer: CanvasLayer

var level: Level
var hud: Hud
## On-screen D-pad for touch screens, drawn *above* the HUD (same `CanvasLayer`,
## added afterwards). Separate from `Hud` rather than a child of it because the
## two have nothing to say to each other and very different lifetimes: the HUD
## is rebuilt whenever the font setting changes, the pad only when the setting
## or the fold state does. See `scripts/ui/TouchControls.gd`.
var touch_pad: TouchControls
var zone_intro: ZoneIntroCard
var title_screen: TitleScreen
var pause_menu: PauseMenu
## The key-rebinding page, opened from the pause menu (and from the title's
## settings button). It is a sibling of the pause menu on the same layer, so it
## draws on top of it without touching the 3D world.
var controls_panel: ControlsPanel
var sound_panel: SoundPanel
## The teacher's page: all forty missions, jump to any of them. A sibling of the
## pause menu on the same layer, opened from the bottom of it, and hidden rather
## than freed while open so its forty buttons stay out of the focus chain.
var teacher_menu: TeacherMenu
## True while `_quit_cleanly()` is winding down, so the shutdown cannot start twice.
var _quitting := false
## The story page shown between missions. Like the other menus it is built once
## and reused, so the chapter text is only laid out when a chapter actually
## opens (and the layout probe can measure it like any other page).
var story_screen: StoryScreen
var ending_screen: EndingScreen
## The list of the forty bonus challenges. Built once and reused, like the other
## menus, so its buttons exist for the layout probe whether or not it is open.
var challenge_hub: ChallengeHub
## Set when the challenge list was opened from the teacher's page, so BACK goes
## to the pause menu (where the teacher came from) instead of falling through to
## the title screen. Cleared as soon as the list is closed one way or another, so
## the flag can never leak into a later visit.
var _challenges_back_to_pause := false

var _previous_amount := 0

## Story pages waiting to be read. A queue (rather than a single chapter) means
## the prologue and the first zone's chapter can both be read at the start of a
## new game without the screen flow needing to know about either of them.
var _story_queue: Array[Dictionary] = []
## Mission ids whose chapter (or beat) has already been read this session. A
## child who pauses, restarts a mission or walks back into a zone must not have
## the same page pushed in front of them again.
var _story_shown: Array[int] = []
## Set to false by the QA tools (`tools/layout_check.gd`), which drive missions
## back to back and would otherwise have a story page land on top of the panel
## they are measuring. The real game always leaves it true.
var story_enabled := true


func _ready() -> void:
	# See `_notification`: the close button has to be handled by us so the music
	# player is stopped while the tree still exists.
	get_tree().auto_accept_quit = false
	_build_layers()
	_build_level()
	_build_hud()
	_build_touch_pad()
	_build_menus()
	_connect_signals()

	# Sound setting from the save file.
	QuestManager.set_sound(QuestManager.sound_on)

	if start_at_title:
		show_title()
	else:
		begin_playing()

	# Developer hook: `godot --headless --path . -- --smoke` walks every one of
	# the 40 missions automatically and prints the result. It is used to check
	# that no mission crashes without playing the whole game by hand.
	# `-- --smoke --autoplay` additionally solves each mission.
	# `-- --smoke --autoplay --extra` walks the forty bonus challenges instead
	# of the story: they are a separate list with a separate flow
	# (`QuestManager.start_extra`), so the story harness would never build them.
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke"):
		_run_smoke_test(args.has("--autoplay"), args.has("--extra"))


## Automated walk-through of the 40 story missions, or of the 20 bonus challenges
## with `extra` (developer/QA helper).
##
## The two flows are separate on purpose: the story is walked with
## `start_mission(id)`, the bonus challenges with `start_extra(index)`, and a
## harness that only knew the first would never build a single bonus room.
func _run_smoke_test(autoplay: bool = false, extra: bool = false) -> void:
	await get_tree().create_timer(0.6).timeout
	# The harness drives the mission sequence itself, so the level must not
	# also advance after each flame.
	QuestManager.auto_advance = false
	# ...and it must not write any of that to the child's save file: the harness
	# solves all 40 missions, which would otherwise leave the machine believing
	# the game is finished.
	QuestManager.persist = false
	title_screen.close()
	screen = Screen.PLAYING
	_set_gameplay_active(true)
	var ids: Array = []
	if extra:
		for i in range(1, GameData.EXTRA_CHALLENGES.size() + 1):
			ids.append(i)
	else:
		for m in GameData.missions():
			ids.append(int(m["id"]))
	var failures := 0
	var solved := 0
	for key in ids:
		# The same loop walks both lists. `key` is a story mission id or a bonus
		# index; `mission` is the dictionary either way, and `_autoplay_mission()`
		# drives the controller from that dictionary rather than from a list.
		var mission: Dictionary
		var label: String
		if extra:
			# `start_extra()` also sets `current_zone` from the mission, which is
			# what makes the level rebuild the right world for it.
			QuestManager.start_extra(int(key))
			mission = GameData.extra_mission(int(key))
			label = "challenge"
		else:
			QuestManager.start_mission(int(key))
			mission = GameData.mission(int(key))
			label = "mission"
		# Zone changes fade the world out and in (about 1s), so wait for the
		# transition to settle before inspecting the spawned controller.
		await get_tree().create_timer(1.2).timeout
		var mechanic := String(mission.get("mechanic", "?"))
		if level.mission_controller == null:
			failures += 1
			print("SMOKE FAIL %s %d (%s): no controller" % [label, int(key), mechanic])
			continue
		print("SMOKE OK %-9s %02d  mechanic=%-12s zone=%d  props=%d" % [
			label, int(key), mechanic, int(mission.get("zone", 1)),
			level.mission_controller.get_child_count(),
		])
		if autoplay:
			var ok: bool = await _autoplay_mission(mission, mechanic)
			if ok:
				solved += 1
			else:
				failures += 1
				print("SMOKE FAIL %s %d (%s): could not be solved" % [label, int(key), mechanic])
		QuestManager.busy = false
		if level.mission_controller != null:
			level.mission_controller.cleanup()
			level.mission_controller.queue_free()
			level.mission_controller = null
		# Keep the save file clean between iterations. In the bonus flow the
		# tally lives in `extra_completed`, which is a saved field: leaving it
		# filled would make the hub think twenty puzzles were already solved.
		QuestManager.completed_missions.clear()
		QuestManager.flames = 0
		QuestManager.extra_completed.clear()
	var heading := "EXTRA RESULT" if extra else "SMOKE RESULT"
	var noun := "challenges" if extra else "missions"
	print("%s: %d / %d %s built, %d solved, %d failures" % [
		heading, ids.size() - failures, ids.size(), noun, solved, failures,
	])
	# Let the last success jingle finish before tearing the tree down. Godot
	# reports "ObjectDB instances were leaked" when a WAV is still playing at
	# shutdown: the playback object holds its stream, and the audio server only
	# releases it on a *mix pass*. Waiting two frames was not enough — the mix
	# pass runs on the audio thread at a fixed rate, so at 144 fps two frames can
	# be shorter than one mix. A real timer is the only thing that is independent
	# of the frame rate, which is why this waits on seconds and not on frames.
	AudioFx.stop_sfx()
	# Same reason as the effects, for the music: the title theme is still
	# playing when the harness decides to quit (the run starts on the title
	# screen), and a stream that is still playing at shutdown is what Godot
	# reports as a leaked `AudioStreamPlaybackOggVorbis` and as
	# "resource still in use". Stopping without a fade: a tween would not get
	# the chance to run at all.
	Music.stop_now()
	# And the voice: every sentence the smoke run spoke left its `.ogg` in
	# `AudioFx._voice_clip_cache`, which is a live resource per clip. Once the
	# voice pack is in the project that cache holds the whole corpus, and Godot
	# reports all of it as "resources still in use at exit". Dropping it here is
	# what keeps the packaged build's log clean, the same way `stop_now()` does
	# for the music.
	AudioFx.release_cache()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if failures > 0 else 0)



func _build_layers() -> void:
	game_layer = Node3D.new()
	game_layer.name = "GameLayer"
	add_child(game_layer)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UiLayer"
	ui_layer.layer = 10
	add_child(ui_layer)

	menu_layer = CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	menu_layer.layer = 20
	add_child(menu_layer)


func _build_level() -> void:
	level = Level.new()
	level.name = "Level"
	game_layer.add_child(level)


func _build_hud() -> void:
	hud = Hud.new()
	hud.name = "Hud"
	ui_layer.add_child(hud)
	hud.help_pressed.connect(_on_help)
	hud.pause_pressed.connect(_on_pause)
	hud.repeat_audio_pressed.connect(_on_repeat_audio)
	level.hud = hud


## Builds the touch overlay. Called right after `_build_hud()` so it is the
## later sibling and therefore drawn on top: the pad is a set of buttons that
## must stay pressable, while the HUD is scenery the child reads.
##
## It is built unconditionally, even when the setting is off, because the
## setting can be turned on from the pause menu *during* a mission and a pad
## that only exists after the next zone load would look broken. `_ready()` on
## the node hides it when the setting says so, which costs one hidden `Control`
## and saves a rebuild path that would have to be duplicated in `_rebuild_ui()`.
func _build_touch_pad() -> void:
	touch_pad = TouchControls.new()
	touch_pad.name = "TouchControls"
	ui_layer.add_child(touch_pad)
	touch_pad.set_gameplay_active(screen == Screen.PLAYING)
	# The level needs this reference for one reason only: a press on the pad must
	# not also raycast the world behind it. See `Level._try_click()`.
	level.touch_pad = touch_pad


func _build_menus() -> void:
	title_screen = TitleScreen.new()
	title_screen.name = "TitleScreen"
	menu_layer.add_child(title_screen)
	title_screen.start_pressed.connect(_on_title_start)
	title_screen.continue_pressed.connect(_on_title_continue)
	title_screen.settings_pressed.connect(_on_title_settings)
	title_screen.challenges_pressed.connect(_on_title_challenges)

	zone_intro = ZoneIntroCard.new()
	zone_intro.name = "ZoneIntro"
	menu_layer.add_child(zone_intro)
	zone_intro.dismissed.connect(_on_intro_dismissed)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	menu_layer.add_child(pause_menu)
	_connect_pause_menu()

	# The story page sits between the zone card and the mission itself. It is
	# the largest page in the game, so it is also the one the layout probe
	# (`tools/layout_check.gd`) needs to be able to measure on demand.
	story_screen = StoryScreen.new()
	story_screen.name = "StoryScreen"
	menu_layer.add_child(story_screen)
	story_screen.finished.connect(_on_story_finished)

	controls_panel = ControlsPanel.new()
	controls_panel.name = "ControlsPanel"
	menu_layer.add_child(controls_panel)
	controls_panel.back_pressed.connect(_on_controls_back)

	# The two volume levels get their own page: the pause screen has no room
	# left for two more rows without shrinking KEEP PLAYING (see SoundPanel).
	sound_panel = SoundPanel.new()
	sound_panel.name = "SoundPanel"
	menu_layer.add_child(sound_panel)
	_connect_sound_panel()

	ending_screen = EndingScreen.new()
	ending_screen.name = "EndingScreen"
	menu_layer.add_child(ending_screen)
	ending_screen.play_again_pressed.connect(_on_play_again)
	# The ending offers the challenges too: by then the class has done the
	# whole story, so "you can keep playing" belongs on the last page rather
	# than only on the title screen they may never go back to.
	ending_screen.challenges_pressed.connect(_on_title_challenges)

	challenge_hub = ChallengeHub.new()
	challenge_hub.name = "ChallengeHub"
	menu_layer.add_child(challenge_hub)
	challenge_hub.challenge_pressed.connect(_on_challenge_pressed)
	challenge_hub.back_pressed.connect(_on_challenges_back)

	# The teacher's page. Built with everything else so the layout probe can
	# measure its forty entries whether or not a teacher has opened it.
	teacher_menu = TeacherMenu.new()
	teacher_menu.name = "TeacherMenu"
	menu_layer.add_child(teacher_menu)
	teacher_menu.mission_pressed.connect(_on_teacher_mission)
	teacher_menu.challenges_pressed.connect(_on_teacher_challenges)
	teacher_menu.back_pressed.connect(_on_teacher_back)


## Wires the pause menu's signals. Shared by `_build_menus()` and `_rebuild_ui()`
## because the easy-read toggle recreates the menu from scratch: a signal that
## was only connected in one of the two places would silently stop working for
## the rest of the session.
func _connect_pause_menu() -> void:
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.help_pressed.connect(_on_help)
	pause_menu.quit_pressed.connect(_on_quit)
	pause_menu.restart_zone_pressed.connect(_on_restart_zone)
	pause_menu.controls_pressed.connect(_on_controls)
	pause_menu.easy_read_changed.connect(_on_easy_read_changed)
	pause_menu.sound_changed.connect(_on_sound_changed)
	pause_menu.difficulty_pressed.connect(_on_difficulty)
	pause_menu.sound_settings_pressed.connect(_on_sound_settings)
	pause_menu.teacher_pressed.connect(_on_teacher)


## Wires the volume page. Shared by both build paths for the same reason as
## `_connect_pause_menu()`: a page recreated with no connections looks fine and
## silently ignores every press.
func _connect_sound_panel() -> void:
	sound_panel.back_pressed.connect(_on_sound_back)
	# The page applies the change itself through QuestManager; this listener is
	# what lets the pause menu and the HUD redraw anything that shows a level.
	sound_panel.volume_changed.connect(_on_volume_changed)
	# The VIEW row is different: `QuestManager` emits `camera_mode_changed`, and
	# `Level` is the listener that actually moves the camera. Main only needs to
	# know because the pause menu's summary line mentions the view.
	sound_panel.camera_mode_changed.connect(_on_camera_mode_changed)


func _connect_signals() -> void:
	QuestManager.level_transition_requested.connect(_on_zone_changed)
	QuestManager.all_missions_completed.connect(_on_all_completed)
	# Finishing a bonus challenge returns to the challenge list instead of
	# walking into the next one. `QuestManager` decides *when*, this decides
	# *where*: only `Main` knows what a screen is.
	QuestManager.extra_return_requested.connect(_on_extra_return)
	# A story *beat* (missions 4, 8, 16, 24, 32) lands in the middle of a zone,
	# where no zone card is shown, so `_on_intro_dismissed()` is never reached.
	# Listening to the mission itself is what lets those pages exist at all.
	QuestManager.mission_started.connect(_on_story_mission_started)


# --- Screen flow -----------------------------------------------------------

func show_title() -> void:
	screen = Screen.TITLE
	Music.play_track("title")
	title_screen.open(QuestManager.flames)
	_set_gameplay_active(false)


func begin_playing() -> void:
	title_screen.close()
	_queue_prologue()
	var zone_id: int = QuestManager.current_zone
	var mission: Dictionary = QuestManager.current_mission()
	# A zone card introduces each biome the first time the child enters it,
	# including on "Continue", so they always know where they are.
	_show_zone_intro(zone_id, mission)


## The prologue is the only page in the book that belongs to no mission (it is
## keyed `mission: 0`), so `Story.chapter_for()` can never return it. It is
## pushed onto the queue instead, and `_on_intro_dismissed()` reads the queue
## before it looks for a chapter: the class hears *why* Jack needs forty flames,
## then *where* he is standing, and only then gets the first task.
##
## Only at the very beginning (`mission <= 1`), so a child who continues an
## existing game is not made to sit through the opening again.
func _queue_prologue() -> void:
	if _story_shown.has(0) or QuestManager.current_mission_id > 1:
		return
	var prologue := Story.chapter_for(0)
	if not prologue.is_empty():
		_story_queue.append(prologue)


func _show_zone_intro(zone_id: int, mission: Dictionary) -> void:
	# The zone card is shown *before* the story page: it places the class in a
	# biome, then the chapter tells them what is happening there. A story page
	# that arrived first would talk about a place nobody has seen yet.
	#
	# The zone's theme starts here, on the card, rather than when the child is
	# let into the room: arriving to a silent pumpkin patch and hearing music
	# begin a second later reads as a glitch, and the card is the one moment where
	# nothing else is asking for attention. `play_track()` ignores a request for
	# the track already playing, so re-entering the same zone mid-way through
	# does not restart it.
	Music.play_zone(zone_id)
	screen = Screen.ZONE_INTRO
	_set_gameplay_active(false)
	zone_intro.open(zone_id, mission)


## The zone card is gone: hand over to a queued page (the prologue), then to the
## story page when this mission opens a chapter, otherwise start playing.
##
## A story page is only ever shown when the game is advancing by itself
## (`QuestManager.auto_advance`). The QA harness turns that flag off and drives
## all 40 missions back to back; a modal page appearing in the middle of that run
## would sit unread on top of the panel the harness is inspecting.
func _on_intro_dismissed() -> void:
	if story_enabled and not _story_queue.is_empty():
		_show_story(_story_queue.pop_front())
		return
	# A tool has switched the story off: drop anything still queued, so the next
	# real play session does not start with a page nobody asked for.
	if not story_enabled:
		_story_queue.clear()
	var mission_id := QuestManager.current_mission_id
	if story_enabled and QuestManager.auto_advance and not _story_shown.has(mission_id):
		var page := Story.chapter_for(mission_id)
		if not page.is_empty():
			_show_story(page)
			return
	_begin_mission()


## Shows one page of the story. The page never advances by itself: the class
## reads it, presses PAUSE to talk, and leaves with GO ON.
func _show_story(page: Dictionary) -> void:
	if story_screen == null or not story_enabled:
		_begin_mission()
		return
	screen = Screen.STORY
	_set_gameplay_active(false)
	# A chapter is read at the class's pace, with a teacher talking over it, so
	# the music steps back for as long as the page is open instead of switching
	# to a separate "story" cue. See `Music.hold_duck()`.
	Music.hold_duck(true)
	var mission_id := int(page.get("mission", QuestManager.current_mission_id))
	if not _story_shown.has(mission_id):
		_story_shown.append(mission_id)
	story_screen.open(page)


## GO ON on the story page.
func _on_story_finished() -> void:
	# A queued page (prologue -> first chapter) is read next, so the class is
	# never dropped straight into a task in the middle of the story.
	if not _story_queue.is_empty():
		_show_story(_story_queue.pop_front())
		return
	# The page just read may have been the prologue, which opens *no* mission:
	# mission 1's own chapter would then still be unread. Running the same
	# interception again keeps the book from being skipped just because another
	# page happened to be waiting in the queue.
	var mission_id := QuestManager.current_mission_id
	if story_enabled and QuestManager.auto_advance and not _story_shown.has(mission_id):
		var page := Story.chapter_for(mission_id)
		if not page.is_empty():
			_show_story(page)
			return
	_begin_mission()


func _begin_mission() -> void:
	# Whatever lifted the music (a story page, a pause) is over: the task is
	# about to be spoken over the full mix.
	Music.hold_duck(false)
	screen = Screen.PLAYING
	# `_set_gameplay_active(true)` is what reads the task aloud: it raises
	# `Level._gameplay_live`, and the level announces the mission that was built
	# while the class was reading. Nothing is spoken here as well — a second
	# `speak()` for the same sentence is the doubling this whole path exists to
	# remove, and it used to fire on *every* mission, not only after a chapter.
	_set_gameplay_active(true)
	# The level starts the mission itself; this just makes sure the world and
	# the quest agree after a "Continue".
	if level.mission_controller == null:
		level._start_current_mission()


func _set_gameplay_active(active: bool) -> void:
	# The level is the one that owns "is the world the thing on screen": it needs
	# to know both to park Jack and to decide *when* to read the task aloud. It
	# used to set the player's flag itself, which is why the mission prompt was
	# spoken at 0.83 s — while the title screen was still up — and again under
	# the zone card. See `Level.set_gameplay_live()`.
	var live := active and screen == Screen.PLAYING
	if level != null:
		level.set_gameplay_live(live)
	hud.visible = active
	# The pad answers to the same question as the HUD, and it is told rather than
	# assigned: it has two other reasons to be hidden (the setting and the fold)
	# that a bare `visible = active` here would silently overrule.
	if touch_pad != null:
		touch_pad.set_gameplay_active(active)


## Drives one mission to completion by calling the same handlers a child's
## taps trigger. Returns true when the controller emitted `solved`.
func _autoplay_mission(mission: Dictionary, mechanic: String) -> bool:
	var controller: MissionController = level.mission_controller
	if controller == null:
		return false
	var solved_flag := [false]
	controller.solved.connect(func(): solved_flag[0] = true)

	match mechanic:
		"find":
			# Tap every correct prop; distractors are deliberately left alone.
			for child in controller.get_children().duplicate():
				if solved_flag[0]:
					break
				if child is LearningProp and (child as LearningProp).is_correct:
					(child as LearningProp).interact()
					await get_tree().create_timer(0.06).timeout
		"count":
			# Collect and hand in one item at a time, exactly like a child
			# counting: pick something the mission asks for, then press GIVE.
			var panel: CountingPanel = controller.get_node_or_null("CountingPanel")
			var props: Array = []
			for child in controller.get_children():
				if child is LearningProp and controller.has_method("matches_requirement"):
					if (controller as CountMission).matches_requirement(child as LearningProp):
						props.append(child)
			for prop in props:
				# `is_instance_valid` on every reference, not just once at the
				# start: a solve retires the controller and the next mission's
				# build frees it, so a panel or prop captured here can be gone by
				# the next iteration. Calling a method on a freed Object is not a
				# GDScript error — it is a `signal 11` crash of the engine, which
				# is how this harness failed the first time it ran with a
				# controller that could disappear mid-run.
				if solved_flag[0] or not is_instance_valid(panel) or not is_instance_valid(prop):
					break
				if not (prop as LearningProp).can_interact():
					continue
				(prop as LearningProp).interact()
				await get_tree().create_timer(0.06).timeout
				if not is_instance_valid(panel):
					break
				panel._on_give()
				await get_tree().create_timer(0.15).timeout
		"sequence":
			# Step on each pad in order.
			var pads: Array = controller._pads
			for pad in pads:
				if pad != null and is_instance_valid(pad):
					(pad as LearningProp).interact()
					await get_tree().create_timer(0.06).timeout
		"quiz":
			# Answer every question correctly through the quiz panel. The quiz
			# slides in after a short delay and locks itself for ~1.2s after a
			# correct answer, so poll instead of guessing timings.
			var quiz: QuizManager = controller.get_node_or_null("QuizManager")
			if quiz != null:
				var guard := 0
				while guard < 200 and not solved_flag[0] and (not quiz.visible or quiz._locked):
					guard += 1
					if quiz._index >= (mission.get("questions", []) as Array).size():
						break
					await get_tree().create_timer(0.1).timeout
				guard = 0
				while guard < 400 and not solved_flag[0] and quiz.visible:
					guard += 1
					var questions: Array = mission.get("questions", [])
					if quiz._index >= questions.size():
						await get_tree().create_timer(0.1).timeout
						continue
					if quiz._locked:
						await get_tree().create_timer(0.1).timeout
						continue
					var row: HBoxContainer = quiz._card_row
					var options: Array = questions[quiz._index].get("options", [])
					for i in options.size():
						if bool(options[i].get("correct", false)) and i < row.get_child_count():
							quiz._on_option_pressed(i, row.get_child(i))
							break
					await get_tree().create_timer(0.1).timeout
		"repeat":
			var panel: RepeatPanel = controller.get_node_or_null("RepeatPanel")
			if panel != null:
				var door := 0
				while not panel.visible and door < 30:
					door += 1
					await get_tree().create_timer(0.1).timeout
				var guard := 0
				while panel.visible and not solved_flag[0] and guard < 12:
					guard += 1
					panel._on_replay()
					# Wait out the panel's own "listen first" gate instead of
					# using a literal: `MIN_LISTEN_TIME` is a *speech* timeout and
					# it doubles with the recordings (see its comment in
					# `RepeatPanel`), so a hard-coded 0.7 s here silently became
					# a press the panel refused — the run then reported five
					# `repeat` missions as unsolvable while the game was fine.
					await get_tree().create_timer(panel.MIN_LISTEN_TIME + 0.15).timeout
					panel._on_mic()
					# 0.9s "GREAT!" beat + 0.35s before the next line speaks.
					await get_tree().create_timer(1.45).timeout
		"tpr":
			for target in mission.get("targets", []):
				controller._on_part_pressed(String(target.get("part", "")))
				await get_tree().create_timer(0.12).timeout
		"grid":
			# Teleport Jack onto each path tile in order.
			for coord in mission.get("path", []):
				var room: GridTrapRoom = controller
				level.player.teleport_to(room.coord_to_position(String(coord)) + Vector3(0, 0.6, 0))
				await get_tree().create_timer(0.14).timeout
		"coords":
			# Same walk as "grid", and it works because `CoordsMission` inherits
			# `coord_to_position()`: the harness proves the *route* is walkable,
			# not that a marker was lit.
			for coord in mission.get("path", []):
				if solved_flag[0]:
					break
				var room: CoordsMission = controller
				level.player.teleport_to(room.coord_to_position(String(coord)) + Vector3(0, 0.6, 0))
				await get_tree().create_timer(0.16).timeout
		"find_numbers":
			# Tap one of each wanted number. The wanted list is taken from the
			# mission dictionary, not from the controller's private state, so a
			# controller that mis-read its own data would still be caught.
			var wanted: Array = mission.get("numbers", [])
			for child in controller.get_children().duplicate():
				if solved_flag[0]:
					break
				if not (child is LearningProp):
					continue
				if not wanted.has((child as LearningProp).number):
					continue
				(child as LearningProp).interact()
				wanted.erase((child as LearningProp).number)
				await get_tree().create_timer(0.08).timeout
		"spell":
			# Spell the word the way a child would: ask the panel which letter it
			# wants next, then press exactly that key. `press_letter()` is a
			# public helper on the panel written for this harness — walking the
			# private `_keys` arrays from here would let the test disagree with
			# the panel about what a "correct letter" is, which is precisely the
			# bug the test exists to catch elsewhere. The loop waits on
			# `solved_flag` as well as on the index, because the panel holds the
			# last letter on screen for ~1.1 s before it emits `finished`.
			var panel: SpellingPanel = controller.get_node_or_null("SpellingPanel")
			if panel != null:
				var door := 0
				while not panel.visible and door < 30:
					door += 1
					await get_tree().create_timer(0.1).timeout
				var guard := 0
				while panel.visible and not solved_flag[0] and guard < 200:
					guard += 1
					# A wrong letter would still be recoverable (the panel never
					# fails a word), but pressing the expected one is what a
					# child does after listening, and it keeps this run short.
					if not panel.press_letter(panel.expected_letter()):
						await get_tree().create_timer(0.1).timeout
					await get_tree().create_timer(0.12).timeout

	# Give the flame/last animation time to emit `solved` (solve() waits 0.2s).
	var settle := 0.0
	while not solved_flag[0] and settle < 6.0:
		await get_tree().create_timer(0.1).timeout
		settle += 0.1
	return solved_flag[0]


## The story page at a mission that does *not* open a zone.
##
## Chapters already arrive through `_on_intro_dismissed()` (zone card first, then
## chapter). Beats sit inside a zone, where `advance()` starts the next mission
## directly with no card, so without this hook the five intermezzo pages would
## never be read. It fires for every mission and does nothing unless the page is
## a beat that has not been shown yet.
##
## Everything the QA harness relies on is guarded: `story_enabled` is turned off
## by `tools/layout_check.gd`, and `QuestManager.auto_advance` is off for the
## `--smoke` run, so a modal page can never land on top of a measured mission.
func _on_story_mission_started(mission: Dictionary) -> void:
	if not story_enabled or not QuestManager.auto_advance:
		return
	if screen == Screen.TITLE or screen == Screen.ENDING:
		return
	var mission_id := int(mission.get("id", 0))
	if _story_shown.has(mission_id):
		return
	if Story.beat_for(mission_id).is_empty():
		return
	# The level is already building the props behind us. The page is shown a beat
	# later so its scrim covers a settled world instead of a half-faded one, and
	# the mission itself is left completely intact underneath.
	#
	# The prompt is silenced *before* the wait, not when the page opens: a beat
	# sits inside a zone and the build that started it can finish in under
	# 0.35 s, so the task line is already being read when the page's own title
	# begins. `defer_prompt_announcement()` stops that sentence and marks the
	# mission as not-yet-read, so it is read again — whole — by the
	# `set_gameplay_live(true)` that follows GO ON.
	if level != null:
		level.defer_prompt_announcement()
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or not story_enabled or QuestManager.current_mission_id != mission_id:
		return
	var page := Story.chapter_for(mission_id)
	if page.is_empty():
		return
	_show_story(page)


func _on_zone_changed(zone_id: int, mission_id: int) -> void:
	# The world is about to be replaced by a different one, and a card is about
	# to introduce it. Both are reasons for the level not to read the incoming
	# task yet: the build takes ~0.9 s (two fades) and would otherwise finish —
	# and speak — *after* the card had started its own sentence, because the
	# 0.2 s below is shorter than the fade. Measured before this: the card
	# began at 1.23 s and the task at 1.30 s.
	_set_gameplay_active(false)
	await get_tree().create_timer(0.2).timeout
	_show_zone_intro(zone_id, GameData.mission(mission_id))


# --- Menu callbacks -------------------------------------------------------

func _on_title_start() -> void:
	QuestManager.reset_progress()
	# A brand-new game is a brand-new book: the prologue and every chapter have
	# to be readable again, otherwise START on a game the class has already
	# finished would jump straight into the tasks with no story at all.
	_story_shown.clear()
	_story_queue.clear()
	begin_playing()


func _on_title_continue() -> void:
	begin_playing()


func _on_title_settings() -> void:
	pause_menu.open(0.0)


# --- Bonus challenges ------------------------------------------------------

## The title (or the ending) asked for the list of bonus challenges.
##
## The story is paused, not reset: `current_mission_id` and the flames are
## untouched, so BACK puts the class exactly where they were. That is the whole
## contract of the bonus set, and it is why none of this goes through
## `reset_progress()`.
func _on_title_challenges() -> void:
	if challenge_hub == null:
		return
	# Every entry into the list starts by assuming the way back is the title:
	# the teacher's page is the one caller that overrides it afterwards.
	_challenges_back_to_pause = false
	screen = Screen.CHALLENGES
	title_screen.close()
	ending_screen.close()
	_set_gameplay_active(false)
	challenge_hub.open()


## A challenge was chosen. The level builds it through the normal
## `mission_started` path, so nothing here spawns props itself.
func _on_challenge_pressed(index: int) -> void:
	challenge_hub.close()
	# The list is no longer behind anything: whatever the next BACK belongs to,
	# it is not the teacher's page.
	_challenges_back_to_pause = false
	screen = Screen.PLAYING
	_set_gameplay_active(true)
	QuestManager.start_extra(index)


## BACK from the challenge list.
func _on_challenges_back() -> void:
	challenge_hub.close()
	# Opened from the teacher's page: return to the pause screen it came from,
	# which is the only page in the game that opened it *from a mission*. Checked
	# before the ending and before the flames, because a teacher can open this at
	# mission 1 with an empty lantern, where the fallback below would send them
	# to the title.
	if _challenges_back_to_pause:
		_challenges_back_to_pause = false
		screen = Screen.PAUSE
		pause_menu.open(0.0)
		return
	# Where to return depends on where the hub was opened from. The ending is
	# the one case with a *different* page behind it: a class that has just
	# finished the story must not be dropped on the title with PLAY AGAIN.
	if ending_screen != null and ending_screen.visible:
		screen = Screen.ENDING
		ending_screen.open()
		return
	if QuestManager.flames > 0 or QuestManager.current_mission_id > 1:
		begin_playing()
		return
	show_title()


## A bonus challenge was solved: back to the list, which shows the new tally.
##
## No extra wait here. `Level._celebrate_flame()` already held the reward on
## screen for 2.2 s before `advance()` asked to move on, and adding a second
## delay on top of that would leave the class looking at an empty board.
func _on_extra_return() -> void:
	if not is_inside_tree():
		return
	if challenge_hub == null:
		return
	# A harness may have moved on in the meantime; the page only opens if the
	# bonus flow is still the thing that just finished.
	if not QuestManager.extra_active:
		return
	challenge_hub.open()
	screen = Screen.CHALLENGES
	_set_gameplay_active(false)


func _on_pause() -> void:
	screen = Screen.PAUSE
	pause_menu.open(0.0)
	# Through the level, not straight at the player: `Level.set_gameplay_live()`
	# is also what decides when the task may be read aloud, and poking
	# `player.set_input_enabled()` directly left the level believing the world
	# was still live — so the prompt spoke over the pause menu. The quiz/mouse
	# half (`Jack._ui_blocked`) is untouched by this and keeps working.
	if level != null:
		level.set_gameplay_live(false)


## Opens the key-rebinding page on top of the pause menu. The pause menu is
## hidden (not freed) while the page is open: that keeps its buttons out of the
## keyboard focus chain, so Enter cannot "press" KEEP PLAYING behind the child's
## back, and BACK returns to a screen that is already familiar.
func _on_controls() -> void:
	if controls_panel == null:
		return
	if pause_menu != null:
		pause_menu.visible = false
	controls_panel.open()


## BACK from the controls page: close it and return to the pause menu. The
## pause menu is re-shown even when the page was opened from the title screen,
## because that is the page that opened it.
func _on_controls_back() -> void:
	if controls_panel == null:
		return
	controls_panel.close()
	if pause_menu != null:
		pause_menu.visible = true


## Opens the sound page on top of the pause menu, hidden for the same reason as
## the controls page: an invisible KEEP PLAYING cannot be pressed by accident.
func _on_sound_settings() -> void:
	if sound_panel == null:
		return
	if pause_menu != null:
		pause_menu.visible = false
	sound_panel.open()


func _on_sound_back() -> void:
	if sound_panel == null:
		return
	sound_panel.close()
	if pause_menu != null:
		pause_menu.visible = true
		UiKit.focus_first_button(pause_menu)


# --- Teacher menu ----------------------------------------------------------

## Opens the teacher's page from the bottom of the pause screen.
##
## The pause menu is *hidden*, not closed and not freed, for the same reason the
## controls page hides it: a visible KEEP PLAYING behind an open page is a button
## a leaning child can press, and the forty mission buttons need the keyboard
## focus chain to themselves. Hiding also means BACK returns to a page that is
## already in the state it was left in (difficulty, switches), instead of
## replaying its fade and re-syncing its toggles.
##
## The gameplay stays parked: `_on_pause()` already called
## `level.set_gameplay_live(false)`, and nothing here raises it. A teacher who
## opens a mission from this page gets a fresh build, which is what announces the
## task aloud and hands control to the child.
func _on_teacher() -> void:
	if teacher_menu == null:
		return
	if pause_menu != null:
		pause_menu.visible = false
	teacher_menu.open()


## BACK from the teacher's page: the pause menu comes back, with the focus on
## KEEP PLAYING rather than on the button that was pressed, so the next press of
## the A button resumes the game instead of reopening this page.
func _on_teacher_back() -> void:
	if teacher_menu == null:
		return
	teacher_menu.close()
	if pause_menu != null:
		pause_menu.visible = true
		UiKit.focus_first_button(pause_menu)


## A mission was chosen from the teacher's page.
##
## `start_mission()` is the same call the sequence uses, so the mission is built
## by the normal path: zone fade, world, character, task read aloud. The story
## page is deliberately *not* pushed here — a teacher jumping to mission 21 has
## already read chapter 21 out loud, and shoving it in front of the class would
## make the shortcut slower than playing the game.
##
## `_story_shown` still has to be told the page was seen, otherwise the mission
## the class actually reaches in the sequence would open with a chapter they were
## given no credit for having read: they would get it twice. Marking it here is
## the honest reading of "the teacher skipped it".
func _on_teacher_mission(mission_id: int) -> void:
	teacher_menu.close()
	if pause_menu != null:
		pause_menu.close()
	screen = Screen.PLAYING
	_set_gameplay_active(true)
	if not _story_shown.has(mission_id):
		_story_shown.append(mission_id)
	QuestManager.start_mission(mission_id)


## The EXTRA CHALLENGES button on the teacher's page.
##
## Same destination as the title's, with one difference in where BACK leads: the
## class was in the middle of a mission and the pause page is what they left, so
## the list returns there rather than to the title (`_challenges_back_to_pause`).
## Without it, a teacher who opened the list from mission 1 with no flames would
## press BACK and be dropped on the title screen, having lost the pause menu they
## started from.
func _on_teacher_challenges() -> void:
	teacher_menu.close()
	if pause_menu != null:
		pause_menu.close()
	_on_title_challenges()
	# Set *after* the call above, because `_on_title_challenges()` clears it: the
	# title and the ending are the two screens whose BACK leads somewhere else,
	# and the flag has to describe the visit that is actually happening.
	_challenges_back_to_pause = true


## A volume level changed on the sound page. The page has already applied and
## saved it (QuestManager owns that); this is only where anything that *shows*
## a level would redraw. Kept as a real handler so adding such a widget later
## does not mean finding every call site.
func _on_volume_changed(_channel: String, step: int) -> void:
	# A child who silenced everything with the Sound switch, then opened this
	# page and pressed `>` expecting to hear something, would otherwise press
	# an arrow and hear silence -- which reads as "the game is broken". Raising
	# a level is a request for sound, so the switch is turned back on. Turning a
	# level to OFF is *not* treated as a request for silence: that is what the
	# switch is for, and the two controls stay independent in that direction.
	if step > 0 and not QuestManager.sound_on:
		_on_sound_changed(true)
		if pause_menu != null:
			pause_menu.sync_sound_toggle(true)


## The camera view changed on the settings page.
##
## `QuestManager` and `Level` have already done the work (the signal they emit is
## what the rig listens to). This handler exists so the *page* stays honest: the
## name next to the arrows is redrawn here rather than relying on the button
## handler, which keeps the two in step if the setting is ever changed from
## somewhere else (a future title-screen shortcut, a reset).
func _on_camera_mode_changed(_mode: int) -> void:
	if sound_panel != null:
		sound_panel.refresh()


func _on_resume() -> void:
	screen = Screen.PLAYING
	pause_menu.close()
	# Raising the flag here means a mission that was never read (paused during
	# its first second) is read now, instead of staying silent. A quiz that is
	# still open underneath keeps Jack frozen through `Jack._ui_blocked`, so
	# resuming cannot hand the child a walking character mid-question.
	if level != null:
		level.set_gameplay_live(true)


func _on_quit() -> void:
	_quit_cleanly()


func _on_restart_zone() -> void:
	screen = Screen.PLAYING
	pause_menu.close()
	# Restart is the one path where the build is started *by* this handler, so
	# the request goes first: `mission_started` is emitted synchronously and
	# `Level` raises its `_building` flag before its first fade, so the
	# `set_gameplay_live(true)` below sees a build in flight and stays quiet.
	# The build itself speaks when it lands — announcing here as well would read
	# the same prompt twice, ~0.9 s apart.
	QuestManager.restart_current()
	if level != null:
		level.set_gameplay_live(true)


func _on_easy_read_changed(enabled: bool) -> void:
	QuestManager.set_easy_read(enabled)
	QuestManager.save_progress()
	UiKit.refresh_theme()
	# Rebuild the UI so every label picks up the new font.
	_rebuild_ui()


## The `<` / `>` arrows next to the difficulty name in the pause menu.
##
## Changing the level never interrupts play and never rebuilds the level: the
## panels ask `Hints` every time they are drawn, so the *next* mission prompt,
## quiz card or pad glow already obeys the new level. The HUD and an open story
## page are refreshed immediately because they are on screen right now, and a
## teacher who presses `>` while a chapter is open expects the pictures to
## disappear from the words in front of them.
func _on_difficulty(step: int) -> void:
	var wanted := Hints.neighbour(Hints.level(), step)
	if wanted == Hints.level():
		return
	QuestManager.set_difficulty(wanted)
	QuestManager.save_progress()
	AudioFx.play_sfx("pop")
	if pause_menu != null:
		pause_menu.refresh_difficulty()
	# The HUD is *not* told here: it listens to `difficulty_changed` itself, and
	# calling `show_mission()` as well would replay the prompt fade and rebuild
	# the same row twice.
	# The story page keeps its own copy of the page being read, so it has to
	# redraw its keyword chips at the new level. `refresh_hints()` rather than
	# `open()`: re-opening would un-pause a paused page, re-speak the title and
	# start a second fade while a teacher is mid-sentence.
	if story_screen != null and story_screen.visible:
		story_screen.refresh_hints()


func _rebuild_ui() -> void:
	var was_playing := screen == Screen.PLAYING
	# The easy-read toggle can in principle be reached while a page is open (a
	# child may pause, change the font and come back), so the page being read is
	# remembered and re-opened at the end instead of being dropped on the floor.
	var was_story := screen == Screen.STORY
	var story_page: Dictionary = Story.chapter_for(QuestManager.current_mission_id) if was_story else {}
	# Both overlays are freed *first*, then rebuilt in build order, so the drawing
	# order cannot be inverted by the rebuild itself: the pad is the later
	# sibling and must stay drawn above the HUD.
	if hud != null:
		hud.queue_free()
		hud = null
	# The pad is rebuilt as well, and for a second reason beyond the theme: it is
	# a sibling *after* the HUD, so freeing only the HUD and adding a new one
	# would put the new HUD on top of the pad. It would still be pressable (the
	# HUD ignores the mouse) but every drawn arrow would be behind the task bar.
	if touch_pad != null:
		touch_pad.queue_free()
		touch_pad = null
	_build_hud()
	_build_touch_pad()
	if pause_menu != null:
		pause_menu.close()
		pause_menu.queue_free()
		pause_menu = PauseMenu.new()
		pause_menu.name = "PauseMenu"
		menu_layer.add_child(pause_menu)
		_connect_pause_menu()
		hud.show_mission(QuestManager.current_mission(), QuestManager.current_zone_info())
	# The controls page labels are themed too, so it is rebuilt alongside.
	if controls_panel != null:
		controls_panel.close()
		controls_panel.queue_free()
		controls_panel = ControlsPanel.new()
		controls_panel.name = "ControlsPanel"
		menu_layer.add_child(controls_panel)
		controls_panel.back_pressed.connect(_on_controls_back)
	if sound_panel != null:
		sound_panel.close()
		sound_panel.queue_free()
		sound_panel = SoundPanel.new()
		sound_panel.name = "SoundPanel"
		menu_layer.add_child(sound_panel)
		_connect_sound_panel()
	# The teacher's page is forty buttons of themed text like everything else, so
	# the easy-read font has to reach it too. Rebuilt right after the sound page
	# for the one ordering reason that matters: it must be a later sibling than
	# the pause menu, so it draws *over* the page it was opened from rather than
	# under it. `_build_menus()` adds it last for the same reason.
	if teacher_menu != null:
		teacher_menu.close()
		teacher_menu.queue_free()
		teacher_menu = TeacherMenu.new()
		teacher_menu.name = "TeacherMenu"
		menu_layer.add_child(teacher_menu)
		teacher_menu.mission_pressed.connect(_on_teacher_mission)
		teacher_menu.challenges_pressed.connect(_on_teacher_challenges)
		teacher_menu.back_pressed.connect(_on_teacher_back)
	# The story page's buttons are themed too. It is rebuilt with everything else
	# so the easy-read font reaches the chapter text as well — a menu recreated in
	# only one of the two build paths would silently keep the old font.
	#
	# It is freed *without* `close()`: closing fades the page out and then emits
	# `finished`, which would start the mission behind the teacher's back.
	if story_screen != null:
		story_screen.queue_free()
		story_screen = StoryScreen.new()
		story_screen.name = "StoryScreen"
		menu_layer.add_child(story_screen)
		story_screen.finished.connect(_on_story_finished)
	if was_playing:
		screen = Screen.PLAYING
		_on_resume()
	elif was_story and not story_page.is_empty():
		_show_story(story_page)


func _on_sound_changed(enabled: bool) -> void:
	QuestManager.set_sound(enabled)
	QuestManager.save_progress()
	AudioFx.play_sfx("pop")


## The Magic Magnifying Glass: announced to the level, which knows whether a
## quiz or dialogue is currently on screen.
func _on_help() -> void:
	QuestManager.request_translation()


func _on_repeat_audio() -> void:
	AudioFx.speak(String(QuestManager.current_mission().get("prompt_en", "")))


func _on_all_completed() -> void:
	if screen == Screen.ENDING:
		return
	screen = Screen.ENDING
	_set_gameplay_active(false)
	Music.hold_duck(false)
	# The party's own track gives way to the ending cue as the last flame lands.
	Music.play_track("ending")
	level.play_finale()
	await get_tree().create_timer(3.2).timeout
	if is_inside_tree():
		ending_screen.open()


func _on_play_again() -> void:
	QuestManager.reset_progress()
	ending_screen.close()
	get_tree().reload_current_scene()


## Intercepts the window's close button so the music is released cleanly.
##
## Without this, clicking the red dot (or Alt-F4, or Cmd-Q) tears the SceneTree
## down while an `AudioStreamPlayer` is still holding its stream, and Godot
## prints "N ObjectDB instances were leaked" plus "resource still in use:
## res://assets/music/title.ogg". Measured on the packaged macOS build: closing
## that way reported exactly those four instances, and the fix is to stop the
## player in the one notification that arrives *before* the tree is freed.
##
## `NOTIFICATION_WM_CLOSE_REQUEST` is delivered only while
## `auto_accept_quit` is false; it is switched off in `_ready()`.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_cleanly()


## Stops audio, saves, then quits. Shared by the QUIT button and the window's
## close request so both leave the same state behind.
##
## The 0.2 s pause before `quit()` is measured, not decorative: `stop()` only
## *asks* the audio server to release a playback, and the server does so on its
## next mix pass. Quitting in the same frame skips that pass, which is why an
## earlier version of this function still printed "4 ObjectDB instances were
## leaked" and "resource still in use: res://assets/music/title.ogg" on the
## packaged build. The smoke harness waits for the same reason. 0.2 s is two
## mix blocks at any plausible buffer size and is far too short to be noticed
## by anyone clicking QUIT.
func _quit_cleanly() -> void:
	QuestManager.save_progress()
	# Not fades: a tween would also need frames, and stopping outright is what
	# matters -- nobody hears the last 200 ms of a track they just quit on.
	Music.stop_now()
	AudioFx.stop_sfx()
	# The recorded voice clips are cached resources too, and the cache is what
	# `--headless` reports as "resources still in use at exit" once the pack is
	# in the build. `release_cache()` drops them (and the speech player's stream)
	# before the 0.2 s wait below, so the audio server's mix pass has something to
	# release. Without it the packaged build prints the same warning this
	# function's own comment describes for the music.
	AudioFx.release_cache()
	# Guarded: a second close request (someone clicking the red dot twice)
	# would otherwise start two quit sequences.
	if _quitting:
		return
	_quitting = true
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


## True while a panel -- not the 3D world -- is the thing the child is looking at.
##
## The test is "any of our modal panels is visible", not `screen == ...`: the
## quiz, the counting bag, the dialogue box and the story page are owned by
## `Level` and can be open while `screen` still says PLAYING. Checking the
## visible panels is what keeps the controller's A button working in all of them
## without a list of states that would go stale the next time a panel is added.
func _menu_owns_screen() -> bool:
	if screen != Screen.PLAYING:
		return true
	for panel in [hud, pause_menu, controls_panel, sound_panel, story_screen,
			zone_intro, title_screen, ending_screen, challenge_hub, teacher_menu]:
		if panel != null and (panel as Control).visible:
			return true
	if level != null:
		# The dialogue box is a CanvasItem: its own `visible` says whether it is up.
		# The quiz / mirror / counting panels are not children of the level, they
		# are built inside the active mission controller, so the only honest
		# answer is to ask the controller itself. `is_panel_open()` exists for
		# exactly this question (see MissionController.gd, overridden by
		# QuizMission.gd) and avoids guessing at a node name that may not exist.
		if level.dialogue != null and level.dialogue.visible:
			return true
		if level.mission_controller != null and level.mission_controller.is_panel_open():
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Controller "A" presses whatever button the menu has focused. It is routed
	# here, and only here, because `ui_accept` must *not* carry the pad: the HUD
	# keeps two focusable buttons on screen while the child walks around, and a
	# stray focus would turn "pick up the pumpkin" into "read the task again".
	# See `Controls.install_pad_ui()` for the measurement behind this.
	#
	# Synthesising `ui_accept` rather than calling a button directly keeps the
	# behaviour identical to the keyboard: focus order, disabled buttons and
	# `pressed` signals all work exactly as they already do.
	if event.is_action_pressed("ui_confirm_pad") and _menu_owns_screen():
		var press := InputEventAction.new()
		press.action = "ui_accept"
		press.pressed = true
		Input.parse_input_event(press)
		get_viewport().set_input_as_handled()
		return
	# The story page owns `pause` itself (it freezes instead of closing). Checked
	# first because Main sits above every menu in the tree and would otherwise
	# resume a game that is not running.
	if story_screen != null and story_screen.visible:
		return
	if event.is_action_pressed("pause"):
		# Escape is also the "cancel" of the key-rebinding page, the sound page
		# and the teacher's page: closing one of those must never also resume the
		# game in a single keystroke.
		if teacher_menu != null and teacher_menu.visible:
			_on_teacher_back()
		elif sound_panel != null and sound_panel.visible:
			_on_sound_back()
		elif controls_panel != null and controls_panel.visible:
			_on_controls_back()
		elif screen == Screen.PLAYING:
			_on_pause()
		elif screen == Screen.PAUSE:
			_on_resume()
		get_viewport().set_input_as_handled()
