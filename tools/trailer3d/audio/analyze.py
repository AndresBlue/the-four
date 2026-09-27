"""What the mix does, measured, since it cannot be listened to here: the
loudness over time (momentary and short-term), how far the voice stands over
everything else while it speaks, how hard the limiter worked, the balance of
the spectrum, and a picture of it all (evidence/trailer3d/audio/analysis.png).

    python tools/trailer3d/audio/analyze.py"""
import os
import sys

import numpy as np
import scipy.signal as sig
from scipy.ndimage import maximum_filter1d

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp
import mix as edit
from dsp import SR

AUDIO = edit.OUT


def k_weight(x):
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621]
    return sig.lfilter(b2, a2, sig.lfilter(b1, a1, x, axis=0), axis=0)


def loudness_curve(x, window, step=0.1):
    k = k_weight(dsp.stereo(x) if x.ndim == 1 else x)
    n, s = dsp.n_of(window), dsp.n_of(step)
    out = []
    for start in range(0, len(k) - n + 1, s):
        p = np.mean(k[start:start + n] ** 2, axis=0).sum()
        out.append(-0.691 + 10 * np.log10(max(p, 1e-12)))
    return np.array(out)


def main():
    mix = dsp.load(os.path.join(AUDIO, 'mix.wav'), mono=False)
    voice = dsp.load(os.path.join(AUDIO, 'voice.wav'), mono=False)
    music = dsp.load(os.path.join(AUDIO, 'music.wav'), mono=False)
    fx = dsp.load(os.path.join(AUDIO, 'effects.wav'), mono=False)
    print('integrated %.2f LUFS, true peak %.2f dBTP' % (dsp.lufs(mix), dsp.true_peak(mix)))
    mom = loudness_curve(mix, 0.4)
    short = loudness_curve(mix, 3.0)
    print('momentary max %.1f LUFS, short-term max %.1f LUFS, range (10-95%%) %.1f LU' % (mom.max(), short.max(), np.percentile(short, 95) - np.percentile(short[short > -60], 10)))
    # Loudness by shot.
    for shot in edit.TIMELINE['shots']:
        a, b = shot['start'], shot['end']
        part = mix[dsp.n_of(a):dsp.n_of(b)]
        if len(part) > dsp.n_of(0.4):
            print('  %-11s %5.1f-%5.1f s  %6.1f LUFS  peak %6.1f dBFS' % (shot['id'], a, b, dsp.lufs(part), 20 * np.log10(np.abs(part).max() + 1e-9)))
    # The voice over the rest, line by line (momentary loudness while it speaks).
    rest = music + fx
    print('voice over the rest (dB, while each line is spoken):')
    for ident, at in edit.voice_cues():
        length = edit.trim(dsp.load(os.path.join(edit.VOICE_DIR, ident + '.wav'))).size / SR
        a, b = dsp.n_of(at), dsp.n_of(at + length)
        v, r = voice[a:b], rest[a:b]
        lv = -0.691 + 10 * np.log10(np.mean(k_weight(v) ** 2, axis=0).sum() + 1e-12)
        lr = -0.691 + 10 * np.log10(np.mean(k_weight(r) ** 2, axis=0).sum() + 1e-12)
        flag = '' if lv - lr >= 5.95 else '   <-- covered'
        print('  %-12s %5.2f-%5.2f s  voice %6.1f  rest %6.1f  margin %5.1f%s' % (ident, at, at + length, lv, lr, lv - lr, flag))
    # How hard the limiter worked: the mix against the sum of its stems.
    summed = voice + music + fx
    scale = np.sqrt(np.mean(mix ** 2)) / max(np.sqrt(np.mean(summed ** 2)), 1e-9)
    env_mix = maximum_filter1d(np.abs(mix).max(axis=1), dsp.n_of(0.01))
    env_sum = maximum_filter1d(np.abs(summed * scale).max(axis=1), dsp.n_of(0.01))
    gr = 20 * np.log10(np.maximum(env_mix, 1e-6) / np.maximum(env_sum, 1e-6))
    t_all = np.arange(len(env_sum)) / SR
    loud = env_sum > 0.1
    print('limiter: gain reduction over 3 dB for %.2f s, worst %.1f dB' % ((gr[loud] < -3).sum() / SR, gr[loud].min() if loud.any() else 0.0))
    # Spectral balance of the whole thing, by octave.
    f, p = sig.welch(dsp.mono(mix), SR, nperseg=8192)
    bands = [(20, 40), (40, 80), (80, 160), (160, 320), (320, 640), (640, 1280), (1280, 2560), (2560, 5120), (5120, 10240), (10240, 20000)]
    total = p.sum()
    print('spectrum by octave (share of energy, dB relative to total):')
    print('  ' + '  '.join('%d-%d:%5.1f' % (lo, hi, 10 * np.log10(p[(f >= lo) & (f < hi)].sum() / total + 1e-12)) for lo, hi in bands))
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig, axes = plt.subplots(4, 1, figsize=(20, 13), sharex=True)
        t = np.arange(len(mix)) / SR
        axes[0].plot(t[::40], dsp.mono(mix)[::40], lw=0.3, color='k')
        axes[0].set_ylabel('wave')
        tm = np.arange(len(mom)) * 0.1 + 0.2
        ts = np.arange(len(short)) * 0.1 + 1.5
        axes[1].plot(tm, mom, lw=0.8, label='momentary')
        axes[1].plot(ts, short, lw=1.5, label='short-term')
        axes[1].axhline(-14, color='r', lw=0.5)
        axes[1].set_ylim(-50, -2)
        axes[1].legend(loc='lower left')
        axes[1].set_ylabel('LUFS')
        for name, x, col in (('voice', voice, 'tab:blue'), ('music', music, 'tab:green'), ('effects', fx, 'tab:red')):
            c = loudness_curve(x, 0.4)
            axes[2].plot(np.arange(len(c)) * 0.1 + 0.2, c, lw=0.8, label=name, color=col)
        axes[2].set_ylim(-60, 0)
        axes[2].legend(loc='lower left')
        axes[2].set_ylabel('stems LUFS')
        axes[3].specgram(dsp.mono(mix), NFFT=4096, Fs=SR, noverlap=2048, cmap='magma', vmin=-130, vmax=-30)
        axes[3].set_yscale('symlog', linthresh=200)
        axes[3].set_ylim(30, 20000)
        axes[3].set_ylabel('Hz')
        for shot in edit.TIMELINE['shots']:
            for ax in axes: ax.axvline(shot['start'], color='gray', lw=0.4, alpha=0.6)
            axes[1].text(shot['start'] + 0.05, -4, shot['id'], fontsize=7, rotation=90, va='top')
        for ident, at in edit.voice_cues():
            axes[2].text(at, -5, ident, fontsize=7, rotation=90, va='top')
        axes[3].set_xlabel('s')
        fig.tight_layout()
        fig.savefig(os.path.join(AUDIO, 'analysis.png'), dpi=80)
        print('picture:', os.path.join(AUDIO, 'analysis.png'))
    except ImportError:
        pass


if __name__ == '__main__':
    main()
