#!/usr/bin/env python3
"""Synthesises the background music for *Jack o' Lantern - The 40 Magic Flames*.

Run with the helper virtualenv (numpy + scipy, kept out of the project):

    python3 -m venv /tmp/musenv && /tmp/musenv/bin/pip install numpy scipy
    /tmp/musenv/bin/python tools/make_music.py                # every track
    /tmp/musenv/bin/python tools/make_music.py --only title   # just one

Writes `assets/music/<id>.ogg` plus a peak/RMS report, so a rebuild can be
checked without listening to it.

Why a script instead of checked-in recordings
---------------------------------------------
The game has no composer and no budget: every sound in it is generated from
code so it can be regenerated, re-tuned and re-timed by whoever maintains the
project. A recording would also carry a licence and a fixed length. Everything
here is deterministic (each track has its own RNG seed), so the same numbers
produce the same bytes.

How a loop is made seamless
---------------------------
Each track is rendered slightly *longer* than its musical length, so the
reverb tail and the last ringing bells have somewhere to go. The overflow is
then folded back onto the start (`fold`). The result loops without the seam
that a plain "cut at the bar line" produces: the tail of bar 16 is already
sitting under bar 1.

Continuous beds (the low hum in the laboratory) are the one case folding
cannot fix, because a sine whose phase jumps clicks. Those are generated with
a frequency snapped to a whole number of cycles per loop, so the phase at the
loop point is exactly the phase at the start.
"""

from __future__ import annotations

import argparse
import math
import os
import subprocess
import sys
import wave as wavfile

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "music")
TMP_DIR = os.path.join(ROOT, "build", "music")

# Names of the notes, so a chord can be written as ("A", 3) instead of 57.
_PITCH = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
          "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def m(name: str, octave: int) -> int:
    """MIDI number of a written note, e.g. m("A", 4) -> 69."""
    return 12 * (octave + 1) + _PITCH[name]


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


# ---------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------

def _sos(kind: str, fc: float, order: int = 2):
    nyq = SR * 0.5
    fc = min(max(fc, 10.0), nyq * 0.99)
    return butter(order, fc / nyq, btype=kind, output="sos")


def lowpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return sosfilt(_sos("low", fc, order), x)


def highpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return sosfilt(_sos("high", fc, order), x)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    nyq = SR * 0.5
    sos = butter(order, [max(lo, 10.0) / nyq, min(hi, nyq * 0.99) / nyq],
                 btype="band", output="sos")
    return sosfilt(sos, x)


# ---------------------------------------------------------------------------
# Band-limited oscillators
# ---------------------------------------------------------------------------

_TABLE_SIZE = 4096
_TABLE_CACHE: dict[tuple[str, int], np.ndarray] = {}


def _table(kind: str, max_harm: int) -> np.ndarray:
    """One period of `kind`, band-limited to `max_harm` harmonics.

    Generating a wavetable per (waveform, harmonic count) and reading it with
    linear interpolation is ~50x faster than summing sines for every note, and
    it can never alias: the harmonic count is chosen from the note's own
    frequency so the top partial stays under Nyquist.
    """
    key = (kind, max_harm)
    cached = _TABLE_CACHE.get(key)
    if cached is not None:
        return cached
    ph = np.arange(_TABLE_SIZE) / _TABLE_SIZE
    out = np.zeros(_TABLE_SIZE)
    for h in range(1, max_harm + 1):
        if kind == "saw":
            amp = 1.0 / h
        elif kind == "square":
            amp = (1.0 / h) if h % 2 == 1 else 0.0
        elif kind == "tri":
            amp = (1.0 / (h * h)) * (1.0 if (h // 2) % 2 == 0 else -1.0) if h % 2 == 1 else 0.0
        elif kind == "organ":
            amp = {1: 1.0, 2: 0.55, 3: 0.3, 4: 0.22, 6: 0.1}.get(h, 0.0)
        else:
            amp = 0.0
        if amp:
            out += amp * np.sin(2 * np.pi * h * ph)
    peak = np.max(np.abs(out)) or 1.0
    out /= peak
    _TABLE_CACHE[key] = out
    return out


def wave(freq, n: int, kind: str = "saw", phase: float = 0.0,
         table_size: int = _TABLE_SIZE) -> np.ndarray:
    """`n` samples of `kind`, read from a band-limited wavetable.

    `freq` may be an array (a wobble, a slide, a vibrato): the phase is then
    the running integral of the instantaneous frequency, which is what makes
    a pitch sweep sound continuous instead of stepped.
    """
    if isinstance(freq, np.ndarray) or isinstance(freq, list):
        f = np.asarray(freq, dtype=np.float64)
        max_harm = int((SR * 0.45) / max(float(np.max(f)), 1.0))
        max_harm = max(1, min(max_harm, 48))
        tab = _table(kind, max_harm)
        phase_acc = phase * table_size + np.cumsum(f / SR * table_size)
        idx = phase_acc % table_size
        grid = np.arange(table_size + 1, dtype=np.float64)
        return np.interp(idx, grid, np.append(tab, tab[0]))

    max_harm = int((SR * 0.45) / max(freq, 1.0))
    max_harm = max(1, min(max_harm, 48))
    tab = _table(kind, max_harm)
    inc = freq / SR * table_size
    idx = (phase * table_size + np.arange(n, dtype=np.float64) * inc) % table_size
    grid = np.arange(table_size + 1, dtype=np.float64)
    return np.interp(idx, grid, np.append(tab, tab[0]))


def sine(freq: float, n: int, phase: float = 0.0) -> np.ndarray:
    return np.sin(2 * np.pi * freq * np.arange(n) / SR + phase)


def env(n: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    """ADSR envelope in seconds. Never returns a value above 1.0."""
    t = np.arange(n) / SR
    total = n / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    d = np.clip((t - attack) / max(decay, 1e-4), 0.0, 1.0)
    body = 1.0 + (sustain - 1.0) * d
    rel_start = max(total - release, attack + decay)
    r = np.clip((t - rel_start) / max(release, 1e-4), 0.0, 1.0)
    return a * body * (1.0 - r) ** 1.4


def expdec(n: int, rate: float) -> np.ndarray:
    return np.exp(-np.arange(n) / SR * rate)


# ---------------------------------------------------------------------------
# Instruments
#
# Each one takes (frequency, gate_seconds, velocity) and returns a mono
# signal. They may ring past `gate`: that is what makes the mix sound like
# instruments in a room rather than samples cut to length.
# ---------------------------------------------------------------------------

def inst_celesta(f: float, gate: float, vel: float) -> np.ndarray:
    """Music-box bell: the game's 'voice' for melodies."""
    n = int(min(gate + 1.1, 1.6) * SR)
    t = np.arange(n) / SR
    parts = ((1.0, 1.0, 0.75), (2.0, 0.34, 0.5), (3.01, 0.13, 0.34), (4.21, 0.06, 0.22))
    y = np.zeros(n)
    for mult, amp, decay in parts:
        if f * mult > SR * 0.45:
            continue
        y += amp * np.sin(2 * np.pi * f * mult * t) * np.exp(-t / decay)
    y *= np.clip(t / 0.004, 0.0, 1.0)
    return y * vel * 0.42


def inst_marimba(f: float, gate: float, vel: float) -> np.ndarray:
    """Warm wooden mallet, used for the march-like zones."""
    n = int(min(gate + 0.55, 0.9) * SR)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.42)
         + 0.22 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / 0.09)
         + 0.08 * np.sin(2 * np.pi * f * 9.7 * t) * np.exp(-t / 0.04))
    y *= np.clip(t / 0.003, 0.0, 1.0)
    mallet = lowpass(np.random.default_rng(int(f) % 99991).standard_normal(n), 5000) * np.exp(-t / 0.01) * 0.05
    return (y + mallet) * vel * 0.4


