#!/usr/bin/env python3
"""Generates placeholder audio: sound effects in Audio/ and music loops in Audio/Music/.

Run from the project root:  python3 tools/gen_audio.py

Music: each track is a 4-bar loop split into 4 layers of identical length
(drums, bass, arp, lead) so the game can fade layers in and out in sync.
Every WAV embeds loop points (RIFF "smpl" chunk) so Godot loops it seamlessly.
To use real music, export each layer as <track>_<layer>.wav at the same BPM.
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), "..", "Audio")
RATE = 22050
random.seed(11)


def write(name, samples):
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def square(phase):
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def sweep(dur, f0, f1, vol, fn=square, curve=1.5):
    n = int(dur * RATE)
    out, ph = [], 0.0
    for i in range(n):
        t = i / n
        ph += (f0 + (f1 - f0) * t) / RATE
        out.append(fn(ph) * (1 - t) ** curve * vol)
    return out


def noise(dur, vol, hold=1):
    n = int(dur * RATE)
    out, v = [], 0.0
    for i in range(n):
        if i % hold == 0:
            v = random.uniform(-1, 1)
        out.append(v * (1 - i / n) ** 2 * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0 for t in tracks) for i in range(n)]


def tri(phase):
    return 4 * abs((phase % 1.0) - 0.5) - 1


def main():
    os.makedirs(OUT, exist_ok=True)
    write("shoot.wav", sweep(0.09, 1800, 900, 0.18))
    write("hit.wav", mix(sweep(0.06, 600, 300, 0.15), noise(0.05, 0.1, 2)))
    write("explode.wav", mix(sweep(0.3, 400, 60, 0.18), noise(0.35, 0.3, 5)))
    pick = []
    for f in (880, 1320, 1760):
        pick += sweep(0.05, f, f, 0.2, tri, 0.5)
    write("pickup.wav", pick)
    write("power_up.wav", sum((sweep(0.07, f, f * 1.05, 0.2, tri, 0.4) for f in (523, 659, 784, 1047)), []))
    write("player_hit.wav", mix(sweep(0.6, 900, 80, 0.2), noise(0.7, 0.35, 8)))
    write("enemy_shoot.wav", sweep(0.12, 500, 250, 0.1, tri))
    print("wrote sounds to %s" % os.path.normpath(OUT))
    write_music()



# ---------------------------------------------------------------- music

MUSIC_OUT = os.path.join(OUT, "Music")
BARS = 4
BEATS_PER_BAR = 4

# name: (bpm, root midi note, chord roots as semitones from root, minor scale lead pattern)
TRACKS = {
    "level1": (110, 57, [0, -4, 3, -2]),   # A minor: Am F C G
    "level2": (125, 50, [0, -4, 3, -2]),   # D minor: Dm Bb F C
    "level3": (140, 52, [0, -4, -2, 0]),   # E minor: Em C D Em
    "boss1": (120, 57, [0, 1, 0, -1]),     # tense: i bII i VII
    "boss2": (135, 50, [0, 1, -2, -5]),
    "boss3": (150, 52, [0, 1, 3, -1]),
}
MINOR_PENTATONIC = [0, 3, 5, 7, 10, 12, 15, 17]
LEAD_PATTERNS = [  # (step in 8ths, scale index, length in 8ths) per bar
    [(0, 4, 2), (2, 3, 1), (3, 2, 1), (4, 4, 3), (7, 5, 1)],
    [(0, 2, 3), (3, 1, 1), (4, 0, 2), (6, 1, 2)],
    [(0, 3, 1), (1, 4, 1), (2, 5, 2), (4, 6, 2), (6, 5, 1), (7, 4, 1)],
    [(0, 4, 4), (4, 2, 2), (6, 0, 2)],
]


def midi_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def write_loop(name, samples):
    """Mono 16-bit WAV with a forward loop over the whole file (smpl chunk)."""
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples)
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
    smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt
    body += b"data" + struct.pack("<I", len(data)) + data
    body += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(os.path.join(MUSIC_OUT, name), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)


def add_note(buf, start, length, freq, vol, wave_fn, decay=3.0, vibrato=0.0):
    n = min(length, len(buf) - start)
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        ph += f / RATE
        env = math.exp(-decay * t) * min(1.0, (n - i) / 200.0)  # short release, no clicks
        buf[start + i] += wave_fn(ph) * env * vol


def sine(phase):
    return math.sin(2 * math.pi * phase)


def pulse25(phase):
    return 1.0 if (phase % 1.0) < 0.25 else -1.0


def write_music():
    os.makedirs(MUSIC_OUT, exist_ok=True)
    for name, (bpm, root, chords) in TRACKS.items():
        beat = 60.0 / bpm
        total = int(round(BARS * BEATS_PER_BAR * beat * RATE))
        eighth = beat / 2
        drums, bass, arp, lead = ([0.0] * total for _ in range(4))
        at = lambda beats: int(round(beats * beat * RATE))
        boss = name.startswith("boss")
        for bar in range(BARS):
            b0 = bar * BEATS_PER_BAR
            chord_root = root + chords[bar]
            for q in range(BEATS_PER_BAR):
                # kick on every beat (four-on-the-floor) so the beat is unmistakable
                kick = sweep(0.16, 130, 40, 0.55, sine, 2.0)
                for i, v in enumerate(kick):
                    if at(b0 + q) + i < total:
                        drums[at(b0 + q) + i] += v
                if q in (1, 3):
                    for i, v in enumerate(noise(0.14, 0.32, 2)):
                        if at(b0 + q) + i < total:
                            drums[at(b0 + q) + i] += v
                for h in (0.5,) + ((0.25, 0.75) if boss else ()):
                    for i, v in enumerate(noise(0.03, 0.12, 1)):
                        if at(b0 + q + h) + i < total:
                            drums[at(b0 + q + h) + i] += v
            # bass: 8th notes, root / octave
            for e in range(8):
                note = chord_root - 12 + (12 if e % 2 else 0)
                add_note(bass, at(b0 + e / 2), int(eighth * RATE * 0.9), midi_hz(note), 0.22, tri, 4.0)
            # arp: 16ths over the minor triad, 2 octaves
            triad = [0, 3, 7, 12, 15, 19, 24, 19]
            for s16 in range(16):
                note = chord_root + 12 + triad[s16 % len(triad)]
                add_note(arp, at(b0 + s16 / 4), int(beat / 4 * RATE * 0.8), midi_hz(note), 0.07, pulse25, 8.0)
            # lead: pentatonic phrase per bar
            for step, idx, length in LEAD_PATTERNS[bar % len(LEAD_PATTERNS)]:
                note = root + 12 + MINOR_PENTATONIC[idx] + (chords[bar] if boss else 0)
                add_note(lead, at(b0 + step / 2), int(length * eighth * RATE * 0.95), midi_hz(note), 0.12, square, 1.5, 0.006)
        for layer, buf in (("drums", drums), ("bass", bass), ("arp", arp), ("lead", lead)):
            write_loop("%s_%s.wav" % (name, layer), buf)
    print("wrote %d music tracks x 4 layers to %s" % (len(TRACKS), os.path.normpath(MUSIC_OUT)))


if __name__ == "__main__":
    main()
