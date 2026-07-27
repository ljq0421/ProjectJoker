# Settings Overlay Implementation Plan

> **Target:** `project-joker/master`
>
> **Source specification:** `docs/superpowers/specs/2026-07-26-settings-overlay-design.md`
>
> **Execution rule:** Preserve unrelated staged files and the existing
> `project.godot` diff. Do not commit. Stage this plan document only.

**Goal:** Add a persistent dream-glass settings overlay to all five main
gameplay pages, with immediate audio controls and safely confirmed display
controls that preserve the active run.

**Architecture:** `SettingsService` owns validated runtime settings and
coordinates a pure `SettingsStore` plus an injectable
`DisplaySettingsAdapter`. A reusable, scene-first `SettingsLayer` contains the
top-right entry button, pause-safe full-screen overlay, audio page, display
page, and display confirmation layer. Main scenes only instance the component.

**Tech stack:** Godot 4.6.1, GDScript, ConfigFile, AudioServer, DisplayServer,
existing dream-glass Theme and semantic SFX service.

## Global constraints

- Work only in `D:\Project\ProjectJoker\project-joker` on `master`.
- Do not restore, reorder, stage, or otherwise alter unrelated changes.
- Preserve the current unstaged sound implementation and pre-existing
  `project.godot` edits.
- Do not add music, exclusive fullscreen, render scaling, graphics quality,
  controls, accessibility, gameplay settings, hover sounds, or global button
  interception.
- Stable structure and visible controls belong in `.tscn`; scripts bind state,
  validate input, apply settings, and refresh labels.
- The overlay must restore the exact pause value that existed before opening.
- Unconfirmed display settings must never reach the persistent file.
- Do not commit implementation or documents.

## Files

### Create

- `scripts/settings/settings_store.gd`
- `scripts/settings/display_settings_adapter.gd`
- `scripts/settings/settings_service.gd`
- `scripts/ui/settings_layer.gd`
- `scenes/components/settings_layer.tscn`
- `tests/settings_service_test.gd`
- `tests/settings_ui_contract_test.gd`
- `tests/settings_input_self_check.gd`
- `tests/settings_layout_self_check.gd`

### Modify

- `project.godot`
- `tests/run_all.gd`
- `scenes/run/single_encounter_screen.tscn`
- `scenes/run/three_round_run_screen.tscn`
- `scenes/run/gold_corridor_run_screen.tscn`
- `scenes/run/iron_abacus_slice_screen.tscn`
- `scenes/shop/shop_screen.tscn`

---

## Task 1: Build validated persistent settings primitives

### Step 1.1 — Write the failing service/store test

Create `tests/settings_service_test.gd`. The existing `tests/run_all.gd`
discovers every `*_test.gd` suite automatically; do not add a manual registry.

Cover:

- schema defaults match `Master`, `UI`, and `Gameplay` bus defaults;
- single invalid values fall back without discarding valid siblings;
- an unparseable file returns defaults without overwriting the file;
- explicit save writes a complete versioned config;
- reload returns the saved values;
- temporary save failure preserves the old file;
- linear volume, zero, mute, and last-audible behavior;
- display drafts do not mutate confirmed settings;
- display apply, readback, confirm, manual revert, and timeout revert;
- display values are saved only after confirmation;
- unsupported VSync and invalid window sizes restore the prior snapshot.

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file tmp\settings-service-red.log `
  -s res://tests/run_all.gd
```

Expected before implementation: the settings service suite reports missing
scripts while the pre-existing suites remain green.

### Step 1.2 — Implement `SettingsStore`

Create `scripts/settings/settings_store.gd` as a `RefCounted` unit with an
injectable config path.

Responsibilities:

- expose schema version `1`;
- load defaults first, then validate each ConfigFile value by type/range;
- accept only `windowed` and `fullscreen`;
- accept only the three approved resolutions;
- retain a parse-failure status without overwriting the source;
- write to a peer temporary file and replace the real file only after a
  successful save;
- report structured load/save errors without touching UI.

### Step 1.3 — Implement `DisplaySettingsAdapter`

Create `scripts/settings/display_settings_adapter.gd`.

Wrap:

- window mode get/set;
- window size get/set;
- current screen and usable rectangle;
- window centering;
- VSync get/set;
- platform capability/readback.

Keep the interface small enough for a fake adapter in tests.

---

## Task 2: Implement the persistent `SettingsService`

### Step 2.1 — Register the Autoload

Patch only the existing `[autoload]` section in `project.godot`:

```ini
[autoload]

SfxService="*res://scripts/audio/sfx_service.gd"
SettingsService="*res://scripts/settings/settings_service.gd"
```

Do not modify other existing project settings.

### Step 2.2 — Implement audio settings

Create `scripts/settings/settings_service.gd`.

Audio API:

- getters for linear values, mute state, and displayed percentages;
- `set_audio_linear(channel, value)`;
- `set_audio_muted(channel, muted)`;
- `restore_audio_defaults()`;
- `finish_audio_adjustment(channel)` to save and emit one preview request.

Rules:

- map `master`, `ui`, and `gameplay` to the correct buses;
- keep `SFX` fixed at `-3 dB`;
- clamp linear values to `0.0..1.0`;
- use bus mute for explicit mute and `-80 dB` for zero;
- retain the last value above zero;
- skip missing buses with a structured error;
- save on drag end, mute change, and reset only.

### Step 2.3 — Implement display drafts and safe confirmation

Display API:

- read confirmed settings;
- begin/edit/discard a display draft;
- query available resolution options;
- apply the draft and create a runtime snapshot;
- confirm and save;
- revert manually or on timeout;
- expose remaining confirmation seconds.

Rules:

