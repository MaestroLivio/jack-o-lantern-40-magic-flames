#!/usr/bin/env python3
"""Generates the recorded voice pack the game ships with.

WHY this exists
---------------
`AudioFx.speak()` can borrow the operating system's text-to-speech, and on the
machine it was written on that sounds fine. On a school computer it does not:
the first `en` voice may be `en_US`, may be a 16 kHz SAPI4 leftover, or may not
exist at all -- a bare macOS install with no British voice falls back to Italian
reading English, which is worse for a child than silence. The voice is the
*lesson*, so it cannot be whatever the machine happens to have.

The alternative is to synthesise every spoken line once, here, with a neural
voice, and ship the audio. Measured on this project: the corpus is 880 sentences,
~32 minutes of speech, 13 MB of Ogg, and it takes about four minutes of CPU to
generate. That adds 13 MB to the installer instead of the 60-113 MB that shipping
the Piper model itself would cost, needs no binary on the target machine, and
cannot be broken by Gatekeeper or an antivirus.

Two consequences that shape the code:

  * The pack is indexed by the *text*, not by a made-up key. `AudioFx.speak()`
    is called from forty places with sentences assembled at runtime
    ("Find %s first!" % word, "A magic flame! %d"), so a key per string would
    mean touching every one of those places and getting each of them right. A
    lookup on the normalised sentence covers them all, including the ones a
    future edit adds without telling anybody.
  * Anything not in the pack falls through to the system voice. That is the
    "hybrid" behaviour: the fixed corpus is identical on every computer, and a
    sentence somebody just wrote still gets read out instead of going silent.

Encoding
--------
Ogg Vorbis, not WAV: the 32 minutes of PCM would be ~85 MB and becomes 13 MB, and
the project already ships Vorbis for the music (see `tools/make_music.py`), so the
Godot import path is the one the game already trusts.

Usage
-----
    python3 -m venv /tmp/pipenv && /tmp/pipenv/bin/pip install piper-tts
    /tmp/pipenv/bin/python tools/make_voice_pack.py --en cori.onnx --it serena.onnx

    # a single sentence, to audition a voice before committing to it
    /tmp/pipenv/bin/python tools/make_voice_pack.py --en cori.onnx --sample "Hello!"

The models are NOT in the repository: they are 113 MB each and their licence is
documented in `tools/VOICE_MODELS.md`. `assets/voice/` holds only the result.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "voice")

# Ogg Vorbis quality, on libvorbis' -1..10 scale. 3 is ~32 kbps mono at 22 kHz,
# which is transparent for a single speaking voice and keeps the whole pack near
# 2 MB. Raising it to 6 doubles the size for no audible gain on speech.
VORBIS_QUALITY = 3

# The filename is a hash of the normalised text. Kept short (12 hex chars) so the
# paths stay readable, and case-sensitive so a rebuild on a case-insensitive
# filesystem cannot collide two different sentences.
HASH_LEN = 12


def normalize(text):
    """The form used both as the lookup key and as the hash input.

    Mirrors `AudioFx.normalize_speech()`: whitespace collapsed, trimmed, and
    curly quotes folded onto straight ones, because the story text uses `"` and
    `'` and a different editor may produce `"` for the same sentence. A key that
    differs by one apostrophe would silently fall back to the system voice.
    """
    text = str(text)
    for a, b in (("\u2019", "'"), ("\u2018", "'"), ("\u201c", '"'), ("\u201d", '"'),
                 ("\u2014", "-"), ("\u2013", "-"), ("\u00a0", " ")):
        text = text.replace(a, b)
    text = " ".join(text.split())
    return text.strip()


def clip_name(text, lang):
    """Filename for one clip: a hash of language + normalised text.

    The language is part of the hash on purpose. A few strings exist in both
    languages ("OK", a number said the same way, a name), and hashing the text
    alone would give those two sentences one file — whichever was generated last
    would win, and the other language would be spoken in the wrong voice.
    """
    import hashlib
    key = "%s|%s" % (lang, normalize(text))
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:HASH_LEN]


def collect_corpus(godot):
    """Asks the game what it can say, through `tools/collect_speech.gd`."""
    out = subprocess.run(
        [godot, "--headless", "--path", ROOT, "--script", "tools/collect_speech.gd"],
        capture_output=True, text=True)
    rows = []
    for line in out.stdout.splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    if not rows:
        sys.exit("make_voice_pack: collect_speech.gd produced nothing.\n"
                 "stderr:\n" + out.stderr[-2000:])
    return rows


def synthesize(voice, text, path, length_scale):
    """One clip. Piper writes a WAV to `path`.

    `length_scale` lives on `SynthesisConfig` in piper-tts 1.8 (it used to be a
    keyword on `synthesize()` itself). Passing it the old way is a `TypeError`
    that only shows up when the first clip is generated, so it is built here.
    """
    from piper import SynthesisConfig
    config = SynthesisConfig(length_scale=length_scale)
    chunks = list(voice.synthesize(text, syn_config=config))
    if not chunks:
        return False
    rate = chunks[0].sample_rate
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        for c in chunks:
            w.writeframes(c.audio_int16_bytes)
    return True


def encode(wav_path, ogg_path):
    """WAV -> Ogg Vorbis. `oggenc` is the encoder the music build already needs."""
    result = subprocess.run(
        ["oggenc", "-q", str(VORBIS_QUALITY), "-o", ogg_path, wav_path],
        capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("make_voice_pack: oggenc failed: " + result.stderr[-800:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--en", required=True, help="path to the English .onnx voice")
    ap.add_argument("--it", default="", help="path to the Italian .onnx voice")
    ap.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    ap.add_argument("--length-scale", type=float, default=1.12,
                    help="1.0 is the voice's own pace; >1 is slower")
    ap.add_argument("--sample", default="", help="say this one sentence and stop")
    ap.add_argument("--dry-run", action="store_true",
                    help="list what would be generated, without synthesising")
    ap.add_argument("--force", action="store_true",
                    help="rebuild clips that are already on disk")
    ap.add_argument("--keep-orphans", action="store_true",
                    help="do not delete clips the new manifest does not name")
    args = ap.parse_args()

    if not shutil.which("oggenc"):
        sys.exit("make_voice_pack: oggenc missing. Run: brew install vorbis-tools")

    from piper import PiperVoice
    en_voice = PiperVoice.load(args.en)
    it_voice = PiperVoice.load(args.it) if args.it else None

    if args.sample:
        # An audition deliberately does NOT write into `assets/voice/`: a stray
        # `sample_*.ogg` there is not referenced by the manifest, would be
        # exported into the build for nothing, and -- worse -- makes the folder
        # look like a legitimately generated pack while `voice_pack.json` is
        # missing. Write to the temp dir and say where it went.
        wav = os.path.join(tempfile.gettempdir(), "sample.wav")
        dst = os.path.join(tempfile.gettempdir(), "sample_%s.ogg" % clip_name(args.sample, "en"))
        synthesize(en_voice, args.sample, wav, args.length_scale)
        encode(wav, dst)
        print("wrote", dst)
        return 0

    rows = collect_corpus(args.godot)
    os.makedirs(OUT_DIR, exist_ok=True)

    manifest = {}
    generated = 0
    skipped = 0
    missing_voice = 0
    total_seconds = 0.0

    for row in rows:
        lang = row.get("lang", "en")
        text = normalize(row.get("text", ""))
        if not text:
            continue
        name = clip_name(text, lang)
        if lang == "it" and it_voice is None:
            missing_voice += 1
            continue
        voice = it_voice if lang == "it" else en_voice
        dst = os.path.join(OUT_DIR, "%s.ogg" % name)
        if os.path.exists(dst) and not args.force:
            skipped += 1
        else:
            if args.dry_run:
                print("would generate", lang, repr(text[:70]))
                generated += 1
                continue
            wav = os.path.join(tempfile.gettempdir(), "vp_%s.wav" % name)
            if not synthesize(voice, text, wav, args.length_scale):
                continue
            with wave.open(wav) as w:
                total_seconds += w.getnframes() / float(w.getframerate())
            encode(wav, dst)
            os.unlink(wav)
            generated += 1
        manifest["%s|%s" % (lang, text)] = name
        if generated % 100 == 0 and generated > 0:
            print("  ...%d clips" % generated)

    if args.dry_run:
        print("dry run: %d would be generated, %d already present" % (generated, skipped))
        return 0

    # The manifest is keyed by "lang|sentence", not by filename, so the game can
    # look a line up directly instead of hashing it in a second language and
    # hoping the two implementations agree. It is also readable: a teacher
    # opening the file sees the sentences, and a missing line is diagnosable.
    index_path = os.path.join(OUT_DIR, "voice_pack.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "quality": VORBIS_QUALITY,
                   "clips": manifest}, f, ensure_ascii=False, indent=0,
                  sort_keys=True)

    # Delete clips the manifest no longer names.
    #
    # A sentence that leaves the data leaves its .ogg behind, and nothing would
    # ever remove it: the builder only writes, and the game only reads what the
    # manifest points at. They accumulate silently -- every reworded mission, every
    # dropped hint -- and they are exported into the installer because the export
    # filter takes the whole `assets/voice/` folder. Pruning here is the only place
    # that knows which files are still wanted. `--keep-orphans` exists because a
    # half-generated pack (an interrupted run, a voice missing) would otherwise
    # delete exactly the clips it failed to replace.
    on_disk = set(n for n in os.listdir(OUT_DIR) if n.endswith(".ogg"))
    wanted = set(v + ".ogg" for v in manifest.values())
    orphans = sorted(on_disk - wanted)
    if orphans and not args.keep_orphans:
        for name in orphans:
            os.unlink(os.path.join(OUT_DIR, name))
        print("")
        print("pruned        : %d clip(s) the manifest no longer names" % len(orphans))
    elif orphans:
        print("")
        print("orphans kept  : %d (--keep-orphans)" % len(orphans))

    sizes = sum(os.path.getsize(os.path.join(OUT_DIR, n + ".ogg"))
                for n in manifest.values())
    print("")
    print("clips written : %d" % generated)
    print("clips reused  : %d" % skipped)
    if missing_voice:
        print("skipped (no Italian voice): %d" % missing_voice)
    print("audio length  : %.1f s" % total_seconds)
    print("pack size     : %.2f MB" % (sizes / 1048576.0))
    print("manifest      : %s" % index_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
