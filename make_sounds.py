"""Barbut ses dosyalarını sıfırdan üretir (dosya indirmez, kayıt kullanmaz).

Çalıştırma:  python tool/make_sounds.py
Çıktı:       assets/sounds/*.wav  (44.1 kHz, mono, 16 bit)
"""
import os
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
rng = np.random.default_rng(1453)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
os.makedirs(OUT, exist_ok=True)

HICAZ = [293.66, 311.13, 369.99, 392.0, 440.0, 466.16, 523.25, 587.33]


def buf(sec):
    return np.zeros(int(SR * sec))


def env(n, att, rel_curve=6.0):
    """Hızlı yükselen, üstel sönen zarf."""
    a = max(1, int(SR * att))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    t = np.linspace(0, 1, n - a)
    e[a:] = np.exp(-rel_curve * t)
    return e


def band(x, lo, hi, order=2):
    lo = max(20, lo)
    hi = min(SR / 2 - 100, hi)
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def add(dst, src, at, gain=1.0):
    i = int(at * SR)
    if i >= len(dst):
        return
    n = min(len(src), len(dst) - i)
    dst[i:i + n] += src[:n] * gain


def noise_burst(dur, f, q=2.0, att=0.002, curve=6.0):
    n = int(SR * dur)
    x = rng.uniform(-1, 1, n)
    bw = f / q
    return band(x, f - bw / 2, f + bw / 2) * env(n, att, curve) * 3


def sine(dur, f0, f1=None, att=0.005, curve=6.0, vib=0.0, vib_depth=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = np.full(n, f0) if f1 is None else f0 * (f1 / f0) ** (t / dur)
    if vib:
        f = f + np.sin(2 * np.pi * vib * t) * vib_depth
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(n, att, curve)


def impulse_response(sec=3.0, decay=2.6):
    n = int(SR * sec)
    t = np.linspace(0, 1, n)
    ir = rng.uniform(-1, 1, n) * (1 - t) ** decay
    ir[: int(SR * 0.012)] *= np.linspace(0, 1, int(SR * 0.012))
    ir = lowpass(ir, 5200)
    return ir / np.sqrt(np.sum(ir ** 2))


IR = impulse_response()


def verb(dry, wet=0.45):
    w = fftconvolve(dry, IR)[: len(dry)]
    return dry + w * wet


def bone_click(gain=1.0, pitch=1.0):
    """Kemik zarın sert yüzeye çarpması: tiz tık + kısa rezonans + gövde."""
    x = buf(0.12)
    add(x, noise_burst(0.045, 3100 * pitch + rng.uniform(-300, 300), q=2.2, curve=9), 0, 0.42)
    add(x, sine(0.07, 1650 * pitch + rng.uniform(-150, 150), curve=8), 0, 0.12)
    add(x, sine(0.06, 170, 90, curve=7), 0, 0.22)
    return x * gain


def bell(dur, f, gain):
    x = buf(dur)
    for m, a in [(1, 1), (2.76, 0.45), (5.4, 0.22), (8.93, 0.1)]:
        add(x, sine(dur, f * m, att=0.003, curve=4.5 * (m * 0.6 + 0.4)), 0, gain * a)
    return x


def gong(dur, f, gain):
    x = buf(dur)
    for m, a in [(1, 1), (1.47, 0.6), (2.09, 0.4), (2.56, 0.3), (3.3, 0.15)]:
        add(x, sine(dur, f * m, f * m * 0.985, att=0.02, curve=3.2), 0, gain * a)
    add(x, lowpass(rng.uniform(-1, 1, int(SR * 0.25)), 600) * env(int(SR * 0.25), 0.002, 8), 0, 0.5 * gain)
    return x


def ney(dur, f, gain):
    x = buf(dur + 0.1)
    add(x, lowpass(sine(dur, f, att=0.22, curve=3, vib=5.2, vib_depth=f * 0.012), 1800), 0, gain)
    add(x, lowpass(sine(dur, f * 2, att=0.3, curve=3), 2400), 0, gain * 0.18)
    n = int(SR * dur)
    add(x, band(rng.uniform(-1, 1, n), f * 1.6, f * 2.6) * env(n, 0.2, 3) * 2, 0, gain * 0.25)
    return x


def master(x, peak=0.89):
    x = np.tanh(x * 1.2)  # yumuşak sıkıştırma
    fade = int(SR * 0.03)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x, peak=0.89):
    x = master(x, peak)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print(name, f"{len(x) / SR:.2f}s")