def inst_pizz(f: float, gate: float, vel: float) -> np.ndarray:
    """Plucked string (pizzicato): short, bouncy, very 'cartoon'."""
    n = int(min(gate + 0.6, 1.0) * SR)
    t = np.arange(n) / SR
    body = wave(f, n, "saw")
    body = lowpass(body, 1800 + 900 * vel)
    y = body * np.exp(-t / 0.22) * np.clip(t / 0.004, 0.0, 1.0)
    # A quiet octave above gives the pluck its "ping" without a second note.
    y += 0.18 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.12)
    return y * vel * 0.4


def inst_bass(f: float, gate: float, vel: float) -> np.ndarray:
    """Round upright bass: sine fundamental with a little grit."""
    n = int((gate + 0.25) * SR)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t)
         + 0.34 * np.sin(2 * np.pi * f * 2 * t)
         + 0.12 * np.sin(2 * np.pi * f * 3 * t))
    y = np.tanh(y * 1.25) * 0.8
    e = env(n, 0.012, 0.12, 0.72, min(0.16, gate))
    return y * e * vel * 0.5


def inst_pad(f: float, gate: float, vel: float) -> np.ndarray:
    """Soft string pad, three slightly detuned voices: the 'warm room'."""
    n = int((gate + 0.6) * SR)
    y = np.zeros(n)
    for cents in (-7.0, 0.0, 6.0):
        y += wave(f * 2 ** (cents / 1200.0), n, "saw", phase=0.13 * (cents + 7))
    y = lowpass(y / 3.0, 1300)
    return y * env(n, 0.35, 0.3, 0.85, 0.5) * vel * 0.3


def inst_harp(f: float, gate: float, vel: float) -> np.ndarray:
    """Harpsichord-ish: bright pluck, short decay. The castle's furniture."""
    n = int(min(gate + 0.7, 1.0) * SR)
    t = np.arange(n) / SR
    y = wave(f, n, "saw") * 0.6 + wave(f, n, "square") * 0.25
    y = bandpass(y, 200, 5200)
    return y * np.exp(-t / 0.30) * np.clip(t / 0.003, 0.0, 1.0) * vel * 0.32


def inst_brass(f: float, gate: float, vel: float) -> np.ndarray:
    """Friendly brass stab for the party: bright but never harsh."""
    n = int((gate + 0.3) * SR)
    t = np.arange(n) / SR
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    y = np.zeros(n)
    for mult, amp in ((1, 1.0), (2, 0.6), (3, 0.38), (4, 0.2), (5, 0.1)):
        if f * mult < SR * 0.45:
            y += amp * np.sin(2 * np.pi * f * mult * vib * t)
    y = lowpass(y, 3400)
    e = env(n, 0.05, 0.14, 0.7, min(0.2, gate * 0.6))
    return np.tanh(y * e * 0.55) * vel * 0.45


def inst_organ(f: float, gate: float, vel: float) -> np.ndarray:
    """Comic organ (drawbar): the 'spooky but silly' colour."""
    n = int((gate + 0.35) * SR)
    y = wave(f, n, "organ")
    y = lowpass(y, 2600)
    return y * env(n, 0.02, 0.18, 0.8, min(0.14, gate)) * vel * 0.33


def inst_whistle(f: float, gate: float, vel: float) -> np.ndarray:
    """Slide whistle: the party's cartoon exclamation mark."""
    n = int((gate + 0.3) * SR)
    t = np.arange(n) / SR
    slide = 1.0 + 0.06 * np.clip((t - gate * 0.5) / 0.2, 0.0, 1.0)
    y = np.sin(2 * np.pi * f * slide * t)
    breath = highpass(np.random.default_rng(7).standard_normal(n), 2500) * 0.05
    e = env(n, 0.05, 0.1, 0.8, min(0.18, gate))
    return (y + breath) * e * vel * 0.22


# --- Percussion ------------------------------------------------------------

_RNG = np.random.default_rng(20251031)


def drum_kick(vel: float = 1.0) -> np.ndarray:
    n = int(0.30 * SR)
    t = np.arange(n) / SR
    f = 118.0 * np.exp(-t * 24.0) + 44.0
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.0)
    click = _RNG.standard_normal(n) * np.exp(-t * 120.0) * 0.18
    return np.tanh((body + click) * 1.3) * vel * 0.55


def drum_snare(vel: float = 1.0) -> np.ndarray:
    n = int(0.20 * SR)
    t = np.arange(n) / SR
    noise = bandpass(_RNG.standard_normal(n), 900, 7000) * np.exp(-t * 26.0) * 0.5
    tone = np.sin(2 * np.pi * 195 * t) * np.exp(-t * 34.0) * 0.32
    return (noise + tone) * vel * 0.34


def drum_hat(vel: float = 1.0) -> np.ndarray:
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    y = highpass(_RNG.standard_normal(n), 7000) * np.exp(-t * 62.0)
    return y * vel * 0.16


