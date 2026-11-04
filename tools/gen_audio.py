#!/usr/bin/env python3
"""Процедурні звуки й музика «Спогадів пращурів» (власні, CC0) + конвертація обраних CC0-файлів Kenney.
Запуск: python3 tools/gen_audio.py /шлях/до/kenney_розпакованого  → audio/*.ogg"""
import os, sys, subprocess, tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.01, r=0.2):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e
def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band"); return lfilter(b, a, x)
def lp(x, f, o=2):
    b, a = butter(o, f / (SR / 2)); return lfilter(b, a, x)
def hp(x, f, o=2):
    b, a = butter(o, f / (SR / 2), btype="high"); return lfilter(b, a, x)
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def norm(x, p=0.9): m = np.max(np.abs(x)) or 1; return x / m * p
def pluck(f, d, damp=0.996):
    n = int(SR * d); p = max(2, int(SR / f)); buf = rng.uniform(-1, 1, p); out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]; buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out
def place(dst, src, at):
    i = int(at * SR); j = min(len(dst), i + len(src)); dst[i:j] += src[:j - i]
def loopfade(x, f=0.5):
    n = int(f * SR); x = x.copy(); x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n); return x[:-n]

def save(name, x, stereo=False, q=3):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wavfile.write(f.name, SR, (norm(x) * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f.name, "-ac", "1", "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], check=True)
        os.unlink(f.name)

def kenney(src, name):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, name + ".ogg")], check=True)

# ---------- бій ----------
def arrow():
    d = 0.35; x = bp(noise(d), 1500, 6000) * np.exp(-t(d) * 9)
    tw = np.sin(2 * np.pi * 220 * t(0.12)) * np.exp(-t(0.12) * 30) * 0.6
    place(x, tw, 0); return x
def magic_fire():
    d = 0.7; x = lp(noise(d), 900) * env(int(SR * d), 0.05, 0.4) * 2
    x += 0.3 * np.sin(2 * np.pi * (120 + 200 * t(d)) * t(d)) * np.exp(-t(d) * 3); return x
def magic_lightning():
    d = 0.6; x = np.zeros(int(SR * d))
    for k in range(14):
        place(x, hp(noise(0.02), 2000) * rng.uniform(0.3, 1), rng.uniform(0, 0.4))
    x += lp(noise(d), 200) * np.exp(-t(d) * 5) * 1.5; return x
def magic_ice():
    d = 0.8; x = np.zeros(int(SR * d))
    for f in [1760, 2093, 2637, 3136]:
        place(x, np.sin(2 * np.pi * f * t(0.5)) * np.exp(-t(0.5) * 8), rng.uniform(0, 0.25))
    x += bp(noise(d), 3000, 8000) * np.exp(-t(d) * 6) * 0.4; return x
def magic_holy():
    d = 1.0; x = np.zeros(int(SR * d))
    for i, f in enumerate([523, 659, 784, 1047]):
        place(x, np.sin(2 * np.pi * f * t(0.7)) * env(int(SR * 0.7), 0.02, 0.6) * 0.5, i * 0.07)
    return x
def magic_nature():
    d = 0.8; x = bp(noise(d), 300, 1200) * env(int(SR * d), 0.2, 0.4)
    x += 0.4 * np.sin(2 * np.pi * 330 * t(d) + 3 * np.sin(2 * np.pi * 5 * t(d))) * env(int(SR * d), 0.1, 0.5); return x
def whoosh():
    d = 0.4; s = t(d); x = bp(noise(d), 400, 2500) * np.sin(np.pi * s / d) ** 2; return x
def roar(base=70, d=1.8):
    s = t(d); f = base * (1 + 0.25 * np.sin(np.pi * s / d)) + 6 * np.sin(2 * np.pi * 9 * s)
    ph = 2 * np.pi * np.cumsum(f) / SR; x = np.sign(np.sin(ph)) * 0.5 + np.sin(2 * ph) * 0.3
    x = lp(x, 900) + lp(noise(d), 600) * 0.6; return x * env(len(s), 0.15, 0.6)
def death():
    d = 0.7; s = t(d); f = 180 * np.exp(-s * 2); ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) * 0.6 + lp(noise(d), 500) * 0.5) * np.exp(-s * 4)
def enemy_hit():
    d = 0.18; return lp(noise(d), 1400) * np.exp(-t(d) * 25) + np.sin(2 * np.pi * 110 * t(d)) * np.exp(-t(d) * 20)
def levelup():
    x = np.zeros(int(SR * 1.4))
    for i, f in enumerate([392, 494, 587, 784, 988]):
        place(x, pluck(f, 0.9, 0.998) * 0.6, i * 0.11)
    return x
