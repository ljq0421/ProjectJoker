# Iron Abacus Contextual Onboarding Implementation Plan

> **Implementation note:** The `writing-plans` skill was unavailable in the authoring session, so this plan was produced with the equivalent task-by-task, test-first workflow.

**Goal:** Add a first-time, dismissible five-checkpoint contextual guide to the complete Iron Abacus slice without changing gameplay state or the existing fixed base tutorial.

**Architecture:** Keep the existing base tutorial intact. Add a preserving config store, a pure five-checkpoint guide flow, and a scene-backed focus overlay. `IronAbacusSliceScreen` requests guide cards only after each phase UI is bound, while all gameplay remains owned by `IronAbacusSliceSession` and its existing child sessions.

**Tech stack:** Godot 4.6.1, typed GDScript, `ConfigFile`, `.tscn` scene composition, synchronous dependency-free tests, `Window.push_input()` interaction checks, and dual-resolution visual acceptance.

## Global constraints

- Work directly on `master`, as already authorized for this repository.
- Keep all design and plan documents staged and uncommitted.
- Preserve the existing unstaged `project.godot` modification; do not edit, stage, or commit it.
- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe`.
- Every headless Godot command passes `--log-file` to a writable path under `$env:TEMP`.
- Treat `SCRIPT ERROR`, `Failed to load script`, or a nonzero exit code as failure.
- Preserve the existing base tutorial path `44→51→44→51`.
- The guide never modifies dice, assignments, cards, deck IDs, tickets, RNG, totals, reports, phase, retry state, or rewards.
- The guide never requires a highlighted gameplay action after the player dismisses a card.
- Stable overlay hierarchy, copy containers, and buttons live in `.tscn`; scripts bind content, position frames, and emit signals.
- Every code commit uses `git commit --only` with explicit paths so staged documents remain excluded.

## Planned file map

```text
res://
  scenes/
    components/
      iron_abacus_guide_overlay.tscn
    run/
      iron_abacus_slice_screen.tscn
      single_encounter_screen.tscn
  scripts/
    ui/
      iron_abacus_slice_screen.gd
      single_encounter_screen.gd
      tutorial/
        iron_abacus_guide_flow.gd
        iron_abacus_guide_overlay.gd
        iron_abacus_guide_progress_store.gd
        tutorial_progress_store.gd
  tests/
    iron_abacus_guide_flow_test.gd
    iron_abacus_guide_progress_store_test.gd
    iron_abacus_guide_ui_contract_test.gd
    stage5_guide_input_self_check.gd
    stage5_guide_layout_self_check.gd
```

## Task 1: Preserve tutorial config sections and add advanced-guide persistence

**Files**

- Modify: `scripts/ui/tutorial/tutorial_progress_store.gd`
- Modify: `tests/tutorial_progress_store_test.gd`
- Create: `scripts/ui/tutorial/iron_abacus_guide_progress_store.gd`
- Create: `tests/iron_abacus_guide_progress_store_test.gd`

### Steps

- [x] Extend the existing base-store test with a pre-existing foreign section.
- [x] Assert `mark_done()` and `reset()` preserve that foreign section.
- [x] Run `tests/run_all.gd` and confirm the new assertion fails before production changes.
- [x] Change `TutorialProgressStore._save()` to:
  - load the existing file when present;
  - accept `ERR_FILE_NOT_FOUND` as an empty initial config;
  - return any other load error without overwriting the file;
  - update only `onboarding/done`;
  - save the merged config.
- [x] Add `IronAbacusGuideProgressStore` with section `iron_abacus_guide_v1`.
- [x] Define stable keys:
  - `dismissed`;
  - `seen_normal`;
  - `seen_shop`;
  - `seen_dealer`;
  - `seen_reward`;
  - `seen_verification`.
- [x] Give the store an in-memory snapshot that remains updated if a save attempt fails.
- [x] Implement:
  - `snapshot() -> Dictionary`;
  - `is_dismissed() -> bool`;
  - `is_seen(checkpoint_id: StringName) -> bool`;
  - `mark_seen(checkpoint_id: StringName) -> Error`;
  - `dismiss_all() -> Error`;
  - `reset() -> Error`.
- [x] Reject unknown checkpoint IDs without writing.
- [x] Treat a missing file as all-false state.
- [x] Treat a corrupt existing file as a load warning state and never overwrite it in that run.
- [x] Test all five keys, dismiss, reset, foreign-section preservation, base-section preservation, missing file, unknown ID, and corrupt file.
- [x] Remove all temporary config files created by tests.

### Verification

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-joker-guide-store.log" `
  -s res://tests/run_all.gd
