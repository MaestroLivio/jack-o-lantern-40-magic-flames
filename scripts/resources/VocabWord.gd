class_name VocabWord
extends Resource
## A single teachable word or sentence.
##
## Holds the English text, its Italian translation (revealed by the
## "Magic Italian Magnifying Glass"), an optional icon and an optional
## pre-recorded pronunciation. When no recording exists — which is the normal
## case, since the shipped voice pack is keyed by the word itself — the
## `AudioFx` autoload plays the word from the pack, and only a word the pack has
## never heard of reaches the system text-to-speech engine.

@export_multiline var english_text: String = ""
@export_multiline var italian_translation: String = ""
@export var icon: Texture2D
@export var audio_pronunciation: AudioStream
## Speaking speed multiplier. Slightly below 1.0 keeps the pace gentle.
@export_range(0.5, 1.5, 0.05) var speech_rate: float = 0.9
## Optional hint shown as a picture-word card (kind used by PropFactory).
@export var prop_kind: String = ""


## Speaks the English word with the recorded clip if available, otherwise
## through the voice pack (and its text-to-speech fallback).
func speak() -> void:
	if english_text.is_empty():
		return
	if audio_pronunciation != null:
		AudioFx.play_stream(audio_pronunciation)
	else:
		AudioFx.speak(english_text, "en", speech_rate)


## Speaks the Italian translation, if there is one.
func speak_italian() -> void:
	if italian_translation.is_empty():
		return
	AudioFx.speak(italian_translation, "it", 0.95)
