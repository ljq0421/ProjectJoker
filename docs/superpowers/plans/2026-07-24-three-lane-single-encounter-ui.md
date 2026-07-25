# Three-Lane Single-Encounter UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver one playable 1920×1080 encounter in which the player can drag or click six dice into three rule lanes, target cards at dice/tables/gaps, undo every tentative action, inspect the exact resolution trail, and commit the round.

**Architecture:** Keep all score and legality decisions in the existing domain layer. Add a non-Node `SingleEncounterSession` that translates UI intentions into `RoundController` calls, then bind scene-first Godot `Control` components to that session. UI nodes render snapshots and emit intentions; they never calculate score or mutate `RoundState` directly.

**Tech Stack:** Godot 4.6.1, typed GDScript, `.tscn` scene composition, custom `Theme`, existing dependency-free headless tests, asynchronous scene self-check scripts using real mouse input events.

## Global Constraints

- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` for automated checks.
- Every Godot headless command must pass `--log-file` to a writable path under `$env:TEMP`.
- Treat `SCRIPT ERROR` or `Failed to load script` in a Godot log as failure even if the process returns `0`.
- Run `--import` after adding `class_name` scripts and track generated `.gd.uid` files with their scripts.
- Target PC landscape at exactly 1920×1080 for the phase acceptance test.
- Preserve the current Mobile renderer.
- Stable UI hierarchy and layout live in `.tscn`; scripts bind data, forward signals, and refresh state.
- The center of the screen contains three parallel rule lanes with two physical gap targets.
- The left column shows dealer/rule context; the right column shows ordered resolution events.
- Dice support both real drag/drop and click-die-then-click-lane interaction.
- Cards support die, table, gap, and global targets; only legal targets highlight.
- Every accepted action remains undoable until commit.
- `RoundResolver.resolve()` remains the only score path for both prediction and commit.
- Do not add shops, room routing, saves, engravings, full content, animation polish, or mobile layouts in this phase.
- Documentation files remain staged and uncommitted.
- Code commits use `git commit --only` with explicit code/test paths so staged documentation is never included.

## Phase Acceptance Scenario

The reference scene starts with dice `[1, 2, 3, 4, 5, 6]`, two calibration points, four cards, and three rules:

- Left: two dice totaling exactly 7, coefficient 2.
- Middle: three consecutive dice, coefficient 2.
- Right: one even die, coefficient 3.

The test assigns `1+6` left, `2+3+4` middle, calibrates `5→4`, assigns it right, then applies a `+1` coefficient card to the left table. Prediction and commit must both equal `51`. Undoing the card must return prediction to `44`.

## File Map

```text
res://
  project.godot
  resources/
    themes/
      neon_dream_theme.tres
  scenes/
    components/
      card_token.tscn
      die_token.tscn
      resolution_panel.tscn
      rule_lane.tscn
    run/
      single_encounter_screen.tscn
  scripts/
    cards/
      card_rules.gd
      effect_spec.gd
    demo/
      single_encounter_fixture.gd
    resolution/
      round_resolver.gd
    run/
      round_controller.gd
    ui/
      card_token.gd
      dice_tray.gd
      die_token.gd
      interaction_state.gd
      resolution_panel.gd
      rule_lane.gd
      single_encounter_screen.gd
      single_encounter_session.gd
  tests/
    card_rules_test.gd
    resolution_test.gd
    round_controller_test.gd
    single_encounter_fixture_test.gd
    single_encounter_session_test.gd
    single_encounter_layout_self_check.gd
    single_encounter_input_self_check.gd
```

---

### Task 1: Domain Operations Required by the UI

**Files:**
- Modify: `scripts/cards/effect_spec.gd`
- Modify: `scripts/cards/card_rules.gd`
- Modify: `scripts/resolution/round_resolver.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/validation/content_validator.gd`
- Modify: `tests/card_rules_test.gd`
- Modify: `tests/resolution_test.gd`
- Modify: `tests/round_controller_test.gd`

**Interfaces:**
- Consumes: existing `RoundState`, `PlayedCard`, `RoundActions`, and `ResolutionReport`.
- Produces: `RoundController.unassign_die()`, secondary-target validation for gap cards, and `EffectSpec.Operation.LINK_NEIGHBORS`.

- [x] **Step 1: Add failing tests for tray return and gap targeting**

Append to `tests/card_rules_test.gd` inside `run()`:

```gdscript
	var gap_card := CardDefinitionScript.new()
	gap_card.id = &"spade_link"
	gap_card.display_name = "桥接"
	gap_card.target_type = CardDefinitionScript.TargetType.GAP
	var missing_neighbor = CardRulesScript.play_card(
		state,
		PlayedCardScript.new(gap_card, &"left")
	)
	assert_false(missing_neighbor.accepted, "gap cards require two neighboring table IDs")
	var complete_gap = CardRulesScript.play_card(
		state,
		PlayedCardScript.new(gap_card, &"left", &"middle")
	)
	assert_true(complete_gap.accepted, "gap cards accept two neighboring table IDs")
```

Append to `tests/round_controller_test.gd` immediately after assigning `d1` to the left lane:

```gdscript
	assert_true(controller.unassign_die(&"d1").accepted, "tray return should unassign d1")
	assert_equal(
		controller.state.assignments[&"left"],
		[],
		"tray return should clear the lane"
	)
	assert_true(controller.undo(), "tray return should be undoable")
	assert_equal(
		controller.state.assignments[&"left"],
		[&"d1"],
		"undo should restore the lane assignment"
	)
```

Append a new helper invocation to `tests/resolution_test.gd` inside `run()`:

```gdscript
	_test_neighbor_link()
```

Add the helper:

```gdscript
func _test_neighbor_link() -> void:
	var state = _build_state()
	var effect := EffectSpecScript.new()
	effect.operation = EffectSpecScript.Operation.LINK_NEIGHBORS
	effect.amount = 1
	var card := CardDefinitionScript.new()
	card.id = &"spade_link"
	card.display_name = "桥接"
	card.target_type = CardDefinitionScript.TargetType.GAP
	card.effects = [effect]
	state.played_cards = [PlayedCardScript.new(card, &"left", &"middle")]

	var report = RoundResolverScript.new().resolve(state, _build_encounter())
	assert_equal(report.total, 58, "left result 14 should add to middle result 18")
	assert_true(
		report.events.any(
			func(event) -> bool:
				return event.source_id == &"spade_link" and event.delta == 14
		),
		"link should create a visible 14-point event"
	)
```

- [x] **Step 2: Run the core suite and verify the new API is missing**

Run:

```powershell
$uiTask1Log = Join-Path $env:TEMP 'project-joker-ui-task1-red.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $uiTask1Log -s res://tests/run_all.gd
```

Expected: failure because `LINK_NEIGHBORS` and `RoundController.unassign_die()` do not exist.

- [x] **Step 3: Implement unassign and deterministic gap links**

Add to `EffectSpec.Operation` in `scripts/cards/effect_spec.gd`:

```gdscript
	LINK_NEIGHBORS,
```

Add before cloning state in `CardRules.play_card()`:

```gdscript
	if (
		played_card.definition.target_type == CardDefinition.TargetType.GAP
		and played_card.secondary_target == &""
	):
		return ActionResult.new(false, "gap cards require two neighboring tables", state)
