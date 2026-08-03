#!/usr/bin/env python3
"""Verify Project Joker music format, provenance, and reproducibility."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import struct
import sys
import wave


REPO_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = REPO_ROOT / "resources" / "audio" / "music"
MANIFEST_PATH = ASSET_DIR / "manifest.json"
PROVENANCE_PATH = ASSET_DIR / "PROVENANCE.md"
GENERATOR_PATH = REPO_ROOT / "tools" / "generate_music.py"
SERVICE_PATH = REPO_ROOT / "scripts" / "audio" / "music_service.gd"

EXPECTED_FILES = {
    "glass_antechamber.wav",
    "masked_table.wav",
    "loaded_dice.wav",
    "gold_contract.wav",
    "mirror_refraction.wav",
    "faceless_protocol.wav",
}
EXPECTED_CONTEXTS = {
    "menu",
    "journey",
    "encounter",
    "encounter_gold_corridor",
    "encounter_mirror_hall",
    "encounter_faceless_hub",
}
FORBIDDEN_AUDIO_SUFFIXES = {".wav", ".ogg", ".mp3", ".flac"}
MAX_PCM_PEAK = round(32767 * (10 ** (-5.8 / 20.0))) + 1


class VerificationError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_parameters_sha(parameters: object) -> str:
    payload = json.dumps(
        parameters,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def load_manifest() -> dict:
    if not MANIFEST_PATH.is_file():
        raise VerificationError(f"Missing manifest: {MANIFEST_PATH}")
    try:
        return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise VerificationError(f"Cannot read manifest: {exc}") from exc


def verify_provenance_document() -> None:
    if not PROVENANCE_PATH.is_file():
        raise VerificationError(f"Missing provenance document: {PROVENANCE_PATH}")
    content = PROVENANCE_PATH.read_text(encoding="utf-8")
    required_phrases = (
        "OpenAI Codex",
        "procedurally synthesized",
        "no third-party samples",
        "borrowed melodies",
        "commercial",
        "legal review",
    )
    missing = [
        phrase for phrase in required_phrases
        if phrase.lower() not in content.lower()
    ]
    if missing:
        raise VerificationError(
            "PROVENANCE.md is missing required statements: "
            + ", ".join(missing)
        )


def verify_wave(path: Path, entry: dict) -> None:
    try:
        with wave.open(str(path), "rb") as wav:
            channels = wav.getnchannels()
            sample_rate = wav.getframerate()
            sample_width = wav.getsampwidth()
            frame_count = wav.getnframes()
            compression = wav.getcomptype()
            frames = wav.readframes(frame_count)
    except (OSError, wave.Error) as exc:
        raise VerificationError(f"Invalid WAV {path.name}: {exc}") from exc

    duration_ms = frame_count * 1000.0 / sample_rate
    if channels != 2:
        raise VerificationError(
            f"{path.name}: expected stereo, got {channels} channels"
        )
    if sample_rate != 32000:
        raise VerificationError(
            f"{path.name}: expected 32000 Hz, got {sample_rate}"
        )
    if sample_width != 2:
        raise VerificationError(
            f"{path.name}: expected 16-bit PCM, got {sample_width * 8}-bit"
        )
    if compression != "NONE":
        raise VerificationError(f"{path.name}: expected uncompressed PCM")
    if not 18_000.0 <= duration_ms <= 30_000.0:
        raise VerificationError(
            f"{path.name}: duration {duration_ms:.2f}ms outside 18-30s"
        )

    sample_count = len(frames) // 2
    samples = struct.unpack(f"<{sample_count}h", frames)
    peak = max(abs(value) for value in samples) if samples else 0
    if peak > MAX_PCM_PEAK:
        raise VerificationError(
            f"{path.name}: peak {peak} exceeds the -5.8 dBFS ceiling "
            f"{MAX_PCM_PEAK}"
        )

    declared_format = entry.get("format", {})
    expected_format = {
        "sample_rate": sample_rate,
        "channels": channels,
        "bit_depth": sample_width * 8,
        "duration_ms": round(duration_ms, 3),
    }
    for key, actual in expected_format.items():
        declared = declared_format.get(key)
        if isinstance(actual, float):
            if declared is None or abs(float(declared) - actual) > 0.01:
                raise VerificationError(
                    f"{path.name}: manifest {key}={declared!r}, expected {actual}"
                )
        elif declared != actual:
            raise VerificationError(
                f"{path.name}: manifest {key}={declared!r}, expected {actual}"
            )
    expected_loop = {
        "mode": "forward",
        "begin_frame": 0,
        "end_frame": frame_count,
    }
    if entry.get("loop") != expected_loop:
        raise VerificationError(f"{path.name}: full-file loop metadata mismatch")


def verify_manifest_and_assets() -> dict[str, str]:
    manifest = load_manifest()
    if manifest.get("schema_version") != 1:
        raise VerificationError("manifest schema_version must be 1")
    if manifest.get("generator", {}).get("path") != "tools/generate_music.py":
        raise VerificationError(
            "manifest generator path is not tools/generate_music.py"
        )
    if not manifest.get("generator", {}).get("version"):
        raise VerificationError("manifest generator version is missing")
    if not isinstance(manifest.get("generator", {}).get("master_seed"), int):
        raise VerificationError("manifest generator master_seed must be an integer")

    entries = manifest.get("assets")
    if not isinstance(entries, list):
        raise VerificationError("manifest assets must be a list")
    by_file = {entry.get("file"): entry for entry in entries}
    if set(by_file) != EXPECTED_FILES:
        raise VerificationError(
            "manifest asset set mismatch; "
            f"missing={sorted(EXPECTED_FILES - set(by_file))}, "
            f"extra={sorted(set(by_file) - EXPECTED_FILES)}"
        )
    contexts = {entry.get("context") for entry in entries}
    if contexts != EXPECTED_CONTEXTS:
        raise VerificationError(
            f"context set mismatch; expected={sorted(EXPECTED_CONTEXTS)}, "
            f"actual={sorted(contexts)}"
        )

    discovered_audio = {
        path.name
        for path in ASSET_DIR.rglob("*")
        if path.is_file() and path.suffix.lower() in FORBIDDEN_AUDIO_SUFFIXES
    }
    if discovered_audio != EXPECTED_FILES:
        raise VerificationError(
            "audio directory mismatch; "
            f"missing={sorted(EXPECTED_FILES - discovered_audio)}, "
            f"undeclared={sorted(discovered_audio - EXPECTED_FILES)}"
        )

    hashes: dict[str, str] = {}
    for file_name in sorted(EXPECTED_FILES):
        entry = by_file[file_name]
        if entry.get("third_party_samples") is not False:
            raise VerificationError(
                f"{file_name}: third_party_samples must be false"
            )
        if entry.get("generation_assistance") != "OpenAI Codex":
            raise VerificationError(
                f"{file_name}: generation_assistance must be OpenAI Codex"
            )
        if entry.get("commercial_review") != "procedural_no_external_samples":
            raise VerificationError(
                f"{file_name}: unexpected commercial_review status"
            )
        if not isinstance(entry.get("seed"), int):
            raise VerificationError(f"{file_name}: integer seed is missing")
        parameters = entry.get("parameters")
        if not isinstance(parameters, dict) or not parameters:
            raise VerificationError(f"{file_name}: parameters are missing")
        if entry.get("parameters_sha256") != canonical_parameters_sha(parameters):
            raise VerificationError(f"{file_name}: parameters SHA-256 mismatch")
        path = ASSET_DIR / file_name
        actual_hash = sha256_file(path)
        if entry.get("sha256") != actual_hash:
            raise VerificationError(f"{file_name}: file SHA-256 mismatch")
        verify_wave(path, entry)
        hashes[file_name] = actual_hash
    return hashes


def verify_runtime_references() -> None:
    if not SERVICE_PATH.is_file():
        raise VerificationError(f"Missing runtime service: {SERVICE_PATH}")
    content = SERVICE_PATH.read_text(encoding="utf-8")
    referenced = set(
        re.findall(r"res://resources/audio/music/([a-z0-9_]+\.wav)", content)
    )
    if referenced != EXPECTED_FILES:
        raise VerificationError(
            "runtime WAV references mismatch; "
            f"missing={sorted(EXPECTED_FILES - referenced)}, "
            f"extra={sorted(referenced - EXPECTED_FILES)}"
        )


def verify_reproduction(expected_hashes: dict[str, str]) -> None:
    if not GENERATOR_PATH.is_file():
        raise VerificationError(f"Missing generator: {GENERATOR_PATH}")
    temp_root = REPO_ROOT / "tmp"
    temp_root.mkdir(parents=True, exist_ok=True)
    output_dir = temp_root / "music_reproduction_check"
    output_dir.mkdir(parents=True, exist_ok=True)
    for child in output_dir.iterdir():
        if not child.is_file():
            raise VerificationError(
                f"Unexpected non-file in reproduction directory: {child}"
            )
        child.unlink()
    spec = importlib.util.spec_from_file_location(
        "project_joker_generate_music",
        GENERATOR_PATH,
    )
    if spec is None or spec.loader is None:
        raise VerificationError("Cannot load generator module")
    generator = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(generator)
        generator.generate(output_dir, False)
    except Exception as exc:
        raise VerificationError(f"Generator reproduction failed: {exc}") from exc
    reproduced = {
        file_name: sha256_file(output_dir / file_name)
        for file_name in sorted(EXPECTED_FILES)
    }
    if reproduced != expected_hashes:
        changed = [
            file_name
            for file_name in sorted(EXPECTED_FILES)
            if reproduced.get(file_name) != expected_hashes.get(file_name)
        ]
        raise VerificationError(
            "Reproduction hashes differ for: " + ", ".join(changed)
        )
    for child in output_dir.iterdir():
        child.unlink()
    output_dir.rmdir()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--reproduce",
        action="store_true",
        help="Regenerate into a repository temporary directory and compare hashes.",
    )
    args = parser.parse_args()
    try:
        verify_provenance_document()
        hashes = verify_manifest_and_assets()
        verify_runtime_references()
        if args.reproduce:
            verify_reproduction(hashes)
    except VerificationError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(
        f"PASS: verified {len(EXPECTED_FILES)} commercial-provenance music assets"
        + (" with reproducible hashes." if args.reproduce else ".")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
