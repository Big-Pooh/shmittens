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
    # skills, boss warning, rewards, perfect-click tick
    write("shockwave.wav", mix(sweep(0.5, 180, 40, 0.3, tri, 1.2), noise(0.5, 0.25, 6)))
    write("laser.wav", mix(sweep(0.45, 1600, 1200, 0.15, square, 0.8), sweep(0.45, 400, 380, 0.1, tri, 0.8)))
    write("lightning.wav", mix(noise(0.35, 0.35, 1), sweep(0.35, 2400, 300, 0.08)))
    write("shield.wav", sum((sweep(0.09, f, f, 0.18, tri, 0.3) for f in (392, 523, 659, 784)), []))
    siren = []
    for k in range(3):
        siren += sweep(0.25, 500, 900, 0.18, tri, 0.1) + sweep(0.25, 900, 500, 0.18, tri, 0.1)
    write("siren.wav", siren)
    write("jingle.wav", sum((sweep(0.08, f, f, 0.2, square, 0.6) for f in (784, 988, 1175, 1568)), []))
    write("perfect.wav", sweep(0.06, 2093, 2093, 0.15, tri, 3.0))
    # spell-chain stings: rising pentatonic notes (A minor), one per chain link
    for i, semis in enumerate([0, 3, 7, 12]):
        f = 440.0 * 2 ** (semis / 12.0)
        write("chain_%d.wav" % (i + 1), mix(sweep(0.25, f, f, 0.18, tri, 1.2), sweep(0.25, f * 2, f * 2, 0.06, square, 2.0)))
    # playtest 2: weapons, beat armour, dance break
    write("shoot_laser.wav", sweep(0.08, 2600, 1900, 0.14, square, 2.0))
    write("shoot_fish.wav", sweep(0.1, 700, 1100, 0.14, tri, 1.5))
    write("weapon_switch.wav", sweep(0.05, 1200, 1200, 0.15, square, 1.0) + sweep(0.06, 1600, 1600, 0.15, square, 1.0))
    write("armor_ping.wav", sweep(0.12, 2400, 2300, 0.12, tri, 6.0))
    write("armor_crack.wav", mix(sweep(0.18, 1500, 700, 0.18, square, 3.0), noise(0.12, 0.2, 3)))
    write("armor_break.wav", mix(sweep(0.5, 900, 120, 0.25, square, 1.0), noise(0.5, 0.3, 4)))
    write("dance.wav", sweep(0.07, 1319, 1319, 0.16, tri, 2.0))
    write_meows()
    print("wrote sounds to %s" % os.path.normpath(OUT))
    write_music()



# ---------------------------------------------------------------- meows (playtest 7)
# Recipe from the design review: a sawtooth source with a pitch contour (rise ~1.5x in the first
# 40%, fall to ~0.8x, 5 Hz vibrato), shaped by two band-pass "formants" sweeping ee -> a -> oo
# (F1 400 -> 900 -> 500 Hz, F2 2200 -> 1500 -> 900 Hz), plus a little breath noise.
# Base pitch is tuned to A (the game pitches it to each song's key at runtime).

def _bandpass_run(x, centers, q=4.0):
    """Time-varying 2-pole band-pass (RBJ biquad), coefficients updated every 32 samples."""
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    b0 = b2 = a1 = a2 = 0.0
    for i, v in enumerate(x):
        if i % 32 == 0:
            f = centers(i / len(x))
            w = 2 * math.pi * f / RATE
            alpha = math.sin(w) / (2 * q)
            a0 = 1 + alpha
            b0, b2 = alpha / a0, -alpha / a0
            a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
        y = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, y
        out[i] = y
    return out


def _lerp3(a, b, c, t):
    return a + (b - a) * (t / 0.4) if t < 0.4 else b + (c - b) * ((t - 0.4) / 0.6)


