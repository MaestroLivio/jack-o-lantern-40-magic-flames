extends Node
## Quest manager / event bus (autoload `QuestManager`).
##
## Owns the single source of truth for progress: which of the 40 missions is
## active, which ones are done, how many Magic Flames Jack carries. Every
## screen talks to the rest of the game through the signals declared here,
## so no node needs a direct reference to another one.
##
## Progression is strictly sequential (the GDD's scaffolding), and nothing
## here can ever fail a child: there is no timeout, no life, no game over.

# --- Signals ---------------------------------------------------------------

## A mission has been set up and its prompt is ready to be shown.
signal mission_started(mission: Dictionary)
## The current mission was solved (fired before the flame animation).
signal mission_completed(mission_id: int, flames: int)
## A new Magic Flame went into the lantern.
signal flames_changed(flames: int)
## Someone asked for a full-screen or HUD message.
signal feedback(text_en: String, text_it: String, kind: String)
## The active zone changed; the level has to be rebuilt.
signal level_transition_requested(zone_id: int, mission_id: int)
## Every mission is done (mission 40 included).
signal all_missions_completed()
## Progress inside the current quiz/multi-step mission: step/total.
signal step_changed(step: int, total: int)
## The child pressed the magnifying glass on the current mission.
signal translation_requested()
## Save/load notifications for the HUD toast.
signal save_state_changed(saved: bool)
## The difficulty changed (1..3). Panels rebuild their hints when it does.
signal difficulty_changed(level: int)
## The camera mode changed (see `CAMERA_MODES`). The level applies it at once.
signal camera_mode_changed(mode: int)
## A volume setting changed. `channel` is "music" or "sfx".
signal volume_changed(channel: String, value: float)
## Every bonus challenge is done. Separate from `all_missions_completed`, which
## is the end of the story: a class that finishes the forty extras has not
## finished the lantern, and the two endings must not be the same screen.
signal extra_challenges_completed()
## One bonus challenge was solved. `index` and `total` count the whole list,
## which is forty (`GameData.EXTRA_CHALLENGES.size()`), not a literal here:
## the list doubled in 1.0.5 and this doc line was the only place that said 20.
## Named `..._solved` and not `extra_completed` because that identifier is the
## saved array of solved indices: GDScript refuses a signal and a variable that
## share a name, and the array is the one that has to keep its name (the save
## key is written straight from it).
signal extra_challenge_solved(index: int, total: int)
## The bonus tally changed (solved / total). The hub and the HUD listen to this.
signal extra_completed_changed(done: int, total: int)
## A bonus challenge was solved and the class should return to the challenge
## list. The challenge list is the only way *out* of the bonus flow, so it is
## `Main` -- which owns screens -- that decides what opens, not the level.
signal extra_return_requested()
## The auto-hide-UI setting changed. Panels that are already open react at once
## instead of waiting for the next mission to be built.
signal auto_hide_ui_changed(enabled: bool)
## The automatic-camera setting changed. `Level` forwards it to the rig, which
## starts (or stops) easing its view behind Jack on the mission already running:
## a teacher who turns it off in the pause menu expects the camera to stop
## chasing *now*, not after the next flame.
signal auto_camera_changed(enabled: bool)
## The on-screen-controls setting changed. The HUD shows or removes the touch
## pad at once, and the pad releases anything it was holding when it goes.
signal touch_controls_changed(enabled: bool)
## The child dragged the on-screen pad somewhere else. `pos` is the top-left
## corner of the open cluster in canvas pixels, already clamped to the screen by
## the pad (`TouchControls._clamp_origin()`); the manager stores it and does not
## second-guess it, because the pad is the only thing that knows how big the
## block really is on this machine.
signal touch_pad_position_changed(pos: Vector2)

# --- State -----------------------------------------------------------------

const SAVE_PATH := "user://jack_progress.json"
const SAVE_VERSION := 1
const TOTAL_MISSIONS := 40
const TOTAL_FLAMES := 40

