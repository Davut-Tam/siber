"""Oyunun ses efektlerini sentezleyip assets/sounds altına WAV olarak yazar.

Kullanım: python3 tool/make_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = random.Random(7)


def osc(kind, phase):
    x = phase % 1.0
    if kind == 'sine':
        return math.sin(2 * math.pi * x)
    if kind == 'square':
        return 1.0 if x < 0.5 else -1.0
    if kind == 'saw':
        return 2 * x - 1
    if kind == 'tri':
        return 4 * abs(x - 0.5) - 1
    return rng.uniform(-1, 1)  # gürültü


def tone(dur, f0, f1=None, kind='sine', vol=0.5, attack=0.004, curve=3.0, delay=0.0):
    """f0'dan f1'e kayan, üstel sönen bir ton; (gecikme, örnekler) döner"""
    f1 = f0 if f1 is None else f1
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += f / RATE
        env = min(1.0, i / (attack * RATE + 1)) * (1 - t) ** curve
        out.append(osc(kind, phase) * env * vol)
    return delay, out


def noise(dur, vol=0.5, cutoff=0.25, cutoff_end=None, curve=2.0, delay=0.0):
    """Tek kutuplu alçak geçiren süzgeçten geçmiş gürültü; süzgeç zamanla kapanabilir"""
    cutoff_end = cutoff if cutoff_end is None else cutoff_end
    n = int(dur * RATE)
    out, y = [], 0.0
    for i in range(n):
        t = i / n
        a = cutoff + (cutoff_end - cutoff) * t
        y += a * (rng.uniform(-1, 1) - y)
        out.append(y * (1 - t) ** curve * vol * 2.2)
    return delay, out


def save(name, *parts):
    length = max(int(d * RATE) + len(s) for d, s in parts)
    mix = [0.0] * length
    for d, s in parts:
        o = int(d * RATE)
        for i, v in enumerate(s):
            mix[o + i] += v
    peak = max(1e-6, max(abs(v) for v in mix))
    gain = min(1.0, 0.9 / peak)
    with wave.open(os.path.join(OUT, name + '.wav'), 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(v * gain * 32767)) for v in mix))


os.makedirs(OUT, exist_ok=True)
save('ates', tone(0.09, 1500, 420, 'square', 0.22, curve=2.5))
save('fuze', noise(0.28, 0.35, 0.05, 0.4, 1.2), tone(0.28, 300, 900, 'saw', 0.12, curve=1.5))
save('isabet', tone(0.04, 900, 600, 'tri', 0.35))
save('patlama', noise(0.35, 0.8, 0.5, 0.05, 2.0), tone(0.3, 140, 50, 'sine', 0.5))
save('buyuk_patlama', noise(0.9, 0.9, 0.35, 0.02, 1.6), tone(0.9, 90, 30, 'sine', 0.8, curve=2.0))
save('guc', tone(0.12, 660, 660, 'tri', 0.4), tone(0.12, 880, 880, 'tri', 0.4, delay=0.07), tone(0.22, 1320, 1320, 'tri', 0.4, delay=0.14))
save('vuruldu', tone(0.4, 320, 70, 'saw', 0.5, curve=1.6), noise(0.25, 0.5, 0.3, 0.05))
save('bomba', tone(1.4, 70, 28, 'sine', 0.9, curve=1.4), noise(1.4, 0.8, 0.6, 0.01, 1.3), tone(0.5, 1200, 200, 'saw', 0.15))
save('dalga', tone(0.25, 520, 520, 'sine', 0.4), tone(0.4, 780, 780, 'sine', 0.4, delay=0.15))
save('alarm', *[tone(0.18, 440 if i % 2 == 0 else 330, None, 'square', 0.25, curve=0.6, delay=i * 0.2) for i in range(4)])
save('kombo', tone(0.06, 1200, 1600, 'sine', 0.3))
save('kalkan', tone(0.3, 400, 1200, 'sine', 0.3, curve=1.0), tone(0.3, 600, 1800, 'tri', 0.15, curve=1.0, delay=0.04))
save('bitti', tone(0.25, 523, 523, 'tri', 0.4), tone(0.25, 392, 392, 'tri', 0.4, delay=0.22), tone(0.6, 262, 262, 'tri', 0.45, delay=0.44))
