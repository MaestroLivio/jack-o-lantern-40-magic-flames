extends Node
## Audio & voice service (autoload `AudioFx`).
##
## Two jobs:
##  1. `speak()` reads English (or Italian) text aloud, from the recorded voice
##     pack that ships in `assets/voice/`. The operating system's text-to-speech
##     is only the fallback for a sentence nobody recorded — see `speak()` for why
##     the order is that way round.
##  2. `play_sfx()` plays tiny synthesised sound effects. They are generated
##     as WAV data at runtime, so the effects add no weight to the download and
##     a teacher can be sure none of them contains a voice the child does not
##     know. Background *music* is the one thing that ships as files: see the
##     `Music` autoload, and `tools/make_music.py` for how they were made.

## Master level for speech, 0..1. Kept gentle for young ears.
##
## Speech is *not* one of the two settings on the sound page: the game's whole
## point is hearing the English words, and a child who turns the voice down has
## turned the lesson off while leaving the game running. The effects and the
## music are the two things worth letting them change.
@export_range(0.0, 1.0) var speech_volume: float = 0.9
## When true every spoken line is also printed to the console (useful for
## teachers checking a lesson without sound).
@export var print_speech: bool = false

const SAMPLE_RATE := 22050

var _speech_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _next_player := 0
var _en_voice: String = ""
var _it_voice: String = ""
var _tts_available := false
var _utterance_counter := 0

## Text → clip name, built once from `assets/voice/voice_pack.json`.
##
## The pack is indexed by the *sentence*, not by an id, and that is deliberate.
## `speak()` is called from forty-odd places and most of them assemble the
## sentence at runtime ("Find %s first!" % word, "A magic flame! %d",
## "Not this one. Look for %s.") — a key per string would mean editing every one
## of those call sites and getting each right, and the first one missed is a line
## that silently goes back to the system voice. A lookup on the normalised text
## covers them all, including the call sites a future edit adds.
var _voice_pack: Dictionary = {}
## True once the manifest has been read, whether or not it had any entries. The
## lookup is on the speech path, so it must not re-stat the file every sentence.
var _voice_pack_loaded := false
## Set by a tool or a test that needs the raw sentences: every line that fell
## through the pack is collected here so `tools/voice_pack_check.gd` can report
## exactly which sentences are missing instead of guessing.
var voice_pack_misses: Array[String] = []
## Manifest entries whose `.ogg` could not be loaded. Separate from
## `voice_pack_misses` because it is a *different* fault: a miss means nobody
## recorded that sentence, whereas this means the manifest promises a clip that
## is not there — a truncated copy, a build that forgot to export the audio, or an
## un-imported `.ogg`. Reported by `tools/voice_pack_check.gd`, which fails on it:
## the fallback hides it, but every one of these is a sentence read in a different
## voice from the rest of the game.
var voice_pack_broken: Array[String] = []
## When true, every miss is appended to `voice_pack_misses`. Off by default: the
## array is only useful to `tools/voice_pack_check.gd`, and in a normal session
## it would grow without bound.
var collect_misses := false
## Loaded clips, by manifest name. A mission can ask for the same sentence a
## dozen times (the "listen again" button), and `load()` on an imported .ogg is
## cheap but not free.
var _voice_clip_cache: Dictionary = {}

## Path of the manifest, relative to the project.
const VOICE_PACK_INDEX := "res://assets/voice/voice_pack.json"
const VOICE_PACK_DIR := "res://assets/voice"


func _ready() -> void:
	# Speech needs its own player so it never cuts a sound effect (and vice versa).
	_speech_player = AudioStreamPlayer.new()
	_speech_player.name = "SpeechPlayer"
	# Its own bus so the music can duck under the voice without the voice
	# having to be louder than everything else to be understood.
	_speech_player.bus = "Voice"
	add_child(_speech_player)

	# A small pool lets overlapping beeps ring out together. They share the SFX
	# bus, which is where the settings menu's volume control actually lands:
	# one place to turn the effects down, instead of an exported number per
	# player that nothing can reach from the UI.
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	_detect_tts()
	apply_settings()


## Pushes the saved effect level onto the SFX bus. Called on startup and whenever
## the settings change, so the panel never has to know about buses.
##
## The level itself lives in `QuestManager.sfx_volume` and *only* there: an
## `@export` here as well would give the two settings screens two different
## truths, and the Inspector value would win on the first startup while the
## saved value won after that.
func apply_settings() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	var v := clampf(QuestManager.sfx_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	if v > 0.001:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))


