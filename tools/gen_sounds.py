#!/usr/bin/env python3
"""Generate the placeholder sound effects (16-bit mono WAV) into game/sounds/.
Pure synthesis (numpy); no external assets. Re-run to regenerate:  python3 tools/gen_sounds.py"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "sounds")
rng = np.random.default_rng(7)


def t(d): return np.linspace(0, d, int(SR * d), endpoint=False)
def env(n, a=0.005, decay=6.0):
    x = np.linspace(0, 1, n)
    atk = np.minimum(1, x / max(a, 1e-4) * (n / SR) ** -1 * 0 + x / (a / (n / SR)))
    return np.minimum(1, x / (a / (n / SR))) * np.exp(-decay * x)
def noise(n): return rng.uniform(-1, 1, n)
def lowpass(x, k):
    out = np.copy(x); a = k
    for i in range(1, len(x)): out[i] = out[i - 1] + a * (x[i] - out[i - 1])
    return out
def sweep(f0, f1, d):
    tt = t(d); f = np.linspace(f0, f1, len(tt))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def tone(f, d): return np.sin(2 * np.pi * f * t(d))

def save(name, x, gain=0.8):
    x = x / max(1e-6, np.max(np.abs(x))) * gain
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

def E(x, a=0.004, decay=6.0): return x * env(len(x), a, decay)

# ---- weapons
save("laser_light", E(sweep(1800, 500, 0.16) + 0.25 * noise(int(SR * .16)) * 0.3, decay=5))
save("laser_heavy", E(sweep(900, 140, 0.42) + 0.5 * sweep(1800, 280, 0.42), decay=4))
save("gun",         E(lowpass(noise(int(SR * .10)), 0.5) + 0.6 * tone(120, .10), decay=9))
save("cannon",      E(lowpass(noise(int(SR * .22)), 0.25) + 0.9 * sweep(180, 60, .22), decay=7))
save("boom_mortar", E(lowpass(noise(int(SR * .55)), 0.12) + 0.8 * sweep(120, 35, .55), a=0.01, decay=5))
save("impact",      E(lowpass(noise(int(SR * .07)), 0.6), decay=10))
# ---- explosions
save("explo_small",  E(lowpass(noise(int(SR * .45)), 0.2), a=0.003, decay=6))
save("explo_medium", E(lowpass(noise(int(SR * .8)), 0.14) + 0.4 * sweep(110, 40, .8), a=0.004, decay=4.5))
save("explo_large",  E(lowpass(noise(int(SR * 1.6)), 0.09) + 0.7 * sweep(90, 28, 1.6), a=0.006, decay=3.2))
# ---- UI / unit
save("select",   E(tone(880, .07) + 0.5 * tone(1320, .07), decay=5), 0.5)
save("ok",       E(np.concatenate([tone(660, .06), tone(990, .08)]), decay=3), 0.5)
save("cant",     E(np.sign(tone(110, .22)) * 0.6 + 0.3 * tone(165, .22), decay=3), 0.5)
save("complete", E(np.concatenate([tone(523, .09), tone(659, .09), tone(784, .16)]), decay=2.2), 0.6)
save("blink",    E(sweep(300, 2400, .28) * 0.8 + 0.3 * lowpass(noise(int(SR * .28)), 0.5), a=0.02, decay=3.5), 0.7)
save("levelup",  E(np.concatenate([tone(f, .1) for f in (523, 659, 784, 1047)]), decay=1.6), 0.7)
save("power_off",E(sweep(700, 90, .5), decay=3), 0.6)
save("power_on", E(sweep(120, 900, .4), a=0.02, decay=2.5), 0.6)
print("wrote", len(os.listdir(OUT)), "sounds to", os.path.abspath(OUT))
