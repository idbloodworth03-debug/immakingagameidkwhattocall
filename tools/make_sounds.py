"""Generates every sound effect and music loop in game/audio/ from scratch.

Nothing is sampled, so there are no licenses to worry about. Run from the
repository root after changing anything here:

    python3 tools/make_sounds.py

Requires numpy. Output is 16-bit mono WAV at 22,050 Hz.
"""
import os
import sys
import wave

import numpy as np

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "game", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "game", "audio", "music")
rng = np.random.default_rng(7)
MUSIC_RMS = 0.12  # how loud the music loops are on average


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


# --- Warm instruments ("Ranger Camp": wood, brass, plucked strings) ----------

def marimba(freq, length=0.5, decay=0.22):
    """A wooden bar: a round fundamental with a quick, bright overtone."""
    return mix(
        envelope(tone(freq, length), attack=0.002, decay=decay),
        0.35 * envelope(tone(freq * 4.0, length), attack=0.001, decay=decay * 0.18),
        0.12 * envelope(tone(freq * 9.9, length), attack=0.001, decay=decay * 0.06),
    )


def bell(freq, length=0.9, decay=0.35):
    """A glockenspiel bar: bright, with a long soft ring."""
    return mix(
        envelope(tone(freq, length), attack=0.001, decay=decay),
        0.4 * envelope(tone(freq * 2.76, length), attack=0.001, decay=decay * 0.35),
        0.15 * envelope(tone(freq * 5.4, length), attack=0.001, decay=decay * 0.15),
    )


def pluck(freq, length=0.6, brightness=0.5, decay=0.996):
    """A plucked string, like a ukulele (Karplus-Strong)."""
    n = max(2, int(RATE / freq))
    buf = list(lowpass(rng.uniform(-1, 1, n), 1.0 - brightness))
    out = np.empty(int(length * RATE))
    i = 0
    for k in range(len(out)):
        j = k % n
        nxt = buf[(j + 1) % n]
        out[k] = buf[j]
        buf[j] = (buf[j] + nxt) * 0.5 * decay
    return envelope(out, attack=0.002, release=0.03)


def knock(freq, decay=0.05):
    """A wooden knock: a short, round bump with a soft click."""
    return mix(
        envelope(tone(freq, 0.18, "sine", freq * 0.92), attack=0.001, decay=decay),
        0.45 * envelope(tone(freq * 2.7, 0.1), attack=0.001, decay=decay * 0.35),
        0.18 * envelope(lowpass(noise(0.02), 0.6), attack=0.0005, decay=0.004),
    )


def soft_whoosh(seconds=0.45, darkness=0.93):
    t = t_axis(seconds)
    shape = np.sin(np.pi * t / seconds) ** 1.5
    return envelope(lowpass(noise(seconds), darkness) * shape, attack=0.04, release=0.08)


