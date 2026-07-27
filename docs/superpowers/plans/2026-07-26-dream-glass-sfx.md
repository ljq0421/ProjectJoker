# Dream Glass SFX Implementation Plan

> **Target:** `project-joker/master`
>
> **Source specification:** `docs/superpowers/specs/2026-07-26-dream-glass-sfx-design.md`
>
> **Execution rule:** Preserve unrelated staged files and the existing
> `project.godot` diff. Do not commit. Stage this plan document only.

**Goal:** Add commercially traceable, procedurally generated dream-glass sound
effects to the complete core loop and confirmed UI transitions without adding
music, ambience, hover sounds, or a settings page.

**Architecture:** A persistent `SfxService` Autoload owns the cue catalog,
12-player pool, cooldowns, pitch variation, bus routing, and safe failure
behavior. UI scripts emit semantic cue IDs only after domain acceptance or a
real visibility/page transition. Sixteen generated WAV families serve the
22 semantic events through per-event pitch and volume mappings.

**Tech stack:** Godot 4.6.1, GDScript, Godot audio buses, 48 kHz mono PCM WAV,
Python standard library for deterministic synthesis and provenance validation.

## Global constraints

- Work only in `D:\Project\ProjectJoker\project-joker` on `master`.
- Do not restore, reorder, stage, or otherwise alter unrelated existing
  workspace changes.
- Merge the Autoload entry into the current `project.godot` content; preserve
  its existing unstaged diff byte-for-byte outside the new section.
- Do not add music, ambience, voice, hover/focus sounds, volume UI, persistence,
  external samples, third-party audio, or recognizable borrowed melodies.
- Do not call audio from domain models, resolvers, run state, or gameplay RNG.
- One accepted input produces at most one most-specific cue.
- A tutorial guard that blocks before the domain action remains silent.
- A rejected domain action that presents a visible reason plays only `error`.
- Generated WAV files and runtime references must be fully covered by the
  provenance manifest.
- Do not commit implementation or documents.

## Files

### Create

- `tools/generate_sfx.py`
- `tools/verify_sfx_provenance.py`
- `resources/audio/sfx/PROVENANCE.md`
- `resources/audio/sfx/manifest.json`
- `resources/audio/sfx/ui_tap.wav`
- `resources/audio/sfx/ui_back_fold.wav`
- `resources/audio/sfx/panel_open.wav`
- `resources/audio/sfx/page_transition.wav`
- `resources/audio/sfx/die_select.wav`
- `resources/audio/sfx/die_land.wav`
- `resources/audio/sfx/card_select.wav`
- `resources/audio/sfx/card_play.wav`
- `resources/audio/sfx/calibrate.wav`
- `resources/audio/sfx/undo.wav`
- `resources/audio/sfx/progress_confirm.wav`
- `resources/audio/sfx/engraving.wav`
- `resources/audio/sfx/round_commit.wav`
- `resources/audio/sfx/success.wav`
- `resources/audio/sfx/failure.wav`
- `resources/audio/sfx/error.wav`
- `default_bus_layout.tres`
- `scripts/audio/sfx_service.gd`
- `scripts/audio/sfx_access.gd`
- `tests/sfx_service_test.gd`
- `tests/sfx_ui_contract_test.gd`

### Modify

- `project.godot`
- `scripts/ui/single_encounter_screen.gd`
- `scripts/ui/shop/shop_screen.gd`
- `scripts/ui/route_choice_panel.gd`
- `scripts/ui/engraving_reward_panel.gd`
- `scripts/ui/round_summary_panel.gd`
- `scripts/ui/area_complete_panel.gd`
- `scripts/ui/gold_corridor_run_screen.gd`
- `scripts/ui/iron_abacus_slice_screen.gd`
- `scripts/ui/three_round_run_screen.gd`
- `scripts/ui/tutorial/single_encounter_tutorial.gd`
- `scripts/ui/tutorial/iron_abacus_guide_overlay.gd`

---

## Task 1: Generate original audio and prove its provenance

### Step 1.1 — Write the failing provenance verifier

Create `tools/verify_sfx_provenance.py` using only Python standard-library
modules. It must fail until the generator, manifest, provenance document, and
all 16 WAV files exist.

Checks:

