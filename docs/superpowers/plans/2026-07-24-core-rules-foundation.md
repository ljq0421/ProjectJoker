# Core Rules Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, headless-tested rules foundation for one three-table round, including dice adjustment and assignment, two-card play, preview, undo, and atomic commit.

**Architecture:** Keep gameplay state in `RefCounted` domain objects and authored definitions in custom `Resource` types. Every tentative action returns a cloned `RoundState`; one `RoundResolver` generates both preview and committed `ResolutionReport` objects so UI code added later never calculates score.

**Tech Stack:** Godot 4.6.1, typed GDScript, custom `Resource` definitions, `RandomNumberGenerator`, dependency-free headless self-check scripts.

## Global Constraints

- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` for automated checks; keep the GUI executable for editor use.
- Every headless command must pass `--log-file` to a writable path under `$env:TEMP`.
- A test run fails if its log contains `SCRIPT ERROR` or `Failed to load script`, even when Godot returns exit code `0`.
- Run Godot with `--import` after adding new `class_name` scripts, and track the generated `.gd.uid` files with their owning scripts.
- Target PC landscape; the current Godot Mobile renderer remains unchanged during this phase.
- Do not add third-party test or runtime dependencies.
- All randomness must use an injected `RunRng`; do not call global `rand*` functions.
- Card effects are deterministic and use a finite operation enum.
- Preview and commit must call the same `RoundResolver.resolve()` method.
- A round has six dice, two calibration points, at most two played cards, and three rule tables.
- Scores are integers; no global multiplier exists.
- Runtime IDs are `StringName` values and must not depend on node paths.
- This plan creates no player-facing UI and no production content library.
- Documentation files are staged with `git add` but never committed; code commits must use `git commit --only` with explicit code and test paths.

## Plan Boundary

This is the first of four implementation plans:

1. **Core rules foundation:** this document; produces a deterministic headless rules loop.
2. **Single-encounter UI:** three-lane scene, drag/click placement, cards, undo, prediction panel, and real input-path tests.
3. **Run progression:** rooms, shops, twelve-card deck replacement, dealers, engravings, saves, and three areas.
4. **Content and polish:** forty cards, eighteen tables, twelve engravings, accessibility, audiovisual feedback, and balance telemetry.

The first phase is complete when the integration test builds six dice, assigns them to three rules, plays a table modifier, previews 51 points, undoes it, replays it, and commits the exact same 51-point event stream.

## File Map

```text
res://
  scripts/
    cards/
      card_definition.gd
      card_rules.gd
      effect_spec.gd
      played_card.gd
    resolution/
      encounter_definition.gd
      resolution_event.gd
      resolution_report.gd
      round_resolver.gd
    rules/
      rule_definition.gd
      rule_evaluator.gd
      rule_result.gd
    run/
      action_history.gd
      action_result.gd
      card_deck.gd
      die_state.gd
      round_actions.gd
      round_controller.gd
      round_state.gd
      run_rng.gd
    validation/
      content_validator.gd
  tests/
    content_validator_test.gd
    framework_self_test.gd
    resolution_test.gd
    rng_and_deck_test.gd
    round_actions_test.gd
    round_controller_test.gd
    rule_evaluator_test.gd
    run_all.gd
    test_case.gd
```

---

### Task 1: Dependency-Free Headless Test Harness

**Files:**
- Create: `tests/test_case.gd`
- Create: `tests/framework_self_test.gd`
- Create: `tests/run_all.gd`

**Interfaces:**
- Consumes: Godot `SceneTree`, `DirAccess`, and `ResourceLoader`.
- Produces: `TestCase.failures`, `assert_equal()`, `assert_true()`, `assert_false()`, and a runner that executes every `res://tests/*_test.gd`.

- [x] **Step 1: Create the runner and a deliberately incomplete assertion base**

Create `tests/test_case.gd`:

```gdscript
class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

Create `tests/framework_self_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	assert_equal(2 + 2, 4, "assert_equal should accept equal values")
	assert_true(true, "assert_true should accept true")
	assert_false(false, "assert_false should accept false")
```

Create `tests/run_all.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	var directory := DirAccess.open("res://tests")
	if directory == null:
		push_error("Cannot open res://tests")
		quit(1)
		return

	var test_files: Array[String] = []
	for file_name in directory.get_files():
		if file_name.ends_with("_test.gd"):
			test_files.append(file_name)
	test_files.sort()

	var failure_count := 0
	for file_name in test_files:
		var suite_script := load("res://tests/%s" % file_name)
		if suite_script == null or not suite_script.can_instantiate():
			push_error("%s: failed to load test suite" % file_name)
			failure_count += 1
			continue
		var suite = suite_script.new()
		suite.run()
		if suite.failures.is_empty():
			print("PASS %s" % file_name)
		else:
			for failure in suite.failures:
				push_error("%s: %s" % [file_name, failure])
			failure_count += suite.failures.size()

	if failure_count == 0:
		print("ALL TESTS PASSED (%d suites)" % test_files.size())
		quit(0)
	else:
		push_error("%d TEST FAILURE(S)" % failure_count)
		quit(1)
```

- [x] **Step 2: Run the harness and verify that it fails**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-joker-headless.log" -s res://tests/run_all.gd
```

Expected: exit code `1` with a parser error stating that `assert_equal` or `assert_false` is not defined.

- [x] **Step 3: Complete the assertion base**

Replace `tests/test_case.gd` with:

```gdscript
class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)
```

- [x] **Step 4: Run the harness and verify that it passes**

Run the command from Step 2.

Expected:

```text
PASS framework_self_test.gd
ALL TESTS PASSED (1 suites)
```

- [x] **Step 5: Commit only the test harness code**

