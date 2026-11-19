"""Soundtrack for the Wordsmith video: music and effects written together, D major, 120 BPM, 29 s.

Standard library only. Usage: python3 audio.py audio.wav
"""
import math
import random
import struct
import sys
import wave

SR = 44100
DUR = 29.0
N = int(SR * DUR)
BEAT = 0.5
random.seed(7)

music_l = [0.0] * N
music_r = [0.0] * N
fx = [0.0] * N        # effects, mono, also sent to the shared reverb
send = [0.0] * N      # reverb send (plucks + effects), so music and effects sit in one space


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def add(buf, start, samples, gain=1.0):
    i0 = int(start * SR)
    for i, s in enumerate(samples):
        j = i0 + i
        if 0 <= j < N:
            buf[j] += s * gain


def tone(freq, dur, decay, partials=((1, 1.0),), attack=0.004):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        env = min(1.0, t / attack) * math.exp(-t / decay)
        out.append(env * sum(a * math.sin(2 * math.pi * freq * m * t) for m, a in partials))
    return out


def noise(dur, decay, smooth=0.0):
    """Noise burst; `smooth` > 0 low-passes it (darker)."""
    out, prev = [], 0.0
    for i in range(int(dur * SR)):
        prev = prev * smooth + random.uniform(-1, 1) * (1 - smooth)
        out.append(prev * math.exp(-(i / SR) / decay))
    return out


def whoosh(dur, peak=0.6, rise=False):
    """Noise swell whose brightness rises and falls; `rise` only builds up (a riser into a downbeat)."""
    out, prev = [], 0.0
    for i in range(int(dur * SR)):
        x = i / (dur * SR)
        env = x ** 2 if rise else math.sin(math.pi * x) ** 2
        smooth = 0.97 - 0.25 * (x if rise else math.sin(math.pi * x))
        prev = prev * smooth + random.uniform(-1, 1) * (1 - smooth)
        out.append(prev * env * peak)
    return out


BELL = ((1, 1.0), (2.76, 0.18), (5.4, 0.05))
PLUCK = ((1, 1.0), (2, 0.3), (3, 0.08))

# --- music -----------------------------------------------------------------------------------------
CHORDS = {  # pad voicings
    "D": [62, 66, 69, 73], "Bm": [59, 62, 66, 69], "G": [55, 59, 62, 66], "A": [57, 61, 64, 66],
}
ROOTS = {"D": 38, "Bm": 35, "G": 43, "A": 45}
# (start, length, chord): the A before the outro is held for 3 s, so D lands on the outro at 25.0 s
SECTIONS = [(0, 2, "D"), (2, 2, "Bm"), (4, 2, "G"), (6, 2, "A"), (8, 2, "D"), (10, 2, "Bm"), (12, 2, "G"),
            (14, 2, "A"), (16, 2, "D"), (18, 2, "Bm"), (20, 2, "G"), (22, 3, "A"), (25, 4, "D")]
GROOVE = (3.5, 19.0)        # kick and bass; the menu bar scene is a breakdown without them
OUTRO = 25.0


def chord_at(t):
    return next(name for start, length, name in reversed(SECTIONS) if t >= start)


# pad: slow attack, overlapping release, two detuned sines per note; the last chord rings to the end
for start, length, name in SECTIONS:
    length = length + (0 if start == OUTRO else 0.8)
    for k, midi in enumerate(CHORDS[name]):
        f = hz(midi)
        pan = 0.35 + 0.1 * k
        for i in range(int(length * SR)):
            t = i / SR
            env = min(1.0, t / 0.35) * min(1.0, max(0.0, (length - t) / 0.8))
            s = env * (math.sin(2 * math.pi * f * t) + 0.6 * math.sin(2 * math.pi * f * 1.004 * t + 1.3)
                       + 0.15 * math.sin(2 * math.pi * f * 2 * t))
            j = int(start * SR) + i
            if j < N:
                music_l[j] += s * 0.032 * (1 - pan)
                music_r[j] += s * 0.032 * pan

# plucked arpeggio in 8ths, one octave up; softer in the breakdown, sparser in the outro
PATTERN = [0, 1, 2, 3, 2, 1, 2, 3]
for step in range(int(DUR / (BEAT / 2))):
    t0 = step * BEAT / 2
    if t0 > 28.0 or (t0 >= OUTRO and step % 2):
        continue
    midi = CHORDS[chord_at(t0)][PATTERN[step % 8]] + 12
    p = tone(hz(midi), 0.6, 0.16, PLUCK)
    pan = 0.35 if step % 2 else 0.65
    gain = 0.07 if t0 < 3.0 else 0.06 if GROOVE[1] <= t0 < OUTRO else 0.085
    add(music_l, t0, p, gain * (1 - pan) * 2)
    add(music_r, t0, p, gain * pan * 2)
    add(send, t0, p, gain * 0.5)

# kick on every beat of the groove, one big hit on the outro downbeat
kick, phase = [], 0.0
for i in range(int(0.35 * SR)):
    t = i / SR
    phase += 2 * math.pi * (45 + 75 * math.exp(-t / 0.03)) / SR
    kick.append(math.sin(phase) * math.exp(-t / 0.12))
groove_beats = [b * BEAT for b in range(int(GROOVE[0] / BEAT), int(GROOVE[1] / BEAT))]
for t0 in groove_beats + [OUTRO]:
    add(music_l, t0, kick, 0.38 if t0 == OUTRO else 0.32)
    add(music_r, t0, kick, 0.38 if t0 == OUTRO else 0.32)

