#!/usr/bin/env python3
"""Add a timestamp to every spoken line and report collisions.

Reads the output of tools/speech_timeline.gd on stdin, so the clock belongs to
whoever is reading the pipe rather than to the engine (a `--headless` Godot run
has no stable frame rate, and its own timers drift against wall time).

    godot --headless --path . --script tools/speech_timeline.gd 2>&1 \
        | python3 -u tools/stamp_speech.py

Reports, with exit code 1 if either happens:

  * OVERLAP  -- two lines closer together than the first one takes to say. The
    game uses `interrupt = true`, so the second cuts the first off mid-word.
  * REPEAT   -- the same sentence spoken twice in one run.

The spoken length is estimated at SPEAK_WPM. Until 1.0.5 this was 135 wpm: the
rate `AudioFx.speak()` defaults to is 0.9 of the system voice's normal speed,
and 150 wpm is a fair average for the voices Windows and macOS ship. Since the
voice pack is recorded with `--length-scale 2.24` (half speed), every *shipped*
sentence is spoken at half that rate again, so the old estimate would report a
collision that does not exist. 67.5 wpm is the same measurement halved.
"""
import re
import sys
import time

SPEAK_WPM = 67.5
# Words are cheaper to say than they look: leave a beat after the sentence so a
# line that lands exactly on the estimated end is not reported.
SLACK_S = 0.15
SPEECH_RE = re.compile(r"\[speech/(\w+)\]\s*(.*)")


def main() -> int:
    started = time.monotonic()
    last_at = None
    last_text = ""
    last_len = 0.0
    seen = {}
    lines = []
    overlaps = []
    repeats = []

    for raw in sys.stdin:
        match = SPEECH_RE.search(raw)
        if not match:
            continue
        now = time.monotonic() - started
        text = match.group(2).strip()
        if not text:
            continue
        lines.append((now, text))

        if last_at is not None:
            gap = now - last_at
            remaining = last_len - gap
            if remaining > SLACK_S:
                overlaps.append((now, gap, remaining, last_text, text))
        if text in seen:
            repeats.append((now, text, seen[text]))
        seen.setdefault(text, now)

        words = max(len(text.split()), 1)
        last_len = (words / SPEAK_WPM) * 60.0
        last_at = now
        last_text = text

    print("\n--- speech timeline ---")
    for at, text in lines:
        print(f"{at:6.2f} s  {text}")

    print("\n--- verdict ---")
    for at, gap, remaining, prev, cur in overlaps:
        print(f"OVERLAP at {at:.2f} s: '{prev}' still had {remaining:.1f} s to run "
              f"when '{cur}' started (gap {gap:.2f} s)")
    for at, text, first in repeats:
        print(f"REPEAT  at {at:.2f} s: '{text}' (already said at {first:.2f} s)")

    if not overlaps and not repeats:
        print(f"{len(lines)} line(s), no collisions")
        return 0
    print(f"{len(lines)} line(s), {len(overlaps)} overlap(s), {len(repeats)} repeat(s)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
