# The voices behind `assets/voice/` — how the pack is made and why

The game does not ship a speech synthesiser. It ships **audio**: every sentence it
can say was recorded once, on a build machine, and lives in `assets/voice/` as an
Ogg Vorbis clip. `AudioFx.speak()` looks the sentence up in
`assets/voice/voice_pack.json` and plays the clip; only a sentence that is *not*
in the pack falls back to the operating system's text-to-speech.

This file documents the two models, their licences, and how to regenerate the
pack. The models themselves are **not in the repository**: they are 113 MB each,
and the result is 3 MB.

## The two voices

| Language | Piper model | Quality | Licence | Trained on |
|---|---|---|---|---|
| English (British) | `en_GB-cori-high` | high | model: public domain; dataset: LibriVox (public domain) | LibriVox audiobooks |
| Italian | `it_IT-serena-high` | high | model: see repo; dataset: CC-BY-4.0 | a CC-BY-4.0 Italian speech corpus |

`cori` was chosen over the alternatives for one reason that matters for a
children's English lesson: it is a British voice with a neutral, unhurried
delivery, and it matches the `en-GB` target the story text is written in. The
first version of this game borrowed whatever the machine had, and on a school
Mac that turned out to be an `en_US` voice or, worse, no English voice at all —
Italian reading English. That is the failure this whole mechanism exists to
prevent.

## Download

Both models come from the `rhasspy/piper-voices` dataset on Hugging Face (MIT).
Each voice needs the `.onnx` and its `.onnx.json` sidecar, and the sidecar must
keep the same basename as the model.

```bash
mkdir -p /tmp/piperprobe && cd /tmp/piperprobe

# English (British), high quality
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/cori/high/en_GB-cori-high.onnx
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/cori/high/en_GB-cori-high.onnx.json

# Italian, high quality
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/it/it_IT/serena/high/it_IT-serena-high.onnx
curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/it/it_IT/serena/high/it_IT-serena-high.onnx.json
```

The pack builder takes any `.onnx` path, so a different voice can be auditioned
without renaming anything:

```bash
python tools/make_voice_pack.py --en cori.onnx --sample "Hello, Jack! Let's find the pumpkins."
```

The sample is written to the system temp directory on purpose. A stray
`sample_*.ogg` inside `assets/voice/` is a file the manifest does not reference:
it would be exported into the build for nothing, and it makes the folder look
like a finished pack while `voice_pack.json` is still missing.

## Requirements

* **`piper-tts` 1.8** (Python). Run it from a throwaway virtualenv, never from
  the project:

  ```bash
  python3 -m venv /tmp/piperprobe/venv
  /tmp/piperprobe/venv/bin/pip install piper-tts
  ```

  In 1.8 `length_scale` is a field on `SynthesisConfig`, not a keyword argument
  of `synthesize()`. The old form raises `TypeError` only when the first clip is
  generated, i.e. after the model has already loaded — see `synthesize()` in
  `tools/make_voice_pack.py`.

* **`oggenc`** from `vorbis-tools` (`brew install vorbis-tools`). The music build
  already needs it, so this adds no new dependency.

* **Godot**, because `make_voice_pack.py` asks the game for its sentences:

  ```bash
  godot --headless --path . --script tools/collect_speech.gd
  ```

  That walk is what makes the pack complete. A regex over the `.gd` files
  underestimates the corpus badly — it cannot see `"%s. Well done!" % label`, it
  counts commented-out text, and it misses whole generated families such as
  `"Go to C4."` for all one hundred cells or `"A magic flame! %d"` for 1..40.

## Regenerating

```bash
cd "/path/to/Halloween game"
/tmp/piperprobe/venv/bin/python tools/make_voice_pack.py \
    --en /tmp/piperprobe/en_GB-cori-high.onnx \
    --it /tmp/piperprobe/it_IT-serena-high.onnx \
    --force
godot --headless --path . --import        # so ResourceLoader.exists() finds the clips
godot --headless --path . --script tools/voice_pack_check.gd
```

`--force` rebuilds clips that already exist. Without it the builder skips a file
it finds on disk, which is faster but wrong after a change to `--length-scale`,
to a voice, or to the normaliser: the old byte stays and the manifest points at
it. `voice_pack_check.gd` is the guard — it replays the corpus through
`AudioFx.speak()` and prints every sentence that fell through to the system
voice. It must report **0 misses**.

Measured on this machine: **880 sentences** (714 English, 166 Italian), ~32 minutes
of audio, about 4 minutes of CPU, **13 MB** of Ogg at `-q 3`. Regenerating all of it
is cheap enough to be part of a release build, which is why the audio is committed
and the models are not.

The builder also **prunes**. A sentence that leaves the data leaves its `.ogg` behind,
and nothing else would ever remove it — the game only reads what the manifest points
at, and the export takes the whole folder. Every leftover is megabytes of installer
for audio no code can play. `--keep-orphans` skips the pruning, which is what to pass
if a run was interrupted or a voice was missing: otherwise it would delete exactly the
clips it failed to replace.

An earlier build of this pack had 1017 entries, because the corpus walk synthesised
`"Go to C4."` for all hundred cells and `"Magic Flame! %d / 40"` for all forty flames.
Both were guesses about templates nothing builds: the real `Go to …` prompts are
literals in `GameData`, and the flame counter is a *toast* label that
`Hud.show_feedback()` writes and nothing speaks. Pruning took the pack from 14.7 MB to
13.0 MB. That is why `voice_pack_check.gd` reports a corpus *and* a manifest count and
fails only on misses — a pack bigger than the corpus is legal (it keeps clips for
sentences a mission used to say), but a pack padded with unspoken sentences hides a
real miss in its own inventory.

## Why not ship Piper itself

Considered and rejected:

* 60–113 MB of model in the installer, against 3 MB of audio.
* 0.78–0.96 s to load the model at startup, and ~0.96 s per sentence through the
  CLI — a child waits a second for every instruction.
* The current `piper1-gpl` repository is **GPL-3.0**, unlike the MIT `rhasspy`
  version this pack was generated with.
* The official macOS release binary is broken: the tarball has no
  `libespeak-ng.1.dylib` / `libpiper_phonemize.1.dylib` / `libonnxruntime`, so it
  dies on `dyld`. Shipping it would mean shipping a workaround for that too.

Recording the corpus once has none of those problems and makes the voice
identical on every computer the game is installed on, which was the actual
complaint.