## Highest mission id ever unlocked (missions <= this can be replayed).
var current_mission_id: int = 1
## Mission ids the child has already solved.
var completed_missions: Array[int] = []
## Number of flames currently in Jack's lantern (== completed count).
var flames: int = 0
## Zone of the active mission, 1..6.
var current_zone: int = 1
## When false the language is set to "easy read" (bigger, spaced text).
var easy_read: bool = false
## Sound on/off, toggled from the pause menu.
var sound_on: bool = true
## How much visual help the game gives: 1 = lots, 2 = some, 3 = none.
## Read through `Hints` so every panel agrees; saved with the rest of the
## settings because a class that chose "all by myself" expects it tomorrow too.
##
## The default is 3. The game is meant to be played by a class that has already
## done the units it revises: a teacher who wants the pictures back can move the
## arrows two steps in the pause menu, and that choice is remembered. Starting at
## 1 would instead quietly give the answer away on the first screen of every new
## installation, which is the opposite of the request ("imposta per default il
## livello difficile"). A save file that already says 1 keeps saying 1: it is a
## setting the class chose, not something to be corrected on load.
var difficulty: int = 3
## How the camera is framed: see `CAMERA_MODES`.
var camera_mode: int = 0
## Background music level, 0..1, in five coarse steps (see `VOLUME_STEPS`).
##
## A continuous slider would be the obvious control, but this game is aimed at
## seven-year-olds and used on a classroom projector, where a mouse is often a
## teacher's hand on a trackpad: hitting a 4-pixel handle is not a fair ask.
## Five steps -- silent, soft, normal, loud -- are discrete targets a child can
## aim at and a teacher can describe out loud ("press it twice").
var music_volume: float = 0.42
## Sound-effect level, 0..1, same five steps. Kept above the music by default
## so the "ding" of a correct answer is always the thing heard first.
var sfx_volume: float = 0.62
## Set while a celebration animation is playing so inputs are ignored.
var busy: bool = false
## When true the instruction bar and the dialogue box fold themselves away once
## the child has had time to read them, leaving the world visible. A small tab
## stays on screen and brings them back, so folding is never a dead end.
##
## Default ON: the complaint that started this was that the task bar covered the
## very candies it asked the child to find, and a setting nobody finds is not a
## fix. A teacher who prefers the bar to stay put turns it off in SETTINGS, and
## the choice is saved with the rest of them.
var auto_hide_ui: bool = true
## When true the camera turns itself to stay behind Jack, so a child only has to
## walk: the view follows whichever way he faces instead of waiting to be
## dragged. Turned off in SETTINGS by anyone who wants to drive the view by hand.
##
## Default ON. The complaint that asked for this was a class where the children
## spent the whole session dragging the world back round after every corner, and
## the props the task asked about ended up off screen. A child who has learned
## the drag gesture loses nothing by leaving it on — a drag still wins for as
## long as the finger is down, and `AUTO_CAMERA_RESUME` in `CameraRig` only gives
## the view back to Jack a moment after the hand stops — while a child who never
## found the gesture at all gets a camera that simply works.
var auto_camera: bool = true
## When true the on-screen pad for touch screens is drawn over the world.
##
## Default ON and *minimisable* rather than off: the classroom screens this is
## for are frequently touch laptops and tablets, where a child with no keyboard
## has no other way to walk. Off by default would mean the one device that needs
## it is also the one where nobody knows to look in SETTINGS. It costs a mouse
## user nothing — the pad sits in the bottom corners the task bar only covers
## while it is open, it folds into a small tab, and it is ignored by the world
## raycast (`TouchControls.blocks_point()`).
var touch_controls: bool = true
## Where the child last dragged the on-screen pad, as the top-left corner of the
## open cluster in canvas pixels.
##
## `Vector2(-1, -1)` means "never moved", and is the default a fresh save gets:
## the pad then places itself at its measured home on the left edge (see
## `TouchControls._default_origin()`). A sentinel rather than writing the home
## position here, because the home position depends on the height of the window,
## which the manager has no business knowing — and a stored home position would
## be wrong the first time the game was run at a different resolution.
##
## Everything else about the value is deliberately the pad's business. The size
## of the block is measured after layout (408 x 236 px at 1280x720, not the 392
## the constants add up to), so only the pad can clamp it, and it clamps before
## calling `set_touch_pad_position()`.
var touch_pad_position: Vector2 = Vector2(-1, -1)
## The last mission id `advance()` has already moved away from.
##
## A zone change used to be a *second* async path that could also advance, and a
## second `advance()` for the same mission does not duplicate harmlessly: it
## reads `current_mission_id`, which does not change until `start_mission()`
## runs, so both calls ask for the same next mission — two controllers, two
## panels, one child. One advance per completed mission.
var _advanced_for_id: int = 0
## When false the level does not move on after a flame. Only the QA harness
## turns this off, so it can inspect every mission without racing the flow.
var auto_advance: bool = true
## When false `save_progress()` and `reset_progress()` leave `user://` alone.
##
## The smoke test walks all 40 missions and solves them, and `complete_current()`
## saves after every flame: running `-- --smoke` in the developer's copy used to
## overwrite the progress of whoever was playing that machine, and a class that
## had reached mission 12 would find itself at mission 40 afterwards. Tools that
## drive the game say so up front instead of remembering to restore the file.
var persist: bool = true