```

Add to `scripts/run/round_controller.gd`:

```gdscript
func unassign_die(die_id: StringName) -> ActionResult:
	if committed:
		return ActionResult.new(false, "round is already committed", state)
	return _accept(RoundActions.unassign_die(state, die_id))
```

In `RoundResolver.resolve()`, declare links beside the existing modifiers:

```gdscript
	var neighbor_links: Dictionary = {}
```

Add this branch to the card-effect `match`:

```gdscript
				EffectSpec.Operation.LINK_NEIGHBORS:
					if (
						not table_ids.has(played_card.primary_target)
						or not table_ids.has(played_card.secondary_target)
					):
						return _invalid("link card targets unknown tables")
					neighbor_links[played_card.secondary_target] = {
						"source_table": played_card.primary_target,
						"card_id": played_card.definition.id,
						"card_name": played_card.definition.display_name,
					}
```

Before the rule-resolution loop, add:

```gdscript
	var resolved_table_totals: Dictionary = {}
```

After each valid table finishes its repeats, add:

```gdscript
		resolved_table_totals[rule.id] = result.total * resolution_count
		if neighbor_links.has(rule.id):
			var link: Dictionary = neighbor_links[rule.id]
			var linked_value: int = resolved_table_totals.get(link.source_table, 0)
			report.total += linked_value
			report.events.append(ResolutionEvent.new(
				link.card_id,
				"%s：%s → %s" % [link.card_name, link.source_table, rule.id],
				linked_value,
				report.total
			))
```

Add to the validator effect `match`:

```gdscript
				EffectSpec.Operation.LINK_NEIGHBORS:
					if card.target_type != CardDefinition.TargetType.GAP:
						errors.append("card %s link effect requires a gap target" % card.id)
					if effect.amount != 1:
						errors.append("card %s link amount must equal one" % card.id)
```

- [x] **Step 4: Run import and all core tests**

```powershell
$uiTask1ImportLog = Join-Path $env:TEMP 'project-joker-ui-task1-import.log'
$uiTask1TestLog = Join-Path $env:TEMP 'project-joker-ui-task1.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $uiTask1ImportLog --import
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $uiTask1TestLog -s res://tests/run_all.gd
```

Expected: all existing suites pass; the link report totals `58`; neither log contains `SCRIPT ERROR`.

- [x] **Step 5: Commit only domain and test code**

```powershell
git add scripts/cards/effect_spec.gd scripts/cards/effect_spec.gd.uid scripts/cards/card_rules.gd scripts/cards/card_rules.gd.uid scripts/resolution/round_resolver.gd scripts/resolution/round_resolver.gd.uid scripts/run/round_controller.gd scripts/run/round_controller.gd.uid scripts/validation/content_validator.gd scripts/validation/content_validator.gd.uid tests/card_rules_test.gd tests/card_rules_test.gd.uid tests/resolution_test.gd tests/resolution_test.gd.uid tests/round_controller_test.gd tests/round_controller_test.gd.uid
git commit --only scripts/cards/effect_spec.gd scripts/cards/effect_spec.gd.uid scripts/cards/card_rules.gd scripts/cards/card_rules.gd.uid scripts/resolution/round_resolver.gd scripts/resolution/round_resolver.gd.uid scripts/run/round_controller.gd scripts/run/round_controller.gd.uid scripts/validation/content_validator.gd scripts/validation/content_validator.gd.uid tests/card_rules_test.gd tests/card_rules_test.gd.uid tests/resolution_test.gd tests/resolution_test.gd.uid tests/round_controller_test.gd tests/round_controller_test.gd.uid -m "feat: add ui-facing round operations"
```

---

### Task 2: Deterministic Single-Encounter Fixture

**Files:**
- Create: `scripts/demo/single_encounter_fixture.gd`
- Create: `tests/single_encounter_fixture_test.gd`

**Interfaces:**
- Consumes: existing rule, card, state, encounter, and content-validator types.
- Produces: `make_state()`, `make_encounter()`, and `make_hand()` for tests and the screen.

- [x] **Step 1: Write the failing fixture test**

Create `tests/single_encounter_fixture_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const FixtureScript = preload("res://scripts/demo/single_encounter_fixture.gd")

func run() -> void:
	var state = FixtureScript.make_state()
	var encounter = FixtureScript.make_encounter()
	var hand = FixtureScript.make_hand()
	assert_equal(state.dice.size(), 6, "fixture should provide six dice")
	assert_equal(state.calibration_points, 2, "fixture should provide two calibration points")
	assert_equal(encounter.rules.size(), 3, "fixture should provide three lanes")
	assert_equal(hand.size(), 4, "fixture should provide four cards")
	assert_equal(
		ContentValidator.new().validate(encounter.rules, hand),
		[],
		"fixture content should pass validation"
	)
```

- [x] **Step 2: Run tests and observe the missing fixture**

Run the core suite with a writable log.

Expected: `single_encounter_fixture.gd` preload failure.

- [x] **Step 3: Implement the complete fixture**

Create `scripts/demo/single_encounter_fixture.gd`:

```gdscript
class_name SingleEncounterFixture
extends RefCounted

static func make_state() -> RoundState:
	var state := RoundState.new()
	for value in range(1, 7):
		state.dice.append(DieState.new(StringName("d%d" % value), value))
	return state

static func make_encounter() -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = &"neon_training_room"
	encounter.rules = [
		_rule(
			&"left",
			"精确为 7",
			RuleDefinition.ConditionType.EXACT_SUM,
			2,
			2,
			7
		),
		_rule(
			&"middle",
			"连续三数",
			RuleDefinition.ConditionType.CONSECUTIVE,
			3,
			2
		),
		_rule(
			&"right",
			"单枚偶数",
			RuleDefinition.ConditionType.ALL_EVEN,
			1,
			3
		),
	]
	return encounter

static func make_hand() -> Array[CardDefinition]:
	return [
		_card(
			&"club_nudge",
			"拨码",
			CardDefinition.TargetType.DIE,
			EffectSpec.Operation.ADJUST_DIE,
			-1
		),
		_card(
			&"diamond_map",
			"映射",
			CardDefinition.TargetType.TABLE,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			1
		),
		_card(
			&"spade_link",
			"桥接",
			CardDefinition.TargetType.GAP,
			EffectSpec.Operation.LINK_NEIGHBORS,
			1
		),
		_card(
			&"heart_reverse",
			"倒序",
			CardDefinition.TargetType.GLOBAL,
			EffectSpec.Operation.REVERSE_RESOLUTION,
			0
		),
	]

static func _rule(
	id: StringName,
	display_name: String,
	condition_type: RuleDefinition.ConditionType,
	slot_count: int,
	coefficient: int,
	target_value: int = 0
) -> RuleDefinition:
	var rule := RuleDefinition.new()
	rule.id = id
	rule.display_name = display_name
	rule.condition_type = condition_type
	rule.slot_count = slot_count
	rule.coefficient = coefficient
	rule.target_value = target_value
	return rule

static func _card(
	id: StringName,
	display_name: String,
	target_type: CardDefinition.TargetType,
	operation: EffectSpec.Operation,
	amount: int
) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = operation
	effect.amount = amount
	var card := CardDefinition.new()
	card.id = id
	card.display_name = display_name
	card.target_type = target_type
	card.effects = [effect]
	return card