```powershell
git add tests/test_case.gd tests/framework_self_test.gd tests/run_all.gd
git commit --only tests/test_case.gd tests/framework_self_test.gd tests/run_all.gd -m "test: add headless gdscript harness"
```

---

### Task 2: Rule Definitions and Evaluation

**Files:**
- Create: `scripts/rules/rule_definition.gd`
- Create: `scripts/rules/rule_result.gd`
- Create: `scripts/rules/rule_evaluator.gd`
- Create: `tests/rule_evaluator_test.gd`

**Interfaces:**
- Consumes: arrays of integer die values.
- Produces: `RuleEvaluator.evaluate(definition, values, coefficient_modifier) -> RuleResult`.

- [x] **Step 1: Write failing tests for exact sum, parity, and consecutive rules**

Create `tests/rule_evaluator_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const RuleEvaluatorScript = preload("res://scripts/rules/rule_evaluator.gd")

func run() -> void:
	var evaluator := RuleEvaluatorScript.new()

	var exact := RuleDefinitionScript.new()
	exact.id = &"exact_7"
	exact.condition_type = RuleDefinitionScript.ConditionType.EXACT_SUM
	exact.slot_count = 2
	exact.target_value = 7
	exact.coefficient = 2
	var exact_result = evaluator.evaluate(exact, [1, 6])
	assert_true(exact_result.valid, "1 + 6 should satisfy exact sum 7")
	assert_equal(exact_result.total, 14, "exact sum should use sum times coefficient")

	var even := RuleDefinitionScript.new()
	even.id = &"all_even"
	even.condition_type = RuleDefinitionScript.ConditionType.ALL_EVEN
	even.slot_count = 2
	even.coefficient = 3
	assert_false(evaluator.evaluate(even, [2, 5]).valid, "odd values should fail all-even")

	var consecutive := RuleDefinitionScript.new()
	consecutive.id = &"three_consecutive"
	consecutive.condition_type = RuleDefinitionScript.ConditionType.CONSECUTIVE
	consecutive.slot_count = 3
	consecutive.coefficient = 2
	var consecutive_result = evaluator.evaluate(consecutive, [4, 2, 3])
	assert_true(consecutive_result.valid, "unordered 2,3,4 should be consecutive")
	assert_equal(consecutive_result.total, 18, "2 + 3 + 4 at coefficient 2 should score 18")

	var modified_result = evaluator.evaluate(exact, [1, 6], 1)
	assert_equal(modified_result.total, 21, "coefficient modifiers should be additive")
```

- [x] **Step 2: Run the tests and verify that resource preloads fail**

Run the headless test command from Task 1.

Expected: exit code `1` because `res://scripts/rules/rule_definition.gd` does not exist.

- [x] **Step 3: Implement the rule types and evaluator**

Create `scripts/rules/rule_definition.gd`:

```gdscript
class_name RuleDefinition
extends Resource

enum ConditionType {
	EXACT_SUM,
	ALL_EVEN,
	CONSECUTIVE,
}

@export var id: StringName
@export var display_name: String
@export var condition_type: ConditionType = ConditionType.EXACT_SUM
@export_range(1, 6, 1) var slot_count: int = 1
@export var target_value: int = 0
@export_range(1, 20, 1) var coefficient: int = 1
@export var flat_bonus: int = 0
```

Create `scripts/rules/rule_result.gd`:

```gdscript
class_name RuleResult
extends RefCounted

var valid: bool
var base_sum: int
var total: int
var reason: String

func _init(
	p_valid: bool,
	p_base_sum: int,
	p_total: int,
	p_reason: String = ""
) -> void:
	valid = p_valid
	base_sum = p_base_sum
	total = p_total
	reason = p_reason
```

Create `scripts/rules/rule_evaluator.gd`:

```gdscript
class_name RuleEvaluator
extends RefCounted

func evaluate(
	definition: RuleDefinition,
	values: Array,
	coefficient_modifier: int = 0
) -> RuleResult:
	if values.size() != definition.slot_count:
		return RuleResult.new(false, 0, 0, "requires %d dice" % definition.slot_count)

	var typed_values: Array[int] = []
	for value in values:
		var int_value := int(value)
		if int_value < 1 or int_value > 6:
			return RuleResult.new(false, 0, 0, "die values must be between 1 and 6")
		typed_values.append(int_value)

	var valid := _matches(definition, typed_values)
	var base_sum := _sum(typed_values)
	if not valid:
		return RuleResult.new(false, base_sum, 0, "condition not satisfied")

	var effective_coefficient := definition.coefficient + coefficient_modifier
	if effective_coefficient < 0:
		return RuleResult.new(false, base_sum, 0, "effective coefficient cannot be negative")
	return RuleResult.new(
		true,
		base_sum,
		base_sum * effective_coefficient + definition.flat_bonus
	)

func _matches(definition: RuleDefinition, values: Array[int]) -> bool:
	match definition.condition_type:
		RuleDefinition.ConditionType.EXACT_SUM:
			return _sum(values) == definition.target_value
		RuleDefinition.ConditionType.ALL_EVEN:
			return values.all(func(value: int) -> bool: return value % 2 == 0)
		RuleDefinition.ConditionType.CONSECUTIVE:
			var sorted_values := values.duplicate()
			sorted_values.sort()
			for index in range(1, sorted_values.size()):
				if sorted_values[index] != sorted_values[index - 1] + 1:
					return false
			return true
	return false

func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
```

- [x] **Step 4: Run all tests and verify the evaluator passes**

Run the headless test command.

Expected: `PASS rule_evaluator_test.gd` followed by `ALL TESTS PASSED`.

- [x] **Step 5: Commit only the rule evaluator code**

