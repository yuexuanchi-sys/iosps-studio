# -*- coding: utf-8 -*-
"""Deterministic generator for IOSPS original royalty-free background music tracks.

Generates four 16-second (480 frames @ 30 fps) stereo 44.1 kHz AAC (.m4a) tracks
using pure mathematical additive synthesis with warm musical chord progressions.
All generated audio is original work created for IOSPS (CC0-1.0 / MIT).

Usage:
    python tools/generate_bgm.py app/Resources/Music
"""
from __future__ import annotations

import hashlib
import math
import sys
from pathlib import Path
import av
import numpy as np

SAMPLE_RATE = 44_100
DURATION_SECONDS = 16.0
TOTAL_SAMPLES = int(SAMPLE_RATE * DURATION_SECONDS)


def midi_to_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def add_voice(
    left: np.ndarray,
    right: np.ndarray,
    start_s: float,
    dur_s: float,
    midi_note: float,
    amp: float,
    harmonics: list[tuple[int, float]],
    attack_s: float,
    decay_rate: float,
    pan: float = 0.0,
) -> None:
    i0 = int(round(start_s * SAMPLE_RATE))
    length = int(round(dur_s * SAMPLE_RATE))
    if i0 >= TOTAL_SAMPLES or length <= 0:
        return
    i1 = min(TOTAL_SAMPLES, i0 + length)
    n = i1 - i0
    t = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    f0 = midi_to_hz(midi_note)

    wave = np.zeros(n, dtype=np.float64)
    for mult, weight in harmonics:
        if f0 * mult < SAMPLE_RATE * 0.45:
            wave += weight * np.sin(2.0 * math.pi * f0 * mult * t)

    env = np.exp(-decay_rate * t)
    atk_n = max(1, int(round(attack_s * SAMPLE_RATE)))
    if atk_n < n:
        env[:atk_n] *= np.linspace(0.0, 1.0, atk_n, endpoint=False)
    rel_n = min(n, max(1, int(round(0.04 * SAMPLE_RATE))))
    env[-rel_n:] *= np.linspace(1.0, 0.0, rel_n)

    sig = wave * env * amp
    angle = (pan + 1.0) * math.pi / 4.0
    left[i0:i1] += sig * math.cos(angle)
    right[i0:i1] += sig * math.sin(angle)


def finalize_stereo(left: np.ndarray, right: np.ndarray) -> np.ndarray:
    # Gentle loop-boundary smoothing (40 ms fade at very start and very end)
    fade = int(0.04 * SAMPLE_RATE)
    ramp = np.linspace(0.0, 1.0, fade)
    left[:fade] *= ramp
    right[:fade] *= ramp
    left[-fade:] *= ramp[::-1]
    right[-fade:] *= ramp[::-1]

    # Simple warm stereo reverb tap (short delay reflections)
    out_l = left.copy()
    out_r = right.copy()
    for delay_ms, gain in [(43, 0.14), (79, 0.09), (127, 0.05)]:
        d = int(SAMPLE_RATE * delay_ms / 1000.0)
        out_l[d:] += right[:-d] * gain
        out_r[d:] += left[:-d] * gain

    peak = max(float(np.max(np.abs(out_l))), float(np.max(np.abs(out_r))), 1e-6)
    scale = 0.78 / peak
    stereo = np.stack([out_l * scale, out_r * scale], axis=0).astype(np.float32)
    return stereo


def generate_warm_piano() -> np.ndarray:
    """C major warm arpeggiated piano progression (I - V - vi - IV), 90 BPM."""
    l = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    r = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    chords = [
        ([48, 55, 60, 64, 67], [72, 76, 74, 72]),  # C
        ([43, 55, 59, 62, 67], [71, 74, 72, 67]),  # G
        ([45, 52, 57, 60, 64], [69, 72, 76, 74]),  # Am
        ([41, 53, 57, 60, 65], [72, 69, 67, 64]),  # F
    ]
    piano_h = [(1, 1.0), (2, 0.42), (3, 0.16), (4, 0.06)]
    beat = 0.5  # 120 subdivisions -> 4s per bar, 4 bars = 16s
    for repeat in range(2):
        for bar_idx, (arp, melody) in enumerate(chords):
            bar_t = (repeat * 4 + bar_idx) * 2.0
            # Bass pad
            add_voice(l, r, bar_t, 2.0, arp[0], 0.34, [(1, 1.0), (2, 0.28)], 0.02, 1.4, pan=-0.15)
            # Rolling arpeggio
            for step, note in enumerate(arp[1:]):
                add_voice(l, r, bar_t + step * 0.48, 1.4, note, 0.22, piano_h, 0.012, 2.2, pan=-0.2 + step * 0.13)
            # Lyrical top line
            for m_idx, m_note in enumerate(melody):
                add_voice(
                    l,
                    r,
                    bar_t + m_idx * beat,
                    0.95,
                    m_note + (12 if repeat == 1 and m_idx == 2 else 0),
                    0.26,
                    piano_h,
                    0.01,
                    2.6,
                    pan=0.18,
                )
    return finalize_stereo(l, r)