## Guards the "cannot write save file" warning so it appears only once.
var _save_warned: bool = false

## --- Bonus challenges ------------------------------------------------------
##
## The forty bonus missions live outside the story: they are not in
## `completed_missions`, they do not add flames, and they are not counted by
## `TOTAL_MISSIONS`. They are tracked here in their own three fields so that
## finishing them can never disturb a single number the story depends on.
##
## `extra_active` is the switch every shared accessor below reads. It is the
## reason `Level`, `Hud` and `Main` need no changes to run a bonus mission: they
## ask `current_mission()` and get the bonus one, ask `current_zone_info()` and
## get the zone it happens to take place in.
##
## `extra_completed` holds *indices* (1..the list size), not mission ids: the id space of
## the bonus list is an implementation detail, and a save file that stored ids
## would break the day a mission is inserted in the middle of the list.
var extra_active: bool = false
## Which bonus challenge is running, 1..40. 0 when none is.
var extra_index: int = 0
## Bonus challenges already solved, as indices.
var extra_completed: Array[int] = []


func _ready() -> void:
	# Autoloads outlive scenes, so this is the only place state is initialised.
	load_progress()
	current_zone = _zone_of(current_mission_id)


# --- Queries ---------------------------------------------------------------

## The dictionary of the active mission.
##
## During a bonus challenge this returns the bonus mission instead of the story
## mission, and that is deliberate: `Level`, `Hud`, `NpcCharacter` and `Main`
## all ask this one question, so they run a bonus challenge with no knowledge
## that it is one. `current_mission_id` is left untouched, which is what keeps
## the story exactly where the class left it.
func current_mission() -> Dictionary:
	if extra_active:
		return GameData.extra_mission(extra_index)
	return GameData.mission(current_mission_id)


## Zone dictionary of the active mission.
func current_zone_info() -> Dictionary:
	return GameData.zone_info(current_zone)


func is_completed(mission_id: int) -> bool:
	return completed_missions.has(mission_id)


## How many missions of `zone_id` are solved.
func zone_completed_count(zone_id: int) -> int:
	var info := GameData.zone_info(zone_id)
	var count := 0
	for id in range(int(info["first_mission"]), int(info["last_mission"]) + 1):
		if is_completed(id):
			count += 1
	return count


## Total missions in a zone.
func zone_mission_count(zone_id: int) -> int:
	var info := GameData.zone_info(zone_id)
	return int(info["last_mission"]) - int(info["first_mission"]) + 1


## Mission id that starts a zone.
func first_mission_of_zone(zone_id: int) -> int:
	return int(GameData.zone_info(zone_id)["first_mission"])


func _zone_of(mission_id: int) -> int:
	var m := GameData.mission(mission_id)
	return int(m.get("zone", 1))


# --- Progression -----------------------------------------------------------

## Activates a mission. `rebuild` is emitted through `mission_started` so the
## level can spawn the props for the new mechanic.
func start_mission(mission_id: int) -> void:
	# Starting a story mission always leaves the bonus flow. This is the one
	# place the two modes meet, and doing it here means a caller that was
	# written before the bonus missions existed (CONTINUE, a zone transition,
	# the QA harness) cannot accidentally run a story mission on top of a bonus
	# one.
	extra_active = false
	extra_index = 0
	current_mission_id = clampi(mission_id, 1, TOTAL_MISSIONS)
	current_zone = _zone_of(current_mission_id)
	busy = false
	var m := current_mission()
	if m.is_empty():
		push_warning("QuestManager: unknown mission id %d" % mission_id)
		return
	mission_started.emit(m)