```

- [x] Confirm every suite passes.
- [x] Scan the log for `SCRIPT ERROR|Failed to load script`.
- [x] Run `git diff --check`.

### Commit

```powershell
git add -- `
  scripts/ui/tutorial/tutorial_progress_store.gd `
  scripts/ui/tutorial/iron_abacus_guide_progress_store.gd `
  tests/tutorial_progress_store_test.gd `
  tests/iron_abacus_guide_progress_store_test.gd

git commit --only -m "fix: preserve contextual guide progress" -- `
  scripts/ui/tutorial/tutorial_progress_store.gd `
  scripts/ui/tutorial/iron_abacus_guide_progress_store.gd `
  tests/tutorial_progress_store_test.gd `
  tests/iron_abacus_guide_progress_store_test.gd
```

## Task 2: Add the pure five-checkpoint guide flow

**Files**

- Create: `scripts/ui/tutorial/iron_abacus_guide_flow.gd`
- Create: `tests/iron_abacus_guide_flow_test.gd`

### Steps

- [x] Write a failing flow test before the production class exists.
- [x] Define ordered checkpoint IDs:
  - `normal`;
  - `shop`;
  - `dealer`;
  - `reward`;
  - `verification`.
- [x] Define one data specification per checkpoint containing:
  - stable ID;
  - original progress index `1–5`;
  - title;
  - two-to-three-sentence instruction;
  - semantic target IDs.
- [x] Keep numeric rules exact:
  - normal cumulative target `100`;
  - success reward `2` tickets;
  - deck remains `12` cards;
  - dealer cumulative target `150`;
  - fixed reward `max(12 - unassigned_dice * 2, 0)`;
  - engraving choice is candidate → die → face;
  - the chosen die is forced to the engraved face in verification.
- [x] Implement `should_present(checkpoint_id, progress_snapshot)`.
- [x] Make `dismissed=true` suppress all checkpoints.
- [x] Make `seen_<checkpoint>=true` suppress only that checkpoint.
- [x] Track checkpoints requested in the current run so a retry cannot reopen them even when saving failed.
- [x] Implement `mark_requested()` and `reset_run_requests()`.
- [x] Return an empty result for unknown checkpoint IDs instead of inventing content.
- [x] Test order, copy fields, seen filtering, dismissed filtering, current-run deduplication, reset, and unknown IDs.

### Verification

Run `tests/run_all.gd` with a writable guide-flow log, scan the log, and run `git diff --check`.

### Commit

```powershell
git add -- `
  scripts/ui/tutorial/iron_abacus_guide_flow.gd `
  tests/iron_abacus_guide_flow_test.gd

git commit --only -m "feat: add iron abacus guide flow" -- `
  scripts/ui/tutorial/iron_abacus_guide_flow.gd `
  tests/iron_abacus_guide_flow_test.gd
```

## Task 3: Build the focus-card overlay as a reusable scene

**Files**

- Create: `scenes/components/iron_abacus_guide_overlay.tscn`
- Create: `scripts/ui/tutorial/iron_abacus_guide_overlay.gd`
- Create: `tests/iron_abacus_guide_ui_contract_test.gd`

### Scene contract

- [x] Add a full-rect `Control` root hidden by default.
- [x] Add a 45%-opacity dimmer that blocks background mouse input.
- [x] Add a full-rect focus-frame layer.
- [x] Add a scene-backed card containing:
  - progress label;
  - title label;
  - instruction label;
  - persistence warning label;
  - “不再提示” button;
  - “知道了” button.
- [x] Give all test- and script-facing nodes unique names.
- [x] Reuse the established neon theme instead of adding a second style system.

### Script contract

- [x] Write failing UI-contract assertions first.
- [x] Implement `open_card(card_spec: Dictionary, targets: Array[Control])`.
- [x] Reject an invalid spec or missing target list by remaining closed.
- [x] Create only lightweight focus-frame children at runtime; keep the stable layer and card in `.tscn`.
- [x] Convert each target's global rectangle into overlay-local coordinates.
- [x] Position the card bottom-center by default.
- [x] If the card overlaps the union of target rectangles, choose the top or bottom safe region with more space.
- [x] Clamp the final card rectangle to the viewport safe area.
- [x] Implement `close_card()` that removes focus frames and releases input.
- [x] Emit separate signals for:
  - current-card acknowledgement;
  - permanent dismissal.
- [x] Give the acknowledgement button default focus.
- [x] Map `Enter` to acknowledgement.
- [x] Map `Esc` to acknowledgement, not permanent dismissal.
- [x] Keep background input blocked until the card is fully closed.
- [x] Implement `show_persistence_warning(message)` without closing the card or changing gameplay.

### Verification

- [x] Instantiate the packed scene in the contract test.
- [x] Assert all required nodes and signals.
- [x] Verify open/close visibility and mouse-filter semantics.
- [x] Verify invalid data fails open rather than leaving a dimmer.
- [x] Verify focus frames and card bounds at 1280×720 and 1920×1080 with synthetic target controls.
- [x] Run `tests/run_all.gd`, scan the log, and run `git diff --check`.

### Commit

```powershell
git add -- `
  scenes/components/iron_abacus_guide_overlay.tscn `
  scripts/ui/tutorial/iron_abacus_guide_overlay.gd `
  tests/iron_abacus_guide_ui_contract_test.gd

git commit --only -m "feat: add contextual guide overlay" -- `
  scenes/components/iron_abacus_guide_overlay.tscn `
  scripts/ui/tutorial/iron_abacus_guide_overlay.gd `
  tests/iron_abacus_guide_ui_contract_test.gd