```powershell
git add scripts/rules tests/rule_evaluator_test.gd
git commit --only scripts/rules tests/rule_evaluator_test.gd -m "feat: add deterministic rule evaluation"
```

---

### Task 3: Round State and Reversible Dice Actions

**Files:**
- Create: `scripts/run/die_state.gd`
- Create: `scripts/run/round_state.gd`
- Create: `scripts/run/action_result.gd`
- Create: `scripts/run/round_actions.gd`
- Create: `tests/round_actions_test.gd`

**Interfaces:**
- Consumes: a `RoundState`, die ID, table ID, and requested adjustment or slot limit.
- Produces: `ActionResult.accepted`, `reason`, and a cloned `next_state`.

- [x] **Step 1: Write failing tests for calibration and exclusive assignment**

Create `tests/round_actions_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RoundActionsScript = preload("res://scripts/run/round_actions.gd")

func run() -> void:
	var state := RoundStateScript.new()
	state.dice = [
		DieStateScript.new(&"d1", 1),
		DieStateScript.new(&"d2", 6),
	]

	var adjusted = RoundActionsScript.adjust_die(state, &"d1", 1)
	assert_true(adjusted.accepted, "a +1 calibration should be accepted")
	assert_equal(adjusted.next_state.find_die(&"d1").value, 2, "calibration should change cloned state")
	assert_equal(state.find_die(&"d1").value, 1, "calibration must not mutate original state")
	assert_equal(adjusted.next_state.calibration_points, 1, "calibration should consume one point")

	var out_of_range = RoundActionsScript.adjust_die(state, &"d2", 1)
	assert_false(out_of_range.accepted, "a die cannot be calibrated above 6")

	var first_assignment = RoundActionsScript.assign_die(state, &"d1", &"left", 2)
	var moved_assignment = RoundActionsScript.assign_die(first_assignment.next_state, &"d1", &"right", 1)
	assert_equal(moved_assignment.next_state.assignments[&"left"].size(), 0, "moving should clear old table")
	assert_equal(moved_assignment.next_state.assignments[&"right"], [&"d1"], "die should exist in one table")

	var full_table = RoundActionsScript.assign_die(moved_assignment.next_state, &"d2", &"right", 1)
	assert_false(full_table.accepted, "assignment should reject a full table")
```

- [x] **Step 2: Run tests and verify missing script failure**

Run the headless test command.

Expected: exit code `1` because `die_state.gd` does not exist.

- [x] **Step 3: Implement immutable round actions**

Create `scripts/run/die_state.gd`:

```gdscript
class_name DieState
extends RefCounted

var id: StringName
var value: int
var engraving_id: StringName

func _init(p_id: StringName, p_value: int, p_engraving_id: StringName = &"") -> void:
	id = p_id
	value = p_value
	engraving_id = p_engraving_id

func clone() -> DieState:
	return DieState.new(id, value, engraving_id)
```

Create `scripts/run/round_state.gd`:

```gdscript
class_name RoundState
extends RefCounted

var dice: Array[DieState] = []
var assignments: Dictionary = {}
var played_cards: Array = []
var calibration_points: int = 2

func find_die(die_id: StringName) -> DieState:
	for die in dice:
		if die.id == die_id:
			return die
	return null

func clone() -> RoundState:
	var copy := RoundState.new()
	copy.dice = []
	for die in dice:
		copy.dice.append(die.clone())
	copy.assignments = {}
	for table_id in assignments:
		copy.assignments[table_id] = assignments[table_id].duplicate()
	copy.played_cards = []
	for played_card in played_cards:
		copy.played_cards.append(played_card.clone())
	copy.calibration_points = calibration_points
	return copy
```

Create `scripts/run/action_result.gd`:

```gdscript
class_name ActionResult
extends RefCounted

var accepted: bool
var reason: String
var next_state: RoundState

func _init(p_accepted: bool, p_reason: String, p_next_state: RoundState) -> void:
	accepted = p_accepted
	reason = p_reason
	next_state = p_next_state
```

Create `scripts/run/round_actions.gd`:

```gdscript
class_name RoundActions
extends RefCounted

static func adjust_die(state: RoundState, die_id: StringName, delta: int) -> ActionResult:
	if delta != -1 and delta != 1:
		return ActionResult.new(false, "calibration delta must be -1 or +1", state)
	if state.calibration_points <= 0:
		return ActionResult.new(false, "no calibration points remain", state)
	var current := state.find_die(die_id)
	if current == null:
		return ActionResult.new(false, "die does not exist", state)
	var next_value := current.value + delta
	if next_value < 1 or next_value > 6:
		return ActionResult.new(false, "calibration would leave range 1..6", state)

	var next_state := state.clone()
	next_state.find_die(die_id).value = next_value
	next_state.calibration_points -= 1
	return ActionResult.new(true, "", next_state)

static func assign_die(
	state: RoundState,
	die_id: StringName,
	table_id: StringName,
	slot_limit: int
) -> ActionResult:
	if state.find_die(die_id) == null:
		return ActionResult.new(false, "die does not exist", state)
	if table_id == &"":
		return ActionResult.new(false, "table ID is required", state)

	var occupied: Array = state.assignments.get(table_id, [])
	if die_id not in occupied and occupied.size() >= slot_limit:
		return ActionResult.new(false, "rule table is full", state)

	var next_state := state.clone()
	for assigned_table_id in next_state.assignments:
		next_state.assignments[assigned_table_id].erase(die_id)
	if not next_state.assignments.has(table_id):
		next_state.assignments[table_id] = []
	if die_id not in next_state.assignments[table_id]:
		next_state.assignments[table_id].append(die_id)
	return ActionResult.new(true, "", next_state)

static func unassign_die(state: RoundState, die_id: StringName) -> ActionResult:
	var next_state := state.clone()
	var removed := false
	for table_id in next_state.assignments:
		if die_id in next_state.assignments[table_id]:
			next_state.assignments[table_id].erase(die_id)
			removed = true
	if not removed:
		return ActionResult.new(false, "die is not assigned", state)
	return ActionResult.new(true, "", next_state)
```