- manifest schema version is `1`;
- exactly the approved 16 WAV paths are declared;
- there are no undeclared `.wav`, `.ogg`, `.mp3`, or `.flac` files below
  `resources/audio/sfx`;
- each file is mono, 48 kHz, 16-bit PCM and 40–900ms;
- each file SHA-256 matches the manifest;
- `third_party_samples` is `false`;
- `generation_assistance` is `OpenAI Codex`;
- `commercial_review` is `procedural_no_external_samples`;
- generator path, version, seed and parameter SHA-256 are present;
- `PROVENANCE.md` contains the no-third-party and legal-review statements;
- `--reproduce` regenerates into a temporary directory and compares all hashes.

Run:

```powershell
python tools/verify_sfx_provenance.py
```

Expected before generation: non-zero exit with a precise missing-manifest or
missing-asset message.

### Step 1.2 — Implement deterministic synthesis

Create `tools/generate_sfx.py` with:

- `SAMPLE_RATE = 48000`;
- fixed generator version and master seed;
- oscillator, exponential envelope, short filtered-noise, sweep, normalization,
  fade-in/fade-out, PCM conversion and WAV writer helpers;
- per-asset numeric recipes;
- `--output-dir` for reproducibility tests;
- `--write-manifest` for the canonical repository output;
- no binary input or non-standard Python package.

Sound families:

| File | Primary synthesis |
|---|---|
| `ui_tap.wav` | two short inharmonic glass partials |
| `ui_back_fold.wav` | descending glass partial plus soft reverse-like noise |
| `panel_open.wav` | airy rise ending in a quiet glass bloom |
| `page_transition.wav` | short stereo-free noise sweep with tonal landing |
| `die_select.wav` | compact crystalline pickup |
| `die_land.wav` | glass impact, low body, short high shimmer |
| `card_select.wav` | dry paper-air tick without recorded paper |
| `card_play.wav` | rising filtered noise and light tonal release |
| `calibrate.wav` | clean neutral tick designed for pitch inversion |
| `undo.wav` | descending reverse sweep |
| `progress_confirm.wav` | two-note non-melodic confirmation |
| `engraving.wav` | precise metallic-glass lock texture |
| `round_commit.wav` | weighty low pulse with crystal seal |
| `success.wav` | short original upward chord without a quoted melody |
| `failure.wav` | short downward unresolved chord |
| `error.wav` | restrained low warning pulse |

Normalize each file to at most `-3 dBFS`, remove unnecessary leading/trailing
silence, and apply click-preventing fades.

### Step 1.3 — Generate the canonical assets and metadata

Run:

```powershell
python tools/generate_sfx.py --write-manifest
```

Expected:

- exactly 16 WAV files;
- `manifest.json` contains deterministic parameters and hashes;
- `PROVENANCE.md` states that Codex assisted with generator code, audio was
  synthesized locally, no third-party samples were used, no external library
  attribution is required, and final legal review remains with the publisher.

### Step 1.4 — Pass provenance verification

Run:

```powershell
python tools/verify_sfx_provenance.py --reproduce
```

Expected: `PASS` with 16 verified commercial-provenance entries and identical
regenerated hashes.

---

## Task 2: Add buses and the persistent semantic playback service

### Step 2.1 — Write the failing service test

Create `tests/sfx_service_test.gd`. It must instantiate the service and verify:

- all 22 semantic cue IDs are registered;
- every cue resolves to an `AudioStreamWAV`;
- every cue declares the expected `UI` or `Gameplay` bus;
- `play()` returns `false` for an unknown cue;
- cooldown suppresses immediate duplicate UI/error/result cues;
- allowed rapid gameplay cues can overlap;
- player count never exceeds 12;
- `cue_started` reports the semantic cue and resolved bus;
- a local pitch RNG is owned by the service and gameplay RNG is never passed in.

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file "$env:TEMP\project-joker-sfx-service-red.log" `
  -s res://tests/sfx_service_test.gd
```

Expected before implementation: parse/load failure for the missing service.

### Step 2.2 — Create the bus layout

Create `default_bus_layout.tres` with:

- `Master` at `0 dB`;
- `SFX` at `-3 dB`, sending to `Master`;
- `UI` at `-6 dB`, sending to `SFX`;
- `Gameplay` at `-2 dB`, sending to `SFX`.

No effects or compressors are added in this pass.

