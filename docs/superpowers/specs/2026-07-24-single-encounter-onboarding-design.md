# Single-Encounter Onboarding Design

## 1. Goal

Add a first-run, skippable, replayable onboarding flow to the existing
three-lane single encounter. The tutorial must teach the actual interaction
paths and the deterministic strategy loop without automating the solution for
the player.

The tutorial teaches:

- real die drag/drop;
- click-die-then-click-lane placement;
- completing the three rule lanes;
- calibration;
- table-target card play;
- reading the live resolution trace;
- undo;
- exact preview/commit consistency.

## 2. Scope and Constraints

### In scope

- Start automatically when onboarding has not been completed or skipped.
- Allow the player to skip at any time.
- Persist only onboarding completion under `user://onboarding.cfg`.
- Provide a permanent `重看引导` control.
- Reset the deterministic teaching encounter before replaying onboarding.
- Highlight allowed controls and block unrelated gameplay actions.
- Advance action steps only after accepted real gameplay operations.
- Add headless persistence, state-machine, layout, and real-input checks.

### Out of scope

- General run saves or save migration.
- A settings screen.
- Localization infrastructure beyond the current Chinese prototype.
- Voiceover, character animation, audiovisual polish, or mobile layout.
- Rewards for completing or skipping onboarding.
- Changes to the scoring formula, fixture values, or encounter target.
- Changes to the current 1920×1080 logical viewport and 1280×720 display
  override.

## 3. First-Run and Replay Contract

`TutorialProgressStore` owns one boolean value:

```ini
[onboarding]
done=true
```

The default path is `user://onboarding.cfg`. Automated tests inject a path
under `OS.get_temp_dir()` so they never depend on or overwrite real player
state.

Behavior:

1. Missing file or `done=false`: start onboarding after the encounter screen
   finishes its initial render.
2. Completing the final step: write `done=true`.
3. Skipping: write `done=true`; skipping never grants a reward or modifies the
   encounter.
4. Selecting `重看引导`: write `done=false`, reset the encounter to
   `SingleEncounterFixture`, then start at the welcome step.
5. Exiting midway after selecting replay leaves `done=false`, so onboarding
   starts again next launch.

The replay button tooltip and confirmation copy explicitly state that replay
resets the current teaching encounter.

## 4. Tutorial Flow

The tutorial uses eleven ordered steps. Action steps advance automatically;
informational steps expose a `继续` button.

| Step | Instruction | Allowed targets/actions | Completion |
|---|---|---|---|
| 0 | Recognize the three rule lanes and resolution trace | `继续`, `跳过` | Press `继续` |
| 1 | Drag die 1 into the left lane | die `d1`, left lane, drag assignment | Left lane contains `d1` through a drag action |
| 2 | Click die 6, then click the left lane | die `d6`, left lane, click assignment | Left lane contains `d1,d6` through click placement |
| 3 | Complete the middle lane with 2, 3, 4 | dice `d2,d3,d4`, middle lane | Middle lane contains exactly `d2,d3,d4` |
| 4 | Calibrate die 5 to 4 and place it right | die `d5`, `点数 -1`, right lane | `d5.value=4` and right lane contains `d5` |
| 5 | Play `映射` on the left lane | card index 1, left lane | Card is used and preview is 51 |
| 6 | Read the ordered prediction | resolution panel, `继续` | Press `继续` while preview is 51 |
| 7 | Undo the card | `撤销` | Card is restored and preview is 44 |
| 8 | Reapply `映射` to the left lane | card index 1, left lane | Preview returns to 51 |
| 9 | Commit the round | `确认结算` | Controller is committed at 51 |
| 10 | Completion summary | `完成` | Persist `done=true` and close |

Repeated placement inside step 3 and multi-action calibration inside step 4
remain within one conceptual lesson. The callout copy updates within the step
to name the next required sub-action.

## 5. Architecture

### 5.1 `TutorialProgressStore`

A small `RefCounted` service that loads, saves, resets, and reports the
onboarding flag. It contains no encounter state.

Public API:

```gdscript
is_done() -> bool
mark_done() -> Error
reset() -> Error
```

The constructor accepts an optional config path for test isolation.

### 5.2 `SingleEncounterTutorial`

A scene-backed `Control` responsible for:

- current step;
- instruction copy and progress;
- focus-ring placement;
- skip/continue/finish actions;
- deciding whether a requested gameplay action is currently allowed;
- observing accepted UI actions and current `SingleEncounterSession`;
- advancing or updating the current step.

It never mutates `RoundState`, calculates score, or calls `RoundResolver`.
Resetting the teaching encounter is requested through a screen callback.

Public API:

```gdscript
configure(screen, progress_store) -> void
start(replay: bool = false) -> void
allows(action: StringName, payload: Dictionary) -> bool
record_accepted_action(action: StringName, payload: Dictionary) -> void
refresh_targets() -> void
```