def portal():
    d = 1.5; s = t(d); return np.sin(2 * np.pi * (200 + 300 * s) * s) * env(len(s), 0.2, 0.6) * 0.5 + bp(noise(d), 500, 3000) * 0.3 * env(len(s), 0.4, 0.6)
def telegraph():
    d = 0.6; s = t(d); return np.sign(np.sin(2 * np.pi * (60 + 40 * s) * s)) * 0.4 * env(len(s), 0.05, 0.2) + lp(noise(d), 300) * 0.5

# ---------- атмосфера (петлі ~24 с) ----------
L = 24.0
def wind(d, lo=150, hi=900, amt=1.0):
    s = t(d); m = 0.6 + 0.4 * np.sin(2 * np.pi * s / 7.3) * np.sin(2 * np.pi * s / 3.1)
    return bp(noise(d), lo, hi) * m * amt
def bird():
    d = rng.uniform(0.12, 0.3); s = t(d); f0 = rng.uniform(2500, 4200)
    f = f0 + rng.uniform(-900, 900) * np.sin(np.pi * s / d) + 200 * np.sin(2 * np.pi * 30 * s)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(s), 0.01, 0.05)
def frog():
    x = np.zeros(int(SR * 0.6)); f = rng.uniform(110, 190)
    for k in range(rng.integers(2, 5)):
        s = t(0.09); place(x, np.sign(np.sin(2 * np.pi * f * s)) * np.exp(-s * 25) * 0.6 + np.sin(2 * np.pi * f * 2 * s) * np.exp(-s * 30) * 0.3, k * 0.12)
    return lp(x, 1200)
def drip():
    d = 0.25; s = t(d); f = rng.uniform(900, 1700) * (1 + 0.6 * np.exp(-s * 30))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-s * 22)
def rooster():
    x = np.zeros(int(SR * 1.6)); seg = [(0.0, 0.12, 700, 900), (0.16, 0.12, 900, 1000), (0.32, 0.18, 1000, 1150), (0.55, 0.7, 1150, 800)]
    for at, d, a, b in seg:
        s = t(d); f = np.linspace(a, b, len(s)) + 25 * np.sin(2 * np.pi * 40 * s); ph = 2 * np.pi * np.cumsum(f) / SR
        place(x, (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)) * env(len(s), 0.02, 0.06), at)
    return bp(x, 500, 4000) * 0.5
def murmur(d):
    x = np.zeros(int(SR * d))
    for k in range(int(d * 6)):
        n = rng.uniform(0.15, 0.4); s = t(n); f = rng.uniform(110, 220) * (1 + 0.1 * np.sin(2 * np.pi * 4 * s))
        v = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)); place(x, bp(v, 300, 1500) * env(len(s), 0.04, 0.1) * rng.uniform(0.1, 0.3), rng.uniform(0, d - n))
    return lp(x, 1600)
def amb(kind):
    d = L + 0.5; x = np.zeros(int(SR * d))
    if kind == "village":
        x += wind(d, 200, 700, 0.15) + murmur(d) * 0.8
        for at in [3.0, 15.5]: place(x, rooster(), at)
        for k in range(6): place(x, bird() * 0.15, rng.uniform(0, d - 1))
    elif kind == "forest":
        x += wind(d, 200, 1200, 0.35)
        for k in range(40): place(x, bird() * rng.uniform(0.1, 0.35), rng.uniform(0, d - 1))
    elif kind == "swamp":
        x += wind(d, 100, 400, 0.15) + bp(noise(d), 2000, 5000) * 0.02
        for k in range(28): place(x, frog() * rng.uniform(0.2, 0.6), rng.uniform(0, d - 1))
    elif kind == "ruins":
        x += wind(d, 250, 1400, 0.8) + wind(d, 600, 2200, 0.2)
    elif kind == "steppe":
        x += wind(d, 150, 1000, 0.55)
        for k in range(10): place(x, bird() * 0.1, rng.uniform(0, d - 1))
    elif kind == "cave":
        x += lp(noise(d), 120) * 0.25
        for k in range(18): place(x, drip() * rng.uniform(0.2, 0.6), rng.uniform(0, d - 1))
    return loopfade(x)