SFX = {
    # Menus
    "tap": lambda: knock(520, 0.045),
    "select": lambda: mix(knock(760, 0.035), 0.5 * envelope(tone(500, 0.06, "sine", 900), attack=0.002, decay=0.025)),
    "error": lambda: mix(at(knock(330, 0.06), 0, 0.3), at(knock(247, 0.08), 0.11, 0.3)),
    "coin": lambda: mix(at(bell(1319, 0.4, 0.12), 0, 0.5), at(bell(1760, 0.4, 0.14), 0.06, 0.5), 0.5 * at(knock(420, 0.03), 0, 0.5)),
    "upgrade": lambda: mix(*[at(marimba(f, 0.6, 0.25), i * 0.07, 0.9) for i, f in enumerate([523, 659, 784, 1047])], at(0.5 * bell(2093, 0.6, 0.25), 0.28, 0.9)),
    "pop": lambda: mix(envelope(tone(320, 0.08, "sine", 820), attack=0.002, decay=0.035), 0.4 * knock(900, 0.02)),
    # Cages
    "rattle": lambda: mix(*[at(envelope(lowpass(noise(0.03), 0.2) + 0.5 * tone(2600 + 300 * i, 0.03), decay=0.012), i * 0.07, 0.45) for i in range(6)]),
    "reveal": lambda: mix(envelope(tone(880, 0.6), decay=0.2), 0.35 * envelope(tone(880 * 2.76, 0.6), decay=0.1)),
    "new_card": lambda: mix(*[at(marimba(f, 0.6, 0.3), i * 0.08, 1.0) for i, f in enumerate([523, 659, 784, 1047])], at(0.6 * bell(2093, 0.8, 0.3), 0.32, 1.0)),
    # Battle
    "release": lambda: mix(envelope(lowpass(noise(0.14), 0.6), decay=0.05), envelope(tone(300, 0.1, "sine", 650), decay=0.05)),
    "tool": lambda: mix(envelope(lowpass(noise(0.25), 0.4) * np.linspace(0.2, 1, int(0.25 * RATE)), release=0.08), at(envelope(tone(160, 0.15, "sine", 60), decay=0.06), 0.18, 0.4)),
    "horn": lambda: envelope(lowpass(mix(tone(233, 0.5, "triangle"), 0.6 * tone(349, 0.5, "triangle"), 0.3 * tone(466, 0.5, "sine")) * (1 + 0.12 * np.sin(2 * np.pi * 6 * t_axis(0.5))), 0.5), attack=0.03, release=0.1),
    "heal": lambda: chime([1319, 1568, 2093, 2637], 0.05, 0.3, "sine", 0.1),
    "hit": lambda: mix(envelope(tone(150, 0.09, "sine", 60), decay=0.03), 0.4 * envelope(lowpass(noise(0.03), 0.3), decay=0.01)),
    "zap": lambda: envelope(lowpass(noise(0.05), 0.1) * 0.6 + 0.4 * tone(1800, 0.05, "sine", 900), decay=0.02),
    "tower_hit": lambda: mix(envelope(tone(110, 0.16, "sine", 45), decay=0.06), 0.5 * envelope(lowpass(noise(0.08), 0.5), decay=0.03)),
    "death": lambda: envelope(lowpass(noise(0.22), 0.75), decay=0.07),
    "boom": lambda: mix(envelope(lowpass(noise(1.0), 0.93), decay=0.3) * 1.4, envelope(tone(80, 0.9, "sine", 28), decay=0.35)),
    "alert": lambda: mix(*[at(marimba(f, 0.3, 0.12), i * 0.12, 0.5) for i, f in enumerate([880, 1047, 1319])]),
    "tick": lambda: envelope(tone(2000, 0.03, "sine"), decay=0.01),
    "victory": lambda: mix(*[at(marimba(f, 0.5, 0.2), i * 0.11, 1.6) for i, f in enumerate([523, 659, 784])], at(mix(bell(1047, 1.2, 0.5), 0.8 * marimba(784, 1.2, 0.5), 0.7 * marimba(659, 1.2, 0.5), 0.5 * pluck(262, 1.2, 0.6)), 0.36, 1.6)),
    "defeat": lambda: mix(*[at(marimba(f, 0.45, 0.3), i * 0.26, 1.4) for i, f in enumerate([392, 330, 262, 196])]),
    # Big moments
    "star3": lambda: mix(*[at(bell(f, 0.5, 0.15), i * 0.055, 1.5) for i, f in enumerate([784, 988, 1175, 1568, 1976, 2349])], at(mix(bell(1568, 1.1, 0.5), marimba(1175, 1.1, 0.5), marimba(784, 1.1, 0.5)), 0.34, 1.5)),
    "fanfare": lambda: mix(*[at(marimba(f, 0.35, 0.15), i * 0.07, 0.9) for i, f in enumerate([659, 784, 1047])], at(mix(bell(1319, 0.6, 0.3), marimba(1047, 0.6, 0.3)), 0.22, 0.9)),
    "synergy": lambda: mix(*[at(bell(f, 0.4, 0.15), i * 0.06, 0.8) for i, f in enumerate([587, 880, 1175])], at(0.5 * envelope(tone(1760, 0.45, "sine") * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t_axis(0.45))), decay=0.25), 0.18, 0.8)),
    "whoosh": lambda: soft_whoosh(0.45),
    # Rival Rangers: the VS slam, and an emote popping up
    "versus": lambda: mix(
        envelope(tone(110, 0.7, "sine", 38), decay=0.25) * 1.3,
        envelope(lowpass(noise(0.35), 0.8), decay=0.08),
        at(envelope(mix(tone(392, 0.5, "square") * 0.5, tone(587, 0.5, "triangle"), tone(784, 0.5, "triangle")), decay=0.22), 0.05, 0.8),
    ),
    "emote": lambda: mix(envelope(tone(620, 0.09, "sine", 1240), decay=0.05), at(envelope(tone(1480, 0.07, "triangle"), decay=0.03), 0.07, 0.18)),
    "land": lambda: mix(envelope(tone(150, 0.2, "sine", 70), attack=0.002, decay=0.06), 0.35 * envelope(lowpass(noise(0.18), 0.8), attack=0.004, decay=0.06), 0.4 * knock(300, 0.04)),
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


def render_inst(events, total, play, volume):
    """events: (start seconds, length seconds, frequency); play(freq, length) makes one note."""
    out = np.zeros(int(total * RATE))
    for start, length, freq in events:
        out += at(play(freq, length), start, total)[: len(out)] * volume
    return out


def whistle(freq, length):
    """A soft whistle: a pure tone with a little vibrato and breath."""
    t = t_axis(length)
    vibrato = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.25, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vibrato) / RATE
    body = np.sin(phase) + 0.08 * np.sin(2 * phase)
    breath = 0.05 * lowpass(noise(length), 0.7)
    return envelope(body + breath, attack=0.04, release=0.08)


