# Iron Abacus and Engravings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Extend the playable Stage 4 normal-room/shop slice with a deterministic Iron Abacus dealer challenge, an atomic four-to-three engraving reward, installation onto an actual die face, and a one-round visible engraving verification.

**Architecture:** Add resource-backed dealer and engraving content, then pass an optional `ResolutionContext` through the existing session/controller/resolver path. A pure `IronAbacusSliceSession` owns the shared RNG, inherited deck, tickets, die profiles, phase transitions, boundary retries, and verification result; a new scene-backed screen only binds that state to the existing encounter, shop, and summary components plus a focused engraving reward panel.

**Tech Stack:** Godot 4.6.1, typed GDScript, custom `Resource` content, injected `RandomNumberGenerator`, `.tscn` scene composition, dependency-free synchronous tests, and real `Window.push_input()` checks.

## Global Constraints

- Work directly on `master`, as explicitly authorized for this repository.
- Keep every design and plan document staged and uncommitted.
- Preserve the existing unstaged `project.godot` modification; do not edit, stage, or commit that file.
- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` for automated checks.
- Every headless Godot command passes `--log-file` to a writable path under `$env:TEMP`.
- Treat `SCRIPT ERROR` or `Failed to load script` as failure even when Godot exits `0`.
- Keep the fixed teaching hand, fixed teaching dice, and `44→51→44→51` tutorial path unchanged.
- Preview and commit continue to use the same `RoundResolver` and the same `ResolutionReport`.
- UI code never calculates dealer rewards, engraving effects, RNG results, deck state, ticket balance, or phase validity.
- The normal-room target remains exactly `100`; the Iron Abacus target is exactly `150`.
- Iron Abacus reward is exactly `max(12 - unassigned_dice * 2, 0)`.
- This slice installs exactly one engraving selected from three deterministic offers drawn from four definitions.
- The verification round forces only the selected die's rolled face; the other five dice consume the shared RNG.
- Code commits use `git commit --only` with explicit code/resource/scene/test/tool paths so staged documents are excluded.

## File Map

```text
res://
  resources/
    dealers/
      stage5/
        dealer_iron_abacus.tres
    engravings/
      stage5/
        engraving_anchor.tres
        engraving_bridge.tres
        engraving_echo.tres
        engraving_prism.tres
  scenes/
    components/
      die_token.tscn
      engraving_option_token.tscn
      engraving_reward_panel.tscn
      round_summary_panel.tscn
    run/
      iron_abacus_slice_screen.tscn
      single_encounter_screen.tscn
  scripts/
    dealers/
      dealer_catalog.gd
      dealer_definition.gd
    engravings/
      engraving_catalog.gd
      engraving_definition.gd
      engraving_outcome.gd
      engraving_resolver.gd
    resolution/
      resolution_context.gd
      resolution_event.gd
      resolution_report.gd
      round_resolver.gd
    run/
      encounter_run_setup.gd
      iron_abacus_slice_session.gd
      run_rng.gd
      die_state.gd
      round_actions.gd
      round_controller.gd
      three_round_encounter_session.gd
    ui/
      die_token.gd
      engraving_option_token.gd
      engraving_reward_panel.gd
      iron_abacus_slice_screen.gd
      round_summary_panel.gd
      rule_lane.gd
      single_encounter_screen.gd
      single_encounter_session.gd
    validation/
      content_validator.gd
  tests/
    dealer_and_engraving_resolution_test.gd
    deterministic_state_primitives_test.gd
    engraving_action_guard_test.gd
    iron_abacus_slice_session_test.gd
    parameterized_three_round_session_test.gd
    stage5_content_catalog_test.gd
    stage5_input_self_check.gd
    stage5_layout_self_check.gd
    three_round_input_self_check.gd
    ui_component_contract_test.gd
  tools/
    generate_stage5_content.gd
```

---

### Task 1: Deterministic Die, Event, and RNG Primitives

**Files:**
- Modify: `scripts/run/die_state.gd`
- Modify: `scripts/run/run_rng.gd`
- Modify: `scripts/resolution/resolution_event.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Create: `tests/deterministic_state_primitives_test.gd`

**Interfaces:**
- Consumes: existing `DieState`, `RunRng`, and `ResolutionReport.event_signature()`.
- Produces: `DieState.rolled_value`, `DieState.engraved_face`, `RunRng.snapshot_state() -> int`, `RunRng.restore_state(saved_state)`, and `ResolutionEvent.effect_applied`.

- [x] **Step 1: Write the failing primitive test**

Create `tests/deterministic_state_primitives_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var die := DieState.new(&"d1", 4, &"engraving_anchor", 4)
	die.value = 5
	var clone := die.clone()
	assert_equal(clone.id, &"d1", "clone should preserve die ID")
	assert_equal(clone.rolled_value, 4, "clone should preserve rolled value")
	assert_equal(clone.value, 5, "clone should preserve effective value")
	assert_equal(clone.engraving_id, &"engraving_anchor", "clone should preserve engraving")
	assert_equal(clone.engraved_face, 4, "clone should preserve engraved face")

	var rng := RunRng.new(20260726)
	rng.roll_die()
	var checkpoint: int = rng.snapshot_state()
	var expected := [rng.roll_die(), rng.roll_die(), rng.roll_die()]
	rng.restore_state(checkpoint)
	var actual := [rng.roll_die(), rng.roll_die(), rng.roll_die()]
	assert_equal(actual, expected, "restored RNG should replay the same values")

	var report := ResolutionReport.new()
	report.events = [
		ResolutionEvent.new(&"engraving_echo", "没有相邻骰", 0, 0, false),
	]
	assert_true(
		report.event_signature()[0].ends_with("|false"),
		"event signature should include whether the effect applied"
	)
```

- [x] **Step 2: Run the synchronous suite and verify the new fields are missing**

```powershell
$redLog = Join-Path $env:TEMP 'project-joker-stage5-primitives-red.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $redLog -s res://tests/run_all.gd
```

Expected: parse or assertion failure for `rolled_value`, `engraved_face`,
`snapshot_state`, or the fifth `ResolutionEvent` argument.

- [x] **Step 3: Extend `DieState` without breaking existing constructor calls**

Replace `scripts/run/die_state.gd` with:

```gdscript
class_name DieState
extends RefCounted

var id: StringName
var rolled_value: int
var value: int
var engraving_id: StringName
var engraved_face: int

func _init(
	p_id: StringName,
	p_value: int,
	p_engraving_id: StringName = &"",
	p_engraved_face: int = 0,
	p_rolled_value: int = 0
) -> void:
	id = p_id
	value = p_value
	rolled_value = p_value if p_rolled_value == 0 else p_rolled_value
	engraving_id = p_engraving_id
	engraved_face = p_engraved_face

func clone() -> DieState:
	return DieState.new(id, value, engraving_id, engraved_face, rolled_value)
```

Existing two- and three-argument calls continue to compile. Since legal rolled values are
`1..6`, `0` is an unambiguous “use `p_value`” sentinel.

- [x] **Step 4: Add RNG state snapshot and restore**

Append to `scripts/run/run_rng.gd`:

```gdscript
func snapshot_state() -> int:
	return _rng.state

func restore_state(saved_state: int) -> void:
	_rng.state = saved_state
```

Do not expose the `RandomNumberGenerator` object itself.

- [x] **Step 5: Add applied state to resolution events and signatures**

In `scripts/resolution/resolution_event.gd`, add:

```gdscript
var effect_applied: bool
```

Change the constructor to:

```gdscript
func _init(
	p_source_id: StringName,
	p_label: String,
	p_delta: int,
	p_running_total: int,
	p_effect_applied: bool = true
) -> void:
	source_id = p_source_id
	label = p_label
	delta = p_delta
	running_total = p_running_total
	effect_applied = p_effect_applied
```

Change `ResolutionReport.event_signature()` formatting to:

```gdscript
signature.append("%s|%s|%d|%d|%s" % [
	event.source_id,
	event.label,
	event.delta,
	event.running_total,
	str(event.effect_applied),
])
```

- [x] **Step 6: Run all synchronous tests**

```powershell
$testLog = Join-Path $env:TEMP 'project-joker-stage5-primitives.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $testLog -s res://tests/run_all.gd
if (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR|Failed to load script') {
    exit 1
}
```

Expected: the new primitive test and every existing suite pass.

- [x] **Step 7: Commit deterministic primitives only**

```powershell
$paths = @(
  'scripts/run/die_state.gd',
  'scripts/run/run_rng.gd',
  'scripts/resolution/resolution_event.gd',
  'scripts/resolution/resolution_report.gd',
  'tests/deterministic_state_primitives_test.gd',
  'tests/deterministic_state_primitives_test.gd.uid'
)
git add -- $paths
git commit --only -m "feat: add deterministic engraving state" -- $paths
```

---

### Task 2: Resource-Backed Dealer and Engraving Content