# --- kupada tek tıkırtı (sallarken) ---
for i in range(1, 5):
    x = buf(0.35)
    for k in range(rng.integers(1, 3)):
        at = k * 0.022 + rng.uniform(0, 0.01)
        add(x, noise_burst(0.03, rng.uniform(2400, 4200), q=5, curve=10), at, 0.22)
        add(x, sine(0.04, rng.uniform(1000, 1600), curve=9), at, 0.06)
    add(x, band(rng.uniform(-1, 1, len(x)), 900, 1700) * env(len(x), 0.01, 12), 0, 0.05)
    save(f"tick_{i}.wav", verb(x, 0.25), peak=0.7)

# --- düğmeyle atış: def vuruşu + uğultu + kupada çalkalama (0.64 sn) ---
for i in range(1, 3):
    x = buf(1.6)
    for f, g, typ in [(55, 0.07, 0), (82.41, 0.07, 0), (110, 0.03, 1)]:
        s = sine(1.6, f, att=0.6, curve=2.5)
        add(x, lowpass(s, 400), 0, g)
    add(x, sine(0.55, 150, 46, curve=5), 0, 0.75)
    add(x, lowpass(rng.uniform(-1, 1, int(SR * 0.07)), 900) * env(int(SR * 0.07), 0.002, 8), 0, 0.35)
    bed = band(rng.uniform(-1, 1, int(SR * 0.65)), 900, 1800) * env(int(SR * 0.65), 0.2, 3) * 2
    add(x, bed, 0.05, 0.05)
    for _ in range(16):
        at = 0.06 + rng.uniform(0, 0.58)
        add(x, noise_burst(0.03, rng.uniform(2400, 4200), q=5, curve=10), at, rng.uniform(0.18, 0.28))
        add(x, sine(0.04, rng.uniform(1000, 1600), curve=9), at, 0.05)
    save(f"cup_{i}.wav", verb(x, 0.5))

# --- savruluş + tepside sekmeler (t=0 savruluş, ilk çarpma 0.22 sn) ---
HITS = [0.22, 0.46, 0.66, 0.80, 0.90, 0.96]
AMPS = [1, 0.7, 0.5, 0.34, 0.22, 0.12]
for i in range(1, 4):
    x = buf(2.0)
    n = int(SR * 0.3)
    wh = rng.uniform(-1, 1, n)
    sweep = np.zeros(n)
    # basit süpürülen bant: parçalı filtre
    seg = n // 8
    for s in range(8):
        f = 400 * (3200 / 400) ** (s / 7)
        sweep[s * seg:(s + 1) * seg] = band(wh, f * 0.7, f * 1.3)[s * seg:(s + 1) * seg]
    add(x, sweep * env(n, 0.12, 4) * 2, 0, 0.18)
    for die, off in [(0, 0.0), (1, 0.035)]:
        for h, a in zip(HITS, AMPS):
            at = h + off + (rng.uniform(0, 0.02) if die else 0)
            add(x, bone_click(a, pitch=1.0 + die * 0.07 + rng.uniform(-0.05, 0.05)), at)
    save(f"throw_{i}.wav", verb(x, 0.55))

# --- sonuç sesleri ---
x = buf(4.2)
for k, n in enumerate([0, 2, 3, 4, 7]):
    add(x, bell(2.2, HICAZ[n] * 2, 0.09), k * 0.075)
add(x, bell(3.6, HICAZ[7] * 2, 0.12), 0.45)
add(x, gong(3.0, 98, 0.18), 0)
sh = highpass(rng.uniform(-1, 1, int(SR * 1.6)), 7000) * env(int(SR * 1.6), 0.3, 3)
add(x, sh, 0.4, 0.05)
save("win.wav", verb(x, 0.7))

x = buf(5.0)
add(x, gong(4.5, 61.7, 0.42), 0)
for k, n in enumerate([7, 6, 4, 2, 1, 0]):
    add(x, ney(1.8 if k == 5 else 0.32, HICAZ[n] / 2, 0.11), 0.3 + k * 0.24)
save("lose.wav", verb(x, 0.8))

x = buf(2.6)
add(x, ney(1.1, HICAZ[4], 0.12), 0)
add(x, ney(1.3, HICAZ[3], 0.09), 0.55)
save("pass.wav", verb(x, 0.75), peak=0.75)

x = buf(6.0)
for k in range(8):
    add(x, bell(1.8, HICAZ[k] * 2, 0.08), k * 0.09)
add(x, gong(5.0, 73.4, 0.35), 0.8)
add(x, bell(4.5, HICAZ[0] * 4, 0.1), 0.85)
save("final.wav", verb(x, 0.75))
