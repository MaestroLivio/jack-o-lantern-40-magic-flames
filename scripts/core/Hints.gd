class_name Hints
extends RefCounted
## How much visual help the game shows, derived from the difficulty setting.
##
## The GDD's teaching order is "see it, hear it, say it, read it". The first two
## difficulty levels lean on *seeing*: every English word sits next to a picture
## of what it means, so a child can decode "green" from a green swatch without
## knowing the word. That is exactly the crutch a teacher wants to take away
## later — at the higher levels the picture is withdrawn and the child has to
## know that "green" *means* that colour, on their own.
##
## One place decides, so the HUD, the quiz and the sequence mission can never
## disagree about how much to give away:
##
##     if Hints.word_chips_have_icons():
##         chip.add_child(icon)
##
## The level itself lives in `QuestManager.difficulty` (1..3) so it is saved with
## the rest of the settings. Like `UiKit`, this file reads the autoload through
## the scene tree instead of by name: `--script` tools do not register autoload
## identifiers, and a bare `QuestManager` here would break every one of them.

## Three named levels, in the order the settings page offers them.
const LEVELS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "LOTS OF HELP",
		"name_it": "Tanto aiuto",
		"detail": "Pictures next to every word.",
		"detail_it": "Disegni accanto a ogni parola.",
	},
	{
		"id": 2,
		"name": "SOME HELP",
		"name_it": "Un po' di aiuto",
		"detail": "Words only: read the word, remember the picture.",
		"detail_it": "Solo parole: leggi la parola, ricorda il disegno.",
	},
	{
		"id": 3,
		"name": "ALL BY MYSELF",
		"name_it": "Tutto da solo",
		"detail": "No picture clues and no free hints.",
		"detail_it": "Nessun indizio visivo e nessun aiuto gratis.",
	},
]

const MIN_LEVEL := 1
const MAX_LEVEL := 3


## The active level, clamped: a corrupt save can never push it out of range.
static func level() -> int:
	var quest := _quest_manager()
	if quest == null:
		return MIN_LEVEL
	return clampi(int(quest.get("difficulty")), MIN_LEVEL, MAX_LEVEL)


static func _quest_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("QuestManager")


## The dictionary of `level()`, for the settings page.
static func current_level_info() -> Dictionary:
	var id := level()
	for entry in LEVELS:
		if int(entry["id"]) == id:
			return entry
	return LEVELS[0]


## The level above/below `id`, for the settings page's arrows.
static func neighbour(id: int, step: int) -> int:
	return clampi(id + step, MIN_LEVEL, MAX_LEVEL)


# --- What the level switches off ------------------------------------------

## Level 1: the keyword chips in the HUD carry a picture of their meaning.
## From level 2 the chip is the word alone, so "green" has to be understood
## rather than read off the colour of a pumpkin next to it.
static func word_chips_have_icons() -> bool:
	return level() < 2


## The keyword chips themselves. Level 3 hides the row entirely: the child has
## the spoken instruction and nothing else to lean on.
static func prompt_shows_keywords() -> bool:
	return level() < 3


## Quiz cards keep the word under the picture until level 3. Matching a spoken
## word to a picture is the *reading* step; naming the picture is the step after.
static func quiz_cards_show_word() -> bool:
	return level() < 3


## After a wrong answer the correct card glows, so the next tap cannot fail.
## Level 3 removes that safety net — the child tries again on their own.
static func quiz_reveals_correct() -> bool:
	return level() < 3


## Sequence missions keep the next pad lit and breathing. At level 3 only the
## *first* pad is shown: the rest of the order has to be remembered. Touching a
## later pad still flashes the right one (the existing gentle nudge), so this is
## never a dead end.
static func sequence_always_glows() -> bool:
	return level() < 3


## Number missions ask for a *set* of numbers, and their hint line can repeat the
## wanted digits. It stops doing so at level 3: the prompt already names the
## numbers as English words ("find THREE, SEVEN and TWELVE"), so printing "3, 7,
## 12" underneath would quietly turn a reading task into a matching task.
static func number_hints_show_digits() -> bool:
	return level() < 3


## Spelling missions (the bonus set) show the word above the letter slots until
## level 3. Copying the word is the *reading* step; holding five letters in
## memory after one hearing is the step after, and it is exactly what level 3
## asks for. The letters that are already placed stay on screen at every level:
## they are the child's own work, not a hint.
static func spelling_shows_word() -> bool:
	return level() < 3


## After a wrong letter the key that is actually needed glows, so the next tap
## cannot fail. Level 3 removes that safety net, consistently with
## `quiz_reveals_correct()`: at the top level the child finds the letter alone.
static func spelling_reveals_letter() -> bool:
	return level() < 3


## The one-line explanation of the active level, for the settings page.
static func describe() -> String:
	return String(current_level_info().get("detail", ""))
