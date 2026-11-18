"""Spectrograms and numbers for the team voice demo (tools/audio/voice_radio_demo.gd).

Reads evidence/voz/voz_*.wav and, if present, the downloaded CB reference, and
writes evidence/voz/espectro_<name>.png plus evidence/voz/medidas.json:
band at -20 dB from the long-term spectrum, crest factor over the active
part, and the lengths of the roger beeps and of the squelch tail.
Run with: python -P tools/audio/voice_spectrograms.py
"""
import json
import pathlib

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "evidence" / "voz"
REFERENCE = OUT / "descargas" / "grimsby_cb_fm" / "grimsby_cb_27782.9kHz.wav"


def mono(path):
    rate, data = wavfile.read(path)
    data = data.astype(np.float64) / 32768.0
    if data.ndim > 1:
        data = data.mean(axis=1)
    return rate, data


def busiest(rate, data, seconds=20.0):
    """The stretch of the reference with the most speech: an open squelch is
    flat noise, a voice has a shaped spectrum (low spectral flatness)."""
    hop = int(rate * 0.05)
    frames = data[: len(data) // hop * hop].reshape(-1, hop)
    power = np.abs(np.fft.rfft(frames * np.hanning(hop), axis=1)) ** 2
    f = np.fft.rfftfreq(hop, 1 / rate)
    speech = power[:, (f > 300) & (f < 3400)] + 1e-20
    flat = np.exp(np.log(speech).mean(axis=1)) / speech.mean(axis=1)
    span = int(seconds / 0.05)
    counts = np.convolve(flat < 0.15, np.ones(span), "valid")
    start = int(np.argmax(counts)) * hop
    return data[start : start + int(seconds * rate)], start / rate


def speech_only(rate, data):
    """50 ms frames with a shaped spectrum: voice, not noise, beeps or silence."""
    hop = int(rate * 0.05)
    frames = data[: len(data) // hop * hop].reshape(-1, hop)
    power = np.abs(np.fft.rfft(frames * np.hanning(hop), axis=1)) ** 2
    f = np.fft.rfftfreq(hop, 1 / rate)
    speech = power[:, (f > 300) & (f < 3400)] + 1e-20
    flat = np.exp(np.log(speech).mean(axis=1)) / speech.mean(axis=1)
    rms = np.sqrt((frames ** 2).mean(axis=1))
    return frames[(flat < 0.15) & (rms > rms.max() * 0.05)].ravel()


def band(rate, data):
    f, p = signal.welch(data, rate, nperseg=2048)
    db = 10 * np.log10(p + 1e-20)
    keep = f >= 60
    f, db = f[keep], db[keep]
    over = np.where(db >= db.max() - 20)[0]
    return float(f[over[0]]), float(f[over[-1]])


def crest(rate, data):
    """Peak to RMS in dB: the single highest sample, and the 99.9th percentile."""
    rms = np.sqrt((data ** 2).mean())
    return [round(float(20 * np.log10(np.abs(data).max() / rms)), 1), round(float(20 * np.log10(np.percentile(np.abs(data), 99.9) / rms)), 1)]


def runs(mask, rate, hop):
    """(start s, length ms) of each run of True."""
    edges = np.diff(np.concatenate([[0], mask.astype(int), [0]]))
    starts, ends = np.where(edges == 1)[0], np.where(edges == -1)[0]
    return [(round(s * hop / rate, 3), round((e - s) * hop / rate * 1000)) for s, e in zip(starts, ends)]


def events(rate, data):
    """Beeps: a narrow band around 1050 or 1350 Hz holding most of the energy.
    Tail: broadband noise right after a closing beep."""
    hop = int(rate * 0.002)
    f, t, z = signal.stft(data, rate, nperseg=256, noverlap=256 - hop)
    power = np.abs(z) ** 2
    total = power.sum(axis=0) + 1e-20
    found = {}
    for name, hz in (("bip_apertura", 1350.0), ("bip_cierre", 1050.0)):
        near = (f > hz - 90) & (f < hz + 90)
        share = power[near].sum(axis=0) / total
        loud = total > total.max() * 1e-3
        found[name] = runs((share > 0.6) & loud, rate, hop)
    # Tail: from the end of each closing beep until the noise is 20 dB under
    # its own peak, looked for in the 300 ms after it.
    found["cola"] = []
    for start, length in found["bip_cierre"]:
        if length < 50:
            continue
        begin = int((start + length / 1000) * rate / hop)
        window = total[begin : begin + int(0.3 * rate / hop)]
        if len(window) == 0 or window.max() < total.max() * 1e-3:
            continue
        quiet = np.where(window < window.max() * 0.01)[0]
        found["cola"].append((round(begin * hop / rate, 3), round((quiet[0] if len(quiet) else len(window)) * hop / rate * 1000)))
    return found


def picture(rate, data, title, path, offset=0.0):
    f, t, s = signal.spectrogram(data, rate, nperseg=512, noverlap=448)
    t = t + offset
    plt.figure(figsize=(12, 4))
    plt.pcolormesh(t, f, 10 * np.log10(s + 1e-12), shading="auto", vmin=-110, vmax=-30, cmap="magma")
    plt.ylim(0, min(rate / 2, 8000))
    plt.ylabel("Hz")
    plt.xlabel("s")
    plt.title(title)
    plt.colorbar(label="dB")
    plt.tight_layout()
    plt.savefig(path, dpi=90)
    plt.close()


def main():
    numbers = {}
    for path in sorted(OUT.glob("voz_*.wav")):
        rate, data = mono(path)
        name = path.stem
        picture(rate, data, name, OUT / f"espectro_{name}.png")
        if name == "voz_radio":
            # One whole call up close: key-up beep, voice, closing beep, tail.
            picture(rate, data[int(0.6 * rate) : int(2.1 * rate)], name + " 0,6 a 2,1 s", OUT / f"espectro_{name}_detalle.png", 0.6)
        low, high = band(rate, data)
        numbers[name] = {"banda_-20dB_Hz": [round(low), round(high)], "factor_cresta_voz_dB": crest(rate, speech_only(rate, data))}
        if name != "voz_entrada":
            found = events(rate, data)
            numbers[name].update(found)
            # Crest of the voice alone: beeps and tails cut out.
            keep = np.ones(len(data), bool)
            for start, length in [r for key in found for r in found[key]]:
                keep[int(start * rate) : int((start + length / 1000 + 0.01) * rate)] = False
            voice = speech_only(rate, data[keep])
            numbers[name]["factor_cresta_voz_dB"] = crest(rate, voice)
            low, high = band(rate, voice)
            numbers[name]["banda_voz_-20dB_Hz"] = [round(low), round(high)]
    response = OUT / "respuesta_radio.wav"
    if response.exists():
        rate, data = mono(response)
        f, p = signal.welch(data, rate, nperseg=2048)
        db = 10 * np.log10(p + 1e-20)
        db -= db.max()
        def edges(level):
            over = np.where(db >= level)[0]
            return [round(float(f[over[0]])), round(float(f[over[-1]]))]
        numbers["respuesta_radio"] = {"banda_-3dB_Hz": edges(-3), "banda_-6dB_Hz": edges(-6), "banda_-20dB_Hz": edges(-20)}
    if REFERENCE.exists():
        rate, data = mono(REFERENCE)
        part, at = busiest(rate, data)
        picture(rate, part, f"referencia CB FM (desde {at:.0f} s)", OUT / "espectro_referencia_cb.png")
        wavfile.write(OUT / "referencia_cb_fragmento.wav", rate, (part * 32767).astype(np.int16))
        low, high = band(rate, part)
        voiced = speech_only(rate, part)
        low_v, high_v = band(rate, voiced)
        numbers["referencia_cb"] = {"desde_s": round(at), "banda_-20dB_Hz": [round(low), round(high)],
            "banda_voz_-20dB_Hz": [round(low_v), round(high_v)], "factor_cresta_voz_dB": crest(rate, voiced)}
    (OUT / "medidas.json").write_text(json.dumps(numbers, indent=1, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(numbers, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