- [x] **Step 4: Run all tests**

Expected: `PASS round_actions_test.gd` and no mutation failure.

- [x] **Step 5: Commit only the round action code**

```powershell
git add scripts/run tests/round_actions_test.gd
git commit --only scripts/run tests/round_actions_test.gd -m "feat: add reversible dice round actions"
```

---

### Task 4: Finite Card Effect Definitions and Two-Card Limit

**Files:**
- Create: `scripts/cards/effect_spec.gd`
- Create: `scripts/cards/card_definition.gd`
- Create: `scripts/cards/played_card.gd`
- Create: `scripts/cards/card_rules.gd`
- Create: `tests/card_rules_test.gd`

**Interfaces:**
- Consumes: `RoundState` and `PlayedCard`.
- Produces: deterministic card resources and `CardRules.play_card() -> ActionResult`.

- [x] **Step 1: Write failing tests for card targets and the two-card limit**

Create `tests/card_rules_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const RoundStateScript = preload("res://scripts/run/round_state.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")
const CardRulesScript = preload("res://scripts/cards/card_rules.gd")

func run() -> void:
	var boost := CardDefinitionScript.new()
	boost.id = &"diamond_boost"
	boost.display_name = "映射"
	boost.target_type = CardDefinitionScript.TargetType.TABLE

	var state := RoundStateScript.new()
	var first = CardRulesScript.play_card(state, PlayedCardScript.new(boost, &"left"))
	assert_true(first.accepted, "first card should be accepted")
	assert_equal(first.next_state.played_cards.size(), 1, "first card should enter cloned state")
	assert_equal(state.played_cards.size(), 0, "playing a card must not mutate original state")

	var second = CardRulesScript.play_card(first.next_state, PlayedCardScript.new(boost, &"middle"))
	var third = CardRulesScript.play_card(second.next_state, PlayedCardScript.new(boost, &"right"))
	assert_true(second.accepted, "second card should be accepted")
	assert_false(third.accepted, "third card should exceed the round limit")

	var no_target = CardRulesScript.play_card(state, PlayedCardScript.new(boost, &""))
	assert_false(no_target.accepted, "targeted cards require a target ID")
```

- [x] **Step 2: Run tests and verify missing card scripts**

Run the headless test command.

Expected: exit code `1` because `card_definition.gd` does not exist.

- [x] **Step 3: Implement card and effect resources**

Create `scripts/cards/effect_spec.gd`:

```gdscript
class_name EffectSpec
extends Resource

enum Operation {
	ADJUST_DIE,
	MODIFY_COEFFICIENT,
	REPEAT_TABLE,
	REVERSE_RESOLUTION,
}

@export var operation: Operation = Operation.ADJUST_DIE
@export var amount: int = 0
```

Create `scripts/cards/card_definition.gd`:

```gdscript
class_name CardDefinition
extends Resource

enum TargetType {
	DIE,
	TABLE,
	GAP,
	GLOBAL,
}

@export var id: StringName
@export var display_name: String
@export var target_type: TargetType = TargetType.DIE
@export var effects: Array[EffectSpec] = []
```

Create `scripts/cards/played_card.gd`:

```gdscript
class_name PlayedCard
extends RefCounted

var definition: CardDefinition
var primary_target: StringName
var secondary_target: StringName

func _init(
	p_definition: CardDefinition,
	p_primary_target: StringName = &"",
	p_secondary_target: StringName = &""
) -> void:
	definition = p_definition
	primary_target = p_primary_target
	secondary_target = p_secondary_target

func clone() -> PlayedCard:
	return PlayedCard.new(definition, primary_target, secondary_target)
```

Create `scripts/cards/card_rules.gd`:

```gdscript
class_name CardRules
extends RefCounted

const MAX_CARDS_PER_ROUND := 2

static func play_card(state: RoundState, played_card: PlayedCard) -> ActionResult:
	if played_card.definition == null:
		return ActionResult.new(false, "card definition is required", state)
	if state.played_cards.size() >= MAX_CARDS_PER_ROUND:
		return ActionResult.new(false, "at most two cards may be played per round", state)
	if (
		played_card.definition.target_type != CardDefinition.TargetType.GLOBAL
		and played_card.primary_target == &""
	):
		return ActionResult.new(false, "card target is required", state)

	var next_state := state.clone()
	next_state.played_cards.append(played_card.clone())
	return ActionResult.new(true, "", next_state)
```

- [x] **Step 4: Run all tests**

Expected: `PASS card_rules_test.gd` followed by `ALL TESTS PASSED`.

- [x] **Step 5: Commit only the card definition code**

```powershell
git add scripts/cards tests/card_rules_test.gd
git commit --only scripts/cards tests/card_rules_test.gd -m "feat: add finite card effect definitions"
```

---

### Task 5: Shared Preview and Commit Resolver

**Files:**
- Create: `scripts/resolution/encounter_definition.gd`
- Create: `scripts/resolution/resolution_event.gd`
- Create: `scripts/resolution/resolution_report.gd`
- Create: `scripts/resolution/round_resolver.gd`
- Create: `tests/resolution_test.gd`

**Interfaces:**
- Consumes: `RoundState` and an ordered `EncounterDefinition.rules`.
- Produces: `RoundResolver.resolve(state, encounter) -> ResolutionReport` with ordered events and integer total.

- [x] **Step 1: Write a failing three-table resolution test**

