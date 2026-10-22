extends Node
## Background music service (autoload `Music`).
##
## Why this exists at all, for a game about words: silence in a 3D room reads as
## "the game is broken" to a seven-year-old, and a room that sounds different
## from the last one is what makes six zones feel like six places instead of one
## grey box with different props. The music is therefore *per zone*, not per
## mission, and it never stops for a quiz.
##
## Design rules that follow from being a background for language:
##  - It must sit under the voice. The tracks are mastered at -1.5 dBFS, so the
##    Music bus is pulled down well below the Master bus and the default
##    `music_volume` is deliberately lower than the default effect volume.
##  - It must duck while a character speaks, otherwise a child listening to
##    "find the green leaf" competes with a celesta. Ducking is a short linear
##    ramp on the bus, restored when the utterance ends.
##  - It must never crash the game. A missing or unimported .ogg leaves the game
##    silent but playable, with one warning, because a teacher on a school laptop
##    must not meet an error dialog.

## Two players, not one: they swap on every track change so the outgoing track
## can fade out while the incoming one fades in. Reusing a single player would
## mean either a hard cut (assigning `stream` mid-playback stops it dead) or
## tweening one player's stream mid-flight, which is far harder to reason about.
const FADE_TIME := 1.2
## Headroom applied to the Music bus on top of the user's step.
##
## The steps themselves already attenuate (MAX = -0.9 dB, MEDIUM = -7.5 dB, see
## `QuestManager.VOLUME_STEPS`), so this constant is only a safety trim: it keeps
## MAX from clipping when an effect on the SFX bus peaks at the same instant.
##
## Where the numbers land, from the generator's own report plus these gains:
## tracks are delivered at -1.5 dBFS peak / ~-16 dBFS RMS, so at the default
## MEDIUM the music sits at about -25 dBFS RMS, i.e. a background bed a spoken
## sentence (~-18 dBFS RMS) sits comfortably above. An earlier draft used -9 dB
## here, which a bus probe measured at -32 dBFS RMS: present but "a radio in the
## next room", not the playful background the game is going for.
const BASE_DB := -2.0
## How far the music drops while someone is talking.
const DUCK_DB := -7.0
## How far it drops while a story page is open. Shallower than speech: the page
## is read aloud too, so the two add up, but the room must still feel alive.
const STORY_DUCK_DB := -6.0
## Below this the bus is muted outright: a linear volume of 0.02 is inaudible
## anyway, and muting saves the mixer from summing silent voices.
const SILENT := 0.02

## zone id -> file stem in assets/music. Keyed by zone, not by `decor`, so a
## future rename of the decor key cannot silently mute a zone.
const ZONE_TRACKS := {
	1: "zone1_patch",
	2: "zone2_castle",
	3: "zone3_bog",
	4: "zone4_lab",
	5: "zone5_dungeon",
	6: "zone6_party",
}

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_id := ""
var _duck_until := 0.0
var _story_duck := false
var _warned: Dictionary = {}


func _ready() -> void:
	# Two players, both on the Music bus: one audible, one fading out.
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "MusicPlayer%d" % i
		p.bus = "Music"
		# The stream loops, but the player must not overlap itself: `stop()` on
		# a finished looping stream is what produces a click, so the stream's
		# own loop flag is set when it is loaded instead of relying on a timer.
		add_child(p)
		_players.append(p)
	_apply_volume()
	# The saved setting is applied after QuestManager has read the file, hence
	# the deferred call: autoloads are created in project order and Music is
	# declared after QuestManager, but relying on that order silently is how
	# these things break later.
	call_deferred("_apply_volume")


## Plays the track for a zone (1..6). Safe to call on every mission start: the
## track is left alone if it is already the one playing, so the music does not
## restart and lose its place every time a quiz opens.
func play_zone(zone_id: int) -> void:
	var id: String = ZONE_TRACKS.get(zone_id, "")
	if id.is_empty():
		push_warning("Music: no track mapped for zone %d" % zone_id)
		return
	play_track(id)


## Plays a named track from assets/music (without the extension).
func play_track(id: String) -> void:
	if id == _current_id and _players[_active].playing:
		return
	var stream := _load(id)
	if stream == null:
		# Deliberately not stopping what is playing: a missing file should leave
		# the previous mood in place rather than jolt the room into silence.
		return
	var outgoing := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_current_id = id
	# The fade is on volume_db rather than on the bus so the user's chosen
	# volume is untouched by it: tweening the bus would fight the setting.
	var tw := create_tween()
	tw.tween_property(incoming, "volume_db", 0.0, FADE_TIME)
	if outgoing.playing:
		var tw_out := create_tween()
		tw_out.tween_property(outgoing, "volume_db", -40.0, FADE_TIME)
		tw_out.tween_callback(outgoing.stop)


## Stops the music with a fade. Used on quit so shutdown never trims a note.
func stop_music() -> void:
	_current_id = ""
	for p in _players:
		if is_instance_valid(p) and p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, FADE_TIME * 0.5)
			tw.tween_callback(p.stop)


