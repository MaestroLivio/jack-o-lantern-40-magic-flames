extends SceneTree
## Collects every string the game can possibly speak, by walking the *data*.
##
## The alternative — a regex over the .gd files — is what produced the first,
## wrong estimate (273 strings): it cannot see `"%s. Well done!" % label`, it
## counts commented-out text, and it silently misses a whole family when a
## mission is written in a shape it did not expect. This runs inside the engine
## and asks the same autoloads the game asks, so a string it does not know about
## is a string the game cannot say either.
##
## Output is one JSON object per line (JSON Lines), so the Python pack builder can
## stream it without parsing GDScript:
##
##   {"lang": "en", "text": "Find the RED, BLUE and YELLOW pumpkins!"}
##   {"lang": "it", "text": "Trova le zucche ROSSA, BLU e GIALLA!"}
##
##   godot --headless --path . --script tools/collect_speech.gd > /tmp/corpus.jsonl
##
## The normalisation and the de-duplication happen in the pack builder, not here:
## this tool's only job is to be complete. The walk itself lives in
## `tools/speech_corpus.gd`, because `tools/voice_pack_check.gd` has to replay the
## exact same list — a checker built on a different list proves nothing.

const Corpus := preload("res://tools/speech_corpus.gd")


func _initialize() -> void:
	# Autoloads are plain nodes here; a `--script` tool cannot use the bare
	# identifiers (`GameData`, `Story`) the game uses.
	var data: Node = root.get_node_or_null("GameData")
	var story: Node = root.get_node_or_null("Story")
	if data == null or story == null:
		push_error("collect_speech: GameData/Story autoloads missing")
		quit(1)
		return

	var rows: Array = Corpus.build(data, story)
	var en := 0
	var it := 0
	for row in rows:
		if String(row.get("lang", "en")) == "it":
			it += 1
		else:
			en += 1
		print(JSON.stringify(row))
	print("[collect] en=%d it=%d" % [en, it])
	quit(0)
