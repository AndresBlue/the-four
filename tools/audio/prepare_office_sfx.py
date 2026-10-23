"""Working copies of the offices' recordings (spec_f1_systems 1.8), from the
originals in source_assets/oficinas/ into assets/audio/sfx/office/. The
originals are never touched. Every source is marked "ok" in its group's
registro.json, CC0 (BigSoundBank) or the Pixabay Content License.

  typing.wav       steady keys, a loop          bsb_2835_typewriter_2.wav
  typing_bell.wav  the request done             bsb_2844_typewriter_bell_1.wav
  tube_hiss.wav    the capsule running, a loop  bsb_0138_compressed_air.wav
  tube_bell.wav    arrival at a station         bsb_1922_industrial_bell_2.wav
  lever_1..3.wav   a lever, the reader's clunk  bsb_3061..3063_industrial_switch_*.flac
  breaker.wav      the oldest zone dropping     bsb_1092_electric_circuit_breaker.flac
  tick.wav         the red timer, a loop        bsb_0082_timer_2_kitchen.flac
  lift_motor.wav   the freight lift armed       bsb_1712_elevator_6_floors.flac
  fans.wav         the fans, a loop             bsb_3598_ventilation_5.flac
  hatch.wav        the hatch's latches          bsb_0773_metal_filing_cabinet.wav
  crawl_1..2.wav   a knee on sheet metal        the two Ev-Dawg heater vent hits (Pixabay)
  ladder.wav       a ladder climbed             pixabay_76052_ladder_aluminum_erik90.mp3

Each is decoded by ffmpeg (audio/dsp.py finds one), made mono, cut, faded and
brought to its peak; a loop is a stretch from inside the recording whose end
is crossfaded into its start, so it can be repeated without a click. Where a
stretch starts was chosen by the director without listening: the author
should hear them.

Deterministic: re-running reproduces the same files.

    python tools/audio/prepare_office_sfx.py
"""
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/trailer3d/audio"))
from dsp import ffmpeg  # noqa: E402

OFFICE = ROOT / "source_assets/oficinas/audio_oficina"
BUILDING = ROOT / "source_assets/oficinas/audio_edificio"
OUT = ROOT / "assets/audio/sfx/office"
RATE = 44100
XFADE = 0.3
## (original, copy, peak, from (s; -1: its first sound), seconds kept (0: to
## where it dies away), loop).
CLIPS = [
    (OFFICE / "maquina_escribir/bsb_2835_typewriter_2.wav", "typing.wav", 0.6, 20.0, 6.0, True),
    (OFFICE / "maquina_escribir/bsb_2844_typewriter_bell_1.wav", "typing_bell.wav", 0.7, -1, 0.0, False),
    (OFFICE / "tubo_neumatico/bsb_0138_compressed_air.wav", "tube_hiss.wav", 0.5, 1.0, 3.0, True),
    (OFFICE / "tubo_neumatico/bsb_1922_industrial_bell_2.wav", "tube_bell.wav", 0.7, -1, 3.0, False),
    (BUILDING / "breaker_lever_clack/bsb_3061_industrial_switch_1.flac", "lever_1.wav", 0.8, -1, 1.0, False),
    (BUILDING / "breaker_lever_clack/bsb_3062_industrial_switch_2.flac", "lever_2.wav", 0.8, -1, 1.0, False),
    (BUILDING / "breaker_lever_clack/bsb_3063_industrial_switch_3.flac", "lever_3.wav", 0.8, -1, 1.0, False),
    (BUILDING / "breaker_lever_clack/bsb_1092_electric_circuit_breaker.flac", "breaker.wav", 0.8, -1, 2.0, False),
    (BUILDING / "mechanical_timer_ticking/bsb_0082_timer_2_kitchen.flac", "tick.wav", 0.5, 2.0, 4.0, True),
    (BUILDING / "freight_lift_motor/bsb_1712_elevator_6_floors.flac", "lift_motor.wav", 0.7, 3.0, 6.0, False),
    (BUILDING / "ventilation_fans_full/bsb_3598_ventilation_5.flac", "fans.wav", 0.6, 10.0, 8.0, True),
    (OFFICE / "taquillas_metalicas/bsb_0773_metal_filing_cabinet.wav", "hatch.wav", 0.8, -1, 2.0, False),
    (BUILDING / "crawl_sheet_metal/pixabay_83044_heater_vent_hit_lower_evdawg.mp3", "crawl_1.wav", 0.6, -1, 1.0, False),
    (BUILDING / "crawl_sheet_metal/pixabay_103305_heater_vent_hit_higher_evdawg.mp3", "crawl_2.wav", 0.6, -1, 1.0, False),
    (BUILDING / "metal_ladder_climb/pixabay_76052_ladder_aluminum_erik90.mp3", "ladder.wav", 0.7, -1, 4.0, False),
]


def load(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def cut(x, start, keep):
    """From `start` s (or just before its first sound) for `keep` s, or to where
    it has fallen 50 dB."""
    level = np.abs(x)
    if start < 0:
        loud = np.where(level > level.max() * 10 ** (-40 / 20))[0]
        first = max(0, loud[0] - int(0.01 * RATE))
    else:
        first = min(len(x) - 1, int(start * RATE))
    quiet = np.where(level > level.max() * 10 ** (-50 / 20))[0]
    end = min(len(x), quiet[-1] + int(0.05 * RATE))
    if keep > 0:
        end = min(end, first + int(keep * RATE))
    return x[first:end]


def fade(x, fin=0.004, fout=0.25):
    x = x.copy()
    a = min(len(x), int(fin * RATE))
    b = min(len(x), int(fout * RATE))
    x[:a] *= np.linspace(0, 1, a)
    x[len(x) - b:] *= np.linspace(1, 0, b) ** 2
    return x


def loop(x):
    """The last XFADE s laid over the first, equal power, and dropped: the end
    runs into the start."""
    n = int(XFADE * RATE)
    head = x[:n]
    tail = x[-n:]
    t = np.linspace(0, 1, n)
    out = x[: len(x) - n].copy()
    out[:n] = head * np.sqrt(t) + tail * np.sqrt(1 - t)
    return out


def write(name, x, peak):
    OUT.mkdir(parents=True, exist_ok=True)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(np.round(np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("%-16s %.2f s" % (name, len(x) / RATE))


def main():
    for original, copy, peak, start, keep, looped in CLIPS:
        x = cut(load(original), start, keep)
        write(copy, loop(x) if looped else fade(x), peak)


if __name__ == "__main__":
    main()