```

- [x] **Step 4: Import and run all core tests**

Expected: fixture validation passes and the suite count increases by one.

- [x] **Step 5: Commit fixture code**

```powershell
git add scripts/demo/single_encounter_fixture.gd scripts/demo/single_encounter_fixture.gd.uid tests/single_encounter_fixture_test.gd tests/single_encounter_fixture_test.gd.uid
git commit --only scripts/demo/single_encounter_fixture.gd scripts/demo/single_encounter_fixture.gd.uid tests/single_encounter_fixture_test.gd tests/single_encounter_fixture_test.gd.uid -m "feat: add deterministic encounter fixture"
```

---

### Task 3: UI Interaction Session

**Files:**
- Create: `scripts/ui/interaction_state.gd`
- Create: `scripts/ui/single_encounter_session.gd`
- Create: `tests/single_encounter_session_test.gd`

**Interfaces:**
- Consumes: `SingleEncounterFixture`, `RoundController`, `PlayedCard`, and component intention signals.
- Produces: one non-Node session API for die/card selection, table/gap activation, tray return, calibration, undo, prediction, and commit.

- [x] **Step 1: Write failing click-path tests**

Create `tests/single_encounter_session_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const SessionScript = preload("res://scripts/ui/single_encounter_session.gd")

func run() -> void:
	var session := SessionScript.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)

	_assign(session, &"d1", &"left")
	_assign(session, &"d6", &"left")
	_assign(session, &"d2", &"middle")
	_assign(session, &"d3", &"middle")
	_assign(session, &"d4", &"middle")
	assert_true(session.calibrate_die(&"d5", -1), "d5 should calibrate to four")
	_assign(session, &"d5", &"right")
	assert_equal(session.preview().total, 44, "base placement should preview 44")

	assert_true(session.activate_card(1), "table card should become selected")
	assert_true(session.activate_table(&"left"), "selected table card should play")
	assert_equal(session.preview().total, 51, "coefficient card should preview 51")
	assert_true(session.undo(), "card play should be undoable")
	assert_equal(session.preview().total, 44, "undo should restore 44")

	assert_true(session.activate_card(2), "gap card should become selected")
	assert_true(session.activate_gap(&"left", &"middle"), "gap target should play the card")
	assert_true(session.is_card_used(2), "played gap card should be disabled")

	var target_session := SessionScript.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	assert_true(target_session.activate_card(0), "die card should become selected")
	assert_true(target_session.activate_die(&"d6"), "selected die card should play on d6")
	assert_true(target_session.is_card_used(0), "die card should become used")
	assert_true(target_session.activate_card(3), "global card should play immediately")
	assert_true(target_session.is_card_used(3), "global card should become used")

func _assign(session, die_id: StringName, table_id: StringName) -> void:
	assert_true(session.activate_die(die_id), "die should become selected")
	assert_true(session.activate_table(table_id), "selected die should enter lane")
```

- [x] **Step 2: Run tests and observe the missing session**

Expected: preload failure for `single_encounter_session.gd`.

- [x] **Step 3: Implement selection state and session orchestration**

Create `scripts/ui/interaction_state.gd`:

```gdscript
class_name InteractionState
extends RefCounted

enum Kind { NONE, DIE, CARD }

var kind: Kind = Kind.NONE
var die_id: StringName
var card_index: int = -1

func select_die(value: StringName) -> void:
	kind = Kind.DIE
	die_id = value
	card_index = -1

func select_card(value: int) -> void:
	kind = Kind.CARD
	card_index = value
	die_id = &""

func clear() -> void:
	kind = Kind.NONE
	die_id = &""
	card_index = -1
```

Create `scripts/ui/single_encounter_session.gd`:

```gdscript
class_name SingleEncounterSession
extends RefCounted

var controller: RoundController
var hand: Array[CardDefinition]
var selection := InteractionState.new()
var last_error: String = ""

func _init(
	state: RoundState,
	encounter: EncounterDefinition,
	p_hand: Array[CardDefinition]
) -> void:
	controller = RoundController.new(state, encounter)
	hand = p_hand

func activate_die(die_id: StringName) -> bool:
	if selection.kind == InteractionState.Kind.CARD:
		var card := hand[selection.card_index]
		if card.target_type != CardDefinition.TargetType.DIE:
			return _fail("selected card requires another target")
		return _accept(controller.play_card(
			PlayedCard.new(card, die_id)
		), true)
	selection.select_die(die_id)
	last_error = ""
	return true

func activate_card(card_index: int) -> bool:
	if card_index < 0 or card_index >= hand.size():
		return _fail("card index is outside the hand")
	if is_card_used(card_index):
		return _fail("card is already used")
	var card := hand[card_index]
	if card.target_type == CardDefinition.TargetType.GLOBAL:
		return _accept(controller.play_card(PlayedCard.new(card)), true)
	selection.select_card(card_index)
	last_error = ""
	return true

func activate_table(table_id: StringName) -> bool:
	if selection.kind == InteractionState.Kind.DIE:
		var rule := _find_rule(table_id)
		if rule == null:
			return _fail("rule table does not exist")
		return _accept(
			controller.assign_die(selection.die_id, table_id, rule.slot_count),
			true
		)
	if selection.kind == InteractionState.Kind.CARD:
		var card := hand[selection.card_index]
		if card.target_type != CardDefinition.TargetType.TABLE:
			return _fail("selected card does not target a table")
		return _accept(controller.play_card(PlayedCard.new(card, table_id)), true)
	return _fail("select a die or card first")

func activate_gap(left_id: StringName, right_id: StringName) -> bool:
	if selection.kind != InteractionState.Kind.CARD:
		return _fail("select a gap card first")
	var card := hand[selection.card_index]
	if card.target_type != CardDefinition.TargetType.GAP:
		return _fail("selected card does not target a gap")
	return _accept(
		controller.play_card(PlayedCard.new(card, left_id, right_id)),
		true
	)

func assign_dropped_die(die_id: StringName, table_id: StringName) -> bool:
	var rule := _find_rule(table_id)
	if rule == null:
		return _fail("rule table does not exist")
	return _accept(controller.assign_die(die_id, table_id, rule.slot_count), false)

func return_die_to_tray(die_id: StringName) -> bool:
	return _accept(controller.unassign_die(die_id), false)

func calibrate_die(die_id: StringName, delta: int) -> bool:
	return _accept(controller.adjust_die(die_id, delta), false)

func undo() -> bool:
	var accepted := controller.undo()
	if not accepted:
		return _fail("nothing can be undone")
	selection.clear()
	last_error = ""
	return true

func preview() -> ResolutionReport:
	return controller.preview()

func commit() -> ResolutionReport:
	return controller.commit()

func is_card_used(card_index: int) -> bool:
	var id := hand[card_index].id
	return controller.state.played_cards.any(
		func(played_card) -> bool: return played_card.definition.id == id
	)

func _find_rule(table_id: StringName) -> RuleDefinition:
	for rule in controller.encounter.rules:
		if rule.id == table_id:
			return rule
	return null

func _accept(result: ActionResult, clear_selection: bool) -> bool:
	if not result.accepted:
		return _fail(result.reason)
	if clear_selection:
		selection.clear()
	last_error = ""
	return true

func _fail(reason: String) -> bool:
	last_error = reason
	return false
