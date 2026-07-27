#!/usr/bin/env python3
"""Deterministically synthesize Project Joker's original dream-glass SFX."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave


SAMPLE_RATE = 48000
GENERATOR_VERSION = "1.0.0"
MASTER_SEED = 26072026
PEAK_AMPLITUDE = 10 ** (-3.2 / 20.0)
REPO_ROOT = Path(__file__).resolve().parents[1]
CANONICAL_OUTPUT_DIR = REPO_ROOT / "resources" / "audio" / "sfx"

RECIPES = {
    "ui_tap.wav": {
        "duration_ms": 90,
        "profile": "glass_tap",
        "frequencies": [1680.0, 2730.0, 4210.0],
        "decays": [31.0, 42.0, 55.0],
        "amplitudes": [0.72, 0.38, 0.18],
        "cue_ids": ["ui_confirm"],
    },
    "ui_back_fold.wav": {
        "duration_ms": 150,
        "profile": "fold_down",
        "sweep": [2280.0, 820.0],
        "noise": 0.10,
        "cue_ids": ["ui_back", "panel_close"],
    },
    "panel_open.wav": {
        "duration_ms": 360,
        "profile": "bloom",
        "sweep": [430.0, 1120.0],
        "shimmer": [1940.0, 3070.0],
        "cue_ids": ["panel_open"],
    },
    "page_transition.wav": {
        "duration_ms": 420,
        "profile": "whoosh_land",
        "sweep": [310.0, 920.0],
        "landing": [610.0, 970.0],
        "cue_ids": ["page_transition"],
    },
    "die_select.wav": {
        "duration_ms": 105,
        "profile": "crystal_pickup",
        "frequencies": [980.0, 1870.0, 2890.0],
        "cue_ids": ["die_select"],
    },
    "die_land.wav": {
        "duration_ms": 230,
        "profile": "crystal_impact",
        "body": [176.0, 352.0],
        "shimmer": [790.0, 1370.0, 2380.0],
        "cue_ids": ["die_place", "die_return"],
    },
    "card_select.wav": {
        "duration_ms": 90,
        "profile": "air_tick",
        "frequency": 2860.0,
        "noise": 0.16,
        "cue_ids": ["card_select"],
    },
    "card_play.wav": {
        "duration_ms": 270,
        "profile": "air_release",
        "sweep": [760.0, 1710.0],
        "noise": 0.18,
        "cue_ids": ["card_play"],
    },
    "calibrate.wav": {
        "duration_ms": 85,
        "profile": "calibration_tick",
        "frequencies": [1160.0, 2320.0],
        "cue_ids": ["calibrate_up", "calibrate_down"],
    },
    "undo.wav": {
        "duration_ms": 270,
        "profile": "reverse_sweep",
        "sweep": [1880.0, 410.0],
        "noise": 0.12,
        "cue_ids": ["undo"],
    },
    "progress_confirm.wav": {
        "duration_ms": 300,
        "profile": "double_confirm",
        "notes": [620.0, 930.0],
        "cue_ids": ["route_select", "shop_purchase"],
    },
    "engraving.wav": {
        "duration_ms": 330,
        "profile": "precision_lock",
        "impact": 2180.0,
        "body": [655.0, 988.0],
        "cue_ids": ["engraving_select", "engraving_install"],
    },
    "round_commit.wav": {
        "duration_ms": 440,
        "profile": "crystal_seal",
        "body": [118.0, 236.0],
        "seal": [520.0, 780.0, 1310.0],
        "cue_ids": ["round_commit"],
    },
    "success.wav": {
        "duration_ms": 680,
        "profile": "success_chord",
        "frequencies": [523.25, 659.25, 783.99, 1567.98],
        "cue_ids": ["round_success", "area_complete"],
    },
    "failure.wav": {
        "duration_ms": 620,
        "profile": "failure_chord",
        "starts": [466.16, 392.0, 329.63],
        "ends": [415.30, 349.23, 277.18],
        "cue_ids": ["round_failure"],
    },
    "error.wav": {
        "duration_ms": 190,
        "profile": "restrained_warning",
        "frequencies": [174.0, 226.0, 452.0],
        "cue_ids": ["error"],
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


def ease_out_exponential(position: float, decay: float) -> float:
    return math.exp(-decay * max(position, 0.0))


def smoothstep(position: float) -> float:
    position = max(0.0, min(1.0, position))
    return position * position * (3.0 - 2.0 * position)


def add_tone(
    samples: list[float],
    start_s: float,
    duration_s: float,
    frequency_start: float,
    frequency_end: float | None = None,
    amplitude: float = 1.0,
    decay: float = 8.0,
    attack_s: float = 0.003,
    phase: float = 0.0,
) -> None:
    start = max(0, int(round(start_s * SAMPLE_RATE)))
    count = max(1, int(round(duration_s * SAMPLE_RATE)))
    end = min(len(samples), start + count)
    frequency_end = frequency_start if frequency_end is None else frequency_end
    oscillator_phase = phase
    previous_frequency = frequency_start
    for index in range(start, end):
        local_index = index - start
        t = local_index / SAMPLE_RATE
        position = local_index / max(count - 1, 1)
        frequency = frequency_start + (frequency_end - frequency_start) * smoothstep(
            position
        )
        if local_index > 0:
            oscillator_phase += math.tau * (
                previous_frequency + frequency
            ) * 0.5 / SAMPLE_RATE
        previous_frequency = frequency
        attack = min(1.0, t / max(attack_s, 1.0 / SAMPLE_RATE))
        envelope = attack * ease_out_exponential(t, decay)
        samples[index] += math.sin(oscillator_phase) * amplitude * envelope


def add_noise(
    samples: list[float],
    rng: random.Random,
    start_s: float,
    duration_s: float,
    amplitude: float,
    decay: float,
    attack_s: float = 0.002,
    color: float = 0.32,
    reverse_envelope: bool = False,
) -> None:
    start = max(0, int(round(start_s * SAMPLE_RATE)))
    count = max(1, int(round(duration_s * SAMPLE_RATE)))
    end = min(len(samples), start + count)
    filtered = 0.0
    previous = 0.0
    for index in range(start, end):
        local_index = index - start
        t = local_index / SAMPLE_RATE
        position = local_index / max(count - 1, 1)
        raw = rng.uniform(-1.0, 1.0)
        filtered += color * (raw - filtered)
        high = filtered - previous
        previous = filtered
        attack = min(1.0, t / max(attack_s, 1.0 / SAMPLE_RATE))
        if reverse_envelope:
            envelope = smoothstep(position) * (1.0 - 0.65 * position)
        else:
            envelope = attack * ease_out_exponential(t, decay)
        samples[index] += high * amplitude * envelope


def render_recipe(file_name: str, recipe: dict, seed: int) -> list[float]:
    duration_s = recipe["duration_ms"] / 1000.0
    samples = [0.0] * int(round(duration_s * SAMPLE_RATE))
    rng = random.Random(seed)
    profile = recipe["profile"]

    if profile == "glass_tap":
        for frequency, decay, amplitude in zip(
            recipe["frequencies"], recipe["decays"], recipe["amplitudes"]
        ):
            add_tone(
                samples,
                0.0,
                duration_s,
                frequency,
                amplitude=amplitude,
                decay=decay,
                phase=rng.random() * math.tau,
            )
        add_noise(samples, rng, 0.0, 0.026, 0.12, 82.0)
    elif profile == "fold_down":
        add_tone(
            samples,
            0.0,
            duration_s,
            recipe["sweep"][0],
            recipe["sweep"][1],
            0.72,
            15.0,
        )
        add_noise(
            samples,
            rng,
            0.0,
            duration_s * 0.8,
            recipe["noise"],
            13.0,
            reverse_envelope=True,
        )
    elif profile == "bloom":
        add_noise(
            samples, rng, 0.0, 0.24, 0.20, 4.5, 0.08, reverse_envelope=True
        )
        add_tone(
            samples,
            0.015,
            0.30,
            recipe["sweep"][0],
            recipe["sweep"][1],
            0.40,
            6.5,
            0.05,
        )
        for offset, frequency in enumerate(recipe["shimmer"]):
            add_tone(
                samples,
                0.145 + offset * 0.018,
                0.20,
                frequency,
                amplitude=0.28 / (offset + 1),
                decay=15.0,
                attack_s=0.008,
            )
    elif profile == "whoosh_land":
        add_noise(
            samples, rng, 0.0, 0.30, 0.42, 3.3, 0.12, reverse_envelope=True
        )
        add_tone(
            samples,
            0.04,
            0.31,
            recipe["sweep"][0],
            recipe["sweep"][1],
            0.22,
            4.0,
            0.08,
        )
        for frequency in recipe["landing"]:
            add_tone(
                samples,
                0.255,
                0.16,
                frequency,
                amplitude=0.30,
                decay=13.0,
            )
    elif profile == "crystal_pickup":
        for index, frequency in enumerate(recipe["frequencies"]):
            add_tone(
                samples,
                index * 0.004,
                duration_s - index * 0.004,
                frequency,
                amplitude=0.62 / (index + 1),
                decay=25.0 + index * 8.0,
            )
        add_noise(samples, rng, 0.0, 0.025, 0.10, 90.0)
    elif profile == "crystal_impact":
        add_noise(samples, rng, 0.0, 0.055, 0.30, 54.0)
        for index, frequency in enumerate(recipe["body"]):
            add_tone(
                samples,
                0.0,
                0.17,
                frequency,
                amplitude=0.62 / (index + 1),
                decay=18.0 + index * 5.0,
            )
        for index, frequency in enumerate(recipe["shimmer"]):
            add_tone(
                samples,
                0.002 + index * 0.004,
                duration_s,
                frequency,
                amplitude=0.38 / (index + 1),
                decay=18.0 + index * 7.0,
            )
    elif profile == "air_tick":
        add_noise(samples, rng, 0.0, duration_s, recipe["noise"], 37.0)
        add_tone(
            samples,
            0.0,
            duration_s,
            recipe["frequency"],
            amplitude=0.48,
            decay=38.0,
        )
    elif profile == "air_release":
        add_noise(
            samples, rng, 0.0, duration_s * 0.78, recipe["noise"], 8.0, 0.035
        )
        add_tone(
            samples,
            0.015,
            duration_s,
            recipe["sweep"][0],
            recipe["sweep"][1],
            0.50,
            8.0,
            0.028,
        )
        add_tone(samples, 0.14, 0.12, 2460.0, amplitude=0.16, decay=23.0)
    elif profile == "calibration_tick":
        for index, frequency in enumerate(recipe["frequencies"]):
            add_tone(
                samples,
                0.0,
                duration_s,
                frequency,
                amplitude=0.66 / (index + 1),
                decay=33.0 + index * 8.0,
            )
    elif profile == "reverse_sweep":
        add_noise(
            samples,
            rng,
            0.0,
            0.19,
            recipe["noise"],
            6.0,
            0.06,
            reverse_envelope=True,
        )
        add_tone(
            samples,
            0.0,
            duration_s,
            recipe["sweep"][0],
            recipe["sweep"][1],
            0.64,
            6.8,
            0.012,
        )
    elif profile == "double_confirm":
        for index, frequency in enumerate(recipe["notes"]):
            start = index * 0.105
            add_tone(
                samples,
                start,
                0.18,
                frequency,
                amplitude=0.55,
                decay=13.0,
            )
            add_tone(
                samples,
                start,
                0.16,
                frequency * 2.03,
                amplitude=0.16,
                decay=19.0,
            )
    elif profile == "precision_lock":
        add_tone(
            samples,
            0.0,
            0.085,
            recipe["impact"],
            amplitude=0.45,
            decay=34.0,
        )
        add_noise(samples, rng, 0.0, 0.045, 0.16, 60.0)
        for index, frequency in enumerate(recipe["body"]):
            add_tone(
                samples,
                0.095 + index * 0.018,
                0.22,
                frequency,
                amplitude=0.52 / (index + 1),
                decay=12.0,
            )
    elif profile == "crystal_seal":
        add_noise(samples, rng, 0.0, 0.07, 0.24, 42.0)
        for index, frequency in enumerate(recipe["body"]):
            add_tone(
                samples,
                0.0,
                0.33,
                frequency,
                amplitude=0.63 / (index + 1),
                decay=9.0 + index * 3.0,
            )
        for index, frequency in enumerate(recipe["seal"]):
            add_tone(
                samples,
                0.055,
                duration_s - 0.055,
                frequency,
                amplitude=0.34 / (1.0 + index * 0.35),
                decay=11.0 + index * 3.0,
            )
    elif profile == "success_chord":
        for index, frequency in enumerate(recipe["frequencies"]):
            start = 0.018 * index
            add_tone(
                samples,
                start,
                duration_s - start,
                frequency * 0.985,
                frequency,
                0.44 / (1.0 + index * 0.30),
                4.8 + index,
                0.012,
            )
        add_noise(samples, rng, 0.0, 0.11, 0.08, 31.0)
    elif profile == "failure_chord":
        for index, (start_frequency, end_frequency) in enumerate(
            zip(recipe["starts"], recipe["ends"])
        ):
            add_tone(
                samples,
                0.018 * index,
                duration_s - 0.018 * index,
                start_frequency,
                end_frequency,
                0.50 / (1.0 + index * 0.25),
                4.5 + index,
                0.01,
            )
        add_noise(samples, rng, 0.0, 0.09, 0.09, 27.0)
    elif profile == "restrained_warning":
        for index, frequency in enumerate(recipe["frequencies"]):
            add_tone(
                samples,
                0.0,
                duration_s,
                frequency,
                frequency * 0.96,
                0.54 / (1.0 + index * 0.45),
                15.0 + index * 4.0,
            )
        add_noise(samples, rng, 0.0, 0.045, 0.11, 48.0)
    else:
        raise ValueError(f"Unknown synthesis profile for {file_name}: {profile}")

    return finalize_samples(samples)


def finalize_samples(samples: list[float]) -> list[float]:
    fade_frames = max(1, int(round(0.003 * SAMPLE_RATE)))
    for index in range(min(fade_frames, len(samples))):
        gain = index / fade_frames
        samples[index] *= gain
        samples[-1 - index] *= gain
    peak = max(abs(sample) for sample in samples) if samples else 1.0
    if peak > 0.0:
        gain = PEAK_AMPLITUDE / peak
        samples = [max(-1.0, min(1.0, sample * gain)) for sample in samples]
    return samples


def write_wave(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = [
        max(-32767, min(32767, int(round(sample * 32767.0))))
        for sample in samples
    ]
    frames = struct.pack(f"<{len(pcm)}h", *pcm)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(frames)


def write_manifest(output_dir: Path, generated: list[dict]) -> None:
    manifest = {
        "schema_version": 1,
        "generated_on": "2026-07-26",
        "generator": {
            "path": "tools/generate_sfx.py",
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
    provenance = """# Project Joker SFX Provenance