**Files:**
- Create: `scripts/dealers/dealer_definition.gd`
- Create: `scripts/dealers/dealer_catalog.gd`
- Create: `scripts/engravings/engraving_definition.gd`
- Create: `scripts/engravings/engraving_catalog.gd`
- Modify: `scripts/validation/content_validator.gd`
- Create: `tools/generate_stage5_content.gd`
- Generate: `resources/dealers/stage5/dealer_iron_abacus.tres`
- Generate: `resources/engravings/stage5/*.tres`
- Create: `tests/stage5_content_catalog_test.gd`

**Interfaces:**
- Consumes: `ContentValidator`.
- Produces: `DealerDefinition`, `DealerCatalog.iron_abacus()`, `EngravingDefinition.Operation`, `EngravingCatalog.all_engravings()`, `all_ids()`, `find_engraving(id)`, and `validate()`.

- [x] **Step 1: Write the failing content test**

Create `tests/stage5_content_catalog_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var dealers := DealerCatalog.new()
	var engravings := EngravingCatalog.new()
	assert_equal(dealers.validate(), [], "dealer content should validate")
	assert_equal(engravings.validate(), [], "engraving content should validate")

	var dealer := dealers.iron_abacus()
	assert_true(dealer != null, "Iron Abacus should load")
	if dealer != null:
		assert_equal(dealer.id, &"dealer_iron_abacus", "dealer ID should be stable")
		assert_equal(dealer.fixed_reward, 12, "dealer full reward should be twelve")
		assert_equal(
			dealer.penalty_per_unassigned_die,
			2,
			"dealer should lose two per unassigned die"
		)

	var expected := PackedStringArray([
		"engraving_echo",
		"engraving_anchor",
		"engraving_bridge",
		"engraving_prism",
	])
	var actual := PackedStringArray()
	for engraving_id in engravings.all_ids():
		actual.append(String(engraving_id))
	actual.sort()
	expected.sort()
	assert_equal(actual, expected, "catalog should expose exactly four engravings")

	for engraving in engravings.all_engravings():
		assert_false(engraving.rule_text.strip_edges().is_empty(), "rule text should exist")
		assert_true(engraving.tags.size() >= 1, "display tags should exist")
	assert_true(
		engravings.find_engraving(&"missing_engraving") == null,
		"unknown engraving IDs should return null"
	)
```

- [x] **Step 2: Run and verify the catalogs are missing**

Run `tests/run_all.gd` with a writable log.

Expected: preload/global-class failure for `DealerCatalog` or `EngravingCatalog`.

- [x] **Step 3: Add dealer and engraving resource types**

Create `scripts/dealers/dealer_definition.gd`:

```gdscript
class_name DealerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export var fixed_reward: int
@export var penalty_per_unassigned_die: int
@export var tags: PackedStringArray = []
```

Create `scripts/engravings/engraving_definition.gd`:

```gdscript
class_name EngravingDefinition
extends Resource

enum Operation {
	ECHO_ADJACENT,
	ANCHOR_DIE,
	BRIDGE_FORWARD,
	PRISM_PARITY,
}

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export var operation: Operation = Operation.ECHO_ADJACENT
@export var amount: int
@export var tags: PackedStringArray = []
```

- [x] **Step 4: Add exact dealer and engraving validation**

Append to `ContentValidator`:

```gdscript
func validate_dealers(dealers: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for dealer in dealers:
		if dealer == null:
			errors.append("dealer resource is null")
			continue
		if dealer.id == &"":
			errors.append("dealer ID is empty")
		elif seen.has(dealer.id):
			errors.append("duplicate dealer ID: %s" % dealer.id)
		else:
			seen[dealer.id] = true
		if dealer.display_name.strip_edges().is_empty():
			errors.append("dealer %s has no display name" % dealer.id)
		if dealer.rule_text.strip_edges().is_empty():
			errors.append("dealer %s has no rule text" % dealer.id)
		if dealer.fixed_reward <= 0:
			errors.append("dealer %s reward must be positive" % dealer.id)
		if dealer.penalty_per_unassigned_die <= 0:
			errors.append("dealer %s penalty must be positive" % dealer.id)
		if dealer.fixed_reward - dealer.penalty_per_unassigned_die * 6 < 0:
			errors.append("dealer %s penalty exceeds full reward" % dealer.id)
		if dealer.tags.is_empty():
			errors.append("dealer %s has no display tags" % dealer.id)
	return errors

func validate_engravings(engravings: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for engraving in engravings:
		if engraving == null:
			errors.append("engraving resource is null")
			continue
		if engraving.id == &"":
			errors.append("engraving ID is empty")
		elif seen.has(engraving.id):
			errors.append("duplicate engraving ID: %s" % engraving.id)
		else:
			seen[engraving.id] = true
		if engraving.display_name.strip_edges().is_empty():
			errors.append("engraving %s has no display name" % engraving.id)
		if engraving.rule_text.strip_edges().is_empty():
			errors.append("engraving %s has no rule text" % engraving.id)
		if engraving.tags.is_empty():
			errors.append("engraving %s has no display tags" % engraving.id)
		match engraving.operation:
			EngravingDefinition.Operation.ECHO_ADJACENT:
				if engraving.amount != 2:
					errors.append("echo engraving divisor must equal two")
			EngravingDefinition.Operation.ANCHOR_DIE:
				if engraving.amount != 4:
					errors.append("anchor engraving reward must equal four")
			EngravingDefinition.Operation.BRIDGE_FORWARD:
				if engraving.amount != 1:
					errors.append("bridge engraving amount must equal one")
			EngravingDefinition.Operation.PRISM_PARITY:
				if engraving.amount != 0:
					errors.append("prism engraving amount must equal zero")
	return errors
```

- [x] **Step 5: Create the deterministic content generator**