## Starts bonus challenge `index` (1..40).
##
## `current_mission_id` is deliberately *not* touched: the story has to be
## exactly where the class left it when they come back, and `current_zone` does
## change, because the level rebuilds its world from it. A bonus mission in the
## castle therefore runs in the castle, with its own music and its own character.
##
## The zone is taken from the bonus mission itself rather than being hard-coded,
## so moving a challenge to a different zone is a one-word edit in `GameData`.
func start_extra(index: int) -> void:
	var data := GameData.extra_mission(index)
	if data.is_empty():
		push_warning("QuestManager: unknown bonus challenge %d" % index)
		return
	extra_active = true
	extra_index = index
	current_zone = int(data.get("zone", current_zone))
	busy = false
	mission_started.emit(data)


## Leaves the bonus flow and returns to the story mission the class was on.
## Used by the "back to the party" exit of the bonus hub; the level rebuilds the
## world through the normal `mission_started` path.
func stop_extra() -> void:
	if not extra_active:
		return
	extra_active = false
	extra_index = 0
	start_mission(current_mission_id)


## Marks the active mission as solved and adds one Magic Flame.
## Safe to call twice (e.g. a double click) — the second call is ignored.
func complete_current() -> bool:
	# A bonus challenge earns a tick in its own list, never a Magic Flame. The
	# `complete_current()` name is still honest: the thing that is current is
	# what got completed. What it must *not* do is append to
	# `completed_missions`, because that array is the story, and `flames` is
	# literally its size.
	if extra_active:
		if extra_completed.has(extra_index):
			return false
		extra_completed.append(extra_index)
		extra_completed.sort()
		extra_completed_changed.emit(extra_completed.size(), GameData.EXTRA_CHALLENGES.size())
		extra_challenge_solved.emit(extra_index, GameData.EXTRA_CHALLENGES.size())
		# The last one is its own moment. It is *not* the end of the game — there
		# is no ending screen here, because the class has not finished the lantern
		# — so the only thing it does is let the hub say so.
		if extra_completed.size() >= GameData.EXTRA_CHALLENGES.size():
			extra_challenges_completed.emit()
		save_progress()
		return true
	if is_completed(current_mission_id):
		return false
	completed_missions.append(current_mission_id)
	completed_missions.sort()
	flames = completed_missions.size()
	flames_changed.emit(flames)
	mission_completed.emit(current_mission_id, flames)
	save_progress()
	return true


## Moves to the next mission. Called by the level after the flame celebration,
## so the child always sees the reward before the world changes.
func advance() -> void:
	# A bonus challenge is never followed by a story mission. Without this
	# guard, the flame celebration of the last bonus mission would ask for
	# "mission 41", and `clampi` would silently hand back mission 40 — the
	# class would be sent back to a story mission they had already finished.
	#
	# The bonus list is walked by `Main`, which owns the hub screen; there is
	# nothing for `advance()` to decide.
	if extra_active:
		# A bonus challenge is never followed by another one automatically.
		# Finishing one comes back to the challenge list (see `Main`), which is
		# where a teacher chooses what to do next — and which is the only way
		# back out of the bonus flow. Auto-advancing here would leave a child
		# who wanted one more puzzle walking into the twentieth with no exit but
		# quitting the game.
		extra_return_requested.emit()
		return
	if _advanced_for_id == current_mission_id:
		return
	_advanced_for_id = current_mission_id
	var next_id := current_mission_id + 1
	if next_id > TOTAL_MISSIONS:
		all_missions_completed.emit()
		return
	var next_zone := _zone_of(next_id)
	if next_zone != current_zone:
		level_transition_requested.emit(next_zone, next_id)
	else:
		start_mission(next_id)


## Restarts the active mission from scratch (used by "Try again").
func restart_current() -> void:
	mission_started.emit(current_mission())


## Requests a soft, non-punishing hint for the active mission.
func request_translation() -> void:
	translation_requested.emit()


func set_easy_read(enabled: bool) -> void:
	easy_read = enabled


func set_sound(enabled: bool) -> void:
	sound_on = enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not enabled)
	if not enabled:
		AudioFx.stop_speech()