### Step 2.3 — Implement `SfxService`

Create `scripts/audio/sfx_service.gd`:

- `extends Node`;
- `signal cue_started(cue_id: StringName, bus_name: StringName)`;
- preload the 16 WAV families;
- register the 22 cue IDs with stream, bus, volume, pitch range, cooldown and
  priority;
- create 12 `AudioStreamPlayer` children at `_ready()`;
- return `false` on unknown/missing cues without changing game state;
- use bus fallback to `Master` with a warning;
- prefer idle players;
- allow result/error priorities to replace only the oldest lower-priority UI
  playback;
- apply independent pitch variation;
- expose read-only catalog/pool helpers required by tests.

Create `scripts/audio/sfx_access.gd` with a static `play(context, cue_id)`
adapter. It resolves `/root/SfxService` dynamically and returns `false` when
the caller is outside the tree or a Godot `-s` self-check has no Autoload.
UI scripts use this adapter so standalone real-input checks remain compilable.

Event reuse:

- `panel_close` uses `ui_back_fold.wav`;
- `die_return` uses `die_land.wav` with higher pitch;
- `calibrate_up/down` use `calibrate.wav` with opposite pitch direction;
- `route_select` and `shop_purchase` use `progress_confirm.wav` with different
  pitch/volume;
- `engraving_select/install` use `engraving.wav` with different weight;
- `round_success` and `area_complete` use `success.wav`, with area completion
  slower and louder.

### Step 2.4 — Register the Autoload without disturbing existing changes

Patch only the new section in `project.godot`:

```ini
[autoload]

SfxService="*res://scripts/audio/sfx_service.gd"
```

Do not reorder or restore any existing lines.

### Step 2.5 — Make the focused service test green

Run the Step 2.1 command again.

Expected: `PASS sfx_service_test`.

---

## Task 3: Integrate the core encounter loop

### Step 3.1 — Add failing sound assertions to the real input path

Extend or supplement `tests/sfx_ui_contract_test.gd` to instantiate
`single_encounter_screen.tscn`, disable tutorial auto-start, subscribe to
`SfxService.cue_started`, and drive the existing real handlers.

Verify:

- die click → `die_select`;
- successful drag/click assignment → `die_place`;
- successful tray return → `die_return`;
- card selection → `card_select`;
- successfully targeted/global card → `card_play`;
- successful calibration → `calibrate_up/down`;
- successful undo → `undo`;
- first successful commit → `round_commit`;
- rejected full-lane assignment with visible reason → only `error`;
- tutorial guard rejection → no cue.

Expected before integration: assertions fail because no UI cue is emitted.

### Step 3.2 — Patch `SingleEncounterScreen` only after successful operations

In each handler, store the operation result and call `SfxService.play()` only
when the existing domain call returns true or commit changes from uncommitted to
committed.

If the domain call returns false and `session.last_error` produces a visible
error, play `error`. Return immediately without audio when `_tutorial_allows()`
is false.

Do not modify session, controller, resolver, tutorial flow, or refresh order.

### Step 3.3 — Run focused core tests

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file "$env:TEMP\project-joker-sfx-core.log" `
  -s res://tests/sfx_ui_contract_test.gd

& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file "$env:TEMP\project-joker-sfx-input.log" `
  -s res://tests/single_encounter_input_self_check.gd