```

- [x] **Step 4: Import and run the core suite**

Expected: the session test reaches `44`, `51`, then `44` after undo without accessing private controller state.

- [x] **Step 5: Commit only session code and tests**

```powershell
git add scripts/ui/interaction_state.gd scripts/ui/interaction_state.gd.uid scripts/ui/single_encounter_session.gd scripts/ui/single_encounter_session.gd.uid tests/single_encounter_session_test.gd tests/single_encounter_session_test.gd.uid
git commit --only scripts/ui/interaction_state.gd scripts/ui/interaction_state.gd.uid scripts/ui/single_encounter_session.gd scripts/ui/single_encounter_session.gd.uid tests/single_encounter_session_test.gd tests/single_encounter_session_test.gd.uid -m "feat: add single encounter ui session"
```

---

### Task 4: Reusable UI Components

**Files:**
- Create: `scripts/ui/die_token.gd`
- Create: `scripts/ui/card_token.gd`
- Create: `scripts/ui/rule_lane.gd`
- Create: `scripts/ui/dice_tray.gd`
- Create: `scripts/ui/resolution_panel.gd`
- Create: `scenes/components/die_token.tscn`
- Create: `scenes/components/card_token.tscn`
- Create: `scenes/components/rule_lane.tscn`
- Create: `scenes/components/resolution_panel.tscn`
- Create: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: view data supplied by `SingleEncounterScreen`.
- Produces: intention signals only; components do not receive `RoundController`.

- [x] **Step 1: Write a failing component contract test**

Create `tests/ui_component_contract_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var die = load("res://scenes/components/die_token.tscn").instantiate()
	var card = load("res://scenes/components/card_token.tscn").instantiate()
	var lane = load("res://scenes/components/rule_lane.tscn").instantiate()
	var panel = load("res://scenes/components/resolution_panel.tscn").instantiate()
	assert_true(die.has_signal("die_activated"), "die token should emit activation")
	assert_true(card.has_signal("card_activated"), "card token should emit activation")
	assert_true(lane.has_signal("lane_activated"), "lane should emit click activation")
	assert_true(lane.has_signal("die_drop_requested"), "lane should emit die drops")
	assert_true(die.has_method("set_legal_target"), "die token should expose target highlight")
	assert_true(lane.has_method("set_legal_target"), "lane should expose table target highlight")
	assert_true(lane.has_method("set_die_target_highlight"), "lane should highlight assigned dice")
	assert_true(panel.has_method("bind_report"), "resolution panel should bind reports")
	die.free()
	card.free()
	lane.free()
	panel.free()
```

- [x] **Step 2: Run tests and observe missing component scenes**

Expected: load failures for the four component scenes.

- [x] **Step 3: Implement component scripts**

Create `scripts/ui/die_token.gd`:

```gdscript
class_name DieToken
extends Button

signal die_activated(die_id: StringName)

var die_id: StringName

func _ready() -> void:
	pressed.connect(func() -> void: die_activated.emit(die_id))

func bind_die(state: DieState, selected: bool) -> void:
	die_id = state.id
	text = str(state.value)
	button_pressed = selected
	tooltip_text = "骰子 %s：点数 %d" % [state.id, state.value]

func set_legal_target(value: bool) -> void:
	self_modulate = Color(0.68, 1.0, 0.96, 1.0) if value else Color.WHITE

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 28)
	set_drag_preview(preview)
	return {"kind": "die", "die_id": die_id}
```

Create `scripts/ui/card_token.gd`:

```gdscript
class_name CardToken
extends Button

signal card_activated(card_index: int)

var card_index: int

func _ready() -> void:
	pressed.connect(func() -> void: card_activated.emit(card_index))

func bind_card(
	index: int,
	definition: CardDefinition,
	selected: bool,
	used: bool
) -> void:
	card_index = index
	text = "%s\n%s" % [definition.display_name, _target_copy(definition.target_type)]
	button_pressed = selected
	disabled = used
	tooltip_text = "%s；目标：%s" % [definition.display_name, _target_copy(definition.target_type)]

func _target_copy(target_type: CardDefinition.TargetType) -> String:
	match target_type:
		CardDefinition.TargetType.DIE:
			return "骰子"
		CardDefinition.TargetType.TABLE:
			return "规则台"
		CardDefinition.TargetType.GAP:
			return "桌间"
		CardDefinition.TargetType.GLOBAL:
			return "全局"
	return "未知"
```

Create `scripts/ui/rule_lane.gd`:

```gdscript
class_name RuleLane
extends PanelContainer

signal lane_activated(table_id: StringName)
signal die_activated(die_id: StringName)
signal die_drop_requested(die_id: StringName, table_id: StringName)

@onready var title_label: Label = %Title
@onready var condition_label: Label = %Condition
@onready var slots: HBoxContainer = %Slots

var table_id: StringName

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		lane_activated.emit(table_id)
		accept_event()

func bind_lane(
	rule: RuleDefinition,
	assigned_dice: Array,
	die_scene: PackedScene,
	selected_die_id: StringName
) -> void:
	table_id = rule.id
	title_label.text = rule.display_name
	condition_label.text = "%d 个骰位 · 系数 ×%d" % [rule.slot_count, rule.coefficient]
	for child in slots.get_children():
		child.queue_free()
	for die in assigned_dice:
		var token: DieToken = die_scene.instantiate()
		slots.add_child(token)
		token.bind_die(die, die.id == selected_die_id)
		token.die_activated.connect(func(id: StringName) -> void: die_activated.emit(id))
	for empty_index in range(rule.slot_count - assigned_dice.size()):
		var empty := Label.new()
		empty.text = "＋"
		empty.custom_minimum_size = Vector2(54, 54)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(empty)

func set_legal_target(value: bool) -> void:
	self_modulate = Color(0.68, 1.0, 0.96, 1.0) if value else Color.WHITE

func set_die_target_highlight(value: bool) -> void:
	for child in slots.get_children():
		if child is DieToken:
			child.set_legal_target(value)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_drop_requested.emit(data.get("die_id"), table_id)
```

Create `scripts/ui/dice_tray.gd`:

```gdscript
class_name DiceTray
extends HBoxContainer

signal die_return_requested(die_id: StringName)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "die"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_return_requested.emit(data.get("die_id"))
```

Create `scripts/ui/resolution_panel.gd`:

```gdscript
class_name ResolutionPanel
extends PanelContainer

@onready var event_list: VBoxContainer = %EventList
@onready var total_label: Label = %Total

func bind_report(report: ResolutionReport) -> void:
	for child in event_list.get_children():
		child.queue_free()
	for event in report.events:
		var row := Label.new()
		row.text = "%s　%+d　→ %d" % [event.label, event.delta, event.running_total]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_list.add_child(row)
	total_label.text = "预测结算：%d" % report.total
```

- [x] **Step 4: Create the four component scenes**

Create `scenes/components/die_token.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/die_token.gd" id="1"]

[node name="DieToken" type="Button"]
custom_minimum_size = Vector2(58, 58)
toggle_mode = true
focus_mode = 1
script = ExtResource("1")
```

Create `scenes/components/card_token.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/card_token.gd" id="1"]

[node name="CardToken" type="Button"]
custom_minimum_size = Vector2(132, 92)
toggle_mode = true
focus_mode = 1
text = "手法牌"
script = ExtResource("1")
```

Create `scenes/components/rule_lane.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/rule_lane.gd" id="1"]

[node name="RuleLane" type="PanelContainer"]
custom_minimum_size = Vector2(250, 310)
mouse_filter = 0
script = ExtResource("1")