func _detect_tts() -> void:
	_tts_available = DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
	if not _tts_available:
		# Not an error any more. Before the voice pack this meant silence; now the
		# game speaks its whole fixed corpus from `assets/voice/` and only a line
		# added after the last recording would go unspoken. Warning wording kept
		# accurate so a teacher reading the log is not alarmed by a normal state.
		push_warning("AudioFx: no text-to-speech engine; using the voice pack only.")
		return
	var en_voices := DisplayServer.tts_get_voices_for_language("en")
	if en_voices.size() > 0:
		_en_voice = en_voices[0]
	var it_voices := DisplayServer.tts_get_voices_for_language("it")
	if it_voices.size() > 0:
		_it_voice = it_voices[0]
	if _en_voice.is_empty():
		# Fall back to any voice; the child still hears the English words.
		var all := DisplayServer.tts_get_voices()
		if all.size() > 0:
			_en_voice = String(all[0]["name"])


## Stops every sound effect immediately. Speech is left to `stop_speech()` so the
## two can be silenced independently.
##
## Exists because "still playing at shutdown" is what makes Godot report leaked
## `AudioStreamWAV` objects: the playback object holds a reference to its stream,
## and the reference is released on the audio server's next mix pass, i.e. on a
## later frame. Anything that quits the game has to stop the effects, wait a
## frame or two, and only then call `quit()`.
func stop_sfx() -> void:
	for p in _sfx_players:
		if is_instance_valid(p):
			p.stop()


## Reads `text` aloud. `lang` is "en" or "it"; `rate` < 1.0 is slower.
##
## Order of preference, and why:
##
##   1. **The shipped voice pack.** Same voice on every computer, zero latency,
##      and the one the class's English lesson is modelled on. This is the case
##      that almost always hits: the pack is generated from the game's own data
##      (`tools/collect_speech.gd`), so every fixed sentence exists.
##   2. **The system's text-to-speech**, for anything the pack does not have —
##      a sentence a teacher just edited, a brand-new mission. Saying it in a
##      slightly different voice is much better than saying nothing, and the miss
##      is recorded so `tools/voice_pack_check.gd` can report it.
##
## `rate` only affects the fallback: the recorded clips are baked at the pace the
## pack was generated with (see `make_voice_pack.py --length-scale`), which is
## deliberately a little slower than the voices' own default for young learners.
func speak(text: String, lang: String = "en", rate: float = 0.9) -> void:
	var clean := normalize_speech(text)
	if clean.is_empty():
		return
	if print_speech:
		print("[speech/%s] %s" % [lang, clean])
	# The music steps back while the words are spoken, on *both* paths. A child
	# being asked "find the green leaf" must hear the sentence, not compete with
	# it. This used to sit only on the text-to-speech branch, which was correct
	# when that branch was the only one; once the pack took over, the common case
	# stopped ducking and the voice had to fight the music. Guarded because the
	# smoke harness runs before/without music in some modes.
	#
	# Nothing here returns early on "no TTS": a machine without a voice engine
	# still has the pack, and that is the whole point of shipping one.
	_ensure_voice_pack()
	var stream := _pack_stream(clean, lang)
	if stream != null:
		# The clip knows its own length, so the duck matches it exactly instead of
		# being guessed from the word count.
		if is_instance_valid(Music):
			Music.duck_for_speech(clean, stream.get_length())
		play_stream(stream)
		return
	if is_instance_valid(Music):
		Music.duck_for_speech(clean)
	if not _tts_available:
		return
	var voice := _en_voice if lang.begins_with("en") else _it_voice
	if voice.is_empty():
		voice = _en_voice
	if voice.is_empty():
		return
	_utterance_counter += 1
	# Interrupting keeps the audio in sync with what is on screen.
	DisplayServer.tts_speak(clean, voice, int(clampf(speech_volume, 0.0, 1.0) * 100.0),
		rate, rate, _utterance_counter, true)


