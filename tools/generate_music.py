#!/usr/bin/env python3
"""Deterministically synthesize Project Joker's original looping music."""

from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave


SAMPLE_RATE = 32000
GENERATOR_VERSION = "1.1.0"
MASTER_SEED = 31072026
PEAK_AMPLITUDE = 10 ** (-6.0 / 20.0)
REPO_ROOT = Path(__file__).resolve().parents[1]
CANONICAL_OUTPUT_DIR = REPO_ROOT / "resources" / "audio" / "music"

RECIPES = {
    "glass_antechamber.wav": {
        "title": "Glass Antechamber",
        "context": "menu",
        "profile": "luminous_menu",
		"seed_offset": 0,
        "tempo_bpm": 72,
        "bars": 8,
        "chords": [
            [50, 57, 64, 65],
            [50, 57, 60, 64],
            [46, 53, 57, 62],
            [46, 53, 57, 60],
            [41, 48, 52, 57],
            [41, 48, 52, 55],
            [48, 55, 62, 64],
            [48, 55, 59, 62],
        ],
        "lead": [74, 77, 81, 76, 74, 72, 69, 72, 77, 76, 74, 69, 72, 67, 69, 72],
        "bass": [38, 38, 34, 34, 29, 29, 36, 36],
    },
    "masked_table.wav": {
        "title": "Masked Table",
        "context": "journey",
        "profile": "measured_journey",
		"seed_offset": 2018,
        "tempo_bpm": 84,
        "bars": 8,
        "chords": [
            [50, 57, 60, 64],
            [50, 57, 60, 65],
            [43, 50, 55, 59],
            [43, 50, 57, 59],
            [46, 53, 57, 62],
            [46, 53, 57, 60],
            [45, 52, 55, 60],
            [45, 52, 57, 60],
        ],
        "lead": [69, 72, 74, 77, 76, 74, 69, 67, 69, 74, 72, 69, 67, 65, 67, 69],
        "bass": [38, 38, 31, 31, 34, 34, 33, 33],
    },
    "loaded_dice.wav": {
        "title": "Loaded Dice",
        "context": "encounter",
        "profile": "restrained_tension",
		"seed_offset": 1009,
        "tempo_bpm": 96,
        "bars": 8,
        "chords": [
            [50, 57, 60, 64],
            [50, 56, 60, 65],
            [46, 53, 57, 61],
            [46, 52, 57, 60],
            [43, 50, 55, 58],
            [43, 49, 55, 59],
            [45, 52, 55, 61],
            [45, 52, 57, 60],
        ],
        "lead": [74, 77, 76, 72, 73, 76, 69, 72, 70, 74, 73, 67, 69, 73, 72, 68],
        "bass": [38, 38, 34, 34, 31, 31, 33, 33],
    },
    "gold_contract.wav": {
        "title": "Gold Contract",
        "context": "encounter_gold_corridor",
        "profile": "gold_contract",
		"seed_offset": 3027,
        "tempo_bpm": 104,
        "bars": 8,
        "chords": [
            [50, 57, 62, 66],
            [50, 57, 61, 66],
            [45, 52, 57, 62],
            [45, 52, 56, 61],
            [47, 54, 59, 64],
            [47, 54, 58, 63],
            [43, 50, 55, 59],
            [43, 50, 57, 62],
        ],
        "lead": [74, 78, 81, 78, 74, 73, 69, 73, 76, 80, 83, 80, 76, 74, 71, 74],
        "bass": [38, 38, 33, 33, 35, 35, 31, 31],
    },
    "mirror_refraction.wav": {
        "title": "Mirror Refraction",
        "context": "encounter_mirror_hall",
        "profile": "mirror_refraction",
		"seed_offset": 4036,
        "tempo_bpm": 88,
        "bars": 8,
        "chords": [
            [48, 55, 60, 64],
            [47, 54, 59, 63],
            [45, 52, 57, 62],
            [43, 50, 55, 60],
            [43, 50, 55, 60],
            [45, 52, 57, 62],
            [47, 54, 59, 63],
            [48, 55, 60, 64],
        ],
        "lead": [72, 75, 79, 76, 74, 71, 69, 67, 67, 69, 71, 74, 76, 79, 75, 72],
        "bass": [36, 35, 33, 31, 31, 33, 35, 36],
    },
    "faceless_protocol.wav": {
        "title": "Faceless Protocol",
        "context": "encounter_faceless_hub",
        "profile": "faceless_protocol",
		"seed_offset": 5045,
        "tempo_bpm": 100,
        "bars": 8,
        "chords": [
            [49, 56, 60, 65],
            [49, 55, 60, 64],
            [44, 51, 56, 61],
            [46, 53, 58, 63],
            [42, 49, 54, 59],
            [45, 52, 57, 62],
            [47, 54, 59, 64],
            [44, 51, 56, 61],
        ],
        "lead": [73, 76, 80, 75, 78, 71, 74, 69, 72, 77, 70, 73, 68, 75, 71, 66],
        "bass": [37, 37, 32, 34, 30, 33, 35, 32],
    },
}


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def parameters_sha(parameters: dict) -> str:
    return hashlib.sha256(canonical_json_bytes(parameters)).hexdigest()


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def midi_frequency(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def equal_power_pan(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def note_envelope(
    position_s: float,
    duration_s: float,
    attack_s: float,
    release_s: float,
) -> float:
    attack = min(1.0, position_s / max(attack_s, 1.0 / SAMPLE_RATE))
    remaining = max(0.0, duration_s - position_s)
    release = min(1.0, remaining / max(release_s, 1.0 / SAMPLE_RATE))
    return math.sin(min(attack, release) * math.pi * 0.5) ** 2


def add_pad_note(
    channels: tuple[list[float], list[float]],
    start_s: float,
    duration_s: float,
    note: int,
    amplitude: float,
    pan: float,
    phase: float,
) -> None:
    left, right = channels
    start = int(round(start_s * SAMPLE_RATE))
    count = int(round(duration_s * SAMPLE_RATE))
    end = min(len(left), start + count)
    frequency = midi_frequency(note)
    left_gain, right_gain = equal_power_pan(pan)
    for index in range(start, end):
        local_s = (index - start) / SAMPLE_RATE
        envelope = note_envelope(local_s, duration_s, 0.18, 0.34)
        fundamental = math.sin(math.tau * frequency * local_s + phase)
        octave = math.sin(math.tau * frequency * 2.0 * local_s + phase * 0.73)
        fifth = math.sin(math.tau * frequency * 1.5 * local_s + phase * 1.21)
        slow_motion = 0.92 + 0.08 * math.sin(
            math.tau * 0.11 * local_s + phase
        )
        value = (fundamental + octave * 0.18 + fifth * 0.10)
        value *= amplitude * envelope * slow_motion
        left[index] += value * left_gain
        right[index] += value * right_gain


def add_pluck(
    channels: tuple[list[float], list[float]],
    start_s: float,
    duration_s: float,
    note: int,
    amplitude: float,
    pan: float,
    phase: float,
) -> None:
    left, right = channels
    start = int(round(start_s * SAMPLE_RATE))
    count = int(round(duration_s * SAMPLE_RATE))
    end = min(len(left), start + count)
    frequency = midi_frequency(note)
    left_gain, right_gain = equal_power_pan(pan)
    for index in range(start, end):
        local_s = (index - start) / SAMPLE_RATE
        attack = min(1.0, local_s / 0.004)
        envelope = attack * math.exp(-5.8 * local_s)
        glass = (
            math.sin(math.tau * frequency * local_s + phase)
            + 0.36 * math.sin(math.tau * frequency * 2.01 * local_s + phase * 0.5)
            + 0.16 * math.sin(math.tau * frequency * 3.98 * local_s + phase * 1.7)
        )
        value = glass * amplitude * envelope
        left[index] += value * left_gain
        right[index] += value * right_gain


def add_low_pulse(
    channels: tuple[list[float], list[float]],
    start_s: float,
    duration_s: float,
    note: int,
    amplitude: float,
) -> None:
    left, right = channels
    start = int(round(start_s * SAMPLE_RATE))
    count = int(round(duration_s * SAMPLE_RATE))
    end = min(len(left), start + count)
    frequency = midi_frequency(note)
    for index in range(start, end):
        local_s = (index - start) / SAMPLE_RATE
        envelope = min(1.0, local_s / 0.012) * math.exp(-5.2 * local_s)
        value = (
            math.sin(math.tau * frequency * local_s)
            + 0.14 * math.sin(math.tau * frequency * 2.0 * local_s)
        ) * amplitude * envelope
        left[index] += value * 0.707
        right[index] += value * 0.707


def add_air(
    channels: tuple[list[float], list[float]],
    rng: random.Random,
    start_s: float,
    duration_s: float,
    amplitude: float,
    pan: float,
) -> None:
    left, right = channels
    start = int(round(start_s * SAMPLE_RATE))
    count = int(round(duration_s * SAMPLE_RATE))
    end = min(len(left), start + count)
    left_gain, right_gain = equal_power_pan(pan)
    filtered = 0.0
    previous = 0.0
    for index in range(start, end):
        position = (index - start) / max(count - 1, 1)
        raw = rng.uniform(-1.0, 1.0)
        filtered += 0.08 * (raw - filtered)
        high = filtered - previous
        previous = filtered
        envelope = math.sin(math.pi * position) ** 2
        value = high * amplitude * envelope
        left[index] += value * left_gain
        right[index] += value * right_gain


def render_recipe(recipe: dict, seed: int) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    beat_s = 60.0 / recipe["tempo_bpm"]
    bar_s = beat_s * 4.0
    duration_s = recipe["bars"] * bar_s
    frame_count = int(round(duration_s * SAMPLE_RATE))
    channels = ([0.0] * frame_count, [0.0] * frame_count)
    profile = recipe["profile"]

    for bar, chord in enumerate(recipe["chords"]):
        chord_start = bar * bar_s
        for voice, note in enumerate(chord):
            pan = -0.66 + voice * (1.32 / max(len(chord) - 1, 1))
            add_pad_note(
                channels,
                chord_start,
                bar_s,
                note,
                0.115 if profile == "luminous_menu" else 0.095,
                pan,
                rng.random() * math.tau,
            )
        add_low_pulse(
            channels,
            chord_start,
            beat_s * (1.55 if profile == "luminous_menu" else 1.2),
            recipe["bass"][bar],
            0.20 if profile == "restrained_tension" else 0.14,
        )

    lead_step_s = duration_s / len(recipe["lead"])
    for index, note in enumerate(recipe["lead"]):
        if profile == "luminous_menu" and index % 4 == 3:
            continue
        start_s = index * lead_step_s
        add_pluck(
            channels,
            start_s,
            min(beat_s * 1.35, duration_s - start_s),
            note,
            0.115 if profile == "restrained_tension" else 0.095,
            -0.58 if index % 2 == 0 else 0.58,
            rng.random() * math.tau,
        )

    pulse_division = (
        1
        if profile in {"restrained_tension", "gold_contract"}
        else (3 if profile == "faceless_protocol" else 2)
    )
    for beat in range(recipe["bars"] * 4):
        if beat % pulse_division != 0:
            continue
        bar = beat // 4
        start_s = beat * beat_s
        add_low_pulse(
            channels,
            start_s,
            beat_s * 0.55,
            recipe["bass"][bar] + (12 if profile == "restrained_tension" else 0),
            0.075 if profile == "restrained_tension" else 0.045,
        )

    for bar in range(recipe["bars"]):
        add_air(
            channels,
            rng,
            bar * bar_s + bar_s * 0.48,
            bar_s * 0.48,
            0.055 if profile == "luminous_menu" else 0.038,
            -0.35 if bar % 2 == 0 else 0.35,
        )

    peak = max(
        max(abs(value) for value in channels[0]),
        max(abs(value) for value in channels[1]),
        1e-9,
    )
    gain = PEAK_AMPLITUDE / peak
    edge_frames = max(1, int(round(0.012 * SAMPLE_RATE)))
    for channel in channels:
        for index in range(len(channel)):
            channel[index] *= gain
        for index in range(edge_frames):
            fade = math.sin((index / edge_frames) * math.pi * 0.5) ** 2
            channel[index] *= fade
            channel[-index - 1] *= fade
    return channels


def write_wave(path: Path, channels: tuple[list[float], list[float]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = array("h")
    for left, right in zip(*channels):
        pcm.append(max(-32767, min(32767, int(round(left * 32767.0)))))
        pcm.append(max(-32767, min(32767, int(round(right * 32767.0)))))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())


def write_manifest(output_dir: Path, generated: list[dict]) -> None:
    manifest = {
        "schema_version": 1,
        "generated_on": "2026-08-03",
        "generator": {
            "path": "tools/generate_music.py",
            "version": GENERATOR_VERSION,
            "master_seed": MASTER_SEED,
            "runtime_dependencies": [],
        },
        "assets": generated,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    provenance = """# Project Joker Music Provenance

All music files in this directory were procedurally synthesized by
`tools/generate_music.py`. OpenAI Codex assisted with the generator code.

- The generator uses only mathematical oscillators, deterministic noise,
  envelopes, and Python standard-library WAV writing.
- The assets use no third-party samples, recordings, loops, sound libraries,
  borrowed melodies, or binary audio inputs.
- The short note sequences and chord voicings were created for Project Joker;
  no external composition was transcribed.
- No external audio-library attribution is required.
- The tracks are intended for commercial use by the Project Joker publisher.
- The publisher remains responsible for final legal review in its release
  jurisdictions; this provenance record is not a non-infringement warranty.

`manifest.json` records each file's generator version, deterministic seed,
parameters, format, context mapping, loop frames, and SHA-256 digest. Run:

```powershell
python tools/verify_music_provenance.py --reproduce
```

to validate the asset set and reproduce every WAV hash.
"""
    (output_dir / "PROVENANCE.md").write_text(provenance, encoding="utf-8")


def generate(output_dir: Path, include_manifest: bool) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    generated: list[dict] = []
    for index, file_name in enumerate(sorted(RECIPES)):
        recipe = RECIPES[file_name]
        seed = MASTER_SEED + int(recipe.get("seed_offset", index * 1009))
        channels = render_recipe(recipe, seed)
        path = output_dir / file_name
        write_wave(path, channels)
        frame_count = len(channels[0])
        parameters = {
            key: value
            for key, value in recipe.items()
            if key not in {"title", "context", "seed_offset"}
        }
        generated.append(
            {
                "file": file_name,
                "title": recipe["title"],
                "context": recipe["context"],
                "seed": seed,
                "parameters": parameters,
                "parameters_sha256": parameters_sha(parameters),
                "sha256": file_sha(path),
                "format": {
                    "sample_rate": SAMPLE_RATE,
                    "channels": 2,
                    "bit_depth": 16,
                    "duration_ms": round(
                        frame_count * 1000.0 / SAMPLE_RATE,
                        3,
                    ),
                },
                "loop": {
                    "mode": "forward",
                    "begin_frame": 0,
                    "end_frame": frame_count,
                },
                "third_party_samples": False,
                "generation_assistance": "OpenAI Codex",
                "commercial_review": "procedural_no_external_samples",
            }
        )
    if include_manifest:
        write_manifest(output_dir, generated)
    print(
        f"Generated {len(generated)} deterministic music assets in {output_dir}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=CANONICAL_OUTPUT_DIR,
        help="Directory receiving the generated WAV files.",
    )
    parser.add_argument(
        "--write-manifest",
        action="store_true",
        help="Also write manifest.json and PROVENANCE.md.",
    )
    args = parser.parse_args()
    generate(args.output_dir.resolve(), args.write_manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