[node name="Content" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 14
mouse_filter = 2

[node name="Title" type="Label" parent="Content"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 24
horizontal_alignment = 1
mouse_filter = 2

[node name="Condition" type="Label" parent="Content"]
unique_name_in_owner = true
layout_mode = 2
horizontal_alignment = 1
autowrap_mode = 2
mouse_filter = 2

[node name="Slots" type="HBoxContainer" parent="Content"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
alignment = 1
theme_override_constants/separation = 8
mouse_filter = 2
```

Create `scenes/components/resolution_panel.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/resolution_panel.gd" id="1"]

[node name="ResolutionPanel" type="PanelContainer"]
custom_minimum_size = Vector2(300, 0)
script = ExtResource("1")

[node name="Content" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Heading" type="Label" parent="Content"]
layout_mode = 2
text = "结算轨迹"
theme_override_font_sizes/font_size = 24

[node name="EventList" type="VBoxContainer" parent="Content"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3

[node name="Total" type="Label" parent="Content"]
unique_name_in_owner = true
layout_mode = 2
text = "预测结算：0"
theme_override_font_sizes/font_size = 22
```

Run import, then the core suite.

Expected: `ui_component_contract_test.gd` passes.

- [x] **Step 5: Commit component code and scenes**

```powershell
git add scripts/ui/die_token.gd scripts/ui/die_token.gd.uid scripts/ui/card_token.gd scripts/ui/card_token.gd.uid scripts/ui/rule_lane.gd scripts/ui/rule_lane.gd.uid scripts/ui/dice_tray.gd scripts/ui/dice_tray.gd.uid scripts/ui/resolution_panel.gd scripts/ui/resolution_panel.gd.uid scenes/components/die_token.tscn scenes/components/card_token.tscn scenes/components/rule_lane.tscn scenes/components/resolution_panel.tscn tests/ui_component_contract_test.gd tests/ui_component_contract_test.gd.uid
git commit --only scripts/ui/die_token.gd scripts/ui/die_token.gd.uid scripts/ui/card_token.gd scripts/ui/card_token.gd.uid scripts/ui/rule_lane.gd scripts/ui/rule_lane.gd.uid scripts/ui/dice_tray.gd scripts/ui/dice_tray.gd.uid scripts/ui/resolution_panel.gd scripts/ui/resolution_panel.gd.uid scenes/components/die_token.tscn scenes/components/card_token.tscn scenes/components/rule_lane.tscn scenes/components/resolution_panel.tscn tests/ui_component_contract_test.gd tests/ui_component_contract_test.gd.uid -m "feat: add three-lane ui components"
```

---

### Task 5: Scene-First Three-Lane Screen

**Files:**
- Create: `resources/themes/neon_dream_theme.tres`
- Create: `scripts/ui/single_encounter_screen.gd`
- Create: `scenes/run/single_encounter_screen.tscn`

**Interfaces:**
- Consumes: `SingleEncounterSession` and reusable component scenes.
- Produces: a stable three-column screen; dynamic dice/cards are children of scene-defined containers.

- [x] **Step 1: Add a failing scene-load assertion**

Append to `tests/ui_component_contract_test.gd`:

```gdscript
	var screen_scene = load("res://scenes/run/single_encounter_screen.tscn")
	assert_true(screen_scene != null, "single encounter screen should load")
	var screen = screen_scene.instantiate()
	assert_true(screen.has_method("refresh_from_session"), "screen should expose refresh binding")
	screen.free()
```

- [x] **Step 2: Run tests and observe the missing main scene**

Expected: scene load assertion fails.

- [x] **Step 3: Create the neon theme**

Create `resources/themes/neon_dream_theme.tres`:

```ini
[gd_resource type="Theme" load_steps=3 format=3]

[sub_resource type="StyleBoxFlat" id="Panel"]
bg_color = Color(0.045, 0.035, 0.14, 0.92)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.35, 0.9, 0.86, 0.72)
corner_radius_top_left = 10
corner_radius_top_right = 10
corner_radius_bottom_right = 10
corner_radius_bottom_left = 10

[sub_resource type="StyleBoxFlat" id="Button"]
bg_color = Color(0.2, 0.11, 0.36, 0.94)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.83, 0.48, 0.92, 0.9)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8

[resource]
default_font_size = 18
Label/colors/font_color = Color(0.94, 0.92, 1, 1)
Button/colors/font_color = Color(0.96, 0.93, 1, 1)
Button/styles/normal = SubResource("Button")
PanelContainer/styles/panel = SubResource("Panel")
```

- [x] **Step 4: Implement the screen controller and scene**

Create `scripts/ui/single_encounter_screen.gd`:

```gdscript
class_name SingleEncounterScreen
extends Control

const DIE_SCENE = preload("res://scenes/components/die_token.tscn")
const CARD_SCENE = preload("res://scenes/components/card_token.tscn")

@onready var lanes: Array[RuleLane] = [%LeftLane, %MiddleLane, %RightLane]
@onready var dice_tray: DiceTray = %DiceTray
@onready var hand_container: HBoxContainer = %Hand
@onready var resolution_panel: ResolutionPanel = %ResolutionPanel
@onready var error_label: Label = %ErrorLabel
@onready var calibration_label: Label = %CalibrationLabel
@onready var confirm_button: Button = %ConfirmButton

var session: SingleEncounterSession

func _ready() -> void:
	session = SingleEncounterSession.new(
		SingleEncounterFixture.make_state(),
		SingleEncounterFixture.make_encounter(),
		SingleEncounterFixture.make_hand()
	)
	for lane in lanes:
		lane.lane_activated.connect(_on_lane_activated)
		lane.die_activated.connect(_on_die_activated)
		lane.die_drop_requested.connect(_on_die_drop_requested)
	dice_tray.die_return_requested.connect(_on_die_return_requested)
	%LeftGap.pressed.connect(func() -> void: _on_gap_activated(&"left", &"middle"))
	%RightGap.pressed.connect(func() -> void: _on_gap_activated(&"middle", &"right"))
	%MinusButton.pressed.connect(func() -> void: _on_calibrate_pressed(-1))
	%PlusButton.pressed.connect(func() -> void: _on_calibrate_pressed(1))
	%UndoButton.pressed.connect(_on_undo_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	refresh_from_session()

func refresh_from_session() -> void:
	var state := session.controller.state
	var selected_target_type := _selected_card_target_type()
	for lane_index in range(lanes.size()):
		var rule := session.controller.encounter.rules[lane_index]
		var assigned: Array = []
		for die_id in state.assignments.get(rule.id, []):
			assigned.append(state.find_die(die_id))
		lanes[lane_index].bind_lane(
			rule,
			assigned,
			DIE_SCENE,
			session.selection.die_id
		)
		lanes[lane_index].set_legal_target(
			selected_target_type == CardDefinition.TargetType.TABLE
		)
		lanes[lane_index].set_die_target_highlight(
			selected_target_type == CardDefinition.TargetType.DIE
		)

	for child in dice_tray.get_children():
		child.queue_free()
	for die in state.dice:
		if not _is_assigned(die.id):
			var token: DieToken = DIE_SCENE.instantiate()
			dice_tray.add_child(token)
			token.bind_die(die, session.selection.die_id == die.id)
			token.set_legal_target(selected_target_type == CardDefinition.TargetType.DIE)
			token.die_activated.connect(_on_die_activated)

	for child in hand_container.get_children():
		child.queue_free()
	for index in range(session.hand.size()):
		var card_token: CardToken = CARD_SCENE.instantiate()
		hand_container.add_child(card_token)
		card_token.bind_card(
			index,
			session.hand[index],
			session.selection.card_index == index,
			session.is_card_used(index)
		)
		card_token.card_activated.connect(_on_card_activated)

	var gap_is_target := selected_target_type == CardDefinition.TargetType.GAP
	%LeftGap.self_modulate = Color(0.68, 1.0, 0.96, 1.0) if gap_is_target else Color.WHITE
	%RightGap.self_modulate = Color(0.68, 1.0, 0.96, 1.0) if gap_is_target else Color.WHITE
	resolution_panel.bind_report(session.preview())
	error_label.text = session.last_error
	calibration_label.text = "校准点：%d" % state.calibration_points
	confirm_button.disabled = session.controller.committed

func _selected_card_target_type() -> int:
	if session.selection.kind != InteractionState.Kind.CARD:
		return -1
	return session.hand[session.selection.card_index].target_type

func _is_assigned(die_id: StringName) -> bool:
	for table_id in session.controller.state.assignments:
		if die_id in session.controller.state.assignments[table_id]:
			return true
	return false

func _on_die_activated(die_id: StringName) -> void:
	session.activate_die(die_id)
	refresh_from_session()

func _on_card_activated(card_index: int) -> void:
	session.activate_card(card_index)
	refresh_from_session()

func _on_lane_activated(table_id: StringName) -> void:
	session.activate_table(table_id)
	refresh_from_session()

func _on_die_drop_requested(die_id: StringName, table_id: StringName) -> void:
	session.assign_dropped_die(die_id, table_id)
	refresh_from_session()

func _on_die_return_requested(die_id: StringName) -> void:
	session.return_die_to_tray(die_id)
	refresh_from_session()

func _on_gap_activated(left_id: StringName, right_id: StringName) -> void:
	session.activate_gap(left_id, right_id)
	refresh_from_session()

func _on_calibrate_pressed(delta: int) -> void:
	if session.selection.kind != InteractionState.Kind.DIE:
		session.last_error = "请先选择一颗骰子"
	else:
		session.calibrate_die(session.selection.die_id, delta)
	refresh_from_session()

func _on_undo_pressed() -> void:
	session.undo()
	refresh_from_session()

func _on_confirm_pressed() -> void:
	session.commit()
	refresh_from_session()
```

Create `scenes/run/single_encounter_screen.tscn` with this stable hierarchy:

```ini
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/ui/single_encounter_screen.gd" id="1"]
[ext_resource type="Theme" path="res://resources/themes/neon_dream_theme.tres" id="2"]
[ext_resource type="PackedScene" path="res://scenes/components/rule_lane.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/components/resolution_panel.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/ui/dice_tray.gd" id="5"]

[node name="SingleEncounterScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("2")
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.035, 0.025, 0.11, 1)
mouse_filter = 2

[node name="SafeArea" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 32.0
offset_top = 24.0
offset_right = -32.0
offset_bottom = -24.0
grow_horizontal = 2
grow_vertical = 2

[node name="RootColumn" type="VBoxContainer" parent="SafeArea"]
layout_mode = 2
theme_override_constants/separation = 18

[node name="TopBar" type="HBoxContainer" parent="SafeArea/RootColumn"]
layout_mode = 2

[node name="AreaLabel" type="Label" parent="SafeArea/RootColumn/TopBar"]
layout_mode = 2
size_flags_horizontal = 3
text = "梦层 01 · 无尽牌厅"
theme_override_font_sizes/font_size = 26

[node name="GoalLabel" type="Label" parent="SafeArea/RootColumn/TopBar"]
layout_mode = 2
text = "解析目标：0 / 100　轮次 1 / 3"

[node name="Body" type="HBoxContainer" parent="SafeArea/RootColumn"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 18

[node name="DealerPanel" type="PanelContainer" parent="SafeArea/RootColumn/Body"]
custom_minimum_size = Vector2(230, 0)
layout_mode = 2

[node name="DealerCopy" type="VBoxContainer" parent="SafeArea/RootColumn/Body/DealerPanel"]
layout_mode = 2

[node name="DealerName" type="Label" parent="SafeArea/RootColumn/Body/DealerPanel/DealerCopy"]
layout_mode = 2
text = "镜面夫人"
theme_override_font_sizes/font_size = 24

[node name="DealerRule" type="Label" parent="SafeArea/RootColumn/Body/DealerPanel/DealerCopy"]
layout_mode = 2
text = "本场规则：从左向右结算"
autowrap_mode = 2

[node name="Center" type="VBoxContainer" parent="SafeArea/RootColumn/Body"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 14

[node name="Lanes" type="HBoxContainer" parent="SafeArea/RootColumn/Body/Center"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="LeftLane" parent="SafeArea/RootColumn/Body/Center/Lanes" instance=ExtResource("3")]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3

[node name="LeftGap" type="Button" parent="SafeArea/RootColumn/Body/Center/Lanes"]
unique_name_in_owner = true
custom_minimum_size = Vector2(48, 0)
layout_mode = 2
text = "◇"
tooltip_text = "左侧桌间槽"

[node name="MiddleLane" parent="SafeArea/RootColumn/Body/Center/Lanes" instance=ExtResource("3")]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3

[node name="RightGap" type="Button" parent="SafeArea/RootColumn/Body/Center/Lanes"]
unique_name_in_owner = true
custom_minimum_size = Vector2(48, 0)
layout_mode = 2
text = "◇"
tooltip_text = "右侧桌间槽"

[node name="RightLane" parent="SafeArea/RootColumn/Body/Center/Lanes" instance=ExtResource("3")]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3

[node name="DiceRow" type="PanelContainer" parent="SafeArea/RootColumn/Body/Center"]
layout_mode = 2

[node name="DiceTray" type="HBoxContainer" parent="SafeArea/RootColumn/Body/Center/DiceRow"]
unique_name_in_owner = true
layout_mode = 2
alignment = 1
theme_override_constants/separation = 10
script = ExtResource("5")

[node name="Hand" type="HBoxContainer" parent="SafeArea/RootColumn/Body/Center"]
unique_name_in_owner = true
layout_mode = 2
alignment = 1
theme_override_constants/separation = 10

[node name="ActionBar" type="HBoxContainer" parent="SafeArea/RootColumn/Body/Center"]
layout_mode = 2

[node name="CalibrationLabel" type="Label" parent="SafeArea/RootColumn/Body/Center/ActionBar"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "校准点：2"

[node name="MinusButton" type="Button" parent="SafeArea/RootColumn/Body/Center/ActionBar"]
unique_name_in_owner = true
layout_mode = 2
text = "点数 -1"

[node name="PlusButton" type="Button" parent="SafeArea/RootColumn/Body/Center/ActionBar"]
unique_name_in_owner = true
layout_mode = 2
text = "点数 +1"

[node name="UndoButton" type="Button" parent="SafeArea/RootColumn/Body/Center/ActionBar"]
unique_name_in_owner = true
layout_mode = 2
text = "撤销"

[node name="ConfirmButton" type="Button" parent="SafeArea/RootColumn/Body/Center/ActionBar"]
unique_name_in_owner = true
layout_mode = 2
text = "确认结算"

[node name="ResolutionPanel" parent="SafeArea/RootColumn/Body" instance=ExtResource("4")]
unique_name_in_owner = true
layout_mode = 2

[node name="ErrorLabel" type="Label" parent="SafeArea/RootColumn"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(0, 28)
modulate = Color(1, 0.55, 0.66, 1)
text = ""
```

Import and run the core suite.

Expected: screen loads and exposes `refresh_from_session()`.

- [x] **Step 5: Commit screen code and resources**

```powershell
git add resources/themes/neon_dream_theme.tres scripts/ui/single_encounter_screen.gd scripts/ui/single_encounter_screen.gd.uid scenes/run/single_encounter_screen.tscn tests/ui_component_contract_test.gd tests/ui_component_contract_test.gd.uid
git commit --only resources/themes/neon_dream_theme.tres scripts/ui/single_encounter_screen.gd scripts/ui/single_encounter_screen.gd.uid scenes/run/single_encounter_screen.tscn tests/ui_component_contract_test.gd tests/ui_component_contract_test.gd.uid -m "feat: assemble three-lane encounter screen"
```

---

### Task 6: 1920×1080 Layout Self-Check

**Files:**
- Create: `tests/single_encounter_layout_self_check.gd`

**Interfaces:**
- Consumes: `single_encounter_screen.tscn`.
- Produces: asynchronous scene verification of bounds, lane widths, and non-overlap.

- [x] **Step 1: Create the self-check with one deliberately strict assertion**

Create `tests/single_encounter_layout_self_check.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	var dealer: Control = screen.get_node("SafeArea/RootColumn/Body/DealerPanel")
	var left: Control = screen.get_node("%LeftLane")
	var middle: Control = screen.get_node("%MiddleLane")
	var right: Control = screen.get_node("%RightLane")
	var resolution: Control = screen.get_node("%ResolutionPanel")
	var hand: Control = screen.get_node("%Hand")

	_assert_inside(screen.get_rect(), dealer.get_global_rect(), "dealer")
	_assert_inside(screen.get_rect(), left.get_global_rect(), "left lane")
	_assert_inside(screen.get_rect(), middle.get_global_rect(), "middle lane")
	_assert_inside(screen.get_rect(), right.get_global_rect(), "right lane")
	_assert_inside(screen.get_rect(), resolution.get_global_rect(), "resolution")
	_assert_inside(screen.get_rect(), hand.get_global_rect(), "hand")
	_assert_true(
		absf(left.size.x - middle.size.x) <= 2.0
		and absf(middle.size.x - right.size.x) <= 2.0,
		"three lanes should have equal widths"
	)
	_assert_true(dealer.get_global_rect().end.x < left.get_global_rect().position.x, "dealer must not overlap lanes")
	_assert_true(right.get_global_rect().end.x < resolution.get_global_rect().position.x, "lanes must not overlap resolution")

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS single_encounter_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s must remain inside 1920x1080 root" % label
	)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

- [x] **Step 2: Run the layout check**

```powershell
$layoutLog = Join-Path $env:TEMP 'project-joker-layout.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $layoutLog -s res://tests/single_encounter_layout_self_check.gd
```

Expected on the first run: either a concrete overlap/bounds failure or `PASS`; never a parser error. If it passes immediately, proceed without manufacturing a failure because the scene-load assertion in Task 5 already supplied the red phase.

- [x] **Step 3: Adjust only `.tscn` container sizes if the check reports geometry failures**

Use these allowed corrections:

```ini
DealerPanel/custom_minimum_size = Vector2(210, 0)
ResolutionPanel/custom_minimum_size = Vector2(280, 0)
RuleLane/custom_minimum_size = Vector2(220, 300)
```

Do not move layout construction into GDScript.

- [x] **Step 4: Re-run layout and core tests**

Expected: layout prints `PASS single_encounter_layout_self_check`; all core suites still pass; logs contain no script errors.

- [x] **Step 5: Commit the self-check and any scene-only geometry correction**

```powershell
git add tests/single_encounter_layout_self_check.gd tests/single_encounter_layout_self_check.gd.uid scenes/run/single_encounter_screen.tscn scenes/components/rule_lane.tscn
git commit --only tests/single_encounter_layout_self_check.gd tests/single_encounter_layout_self_check.gd.uid scenes/run/single_encounter_screen.tscn scenes/components/rule_lane.tscn -m "test: verify three-lane layout bounds"
```

---

### Task 7: Real Click, Drag, Card, Undo, and Commit Paths

**Files:**
- Create: `tests/single_encounter_input_self_check.gd`
- Modify: `scripts/ui/single_encounter_screen.gd` only if actual input exposes a wiring defect.
- Modify: component scripts/scenes only when the failing event identifies the exact component.

**Interfaces:**
- Consumes: actual `InputEventMouseButton` and `InputEventMouseMotion` events.
- Produces: proof that GUI press/motion/release reaches the domain session.

- [x] **Step 1: Create the real-input self-check**

Create `tests/single_encounter_input_self_check.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []
var screen: SingleEncounterScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	var d1 := _find_die(&"d1")
	var left: Control = screen.get_node("%LeftLane")
	await _drag(d1, left)
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", []) == [&"d1"],
		"real drag should assign d1 to left"
	)

	var tray: Control = screen.get_node("%DiceTray")
	var tray_drop_point := tray.get_global_rect().position + Vector2(12.0, tray.size.y * 0.5)
	await _drag_to_point(_find_die(&"d1"), tray_drop_point)
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", []).is_empty(),
		"dropping an assigned die on the tray should unassign it"
	)
	await _click(screen.get_node("%UndoButton"))
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", []) == [&"d1"],
		"undo should restore a die returned to the tray"
	)

	await _click(_find_die(&"d6"))
	await _click(left)
	_assert_true(
		screen.session.controller.state.assignments.get(&"left", []) == [&"d1", &"d6"],
		"click fallback should assign d6 to left"
	)

	await _click(_find_die(&"d2"))
	await _click(left)
	_assert_true(not screen.get_node("%ErrorLabel").text.is_empty(), "invalid target should show a reason")
	_assert_true(
		&"d2" not in screen.session.controller.state.assignments.get(&"left", []),
		"full lane must reject another die"
	)

	await _click(_find_card(0))
	_assert_true(
		_find_die(&"d2").self_modulate != Color.WHITE
		and screen.get_node("%LeftLane").self_modulate == Color.WHITE,
		"die cards should highlight dice without highlighting tables"
	)
	await _click(_find_card(2))
	_assert_true(
		screen.get_node("%LeftGap").self_modulate != Color.WHITE
		and screen.get_node("%LeftLane").self_modulate == Color.WHITE,
		"gap cards should highlight gaps without highlighting tables"
	)

	var table_card := _find_card(1)
	await _click(table_card)
	_assert_true(
		screen.get_node("%LeftLane").self_modulate != Color.WHITE,
		"selecting a table card should highlight legal table targets"
	)
	await _click(left)
	_assert_true(screen.session.preview().total >= 21, "table card should affect preview")

	await _click(screen.get_node("%UndoButton"))
	_assert_true(not screen.session.is_card_used(1), "undo should restore the card")

	await _click(_find_die(&"d5"))
	await _click(screen.get_node("%MinusButton"))
	screen.session.activate_die(&"d2")
	screen.session.activate_table(&"middle")
	screen.session.activate_die(&"d3")
	screen.session.activate_table(&"middle")
	screen.session.activate_die(&"d4")
	screen.session.activate_table(&"middle")
	screen.session.activate_die(&"d5")
	screen.session.activate_table(&"right")
	screen.session.activate_card(1)
	screen.session.activate_table(&"left")
	screen.refresh_from_session()
	_assert_true(screen.session.preview().total == 51, "complete UI state should preview 51")

	await _click(screen.get_node("%ConfirmButton"))
	_assert_true(screen.session.controller.committed, "confirm button should commit")
	_assert_true(screen.session.commit().total == 51, "committed report should remain 51")

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS single_encounter_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _find_die(id: StringName) -> Control:
	for node in screen.find_children("*", "DieToken", true, false):
		if node.die_id == id:
			return node
	return null

func _find_card(index: int) -> Control:
	for node in screen.find_children("*", "CardToken", true, false):
		if node.card_index == index:
			return node
	return null

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	Input.parse_input_event(release)
	await process_frame

func _drag(source: Control, target: Control) -> void:
	var finish := target.get_global_rect().get_center()
	await _drag_to_point(source, finish)

func _drag_to_point(source: Control, finish: Vector2) -> void:
	var start := source.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	Input.parse_input_event(press)
	await process_frame
	for index in range(1, 6):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(finish, float(index) / 5.0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	Input.parse_input_event(release)
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

- [x] **Step 2: Run the real-input check**

```powershell
$inputLog = Join-Path $env:TEMP 'project-joker-input.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $inputLog -s res://tests/single_encounter_input_self_check.gd
```

Expected on the first run: a specific interaction assertion may fail; parser errors, null-node errors, or manually emitted component signals do not count as interaction proof.

- [x] **Step 3: Fix only the observed event-path defect**

Allowed fixes are:

- `mouse_filter` values in `.tscn`.
- Missing signal connections in `_ready()`.
- Drag/drop target methods on the actual receiving control.
- Refresh ordering after an accepted session action.

Do not replace real input with manually emitted signals.

- [x] **Step 4: Run input, layout, and core suites**

Expected:

```text
PASS single_encounter_input_self_check
PASS single_encounter_layout_self_check
ALL TESTS PASSED
```

All logs must be free of `SCRIPT ERROR` and `Failed to load script`.

- [x] **Step 5: Commit interaction code and the self-check**

```powershell
git add tests/single_encounter_input_self_check.gd tests/single_encounter_input_self_check.gd.uid scripts/ui/single_encounter_screen.gd scripts/ui/single_encounter_screen.gd.uid scripts/ui/die_token.gd scripts/ui/die_token.gd.uid scripts/ui/rule_lane.gd scripts/ui/rule_lane.gd.uid scripts/ui/dice_tray.gd scripts/ui/dice_tray.gd.uid scenes/run/single_encounter_screen.tscn scenes/components/die_token.tscn scenes/components/rule_lane.tscn
git commit --only tests/single_encounter_input_self_check.gd tests/single_encounter_input_self_check.gd.uid scripts/ui/single_encounter_screen.gd scripts/ui/single_encounter_screen.gd.uid scripts/ui/die_token.gd scripts/ui/die_token.gd.uid scripts/ui/rule_lane.gd scripts/ui/rule_lane.gd.uid scripts/ui/dice_tray.gd scripts/ui/dice_tray.gd.uid scenes/run/single_encounter_screen.tscn scenes/components/die_token.tscn scenes/components/rule_lane.tscn -m "test: verify real encounter input paths"
```

---

### Task 8: Main Scene and Phase Acceptance

**Files:**
- Modify: `project.godot`
- Modify: `docs/superpowers/plans/2026-07-24-three-lane-single-encounter-ui.md`

**Interfaces:**
- Consumes: the verified screen and self-checks.
- Produces: project launch into the playable single encounter.

- [x] **Step 1: Set the main scene and fixed test viewport**

Add to `[application]` in `project.godot`:

```ini
run/main_scene="res://scenes/run/single_encounter_screen.tscn"
```

Add:

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

- [x] **Step 2: Run the complete automated acceptance set**

```powershell
$acceptImportLog = Join-Path $env:TEMP 'project-joker-ui-accept-import.log'
$acceptCoreLog = Join-Path $env:TEMP 'project-joker-ui-accept-core.log'
$acceptLayoutLog = Join-Path $env:TEMP 'project-joker-ui-accept-layout.log'
$acceptInputLog = Join-Path $env:TEMP 'project-joker-ui-accept-input.log'

& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $acceptImportLog --import
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $acceptCoreLog -s res://tests/run_all.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $acceptLayoutLog -s res://tests/single_encounter_layout_self_check.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $acceptInputLog -s res://tests/single_encounter_input_self_check.gd
```

Expected:

- Import exits `0`.
- Every synchronous suite passes.
- Layout self-check passes at 1920×1080.
- Real input self-check passes press/motion/release, click fallback, card targeting, undo, prediction, and commit.
- No acceptance log contains `SCRIPT ERROR` or `Failed to load script`.

- [x] **Step 3: Run the project once for visible smoke verification**

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64.exe' --path .
```

Verify:

- Dealer column, three equal lanes, two gap targets, tray, four cards, action bar, and resolution column are simultaneously visible.
- Purple background and cyan rule structure do not obscure text.
- Invalid actions display a concrete reason in `ErrorLabel`.
- No chips, roulette, slot-machine, coin-rain, or betting vocabulary appears.

Close the game after the smoke check.

- [x] **Step 4: Mark completed plan checkboxes and stage documentation**

Change completed `- [x]` entries in this document to `- [x]`, then run:

```powershell
git add docs/superpowers/plans/2026-07-24-core-rules-foundation.md docs/superpowers/plans/2026-07-24-three-lane-single-encounter-ui.md
```

Expected: both plan documents remain staged and uncommitted.

- [x] **Step 5: Commit only project configuration**

```powershell
git add project.godot
git commit --only project.godot -m "feat: launch single encounter ui"
git status --short
```

Expected: Git status shows only the two staged plan documents.

## Implementation Notes

- The real-input self-check uses `Window.push_input()` with actual
  `InputEventMouseMotion` and `InputEventMouseButton` objects. Global
  `Input.parse_input_event()` was nondeterministic under headless window focus;
  direct Window dispatch still exercises Godot's GUI hit-testing and component
  signal path without manually emitting signals.
- Dynamic die/card lookup ignores nodes queued for deletion because each screen
  refresh replaces rendered tokens at the end of the frame.
- Intermediate controls inside `RuleLane` use `MOUSE_FILTER_PASS`, allowing
  title/condition clicks to reach the lane while `DieToken` buttons retain their
  own click behavior.
- Player-facing action and resolution reasons are localized to Chinese after
  visible smoke review exposed mixed-language feedback.

## Phase 2 Exit Checklist

- [x] Project launches directly into `single_encounter_screen.tscn`.
- [x] Three equal rule lanes and two physical gap targets remain inside 1920×1080.
- [x] Six dice can be assigned by real drag/drop.
- [x] Click-die-then-click-lane performs the same assignment.
- [x] Dropping an assigned die onto the tray unassigns it.
- [x] Die-, table-, gap-, and global-target cards route through `SingleEncounterSession`.
- [x] Invalid targets display a concrete reason.
- [x] Used cards visibly disable.
- [x] Undo restores the previous dice/card state before commit.
- [x] Prediction reaches 44, card modification reaches 51, undo returns to 44.
- [x] Commit preserves the exact preview event signature and total.
- [x] Resolution events show label, delta, and running total.
- [x] UI scripts never calculate score.
- [x] Layout and real-input self-checks pass without manually emitted component signals.
- [x] Core rule suites remain green.
- [x] Godot logs contain no script load or compile errors.
- [x] Both implementation-plan documents remain staged and uncommitted.
