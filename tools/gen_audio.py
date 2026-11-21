#!/usr/bin/env python3
"""Generates placeholder sound effects in Audio/ (retro synth beeps).

Run from the project root:  python3 tools/gen_audio.py
Music loops get added here on Day 2.
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


if __name__ == "__main__":
    main()
