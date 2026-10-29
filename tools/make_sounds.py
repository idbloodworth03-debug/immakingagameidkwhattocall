"""Generates every sound effect and music loop in game/audio/ from scratch.

Nothing is sampled, so there are no licenses to worry about. Run from the
repository root after changing anything here:

    python3 tools/make_sounds.py

Requires numpy. Output is 16-bit mono WAV at 22,050 Hz.
"""
import os
import wave

import numpy as np

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "game", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "game", "audio", "music")
rng = np.random.default_rng(7)


# --- Building blocks --------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def tone(freq, seconds, wave_shape="sine", freq_end=None):
    """A tone, optionally sliding from freq to freq_end."""
    t = t_axis(seconds)
    f = np.full_like(t, freq) if freq_end is None else np.linspace(freq, freq_end, len(t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if wave_shape == "sine":
        return np.sin(phase)
    if wave_shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if wave_shape == "triangle":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if wave_shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    raise ValueError(wave_shape)


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * RATE))


def lowpass(signal, amount):
    """Simple one-pole smoothing; amount 0..1 (higher = darker)."""
    out = np.empty_like(signal)
    acc = 0.0
    a = 1.0 - amount
    for i, x in enumerate(signal):
        acc += a * (x - acc)
        out[i] = acc
    return out


def envelope(signal, attack=0.005, decay=None, release=0.02):
    """Fade in, optional exponential decay, fade out (stops clicks)."""
    n = len(signal)
    env = np.ones(n)
    a = min(n, int(attack * RATE))
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if decay:
        env *= np.exp(-np.arange(n) / (decay * RATE))
    r = min(n, int(release * RATE))
    if r > 0:
        env[-r:] *= np.linspace(1, 0, r)
    return signal * env


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[: len(p)] += p
    return out


def at(signal, seconds, total):
    """Places a signal `seconds` into a buffer `total` seconds long."""
    out = np.zeros(int(total * RATE))
    start = int(seconds * RATE)
    end = min(len(out), start + len(signal))
    out[start:end] += signal[: end - start]
    return out


