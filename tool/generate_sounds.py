"""Writes the four feedback sounds to app/assets/sounds/ as 16-bit mono WAV.

Original synthesized sounds, standard library only:
    python3 tool/generate_sounds.py
"""

import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "app" / "assets" / "sounds"


def note(name):
    """Frequency of a note such as 'A4' or 'C#5' (A4 = 440 Hz)."""
    steps = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4,
             "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    return 440.0 * 2 ** ((steps[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


def bell(freq, length, decay):
    """A soft bell: sine with two quiet overtones, short attack, exponential
    decay. Returns `length` seconds of samples between -1 and 1."""
    samples = []
    for i in range(int(RATE * length)):
        t = i / RATE
        attack = min(1.0, t / 0.006)
        envelope = attack * math.exp(-t / decay)
        tone = (math.sin(2 * math.pi * freq * t)
                + 0.25 * math.sin(2 * math.pi * 2 * freq * t)
                + 0.08 * math.sin(2 * math.pi * 3 * freq * t))
        samples.append(envelope * tone / 1.33)
    return samples


def mix(length, parts):
    """Adds (start seconds, samples, gain) parts into one track."""
    track = [0.0] * int(RATE * length)
    for start, samples, gain in parts:
        offset = int(RATE * start)
        for i, value in enumerate(samples[: len(track) - offset]):
            track[offset + i] += gain * value
    return track


def write(name, track, peak=0.5):
    """Normalises to `peak`, fades the last 10 ms and writes the file."""
    top = max(abs(v) for v in track) or 1.0
    fade = int(RATE * 0.01)
    frames = bytearray()
    for i, value in enumerate(track):
        scale = min(1.0, (len(track) - i) / fade)
        frames += struct.pack("<h", round(32767 * peak * scale * value / top))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(bytes(frames))


def main():
    # Correct: a bright rising fourth.
    write("correct.wav", mix(0.45, [
        (0.0, bell(note("E5"), 0.3, 0.09), 0.8),
        (0.08, bell(note("A5"), 0.37, 0.12), 1.0),
    ]))
    # Wrong: two low, soft notes stepping down; a nudge, not a buzzer.
    write("wrong.wav", mix(0.42, [
        (0.0, bell(note("E4"), 0.25, 0.08), 1.0),
        (0.12, bell(note("C4"), 0.3, 0.1), 0.9),
    ]), peak=0.4)
    # Level up: a quick major arpeggio up to the octave.
    arpeggio = ["C5", "E5", "G5", "C6"]
    write("level_up.wav", mix(0.8, [
        (0.07 * i, bell(note(n), 0.8 - 0.07 * i, 0.08 + 0.06 * (i == 3)), 1.0)
        for i, n in enumerate(arpeggio)
    ]))
    # Daily goal: a major chord with a high sparkle on top.
    write("goal.wav", mix(1.0, [
        (0.0, bell(note("C5"), 1.0, 0.25), 0.7),
        (0.0, bell(note("E5"), 1.0, 0.25), 0.6),
        (0.0, bell(note("G5"), 1.0, 0.25), 0.6),
        (0.15, bell(note("E6"), 0.85, 0.12), 0.45),
        (0.25, bell(note("G6"), 0.75, 0.1), 0.35),
    ]))


if __name__ == "__main__":
    main()