## Sets the difficulty (1..3), clamped. Emits so live panels can rebuild the
## hints they are showing without the level being reloaded.
func set_difficulty(level: int) -> void:
	var wanted := clampi(level, 1, 3)
	if wanted == difficulty:
		return
	difficulty = wanted
	difficulty_changed.emit(difficulty)


## How the camera is allowed to behave, as three named choices instead of a
## switch.
##
## "AUTO" is the original behaviour: scroll all the way in and the camera steps
## into Jack's head. That is delightful once a child has found it and confusing
## while they are still learning to steer, because a trackpad's momentum can
## carry them through the threshold by accident. "ALWAYS" is for a class that
## wants to play the whole game from inside Jack (a projector, a child who finds
## the third-person camera hard to read); "NEVER" locks the orbit view for a
## child who kept falling into first person by mistake.
##
## Three states rather than a checkbox because a checkbox cannot express "let me
## do it, but do not do it for me", which is what most children want.
const CAMERA_MODES: Array[Dictionary] = [
	{
		"id": 0,
		"name": "AUTO",
		"detail": "Scroll in to be Jack.",
		"detail_it": "Scorri avanti per essere Jack.",
	},
	{
		"id": 1,
		"name": "ALWAYS",
		"detail": "Play from Jack's eyes.",
		"detail_it": "Gioca con gli occhi di Jack.",
	},
	{
		"id": 2,
		"name": "NEVER",
		"detail": "Stay behind Jack.",
		"detail_it": "Resta dietro a Jack.",
	},
]


## The active camera mode, clamped against a corrupt save file.
func camera_mode_id() -> int:
	return clampi(camera_mode, 0, CAMERA_MODES.size() - 1)


## The dictionary of the active camera mode, for the settings page.
func camera_mode_info() -> Dictionary:
	var id := camera_mode_id()
	for entry in CAMERA_MODES:
		if int(entry["id"]) == id:
			return entry
	return CAMERA_MODES[0]


## Sets the camera mode (0..2), clamped, and emits so the level can apply it
## immediately instead of waiting for the next mission to be built.
func set_camera_mode(mode: int) -> void:
	var wanted := clampi(mode, 0, CAMERA_MODES.size() - 1)
	if wanted == camera_mode:
		return
	camera_mode = wanted
	camera_mode_changed.emit(camera_mode)


## Turns the auto-hide behaviour on or off. Emits so the panel that is already
## on screen folds or unfolds at once, rather than at the next mission.
func set_auto_hide_ui(enabled: bool) -> void:
	if enabled == auto_hide_ui:
		return
	auto_hide_ui = enabled
	auto_hide_ui_changed.emit(auto_hide_ui)


## Turns the automatic camera on or off, emitting so the rig of the mission that
## is already running obeys instead of waiting for the next build.
func set_auto_camera(enabled: bool) -> void:
	if enabled == auto_camera:
		return
	auto_camera = enabled
	auto_camera_changed.emit(auto_camera)


## Shows or removes the on-screen pad, emitting so the overlay appears (or folds
## away and lets go of any held direction) without a rebuild of the HUD.
func set_touch_controls(enabled: bool) -> void:
	if enabled == touch_controls:
		return
	touch_controls = enabled
	touch_controls_changed.emit(touch_controls)


## Remembers where the child dragged the on-screen pad.
##
## Emits only on a real change, for the same reason the toggles do: `_apply_origin()`
## listens, and a re-emit of the same value would move the pad again while the
## same value is set from the pad itself — a signal loop that looks like a stutter.
## The pad clamps before it gets here, so no validation is repeated; a `Vector2`
## is not something a child can type into a text field.
func set_touch_pad_position(pos: Vector2) -> void:
	if pos.is_equal_approx(touch_pad_position):
		return
	touch_pad_position = pos
	touch_pad_position_changed.emit(touch_pad_position)


## The five volume steps, as linear gains.
##
## The middle step is *not* 0.5: perceived loudness is roughly logarithmic, so
## linear halves sound like small changes. These values are spaced so each
## press of an arrow is an audible step of about the same size, and the top
## value leaves headroom rather than running the mix at unity.
const VOLUME_STEPS := [0.0, 0.22, 0.42, 0.62, 0.9]
## Names for the steps, so the settings page can say a word instead of a number.
## A child can read "LOUD" long before they can interpret a percentage.
const VOLUME_NAMES := ["OFF", "SOFT", "MEDIUM", "LOUD", "MAX"]