- ordinary fullscreen follows the monitor and disables resolution editing;
- windowed mode uses only approved sizes that fit the usable screen;
- no fitting preset disables applying windowed mode with a visible reason;
- readback mismatch and unsupported VSync revert immediately;
- the 10-second timer processes while the tree is paused;
- startup applies audio immediately and display settings after the root window
  is ready.

### Step 2.4 — Make the focused service test green

Run the Step 1.1 command.

Expected: `PASS settings_service_test`.

---

## Task 3: Build the scene-first settings overlay

### Step 3.1 — Write the failing UI contract test

Create `tests/settings_ui_contract_test.gd`; it is auto-discovered by the
existing runner.

Verify:

- `settings_layer.tscn` loads with the existing dream-glass Theme;
- the `96 x 48` top-right entry button is anchored inside the safe margin;
- the full-screen blocker uses stop mouse filtering;
- audio and display sidebar buttons exist;
- all three slider/value/mute rows exist in the scene;
- display mode, resolution, VSync, defaults, and apply controls exist;
- display confirmation layer has keep/revert controls;
- the script does not directly reference `AudioServer`, `DisplayServer`, or
  `ConfigFile`;
- the five approved main scenes instance the same PackedScene.

Expected before the scene exists: load/contract failures.

### Step 3.2 — Create `settings_layer.tscn`

Build the stable structure in the scene:

- `CanvasLayer` root at a high layer;
- top-right `SettingsButton`;
- initially hidden full-screen blocker;
- dark translucent background and glass shell;
- title/close header;
- left navigation with audio and display buttons;
- audio page with three explicit rows;
- display page with mode/resolution selectors, VSync, defaults, and apply;
- status/error label;
- topmost display confirmation layer with countdown, keep, and revert.

Reuse `resources/themes/neon_dream_theme.tres`. Do not create runtime layout
trees in script.

### Step 3.3 — Implement `settings_layer.gd`

Responsibilities:

- bind controls to `SettingsService`;
- open once, record prior pause state, pause, focus, and play `panel_open`;
- close once, revert pending display state, restore prior pause state, and play
  `panel_close`;
- consume all input while open;
- allow `Esc` to close only while open;
- update volume immediately but preview/save once on drag end;
- refresh mute and percentage labels;
- edit display drafts without applying;
- show disabled full-screen resolution semantics;
- show apply errors and the 10-second confirmation layer;
- play only the approved semantic SFX.

### Step 3.4 — Make the UI contract test green

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file tmp\settings-ui-contract.log `
  -s res://tests/run_all.gd
```

Expected: `PASS settings_service_test.gd`,
`PASS settings_ui_contract_test.gd`, and no regression in existing suites.

---

## Task 4: Integrate all five main pages

### Step 4.1 — Instance the shared component

Add the same PackedScene external resource and one `SettingsLayer` instance to:

- `single_encounter_screen.tscn`;
- `three_round_run_screen.tscn`;
- `gold_corridor_run_screen.tscn`;
- `iron_abacus_slice_screen.tscn`;
- `shop_screen.tscn`.

Do not duplicate settings controls or settings logic in host scenes.

### Step 4.2 — Verify popup/tutorial layering

Confirm that the settings entry remains reachable above ordinary page content,
and the opened overlay sits above tutorials, summaries, shops, and reward
panels without modifying their logic.

---

## Task 5: Real input, layout, and full verification

### Step 5.1 — Add real-input self-check

Create `tests/settings_input_self_check.gd`.

Drive actual mouse/keyboard events to verify:

- top-right click opens the overlay and pauses the tree;
- a click aimed at the underlying encounter does not change its state;
- audio/display navigation changes visible pages;
- slider adjustment updates runtime audio;
- drag end produces one preview request;
- mute toggles preserve/restores last audible value;
- display apply opens confirmation;
- revert and timeout restore the fake runtime snapshot;
- `Esc` closes and restores the prior pause value;
- hover/focus motion emits no SFX.

### Step 5.2 — Add layout self-check

Create `tests/settings_layout_self_check.gd`.

At `1280 x 720`, `1600 x 900`, and `1920 x 1080`, verify:

- entry button bounds;
- blocker coverage;
- glass shell and sidebar bounds;
- labels and controls remain inside their parents;
- confirmation layer covers settings controls;
- no control overlaps the top-right entry while closed.

### Step 5.3 — Import and run focused checks

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --editor --path . `
  --log-file tmp\settings-import.log `
  --quit

$tests = @(
  'settings_input_self_check.gd',
  'settings_layout_self_check.gd'
)
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file tmp\settings-run-all-focused.log `
  -s res://tests/run_all.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($test in $tests) {
  & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
    --headless --path . `
    --log-file "tmp\$test.log" `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all focused checks pass.

### Step 5.4 — Run all existing tests and main-scene smoke

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file tmp\settings-run-all.log `
  -s res://tests/run_all.gd

& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . `
  --log-file tmp\settings-main-smoke.log `
  --quit-after 3
```

Expected: all suites pass and the main scene exits successfully.

### Step 5.5 — Visible acceptance

Run a visible window and verify:

1. settings opens from each main page without losing the active run;
2. audio sliders and mute toggles audibly match their labels;
3. window mode and all fitting window resolutions apply and center;
4. fullscreen follows the monitor and disables resolution selection;
5. VSync applies or presents a truthful platform limitation;
6. keep/revert/timeout behaves exactly as documented;
7. no clipping, truncation, hidden focus, hover sound, duplicate cue, or
   underlying input leak occurs.

### Step 5.6 — Diff and staging boundary

```powershell
git diff --check
git diff --cached --check
git status --short
```

Confirm:

- existing staged documents remain staged and unchanged;
- only this implementation plan and its source spec are newly staged;
- settings code/assets/tests remain unstaged;
- `.superpowers/brainstorm/` remains outside the staged set;
- no commit exists.