```

## Task 4: Connect the guide to all five slice boundaries and add replay

**Files**

- Modify: `scenes/run/iron_abacus_slice_screen.tscn`
- Modify: `scripts/ui/iron_abacus_slice_screen.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Create: `tests/stage5_guide_input_self_check.gd`

### Integration setup

- [x] Write the focused real-input self-check before wiring all five boundaries.
- [x] Add the guide overlay as the topmost child of `iron_abacus_slice_screen.tscn`.
- [x] Add exported `guide_config_path`, defaulting to `user://onboarding.cfg`.
- [x] Construct one store and one flow per screen instance.
- [x] Keep `tutorial_auto_start=false` on the embedded encounter screen.
- [x] Add a `ReplayAdvancedGuideButton` beside the existing base replay and slice-entry controls.
- [x] Use the same config path as the base tutorial entry screen.

### Boundary hooks

- [x] After normal-room binding, request `normal`.
- [x] After shop binding, request `shop`.
- [x] After dealer binding, request `dealer`.
- [x] After reward-panel binding, request `reward`.
- [x] After verification binding, request `verification`.
- [x] Defer each request until the bound controls have valid global rectangles.
- [x] Close any active card before every visibility or phase transition.

### Target resolution

- [x] Normal targets: goal label and run status.
- [x] Shop targets: ticket label, deck grid, and offer/replacement area.
- [x] Dealer targets: dealer panel and resolution panel.
- [x] Reward targets: candidate row, die row, and face grid.
- [x] Verification targets: installed die token, goal label, and resolution panel.
- [x] Resolve unique nodes from the owning child-scene root, not from the parent scene.
- [x] Treat any missing target as a developer error, mark it requested only in memory for that run, and leave gameplay interactive.

### Persistence and replay

- [x] On “知道了” or `Esc`, mark the current checkpoint seen and close.
- [x] On “不再提示”, set `dismissed=true` and close.
- [x] If saving fails, keep the in-memory decision, show the specified warning, and continue.
- [x] Make failure retry and verification retry reuse current flow request state.
- [x] Make a full ordinary slice restart preserve seen/dismissed state.
- [x] Make “重看进阶引导” reset only the advanced section and start a fresh slice.
- [x] If replay reset cannot be saved, show a warning and keep ordinary “进入六面诡局” usable.
- [x] Do not reset the base tutorial's `onboarding/done`.

### State-invariance proof

Before and after each guide interaction, capture and compare:

- [x] slice phase and failure origin;
- [x] shared RNG snapshot;
- [x] inherited deck IDs and ticket balance;
- [x] current round, cumulative total, target, and current hand;
- [x] die values, rolled values, engraving data, assignments, calibration, selection, and undo state;
- [x] committed report/event signature when present.

### Focused input verification

- [x] Prove a background click is blocked while a card is open.
- [x] Prove the same real click path works after “知道了”.
- [x] Complete normal → shop → dealer → reward → verification while acknowledging all five cards.
- [x] Prove dealer and verification retries do not reopen their cards.
- [x] Prove permanent dismissal suppresses later cards.
- [x] Prove replay restores all five cards without resetting the base tutorial.

Run the focused script with:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-joker-stage5-guide-input.log" `
  -s res://tests/stage5_guide_input_self_check.gd