Create `tests/resolution_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const EncounterDefinitionScript = preload("res://scripts/resolution/encounter_definition.gd")
const RoundResolverScript = preload("res://scripts/resolution/round_resolver.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")

func run() -> void:
	var state = _build_state()
	var encounter = _build_encounter()
	var report = RoundResolverScript.new().resolve(state, encounter)
	assert_true(report.valid, "configured round should resolve")
	assert_equal(report.total, 51, "three tables and coefficient card should total 51")
	assert_equal(report.events.size(), 4, "one card event and three table events are expected")
	assert_equal(report.events[1].source_id, &"left", "left table should resolve first")

func _build_state():
	var state := RoundStateScript.new()
	for value in range(1, 7):
		state.dice.append(DieStateScript.new(StringName("d%d" % value), value))
	state.find_die(&"d5").value = 4
	state.assignments = {
		&"left": [&"d1", &"d6"],
		&"middle": [&"d2", &"d3", &"d4"],
		&"right": [&"d5"],
	}

	var effect := EffectSpecScript.new()
	effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	effect.amount = 1
	var card := CardDefinitionScript.new()
	card.id = &"diamond_boost"
	card.display_name = "映射"
	card.target_type = CardDefinitionScript.TargetType.TABLE
	card.effects = [effect]
	state.played_cards = [PlayedCardScript.new(card, &"left")]
	return state

func _build_encounter():
	var left = _rule(&"left", RuleDefinitionScript.ConditionType.EXACT_SUM, 2, 2, 7)
	var middle = _rule(&"middle", RuleDefinitionScript.ConditionType.CONSECUTIVE, 3, 2)
	var right = _rule(&"right", RuleDefinitionScript.ConditionType.ALL_EVEN, 1, 3)
	var encounter := EncounterDefinitionScript.new()
	encounter.id = &"foundation_round"
	encounter.rules = [left, middle, right]
	return encounter

func _rule(id: StringName, type: int, slots: int, coefficient: int, target: int = 0):
	var rule := RuleDefinitionScript.new()
	rule.id = id
	rule.condition_type = type
	rule.slot_count = slots
	rule.coefficient = coefficient
	rule.target_value = target
	return rule
```

- [x] **Step 2: Run tests and verify missing resolver failure**

Expected: exit code `1` because `round_resolver.gd` does not exist.

- [x] **Step 3: Implement ordered resolution events**

Create `scripts/resolution/encounter_definition.gd`:

```gdscript
class_name EncounterDefinition
extends Resource

@export var id: StringName
@export var rules: Array[RuleDefinition] = []
```

Create `scripts/resolution/resolution_event.gd`:

```gdscript
class_name ResolutionEvent
extends RefCounted

var source_id: StringName
var label: String
var delta: int
var running_total: int

func _init(
	p_source_id: StringName,
	p_label: String,
	p_delta: int,
	p_running_total: int
) -> void:
	source_id = p_source_id
	label = p_label
	delta = p_delta
	running_total = p_running_total
```

Create `scripts/resolution/resolution_report.gd`:

```gdscript
class_name ResolutionReport
extends RefCounted

var valid: bool = true
var reason: String = ""
var total: int = 0
var events: Array[ResolutionEvent] = []

func event_signature() -> Array[String]:
	var signature: Array[String] = []
	for event in events:
		signature.append("%s|%s|%d|%d" % [
			event.source_id,
			event.label,
			event.delta,
			event.running_total,
		])
	return signature
```

Create `scripts/resolution/round_resolver.gd`:

```gdscript
class_name RoundResolver
extends RefCounted

var _evaluator := RuleEvaluator.new()

func resolve(state: RoundState, encounter: EncounterDefinition) -> ResolutionReport:
	var report := ResolutionReport.new()
	var die_values: Dictionary = {}
	for die in state.dice:
		die_values[die.id] = die.value

	var coefficient_modifiers: Dictionary = {}
	var repeat_counts: Dictionary = {}
	var reverse_order := false

	for played_card in state.played_cards:
		for effect in played_card.definition.effects:
			match effect.operation:
				EffectSpec.Operation.ADJUST_DIE:
					if not die_values.has(played_card.primary_target):
						return _invalid("card targets an unknown die")
					die_values[played_card.primary_target] = clampi(
						die_values[played_card.primary_target] + effect.amount,
						1,
						6
					)
				EffectSpec.Operation.MODIFY_COEFFICIENT:
					coefficient_modifiers[played_card.primary_target] = (
						coefficient_modifiers.get(played_card.primary_target, 0) + effect.amount
					)
				EffectSpec.Operation.REPEAT_TABLE:
					repeat_counts[played_card.primary_target] = (
						repeat_counts.get(played_card.primary_target, 0) + effect.amount
					)
				EffectSpec.Operation.REVERSE_RESOLUTION:
					reverse_order = not reverse_order
		report.events.append(ResolutionEvent.new(
			played_card.definition.id,
			played_card.definition.display_name,
			0,
			report.total
		))

	var ordered_rules := encounter.rules.duplicate()
	if reverse_order:
		ordered_rules.reverse()

	for rule in ordered_rules:
		var assigned_ids: Array = state.assignments.get(rule.id, [])
		var values: Array[int] = []
		for die_id in assigned_ids:
			if not die_values.has(die_id):
				return _invalid("assignment references an unknown die")
			values.append(die_values[die_id])

		var result := _evaluator.evaluate(
			rule,
			values,
			coefficient_modifiers.get(rule.id, 0)
		)
		if not result.valid:
			report.events.append(ResolutionEvent.new(rule.id, result.reason, 0, report.total))
			continue

		var resolution_count: int = 1 + repeat_counts.get(rule.id, 0)
		for repeat_index in range(resolution_count):
			report.total += result.total
			var label: String = rule.display_name
			if label.is_empty():
				label = String(rule.id)
			if repeat_index > 0:
				label += "（重复）"
			report.events.append(ResolutionEvent.new(
				rule.id,
				label,
				result.total,
				report.total
			))
	return report

func _invalid(reason: String) -> ResolutionReport:
	var report := ResolutionReport.new()
	report.valid = false
	report.reason = reason
	return report
```