def meow(seconds=0.36, f0=700.0, rise=1.5, fall=0.8, noise_amt=0.05, vol=0.5, trill=0.0, seed=1):
    rnd = random.Random(seed)
    n = int(seconds * RATE)
    src, ph = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 * _lerp3(1.0, rise, fall, t) * (1 + 0.02 * math.sin(2 * math.pi * 5 * i / RATE))
        ph += f / RATE
        saw = 2 * (ph % 1.0) - 1
        src.append(saw + noise_amt * (rnd.random() * 2 - 1))
    f1 = _bandpass_run(src, lambda t: _lerp3(400, 900, 500, t), 3.0)
    f2 = _bandpass_run(src, lambda t: _lerp3(2200, 1500, 900, t), 5.0)
    out = []
    att, rel = int(0.015 * RATE), int(0.12 * RATE)
    for i in range(n):
        env = min(1.0, i / att) * min(1.0, (n - i) / rel)
        if trill:
            env *= 0.6 + 0.4 * math.sin(2 * math.pi * trill * i / RATE)
        out.append((f1[i] * 1.0 + f2[i] * 0.6) * env * vol * 3.0)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * vol for v in out]


def write_meows():
    variants = [
        dict(seconds=0.34, f0=700, rise=1.5, fall=0.8),
        dict(seconds=0.30, f0=760, rise=1.4, fall=0.85),
        dict(seconds=0.40, f0=660, rise=1.6, fall=0.75),
        dict(seconds=0.26, f0=820, rise=1.3, fall=0.9),
        dict(seconds=0.38, f0=720, rise=1.55, fall=0.7),
    ]
    for k, v in enumerate(variants):
        write("meow_%d.wav" % (k + 1), meow(seed=k + 1, **v))
    write("mrrp.wav", meow(seconds=0.22, f0=520, rise=1.15, fall=0.95, trill=28.0, noise_amt=0.08, seed=9))
    write("meow_growl.wav", meow(seconds=0.55, f0=380, rise=1.35, fall=0.7, noise_amt=0.18, vol=0.55, seed=11))


# ---------------------------------------------------------------- music

MUSIC_OUT = os.path.join(OUT, "Music")
BARS = 32   # sprint 1: arranged tracks (intro 4, A 8, B 8, bridge 4, A' 8) instead of a 4-bar loop
BEATS_PER_BAR = 4