## Index (0..4) of a 0..1 volume value, nearest step.
static func volume_step_of(value: float) -> int:
	var best := 0
	var best_d := 999.0
	for i in VOLUME_STEPS.size():
		var d: float = absf(VOLUME_STEPS[i] - value)
		if d < best_d:
			best_d = d
			best = i
	return best


## Sets the music or effect level from a step index, and applies it at once.
##
## Applying here rather than in the panel means the bus cannot drift out of
## sync with the saved setting if a future screen forgets to listen to the
## signal. The signal is still emitted because the panel needs to redraw.
func set_volume(channel: String, step: int) -> void:
	var idx := clampi(step, 0, VOLUME_STEPS.size() - 1)
	var value: float = VOLUME_STEPS[idx]
	if channel == "music":
		if is_equal_approx(value, music_volume):
			return
		music_volume = value
		Music.apply_settings()
	else:
		if is_equal_approx(value, sfx_volume):
			return
		sfx_volume = value
		AudioFx.apply_settings()
	volume_changed.emit(channel, value)


## Current step index for a channel, for the settings UI.
func volume_step(channel: String) -> int:
	return volume_step_of(music_volume if channel == "music" else sfx_volume)


# --- Persistence -----------------------------------------------------------

## Writes progress to disk (user://jack_progress.json).
func save_progress() -> void:
	# A tool driving the game (smoke test, layout probe) must not leave the
	# child's save file holding the tool's 40 completed missions.
	if not persist:
		return
	var data := {
		"version": SAVE_VERSION,
		"current_mission_id": current_mission_id,
		"completed_missions": completed_missions,
		"flames": flames,
		"easy_read": easy_read,
		"sound_on": sound_on,
		"difficulty": difficulty,
		"camera_mode": camera_mode,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		# Bonus progress is an *extra* key with a default, never a reason to
		# bump SAVE_VERSION: a version bump makes `load_progress()` call
		# `_reset_state()`, which would wipe a class's forty flames in order to
		# remember twenty optional puzzles. Same treatment the volumes and the
		# difficulty already get.
		"extra_completed": extra_completed,
		"auto_hide_ui": auto_hide_ui,
		# Same lenient treatment as `auto_hide_ui` and the volumes: an optional
		# key with a default, never a `SAVE_VERSION` bump, because bumping the
		# version would wipe a class's forty flames to remember two switches.
		"auto_camera": auto_camera,
		"touch_controls": touch_controls,
		# The dragged pad position, stored as a two-number array because that is
		# what `JSON.stringify()` round-trips exactly; a `Vector2` would be
		# written as a string and read back as one. `(-1, -1)` is the "never
		# moved" sentinel and is written like any other value, so a child who
		# drags the pad back onto its home corner still gets their choice saved
		# rather than being reset to the default on the next launch.
		"touch_pad_position": [touch_pad_position.x, touch_pad_position.y],
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		# Happens when the OS user-data folder is unavailable (read-only or
		# sandboxed run). Progress simply is not persisted; the game continues.
		if not _save_warned:
			_save_warned = true
			push_warning("QuestManager: cannot write save file (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_state_changed.emit(true)


## Loads progress; silently starts a fresh game if the file is missing or old.
func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_state()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_reset_state()
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_reset_state()
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		_reset_state()
		return
	completed_missions.clear()
	for id in data.get("completed_missions", []):
		var value := int(id)
		if value >= 1 and value <= TOTAL_MISSIONS:
			completed_missions.append(value)
	completed_missions.sort()
	flames = completed_missions.size()
	# Resume at the first unsolved mission: no child can get stuck on a
	# mission they had already finished.
	var resume := TOTAL_MISSIONS
	for id in range(1, TOTAL_MISSIONS + 1):
		if not completed_missions.has(id):
			resume = id
			break
	current_mission_id = clampi(resume, 1, TOTAL_MISSIONS)
	current_zone = _zone_of(current_mission_id)
	easy_read = bool(data.get("easy_read", false))
	sound_on = bool(data.get("sound_on", true))
	# Old save files have no difficulty, so the *current* default is used: a save
	# written before the setting existed belongs to a class that never chose.
	# `difficulty` itself now defaults to 3 (see the declaration), which is the
	# level the game is meant to be played at; an explicit value in the file is
	# always honoured, so a class that chose "lots of help" keeps it.
	difficulty = clampi(int(data.get("difficulty", difficulty)), 1, 3)
	# Same treatment for the camera: absent means "whatever the shipped default
	# is today", present means the class already made a choice.
	camera_mode = clampi(int(data.get("camera_mode", camera_mode)), 0, CAMERA_MODES.size() - 1)
	# Volumes are read with defaults rather than by bumping SAVE_VERSION: a
	# version bump makes load_progress() call _reset_state(), which would wipe
	# the child's 39 flames to add a volume slider. New optional keys are what
	# `difficulty` already does two lines up, for the same reason.
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	# Read with a default, not a version bump: see the volume keys above.
	auto_hide_ui = bool(data.get("auto_hide_ui", auto_hide_ui))
	# Same rule. The default here is the *declared* one, so a save written
	# before these two settings existed gets the shipped behaviour (camera
	# following, pad shown) rather than inheriting whatever the last probe left
	# in memory.
	auto_camera = bool(data.get("auto_camera", auto_camera))
	touch_controls = bool(data.get("touch_controls", touch_controls))
	# The dragged pad position. Written as a two-number array, so read back as
	# one and accept nothing else: a hand-edited file with a string, a
	# dictionary or a single number must fall back to "never moved" rather than
	# throw, and `Vector2()` at the origin would put the pad in the top-left
	# corner — a real position, so the child would not even be able to tell it
	# had been misread. `(-1, -1)` is the sentinel that means "use the default",
	# and a stored value is *not* clamped here: only the pad knows how big it
	# really is, so `TouchControls._apply_origin()` clamps every assignment,
	# including this one.
	var stored_pad: Variant = data.get("touch_pad_position", [])
	if stored_pad is Array and (stored_pad as Array).size() == 2:
		touch_pad_position = Vector2(float(stored_pad[0]), float(stored_pad[1]))
	else:
		touch_pad_position = Vector2(-1, -1)
	# Bonus progress, read leniently for the same reason as the keys above: a
	# save written before the bonus missions existed simply has no bonus
	# progress, which is the correct starting state.
	extra_completed.clear()
	var total_extra := GameData.EXTRA_CHALLENGES.size()
	for value in data.get("extra_completed", []):
		var index := int(value)
		if index >= 1 and index <= total_extra and not extra_completed.has(index):
			extra_completed.append(index)
	extra_completed.sort()
	# The bonus flow itself is never resumed: a session always starts in the
	# story or on the hub, never in the middle of challenge 13. `extra_active`
	# is not in the save file at all, and a fresh run has it false.


## Wipes the save file and starts over from mission 1.
##
## `persist == false` must not delete the file either: a QA tool that restarts
## the run would otherwise erase the child's progress just as effectively as a
## save would overwrite it.
func reset_progress() -> void:
	_reset_state()
	if persist and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save_progress()


func _reset_state() -> void:
	completed_missions.clear()
	flames = 0
	current_mission_id = 1
	current_zone = 1
	easy_read = false
	sound_on = true
	# A brand-new installation starts on the hardest level (see the declaration
	# of `difficulty`) and on the camera behaviour that lets a child decide.
	difficulty = 3
	camera_mode = 0
	auto_hide_ui = true
	# The two ease-of-play switches go back to their shipped defaults, but only
	# in `_reset_state()`: they are *playability* settings rather than story
	# progress, and a reset is asked for precisely by a class that wants the
	# game as it came out of the box.
	auto_camera = true
	touch_controls = true
	# And the pad goes back to its home corner: it is a playability setting for
	# the same reason, and a class that asked for a fresh start expects the
	# controls where the game puts them, not wherever a previous child left them
	# half off the edge of a different screen.
	touch_pad_position = Vector2(-1, -1)
	# Starting over is a story choice, not a settings choice: the bonus
	# challenges are kept, because "PLAY AGAIN" offers to replay the story and
	# taking twenty solved puzzles away would punish a class for saying yes.
	extra_active = false
	extra_index = 0
	busy = false