def generate_music_box() -> np.ndarray:
    """G major delicate celesta / music-box waltz feel for birthday wishes."""
    l = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    r = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    bell_h = [(1, 1.0), (2, 0.32), (3, 0.18), (5, 0.07)]
    pad_h = [(1, 1.0), (2, 0.18)]
    bars = [
        (55, [67, 71, 74, 79, 74, 71]),  # G
        (52, [64, 67, 71, 76, 71, 67]),  # Em
        (48, [60, 64, 67, 72, 74, 72]),  # C
        (50, [62, 66, 69, 74, 72, 69]),  # D
    ]
    for repeat in range(2):
        for idx, (bass, notes) in enumerate(bars):
            base = (repeat * 4 + idx) * 2.0
            add_voice(l, r, base, 2.0, bass, 0.25, pad_h, 0.04, 1.1, pan=0.0)
            for k, n_midi in enumerate(notes):
                pan = -0.3 + 0.12 * k
                add_voice(l, r, base + k * (2.0 / 6.0), 1.1, n_midi + 12, 0.26, bell_h, 0.004, 3.8, pan=pan)
    return finalize_stereo(l, r)


def generate_sunny_acoustic() -> np.ndarray:
    """F major bright rhythmic plucked acoustic groove for travel memories."""
    l = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    r = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    pluck_h = [(1, 1.0), (2, 0.55), (3, 0.28), (4, 0.14), (5, 0.07)]
    prog = [
        ([53, 57, 60, 65], [69, 72, 74, 72, 69, 65]),  # F
        ([48, 55, 60, 64], [67, 72, 71, 67, 64, 67]),  # C
        ([50, 57, 62, 65], [69, 74, 72, 69, 65, 69]),  # Dm
        ([46, 53, 58, 62], [70, 69, 65, 67, 69, 72]),  # Bb
    ]
    for repeat in range(2):
        for idx, (chord, riff) in enumerate(prog):
            base = (repeat * 4 + idx) * 2.0
            # Light rhythmic strums at 0, 0.5, 0.75, 1.25, 1.5
            for strum_t, vel in [(0.0, 0.22), (0.5, 0.15), (0.75, 0.18), (1.25, 0.16), (1.5, 0.20)]:
                for s_i, note in enumerate(chord):
                    add_voice(
                        l,
                        r,
                        base + strum_t + s_i * 0.014,
                        0.45,
                        note,
                        vel,
                        pluck_h,
                        0.005,
                        6.0,
                        pan=-0.25 + s_i * 0.15,
                    )
            for r_i, note in enumerate(riff):
                add_voice(l, r, base + r_i * (2.0 / 6.0), 0.55, note, 0.24, pluck_h, 0.006, 4.2, pan=0.22)
    return finalize_stereo(l, r)


def generate_starry_nocturne() -> np.ndarray:
    """Lush slow electric-piano nocturne (C / Am / Fmaj7 / G6) for reflective stories."""
    l = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    r = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
    ep_h = [(1, 1.0), (2, 0.22), (3, 0.08)]
    voicings = [
        ([48, 55, 60, 64, 71], [76, 74]),  # Cmaj7
        ([45, 52, 57, 60, 67], [72, 71]),  # Am7
        ([41, 53, 57, 60, 64], [69, 72]),  # Fmaj7
        ([43, 50, 55, 59, 64], [71, 67]),  # G6
    ]
    for idx, (pad_notes, top_notes) in enumerate(voicings):
        base = idx * 4.0
        for p_i, note in enumerate(pad_notes):
            add_voice(l, r, base + p_i * 0.06, 4.0, note, 0.22, ep_h, 0.18, 0.55, pan=-0.3 + p_i * 0.15)
        add_voice(l, r, base + 0.75, 2.2, top_notes[0], 0.24, ep_h, 0.04, 1.3, pan=0.18)
        add_voice(l, r, base + 2.5, 1.5, top_notes[1], 0.22, ep_h, 0.04, 1.5, pan=-0.18)
    return finalize_stereo(l, r)


def write_m4a(stereo_f32: np.ndarray, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    container = av.open(str(dest), mode="w", format="ipod")
    stream = container.add_stream("aac", rate=SAMPLE_RATE)
    stream.layout = "stereo"
    stream.bit_rate = 128_000

    chunk = 1024
    pts = 0
    total = stereo_f32.shape[1]
    for start in range(0, total, chunk):
        seg = np.ascontiguousarray(stereo_f32[:, start : start + chunk])
        frame = av.AudioFrame.from_ndarray(seg, format="fltp", layout="stereo")
        frame.sample_rate = SAMPLE_RATE
        frame.pts = pts
        pts += seg.shape[1]
        for packet in stream.encode(frame):
            container.mux(packet)
    for packet in stream.encode(None):
        container.mux(packet)
    container.close()


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("app/Resources/Music")
    tracks = [
        ("warm-piano", generate_warm_piano),
        ("music-box", generate_music_box),
        ("sunny-acoustic", generate_sunny_acoustic),
        ("starry-nocturne", generate_starry_nocturne),
    ]
    for name, fn in tracks:
        stereo = fn()
        dest = out_dir / f"{name}.m4a"
        write_m4a(stereo, dest)
        digest = hashlib.sha256(dest.read_bytes()).hexdigest()
        size_kb = dest.stat().st_size / 1024.0
        # Verify decode roundtrip
        c = av.open(str(dest))
        astream = c.streams.audio[0]
        decoded = sum(f.samples for f in c.decode(audio=0))
        c.close()
        print(f"{name}.m4a: {size_kb:.1f} KB, rate={astream.rate}, ch={astream.channels}, dur={decoded/astream.rate:.3f}s, sha256={digest}")


if __name__ == "__main__":
    main()