def note(name):
    """'A4' -> frequency."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


def save(path, signal, peak=0.85):
    signal = signal / max(1e-9, np.max(np.abs(signal))) * peak
    data = (signal * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


# --- Sound effects ------------------------------------------------------------

def chime(freqs, step, length, shape="sine", decay=0.25):
    total = step * len(freqs) + length
    return mix(*[at(envelope(tone(f, length, shape), decay=decay), i * step, total) for i, f in enumerate(freqs)])


SFX = {
    # Menus
    "tap": lambda: mix(envelope(tone(1200, 0.05, "sine", 900), decay=0.015), envelope(noise(0.01) * 0.3)),
    "select": lambda: envelope(tone(880, 0.07, "triangle", 1320), decay=0.04),
    "error": lambda: mix(at(envelope(tone(180, 0.09, "square")), 0, 0.25), at(envelope(tone(150, 0.11, "square")), 0.12, 0.25)),
    "coin": lambda: chime([1568, 2093], 0.06, 0.25, "sine", 0.08),
    "upgrade": lambda: chime([523, 659, 784, 1047, 1319], 0.07, 0.35, "triangle", 0.12),
    "pop": lambda: envelope(tone(500, 0.08, "sine", 1100), decay=0.04),
    # Cages
    "rattle": lambda: mix(*[at(envelope(lowpass(noise(0.03), 0.2) + 0.5 * tone(2600 + 300 * i, 0.03), decay=0.012), i * 0.07, 0.45) for i in range(6)]),
    "reveal": lambda: mix(envelope(tone(880, 0.6), decay=0.2), 0.35 * envelope(tone(880 * 2.76, 0.6), decay=0.1)),
    "new_card": lambda: chime([523, 659, 784, 1047], 0.08, 0.45, "square", 0.18),
    # Battle
    "release": lambda: mix(envelope(lowpass(noise(0.14), 0.6), decay=0.05), envelope(tone(300, 0.1, "sine", 650), decay=0.05)),
    "tool": lambda: mix(envelope(lowpass(noise(0.25), 0.4) * np.linspace(0.2, 1, int(0.25 * RATE)), release=0.08), at(envelope(tone(160, 0.15, "sine", 60), decay=0.06), 0.18, 0.4)),
    "horn": lambda: envelope(mix(tone(233, 0.45, "square"), 0.6 * tone(349, 0.45, "square")) * (1 + 0.15 * np.sin(2 * np.pi * 7 * t_axis(0.45))), attack=0.02, release=0.08),
    "heal": lambda: chime([1319, 1568, 2093, 2637], 0.05, 0.3, "sine", 0.1),
    "hit": lambda: mix(envelope(tone(150, 0.09, "sine", 60), decay=0.03), 0.4 * envelope(lowpass(noise(0.03), 0.3), decay=0.01)),
    "zap": lambda: envelope(lowpass(noise(0.05), 0.1) * 0.6 + 0.4 * tone(1800, 0.05, "sine", 900), decay=0.02),
    "tower_hit": lambda: mix(envelope(tone(110, 0.16, "sine", 45), decay=0.06), 0.5 * envelope(lowpass(noise(0.08), 0.5), decay=0.03)),
    "death": lambda: envelope(lowpass(noise(0.22), 0.75), decay=0.07),
    "boom": lambda: mix(envelope(lowpass(noise(1.0), 0.93), decay=0.3) * 1.4, envelope(tone(80, 0.9, "sine", 28), decay=0.35)),
    "alert": lambda: mix(*[at(envelope(tone(f, 0.14, "square")), i * 0.18, 0.6) for i, f in enumerate([880, 660, 880])]),
    "tick": lambda: envelope(tone(2000, 0.03, "sine"), decay=0.01),
    "victory": lambda: mix(
        chime([523, 659, 784], 0.12, 0.3, "square", 0.15),
        at(envelope(mix(tone(1047, 0.9, "square"), tone(784, 0.9, "triangle"), tone(659, 0.9, "triangle")), decay=0.5), 0.38, 1.4),
    ),
    "defeat": lambda: mix(*[at(envelope(tone(f, 0.35, "triangle"), decay=0.3), i * 0.28, 1.4) for i, f in enumerate([392, 330, 262, 196])]),
}


# --- Music --------------------------------------------------------------------

def render_part(events, total, shape, volume, decay=None, release=0.03):
    """events: list of (start_beat, beats, note_name) with seconds per beat in the tuple."""
    out = np.zeros(int(total * RATE))
    for start, length, freq in events:
        sig = envelope(tone(freq, length * 0.95, shape), attack=0.008, decay=decay, release=release)
        out += at(sig, start, total)[: len(out)] * volume
    return out


def chord_notes(root, minor=False):
    r = note(root)
    third = r * 2 ** ((3 if minor else 4) / 12)
    fifth = r * 2 ** (7 / 12)
    return [r, third, fifth]


def menu_music():
    """A calm loop in G major, 100 bpm, 16 bars."""
    beat = 60 / 100
    chords = ["G", "D", "Em", "C", "G", "D", "C", "D", "G", "D", "Em", "C", "C", "D", "G", "G"]
    melody_blocks = {
        "A": [("B4", 1), ("D5", 1), ("G5", 1.5), ("F#5", 0.5), ("E5", 1), ("D5", 1), ("A4", 2)],
        "B": [("G4", 1), ("B4", 1), ("E5", 1.5), ("D5", 0.5), ("C5", 1), ("B4", 1), ("G4", 2)],
        "A2": [("B4", 1), ("D5", 1), ("G5", 1), ("A5", 1), ("B5", 1.5), ("A5", 0.5), ("F#5", 2)],
        "C": [("E5", 1), ("G5", 1), ("E5", 1), ("C5", 1), ("D5", 1), ("F#5", 1), ("A5", 2)],
        "END": [("D5", 1), ("B4", 1), ("A4", 1), ("B4", 1), ("G4", 4)],
    }
    order = ["A", "B", "A2", "C", "A", "B", "C", "END"]
    total = len(chords) * 4 * beat
    melody, bass, arp = [], [], []
    t = 0.0
    for block in order:
        for name, beats in melody_blocks[block]:
            melody.append((t, beats * beat, note(name)))
            t += beats * beat
    for bar, chord in enumerate(chords):
        minor = chord.endswith("m")
        root = chord.rstrip("m")
        start = bar * 4 * beat
        bass_root = note(root + "2") if root in ("A", "B") else note(root + "3") / 2
        bass.append((start, 2 * beat, bass_root))
        bass.append((start + 2 * beat, 2 * beat, bass_root * 1.5))
        tones = chord_notes(root + "4", minor)
        pattern = [tones[0], tones[1], tones[2], tones[1]] * 2
        for i, f in enumerate(pattern):
            arp.append((start + i * beat / 2, beat / 2, f))
    return mix(
        render_part(melody, total, "triangle", 0.30, decay=0.6),
        render_part(bass, total, "triangle", 0.30),
        render_part(arp, total, "square", 0.05, decay=0.12),
    )


def battle_music():
    """An upbeat loop in A minor, 132 bpm, 16 bars, with drums."""
    beat = 60 / 132
    chords = ["Am", "F", "C", "G"] * 4
    hook = [
        [("A4", .5), ("C5", .5), ("E5", .5), ("A5", .5), ("G5", 1), ("E5", 1)],
        [("F5", .5), ("E5", .5), ("C5", .5), ("A4", .5), ("C5", 2)],
        [("E5", .5), ("G5", .5), ("C6", .5), ("G5", .5), ("E5", 1), ("D5", 1)],
        [("D5", .5), ("E5", .5), ("G5", .5), ("B5", .5), ("A5", 2)],
    ]
    calm = [
        [("A4", 2), ("E5", 2)],
        [("F5", 2), ("C5", 2)],
        [("E5", 2), ("G5", 2)],
        [("D5", 2), ("B4", 2)],
    ]
    sections = [hook, hook, calm, hook]
    total = len(chords) * 4 * beat
    melody, bass, pad = [], [], []
    t = 0.0
    for section in sections:
        for bar_notes in section:
            for name, beats in bar_notes:
                melody.append((t, beats * beat, note(name)))
                t += beats * beat
    drums = np.zeros(int(total * RATE))
    kick = envelope(tone(120, 0.18, "sine", 40), decay=0.06)
    snare = envelope(lowpass(noise(0.15), 0.35), decay=0.05)
    hat = envelope(noise(0.04) * 0.5, decay=0.01)
    for bar, chord in enumerate(chords):
        root = chord.rstrip("m")
        minor = chord.endswith("m")
        start = bar * 4 * beat
        low = note(root + "2")
        for eighth in range(8):
            bass.append((start + eighth * beat / 2, beat / 2, low if eighth % 4 != 3 else low * 1.5))
            drums += at(hat, start + eighth * beat / 2, total)[: len(drums)] * 0.35
        for b in (0, 2):
            drums += at(kick, start + b * beat, total)[: len(drums)] * 0.9
        for b in (1, 3):
            drums += at(snare, start + b * beat, total)[: len(drums)] * 0.45
        for f in chord_notes(root + "4", minor):
            pad.append((start, 4 * beat, f))
    return mix(
        render_part(melody, total, "square", 0.17, decay=0.35),
        render_part(bass, total, "saw", 0.16, decay=0.15),
        render_part(pad, total, "triangle", 0.06),
        drums * 0.55,
    )


def main():
    for name, make in SFX.items():
        save(os.path.join(SFX_DIR, name + ".wav"), make())
    save(os.path.join(MUSIC_DIR, "menu.wav"), menu_music(), peak=0.7)
    save(os.path.join(MUSIC_DIR, "battle.wav"), battle_music(), peak=0.7)
    print(f"{len(SFX)} sound effects and 2 music loops written")


if __name__ == "__main__":
    main()