## The canonical form of a sentence, used to look it up in the pack.
##
## Must match `normalize()` in `tools/make_voice_pack.py`: a key that differs by
## one apostrophe is a sentence that silently goes back to the system voice. The
## typographic characters are folded because the story text uses `'` and `"`,
## while a different editor (or a teacher's correction) may produce `'` and `"`
## for exactly the same sentence.
func normalize_speech(text: String) -> String:
	var out := text
	for pair in [["\u2019", "'"], ["\u2018", "'"], ["\u201c", "\""], ["\u201d", "\""],
			["\u2014", "-"], ["\u2013", "-"], ["\u00a0", " "]]:
		out = out.replace(String(pair[0]), String(pair[1]))
	out = out.replace("\n", " ").replace("\r", " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()


## Reads the manifest once. A missing or unreadable pack is not an error: the
## game simply uses the system voice, which is exactly what it did before.
func _ensure_voice_pack() -> void:
	if _voice_pack_loaded:
		return
	_voice_pack_loaded = true
	if not FileAccess.file_exists(VOICE_PACK_INDEX):
		return
	var raw := FileAccess.get_file_as_string(VOICE_PACK_INDEX)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_warning("AudioFx: %s is not valid JSON; using the system voice." % VOICE_PACK_INDEX)
		return
	var clips: Variant = (parsed as Dictionary).get("clips", {})
	if not clips is Dictionary:
		return
	_voice_pack = clips as Dictionary


## The loaded clip for `text`, or null when the pack does not have it.
##
## Split out from playback rather than returning a bool, because the caller needs
## the stream's length to duck the music for exactly the right time; a bool would
## force `speak()` to look the clip up a second time.
##
## The manifest is keyed "en|<sentence>" / "it|<sentence>". Hashing here too
## would mean two implementations of the same hash having to agree forever;
## asking for the sentence by name cannot drift. `voice_pack_misses` is only
## filled when a tool asked for it, so the array does not grow unbounded in a
## normal session.
func _pack_stream(text: String, lang: String) -> AudioStream:
	var name := String(_voice_pack.get("%s|%s" % [lang.left(2), text], ""))
	if name.is_empty():
		if collect_misses and not voice_pack_misses.has("%s|%s" % [lang.left(2), text]):
			voice_pack_misses.append("%s|%s" % [lang.left(2), text])
		return null
	var stream := _load_voice_clip(name)
	if stream == null and collect_misses and not voice_pack_misses.has("%s|%s" % [lang.left(2), text]):
		# The manifest promised a clip and it would not load; `_load_voice_clip`
		# has already recorded it in `voice_pack_broken`. Reported as a plain miss
		# too, because from `speak()`'s point of view this sentence is unserved.
		voice_pack_misses.append("%s|%s" % [lang.left(2), text])
	return stream


func _load_voice_clip(name: String) -> AudioStream:
	if _voice_clip_cache.has(name):
		return _voice_clip_cache[name] as AudioStream
	var path := "%s/%s.ogg" % [VOICE_PACK_DIR, name]
	# Both failures below are silent to the player — the sentence is still read,
	# just in the system voice — so they are recorded instead. `ResourceLoader`
	# needs the `.import` file that Godot writes when the project is scanned; a
	# pack copied into `assets/voice/` without running `--import` produces exactly
	# this, and the only symptom is an inconsistent voice.
	if not ResourceLoader.exists(path):
		if collect_misses and not voice_pack_broken.has(name):
			voice_pack_broken.append(name)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		if collect_misses and not voice_pack_broken.has(name):
			voice_pack_broken.append(name)
		return null
	_voice_clip_cache[name] = stream
	return stream


## True when the shipped pack is present and indexed.
func has_voice_pack() -> bool:
	_ensure_voice_pack()
	return not _voice_pack.is_empty()


## How many sentences the pack can say. Used by the QA tools and by the settings
## page, so a teacher can tell a class "the voice is the game's own".
func voice_pack_size() -> int:
	_ensure_voice_pack()
	return _voice_pack.size()


## Stops whatever is being spoken — the recorded clip as well as the system voice.
##
## Both halves are needed. `tts_stop()` cannot stop an `AudioStreamPlayer`, so
## before the voice pack a "stop" left a recorded line running; and the player
## has to be stopped even when there is no TTS engine at all, which is now a
## normal state (the pack works on a machine with no voices installed).
func stop_speech() -> void:
	if _tts_available:
		DisplayServer.tts_stop()
	if is_instance_valid(_speech_player):
		_speech_player.stop()


## Releases the cached clips and the loaded manifest.
##
## A cached `AudioStreamOggVorbis` is a live resource, and Godot reports anything
## still alive at shutdown as "N resources still in use at exit" — which is what
## an earlier version of this class printed on every run of the QA probes once the
## clip cache was added (880 clips are reachable from `_voice_clip_cache`). The
## fix is not to silence the warning: it is that a quit path has to *let go* of
## the audio before the audio server shuts down, the same reason `Music.stop_now()`
## drops the stream instead of only stopping the player. Called from
## `Main._quit_cleanly()`, which already waits two mix passes afterwards.
##
## `_voice_pack` is cleared too, and `_voice_pack_loaded` is reset, so this class
## is left in exactly the state it started in and a second call is harmless.
func release_cache() -> void:
	if is_instance_valid(_speech_player):
		_speech_player.stop()
		_speech_player.stream = null
	_voice_clip_cache.clear()
	_voice_pack.clear()
	_voice_pack_loaded = false


## Plays a pre-recorded clip on the speech channel.
func play_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	# A `--script` tool reaches this autoload from `_initialize()`, which on some
	# runs happens before the node has entered the tree and run `_ready()`. There
	# is no speaker at that point — and none is wanted, because the QA probes mute
	# the voice anyway — but the *lookup* they are testing must still succeed, so
	# this returns quietly rather than crashing on a null player.
	if not is_instance_valid(_speech_player):
		return
	if _tts_available:
		DisplayServer.tts_stop()
	_speech_player.stream = stream
	_speech_player.volume_db = linear_to_db(clampf(speech_volume, 0.001, 1.0))
	_speech_player.play()


## A short positive "ding" used for every success. Error-free learning means
## the wrong-answer sound is a soft "boop", never a buzzer.
func play_sfx(kind: String) -> void:
	var stream := _get_or_build(kind)
	if stream == null:
		return
	var p := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	p.stream = stream
	# No per-player gain: the SFX bus carries the user's setting now, and
	# applying linear_to_db here as well would multiply the two, so "medium"
	# would land at roughly a quarter of "medium".
	p.play()


func _get_or_build(kind: String) -> AudioStreamWAV:
	if _sfx_cache.has(kind):
		return _sfx_cache[kind]
	var stream := _build_sfx(kind)
	if stream != null:
		_sfx_cache[kind] = stream
	return stream


## Detaches every stream on the way out, as a backstop for the exits that do not
## go through the smoke harness.
##
## This alone does **not** silence the leak warning: the audio server releases a
## playback on its next mix pass, and during shutdown there is no next pass. That
## is why the harness calls `stop_sfx()` and waits two frames before `quit()`;
## the detaching here is what keeps the cache from outliving the node.
func _exit_tree() -> void:
	stop_speech()
	stop_sfx()
	for p in _sfx_players:
		if is_instance_valid(p):
			p.stream = null
	if is_instance_valid(_speech_player):
		_speech_player.stop()
		_speech_player.stream = null
	_sfx_cache.clear()


## Synthesises a small sound. Each kind is a short sequence of notes with a
## soft envelope, so nothing ever clicks or startles.
func _build_sfx(kind: String) -> AudioStreamWAV:
	var notes: Array = []
	match kind:
		"correct", "success":
			# A rising major triad: the signature "you did it" of the game.
			notes = [[523.25, 0.09], [659.25, 0.09], [783.99, 0.22]]
		"wrong", "soft":
			# A gentle two-note "boop": kind, never punishing.
			notes = [[392.0, 0.1], [329.63, 0.16]]
		"pickup":
			notes = [[880.0, 0.06], [1174.66, 0.1]]
		"flame":
			notes = [[659.25, 0.07], [880.0, 0.07], [1046.5, 0.07], [1318.5, 0.24]]
		"step":
			notes = [[220.0, 0.05]]
		"pop":
			notes = [[740.0, 0.05]]
		"win":
			notes = [[523.25, 0.12], [659.25, 0.12], [783.99, 0.12], [1046.5, 0.1], [1318.5, 0.4]]
		"magic":
			notes = [[1046.5, 0.06], [1318.5, 0.06], [1567.98, 0.18]]
		"trap":
			notes = [[196.0, 0.12], [174.61, 0.18]]
		_:
			notes = [[660.0, 0.08]]

	var total_samples := 0
	for n in notes:
		total_samples += int(SAMPLE_RATE * float(n[1]))
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var cursor := 0
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var count := int(SAMPLE_RATE * dur)
		for i in count:
			var t := float(i) / float(SAMPLE_RATE)
			# Fade in/out within each note keeps the tone smooth.
			var attack := clampf(float(i) / (SAMPLE_RATE * 0.006), 0.0, 1.0)
			var release := clampf(float(count - i) / (SAMPLE_RATE * 0.03), 0.0, 1.0)
			var env := attack * release
			# Fundamental plus a quiet octave: a warm "toy instrument" timbre.
			var value := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.18
			var sample := int(clampf(value * env, -1.0, 1.0) * 32767.0)
			data.encode_s16(cursor * 2, sample)
			cursor += 1

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