- [x] **Step 4: Run all tests and verify the total is 51**

Expected: `PASS resolution_test.gd`; no mismatch between event order and total.

- [x] **Step 5: Commit only the resolver code**

```powershell
git add scripts/resolution tests/resolution_test.gd
git commit --only scripts/resolution tests/resolution_test.gd -m "feat: add shared round resolution report"
```

---

### Task 6: Seeded Dice and Twelve-Card Encounter Deck

**Files:**
- Create: `scripts/run/run_rng.gd`
- Create: `scripts/run/card_deck.gd`
- Create: `tests/rng_and_deck_test.gd`

**Interfaces:**
- Consumes: a signed 64-bit seed and twelve card IDs.
- Produces: deterministic `roll_die()`, `shuffle()`, and three non-overlapping four-card hands.

- [x] **Step 1: Write failing deterministic RNG and deck tests**

Create `tests/rng_and_deck_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const RunRngScript = preload("res://scripts/run/run_rng.gd")
const CardDeckScript = preload("res://scripts/run/card_deck.gd")

func run() -> void:
	var first_rng := RunRngScript.new(20260724)
	var second_rng := RunRngScript.new(20260724)
	var first_rolls: Array[int] = []
	var second_rolls: Array[int] = []
	for index in range(6):
		first_rolls.append(first_rng.roll_die())
		second_rolls.append(second_rng.roll_die())
	assert_equal(first_rolls, second_rolls, "equal seeds should produce equal dice")

	var ids: Array[StringName] = []
	for index in range(12):
		ids.append(StringName("card_%02d" % index))
	var deck := CardDeckScript.new()
	deck.start_encounter(ids, RunRngScript.new(99))
	var seen: Array[StringName] = []
	for round_index in range(3):
		var hand := deck.draw_round()
		assert_equal(hand.size(), 4, "each round should draw four cards")
		seen.append_array(hand)
	assert_equal(seen.size(), 12, "three rounds should expose twelve cards")
	var unique := {}
	for card_id in seen:
		unique[card_id] = true
	assert_equal(unique.size(), 12, "encounter hands must not repeat cards")
	assert_equal(deck.draw_round().size(), 0, "deck should be empty after three hands")
```

- [x] **Step 2: Run tests and verify missing RNG failure**

Expected: exit code `1` because `run_rng.gd` does not exist.

- [x] **Step 3: Implement the injected RNG and fixed encounter deck**

Create `scripts/run/run_rng.gd`:

```gdscript
class_name RunRng
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int) -> void:
	_rng.seed = seed_value

func roll_die() -> int:
	return _rng.randi_range(1, 6)

func shuffle(values: Array) -> Array:
	var shuffled := values.duplicate()
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = temporary
	return shuffled
```

Create `scripts/run/card_deck.gd`:

```gdscript
class_name CardDeck
extends RefCounted

const HAND_SIZE := 4

var _draw_pile: Array[StringName] = []

func start_encounter(card_ids: Array[StringName], run_rng: RunRng) -> void:
	assert(card_ids.size() == 12, "an encounter deck must contain exactly twelve cards")
	_draw_pile.assign(run_rng.shuffle(card_ids))

func draw_round() -> Array[StringName]:
	var hand: Array[StringName] = []
	for draw_index in range(mini(HAND_SIZE, _draw_pile.size())):
		hand.append(_draw_pile.pop_front())
	return hand
```

- [x] **Step 4: Run all tests twice**

Run the headless command twice.

Expected: both runs pass, and the deterministic tests report no difference.

- [x] **Step 5: Commit only the RNG and deck code**

```powershell
git add scripts/run/run_rng.gd scripts/run/card_deck.gd tests/rng_and_deck_test.gd
git commit --only scripts/run/run_rng.gd scripts/run/card_deck.gd tests/rng_and_deck_test.gd -m "feat: add seeded dice and encounter deck"
```

---

### Task 7: Undoable Round Controller and Preview/Commit Equivalence

**Files:**
- Create: `scripts/run/action_history.gd`
- Create: `scripts/run/round_controller.gd`
- Create: `tests/round_controller_test.gd`

**Interfaces:**
- Consumes: a starting `RoundState`, `EncounterDefinition`, and domain actions.
- Produces: `preview()`, `commit()`, `undo()`, and the current tentative state.

- [x] **Step 1: Write the failing end-to-end controller test**

