extends SceneTree
## Regression probe: can the shipped voice pack say every line the game says?
##
## The pack (`assets/voice/`) exists so that the English lesson sounds the same on
## every computer. That only holds if the corpus the pack was built from and the
## corpus the game actually speaks are the same list. They are two different
## things written at two different times, so they drift:
##
##   * a mission is added, and its prompt is not recorded → that one line is read
##     by whatever voice the machine has, mid-lesson;
##   * a clip is generated but the project was never re-imported, so
##     `ResourceLoader.exists()` is false → the fallback fires even though the
##     audio is sitting right there on disk;
##   * a typographic apostrophe changes in the story text and the normalised key
##     no longer matches → silent, because the fallback is *by design* silent.
##
## None of those is visibly broken in the running game. This is the only place
## that can tell, so it fails loudly:
##
##   godot --headless --path . --script tools/voice_pack_check.gd
##
## Exit code 0 only when the manifest covers the whole corpus *and* every clip it
## names loads. The replay goes through `AudioFx.speak()` — the real entry point —
## rather than through the pack lookup directly, so the probe also covers the
## normalisation both sides have to agree on.

const Corpus := preload("res://tools/speech_corpus.gd")
const Shutdown := preload("res://tools/probe_shutdown.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var audio: Node = root.get_node_or_null("AudioFx")
	var data: Node = root.get_node_or_null("GameData")
	var story: Node = root.get_node_or_null("Story")
	if audio == null or data == null or story == null:
		_fail("AudioFx/GameData/Story autoloads missing")
		_report()
		return

	if not bool(audio.call("has_voice_pack")):
		# A missing pack is not a crash: the game falls back to the system voice,
		# which is what it did before any of this existed. It is a *failure* here
		# all the same, because the point of this tool is to check the pack, and a
		# green run with no pack would be a lie.
		_fail("no voice pack: assets/voice/voice_pack.json is missing or empty")
		_report()
		return

	var rows: Array = Corpus.build(data, story)
	var expected := int(audio.call("voice_pack_size"))

	# Speech must not actually come out of the speakers a thousand times, and the
	# player must not be left with a queue of clips to play over each other.
	audio.set("print_speech", false)
	audio.set("collect_misses", true)
	audio.set("speech_volume", 0.0)

	var said := 0
	for row in rows:
		var lang := String(row.get("lang", "en"))
		var text := String(row.get("text", ""))
		if text.is_empty():
			continue
		audio.call("speak", text, lang, 0.9)
		said += 1
		# A clip is ~1-3 s. Only the load matters here, not the listening, so the
		# player is stopped again immediately; a thousand overlapping clips would
		# otherwise be mixed on every frame of the loop.
		audio.call("stop_speech")

	audio.set("collect_misses", false)

	var misses: Array = audio.get("voice_pack_misses")
	var broken: Array = audio.get("voice_pack_broken")

	for m in misses:
		_fail("not in the pack: %s" % String(m))
	for b in broken:
		_fail("manifest names a clip that will not load: %s.ogg" % String(b))

	print("[voice] corpus=%d lines, manifest=%d clips, misses=%d, broken=%d"
		% [said, expected, misses.size(), broken.size()])

	# The two directions are different faults, so they are checked separately. A
	# manifest *larger* than the corpus is not an error — the pack legitimately
	# keeps clips for sentences a mission used to say, and re-recording 1000 clips
	# to drop three of them is not worth it. Only unwritable lines matter.
	if said > 0 and expected < said / 2:
		_fail("the manifest covers only %d of %d sentences; was the pack generated "
			% [expected, said] + "before the data changed? Re-run tools/make_voice_pack.py --force")

	_report()


func _fail(msg: String) -> void:
	_failures.append(msg)
	print("[voice] FAIL " + msg)


func _report() -> void:
	if _failures.is_empty():
		print("[voice] OK: every sentence the game can say is in the pack")
		await Shutdown.and_quit(self, 0)
		return
	print("[voice] %d failure(s)" % _failures.size())
	await Shutdown.and_quit(self, 1)