```

### Commit

```powershell
git add -- `
  scenes/run/iron_abacus_slice_screen.tscn `
  scripts/ui/iron_abacus_slice_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  tests/stage5_guide_input_self_check.gd `
  tests/stage5_guide_input_self_check.gd.uid

git commit --only -m "feat: connect iron abacus contextual guide" -- `
  scenes/run/iron_abacus_slice_screen.tscn `
  scripts/ui/iron_abacus_slice_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  tests/stage5_guide_input_self_check.gd `
  tests/stage5_guide_input_self_check.gd.uid
```

## Task 5: Complete layout, visual, regression, and content acceptance

**Files**

- Create: `tests/stage5_guide_layout_self_check.gd`
- Update only if a measured defect requires it:
  - `scenes/components/iron_abacus_guide_overlay.tscn`
  - `scripts/ui/tutorial/iron_abacus_guide_overlay.gd`
  - owning scenes whose target nodes need unique names

### Layout self-check

- [x] Instantiate the real full slice at 1280×720.
- [x] Open and inspect all five cards.
- [x] Repeat at 1920×1080.
- [x] Assert overlay, dimmer, card, buttons, focus frames, and warning remain within the viewport.
- [x] Assert each card avoids the union of its target rectangles.
- [x] Assert no target is hidden by an opaque card.
- [x] Assert the overlay is above the shop, summary, reward, and encounter layers.
- [x] Assert closing a card removes every temporary focus frame.

### Visual acceptance

- [x] Capture the five real phase cards at 1280×720.
- [x] Capture the five real phase cards at 1920×1080.
- [x] Inspect all ten images for:
  - clipping;
  - overlapping text;
  - illegible dimmed content;
  - misplaced focus frames;
  - card/target overlap;
  - unclear button hierarchy.
- [x] Keep visual-capture helpers and PNGs temporary; remove them before the final commit.

### Stability

- [x] Run `stage5_guide_input_self_check.gd` three consecutive times with separate writable logs.
- [x] Scan every log for script-load errors.
- [x] Run the editor import check.
- [x] Run `tests/run_all.gd`.
- [x] Run all existing layout checks:
  - `single_encounter_layout_self_check.gd`;
  - `tutorial_layout_self_check.gd`;
  - `three_round_layout_self_check.gd`;
  - `stage5_layout_self_check.gd`;
  - `stage5_guide_layout_self_check.gd`.
- [x] Run all existing input checks:
  - `single_encounter_input_self_check.gd`;
  - `tutorial_input_self_check.gd`;
  - `three_round_input_self_check.gd`;
  - `stage5_input_self_check.gd`;
  - `stage5_guide_input_self_check.gd`.
- [x] Start the project main scene headlessly with a writable log.
- [x] Scan gameplay source for betting, chips, loans, recharging, real-money, and probability-trigger language.
- [x] Run `git diff --check` and `git diff --cached --check`.

### Final Git boundary

- [x] Confirm staged files are documentation only before the code commit.
- [x] Confirm the only unrelated unstaged file is the user's existing `project.godot`.
- [x] Commit the new layout self-check and any measured guide-layout fixes with explicit paths.
- [x] Reconfirm all design and plan documents remain staged and uncommitted.
- [x] Mark every implementation-plan checkbox complete and restage this plan without committing it.

Suggested final test commit:

```powershell
git add -- `
  tests/stage5_guide_layout_self_check.gd `
  tests/stage5_guide_layout_self_check.gd.uid

git commit --only -m "test: verify contextual guide flow" -- `
  tests/stage5_guide_layout_self_check.gd `
  tests/stage5_guide_layout_self_check.gd.uid
```

## Final acceptance summary

The implementation is complete only when:

- [x] five first-time cards appear at the approved boundaries;
- [x] “知道了”, `Enter`, and `Esc` acknowledge only the current card;
- [x] “不再提示” suppresses the complete advanced guide;
- [x] replay resets only the advanced guide and starts a fresh slice;
- [x] retries do not reopen acknowledged cards;
- [x] missing targets and persistence failures leave gameplay usable;
- [x] every guide interaction preserves the full domain snapshot;
- [x] all ten dual-resolution visual states pass inspection;
- [x] all synchronous, layout, input, import, and main-scene checks pass;
- [x] the fixed base tutorial remains `44→51→44→51`;
- [x] source remains free of new gambling-oriented mechanics or language;
- [x] code is committed directly on `master`;
- [x] documents remain staged and uncommitted;
- [x] `project.godot` remains untouched and unstaged.
