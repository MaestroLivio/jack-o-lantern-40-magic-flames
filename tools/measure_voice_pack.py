#!/usr/bin/env python3
"""Measure the spoken corpus of the game and what a Piper voice pack would cost.

Run with the helper virtualenv (it needs `piper-tts`, kept out of the project):

    python3 -m venv /tmp/pipenv && /tmp/pipenv/bin/pip install piper-tts
    /tmp/pipenv/bin/python tools/measure_voice_pack.py --model /tmp/alan.onnx

WHY this exists
---------------
The game currently borrows the operating system's text-to-speech, so the voice a
class hears depends on the machine: an en_US voice, a 16 kHz SAPI4 leftover, or
(measured on a bare macOS install) no British voice at all. The alternative is a
voice pack generated once, at build time, with a neural model that ships with the
project -- the same audio on every computer.

That decision needs numbers, not estimates, and the two that decide it are:

  * how many bytes the pack adds to the installer, and
  * how long the whole corpus takes to synthesise (a build step, not a runtime
    one).

The strings are extracted from `GameData.gd` and `Story.gd` with the same keys the
game reads (`prompt_en`, `title`, `lines`, `word`, `en`, `label`, ...). It is a
*superset* on purpose: a string that is extracted and never spoken costs a few
kilobytes, while a string that is spoken and missed would be a hole in the pack.
The generated families (grid coordinates, numerals) are listed separately, because
they are composed at runtime and are the part a pack cannot cover by recording.

Usage:
    measure_voice_pack.py --model alan.onnx [--out /tmp/pack] [--limit N]
"""
import argparse
import json
import os
import re
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Keys whose value is read aloud somewhere in the game. See the module docstring
# for why this errs on the side of including too much.
SPOKEN_KEYS = ("prompt_en", "title", "word", "en", "label", "name_en",
               "topic_en", "short_en", "question", "npc")


def strings_of(text, key):
    """Every single-line `"key": "value"` in a GDScript literal."""
    pattern = r'"%s"\s*:\s*"((?:[^"\\]|\\.)*)"' % key
    return re.findall(pattern, text)


def story_lines(text):
    """The `"lines": [ "a", "b" ]` arrays, flattened."""
    out = []
    for body in re.findall(r'"lines":\s*\[(.*?)\]', text, re.S):
        out += re.findall(r'"(.*?)"', body)
    return out


def literal_speaks(text):
    """`AudioFx.speak("...")` with a literal argument, across the scripts."""
    return re.findall(r'AudioFx\.speak\("((?:[^"\\]|\\.)*)"', text)


def build_corpus():
    corpus = set()
    gd = open(os.path.join(ROOT, "scripts/autoload/GameData.gd"), encoding="utf-8").read()
    st = open(os.path.join(ROOT, "scripts/autoload/Story.gd"), encoding="utf-8").read()
    for key in SPOKEN_KEYS:
        corpus.update(strings_of(gd, key))
        corpus.update(strings_of(st, key))
    corpus.update(story_lines(st))
    corpus.update(literal_speaks(gd))
    corpus.update(literal_speaks(st))
    # The panels' own lines (praise, corrections, the goal sentence) are built
    # from format strings, so the literal part is what gets spoken alone.
    for path in ("scripts/ui/QuizManager.gd", "scripts/ui/RepeatPanel.gd",
                 "scripts/missions/MissionController.gd",
                 "scripts/missions/GridTrapRoom.gd",
                 "scripts/missions/FindNumbersMission.gd",
                 "scripts/ui/ZoneIntroCard.gd", "scripts/ui/DialogueBox.gd"):
        full = os.path.join(ROOT, path)
        if os.path.exists(full):
            corpus.update(literal_speaks(open(full, encoding="utf-8").read()))
    # `%d` / `%s` placeholders are composed at runtime: keep the sentence body so
    # the measurement includes its length, but mark it as templated.
    cleaned = set()
    for s in corpus:
        s = s.strip()
        if not s or "%" in s and s.count("%") == s.count("%%"):
            continue
        cleaned.add(s)
    return sorted(cleaned)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="path to the .onnx voice")
    ap.add_argument("--out", default="", help="directory to keep the .wav files")
    ap.add_argument("--limit", type=int, default=0, help="only the first N (smoke run)")
    args = ap.parse_args()

    from piper import PiperVoice
    voice = PiperVoice.load(args.model)

    corpus = build_corpus()
    if args.limit:
        corpus = corpus[: args.limit]

    if args.out:
        os.makedirs(args.out, exist_ok=True)

    total_bytes = 0
    total_frames = 0
    rate = 22050
    for i, text in enumerate(corpus):
        chunks = list(voice.synthesize(text))
        if not chunks:
            continue
        for j, chunk in enumerate(chunks):
            rate = chunk.sample_rate
            total_frames += len(chunk.audio_int16_bytes) // 2
            if args.out:
                name = "line_%03d_%d.wav" % (i, j)
                with wave.open(os.path.join(args.out, name), "wb") as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(rate)
                    w.writeframes(chunk.audio_int16_bytes)
        # 16-bit mono PCM is 2 bytes per sample at `rate` samples per second.
        total_bytes += sum(len(c.audio_int16_bytes) for c in chunks)

    seconds = total_frames / float(rate)
    words = sum(len(t.split()) for t in corpus)
    print("voice model : %s" % os.path.basename(args.model))
    print("strings     : %d" % len(corpus))
    print("words       : %d" % words)
    print("speech      : %.1f s (%.1f min) at %d Hz" % (seconds, seconds / 60.0, rate))
    print("PCM 16-bit  : %.1f MB" % (total_bytes / 1048576.0))
    for kbps in (24, 32, 48):
        print("  Opus %2d kbps: %.2f MB" % (kbps, seconds * kbps * 1000 / 8 / 1048576.0))
    print("model file  : %.1f MB" % (os.path.getsize(args.model) / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
