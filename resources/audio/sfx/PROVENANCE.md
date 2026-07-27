# Project Joker SFX Provenance

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
