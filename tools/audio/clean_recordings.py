"""Cleans supplied recordings for use in game (16-bit mono WAV).

* The slow door opening (also the wardrobe peek): microphone hiss removed with
  a spectral gate, rumble filtered, and the level eased down as it plays so it
  ends softer than it starts, with a short fade at the tail.
* The bed recording (`assets/audio/bed-sound.m4a`, someone moving on a bed):
  denoised and cut into the movements of the opening scene. The sharp knocks
  of hands pressing on the mattress are kept but softened.

Compressed sources are decoded first with `tools/audio/decode_media.ps1`
(Windows Media Foundation, no extra installs).

    python tools/audio/clean_recordings.py
"""
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal
from scipy.ndimage import uniform_filter

ROOT = Path(__file__).resolve().parents[2]
DECODER = ROOT / "tools/audio/decode_media.ps1"

## Bed clips: name -> (start, end) seconds in the recording.
BED_CLIPS = {
    "bed_stir": (0.70, 2.00),  # stirring awake
    "bed_sit": (6.10, 10.00),  # sitting up, one hand pushes down
    "bed_lean": (25.80, 28.70),  # shuffling forward towards the television
    "bed_shift": (29.10, 30.00),  # a small shift of weight
    "bed_press": (20.60, 22.05),  # leaning on the hands, the mattress gives
    "bed_rise": (15.40, 16.40),  # springing up off the bed
}


def decode(source: Path, folder: Path) -> tuple[int, np.ndarray]:
    target = folder / (source.stem + ".wav")
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(DECODER), "-In", str(source), "-Out", str(target)], check=True, capture_output=True)
    with wave.open(str(target), "rb") as w:
        rate = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
        data = data.reshape(-1, w.getnchannels()).mean(axis=1)
    return rate, data


def write(path: Path, rate: int, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.clip(samples * 32767, -32768, 32767).astype("<i2").tobytes())
    peak = 20 * np.log10(np.abs(samples).max() + 1e-9)
    print(f"wrote {path.relative_to(ROOT)}  {len(samples) / rate:.2f} s  peak {peak:.1f} dBFS")


def denoise(rate: int, x: np.ndarray, strength: float = 2.0, floor: float = 0.06, highpass: float = 70.0) -> np.ndarray:
    """Spectral gate: the noise floor per frequency is the quiet end of each
    bin over time; bins close to it are pulled down, smoothed so the gate
    does not warble."""
    x = signal.sosfiltfilt(signal.butter(4, highpass, "highpass", fs=rate, output="sos"), x)
    _, _, spec = signal.stft(x, rate, nperseg=2048, noverlap=1536)
    magnitude = np.abs(spec)
    noise = np.percentile(magnitude, 12, axis=1, keepdims=True)
    gain = np.clip(1.0 - strength * noise / (magnitude + 1e-12), floor, 1.0)
    gain = uniform_filter(gain, size=(5, 5))
    _, cleaned = signal.istft(spec * gain, rate, nperseg=2048, noverlap=1536)
    return cleaned[: len(x)]


def soften_knocks(rate: int, x: np.ndarray, headroom_db: float = 16.0) -> np.ndarray:
    """Limits peaks to `headroom_db` above the clip's RMS level, with a short
    look-ahead so the gain is already down when a knock lands."""
    threshold = np.sqrt(np.mean(x * x)) * 10 ** (headroom_db / 20)
    envelope = np.zeros_like(x)
    level = 0.0
    release = np.exp(-1.0 / (rate * 0.08))
    for i, value in enumerate(np.abs(x)):
        level = value if value > level else level * release
        envelope[i] = level
    look = int(rate * 0.004)
    envelope = np.maximum(envelope, np.concatenate([envelope[look:], np.zeros(look)]))
    return x * np.minimum(1.0, threshold / (envelope + 1e-12))


def fade(rate: int, x: np.ndarray, inward: float, outward: float) -> np.ndarray:
    x = x.copy()
    a = int(rate * inward)
    b = int(rate * outward)
    if a: x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if b: x[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return x


def normalise(x: np.ndarray, peak_db: float) -> np.ndarray:
    return x / (np.abs(x).max() + 1e-12) * 10 ** (peak_db / 20)


def main() -> None:
    with tempfile.TemporaryDirectory() as folder:
        temp = Path(folder)
        # Slow door: same loudness at the start, easing 10 dB down by the end.
        rate, door = decode(ROOT / "assets/audio/sfx/door/opening/creaky-wooden-door-slow-opening.mp3", temp)
        clean = denoise(rate, door, 2.2, 0.04, 120.0)
        t = np.arange(len(clean)) / len(clean)
        clean *= 10 ** (-10.0 * t ** 1.3 / 20)
        clean = fade(rate, clean, 0.0, 0.7)
        write(ROOT / "assets/audio/sfx/door/opening/slow-opening-clean.wav", rate, clean)
        # Bed: one denoise over the whole take, then the movements.
        rate, bed = decode(ROOT / "assets/audio/bed-sound.m4a", temp)
        bed = denoise(rate, bed)
        for name, (start, end) in BED_CLIPS.items():
            clip = bed[int(start * rate): int(end * rate)]
            clip = soften_knocks(rate, clip)
            clip = fade(rate, clip, 0.04, 0.15)
            write(ROOT / f"assets/audio/intro/{name}.wav", rate, normalise(clip, -3.0))


if __name__ == "__main__":
    main()