# name: (bpm, root midi note, chord roots as semitones from root, minor scale lead pattern)
TRACKS = {
    "level1": (92, 57, [0, -4, 3, -2]),   # A minor: Am F C G
    "level2": (104, 50, [0, -4, 3, -2]),   # D minor: Dm Bb F C
    "level3": (116, 52, [0, -4, -2, 0]),   # E minor: Em C D Em
    "boss1": (100, 57, [0, 1, 0, -1]),     # tense: i bII i VII
    "boss2": (112, 50, [0, 1, -2, -5]),
    "level4": (120, 53, [0, -4, -5, -2]),   # F minor: Fm Db C Eb
    "boss4": (128, 53, [0, 1, -1, 1]),     # final boss: tense half-steps
    "level5": (108, 55, [0, -4, -2, 3]),   # G minor
    "boss5": (116, 55, [0, 1, -2, 1]),
    "level6": (124, 48, [0, 3, -2, 5]),    # C minor, disco
    "boss6": (132, 48, [0, 3, 5, -2]),
    "level7": (112, 50, [0, -5, -2, -4]),  # D minor, icy
    "boss7": (120, 50, [0, 1, -5, 1]),
    "level8": (128, 53, [0, -4, 3, 5]),    # F minor, heroic finale
    "boss8": (136, 53, [0, 1, 3, 1]),
    "boss3": (124, 52, [0, 1, 3, -1]),
}
MINOR_PENTATONIC = [0, 3, 5, 7, 10, 12, 15, 17]
# Presentation pass: every PLANET has its own lead motif (4 bars), and its BOSS track plays a
# variation of the same motif (one scale step higher, last bar answered), so you can tell the
# planets apart and the boss sounds like "its" planet. (step in 8ths, scale index, length in 8ths)
MOTIFS = {
    "level1": [  # Mousetronica: bouncy, call-and-response
        [(0, 2, 1), (1, 4, 1), (2, 5, 2), (4, 4, 2), (6, 2, 2)],
        [(0, 3, 2), (2, 2, 1), (3, 1, 1), (4, 0, 4)],
        [(0, 2, 1), (1, 4, 1), (2, 5, 2), (4, 6, 2), (6, 5, 2)],
        [(0, 4, 3), (3, 2, 1), (4, 1, 2), (6, 0, 2)],
    ],
    "level2": [  # Drainia: drippy syncopation
        [(1, 4, 1), (2, 3, 2), (5, 2, 1), (6, 3, 2)],
        [(0, 1, 3), (3, 2, 1), (5, 0, 3)],
        [(1, 5, 1), (2, 4, 2), (5, 3, 1), (6, 4, 2)],
        [(0, 2, 2), (2, 1, 2), (4, 0, 4)],
    ],
    "level3": [  # Ratopolis: regal fanfare, long notes
        [(0, 0, 2), (2, 2, 2), (4, 4, 4)],
        [(0, 5, 2), (2, 4, 2), (4, 2, 4)],
        [(0, 0, 2), (2, 2, 2), (4, 4, 2), (6, 6, 2)],
        [(0, 7, 4), (4, 4, 4)],
    ],
    "level4": [  # Flexor: driving 8ths, heroic climb
        [(0, 0, 1), (1, 0, 1), (2, 3, 1), (3, 4, 1), (4, 5, 2), (6, 4, 2)],
        [(0, 3, 1), (1, 3, 1), (2, 5, 1), (3, 6, 1), (4, 7, 4)],
        [(0, 0, 1), (1, 0, 1), (2, 3, 1), (3, 4, 1), (4, 5, 2), (6, 7, 2)],
        [(0, 6, 2), (2, 5, 2), (4, 4, 2), (6, 3, 2)],
    ],
    "level5": [  # Cheddaria: rolling, sunny
        [(0, 4, 2), (2, 5, 1), (3, 4, 1), (4, 2, 2), (6, 4, 2)],
        [(0, 5, 2), (2, 6, 2), (4, 5, 4)],
        [(0, 4, 2), (2, 5, 1), (3, 6, 1), (4, 7, 2), (6, 5, 2)],
        [(0, 4, 3), (3, 2, 1), (4, 1, 4)],
    ],
    "level6": [  # Neon Nibble: syncopated disco hook
        [(0, 3, 1), (1, 3, 1), (3, 5, 1), (4, 6, 1), (6, 5, 2)],
        [(1, 4, 1), (2, 3, 1), (3, 4, 1), (4, 2, 4)],
        [(0, 3, 1), (1, 3, 1), (3, 5, 1), (4, 7, 1), (6, 6, 2)],
        [(0, 5, 2), (2, 4, 2), (4, 3, 1), (5, 2, 1), (6, 0, 2)],
    ],
    "level7": [  # Frostwhisker: crystalline, high and sparse
        [(0, 7, 2), (4, 6, 2), (6, 5, 2)],
        [(0, 4, 4), (4, 5, 4)],
        [(0, 7, 2), (2, 6, 1), (3, 7, 1), (4, 5, 4)],
        [(0, 3, 2), (2, 4, 2), (4, 2, 4)],
    ],
    "level8": [  # Mount Flexmore: the world-1 Flexor motif, climbed higher
        [(0, 2, 1), (1, 2, 1), (2, 4, 1), (3, 5, 1), (4, 6, 2), (6, 5, 2)],
        [(0, 4, 1), (1, 4, 1), (2, 6, 1), (3, 7, 1), (4, 7, 4)],
        [(0, 2, 1), (1, 2, 1), (2, 4, 1), (3, 5, 1), (4, 6, 2), (6, 7, 2)],
        [(0, 7, 2), (2, 6, 2), (4, 5, 2), (6, 4, 2)],
    ],
}