## Stops the music at once, without a fade, and drops the stream.
##
## This is the *shutdown* path, not the gameplay one: fading would be prettier,
## but a fade schedules its `stop()` on a tween that a quitting SceneTree never
## gets to run, and the playback is then still alive when Godot checks for leaks.
## Measured symptom before this existed: two headless smoke runs reported
## "leaked AudioStreamPlaybackOggVorbis" and "resource still in use:
## res://assets/music/title.ogg" on every exit, because the title theme was
## still playing when the harness called `quit()`.
func stop_now() -> void:
	_current_id = ""
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			# Dropping the stream as well is what lets the resource be released:
			# the playback holds it, and the playback lives on past `stop()`
			# until the audio server's next mix pass.
			p.stream = null


## Drops the music for roughly as long as a spoken line lasts.
##
## `seconds` is the clip's real length when the voice pack played it — known
## exactly, so it is passed in. The estimate from the word count stays for the
## text-to-speech fallback, where the game has no way to ask the OS engine "are
## you finished?". Measured: the recorded voice runs at ~2.2 words per second
## against the system voice's ~2.6, so the estimate that used to cover both
## under-ducks a recorded line by ~18% and the last syllable fights the music.
## `seconds <= 0` means "estimate from the text".
func duck_for_speech(text: String, seconds: float = 0.0) -> void:
	var secs := seconds
	if secs <= 0.0:
		var words := text.split(" ", false).size()
		# ~2.6 words per second is the measured pace of the system voice at the
		# game's default rate; the extra 0.6 s covers the release of the sentence.
		secs = words / 2.6 + 0.6
	# Floor of 0.8 s so a one-word line still ducks audibly; ceiling because a
	# long clip whose stream was freed mid-play must not hold the music down.
	secs = clampf(secs, 0.8, 30.0)
	_duck_until = maxf(_duck_until, Time.get_ticks_msec() / 1000.0 + secs)
	_apply_duck()


## Holds the music down for as long as `on` stays true.
##
## Used by the story page: a chapter sits on screen for as long as a teacher
## wants to talk about it, which is anywhere from ten seconds to five minutes,
## so there is no length to estimate. The zone stays audible underneath at a
## low level rather than being replaced by a separate "reading" track, because
## the page is still *in* that zone and a track change mid-chapter would make
## the room feel like it had moved.
func hold_duck(on: bool) -> void:
	_story_duck = on
	_apply_duck()


## Reads the volume setting from QuestManager and applies it. Called by the
## settings UI and on startup; kept in one place so the bus can never disagree
## with the saved value.
func apply_settings() -> void:
	_apply_volume()


# --- Internals -------------------------------------------------------------

func _apply_volume() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var v := clampf(QuestManager.music_volume, 0.0, 1.0)
	# Muting (rather than -80 dB) also makes the duck below a no-op instead of
	# arithmetic on a bus nobody can hear.
	AudioServer.set_bus_mute(idx, v < SILENT)
	if v < SILENT:
		return
	# linear_to_db is the right curve here because the *setting* is a level,
	# not a perception curve: the UI already offers coarse steps (loud/normal/
	# quiet/off) instead of a continuous slider, so no extra shaping is needed.
	AudioServer.set_bus_volume_db(idx, linear_to_db(v) + BASE_DB)


func _apply_duck() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	if QuestManager.music_volume < SILENT:
		return
	# Two ducks share one bus, so the smaller of the two wins: while a chapter
	# is open a single spoken sentence must not lift the music back up.
	var db := 0.0
	if _story_duck:
		db += STORY_DUCK_DB
	if _duck_until > 0.0:
		db += DUCK_DB
	AudioServer.set_bus_volume_db(idx,
		linear_to_db(clampf(QuestManager.music_volume, 0.001, 1.0)) + BASE_DB + db)


func _process(_delta: float) -> void:
	# Unduck without a timer node: one comparison per frame is cheaper than
	# another SceneTreeTimer that has to be cancelled when speech is cut short.
	if _duck_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _duck_until:
		_duck_until = 0.0
		_apply_duck()


func _load(id: String) -> AudioStream:
	var path := "res://assets/music/%s.ogg" % id
	if not ResourceLoader.exists(path):
		if not _warned.has(id):
			_warned[id] = true
			push_warning("Music: missing track %s (game continues in silence)" % path)
		return null
	var stream := load(path)
	if stream is AudioStreamOggVorbis:
		# Without this the loop plays once and the room falls silent after
		# fifteen seconds, which is exactly the bug this service exists to fix.
		(stream as AudioStreamOggVorbis).loop = true
	return stream


## Releases the players and their streams on the way out.
##
## Same reason as `AudioFx._exit_tree()`: an `AudioStreamPlayer` that is still
## holding a stream when the tree is torn down keeps that stream alive until the
## audio server's next mix pass, and during shutdown there is no next pass -- so
## Godot reports leaked ObjectDB instances and "resources still in use". A
## headless test that quits right after a track started is the case that shows
## it, but the same would happen to a child who alt-F4s out of the game.
func _exit_tree() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_players.clear()
	_current_id = ""