All audio files in this directory were procedurally synthesized by
`tools/generate_sfx.py`. OpenAI Codex assisted with the generator code.

- The generator uses only mathematical oscillators, deterministic noise,
  envelopes, and Python standard-library WAV writing.
- The assets use no third-party samples, recordings, loops, sound libraries,
  borrowed melodies, or binary audio inputs.
- No external audio-library attribution is required.
- The sounds are intended for commercial use by the Project Joker publisher.
- The publisher remains responsible for final legal review in its release
  jurisdictions; this provenance record is not a non-infringement warranty.

`manifest.json` records each file's generator version, deterministic seed,
parameters, format, cue mapping, and SHA-256 digest. Run:

```powershell
python tools/verify_sfx_provenance.py --reproduce
```

to validate the asset set and reproduce every WAV hash.
"""
    (output_dir / "PROVENANCE.md").write_text(provenance, encoding="utf-8")


def generate(output_dir: Path, include_manifest: bool) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    generated: list[dict] = []
    for index, file_name in enumerate(sorted(RECIPES)):
        recipe = RECIPES[file_name]
        seed = MASTER_SEED + index * 1009
        samples = render_recipe(file_name, recipe, seed)
        path = output_dir / file_name
        write_wave(path, samples)
        parameters = {
            key: value for key, value in recipe.items() if key != "cue_ids"
        }
        generated.append(
            {
                "file": file_name,
                "cue_ids": recipe["cue_ids"],
                "seed": seed,
                "parameters": parameters,
                "parameters_sha256": parameters_sha(parameters),
                "sha256": file_sha(path),
                "format": {
                    "sample_rate": SAMPLE_RATE,
                    "channels": 1,
                    "bit_depth": 16,
                    "duration_ms": round(
                        len(samples) * 1000.0 / SAMPLE_RATE, 3
                    ),
                },
                "third_party_samples": False,
                "generation_assistance": "OpenAI Codex",
                "commercial_review": "procedural_no_external_samples",
            }
        )
    if include_manifest:
        write_manifest(output_dir, generated)
    print(f"Generated {len(generated)} deterministic SFX assets in {output_dir}")


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
