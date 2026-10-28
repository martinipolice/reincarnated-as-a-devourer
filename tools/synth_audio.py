"""Synthesizes the game's own sounds: enemy warning cues and ambient beds.

    python tools/synth_audio.py

Writes 16-bit mono WAVs to assets/audio/synth/. Everything is generated from
noise and sine waves with a fixed seed, so the output is ours (no license to
track) and re-running gives the same files. The ambient beds loop seamlessly:
they're filtered in the frequency domain over exactly one loop, and every
modulation completes whole cycles per loop.
"""

import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "synth")
rng = np.random.default_rng(20)


def write(name, signal, peak_db=-1.0, rms_db=None):
    signal = signal - signal.mean()
    if rms_db is not None:
        signal *= 10 ** (rms_db / 20) / max(np.sqrt(np.mean(signal ** 2)), 1e-9)
    else:
        signal *= 10 ** (peak_db / 20) / max(np.abs(signal).max(), 1e-9)
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print(name, f"{len(data) / RATE:.1f}s")


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def band(signal, low, high, slope=1.0):
    """Circular band-pass in the frequency domain (seamless on loops)."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    mask = np.clip((freqs - low * (1 - slope * 0.5)) / (low * slope * 0.5 + 1e-9), 0, 1)
    mask *= np.clip(((high * (1 + slope * 0.5)) - freqs) / (high * slope * 0.5), 0, 1)
    return np.fft.irfft(spectrum * mask, len(signal))


def pink(n):
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    spectrum[1:] /= np.sqrt(freqs[1:])
    return np.fft.irfft(spectrum, n)


def sweep(t, start, end, curve=1.0):
    """Phase of a sine whose pitch glides from start to end Hz."""
    k = (t / t[-1]) ** curve
    freq = start + (end - start) * k
    return 2 * np.pi * np.cumsum(freq) / RATE


def envelope(t, attack, release):
    env = np.minimum(1.0, t / max(attack, 1e-4))
    tail = t[-1] - t
    return env * np.minimum(1.0, tail / max(release, 1e-4))


def place(bed, sound, at):
    """Adds `sound` into `bed` at `at` seconds, wrapping around the loop."""
    start = int(at * RATE) % len(bed)
    idx = (start + np.arange(len(sound))) % len(bed)
    np.add.at(bed, idx, sound)


# Warnings: short, distinct, readable over the music.

def warn_pounce():
    # A rising snarl: rough band noise with a growl underneath.
    t = times(0.45)
    rough = band(rng.standard_normal(len(t)), 140, 700) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 30 * t)))
    growl = np.sin(sweep(t, 85, 170, 1.6)) + 0.4 * np.sin(2 * sweep(t, 85, 170, 1.6))
    return (rough * 0.9 + growl * 0.5) * envelope(t, 0.3, 0.05)


def warn_hex():
    # An eerie rising shimmer with vibrato: a spell being aimed.
    t = times(0.7)
    vib = 1 + 0.015 * np.sin(2 * np.pi * 9 * t)
    phase = sweep(t, 520, 1250, 1.3) * vib
    tone = np.sin(phase) + 0.5 * np.sin(1.5 * phase) + 0.25 * np.sin(2.01 * phase)
    return tone * envelope(t, 0.5, 0.06) * (0.8 + 0.2 * np.sin(2 * np.pi * 22 * t))


def warn_glob():
    # A wet lob: a falling blorp and a splash of noise.
    t = times(0.32)
    blorp = np.sin(sweep(t, 460, 130, 0.5)) * envelope(t, 0.01, 0.22)
    splash = band(rng.standard_normal(len(t)), 300, 2200) * np.exp(-t * 18) * 0.5
    return blorp + splash


def warn_charge():
    # A deep horn swelling before a guardian charges.
    t = times(0.95)
    phase = sweep(t, 70, 96, 2.0)
    horn = sum(np.sin(k * phase) / k for k in range(1, 9))
    horn = band(horn, 40, 900)
    rumble = band(rng.standard_normal(len(t)), 30, 160) * 0.6
    return (horn + rumble) * envelope(t, 0.7, 0.08)


# Ambient beds: 32 s loops, sitting well under the music.
LOOP = 32.0


def lfo(t, cycles, depth, phase=0.0):
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * cycles * t / LOOP + phase))


def forest_night():
    t = times(LOOP)
    wind = band(pink(len(t)), 90, 900) * lfo(t, 3, 0.6) * lfo(t, 7, 0.3, 1.0)
    bed = wind / np.abs(wind).max() * 0.5
    # Crickets: trios of short pulses, a few voices at their own pitch.
    for voice in range(3):
        pitch = 3900 + 350 * voice + rng.uniform(-80, 80)
        level = rng.uniform(0.05, 0.11)
        at = rng.uniform(0, 1)
        while at < LOOP:
            chirp = np.zeros(int(0.16 * RATE))
            for pulse in range(3):
                pt = times(0.018)
                tone = np.sin(2 * np.pi * pitch * pt) * np.sin(np.pi * pt / pt[-1])
                start = int(pulse * 0.045 * RATE)
                chirp[start:start + len(tone)] += tone
            place(bed, chirp * level, at)
            at += rng.uniform(0.7, 1.6)
    # A distant owl, twice a loop.
    for at in (9.0, 24.5):
        for hoot, (pitch, length) in enumerate(((390, 0.35), (360, 0.6))):
            ht = times(length)
            tone = np.sin(sweep(ht, pitch, pitch * 0.94)) * envelope(ht, 0.08, 0.25)
            place(bed, tone * 0.07, at + hoot * 0.55)
    return bed


def ruins_wind():
    t = times(LOOP)
    brown = np.cumsum(rng.standard_normal(len(t)))
    brown -= np.linspace(0, brown[-1] - brown[0], len(t))  # ends where it starts: no click
    brown = band(brown - brown.mean(), 40, 420)
    gusts = lfo(t, 2, 0.7) * lfo(t, 5, 0.4, 2.0)
    whistle = band(pink(len(t)), 480, 560, 0.3) * lfo(t, 3, 0.9, 0.5)
    bed = brown / np.abs(brown).max() * gusts * 0.6 + whistle / np.abs(whistle).max() * 0.18 * gusts
    # Drips in the stone, each with a short echo.
    for at in rng.uniform(0, LOOP, 7):
        dt = times(0.08)
        drip = np.sin(sweep(dt, 1500, 900)) * np.exp(-dt * 50)
        place(bed, drip * 0.12, at)
        place(bed, drip * 0.05, at + 0.13)
    return bed


def temple_drone():
    t = times(LOOP)
    drone = (np.sin(2 * np.pi * 55 * t) * 0.6 + np.sin(2 * np.pi * 82.5 * t) * 0.35
             + np.sin(2 * np.pi * (110 + 1 / LOOP * 8) * t) * 0.25)  # slow beating
    drone *= lfo(t, 4, 0.35)
    breath = band(pink(len(t)), 60, 260) * lfo(t, 3, 0.8, 1.5)
    return drone + breath / np.abs(breath).max() * 0.35


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("warn_pounce", warn_pounce())
    write("warn_hex", warn_hex())
    write("warn_glob", warn_glob())
    write("warn_charge", warn_charge())
    write("amb_forest", forest_night(), rms_db=-24)
    write("amb_ruins", ruins_wind(), rms_db=-23)
    write("amb_temple", temple_drone(), rms_db=-22)
