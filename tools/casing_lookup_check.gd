extends SceneTree
## End-to-end proof that the game's shouted keywords now reach a clip that says
## the *word*. `tools/voice_pack_check.gd` proves every sentence has a file; this
## proves the file it lands on was synthesised from the de-shouted text.
##
## The distinction matters because the pack is keyed by the sentence. After the
## casing fix, `speak("Find the RED …")` normalises to `Find the Red …` and looks
## up *that* key. If the two sides ever disagreed again, the lookup would miss and
## the line would fall back to the system voice — which spells `RED` out as well,
## so the bug would come back looking exactly like the original report.
##
##     godot --headless --path . --script tools/casing_lookup_check.gd

const Shutdown := preload("res://tools/probe_shutdown.gd")

## `[language, sentence as the game writes it]`.
const SPOKEN := [
	["en", "Find the RED, BLUE and YELLOW pumpkins!"],
	["en", "Find the BIG BLACK SPIDER."],
	["en", "Find the SMALL WHITE CAT."],
	["en", "Select the RED TRIANGLE nose."],
	["en", "Step on the leaves in order: RED, GREEN, BLUE."],
	["en", "Which one is BIG?"],
	["en", "Find the GREEN bat ON the tree."],
	["it", "Trova le zucche ROSSA, BLU e GIALLA!"],
	["it", "Scegli l'occhio CERCHIO BLU."],
	["it", "Pesta le foglie in ordine: ROSSA, VERDE, BLU."],
	# Not a casing case at all: proof that an ordinary line still resolves, so a
	# green run here cannot be an artefact of every lookup failing.
	["en", "Find the HAPPY pumpkin. Ignore the sad pumpkin."],
]


func _initialize() -> void:
	var audio := root.get_node_or_null("AudioFx")
	if audio == null:
		print("[lookup] FAIL: AudioFx autoload not found")
		await Shutdown.and_quit(self, 1)
		return

	# A lookup miss is silent by design, so the tool asks the pack directly
	# instead of listening. `_pack_stream` is the exact function `speak()` calls,
	# but `speak()` loads the manifest first — calling it cold would report every
	# sentence as missing, which is a bug in this tool and looks identical to a
	# bug in the game.
	audio.call("_ensure_voice_pack")
	var failures := 0
	for row in SPOKEN:
		var lang: String = row[0]
		var shouted: String = row[1]
		var clean := String(audio.call("normalize_speech", shouted))
		var stream: AudioStream = audio.call("_pack_stream", clean, lang)
		if stream == null:
			failures += 1
			print("[lookup] MISS  %s" % shout_line(lang, shouted))
			continue
		print("[lookup] ok    %-3s %-46s %.2f s  %s" % [lang, clean, stream.get_length(), shouted])
	print("[lookup] %d sentence(s), %d miss(es)" % [SPOKEN.size(), failures])
	# `_pack_stream` remembers misses for the QA report; clear it so a later run
	# in the same process is not judged by this one.
	var empty: Array[String] = []
	audio.set("voice_pack_misses", empty)
	await Shutdown.and_quit(self, 1 if failures > 0 else 0)


func shout_line(lang: String, text: String) -> String:
	return "%-3s %s" % [lang, text]
