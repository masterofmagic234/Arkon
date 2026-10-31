"""Deterministic original vehicle audio. Offline only; NumPy required.

No recordings or third-party samples. Four-cylinder firing pulses, exhaust and
intake resonances, mechanical noise and friction produce seamless PCM loops.
Run from any directory; shipped WAVs need no Python on the device.
"""
from pathlib import Path
import json
import wave
import numpy as np

RATE = 44100
SECONDS = 2
N = RATE * SECONDS
ROOT = Path(__file__).resolve().parents[1] / "assets" / "vehicle_audio"
RNG = np.random.default_rng(240)
T = np.arange(N) / RATE
F = np.fft.rfftfreq(N, 1 / RATE)


def colored_noise(peaks, floor=0.0):
    shape = np.full(len(F), floor)
    for frequency, width, level in peaks:
        shape += level * np.exp(-0.5 * ((F - frequency) / width) ** 2)
    shape *= (1 - np.exp(-(F / 35) ** 2)) * np.exp(-(F / 9000) ** 8)
    noise = np.fft.irfft(np.fft.rfft(RNG.normal(size=N)) * shape, n=N)
    return noise / max(np.std(noise), 1e-9)


def write(name, samples, rms=0.18):
    samples = samples - np.mean(samples)
    samples *= rms / max(np.sqrt(np.mean(samples**2)), 1e-9)
    samples = np.tanh(samples * 1.25) / 1.25
    samples *= min(1.0, 0.86 / max(np.max(np.abs(samples)), 1e-9))
    pcm = np.round(samples * 32767).astype("<i2")
    with wave.open(str(ROOT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    return {"file": name, "frames": len(samples), "rate": RATE,
            "rms": float(np.sqrt(np.mean(samples**2))),
            "peak": float(np.max(np.abs(samples))),
            "seam_delta": float(abs(samples[0] - samples[-1]))}


def engine(rpm, load):
    cycle = rpm / 120  # Four unequal firings per 720-degree cycle.
    period = 1 / cycle
    pulses = np.zeros(N)
    for cylinder, amplitude in enumerate([1.0, 0.91, 0.97, 0.94]):
        elapsed = np.mod(T - cylinder * period / 4, period)
        pulses += amplitude * (np.exp(-elapsed / 0.0025) - np.exp(-elapsed / 0.00022))
    spectrum = np.fft.rfft(pulses - pulses.mean())
    response = np.zeros(len(F))
    for frequency, width, level in [(80, 45, 0.95), (165, 75, 0.78),
                                  (340, 125, 0.40), (620, 180, 0.32),
                                  (1150, 280, 0.23), (2100, 420, 0.12)]:
        response += level * np.exp(-0.5 * ((F - frequency) / width) ** 2)
    exhaust = np.fft.irfft(spectrum * response, n=N)
    exhaust /= max(np.std(exhaust), 1e-9)
    intake = colored_noise([(420, 180, 1), (950, 250, 0.4), (2300, 900, 0.25)])
    mechanical = colored_noise([(1800, 400, 1), (3500, 950, 0.35)])
    # Slow periodic modulation adds combustion variation without a loop seam.
    breath = 0.88 + 0.12 * np.sin(2 * np.pi * cycle * T + 0.4)
    firing_envelope = 0.65 + 0.35 * np.cos(2 * np.pi * rpm / 30 * T)
    signal = exhaust * (1.0 if load else 0.78)
    signal += intake * breath * (0.28 if load else 0.075)
    signal += mechanical * firing_envelope * (0.09 if load else 0.06)
    return signal


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    report = []
    for rpm in [900, 2700, 4500, 6300]:
        for load in [False, True]:
            name = f"engine_{rpm:04d}_{'load' if load else 'coast'}.wav"
            report.append(write(name, engine(rpm, load)))
    # Friction is broadband with moving resonances, rather than a pure whistle.
    slip = colored_noise([(740, 90, 0.65), (1160, 140, 1),
                          (1880, 260, 0.75), (3100, 600, 0.24)], 0.025)
    chirp = np.sin(2 * np.pi * 930 * T + 3.8 * np.sin(2 * np.pi * 6 * T))
    slip = slip * (0.82 + 0.18 * np.sin(2 * np.pi * 11 * T)) + 0.20 * chirp
    report.append(write("tire_scrub.wav", slip, 0.16))
    shift_t = T[:int(RATE * 0.19)]
    knock = colored_noise([(260, 110, 1), (850, 220, 0.4)])[:len(shift_t)]
    knock = (0.6 * np.sin(2 * np.pi * 75 * shift_t) + knock * 0.25)
    knock *= np.exp(-shift_t * 27) * np.minimum(shift_t / 0.007, 1)
    knock *= np.minimum((shift_t[-1] - shift_t) / 0.015, 1)
    report.append(write("automatic_shift.wav", knock, 0.10))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