def strum(chord, length, gap=0.012):
    """A ukulele strum: the chord's strings plucked one after another."""
    return mix(*[at(pluck(f, length, 0.55, 0.993) * (0.9 - 0.12 * i), i * gap, length + gap * len(chord)) for i, f in enumerate(chord)])


def menu_music():
    """A relaxed camp tune in G major, 100 bpm, 16 bars: a whistled melody
    over ukulele strums, a soft marimba echo and a plucked bass."""
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
    melody, bass = [], []
    t = 0.0
    for block in order:
        for name, beats in melody_blocks[block]:
            melody.append((t, beats * beat * 0.95, note(name)))
            t += beats * beat
    strums = np.zeros(int(total * RATE))
    for bar, chord in enumerate(chords):
        minor = chord.endswith("m")
        root = chord.rstrip("m")
        start = bar * 4 * beat
        bass_root = note(root + "2") if root in ("A", "B") else note(root + "3") / 2
        bass.append((start, 2 * beat, bass_root))
        bass.append((start + 2 * beat, 2 * beat, bass_root * 1.5))
        tones = chord_notes(root + "4", minor)
        # Down, down-up, up-down-up: an easy campfire strum.
        for b, k in ((0, 1.0), (1, 0.7), (1.5, 0.55), (2.5, 0.6), (3, 0.7), (3.5, 0.5)):
            strums += at(strum(tones, beat * 1.2) * k, start + b * beat, total)[: len(strums)]
    echo = [(s0 + beat * 0.5, min(l, beat), f / 2) for s0, l, f in melody[::3]]
    return mix(
        render_inst(melody, total, whistle, 0.32),
        strums * 0.16,
        render_inst(echo, total, lambda f, l: marimba(f, l + 0.3, 0.25), 0.10),
        render_inst(bass, total, lambda f, l: pluck(f, l, 0.3, 0.997), 0.34),
    )


def battle_music():
    """A bouncy tune in A minor, 132 bpm, 16 bars: a xylophone hook, ukulele
    off-beat chops, a plucked bass and soft camp drums (a thump, a clap and a
    shaker)."""
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
    melody, bass = [], []
    t = 0.0
    for section in sections:
        for bar_notes in section:
            for name, beats in bar_notes:
                melody.append((t, beats * beat, note(name)))
                t += beats * beat
    drums = np.zeros(int(total * RATE))
    chops = np.zeros(int(total * RATE))
    thump = envelope(tone(110, 0.2, "sine", 50), attack=0.002, decay=0.07)
    clap = envelope(lowpass(noise(0.12), 0.55), attack=0.002, decay=0.035)
    shaker = envelope(lowpass(noise(0.06), 0.2) * 0.5, attack=0.004, decay=0.015)
    for bar, chord in enumerate(chords):
        root = chord.rstrip("m")
        minor = chord.endswith("m")
        start = bar * 4 * beat
        low = note(root + "2")
        for eighth in range(8):
            if eighth % 2 == 0:
                bass.append((start + eighth * beat / 2, beat * 0.45, low if eighth % 4 != 2 else low * 1.5))
            drums += at(shaker, start + eighth * beat / 2, total)[: len(drums)] * (0.45 if eighth % 2 else 0.25)
        for b in (0, 2):
            drums += at(thump, start + b * beat, total)[: len(drums)] * 0.9
        for b in (1, 3):
            drums += at(clap, start + b * beat, total)[: len(drums)] * 0.4
        tones = chord_notes(root + "4", minor)
        for b in (0.5, 1.5, 2.5, 3.5):
            chops += at(strum(tones, beat * 0.35, 0.006), start + b * beat, total)[: len(chops)]
    return mix(
        render_inst(melody, total, lambda f, l: mix(marimba(f, l + 0.25, 0.18), 0.35 * bell(f * 2, l + 0.2, 0.08)), 0.30),
        chops * 0.13,
        render_inst(bass, total, lambda f, l: pluck(f, l + 0.1, 0.35, 0.995), 0.36),
        drums * 0.5,
    )


def main():
    # `python make_sounds.py star3 fanfare` writes just those sounds.
    only = sys.argv[1:]
    for name, make in SFX.items():
        if not only or name in only:
            save(os.path.join(SFX_DIR, name + ".wav"), make())
    if only:
        print(f"{len(only)} sound effects written")
        return
    # Music is evened out by loudness (not peak), and sits under the UI
    # sounds (the game plays it quieter still, see sound.gd).
    for name, track in (("menu", menu_music()), ("battle", battle_music())):
        rms = np.sqrt(np.mean(track ** 2))
        track = track / max(1e-9, rms) * MUSIC_RMS
        save(os.path.join(MUSIC_DIR, name + ".wav"), track, peak=min(0.95, np.max(np.abs(track))))
    print(f"{len(SFX)} sound effects and 2 music loops written")


if __name__ == "__main__":
    main()