def boss_variation(motif):
    """Same motif one scale step up; the last bar answers with the first bar descending."""
    up = [[(s, min(i + 1, 7), l) for s, i, l in bar] for bar in motif]
    up[3] = [(s, max(7 - i, 0), l) for s, i, l in motif[0]]
    return up


for _n in (1, 2, 3, 4, 5, 6, 7, 8):
    MOTIFS["boss%d" % _n] = boss_variation(MOTIFS["level%d" % _n])

LEAD_PATTERNS = [  # (kept for reference: the original shared motif)
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


# --- arrangement (sprint 1) ----------------------------------------------------------------
SECTIONS = [("intro", 4), ("A", 8), ("B", 8), ("bridge", 4), ("A2", 8)]


def section_of(bar):
    b = bar
    for name, length in SECTIONS:
        if b < length:
            return name, b
        b -= length
    return "A2", 0


def arranged_lead(name):
    """The lead melody for all 32 bars: motif in A, inverted/lifted in B, long notes in the
    bridge, an octave-lifted motif in A2, nothing in the intro."""
    motif = MOTIFS.get(name, LEAD_PATTERNS)
    out = []
    for bar in range(BARS):
        sec, k = section_of(bar)
        m = motif[k % 4]
        if sec == "intro":
            out.append([])
        elif sec == "A":
            out.append(list(m))
        elif sec == "B":
            out.append([(st, min(7, max(0, 7 - i + (1 if k >= 4 else 0))), ln) for st, i, ln in m])
        elif sec == "bridge":
            out.append([(0, m[0][1], 4), (4, m[-1][1], 4)])
        else:
            out.append([(st, min(7, i + (2 if k >= 4 else 1)), ln) for st, i, ln in m])
    return out


def chords_for(chords, bar):
    sec, k = section_of(bar)
    if sec == "B":
        return chords[(k + 1) % 4] + 3
    if sec == "bridge":
        return [chords[0], chords[2], chords[0], chords[3]][k % 4]
    return chords[k % 4]


_cache = {}


def cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def stamp(buf, start, samples, gain=1.0):
    n = min(len(samples), len(buf) - start)
    for i in range(n):
        buf[start + i] += samples[i] * gain


def note_samples(length, freq, vol, wave_fn, decay=3.0, vibrato=0.0):
    out = [0.0] * length
    add_note(out, 0, length, freq, vol, wave_fn, decay, vibrato)
    return out


def write_music():
    os.makedirs(MUSIC_OUT, exist_ok=True)
    for name, (bpm, root, chords) in TRACKS.items():
        beat = 60.0 / bpm
        total = int(round(BARS * BEATS_PER_BAR * beat * RATE))
        eighth = beat / 2
        drums, bass, arp, lead = ([0.0] * total for _ in range(4))
        at = lambda beats: int(round(beats * beat * RATE))
        boss = name.startswith("boss")
        kick = cached("kick", lambda: sweep(0.16, 130, 40, 0.55, sine, 2.0))
        snare = cached("snare", lambda: noise(0.14, 0.32, 2))
        hat = cached("hat", lambda: noise(0.03, 0.12, 1))
        lead_bars = arranged_lead(name)
        for bar in range(BARS):
            sec, k = section_of(bar)
            b0 = bar * BEATS_PER_BAR
            chord_root = root + chords_for(chords, bar)
            # drums: four-on-the-floor (half-time in the bridge, kick only + hats in the intro)
            for q in range(BEATS_PER_BAR):
                if sec != "bridge" or q in (0, 2):
                    stamp(drums, at(b0 + q), kick)
                if q in (1, 3) and sec != "intro":
                    stamp(drums, at(b0 + q), snare)
                hats = (0.5,) + ((0.25, 0.75) if boss or sec in ("B", "A2") else ())
                for h in hats:
                    stamp(drums, at(b0 + q + h), hat)
            if sec in ("A", "B", "A2") and k % 4 == 3:   # snare fill closing each phrase
                for f in (2.5, 3.25, 3.5, 3.75):
                    stamp(drums, at(b0 + f), snare, 0.7)
            if boss and sec == "A2":   # bosses build: double kicks at the climax
                for q in range(BEATS_PER_BAR):
                    stamp(drums, at(b0 + q + 0.5), kick, 0.6)
            # bass: 8ths root/octave; whole notes in the bridge; quiet in the intro
            if sec == "bridge":
                stamp(bass, at(b0), cached(("bw", chord_root, bpm), lambda: note_samples(int(4 * beat * RATE * 0.95), midi_hz(chord_root - 12), 0.24, tri, 0.6)))
            elif sec != "intro" or k >= 2:
                for e in range(8):
                    note = chord_root - 12 + (12 if e % 2 else 0) + (7 if sec == "B" and e in (6, 7) else 0)
                    stamp(bass, at(b0 + e / 2), cached(("b8", note, bpm), lambda: note_samples(int(eighth * RATE * 0.9), midi_hz(note), 0.22, tri, 4.0)))
            # arp: 16ths over the minor triad (an octave up in the bridge, every other 16th in the intro)
            triad = [0, 3, 7, 12, 15, 19, 24, 19] if sec != "B" else [0, 4, 7, 12, 16, 19, 24, 19]
            for s16 in range(16):
                if sec == "intro" and s16 % 2:
                    continue
                note = chord_root + 12 + triad[s16 % len(triad)] + (12 if sec == "bridge" else 0)
                stamp(arp, at(b0 + s16 / 4), cached(("a", note, bpm), lambda: note_samples(int(beat / 4 * RATE * 0.8), midi_hz(note), 0.07, pulse25, 8.0)))
            # lead
            for step, idx, length in lead_bars[bar]:
                note = root + 12 + MINOR_PENTATONIC[idx] + (chords_for(chords, bar) if boss else 0)
                stamp(lead, at(b0 + step / 2), cached(("l", note, length, bpm), lambda: note_samples(int(length * eighth * RATE * 0.95), midi_hz(note), 0.12, square, 1.5, 0.006)))
        for layer, buf in (("drums", drums), ("bass", bass), ("arp", arp), ("lead", lead)):
            write_loop("%s_%s.wav" % (name, layer), buf)
        print("  track", name, "done", flush=True)
    print("wrote %d music tracks x 4 layers to %s" % (len(TRACKS), os.path.normpath(MUSIC_OUT)))
    write_patterns()


def write_patterns():
    """Writes scripts/music_patterns.gd so gameplay can follow each track's lead melody."""
    path = os.path.join(os.path.dirname(__file__), "..", "scripts", "music_patterns.gd")
    with open(path, "w") as f:
        f.write("# GENERATED by tools/gen_audio.py - do not edit by hand.\n")
        f.write("# Lead melody per track: per bar, a list of [step in 8th notes, scale index, length in 8ths].\n")
        f.write("# Bosses fire on these notes (see Conductor.lead_note).\n")
        f.write("class_name MusicPatterns\n\n")
        f.write("const BARS = %d\n" % BARS)
        f.write("const SCALE_STEPS = %d\n" % len(MINOR_PENTATONIC))
        f.write("const BY_TRACK = {\n")
        for name in TRACKS:
            bars = ["[" + ", ".join("[%d, %d, %d]" % n for n in bar) + "]" for bar in arranged_lead(name)]
            f.write('\t"%s": [%s],\n' % (name, ", ".join(bars)))
        f.write("}\n")
        f.write("const LEAD = BY_TRACK[\"level1\"]   # default / tests\n\n\n")
        f.write("static func lead(track: String) -> Array:\n\treturn BY_TRACK.get(track, LEAD)\n")
    print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