Create `tools/generate_stage5_content.gd` with these exact definitions:

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	for directory in [
		"res://resources/dealers/stage5",
		"res://resources/engravings/stage5",
	]:
		var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory)
		)
		if directory_error != OK:
			errors.append("%s: %s" % [directory, error_string(directory_error)])

	var dealer := DealerDefinition.new()
	dealer.id = &"dealer_iron_abacus"
	dealer.display_name = "铁算盘"
	dealer.rule_text = "每轮固定奖励 12；每有一颗骰子未分配，奖励减少 2，最低为 0。"
	dealer.fixed_reward = 12
	dealer.penalty_per_unassigned_die = 2
	dealer.tags = PackedStringArray(["庄家", "全骰利用"])
	_save(dealer, "res://resources/dealers/stage5/dealer_iron_abacus.tres", errors)

	var specs := [
		[&"engraving_echo", "回声",
			"刻印面投出并分配后，规则台通过时获得较高相邻骰点数的一半（向下取整）。",
			EngravingDefinition.Operation.ECHO_ADJACENT, 2,
			PackedStringArray(["相邻", "固定奖励"])],
		[&"engraving_anchor", "锚定",
			"刻印面投出后不能校准或被点数牌修改；规则台通过时固定奖励 +4。",
			EngravingDefinition.Operation.ANCHOR_DIE, 4,
			PackedStringArray(["保护", "固定奖励"])],
		[&"engraving_bridge", "桥接",
			"刻印面投出并分配后，把该骰有效点数传递给结算方向中的下一张有效规则台。",
			EngravingDefinition.Operation.BRIDGE_FORWARD, 1,
			PackedStringArray(["桌间", "传递"])],
		[&"engraving_prism", "棱镜",
			"刻印面投出并分配后，在奇偶条件中同时视为奇数与偶数。",
			EngravingDefinition.Operation.PRISM_PARITY, 0,
			PackedStringArray(["条件", "奇偶"])],
	]
	for spec in specs:
		var engraving := EngravingDefinition.new()
		engraving.id = spec[0]
		engraving.display_name = spec[1]
		engraving.rule_text = spec[2]
		engraving.operation = spec[3]
		engraving.amount = spec[4]
		engraving.tags = spec[5]
		_save(
			engraving,
			"res://resources/engravings/stage5/%s.tres" % String(engraving.id),
			errors
		)

	if errors.is_empty():
		print("GENERATED STAGE5 CONTENT: 1 DEALER, 4 ENGRAVINGS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)

func _save(resource: Resource, path: String, errors: Array[String]) -> void:
	var result := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if result != OK:
		errors.append("%s: %s" % [path, error_string(result)])
```

- [x] **Step 6: Generate, import, and scan logs**

```powershell
$generateLog = Join-Path $env:TEMP 'project-joker-stage5-content-generate.log'
$importLog = Join-Path $env:TEMP 'project-joker-stage5-content-import.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $generateLog -s res://tools/generate_stage5_content.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $importLog --import
$bad = Select-String -LiteralPath @($generateLog, $importLog) `
  -Pattern 'SCRIPT ERROR|Failed to load script'
if ($bad) { $bad; exit 1 }
```

Expected: five `.tres` resources exist and the generator prints the exact success line.

- [x] **Step 7: Add explicit catalogs**

`DealerCatalog` loads only
`res://resources/dealers/stage5/dealer_iron_abacus.tres`,
exposes `iron_abacus()`, `all_dealers()`, and delegates validation to
`ContentValidator.validate_dealers()`.

`EngravingCatalog` uses this exact ordered path list:

```gdscript
const PATHS := [
	"res://resources/engravings/stage5/engraving_echo.tres",
	"res://resources/engravings/stage5/engraving_anchor.tres",
	"res://resources/engravings/stage5/engraving_bridge.tres",
	"res://resources/engravings/stage5/engraving_prism.tres",
]
```

It stores `_by_id`, returns duplicates from `all_engravings()` and `all_ids()`,
returns `null` for unknown IDs, and reports a size error unless exactly four resources load.

- [x] **Step 8: Run all synchronous tests**

Expected: the new content suite and every previous suite pass; the log scan is clean.

- [x] **Step 9: Commit Stage 5 content only**

Commit explicit paths for the four new scripts, their `.uid` files, validator,
generator, five resources, and the content test using:

```powershell
git add -- `
  scripts/dealers/dealer_definition.gd scripts/dealers/dealer_definition.gd.uid `
  scripts/dealers/dealer_catalog.gd scripts/dealers/dealer_catalog.gd.uid `
  scripts/engravings/engraving_definition.gd `
  scripts/engravings/engraving_definition.gd.uid `
  scripts/engravings/engraving_catalog.gd `
  scripts/engravings/engraving_catalog.gd.uid `
  scripts/validation/content_validator.gd `
  tools/generate_stage5_content.gd tools/generate_stage5_content.gd.uid `
  resources/dealers/stage5/dealer_iron_abacus.tres `
  resources/engravings/stage5/engraving_anchor.tres `
  resources/engravings/stage5/engraving_bridge.tres `
  resources/engravings/stage5/engraving_echo.tres `
  resources/engravings/stage5/engraving_prism.tres `
  tests/stage5_content_catalog_test.gd tests/stage5_content_catalog_test.gd.uid
git commit --only -m "feat: add dealer and engraving content" -- `
  scripts/dealers/dealer_definition.gd scripts/dealers/dealer_definition.gd.uid `
  scripts/dealers/dealer_catalog.gd scripts/dealers/dealer_catalog.gd.uid `
  scripts/engravings/engraving_definition.gd `
  scripts/engravings/engraving_definition.gd.uid `
  scripts/engravings/engraving_catalog.gd `
  scripts/engravings/engraving_catalog.gd.uid `
  scripts/validation/content_validator.gd `
  tools/generate_stage5_content.gd tools/generate_stage5_content.gd.uid `
  resources/dealers/stage5/dealer_iron_abacus.tres `
  resources/engravings/stage5/engraving_anchor.tres `
  resources/engravings/stage5/engraving_bridge.tres `
  resources/engravings/stage5/engraving_echo.tres `
  resources/engravings/stage5/engraving_prism.tres `
  tests/stage5_content_catalog_test.gd tests/stage5_content_catalog_test.gd.uid
```

---

### Task 3: Resolution Context and Anchor Action Guards

**Files:**
- Create: `scripts/resolution/resolution_context.gd`
- Create: `scripts/engravings/engraving_resolver.gd`
- Modify: `scripts/run/round_actions.gd`
- Modify: `scripts/cards/card_rules.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/ui/single_encounter_session.gd`
- Create: `tests/engraving_action_guard_test.gd`

**Interfaces:**
- Consumes: `EngravingCatalog`, `DieState`, `RoundState`.
- Produces: `ResolutionContext.empty()`, `EngravingResolver.active_definition(die, context)`, `modification_block_reason(state, die_id, context)`, and optional context parameters through action/session/controller layers.

- [x] **Step 1: Write the failing anchor guard test**

Create a test that builds one active anchor die:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var state := RoundState.new()
	state.dice = [DieState.new(&"d1", 4, &"engraving_anchor", 4)]
	var context := ResolutionContext.new(null, EngravingCatalog.new())

	var calibration := RoundActions.adjust_die(state, &"d1", 1, context)
	assert_false(calibration.accepted, "active anchor should reject calibration")
	assert_true("锚定" in calibration.reason, "calibration reason should name anchor")
	assert_equal(calibration.next_state.calibration_points, 2, "rejection should not spend points")
	assert_equal(calibration.next_state.find_die(&"d1").value, 4, "rejection should not change die")

	var card := CardCatalog.new().find_card(&"starter_nudge_up_1")
	var played := PlayedCard.new(card, &"d1")
	var card_result := CardRules.play_card(state, played, context)
	assert_false(card_result.accepted, "active anchor should reject adjust-die card")
	assert_equal(card_result.next_state.played_cards.size(), 0, "rejection should not play card")

	state.find_die(&"d1").rolled_value = 3
	assert_true(
		RoundActions.adjust_die(state, &"d1", 1, context).accepted,
		"anchor should be inactive when rolled face does not match"
	)
```

- [x] **Step 2: Run and verify context-aware overloads are missing**

Expected: parse failure for `ResolutionContext` or extra action arguments.

- [x] **Step 3: Add `ResolutionContext`**

Create:

```gdscript
class_name ResolutionContext
extends RefCounted

var dealer: DealerDefinition
var engraving_catalog: EngravingCatalog

func _init(
	p_dealer: DealerDefinition = null,
	p_engraving_catalog: EngravingCatalog = null
) -> void:
	dealer = p_dealer
	engraving_catalog = p_engraving_catalog

static func empty() -> ResolutionContext:
	return ResolutionContext.new()
```

- [x] **Step 4: Implement active engraving and modification guards**

Create `EngravingResolver` with:

```gdscript
class_name EngravingResolver
extends RefCounted

func active_definition(
	die: DieState,
	context: ResolutionContext
) -> EngravingDefinition:
	if (
		die == null
		or die.engraving_id == &""
		or die.engraved_face < 1
		or die.engraved_face > 6
		or die.rolled_value != die.engraved_face
		or context == null
		or context.engraving_catalog == null
	):
		return null
	return context.engraving_catalog.find_engraving(die.engraving_id)

func modification_block_reason(
	state: RoundState,
	die_id: StringName,
	context: ResolutionContext
) -> String:
	var definition := active_definition(state.find_die(die_id), context)
	if (
		definition != null
		and definition.operation == EngravingDefinition.Operation.ANCHOR_DIE
	):
		return "锚定刻印已激活，这颗骰子本轮不能修改点数"
	return ""
```

- [x] **Step 5: Thread optional context through actions**

Change signatures while preserving old call sites:

```gdscript
static func adjust_die(
	state: RoundState,
	die_id: StringName,
	delta: int,
	context: ResolutionContext = null
) -> ActionResult:
```

After confirming the die exists and before checking the next value:

```gdscript
var block_reason := EngravingResolver.new().modification_block_reason(
	state, die_id, context
)
if not block_reason.is_empty():
	return ActionResult.new(false, block_reason, state)
```

Change `CardRules.play_card` to accept optional context. After target validation and before
cloning state, inspect all effects:

```gdscript
for effect in played_card.definition.effects:
	if effect.operation == EffectSpec.Operation.ADJUST_DIE:
		var reason := EngravingResolver.new().modification_block_reason(
			state, played_card.primary_target, context
		)
		if not reason.is_empty():
			return ActionResult.new(false, reason, state)
```

- [x] **Step 6: Thread context through controller and session**

Add `var resolution_context: ResolutionContext` to `RoundController`.
Its constructor gains `p_context: ResolutionContext = null` and normalizes null to
`ResolutionContext.empty()`.

Use the context in:

```gdscript
RoundActions.adjust_die(state, die_id, delta, resolution_context)
CardRules.play_card(state, played_card, resolution_context)
_resolver.resolve(state, encounter, resolution_context)
```

Add the same optional fourth constructor argument to `SingleEncounterSession` and pass it
to `RoundController`. All existing three-argument calls remain valid.

- [x] **Step 7: Run anchor and full regression tests**

Expected: active anchor rejects both paths without state mutation; all pre-Stage-5 tests pass.

- [x] **Step 8: Commit context and guards**

Commit the new context/resolver files, modified action/controller/session files, and guard test:

```powershell
git add -- `
  scripts/resolution/resolution_context.gd scripts/resolution/resolution_context.gd.uid `
  scripts/engravings/engraving_resolver.gd scripts/engravings/engraving_resolver.gd.uid `
  scripts/run/round_actions.gd scripts/cards/card_rules.gd `
  scripts/run/round_controller.gd scripts/ui/single_encounter_session.gd `
  tests/engraving_action_guard_test.gd tests/engraving_action_guard_test.gd.uid
git commit --only -m "feat: guard active anchor engravings" -- `
  scripts/resolution/resolution_context.gd scripts/resolution/resolution_context.gd.uid `
  scripts/engravings/engraving_resolver.gd scripts/engravings/engraving_resolver.gd.uid `
  scripts/run/round_actions.gd scripts/cards/card_rules.gd `
  scripts/run/round_controller.gd scripts/ui/single_encounter_session.gd `
  tests/engraving_action_guard_test.gd tests/engraving_action_guard_test.gd.uid
```

---

### Task 4: Unified Dealer and Engraving Resolution

**Files:**
- Create: `scripts/engravings/engraving_outcome.gd`
- Modify: `scripts/engravings/engraving_resolver.gd`
- Modify: `scripts/rules/rule_evaluator.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Modify: `scripts/resolution/round_resolver.gd`
- Create: `tests/dealer_and_engraving_resolution_test.gd`

**Interfaces:**
- Consumes: `ResolutionContext`, assigned die IDs, effective die values, ordered rule IDs.
- Produces: parity flags, immediate engraving outcomes, queued bridge outcomes, dealer metrics, and one unified report event stream.

- [x] **Step 1: Write failing dealer and engraving resolution tests**

Create one suite with these concrete cases:

```gdscript
func run() -> void:
	_test_dealer_rewards()
	_test_echo()
	_test_anchor_bonus()
	_test_bridge_direction()
	_test_prism()
```

Dealer loop:

```gdscript
for assigned_count in range(0, 7):
	var state := _state_with_legal_assignments(assigned_count)
	var report := RoundResolver.new().resolve(
		state,
		SingleEncounterFixture.make_encounter(),
		ResolutionContext.new(DealerCatalog.new().iron_abacus(), null)
	)
	assert_equal(
		report.dealer_reward,
		assigned_count * 2,
		"dealer reward should equal two per assigned die"
	)
	assert_equal(report.unassigned_dice, 6 - assigned_count, "metric should be public")
	assert_equal(report.dealer_reward_lost, (6 - assigned_count) * 2, "loss should match")
	assert_equal(
		report.events[-1].source_id,
		&"dealer_iron_abacus",
		"dealer event should be last"
	)
	assert_equal(
		report.events[-1].delta,
		assigned_count * 2,
		"dealer event delta should expose the exact reward"
	)
```

The engraving cases must assert both `total` and `event_signature()` for preview/commit
through `RoundController`. Use these fixed expectations and fixtures:

- Echo covers left-only and right-only neighbors.
- Echo with engraved `4` between `3` and `5` chooses `5`: delta `2`, applied `true`.
- Echo with engraved `4` adjacent to `1`: delta `0`, applied `true`.
- Echo without an adjacent die: delta `0`, applied `false`.
- Echo on an invalid source table adds no reward and records the invalid-source diagnostic.
- Anchor on a valid table: delta `4`, applied `true`.
- Anchor whose rolled face does not match produces no engraving event.
- Bridge from left to middle in left-to-right order: delta equals engraved effective value.
- Reverse-resolution bridge from right to middle: same rule in the opposite direction.
- Bridge with no next table and bridge with an invalid destination each produce an applied-false
  diagnostic and no reward.
- Prism with rolled/effective value `3` on an `ALL_EVEN` one-slot table: table becomes valid,
  prism delta is `0`, applied `true`.
- Prism with an even value still records a zero-delta applied event.
- Prism on an exact-sum table: scoring is unchanged.
- Prism whose rolled face does not match does not alter parity and produces no engraving event.
- The dealer event occurs once and after every table, engraving, and card-link event.

- [x] **Step 2: Run and verify resolution hooks are missing**

Expected: missing report metrics, resolver context argument, or parity support.

- [x] **Step 3: Add an explicit engraving outcome type**

Create:

```gdscript
class_name EngravingOutcome
extends RefCounted

var source_id: StringName
var label: String
var delta: int
var target_table_id: StringName
var effect_applied: bool

func _init(
	p_source_id: StringName,
	p_label: String,
	p_delta: int,
	p_target_table_id: StringName = &"",
	p_effect_applied: bool = true
) -> void:
	source_id = p_source_id
	label = p_label
	delta = p_delta
	target_table_id = p_target_table_id
	effect_applied = p_effect_applied
```

- [x] **Step 4: Add report dealer metrics**

Add to `ResolutionReport`:

```gdscript
var assigned_dice: int = 0
var unassigned_dice: int = 0
var dealer_reward: int = 0
var dealer_reward_lost: int = 0
```

These are derived output fields; UI reads them but never writes them.

- [x] **Step 5: Add parity flags to `RuleEvaluator`**

Change `evaluate` to accept:

```gdscript
parity_overrides: Array[bool] = []
```

Validate that a non-empty override array matches `values.size()`. In `ALL_EVEN`, use:

```gdscript
for index in range(values.size()):
	var prism_treats_as_even := (
		not parity_overrides.is_empty()
		and parity_overrides[index]
	)
	if values[index] % 2 != 0 and not prism_treats_as_even:
		return false
return true
```

Exact sum and consecutive conditions continue to use numeric values only.

- [x] **Step 6: Add engraving resolution helpers**

Extend `EngravingResolver` with:

```gdscript
func parity_overrides(
	state: RoundState,
	assigned_ids: Array,
	context: ResolutionContext
) -> Array[bool]:
	var flags: Array[bool] = []
	for die_id in assigned_ids:
		var definition := active_definition(state.find_die(die_id), context)
		flags.append(
			definition != null
			and definition.operation == EngravingDefinition.Operation.PRISM_PARITY
		)
	return flags
```

Add `table_outcomes(...) -> Array[EngravingOutcome]` with exact behavior:

- Iterate assigned IDs in slot order.
- Inactive or unknown engravings produce no outcome.
- Invalid source rule produces one `effect_applied=false` outcome per active engraving.
- Echo inspects immediate left/right slot IDs, chooses the higher effective value, divides by
  `definition.amount`, and returns an immediate outcome. No neighbor returns false.
- Anchor returns an immediate `definition.amount` outcome.
- Prism returns an immediate zero-delta, applied outcome when the table is valid.
- Bridge returns an outcome targeted at `ordered_rule_ids[rule_index + 1]`; no next rule returns false.

The method receives `die_values: Dictionary` after card adjustments, so echo and bridge use
the same effective values as scoring.

- [x] **Step 7: Integrate outcomes and dealer event into `RoundResolver`**

Change signature:

```gdscript
func resolve(
	state: RoundState,
	encounter: EncounterDefinition,
	context: ResolutionContext = null
) -> ResolutionReport:
```

Normalize null to `ResolutionContext.empty()`.

For each ordered rule:

1. Build `assigned_ids`, numeric values, and parity flags.
2. Evaluate the table.
3. Append the existing table event.
4. If valid, apply any queued bridge outcomes targeting this table. If invalid, append each queued
   bridge as a zero-delta `effect_applied=false` diagnostic naming the invalid destination.
5. Request this table's engraving outcomes.
6. Apply immediate outcomes in slot order.
7. Queue targeted bridge outcomes for later rules.

Use this exact helper when applying an outcome:

```gdscript
func _append_outcome(report: ResolutionReport, outcome: EngravingOutcome) -> void:
	if outcome.effect_applied:
		report.total += outcome.delta
	report.events.append(ResolutionEvent.new(
		outcome.source_id,
		outcome.label,
		outcome.delta if outcome.effect_applied else 0,
		report.total,
		outcome.effect_applied
	))
```

After all rules and links:

```gdscript
if context.dealer != null:
	var assigned: Dictionary = {}
	for table_id in state.assignments:
		for die_id in state.assignments[table_id]:
			assigned[die_id] = true
	report.assigned_dice = assigned.size()
	report.unassigned_dice = maxi(state.dice.size() - assigned.size(), 0)
	report.dealer_reward_lost = mini(
		context.dealer.fixed_reward,
		report.unassigned_dice * context.dealer.penalty_per_unassigned_die
	)
	report.dealer_reward = maxi(
		context.dealer.fixed_reward - report.dealer_reward_lost,
		0
	)
	report.total += report.dealer_reward
	report.events.append(ResolutionEvent.new(
		context.dealer.id,
		"%s：已分配 %d，未分配 %d，奖励 %d" % [
			context.dealer.display_name,
			report.assigned_dice,
			report.unassigned_dice,
			report.dealer_reward,
		],
		report.dealer_reward,
		report.total
	))
```

- [x] **Step 8: Run resolver, controller, tutorial, and full synchronous tests**

Expected: every new exact total passes; existing `51` and `44→51→44→51` behavior is unchanged.

- [x] **Step 9: Commit unified resolution**

```powershell
git add -- `
  scripts/engravings/engraving_outcome.gd scripts/engravings/engraving_outcome.gd.uid `
  scripts/engravings/engraving_resolver.gd `
  scripts/rules/rule_evaluator.gd `
  scripts/resolution/resolution_report.gd scripts/resolution/round_resolver.gd `
  tests/dealer_and_engraving_resolution_test.gd `
  tests/dealer_and_engraving_resolution_test.gd.uid
git commit --only -m "feat: resolve dealer and engraving effects" -- `
  scripts/engravings/engraving_outcome.gd scripts/engravings/engraving_outcome.gd.uid `
  scripts/engravings/engraving_resolver.gd `
  scripts/rules/rule_evaluator.gd `
  scripts/resolution/resolution_report.gd scripts/resolution/round_resolver.gd `
  tests/dealer_and_engraving_resolution_test.gd `
  tests/dealer_and_engraving_resolution_test.gd.uid
```

---

### Task 5: Parameterized Three-Round Encounter Session

**Files:**
- Create: `scripts/run/encounter_run_setup.gd`
- Modify: `scripts/run/three_round_encounter_session.gd`
- Create: `tests/parameterized_three_round_session_test.gd`

**Interfaces:**
- Consumes: injected `RunRng`, inherited deck IDs, encounter definition, resolution context,
  persistent die profiles.
- Produces: `EncounterRunSetup`, backward-compatible `ThreeRoundEncounterSession.new(...)`,
  and dealer-ready three-round sessions.

- [x] **Step 1: Write the failing parameterized-session test**

Create a setup using:

```gdscript
var rng := RunRng.new(20260726)
var setup := EncounterRunSetup.new()
setup.run_rng = rng
setup.deck_ids = CardCatalog.new().starter_ids()
setup.encounter = SingleEncounterFixture.make_encounter()
setup.resolution_context = ResolutionContext.new(
	DealerCatalog.new().iron_abacus(),
	EngravingCatalog.new()
)
setup.success_intel_reward = 0
setup.prepare_shop_offers = false
setup.die_profiles = _profiles_with_anchor()

var session := ThreeRoundEncounterSession.new(
	CardCatalog.new(),
	20260726,
	0,
	setup
)
assert_true(session.start().accepted, "configured session should start")
assert_equal(
	session.current_session.controller.resolution_context.dealer.id,
	&"dealer_iron_abacus",
	"dealer context should reach the round"
)
var d1 := session.current_session.controller.state.find_die(&"d1")
assert_equal(d1.engraving_id, &"engraving_anchor", "profile should copy engraving")
assert_equal(d1.engraved_face, 4, "profile should copy engraved face")
```

Commit three empty rounds and assert:

- success reward remains `0`;
- shop offers remain empty;
- exactly twelve inherited deck IDs are exposed;
- the injected RNG state advances;
- a second setup restored to the original RNG snapshot reproduces dice and hands.

Also call the old three-argument constructor and assert its existing two-ticket/shop behavior.

- [x] **Step 2: Run and verify the setup type/fourth constructor argument is missing**

- [x] **Step 3: Add `EncounterRunSetup`**

Create:

```gdscript
class_name EncounterRunSetup
extends RefCounted

var run_rng: RunRng
var deck_ids: Array[StringName] = []
var encounter: EncounterDefinition
var resolution_context: ResolutionContext
var success_intel_reward: int = 2
var prepare_shop_offers: bool = true
var die_profiles: Array[DieState] = []
var forced_rolls: Dictionary = {}
```

- [x] **Step 4: Generalize `ThreeRoundEncounterSession`**

Add optional fourth constructor argument:

```gdscript
p_setup: EncounterRunSetup = null
```

Normalize setup in `_init`. In `start()`:

```gdscript
_run_rng = setup.run_rng if setup.run_rng != null else RunRng.new(seed_value)
starter_deck_ids = (
	setup.deck_ids.duplicate()
	if not setup.deck_ids.is_empty()
	else catalog.starter_ids()
)
```

Validate exactly twelve unique known deck IDs before calling `CardDeck.start_encounter`. If profiles
are supplied, require exactly the six unique IDs `d1..d6`; require either a blank engraving with
face `0`, or a catalog-known engraving with face `1..6`. Validate every forced-roll key as `d1..d6`
and every forced value as `1..6`. Any failure returns an `OperationResult` before consuming RNG.

In `_begin_round()`:

- use `setup.encounter` or `SingleEncounterFixture.make_encounter()`;
- use `setup.resolution_context` or `ResolutionContext.empty()`;
- roll each die unless `setup.forced_rolls` contains that die ID;
- copy engraving ID and face from the matching profile;
- create `SingleEncounterSession` with the context.

Use:

```gdscript
func _profile_for(die_id: StringName) -> DieState:
	for profile in setup.die_profiles:
		if profile.id == die_id:
			return profile
	return null
```

On success:

```gdscript
intel_tickets = setup.success_intel_reward
if setup.prepare_shop_offers:
	shop_offer_ids.assign(_run_rng.shuffle(catalog.shop_ids()))
else:
	shop_offer_ids.clear()
```

- [x] **Step 5: Run parameterized and Stage 4 deterministic tests**

Expected: injected sessions work and the old seed/dice/hand/shop test remains byte-for-byte deterministic.

- [x] **Step 6: Commit encounter parameterization**

```powershell
git add -- `
  scripts/run/encounter_run_setup.gd scripts/run/encounter_run_setup.gd.uid `
  scripts/run/three_round_encounter_session.gd `
  tests/parameterized_three_round_session_test.gd `
  tests/parameterized_three_round_session_test.gd.uid
git commit --only -m "feat: parameterize three round encounters" -- `
  scripts/run/encounter_run_setup.gd scripts/run/encounter_run_setup.gd.uid `
  scripts/run/three_round_encounter_session.gd `
  tests/parameterized_three_round_session_test.gd `
  tests/parameterized_three_round_session_test.gd.uid
```

---

### Task 6: Iron Abacus Slice Domain State Machine

**Files:**
- Create: `scripts/run/iron_abacus_slice_session.gd`
- Create: `tests/iron_abacus_slice_session_test.gd`

**Interfaces:**
- Consumes: `CardCatalog`, `DealerCatalog`, `EngravingCatalog`,
  `ThreeRoundEncounterSession`, `ShopSession`, shared `RunRng`.
- Produces: phase-safe normal room, shop, dealer, reward, installation,
  verification, retry, and completion operations.

- [x] **Step 1: Write the failing slice-session test**

The test must exercise these exact operations:

```gdscript
var slice := IronAbacusSliceSession.new(20260726, 0, 0)
assert_true(slice.start().accepted, "slice should start normal room")
_commit_three_empty_rounds(slice)
assert_equal(slice.phase, IronAbacusSliceSession.Phase.NORMAL_ROOM, "normal success waits")
assert_true(slice.open_shop().accepted, "normal success should open shop")

var original_replaced: StringName = slice.shop_session.deck_ids[0]
var bought: StringName = slice.shop_session.offer_ids[0]
assert_true(
	slice.shop_session.purchase(bought, original_replaced).accepted,
	"shop replacement should succeed"
)
assert_true(slice.leave_shop().accepted, "leaving shop should preserve state")
assert_true(slice.start_dealer().accepted, "dealer should start from boundary")
assert_true(bought in slice.deck_ids, "dealer deck should inherit purchase")
_commit_three_empty_rounds(slice)
assert_equal(
	slice.phase,
	IronAbacusSliceSession.Phase.ENGRAVING_REWARD,
	"zero dealer target should prepare reward"
)
assert_equal(slice.engraving_offer_ids.size(), 3, "reward should show three of four")
```

Define the test helpers in the same file rather than relying on undeclared fixture functions:

```gdscript
func _commit_three_empty_rounds(slice: IronAbacusSliceSession) -> void:
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := slice.encounter_session.current_session.commit()
		assert_true(
			slice.accept_encounter_report(report).accepted,
			"current committed report should be accepted"
		)
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(
				slice.advance_encounter_round().accepted,
				"summary should advance to the next round"
			)

func _verifiable_offer(slice: IronAbacusSliceSession) -> Dictionary:
	if &"engraving_prism" in slice.engraving_offer_ids:
		return {"id": &"engraving_prism", "face": 1}
	assert_true(
		&"engraving_anchor" in slice.engraving_offer_ids,
		"every three-of-four offer set must contain prism or anchor"
	)
	return {"id": &"engraving_anchor", "face": 2}
```

Then use independent fresh slice sessions for each boundary case:

- choose `_verifiable_offer(slice)` and install it on `d1` using the returned face;
- assert one profile changed and all others remain unengraved;
- assert invalid offer/die/face operations are atomic;
- assert the verification die's `rolled_value` equals the installed face;
- assign `d1` to the fixture's `right` one-slot even table, commit the actual resolver report,
  assert a matching applied event, and reach `COMPLETE`;
- in a fresh verification session, leave `d1` unassigned, commit the actual resolver report,
  assert no matching applied event, remain in `VERIFICATION`, retry, and compare dice/hands;
- in a fresh slice with dealer target `9999`, fail the dealer with three empty rounds, retry from
  the saved dealer boundary, and compare all three hands and eighteen rolled dice;
- start two fresh slices with the same seed and assert their normal hands/dice, dealer hands/dice,
  three-offer order, verification hand, and five non-forced verification dice match;
- after reaching `COMPLETE`, call `restart_slice()` and assert the purchase, tickets, offer,
  selected engraving, installed face, and all die engravings are reset to the initial slice state;
- attempt duplicate/stale reports and assert no phase change.

Use constructor target overrides only for tests:

```gdscript
func _init(
	p_seed_value: int = 20260726,
	p_normal_target: int = 100,
	p_dealer_target: int = 150
)
```

- [x] **Step 2: Run and verify the slice session is missing**

- [x] **Step 3: Add the phase enum and owned state**

Create the class with:

```gdscript
enum Phase {
	NOT_STARTED,
	NORMAL_ROOM,
	SHOP,
	DEALER,
	ENGRAVING_REWARD,
	ENGRAVING_INSTALL,
	VERIFICATION,
	COMPLETE,
	FAILED,
}

const VERIFICATION_HAND_SIZE := 4

var phase: Phase = Phase.NOT_STARTED
var seed_value: int
var normal_target: int
var dealer_target: int
var card_catalog := CardCatalog.new()
var dealer_catalog := DealerCatalog.new()
var engraving_catalog := EngravingCatalog.new()
var run_rng: RunRng
var encounter_session: ThreeRoundEncounterSession
var shop_session: ShopSession
var verification_session: SingleEncounterSession
var deck_ids: Array[StringName] = []
var intel_tickets: int = 0
var die_profiles: Array[DieState] = []
var engraving_offer_ids: Array[StringName] = []
var selected_engraving_id: StringName = &""
var installed_die_id: StringName = &""
var installed_face: int = 0
var failure_origin: Phase = Phase.NOT_STARTED
var last_error: String = ""
```

Store dealer and verification boundary snapshots as private dictionaries containing RNG state,
deck IDs, tickets, and cloned profiles.

- [x] **Step 4: Implement normal-room and shop transitions**

`start()` validates all three catalogs, initializes six profiles `d1..d6`, creates one shared RNG,
and starts a normal `ThreeRoundEncounterSession` with target override and shop preparation.

`accept_encounter_report(report)` delegates to the active three-round session. It does not
change `phase` for early summaries. On normal failure, set `FAILED` with origin `NORMAL_ROOM`.

`advance_encounter_round()` delegates only while the active session status is `ROUND_SUMMARY`.

`open_shop()` requires normal-room success and creates:

```gdscript
ShopSession.new(
	card_catalog,
	encounter_session.starter_deck_ids,
	encounter_session.shop_offer_ids,
	encounter_session.intel_tickets
)
```

`leave_shop()` copies deck and ticket values, saves the dealer boundary, and remains in `SHOP`
until `start_dealer()` is requested.

- [x] **Step 5: Implement dealer start, completion, and retry**

`start_dealer()` restores the saved boundary and starts a configured session:

```gdscript
var setup := EncounterRunSetup.new()
setup.run_rng = run_rng
setup.deck_ids = deck_ids
setup.encounter = SingleEncounterFixture.make_encounter()
setup.resolution_context = ResolutionContext.new(
	dealer_catalog.iron_abacus(),
	engraving_catalog
)
setup.success_intel_reward = 0
setup.prepare_shop_offers = false
setup.die_profiles = _clone_profiles(die_profiles)
encounter_session = ThreeRoundEncounterSession.new(
	card_catalog,
	seed_value,
	dealer_target,
	setup
)
```

On dealer failure, set `FAILED` with origin `DEALER`.
On dealer success, shuffle `engraving_catalog.all_ids()`, assign the first three IDs,
and set `ENGRAVING_REWARD`.

`retry_dealer()` requires a dealer-origin failure, restores the exact dealer boundary, and
calls the same private dealer creation method. A missing or malformed boundary returns a concrete
error without replacing the current RNG or encounter state.

- [x] **Step 6: Implement atomic engraving selection and installation**

`select_engraving(id)` accepts both `ENGRAVING_REWARD` and `ENGRAVING_INSTALL`, requires an ID in
current offers, stores the ID, and moves to `ENGRAVING_INSTALL`. Calling it again with another
offered ID replaces only the pending selection so the player can change a highlighted candidate
before confirmation.

`install_selected_engraving(die_id, face)`:

- validates selected offer;
- validates `d1..d6`;
- validates face `1..6`;
- rejects an already engraved profile;
- applies to cloned profiles;
- commits the clone only after every profile remains unique and legal;
- stores installed die/face;
- saves a verification boundary;
- creates verification and moves to `VERIFICATION`.

- [x] **Step 7: Implement one-round verification and retry**

Private verification creation:

1. Restore verification boundary RNG state.
2. Shuffle the inherited twelve-card deck via `CardDeck`.
3. Draw exactly four cards and resolve IDs through `CardCatalog`.
4. Roll five dice normally.
5. Set the installed die rolled/effective value to `installed_face`.
6. Copy engraving profiles into all six dice.
7. Create `SingleEncounterSession` with an engraving-only context.

`accept_verification_report(report)` verifies committed-report object identity, then checks:

```gdscript
var applied := report.events.any(
	func(event: ResolutionEvent) -> bool:
		return (
			event.source_id == selected_engraving_id
			and event.effect_applied
		)
)
```

Applied moves to `COMPLETE`. Otherwise remain `VERIFICATION`, set a concrete reason, and expose
`retry_verification()` to restore the boundary and recreate the same hand/dice. Missing or malformed
verification boundaries fail without consuming new randomness.

Add `restart_slice()` for normal failure, dealer failure, verification, and completion. It clears
all owned sessions, snapshots, deck/ticket state, offers, pending/installed engraving state, and die
profiles; resets `phase` to `NOT_STARTED`; then calls the same `start()` path with the original seed
and targets. It must not reuse the failed encounter's advanced RNG object.

- [x] **Step 8: Run the slice-domain test twice and the complete synchronous suite**

Expected: every phase and retry assertion passes twice; full suite remains clean.

- [x] **Step 9: Commit the slice domain**

```powershell
git add -- `
  scripts/run/iron_abacus_slice_session.gd `
  scripts/run/iron_abacus_slice_session.gd.uid `
  tests/iron_abacus_slice_session_test.gd `
  tests/iron_abacus_slice_session_test.gd.uid
git commit --only -m "feat: add iron abacus slice state machine" -- `
  scripts/run/iron_abacus_slice_session.gd `
  scripts/run/iron_abacus_slice_session.gd.uid `
  tests/iron_abacus_slice_session_test.gd `
  tests/iron_abacus_slice_session_test.gd.uid
```

---

### Task 7: Dealer, Engraving Reward, and Die Feedback Components

**Files:**
- Modify: `scripts/ui/die_token.gd`
- Modify: `scenes/components/die_token.tscn`
- Modify: `scripts/ui/rule_lane.gd`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/round_summary_panel.gd`
- Modify: `scenes/components/round_summary_panel.tscn`
- Create: `scripts/ui/engraving_option_token.gd`
- Create: `scenes/components/engraving_option_token.tscn`
- Create: `scripts/ui/engraving_reward_panel.gd`
- Create: `scenes/components/engraving_reward_panel.tscn`
- Modify: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: dealer definition, engraving catalog, current die state, slice-session reward state.
- Produces: visible dealer binding, non-color-only die engraving feedback, reward selection signals,
  dealer transition signal, and verification summary.

- [x] **Step 1: Add failing component contracts**

Append assertions that:

- `DieToken` has `bind_die_with_engravings`;
- `SingleEncounterScreen` has `bind_dealer`;
- `RoundSummaryPanel` emits `dealer_requested`, `dealer_retry_requested`, and
  `verification_retry_requested`, and exposes all three corresponding unique buttons;
- engraving option scene loads and emits `engraving_selected`;
- reward panel loads, has `bind_reward`, emits `install_requested`, and exposes unique
  `%OfferRow`, `%DieRow`, `%FaceGrid`, `%InstallEngravingButton`, `%RewardErrorLabel`.

Run `tests/run_all.gd`; expected failures name the missing interfaces.

- [x] **Step 2: Add die engraving copy**

Add a focused binding method:

```gdscript
func bind_die_with_engravings(
	state: DieState,
	selected: bool,
	catalog: EngravingCatalog = null,
	assigned: bool = false
) -> void:
	bind_die(state, selected)
	var engraving := (
		catalog.find_engraving(state.engraving_id)
		if catalog != null and state.engraving_id != &""
		else null
	)
	if engraving == null:
		return
	var face_hit := state.rolled_value == state.engraved_face
	var active := assigned and face_hit
	text = "%d\n%s %d面\n%s" % [
		state.value,
		engraving.display_name,
		state.engraved_face,
		"本轮激活" if active else ("刻印面命中" if face_hit else "未激活"),
	]
	tooltip_text = "骰子 %s：原始 %d，有效 %d；%s" % [
		state.id,
		state.rolled_value,
		state.value,
		engraving.rule_text,
	]
```

Increase token minimum size to `Vector2(82, 82)` and enable autowrap. Update `RuleLane.bind_lane`
to accept an optional catalog and call this method with `assigned = true`.
`SingleEncounterScreen.refresh_from_session` passes
`session.controller.resolution_context.engraving_catalog` for both lane and tray tokens, and passes
`assigned = false` for tray tokens. Thus an unassigned die may show “刻印面命中” but cannot falsely
claim that its engraving applied.

- [x] **Step 3: Bind dealer copy through unique scene nodes**

Mark `DealerEyebrow`, `DealerName`, `DealerRule`, and `DealerHint` unique in the `.tscn`.

Add:

```gdscript
func bind_dealer(dealer: DealerDefinition) -> void:
	if dealer == null:
		%DealerEyebrow.text = "规则监理 / MIRROR-01"
		%DealerName.text = "镜面夫人"
		%DealerRule.text = "本场规则\n从左向右逐轨解析。所有变化都会先出现在结算轨迹中。"
		return
	%DealerEyebrow.text = "庄家挑战 / %s" % String(dealer.id).to_upper()
	%DealerName.text = dealer.display_name
	%DealerRule.text = dealer.rule_text
```

During refresh, if a dealer exists, read the preview report and set the hint to:

```text
已分配：N / 6
当前固定奖励：R / 12
```

- [x] **Step 4: Add summary actions for dealer and verification**

Add signals and buttons:

```gdscript
signal dealer_requested
signal dealer_retry_requested
signal verification_retry_requested
```

Add `%ChallengeDealerButton` with text `挑战铁算盘` and
`%RetryDealerButton` with text `从庄家边界重试` and
`%RetryVerificationButton` with text `重试刻印验证`.

Add:

```gdscript
func show_dealer_ready(deck_ids: Array[StringName], intel_tickets: int) -> void
func show_dealer_failure(run_session: ThreeRoundEncounterSession) -> void
func show_verification_result(applied: bool, reason: String) -> void
```

`show_dealer_failure` includes target gap, `unassigned_dice`, and `dealer_reward_lost`. It exposes
dealer-boundary retry, the existing full-run retry, and return-to-teaching as three distinct actions.
Verification failure exposes verification-boundary retry, full-run retry, and return-to-teaching.
Each show method first hides every action button, then enables only its legal actions.

- [x] **Step 5: Create the engraving option token**

The token is a toggle `Button`, minimum `Vector2(260, 150)`, with:

```gdscript
signal engraving_selected(engraving_id: StringName)

var engraving_id: StringName

func bind_engraving(definition: EngravingDefinition, selected: bool) -> void:
	engraving_id = definition.id
	button_pressed = selected
	text = "%s\n%s\n%s" % [
		definition.display_name,
		" · ".join(definition.tags),
		definition.rule_text,
	]
	tooltip_text = definition.rule_text
```

- [x] **Step 6: Create the scene-first reward panel**

The root is a full-screen `Control` with dimmer and centered `PanelContainer`.
Stable scene nodes:

```text
RewardTitle
RewardRule
OfferRow
DieRow
FaceGrid (columns = 6)
RewardSelectionLabel
RewardErrorLabel
InstallEngravingButton
```

Controller signals:

```gdscript
signal engraving_selected(engraving_id: StringName)
signal die_selected(die_id: StringName)
signal face_selected(face: int)
signal install_requested(engraving_id: StringName, die_id: StringName, face: int)
```

`bind_reward(offer_ids, profiles, catalog)` rebuilds only the three dynamic containers using
`queue_free()`, creates exactly three option tokens, six die buttons, and six face buttons.
It stores selections locally for presentation only. Confirm remains disabled until all three
values are present and emits IDs without mutating profiles.

`show_error(message)` binds a domain error. `close()` hides the panel.

- [x] **Step 7: Import and run component, base layout, base input, tutorial layout, and tutorial input**

Expected: enlarged die tokens remain inside both tray and lanes; all old action paths pass.

- [x] **Step 8: Commit UI components only**

Commit explicit component/script/scene/test paths with:

```powershell
git add -- `
  scripts/ui/die_token.gd scenes/components/die_token.tscn `
  scripts/ui/rule_lane.gd `
  scripts/ui/single_encounter_screen.gd scenes/run/single_encounter_screen.tscn `
  scripts/ui/round_summary_panel.gd scenes/components/round_summary_panel.tscn `
  scripts/ui/engraving_option_token.gd scripts/ui/engraving_option_token.gd.uid `
  scenes/components/engraving_option_token.tscn `
  scripts/ui/engraving_reward_panel.gd scripts/ui/engraving_reward_panel.gd.uid `
  scenes/components/engraving_reward_panel.tscn `
  tests/ui_component_contract_test.gd
git commit --only -m "feat: add dealer and engraving ui components" -- `
  scripts/ui/die_token.gd scenes/components/die_token.tscn `
  scripts/ui/rule_lane.gd `
  scripts/ui/single_encounter_screen.gd scenes/run/single_encounter_screen.tscn `
  scripts/ui/round_summary_panel.gd scenes/components/round_summary_panel.tscn `
  scripts/ui/engraving_option_token.gd scripts/ui/engraving_option_token.gd.uid `
  scenes/components/engraving_option_token.tscn `
  scripts/ui/engraving_reward_panel.gd scripts/ui/engraving_reward_panel.gd.uid `
  scenes/components/engraving_reward_panel.tscn `
  tests/ui_component_contract_test.gd
```

---

### Task 8: Iron Abacus Slice Orchestration and Entry

**Files:**
- Create: `scripts/ui/iron_abacus_slice_screen.gd`
- Create: `scenes/run/iron_abacus_slice_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `tests/three_round_input_self_check.gd`
- Modify: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: `IronAbacusSliceSession`, `SingleEncounterScreen`, `ShopScreen`,
  `RoundSummaryPanel`, `EngravingRewardPanel`.
- Produces: full playable normal → shop → dealer → reward → verification flow.

- [x] **Step 1: Add a failing orchestration contract**

Append:

```gdscript
var slice_scene = load("res://scenes/run/iron_abacus_slice_screen.tscn")
assert_true(slice_scene != null, "Iron Abacus slice scene should load")
if slice_scene != null:
	var slice = slice_scene.instantiate()
	assert_true(slice.has_method("start_slice"), "slice screen should start domain flow")
	assert_true(slice.has_method("bind_current_encounter"), "slice should bind encounter")
	slice.free()
```

Run and verify the scene is missing.

- [x] **Step 2: Create the orchestration scene**

Use the same theme and full-root structure as `three_round_run_screen.tscn`, with these children
in this z-order:

```text
EncounterScreen (single_encounter_screen.tscn, tutorial_auto_start = false)
ShopScreen (shop_screen.tscn)
RoundSummaryPanel (round_summary_panel.tscn)
EngravingRewardPanel (engraving_reward_panel.tscn)
```

Every child has `unique_name_in_owner = true` and full anchors.

- [x] **Step 3: Implement screen startup and normal/dealer encounter binding**

Exports:

```gdscript
@export var run_seed: int = 20260726
@export var normal_target: int = 100
@export var dealer_target: int = 150
```

`start_slice()` creates the domain session, calls `start()`, then binds the current encounter.

`bind_current_encounter()` chooses copy by phase:

- normal: `金线回廊 · 普通试局`;
- dealer: `金线回廊 · 铁算盘`;
- verification: `刻印验证 · 强制显示刻印面`.

It passes the current `SingleEncounterSession`, header/goal copy, and current dealer definition
to `SingleEncounterScreen`. It hides shop/reward and closes summary.

- [x] **Step 4: Wire normal rounds and shop**

On `round_committed`, call the slice domain:

- early round: show standard run summary;
- normal success: show existing shop entry;
- normal failure: show normal failure summary;
- dealer success: open reward panel;
- dealer failure: show dealer failure;
- verification: call verification acceptance and show completion/retry.

On shop entry, call `slice.open_shop()` and bind its actual `ShopSession`.
On shop leave, call `slice.leave_shop()`, hide shop, and show `show_dealer_ready(...)`.
On dealer request, call `slice.start_dealer()` and bind the dealer encounter.
Connect dealer-boundary retry to `slice.retry_dealer()`. Connect the existing `retry_requested`
signal to `slice.restart_slice()` in normal failure, dealer failure, verification, and completion.
Connect `return_requested` to the teaching scene. Every rejected operation is shown through the
visible encounter or summary error label rather than silently closing an overlay.

- [x] **Step 5: Wire engraving reward and verification**

After dealer success:

```gdscript
reward_panel.bind_reward(
	slice.engraving_offer_ids,
	slice.die_profiles,
	slice.engraving_catalog
)
```

On every reward candidate click, call `slice.select_engraving(id)` so changing the toggle also
changes the pending domain selection; die/face choices remain local in the panel. On install
request, reject the request if its engraving ID differs from `slice.selected_engraving_id`, then:

```gdscript
var result := slice.install_selected_engraving(die_id, face)
if not result.accepted:
	reward_panel.show_error(result.reason)
	return
reward_panel.close()
bind_current_encounter()
```

On failed verification retry, call `slice.retry_verification()` and rebind.
On completion, show engraved die ID, face, engraving name, final deck count, and remaining tickets.

- [x] **Step 6: Change teaching entry and preserve Stage 4 regression**

Change `_on_run_trial_pressed()` to:

```gdscript
get_tree().change_scene_to_file("res://scenes/run/iron_abacus_slice_screen.tscn")
```

Update the button tooltip to mention the ordinary room, Iron Abacus, and engraving verification.

`three_round_input_self_check.gd` must no longer click the teaching entry. Instead instantiate
`three_round_run_screen.tscn` directly, assign it to `current_scene`, and keep its three-round/shop
assertions unchanged. The new Stage 5 input test owns the real teaching-entry assertion.

- [x] **Step 7: Import and run synchronous and all pre-Stage-5 scene checks**

Expected: new scene contract passes; Stage 4 direct scene check and all existing tutorial checks pass.

- [x] **Step 8: Commit orchestration**

```powershell
git add -- `
  scripts/ui/iron_abacus_slice_screen.gd `
  scripts/ui/iron_abacus_slice_screen.gd.uid `
  scenes/run/iron_abacus_slice_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  tests/three_round_input_self_check.gd `
  tests/ui_component_contract_test.gd
git commit --only -m "feat: connect iron abacus engraving slice" -- `
  scripts/ui/iron_abacus_slice_screen.gd `
  scripts/ui/iron_abacus_slice_screen.gd.uid `
  scenes/run/iron_abacus_slice_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  tests/three_round_input_self_check.gd `
  tests/ui_component_contract_test.gd
```

---

### Task 9: Layout, Real Input, Visual Smoke, and Full Acceptance

**Files:**
- Create: `tests/stage5_layout_self_check.gd`
- Create: `tests/stage5_input_self_check.gd`
- Modify: `docs/superpowers/plans/2026-07-26-iron-abacus-engravings.md`

**Interfaces:**
- Consumes: the real teaching entry and complete Stage 5 scene.
- Produces: measured layout proof, real input proof, deterministic stability, clean logs, and final staged-document state.

- [x] **Step 1: Create the Stage 5 layout check**

At `1920×1080`:

1. Instantiate the Stage 5 scene with both targets overridden to `0`.
2. Assert encounter root, dealer panel, three lanes, dice tray, hand, and resolution panel fit.
3. Drive domain directly to shop and assert twelve deck cards plus three offers fit.
4. Drive to dealer and assert Iron Abacus name/rule/hint fit.
5. Drive to reward and assert three offers, six die buttons, six face buttons, summary, and confirm fit.
6. Install an engraving, open verification, and assert enlarged engraving die tokens fit tray/lane.

Use `Rect2.encloses()` and include measured rects in failure text:

```gdscript
func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s outside root; root=%s child=%s" % [label, parent_rect, child_rect]
	)
```

- [x] **Step 2: Run layout and fix only measured failures**

```powershell
$layoutLog = Join-Path $env:TEMP 'project-joker-stage5-layout.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $layoutLog -s res://tests/stage5_layout_self_check.gd
```

If enlarged dice cause overflow, reduce only their token minimum to the smallest readable measured
size before changing the established three-track hierarchy.

- [x] **Step 3: Create the complete real-input check**

Use `Window.push_input()` press/move/release helpers copied from the existing input checks.
Before the end-to-end entry path, create a focused `SingleEncounterScreen` with an active
`engraving_anchor` die and an adjust-die card. Real-click `d1` then `%PlusButton`, and separately
real-click the adjust-die card then `d1`; assert both attempts leave calibration points, die value,
played-card count, and undo history unchanged, while `%ErrorLabel` contains `锚定`.

The real path must:

1. Instantiate teaching screen with tutorial disabled.
2. Real-click `%RunTrialButton`.
3. Assert `current_scene is IronAbacusSliceScreen`.
4. Immediately set `slice.slice_session.encounter_session.target_total = 0`; after leaving the shop
   and before clicking the dealer button, set `slice.slice_session.dealer_target = 0`.
5. Real-click three normal commits and two next-round buttons.
6. Enter shop, select one real offer and one real deck card, confirm, and leave.
7. Click `%ChallengeDealerButton`.
8. Real-click three dealer commits and two next-round buttons.
9. Assert reward panel appears.
10. Inspect the three actual offers. Click prism with `d1` and face `1` when present; otherwise
    click anchor with `d1` and face `2`.
11. Click `%InstallEngravingButton`.
12. In verification, real-click `d1`, then the `right` one-slot even table. Prism makes face `1`
    pass parity; anchor uses the already-even face `2`.
13. Click confirm and assert a matching applied event and `COMPLETE`.

The three-of-four offer invariant guarantees at least one of prism or anchor is present, so the
real-input test has exactly the two deterministic branches above. Resolver unit tests, not this
end-to-end path, provide the exhaustive echo and bridge coverage.

Do not call signals directly. Re-find dynamic tokens after every panel refresh and reject queued
or disabled nodes.

- [x] **Step 4: Import and run the input check three consecutive times**

```powershell
$logs = @()
for ($i = 1; $i -le 3; $i++) {
    $log = Join-Path $env:TEMP ("project-joker-stage5-input-{0}.log" -f $i)
    $logs += $log
    & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
      --headless --path . --log-file $log -s res://tests/stage5_input_self_check.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$bad = Select-String -LiteralPath $logs -Pattern 'SCRIPT ERROR|Failed to load script'
if ($bad) { $bad; exit 1 }
```

Expected: three complete real-input passes.

- [x] **Step 5: Run complete automated acceptance**

Run, each with its own writable log:

1. Godot editor import.
2. `tests/run_all.gd`.
3. `single_encounter_layout_self_check.gd`.
4. `tutorial_layout_self_check.gd`.
5. `three_round_layout_self_check.gd`.
6. `stage5_layout_self_check.gd`.
7. `single_encounter_input_self_check.gd`.
8. `tutorial_input_self_check.gd`.
9. `three_round_input_self_check.gd`.
10. `stage5_input_self_check.gd`.
11. main scene `--quit-after 2`.

Collect every log path and fail if any contains:

```text
SCRIPT ERROR
Failed to load script
```

Print `STAGE5_ACCEPTANCE_PASS=11/11` only after all exit codes and the scan pass.

- [x] **Step 6: Capture and inspect eight visual smoke images**

Use a temporary, untracked capture script and the non-headless Godot renderer to capture:

- normal room at `1280×720` and `1920×1080`;
- Iron Abacus at both sizes;
- engraving reward at both sizes;
- verification with active engraving at both sizes.

Inspect that:

- dealer formula and current reward are readable;
- original/effective die values and engraving state are not clipped;
- all three offers, six dice, and six faces are readable;
- summary/reward overlays block underlying input;
- no betting, chips, loans, real-money, or probability-trigger copy appears.

Delete the temporary capture script and images after inspection; they must not appear in Git status.

- [x] **Step 7: Commit Stage 5 checks only**

```powershell
git add -- `
  tests/stage5_layout_self_check.gd tests/stage5_layout_self_check.gd.uid `
  tests/stage5_input_self_check.gd tests/stage5_input_self_check.gd.uid
git commit --only -m "test: verify iron abacus engraving flow" -- `
  tests/stage5_layout_self_check.gd tests/stage5_layout_self_check.gd.uid `
  tests/stage5_input_self_check.gd tests/stage5_input_self_check.gd.uid
```

- [x] **Step 8: Mark this plan complete and stage documents only**

Change every completed `- [x]` in this plan to `- [x]`, then:

```powershell
git add -- `
  docs/superpowers/specs/2026-07-26-three-round-deck-shop-design.md `
  docs/superpowers/plans/2026-07-26-three-round-deck-shop.md `
  docs/superpowers/specs/2026-07-26-iron-abacus-engravings-design.md `
  docs/superpowers/plans/2026-07-26-iron-abacus-engravings.md
git status --short
```

The tracked base design document remains outside this command because it is unchanged. Expected
final state:

```text
A  docs/superpowers/plans/2026-07-26-iron-abacus-engravings.md
A  docs/superpowers/plans/2026-07-26-three-round-deck-shop.md
A  docs/superpowers/specs/2026-07-26-iron-abacus-engravings-design.md
A  docs/superpowers/specs/2026-07-26-three-round-deck-shop-design.md
 M project.godot
```

No code, resource, scene, tool, or test file remains uncommitted.

## Exit Checklist

- [x] Iron Abacus content loads and validates.
- [x] Four engraving resources load with unique IDs and exact parameters.
- [x] Shared RNG snapshot and restore reproduce boundary state.
- [x] Die profiles preserve rolled value, effective value, engraving ID, and engraved face.
- [x] Active anchor rejects calibration and adjust-die cards atomically.
- [x] Dealer rewards for zero through six assigned dice are exact.
- [x] Echo, anchor, bridge, and prism each have positive and negative tests.
- [x] Diagnostic zero events do not satisfy verification.
- [x] Preview and commit event signatures include applied state and remain identical.
- [x] Parameterized dealer encounters inherit the modified twelve-card deck.
- [x] Normal-room shop results survive dealer failure and retry.
- [x] Full-slice restart clears purchases, tickets, offers, and installed engraving state.
- [x] Dealer target `150` and no-ticket reward are domain-owned.
- [x] Four engraving definitions produce deterministic three-offer order.
- [x] Engraving installation is atomic and targets a real die and face.
- [x] Verification forces only the installed die face.
- [x] Stage completion requires an applied engraving event.
- [x] Dealer, reward, and engraving state are visible without relying only on color.
- [x] Existing tutorial and Stage 4 regression paths pass.
- [x] New layout and real-input checks pass repeatedly.
- [x] All headless logs are free of script load and compile errors.
- [x] Eight visual smoke images pass inspection and are removed afterward.
- [x] Gambling/probability copy scan returns zero hits in gameplay source.
- [x] Stage design and plan documents remain staged and uncommitted.
- [x] The pre-existing `project.godot` modification remains unstaged and untouched.