### 5.3 `SingleEncounterScreen`

The screen remains the only UI adapter to `SingleEncounterSession`. It gains:

- `tutorial_auto_start`, enabled by default and disabled by existing UI tests;
- a `view_refreshed` signal;
- an `ui_action_accepted(action, payload)` signal;
- action guards before session calls;
- accepted-action reporting after successful session calls;
- `reset_teaching_encounter()` for replay;
- the `重看引导` button.

The screen does not decide tutorial steps. It asks the tutorial whether an
action is allowed, performs the normal session call, then reports only accepted
actions.

### 5.4 Overlay scene

`single_encounter_tutorial.tscn` contains:

- a translucent full-screen dimmer that does not consume target input;
- one or more cyan focus rings positioned over current legal targets;
- a compact callout panel;
- title, instruction, step counter, `继续`, `跳过`, and `完成` controls.

The callout is positioned away from highlighted targets using four preferred
anchor positions. If no preferred position avoids overlap, it chooses the
position with the smallest intersection area.

## 6. Action Vocabulary

The UI reports a finite action vocabulary:

```text
select_die
drag_assign
click_assign
calibrate
select_card
card_table
card_die
card_gap
card_global
undo
commit
```

Payloads use semantic IDs, never node paths:

```gdscript
{"die_id": &"d1"}
{"die_id": &"d1", "table_id": &"left"}
{"card_index": 1, "table_id": &"left"}
{"delta": -1, "die_id": &"d5"}
```

Tutorial action reporting is UI metadata. It does not become part of the
deterministic scoring model or action history.

## 7. Target Locking and Feedback

- Only controls relevant to the current step receive the cyan focus ring.
- Disallowed gameplay actions are rejected before reaching
  `SingleEncounterSession`.
- A rejected tutorial action does not enter `ActionHistory`.
- The callout briefly changes to a specific direction, such as
  `这一步先选择骰子 6`, instead of using a generic error.
- `跳过` and tutorial navigation remain usable regardless of target locking.
- Existing keyboard focus outlines and button disabled states remain visible.
- The overlay uses text plus geometry; it never relies on color alone.

Dynamic die and card tokens are recreated on refresh, so the tutorial resolves
targets again on every `view_refreshed` event and ignores nodes queued for
deletion.

## 8. Reset and Error Handling

- Replay always creates a new `SingleEncounterSession` from
  `SingleEncounterFixture`, preventing committed or partially solved state from
  blocking tutorial steps.
- Config load failure is treated as `done=false`.
- Config save failure leaves the overlay functional and shows a concrete
  non-blocking warning; it must not stop gameplay.
- If a target node cannot be found, the tutorial does not advance. It reports
  the missing semantic target in the Godot log and keeps the skip control
  available.
- Commit only completes step 9 when the committed report is valid and totals
  51.

## 9. Testing

### Unit tests

- Missing config defaults to not done.
- `mark_done()` persists across store instances.
- `reset()` returns to not done.
- Each step accepts only its declared action vocabulary and semantic targets.
- Step predicates advance at 44/51 and reject incorrect state.
- Skip and completion never award or modify encounter state.

### Scene and layout checks

- Overlay, callout, skip, and progress remain inside 1920×1080.
- Focus rings enclose their resolved target rectangles.
- The callout does not overlap the active target when an alternative position
  exists.
- `重看引导` remains visible without colliding with dealer copy.

### Real-input checks

Use `Window.push_input()` with real `InputEventMouseMotion` and
`InputEventMouseButton` objects:

- first-run overlay appears;
- unrelated target clicks do not mutate session state;
- skip closes and persists;
- replay resets the teaching encounter;
- the prescribed drag/click/calibrate/card/undo/commit sequence reaches the
  completion step;
- existing non-tutorial input and layout checks pass with
  `tutorial_auto_start=false`.

All headless Godot commands continue to pass `--log-file` to a writable path
under `$env:TEMP`, and logs are scanned for `SCRIPT ERROR` and
`Failed to load script`.

## 10. Acceptance Criteria

- A fresh player receives onboarding automatically.
- Completing or skipping suppresses automatic onboarding on future launches.
- `重看引导` resets the teaching encounter and reliably starts from step 0.
- Every action step requires an accepted real gameplay action.
- Disallowed actions do not change domain state or history.
- Preview visibly reaches 44, 51, 44, and 51 at the documented steps.
- Final commit equals preview and completes onboarding.
- No tutorial code calculates score or mutates `RoundState` directly.
- No reward is granted for completion or skip.
- The three-lane screen remains within 1920×1080.
- Existing core, layout, and real-input checks remain green.
- The design and implementation-plan documents remain staged and uncommitted.