def drum_shaker(vel: float = 1.0) -> np.ndarray:
    """Soft shaker: a gentle 'shh' that keeps the march moving."""
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    y = bandpass(_RNG.standard_normal(n), 3800, 9500)
    e = np.clip(t / 0.02, 0.0, 1.0) * np.exp(-t * 34.0)
    return y * e * vel * 0.12


def drum_tambourine(vel: float = 1.0) -> np.ndarray:
    n = int(0.24 * SR)
    t = np.arange(n) / SR
    jingle = highpass(_RNG.standard_normal(n), 5200) * np.exp(-t * 14.0)
    ring = (np.sin(2 * np.pi * 5230 * t) + 0.6 * np.sin(2 * np.pi * 7100 * t)) * np.exp(-t * 22.0)
    return (jingle * 0.35 + ring * 0.12) * vel * 0.3


def drum_wood(vel: float = 1.0) -> np.ndarray:
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * 1020 * t) * np.exp(-t * 62.0)
         + np.sin(2 * np.pi * 1610 * t) * np.exp(-t * 88.0) * 0.6)
    return y * vel * 0.26


def drum_triangle(vel: float = 1.0) -> np.ndarray:
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * 2637 * t) + 0.5 * np.sin(2 * np.pi * 3951 * t)) * np.exp(-t * 4.4)
    return y * vel * 0.09


def drum_frog(vel: float = 1.0) -> np.ndarray:
    """A cartoon 'ribbit': two short pitched croaks. Playful, never scary."""
    n = int(0.34 * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for start, f0, dur in ((0.0, 210.0, 0.10), (0.14, 165.0, 0.13)):
        i0 = int(start * SR)
        seg = np.arange(min(n - i0, int(dur * SR))) / SR
        wob = 1.0 + 0.10 * np.sin(2 * np.pi * 28 * seg)
        croak = wave(f0 * wob, len(seg), "square") * np.exp(-seg * 16.0)
        croak = lowpass(croak, 1200)
        y[i0:i0 + len(seg)] += croak
    return y * vel * 0.16


def drum_bubble(vel: float = 1.0) -> np.ndarray:
    """A single rising bubble for the witch's bog and the laboratory."""
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    f = 320.0 + 900.0 * (t / 0.16)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 26.0)
    return y * vel * 0.11


def cricket(rng: np.random.Generator, vel: float = 1.0) -> np.ndarray:
    """Three fast chirps: the sound of a warm autumn night."""
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    gate = (np.sin(2 * np.pi * 22.0 * t) > 0.55).astype(np.float64)
    y = np.sin(2 * np.pi * 4300 * t) * gate * np.exp(-t * 5.0)
    return lowpass(y, 7000) * vel * 0.05