Create `tests/round_controller_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const DieStateScript = preload("res://scripts/run/die_state.gd")
const RoundStateScript = preload("res://scripts/run/round_state.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const EncounterDefinitionScript = preload("res://scripts/resolution/encounter_definition.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")
const PlayedCardScript = preload("res://scripts/cards/played_card.gd")
const RoundControllerScript = preload("res://scripts/run/round_controller.gd")

func run() -> void:
	var controller := RoundControllerScript.new(_state(), _encounter())
	assert_true(controller.assign_die(&"d1", &"left", 2).accepted, "assign d1")
	assert_true(controller.assign_die(&"d6", &"left", 2).accepted, "assign d6")
	assert_true(controller.assign_die(&"d2", &"middle", 3).accepted, "assign d2")
	assert_true(controller.assign_die(&"d3", &"middle", 3).accepted, "assign d3")
	assert_true(controller.assign_die(&"d4", &"middle", 3).accepted, "assign d4")
	assert_true(controller.adjust_die(&"d5", -1).accepted, "calibrate d5 from 5 to 4")
	assert_true(controller.assign_die(&"d5", &"right", 1).accepted, "assign d5")

	var played := PlayedCardScript.new(_boost_card(), &"left")
	assert_true(controller.play_card(played).accepted, "play coefficient card")
	var preview = controller.preview()
	assert_equal(preview.total, 51, "preview should total 51")

	assert_true(controller.undo(), "card play should be undoable")
	assert_equal(controller.preview().total, 44, "undo should remove the coefficient card")
	assert_true(controller.play_card(played).accepted, "card should be playable again")

	var final_preview = controller.preview()
	var committed = controller.commit()
	assert_equal(committed.total, final_preview.total, "commit total must equal preview")
	assert_equal(
		committed.event_signature(),
		final_preview.event_signature(),
		"commit events must equal preview events"
	)
	assert_false(controller.adjust_die(&"d1", 1).accepted, "committed rounds reject further actions")

func _state():
	var state := RoundStateScript.new()
	for value in range(1, 7):
		state.dice.append(DieStateScript.new(StringName("d%d" % value), value))
	return state

func _encounter():
	var encounter := EncounterDefinitionScript.new()
	encounter.id = &"controller_round"
	encounter.rules = [
		_rule(&"left", RuleDefinitionScript.ConditionType.EXACT_SUM, 2, 2, 7),
		_rule(&"middle", RuleDefinitionScript.ConditionType.CONSECUTIVE, 3, 2),
		_rule(&"right", RuleDefinitionScript.ConditionType.ALL_EVEN, 1, 3),
	]
	return encounter

func _rule(id: StringName, type: int, slots: int, coefficient: int, target: int = 0):
	var rule := RuleDefinitionScript.new()
	rule.id = id
	rule.condition_type = type
	rule.slot_count = slots
	rule.coefficient = coefficient
	rule.target_value = target
	return rule

func _boost_card():
	var effect := EffectSpecScript.new()
	effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	effect.amount = 1
	var card := CardDefinitionScript.new()
	card.id = &"diamond_boost"
	card.display_name = "映射"
	card.target_type = CardDefinitionScript.TargetType.TABLE
	card.effects = [effect]
	return card
```

- [x] **Step 2: Run tests and verify missing controller failure**

Expected: exit code `1` because `round_controller.gd` does not exist.

- [x] **Step 3: Implement snapshot history and controller**

Create `scripts/run/action_history.gd`:

```gdscript
class_name ActionHistory
extends RefCounted

var _states: Array[RoundState] = []

func _init(initial_state: RoundState) -> void:
	_states.append(initial_state.clone())

func push(state: RoundState) -> void:
	_states.append(state.clone())

func undo() -> RoundState:
	if _states.size() <= 1:
		return null
	_states.pop_back()
	return _states.back().clone()
```

Create `scripts/run/round_controller.gd`:

```gdscript
class_name RoundController
extends RefCounted

var state: RoundState
var encounter: EncounterDefinition
var committed: bool = false

var _history: ActionHistory
var _resolver := RoundResolver.new()
var _committed_report: ResolutionReport

func _init(p_state: RoundState, p_encounter: EncounterDefinition) -> void:
	state = p_state.clone()
	encounter = p_encounter
	_history = ActionHistory.new(state)

func adjust_die(die_id: StringName, delta: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(RoundActions.adjust_die(state, die_id, delta))

func assign_die(die_id: StringName, table_id: StringName, slot_limit: int) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(RoundActions.assign_die(state, die_id, table_id, slot_limit))

func play_card(played_card: PlayedCard) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(CardRules.play_card(state, played_card))

func undo() -> bool:
	if committed:
		return false
	var previous := _history.undo()
	if previous == null:
		return false
	state = previous
	return true

func preview() -> ResolutionReport:
	if committed:
		return _committed_report
	return _resolver.resolve(state, encounter)

func commit() -> ResolutionReport:
	if committed:
		return _committed_report
	var report := _resolver.resolve(state, encounter)
	if report.valid:
		committed = true
		_committed_report = report
	return report

func _accept(result: ActionResult) -> ActionResult:
	if result.accepted:
		state = result.next_state
		_history.push(state)
	return result
```

- [x] **Step 4: Run all tests and the Godot import check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-joker-headless.log" -s res://tests/run_all.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-joker-import.log" --import
```

Expected: every test passes, then the import check exits `0` without parser errors.

- [x] **Step 5: Commit only the controller code**

```powershell
git add scripts/run/action_history.gd scripts/run/round_controller.gd tests/round_controller_test.gd
git commit --only scripts/run/action_history.gd scripts/run/round_controller.gd tests/round_controller_test.gd -m "feat: add undoable round controller"
```

---

### Task 8: Content Validation and Phase Acceptance

**Files:**
- Create: `scripts/validation/content_validator.gd`
- Create: `tests/content_validator_test.gd`
- Modify: `docs/superpowers/plans/2026-07-24-core-rules-foundation.md`

**Interfaces:**
- Consumes: arrays of `RuleDefinition` and `CardDefinition`.
- Produces: an array of concrete validation error strings; an empty array means content is valid.

- [x] **Step 1: Write failing validation tests**

Create `tests/content_validator_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const ContentValidatorScript = preload("res://scripts/validation/content_validator.gd")
const RuleDefinitionScript = preload("res://scripts/rules/rule_definition.gd")
const CardDefinitionScript = preload("res://scripts/cards/card_definition.gd")
const EffectSpecScript = preload("res://scripts/cards/effect_spec.gd")