```

Expected: both pass with no duplicate cue reports.

---

## Task 4: Integrate route, shop, engraving and run outcomes

### Step 4.1 — Add failing semantic transition coverage

Extend `tests/sfx_ui_contract_test.gd` with focused fixtures for:

- accepted and rejected route selection;
- shop selection, accepted purchase and rejected purchase;
- engraving selection and accepted installation;
- summary success, failure and area completion;
- transition to another page;
- repeated `show/close` calls that do not change visibility.

Expected: new assertions fail before integration.

### Step 4.2 — Add accepted-action cues

Patch:

- `route_choice_panel.gd`: UI request stays silent until its owner accepts it;
- `shop_screen.gd`: selections use the appropriate selection cue, accepted
  purchase uses `shop_purchase`, visible rejection uses `error`;
- `engraving_reward_panel.gd`: actual selection changes use
  `engraving_select`; incomplete install requests use `error`;
- `gold_corridor_run_screen.gd`: accepted route and installation use
  `route_select` and `engraving_install`;
- `iron_abacus_slice_screen.gd` and `three_round_run_screen.gd`: accepted
  transitions and outcomes use their most-specific cues;
- `round_summary_panel.gd`: choose exactly one of `round_success`,
  `round_failure`, or the appropriate neutral panel cue;
- `area_complete_panel.gd`: first real open uses `area_complete`.

Never add `ui_confirm` to a button that already produces a route, purchase,
install, result or page-transition cue.

### Step 4.3 — Add page-transition cues

Call `page_transition` immediately before successful
`change_scene_to_file()` calls. Do not emit it when validation fails or a guide
reset reports an error.

Because the service is an Autoload, verify that the player remains alive after
the old scene is freed.

### Step 4.4 — Run area and stage input checks

Run:

```powershell
$tests = @(
  'three_round_input_self_check.gd',
  'gold_corridor_input_self_check.gd',
  'stage5_input_self_check.gd'
)
foreach ($test in $tests) {
  & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
    --headless --path . `
    --log-file "$env:TEMP\project-joker-$test.log" `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all pass.

---

## Task 5: Integrate the remaining confirmed UI

### Step 5.1 — Tutorial controls

Patch:

- `single_encounter_tutorial.gd`;
- `iron_abacus_guide_overlay.gd`.

Rules:

- opening a guide from hidden state → `panel_open`;
- continue/acknowledge/finish → `ui_confirm`;
- skip/dismiss → `ui_back`;
- a programmatic close caused by a more specific gameplay action stays silent;
- repeated open/close without a visibility change stays silent.

### Step 5.2 — Generic panel and navigation actions

Cover remaining confirmed buttons in run and summary scripts:

- next/retry/return actions;
- panel open/close where no result cue already exists;
- actual scene/page transitions.

Each handler selects one cue only. Do not add a global `Button.pressed`
listener.

### Step 5.3 — Run tutorial and UI contract checks

Run:

```powershell
$tests = @(
  'tutorial_input_self_check.gd',
  'gold_corridor_guide_input_self_check.gd',
  'stage5_guide_input_self_check.gd',
  'sfx_ui_contract_test.gd'
)
foreach ($test in $tests) {
  & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
    --headless --path . `
    --log-file "$env:TEMP\project-joker-$test.log" `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all pass, with no duplicate sound-event assertions.

---

## Task 6: Full verification and listening acceptance

### Step 6.1 — Re-run commercial provenance checks

```powershell
python tools/verify_sfx_provenance.py --reproduce
```

Expected: all 16 WAV files and runtime references pass.

### Step 6.2 — Import resources through the editor

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file "$env:TEMP\project-joker-sfx-import.log" `
  --quit
```

Expected: no WAV, bus-layout, Autoload or parse error.

### Step 6.3 — Run the complete synchronous suite

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file "$env:TEMP\project-joker-sfx-run-all.log" `
  -s res://tests/run_all.gd
```

Expected: all suites pass.

### Step 6.4 — Inspect the exact diff boundary

```powershell
git diff --check
git status --short
git diff -- project.godot scripts/audio scripts/ui tests tools `
  default_bus_layout.tres resources/audio/sfx
```

Confirm:

- unrelated staged documents are unchanged;
- the pre-existing `project.godot` diff remains intact outside `[autoload]`;
- no external audio or undeclared binary exists;
- only approved scripts contain new sound calls.

### Step 6.5 — Real interaction and listening pass

Run the project in the connected Godot editor and exercise:

1. tutorial selection, drag, return, calibration, card, undo and commit;
2. three-round success and failure;
3. route, shop, dealer, engraving and area completion;
4. tutorial continue/skip and every real page transition;
5. rapid repeated valid operations and visible error cases.

Acceptance:

- sound families are distinguishable at normal listening volume;
- UI is quieter than gameplay and outcomes;
- no hover sound, double sound, clipping, abrupt cutoff or stuck playback;
- transition tails survive scene replacement;
- no cue resembles a recognizable third-party melody, game sound or brand
  identifier.

### Step 6.6 — Final handoff

Do not commit. Report:

- implemented files;
- provenance verification result;
- full test result and focused real-input results;
- any manual listening limitation;
- direct links to representative WAV files so the user can audition them.