# ---------- музика ----------
def music_calm():
    bpm = 72; beat = 60 / bpm; bars = 16; d = bars * 4 * beat + 0.5; x = np.zeros(int(SR * d))
    D = 146.83; scale = [1, 9/8, 6/5, 4/3, 3/2, 8/5, 9/5, 2]   # ре мінор (дорійський відтінок)
    s = t(d); x += (np.sin(2 * np.pi * D / 2 * s) * 0.18 + np.sin(2 * np.pi * D * 3 / 4 * s) * 0.08) * (0.8 + 0.2 * np.sin(2 * np.pi * s / 8))
    mel = [0, 2, 4, 3, 2, 0, 1, 0, 4, 5, 4, 2, 3, 2, 1, 0]
    for b in range(bars):
        root = mel[b]
        for k in range(4):
            deg = [0, 4, 7, 4][k]; f = D * scale[(root + [0, 2, 4, 2][k]) % 8] * (2 if k == 2 else 1)
            place(x, pluck(f * 2, beat * 2, 0.997) * 0.35, (b * 4 + k) * beat)
        if b % 2 == 0:
            place(x, pluck(D * scale[root] * 4, beat * 3, 0.998) * 0.25, (b * 4 + 1.5) * beat)
    return loopfade(lp(x, 4000))
def music_combat():
    bpm = 128; beat = 60 / bpm; bars = 8; d = bars * 4 * beat + 0.3; x = np.zeros(int(SR * d))
    A = 110.0
    def drum(f, dd, nz):
        s = t(dd); return np.sin(2 * np.pi * f * np.exp(-s * 8) * s) * np.exp(-s * 10) + lp(noise(dd), 3000) * np.exp(-s * 30) * nz
    for b in range(bars * 4):
        place(x, drum(70, 0.4, 0.2) * 0.9, b * beat)
        if b % 2 == 1: place(x, drum(180, 0.25, 0.6) * 0.5, b * beat)
        place(x, drum(400, 0.08, 1.0) * 0.15, (b + 0.5) * beat)
    seq = [0, 0, 3, 0, 5, 0, 3, 2] * 4
    sc = [1, 9/8, 6/5, 4/3, 3/2, 8/5, 9/5]
    for i, deg in enumerate(seq):
        f = A * sc[deg % 7]; s = t(beat * 0.9); ph = 2 * np.pi * f * s
        place(x, lp((2 * ((f * s) % 1) - 1) * 0.3, 900) * np.exp(-s * 3), i * beat)
    for b in range(bars):
        f = A * 2 * sc[[0, 3, 5, 4][b % 4]]; s = t(beat * 4)
        place(x, np.sin(2 * np.pi * f * s + 2 * np.sin(2 * np.pi * 5 * s)) * env(len(s), 0.3, 0.5) * 0.15, b * 4 * beat)
    return loopfade(x, 0.25)

if __name__ == "__main__":
    K = sys.argv[1] if len(sys.argv) > 1 else "/workspace/audio_src"
    os.makedirs(OUT, exist_ok=True)
    gen = {"sfx_arrow": arrow, "sfx_magic_fire": magic_fire, "sfx_magic_lightning": magic_lightning, "sfx_magic_ice": magic_ice,
           "sfx_magic_holy": magic_holy, "sfx_magic_nature": magic_nature, "sfx_whoosh": whoosh, "sfx_roar": roar,
           "sfx_roar_big": lambda: roar(48, 2.6), "sfx_death": death, "sfx_enemy_hit": enemy_hit, "sfx_levelup": levelup,
           "sfx_portal": portal, "sfx_telegraph": telegraph}
    for n, f in gen.items(): save(n, f())
    for k in ["village", "forest", "swamp", "ruins", "steppe", "cave"]: save("amb_" + k, amb(k), q=1)
    save("music_calm", music_calm(), q=2)
    save("music_combat", music_combat(), q=2)
    km = {"sfx_hit_melee": "impact-sounds/Audio/impactPunch_medium_000.ogg", "sfx_hit_metal": "impact-sounds/Audio/impactMetal_medium_000.ogg",
          "sfx_player_hurt": "impact-sounds/Audio/impactSoft_heavy_000.ogg", "sfx_click": "interface-sounds/Audio/click_002.ogg",
          "sfx_coins": "rpg-audio/Audio/handleCoins.ogg", "sfx_pickup": "rpg-audio/Audio/handleSmallLeather.ogg",
          "sfx_equip": "rpg-audio/Audio/cloth2.ogg", "sfx_chest": "rpg-audio/Audio/doorOpen_1.ogg", "sfx_slash": "rpg-audio/Audio/knifeSlice.ogg",
          "sfx_open": "interface-sounds/Audio/open_001.ogg", "sfx_close": "interface-sounds/Audio/close_001.ogg",
          "sfx_quest": "music-jingles/Audio/Pizzicato jingles/jingles_PIZZI08.ogg"}
    for n, p in km.items(): kenney(os.path.join(K, p), n)
    print("ok", len(os.listdir(OUT)))