def drip(rng: np.random.Generator, vel: float = 1.0) -> np.ndarray:
    """Water drop: a short glassy ping with a falling tail."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 1500.0 * np.exp(-t * 12.0) + 620.0
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9.0)
    return y * vel * 0.10


INSTRUMENTS = {
    "celesta": inst_celesta, "marimba": inst_marimba, "pizz": inst_pizz,
    "bass": inst_bass, "pad": inst_pad, "harp": inst_harp,
    "brass": inst_brass, "organ": inst_organ, "whistle": inst_whistle,
    "kick": lambda f, g, v: drum_kick(v), "snare": lambda f, g, v: drum_snare(v),
    "hat": lambda f, g, v: drum_hat(v), "shaker": lambda f, g, v: drum_shaker(v),
    "tamb": lambda f, g, v: drum_tambourine(v), "wood": lambda f, g, v: drum_wood(v),
    "triangle": lambda f, g, v: drum_triangle(v), "frog": lambda f, g, v: drum_frog(v),
}
# ---------------------------------------------------------------------------
# Score / sequencer
# ---------------------------------------------------------------------------

_PAN = {
    "celesta": 0.10, "marimba": -0.18, "pizz": 0.22, "bass": 0.0,
    "pad": 0.0, "harp": -0.20, "brass": 0.05, "organ": 0.16,
    "whistle": 0.30, "kick": 0.0, "snare": -0.06, "hat": 0.26,
    "shaker": -0.24, "tamb": 0.20, "wood": -0.30, "triangle": 0.34,
    "frog": -0.34, "bubble": 0.28,
}


class Score:
    """A loop in beats, rendered to seconds at the end.

    `swing` warps every off-beat eighth from 0.5 to 0.5 + swing * 0.167, i.e.
    straight (0.0) through a triplet shuffle (1.0). It is applied once, when a
    note is added, so the humanising never compounds.
    """

    def __init__(self, bpm: float, beats_per_bar: float, bars: int, swing: float = 0.0):
        self.bpm = bpm
        self.beats_per_bar = beats_per_bar
        self.bars = bars
        self.swing = swing
        self.events: list[tuple[str, int, float, float, float]] = []
        self.extra: list[tuple[np.ndarray, float, float]] = []  # (audio, start_s, pan)

    @property
    def beat_s(self) -> float:
        return 60.0 / self.bpm

    @property
    def bar_s(self) -> float:
        return self.beats_per_bar * self.beat_s

    @property
    def length_s(self) -> float:
        return self.bars * self.bar_s

    def _warp(self, beat: float) -> float:
        if self.swing <= 0.0:
            return beat
        whole = math.floor(beat)
        frac = beat - whole
        if abs(frac - 0.5) < 1e-6:
            return whole + 0.5 + self.swing * 0.1667
        return beat

    def add(self, inst: str, midi, beat: float, dur: float = 1.0, vel: float = 0.85) -> None:
        """Adds one note, or a chord when `midi` is a list."""
        notes = midi if isinstance(midi, (list, tuple)) else [midi]
        for i, n in enumerate(notes):
            # A strummed chord: each note a hair later than the one before.
            offset = i * 0.012 if len(notes) > 1 else 0.0
            self.events.append((inst, int(n), self._warp(beat) * self.beat_s + offset,
                                dur * self.beat_s, max(0.05, vel - i * 0.03)))

    def line(self, inst: str, spec, start_beat: float, vel: float = 0.85,
             gate: float = 0.95) -> None:
        """`spec` is [(beat_offset, "A4"|[...], dur), ...] relative to start."""
        for offset, note, dur in spec:
            self.add(inst, _pitch_of(note), start_beat + offset, dur * gate, vel)

    def arp(self, inst: str, chord, start_beat: float, count: int, step: float,
            dur: float = 1.0, vel: float = 0.6, shape: str = "updown", octave: int = 0) -> None:
        tones = sorted(int(n) + 12 * octave for n in chord)
        order: list[int] = []
        while len(order) < count:
            seq = tones + (tones[-2:0:-1] if shape == "updown" and len(tones) > 1 else [])
            order.extend(seq)
        for i in range(count):
            self.add(inst, order[i], start_beat + i * step, dur * 0.9, vel)

    def add_audio(self, audio: np.ndarray, at_beat: float, pan: float = 0.0) -> None:
        self.extra.append((audio, at_beat * self.beat_s, pan))


def _pitch_of(note) -> int | list[int]:
    if isinstance(note, (list, tuple)):
        return [_pitch_of(n) for n in note]
    return _note_midi(note)


def _note_midi(name: str) -> int:
    """'A4' -> 69, 'C#3' -> 49."""
    name = name.strip()
    if not name:
        return 0
    letter = name[0].upper()
    rest = name[1:]
    acc = 0
    if rest.startswith("#"):
        acc, rest = 1, rest[1:]
    elif rest.startswith("b"):
        acc, rest = -1, rest[1:]
    octave = int(rest) if rest else 4
    return 12 * (octave + 1) + _PITCH[letter] + acc


def chord(names: list[str]) -> list[int]:
    return [_note_midi(n) for n in names]


# ---------------------------------------------------------------------------
# Reverb
# ---------------------------------------------------------------------------

def make_ir(seconds: float, decay: float, brightness: float, seed: int,
            predelay: float = 0.012) -> np.ndarray:
    """Exponentially decaying, low-passed noise.

    Not a real room, but it is the cheapest way to get the sense of *a place*:
    the bog needs a longer, duller tail than the castle hall. Normalising by
    the energy of the impulse keeps the wet level comparable across tracks.
    """
    n = int(seconds * SR)
    rng = np.random.default_rng(seed)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / decay)
    # Duller tails lose their top end faster: that is what "distance" sounds like.
    ir = lowpass(ir, brightness)
    ir = highpass(ir, 180)
    # A few discrete early reflections make it read as a room, not as a wash.
    for at, gain in ((0.011, 0.5), (0.019, -0.34), (0.031, 0.26), (0.047, -0.18)):
        i = int(at * SR)
        if i < n:
            ir[i] += gain * np.max(np.abs(ir)) * 0.5
    pre = int(predelay * SR)
    ir = np.concatenate([np.zeros(pre), ir])
    return ir / (np.sqrt(np.sum(ir ** 2)) or 1.0)


def reverberate(x: np.ndarray, ir: np.ndarray, amount: float) -> np.ndarray:
    wet = fftconvolve(x, ir)[: len(x)]
    return x * (1.0 - amount * 0.45) + wet * amount


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def render(score: Score, wet: float = 0.30, tail: float = 2.6,
           seed: int = 1, drive: float = 1.0) -> np.ndarray:
    """Renders a Score into a seamless stereo loop.

    The buffer is `length + tail` long so bells and reverb can ring out, then
    the overflow is folded back onto the beginning. The loop therefore joins
    onto the reverb of its own ending instead of onto silence.
    """
    loop_n = int(round(score.length_s * SR))
    total_n = loop_n + int(tail * SR)
    left = np.zeros(total_n)
    right = np.zeros(total_n)
    rng = np.random.default_rng(seed * 977 + 13)

    for inst, midi, at_s, gate, vel in score.events:
        fn = INSTRUMENTS.get(inst)
        if fn is None or midi <= 0:
            continue
        # A small, deterministic timing and level jitter: a machine-perfect
        # grid is what makes generated music sound like a metronome.
        at = int(max(0.0, at_s + rng.normal(0.0, 0.004)) * SR)
        v = float(np.clip(vel * rng.normal(1.0, 0.045), 0.08, 1.25))
        sig = fn(hz(midi), gate, v)
        end = min(at + len(sig), total_n)
        if end <= at:
            continue
        sig = sig[: end - at]
        pan = _PAN.get(inst, 0.0)
        # Constant-power pan keeps the perceived loudness the same at any angle.
        ang = (pan + 1.0) * math.pi / 4.0
        left[at:end] += sig * math.cos(ang)
        right[at:end] += sig * math.sin(ang)

    for audio, at_s, pan in score.extra:
        at = int(max(0.0, at_s) * SR)
        end = min(at + len(audio), total_n)
        ang = (pan + 1.0) * math.pi / 4.0
        left[at:end] += audio[: end - at] * math.cos(ang)
        right[at:end] += audio[: end - at] * math.sin(ang)

    # Two decorrelated impulses: identical tails would collapse to mono.
    left = reverberate(left, make_ir(2.2, 0.62, 4200, seed * 3 + 1), wet)
    right = reverberate(right, make_ir(2.2, 0.66, 3700, seed * 3 + 2), wet)

    stereo = np.stack([left, right], axis=1)
    out = stereo[:loop_n].copy()
    over = stereo[loop_n:]
    if len(over):
        # Fold: what rang past the loop point belongs under the first bar.
        out[: len(over)] += over[: loop_n] if len(over) > loop_n else over

    # Mix glue: a wide, gentle shelf cut keeps the music behind the voice.
    out[:, 0] = highpass(out[:, 0], 32)
    out[:, 1] = highpass(out[:, 1], 32)
    out = np.tanh(out * drive * 1.05) * 0.92

    # Join smoothing. Folding the tail back makes the *reverb* continuous, but
    # it does not make the last sample and the first sample equal: on a dense
    # track (the party -- brass, drums and a tambourine still ringing) the loop
    # point can land on a step of a tenth of full scale, and the player would
    # click once per loop. The fix is to ease the last few milliseconds onto the
    # first sample with a quadratic (C1) ramp: the value and the slope both meet
    # the loop point, so there is no step and no hole. Fading the tail to zero
    # instead would be worse -- it would silence the tail of a sustained pad for
    # a moment every loop. At 130 bpm a sixteenth is 115 ms, so 6 ms of
    # correction is under a twentieth of a note. Only applied when a step is
    # actually measurable, so sparse tracks keep their attacks untouched.
    delta = out[0] - out[-1]
    if float(np.max(np.abs(delta))) > 0.02:
        fade = min(int(0.006 * SR), loop_n // 8)
        if fade > 8:
            # Quadratic, not linear: linear leaves a slope break at the join.
            ramp = np.linspace(0.0, 1.0, fade) ** 2
            out[-fade:] += ramp[:, None] * delta

    peak = float(np.max(np.abs(out))) or 1.0
    out *= 0.89 / peak
    out *= 10 ** (-1.5 / 20.0)  # -1.5 dBFS of headroom for the encoder
    return out


def write_ogg(stereo: np.ndarray, path: str) -> int:
    """16-bit WAV through `oggenc`. Returns the file size.

    Ogg Vorbis rather than MP3: it is the format Godot imports natively on
    every platform and it has no patent history. This ffmpeg build on macOS
    ships *without* libvorbis, so the WAV is handed to `vorbis-tools` instead
    of re-encoding through ffmpeg — the encoder is named in one place so a
    machine that has a different one only needs this function changed.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)
    wav_path = os.path.join(TMP_DIR, os.path.basename(path).replace(".ogg", ".wav"))
    pcm = np.clip(stereo, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wavfile.open(wav_path, "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(pcm.tobytes())
    # Quality 4 is ~112 kbps stereo: transparent for pads and bells, and all
    # nine tracks together stay under 5 MB.
    subprocess.run(["oggenc", "-Q", "-q", "4", "-o", path, wav_path],
                   check=True, capture_output=True)
    return os.path.getsize(path)
# ---------------------------------------------------------------------------
# The tracks
#
# Every track is a short loop (8-16 bars) because a 7-year-old's attention
# and a teacher's patience both run out long before a 3-minute cue would. The
# harmony is deliberately plain -- I, vi, IV, V in the major keys -- because
# the music is a background for *language*, and a melody with a lot of
# chromaticism pulls attention away from the words.
# ---------------------------------------------------------------------------

def track_title() -> Score:
    """The invitation: bright, bouncing, a little theatrical."""
    sc = Score(bpm=108, beats_per_bar=4, bars=8, swing=0.18)
    prog = [
        (chord(["F2"]), chord(["F4", "A4", "C5", "F5"])),
        (chord(["D2"]), chord(["D4", "F4", "A4", "D5"])),
        (chord(["Bb1"]), chord(["Bb3", "D4", "F4", "Bb4"])),
        (chord(["C2"]), chord(["C4", "E4", "G4", "C5"])),
    ]
    for bar in range(8):
        root, tones = prog[bar % 4]
        b = bar * 4
        sc.add("bass", root[0], b, 1.6, 0.9)
        sc.add("bass", root[0] + 12, b + 2, 0.8, 0.62)
        sc.add("bass", root[0] + 7, b + 3, 0.8, 0.55)
        # Bouncy "oom-pah" on the off-beats: the sound of a toy parade.
        sc.add("pizz", tones[1:], b + 1, 0.45, 0.42)
        sc.add("pizz", tones[1:], b + 3, 0.45, 0.38)
        for i in range(4):
            sc.add("shaker", 60, b + i + 0.5, 0.2, 0.5 if i % 2 == 0 else 0.34)
        if bar % 2 == 1:
            sc.add("kick", 36, b, 0.3, 0.7)

    verse = [
        (0, "F5", 1), (1, "A5", 0.5), (1.5, "C6", 0.5), (2, "A5", 1), (3, "F5", 1),
        (4, "D5", 1), (5, "F5", 1), (6, "A5", 1.5),
        (8, "Bb4", 1), (9, "D5", 0.5), (9.5, "F5", 0.5), (10, "D5", 1), (11, "Bb4", 1),
        (12, "C5", 1), (13, "E5", 1), (14, "G5", 1.6),
    ]
    sc.line("celesta", verse, 0.0, vel=0.92)
    answer = [
        (0, "A5", 1), (1, "C6", 0.5), (1.5, "D6", 0.5), (2, "C6", 1), (3, "A5", 1),
        (4, "G5", 1), (5, "F5", 1), (6, "D5", 1.5),
        (8, "Bb5", 1), (9, "A5", 0.5), (9.5, "G5", 0.5), (10, "F5", 1), (11, "D5", 1),
        (12, "C5", 0.5), (12.5, "E5", 0.5), (13, "G5", 0.5), (13.5, "A5", 0.5), (14, "C6", 1.8),
    ]
    sc.line("celesta", answer, 16.0, vel=0.86)
    sc.line("marimba", [(0, ["F3", "A3"], 2), (2, ["C4", "F4"], 2),
                        (8, ["Bb3", "D4"], 2), (10, ["C4", "E4"], 2)], 16.0, vel=0.4)
    return sc


def track_zone1() -> Score:
    """Pumpkin Patch: sunny, friendly, a bit clumsy on purpose."""
    sc = Score(bpm=116, beats_per_bar=4, bars=8, swing=0.22)
    prog = [("C", ["C4", "E4", "G4"]), ("Am", ["A3", "C4", "E4"]),
            ("F", ["F3", "A3", "C4"]), ("G", ["G3", "B3", "D4"])]
    roots = {"C": 36, "Am": 33, "F": 29, "G": 31}
    for bar in range(8):
        name, tones = prog[bar % 4]
        b = bar * 4
        sc.add("bass", roots[name], b, 1.4, 0.95)
        sc.add("bass", roots[name] + 7, b + 2, 1.0, 0.7)
        sc.add("marimba", chord(tones), b + 1, 0.6, 0.5)
        sc.add("marimba", chord(tones), b + 3, 0.6, 0.44)
        for i in range(4):
            sc.add("shaker", 60, b + i + 0.5, 0.2, 0.4)
        if bar % 4 == 0:
            sc.add("kick", 36, b, 0.3, 0.6)
        if bar % 4 == 2:
            sc.add("snare", 38, b + 2, 0.2, 0.4)

    tune = [
        (0, "G4", 1), (1, "A4", 1), (2, "C5", 1), (3, "E5", 1),
        (4, "D5", 1.2), (5.2, "C5", 0.6), (6, "A4", 1.4),
        (8, "F4", 1), (9, "A4", 1), (10, "C5", 1), (11, "A4", 1),
        (12, "B4", 1), (13, "D5", 1), (14, "G4", 1.6),
    ]
    sc.line("marimba", tune, 0.0, vel=0.8)
    tune2 = [
        (0, "E5", 0.5), (0.5, "D5", 0.5), (1, "C5", 1), (2, "G4", 1), (3, "C5", 1),
        (4, "A4", 1), (5, "C5", 0.5), (5.5, "D5", 0.5), (6, "E5", 1.4),
        (8, "F5", 1), (9, "E5", 0.5), (9.5, "D5", 0.5), (10, "C5", 1), (11, "A4", 1),
        (12, "G4", 0.5), (12.5, "B4", 0.5), (13, "D5", 0.5), (13.5, "G5", 0.5), (14, "E5", 1.6),
    ]
    sc.line("celesta", tune2, 16.0, vel=0.72)
    return sc


def track_zone2() -> Score:
    """Cozy Castle: a little waltz. Elegant, never grand."""
    sc = Score(bpm=138, beats_per_bar=3, bars=8, swing=0.08)
    prog = [
        ("Am", ["A3", "C4", "E4"], 33), ("Am", ["A3", "C4", "E4"], 33),
        ("Dm", ["D3", "F3", "A3"], 26), ("E", ["E3", "G#3", "B3"], 28),
        ("Am", ["A3", "C4", "E4"], 33), ("F", ["F3", "A3", "C4"], 29),
        ("Dm", ["D3", "F3", "A3"], 26), ("E", ["E3", "G#3", "B3"], 28),
    ]
    for bar, (name, tones, root) in enumerate(prog):
        b = bar * 3
        sc.add("bass", root, b, 0.9, 0.92)
        sc.add("harp", chord(tones), b + 1, 0.7, 0.5)
        sc.add("harp", chord(tones), b + 2, 0.7, 0.42)
        sc.add("triangle", 84, b + 1, 0.5, 0.35)

    tune = [
        (0, "E5", 1), (1, "A5", 1), (2, "C6", 1),
        (3, "B5", 1.5), (4.5, "G#5", 0.5), (5, "E5", 1),
        (6, "F5", 1), (7, "A5", 1), (8, "D6", 1),
        (9, "C6", 1), (10, "B5", 2),
        (12, "A5", 1), (13, "E5", 1), (14, "C5", 1),
        (15, "F5", 1), (16, "A5", 1), (17, "C6", 1),
        (18, "B5", 1), (19, "G#5", 1), (20, "E5", 1),
        (21, "A5", 3),
    ]
    sc.line("harp", tune, 0.0, vel=0.78)
    sc.arp("pizz", chord(["A3", "C4", "E4"]), 0.0, 6, 0.5, 0.6, 0.22)
    sc.arp("pizz", chord(["D3", "F3", "A3"]), 6.0, 6, 0.5, 0.6, 0.2)
    return sc


def track_zone3() -> Score:
    """Witch's Bog: bouncy and silly. The frogs keep the beat."""
    sc = Score(bpm=104, beats_per_bar=4, bars=8, swing=0.30)
    prog = [("Dm", ["D4", "F4", "A4"], 26), ("Gm", ["G3", "Bb3", "D4"], 31),
            ("A", ["A3", "C#4", "E4"], 33), ("Dm", ["D4", "F4", "A4"], 26)]
    for bar in range(8):
        name, tones, root = prog[bar % 4]
        b = bar * 4
        sc.add("bass", root, b, 1.0, 0.95)
        sc.add("bass", root + 12, b + 1.5, 0.5, 0.6)
        sc.add("bass", root + 7, b + 2.5, 0.7, 0.7)
        sc.add("organ", chord(tones), b + 1, 0.4, 0.34)
        sc.add("organ", chord(tones), b + 3, 0.4, 0.3)
        # Ducks-in-a-row percussion: two frog croaks a bar, alternating sides.
        sc.add_audio(drum_frog(0.9), b + 2.0, -0.3)
        if bar % 2 == 1:
            sc.add_audio(drum_frog(0.55), b + 3.5, 0.34)
        sc.add("wood", 76, b + 1, 0.2, 0.4)
        sc.add("wood", 76, b + 3, 0.2, 0.34)

    tune = [
        (0, "D5", 0.75), (0.75, "F5", 0.25), (1, "A5", 1), (2, "F5", 0.5), (2.5, "D5", 1.4),
        (4, "G5", 0.75), (4.75, "A5", 0.25), (5, "Bb5", 1), (6, "A5", 1.5),
        (8, "E5", 0.5), (8.5, "F5", 0.5), (9, "G5", 1), (10, "E5", 0.5), (10.5, "C#5", 1.4),
        (12, "D5", 1), (13, "A4", 1), (14, "D5", 1.6),
    ]
    sc.line("pizz", tune, 0.0, vel=0.85)
    tune2 = [
        (0, "A5", 0.5), (0.5, "G5", 0.5), (1, "F5", 0.5), (1.5, "E5", 0.5), (2, "D5", 1.8),
        (4, "Bb5", 0.5), (4.5, "A5", 0.5), (5, "G5", 1), (6, "D5", 1.6),
        (8, "C#5", 0.5), (8.5, "E5", 0.5), (9, "A5", 1), (10, "G5", 0.5), (10.5, "E5", 1.4),
        (12, "F5", 0.5), (12.5, "E5", 0.5), (13, "D5", 0.5), (13.5, "C#5", 0.5), (14, "D5", 1.8),
    ]
    sc.line("celesta", tune2, 16.0, vel=0.66)
    for beat in (1.5, 5.0, 9.5, 13.0, 17.5, 21.0, 25.5, 29.0):
        sc.add_audio(drum_bubble(0.5), beat, 0.4)
    return sc


def track_zone4() -> Score:
    """Franky's Laboratory: clockwork. Ticking, whirring, friendly."""
    sc = Score(bpm=112, beats_per_bar=4, bars=8, swing=0.0)
    prog = [("G", ["G3", "B3", "D4"], 31), ("C", ["C4", "E4", "G4"], 36),
            ("Em", ["E3", "G3", "B3"], 28), ("D", ["D3", "F#3", "A3"], 26)]
    for bar in range(8):
        name, tones, root = prog[bar % 4]
        b = bar * 4
        # A literal tick on every eighth: the laboratory is a machine.
        for i in range(8):
            sc.add("wood", 76, b + i * 0.5, 0.2, 0.34 if i % 2 == 0 else 0.2)
        sc.add("bass", root, b, 1.2, 0.9)
        sc.add("bass", root, b + 2, 1.2, 0.78)
        sc.add("pizz", chord(tones), b + 1, 0.4, 0.45)
        sc.add("pizz", chord(tones), b + 3, 0.4, 0.4)
        if bar % 4 == 0:
            sc.add("kick", 36, b, 0.3, 0.55)
            sc.add("kick", 36, b + 2, 0.3, 0.45)

    tune = [
        (0, "B4", 0.5), (0.5, "D5", 0.5), (1, "G5", 1), (2, "F#5", 0.5), (2.5, "D5", 1.4),
        (4, "E5", 0.5), (4.5, "G5", 0.5), (5, "C6", 1), (6, "B5", 1.5),
        (8, "G5", 0.5), (8.5, "E5", 0.5), (9, "B4", 1), (10, "D5", 0.5), (10.5, "G5", 1.4),
        (12, "F#5", 0.5), (12.5, "E5", 0.5), (13, "D5", 1), (14, "A4", 1.6),
    ]
    sc.line("celesta", tune, 0.0, vel=0.85)
    tune2 = [
        (0, "D6", 0.5), (0.5, "B5", 0.5), (1, "G5", 0.5), (1.5, "B5", 0.5), (2, "D6", 1.6),
        (4, "E6", 0.5), (4.5, "C6", 0.5), (5, "G5", 0.5), (5.5, "C6", 0.5), (6, "E6", 1.4),
        (8, "D6", 0.5), (8.5, "B5", 0.5), (9, "G5", 1), (10, "B5", 0.5), (10.5, "D6", 1.4),
        (12, "A5", 0.5), (12.5, "F#5", 0.5), (13, "D5", 0.5), (13.5, "A4", 0.5), (14, "D5", 1.8),
    ]
    sc.line("marimba", tune2, 16.0, vel=0.7)
    for beat in (2.5, 7.0, 11.5, 18.0, 22.5, 27.0):
        sc.add_audio(drum_bubble(0.6), beat, -0.3)
    return sc


def track_zone5() -> Score:
    """Haunted Dungeon: mysterious, but with a hand held. Slow and airy."""
    sc = Score(bpm=88, beats_per_bar=4, bars=8, swing=0.0)
    prog = [("Em", ["E3", "G3", "B3"], 28), ("C", ["C3", "E3", "G3"], 24),
            ("Am", ["A2", "C3", "E3"], 21), ("B", ["B2", "D#3", "F#3"], 23)]
    for bar in range(8):
        name, tones, root = prog[bar % 4]
        b = bar * 4
        sc.add("pad", chord(tones) + [root + 12], b, 3.6, 0.5)
        sc.add("bass", root, b, 3.0, 0.62)
        sc.add("celesta", _note_midi(tones[0]) + 12, b + 2, 1.0, 0.24)
        if bar % 2 == 0:
            sc.add("triangle", 84, b + 2, 1.2, 0.32)

    tune = [
        (0, "B4", 2), (2, "E5", 1.5), (4, "G5", 2), (6, "E5", 1.4),
        (8, "C5", 2), (10, "G4", 1.5), (12, "F#4", 2), (14, "D#4", 1.4),
    ]
    sc.line("celesta", tune, 0.0, vel=0.66)
    tune2 = [
        (0, "E5", 1.5), (1.5, "G5", 0.5), (2, "B5", 2), (4, "A5", 1.5), (5.5, "G5", 1.5),
        (8, "F#5", 1.5), (9.5, "E5", 0.5), (10, "D#5", 2), (12, "E5", 3.5),
    ]
    sc.line("harp", tune2, 16.0, vel=0.55)
    for beat in (3.0, 9.5, 14.0, 19.0, 25.5, 30.0):
        sc.add_audio(drip(np.random.default_rng(int(beat * 7)), 0.45), beat, 0.42)
    return sc


def track_zone6() -> Score:
    """The Grand Party: the whole cast, dancing. Brass and confetti."""
    sc = Score(bpm=132, beats_per_bar=4, bars=8, swing=0.12)
    prog = [("F", ["F3", "A3", "C4"], 29), ("Bb", ["Bb2", "D3", "F3"], 34),
            ("C", ["C3", "E3", "G3"], 36), ("F", ["F3", "A3", "C4"], 29)]
    for bar in range(8):
        name, tones, root = prog[bar % 4]
        b = bar * 4
        sc.add("bass", root, b, 1.4, 1.0)
        sc.add("bass", root + 7, b + 2, 1.0, 0.8)
        sc.add("brass", chord(tones), b + 1, 0.4, 0.6)
        sc.add("brass", chord(tones), b + 3, 0.4, 0.52)
        sc.add("kick", 36, b, 0.3, 0.85)
        sc.add("kick", 36, b + 2, 0.3, 0.7)
        sc.add("snare", 38, b + 1, 0.2, 0.55)
        sc.add("snare", 38, b + 3, 0.2, 0.55)
        for i in range(8):
            sc.add("hat", 80, b + i * 0.5, 0.12, 0.4 if i % 2 else 0.28)

    tune = [
        (0, "C5", 0.5), (0.5, "F5", 0.5), (1, "A5", 1), (2, "G5", 0.5), (2.5, "F5", 0.5), (3, "C5", 1),
        (4, "D5", 0.5), (4.5, "F5", 0.5), (5, "Bb5", 1), (6, "A5", 0.5), (6.5, "G5", 0.5), (7, "F5", 1),
        (8, "E5", 0.5), (8.5, "G5", 0.5), (9, "C6", 1), (10, "Bb5", 0.5), (10.5, "A5", 0.5), (11, "G5", 1),
        (12, "F5", 0.5), (12.5, "A5", 0.5), (13, "C6", 0.5), (13.5, "A5", 0.5), (14, "F5", 1.6),
    ]
    sc.line("brass", tune, 0.0, vel=0.85)
    sc.line("celesta", tune, 0.0, vel=0.45)
    tune2 = [
        (0, "A5", 0.5), (0.5, "C6", 0.5), (1, "F6", 1), (2, "E6", 0.5), (2.5, "D6", 0.5), (3, "C6", 1),
        (4, "Bb5", 0.5), (4.5, "D6", 0.5), (5, "F6", 1), (6, "E6", 1), (7, "C6", 1),
        (8, "G5", 0.5), (8.5, "C6", 0.5), (9, "E6", 1), (10, "D6", 0.5), (10.5, "C6", 0.5), (11, "G5", 1),
        (12, "A5", 0.5), (12.5, "C6", 0.5), (13, "F6", 0.5), (13.5, "C6", 0.5), (14, "A5", 1.6),
    ]
    sc.line("brass", tune2, 16.0, vel=0.9)
    sc.line("whistle", [(0, "F6", 0.5), (2, "A6", 0.5), (4, "C7", 0.5),
                        (8, "F6", 0.5), (10, "A6", 0.5), (12, "C7", 0.5),
                        (16, "A6", 0.5), (18, "F6", 1.0)], 16.0, vel=0.3)
    for beat in (1.0, 5.0, 9.0, 13.0, 17.0, 21.0, 25.0, 29.0):
        sc.add_audio(drum_tambourine(0.8), beat, -0.2)
    return sc


def track_story() -> Score:
    """Reading music: no rhythm section, no melody to follow, just air."""
    sc = Score(bpm=72, beats_per_bar=4, bars=8, swing=0.0)
    prog = [("C", ["C3", "E3", "G3"], 24), ("Am", ["A2", "C3", "E3"], 21),
            ("F", ["F2", "A2", "C3"], 17), ("G", ["G2", "B2", "D3"], 19)]
    for bar in range(8):
        name, tones, root = prog[bar % 4]
        b = bar * 4
        # `tones` are spelled note names, so the octave-up doubling has to go
        # through _note_midi() rather than plain arithmetic on the strings.
        sc.add("pad", chord(tones) + [_note_midi(tones[0]) + 12], b, 3.8, 0.42)
        sc.add("bass", root, b, 3.4, 0.5)
        # A single high note per bar, well spaced: a music box in the next room.
        if bar % 2 == 0:
            sc.add("celesta", _note_midi(tones[2]) + 24, b + 2, 1.6, 0.26)
        else:
            sc.add("celesta", _note_midi(tones[1]) + 24, b + 2.5, 1.4, 0.22)

    tune = [(0, "G4", 2), (2, "E5", 2), (4, "D5", 2), (6, "C5", 2),
            (8, "A4", 2), (10, "C5", 2), (12, "B4", 2), (14, "D5", 2)]
    sc.line("celesta", tune, 0.0, vel=0.4)
    for beat in (5.0, 13.0, 21.0, 29.0):
        sc.add("triangle", 84, beat, 2.0, 0.22)
    return sc


def track_ending() -> Score:
    """The lantern is full. Warm, unhurried, a little proud."""
    sc = Score(bpm=100, beats_per_bar=4, bars=8, swing=0.1)
    prog = [("C", ["C3", "E3", "G3", "C4"], 24), ("F", ["F2", "A2", "C3", "F3"], 17),
            ("G", ["G2", "B2", "D3", "G3"], 19), ("C", ["C3", "E3", "G3", "C4"], 24)]
    for bar in range(8):
        name, tones, root = prog[bar % 4]
        b = bar * 4
        sc.add("pad", chord(tones), b, 3.6, 0.5)
        sc.add("bass", root, b, 1.6, 0.85)
        sc.add("bass", root + 7, b + 2, 1.2, 0.6)
        sc.add("harp", chord(tones[1:]), b + 1, 0.5, 0.4)
        sc.add("harp", chord(tones[1:]), b + 3, 0.5, 0.36)
        if bar % 2 == 0:
            sc.add("kick", 36, b, 0.3, 0.5)

    tune = [
        (0, "E5", 1), (1, "G5", 1), (2, "C6", 1.5), (3.5, "B5", 0.5),
        (4, "A5", 1), (5, "F5", 1), (6, "A5", 1.6),
        (8, "G5", 1), (9, "B5", 1), (10, "D6", 1.5), (11.5, "B5", 0.5),
        (12, "C6", 1), (13, "G5", 1), (14, "E5", 1.8),
    ]
    sc.line("celesta", tune, 0.0, vel=0.85)
    sc.line("brass", [(0, "C5", 0.5), (4, "A4", 0.5), (8, "B4", 0.5), (12, "C5", 0.5)], 16.0, vel=0.45)
    tune2 = [
        (0, "C6", 1), (1, "E6", 1), (2, "G6", 1.6),
        (4, "F6", 1), (5, "A6", 1), (6, "C7", 1.8),
        (8, "B6", 1), (9, "G6", 1), (10, "D6", 1.4),
        (12, "C6", 1), (13, "E6", 1), (14, "G6", 2.0),
    ]
    sc.line("celesta", tune2, 16.0, vel=0.7)
    for beat in (4.0, 12.0, 20.0, 28.0):
        sc.add("triangle", 84, beat, 1.5, 0.3)
    return sc


TRACKS = {
    "title": (track_title, dict(wet=0.30, seed=11)),
    "zone1_patch": (track_zone1, dict(wet=0.24, seed=21)),
    "zone2_castle": (track_zone2, dict(wet=0.34, seed=31)),
    "zone3_bog": (track_zone3, dict(wet=0.30, seed=41)),
    "zone4_lab": (track_zone4, dict(wet=0.22, seed=51)),
    "zone5_dungeon": (track_zone5, dict(wet=0.44, seed=61)),
    "zone6_party": (track_zone6, dict(wet=0.28, seed=71)),
    "story": (track_story, dict(wet=0.40, seed=81)),
    "ending": (track_ending, dict(wet=0.32, seed=91)),
}


# ---------------------------------------------------------------------------
# Report + CLI
# ---------------------------------------------------------------------------

def describe(name: str, stereo: np.ndarray, size: int) -> str:
    mono = stereo.mean(axis=1)
    peak = float(np.max(np.abs(mono)))
    rms = float(np.sqrt(np.mean(mono ** 2)))
    # The gap between peak and average is what tells a loud, dense mix from a
    # sparse one; the music sits *under* speech, so a lower RMS is correct.
    crest = 20 * math.log10((peak or 1e-9) / (rms or 1e-9))
    seam = float(abs(mono[0] - mono[-1]))
    return ("MUSIC %-14s %6.2fs  %6.1f dBFS peak  %6.1f dBFS rms  "
            "crest %4.1f dB  seam %.4f  %5.1f MB"
            % (name, len(stereo) / SR, 20 * math.log10(peak or 1e-9),
               20 * math.log10(rms or 1e-9), crest, seam, size / 1e6))


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", default="", help="render a single track id")
    ap.add_argument("--out", default=OUT_DIR, help="output directory")
    args = ap.parse_args(argv)

    wanted = [args.only] if args.only else list(TRACKS)
    unknown = [w for w in wanted if w not in TRACKS]
    if unknown:
        print("MUSIC FAIL unknown track(s): %s" % ", ".join(unknown))
        return 2

    os.makedirs(args.out, exist_ok=True)
    for name in wanted:
        builder, opts = TRACKS[name]
        score = builder()
        audio = render(score, wet=opts["wet"], seed=opts["seed"])
        path = os.path.join(args.out, "%s.ogg" % name)
        size = write_ogg(audio, path)
        print(describe(name, audio, size))

    print("MUSIC RESULT: %d track(s) written to %s" % (len(wanted), args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