# bass: root on each beat of the groove, and the outro root ringing out
for t0 in groove_beats:
    b = tone(hz(ROOTS[chord_at(t0)]), 0.45, 0.25, ((1, 1.0), (2, 0.25)), attack=0.01)
    add(music_l, t0, b, 0.11)
    add(music_r, t0, b, 0.11)
outro_bass = tone(hz(ROOTS["D"]), 3.5, 1.2, ((1, 1.0), (2, 0.25)), attack=0.01)
add(music_l, OUTRO, outro_bass, 0.12)
add(music_r, OUTRO, outro_bass, 0.12)

# hats on the off-beats in the highlights
burst = noise(0.06, 0.018)
hat = [s - p for s, p in zip(burst, [0.0] + burst)]  # first difference: a crude high-pass
for t0 in [b * BEAT + BEAT / 2 for b in range(14, int(GROOVE[1] / BEAT))]:
    add(music_l, t0, hat, 0.018)
    add(music_r, t0, hat, 0.03)

# --- effects (tuned to D, soft, under the music) ----------------------------------------------------
D6, Fs6, A6, D7 = hz(86), hz(90), hz(93), hz(98)

t0 = 0.3  # typing: tiny dark ticks, well in the background
while t0 < 2.5:
    add(fx, t0, noise(0.012, 0.003, smooth=0.6), 0.05)
    t0 += 0.07 + random.uniform(-0.015, 0.015)

add(fx, 2.75, whoosh(0.5, 0.4), 0.05)   # selection sweep


def key(t0, freq, gain=0.05):
    add(fx, t0, noise(0.01, 0.002, smooth=0.3), gain * 1.6)
    add(fx, t0, tone(freq, 0.25, 0.06, BELL), gain)


def panel(t0):
    add(fx, t0 - 0.15, whoosh(0.3, 0.5), 0.05)
    add(fx, t0, tone(D6, 0.9, 0.3, BELL), 0.045)
    add(fx, t0 + 0.07, tone(Fs6, 0.9, 0.3, BELL), 0.04)


key(3.9, D6); key(4.2, A6)                             # ⌥ ⌥
panel(4.45); panel(5.95)
for t0, f in [(7.7, Fs6), (8.2, A6), (8.7, Fs6), (9.1, D6)]:
    key(t0, f)                                         # ↓ ↓ ↑ ↑
key(9.6, D6)                                           # ⏎
for i, f in enumerate([D6, Fs6, A6, D7]):             # replace: sparkle
    add(fx, 10.0 + i * 0.06, tone(f, 1.0, 0.35, BELL), 0.05)

add(fx, 11.95, whoosh(0.5), 0.07)                      # to the thread
add(fx, 12.85, whoosh(0.5, 0.4), 0.04)                 # thread selected
key(13.7, D6); key(13.95, A6)                          # ⌃ ⌃
panel(14.15); panel(15.15)
key(18.55, D6)                                         # ⏎ copies
add(fx, 18.62, tone(A6, 0.8, 0.25, BELL), 0.035)

add(fx, 19.1, whoosh(0.5), 0.07)                       # to the menu bar
key(20.5, A6, 0.035)                                   # click on the wand
add(fx, 20.6, tone(Fs6, 0.8, 0.25, BELL), 0.03)        # menu opens
key(21.6, D7, 0.015)                                   # hover tick

add(fx, 24.1, whoosh(0.9, 0.7, rise=True), 0.08)      # riser into the outro
for i, f in enumerate([A6, D7, hz(102), hz(105)]):     # outro shimmer
    add(fx, OUTRO + i * 0.09, tone(f, 1.6, 0.6, BELL), 0.035)

for i in range(N):
    send[i] += fx[i] * 0.8


# --- shared reverb (Schroeder: 4 combs + 2 all-pass), slightly different per side -------------------
def reverb(src, offset):
    out = [0.0] * N
    for delay, fb in [(1557 + offset, 0.80), (1617 + offset, 0.79), (1491 + offset, 0.81), (1422 + offset, 0.78)]:
        buf, idx = [0.0] * delay, 0
        for i in range(N):
            y = buf[idx]
            buf[idx] = src[i] + y * fb
            idx = (idx + 1) % delay
            out[i] += y * 0.25
    for delay, g in [(225, 0.5), (556, 0.5)]:
        buf, idx = [0.0] * delay, 0
        for i in range(N):
            b, x = buf[idx], out[i]
            buf[idx] = x + b * g
            idx = (idx + 1) % delay
            out[i] = b - x
    return out


rev_l = reverb(send, 0)
rev_r = reverb(send, 23)

# --- mix and master ---------------------------------------------------------------------------------
left = [music_l[i] + fx[i] * 0.9 + rev_l[i] * 0.35 for i in range(N)]
right = [music_r[i] + fx[i] * 0.9 + rev_r[i] * 0.35 for i in range(N)]
for ch in (left, right):
    for i in range(N):
        t = i / SR
        fade = min(1.0, t / 0.01) * min(1.0, (DUR - t) / 1.5)
        ch[i] = math.tanh(ch[i] * fade * 1.4)   # gentle soft clip
peak = max(max(abs(s) for s in left), max(abs(s) for s in right))
gain = 10 ** (-1 / 20) / peak
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<hh", int(l * gain * 32767), int(r * gain * 32767))
                           for l, r in zip(left, right)))
print("wrote", sys.argv[1], f"peak gain {gain:.2f}")