func run() -> void:
	var valid_rule := RuleDefinitionScript.new()
	valid_rule.id = &"left"
	valid_rule.display_name = "精确为七"
	valid_rule.slot_count = 2
	valid_rule.coefficient = 2

	var valid_effect := EffectSpecScript.new()
	valid_effect.operation = EffectSpecScript.Operation.MODIFY_COEFFICIENT
	valid_effect.amount = 1
	var valid_card := CardDefinitionScript.new()
	valid_card.id = &"diamond_boost"
	valid_card.display_name = "映射"
	valid_card.target_type = CardDefinitionScript.TargetType.TABLE
	valid_card.effects = [valid_effect]

	var validator := ContentValidatorScript.new()
	assert_equal(
		validator.validate([valid_rule], [valid_card]),
		[],
		"well-formed content should pass"
	)

	var duplicate_rule := valid_rule.duplicate()
	var duplicate_errors = validator.validate([valid_rule, duplicate_rule], [valid_card])
	assert_true(
		duplicate_errors.any(func(error: String) -> bool: return "duplicate rule ID" in error),
		"duplicate rule IDs should be reported"
	)

	var empty_card := CardDefinitionScript.new()
	var empty_errors = validator.validate([valid_rule], [empty_card])
	assert_true(
		empty_errors.any(func(error: String) -> bool: return "card ID is empty" in error),
		"empty card IDs should be reported"
	)
```

- [x] **Step 2: Run tests and verify missing validator failure**

Expected: exit code `1` because `content_validator.gd` does not exist.

- [x] **Step 3: Implement explicit validation**

Create `scripts/validation/content_validator.gd`:

```gdscript
class_name ContentValidator
extends RefCounted

func validate(rules: Array, cards: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_rule_ids := {}
	for rule in rules:
		if rule.id == &"":
			errors.append("rule ID is empty")
		elif seen_rule_ids.has(rule.id):
			errors.append("duplicate rule ID: %s" % rule.id)
		else:
			seen_rule_ids[rule.id] = true
		if rule.display_name.strip_edges().is_empty():
			errors.append("rule %s has no display name" % rule.id)
		if rule.slot_count < 1 or rule.slot_count > 6:
			errors.append("rule %s slot count is outside 1..6" % rule.id)
		if rule.coefficient < 1:
			errors.append("rule %s coefficient must be positive" % rule.id)
		if (
			rule.condition_type == RuleDefinition.ConditionType.EXACT_SUM
			and (
				rule.target_value < rule.slot_count
				or rule.target_value > rule.slot_count * 6
			)
		):
			errors.append("rule %s exact-sum target is unreachable" % rule.id)

	var seen_card_ids := {}
	for card in cards:
		if card.id == &"":
			errors.append("card ID is empty")
		elif seen_card_ids.has(card.id):
			errors.append("duplicate card ID: %s" % card.id)
		else:
			seen_card_ids[card.id] = true
		if card.display_name.strip_edges().is_empty():
			errors.append("card %s has no display name" % card.id)
		if card.effects.is_empty():
			errors.append("card %s has no effects" % card.id)
		for effect in card.effects:
			match effect.operation:
				EffectSpec.Operation.ADJUST_DIE:
					if card.target_type != CardDefinition.TargetType.DIE:
						errors.append("card %s adjust-die effect requires a die target" % card.id)
					if effect.amount == 0:
						errors.append("card %s adjust-die amount cannot be zero" % card.id)
				EffectSpec.Operation.MODIFY_COEFFICIENT:
					if card.target_type != CardDefinition.TargetType.TABLE:
						errors.append("card %s coefficient effect requires a table target" % card.id)
					if effect.amount == 0:
						errors.append("card %s coefficient amount cannot be zero" % card.id)
				EffectSpec.Operation.REPEAT_TABLE:
					if card.target_type != CardDefinition.TargetType.TABLE:
						errors.append("card %s repeat effect requires a table target" % card.id)
					if effect.amount < 1:
						errors.append("card %s repeat amount must be positive" % card.id)
				EffectSpec.Operation.REVERSE_RESOLUTION:
					if card.target_type != CardDefinition.TargetType.GLOBAL:
						errors.append("card %s reverse effect requires a global target" % card.id)
	return errors
```

- [x] **Step 4: Run the complete acceptance suite and record the result**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-joker-headless.log" -s res://tests/run_all.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-joker-import.log" --import
git status --short
```

Expected:

- All eight test suites print `PASS`.
- The runner prints `ALL TESTS PASSED (8 suites)`.
- The import check exits `0`.
- `git status --short` lists the validator files and this staged plan before the code-only commit.

After those commands pass, change every completed checkbox in this plan from `- [ ]` to `- [x]`. Do not mark a step complete before its expected result is observed.

- [x] **Step 5: Commit validator code and stage the completed plan**

```powershell
git add scripts/validation/content_validator.gd tests/content_validator_test.gd
git commit --only scripts/validation/content_validator.gd tests/content_validator_test.gd -m "feat: validate core rules foundation"
git add docs/superpowers/plans/2026-07-24-core-rules-foundation.md
```

## Phase 1 Exit Checklist

- [x] Headless test runner reports eight passing suites.
- [x] Godot opens and imports the project without parser or resource errors.
- [x] Equal seeds produce equal dice and deck order.
- [x] Three four-card hands expose twelve unique cards.
- [x] Dice actions return cloned state and never mutate the prior snapshot.
- [x] A die cannot occupy two rule tables simultaneously.
- [x] A round rejects a third played card.
- [x] The reference round previews 51, undoes to 44, replays, and commits 51.
- [x] Preview and commit event signatures are identical.
- [x] Content validation rejects empty and duplicate IDs.
- [x] After the final code commit, `git status --short` shows only the staged implementation-plan document.
