# Three-Round Deck and Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a playable deterministic three-round encounter that exposes all twelve starter cards, accumulates a public target, and enters an atomic three-card replacement shop.

**Architecture:** Keep the validated single-round resolver and tutorial intact. Add a resource-backed `CardCatalog`, a pure `ThreeRoundEncounterSession`, and a pure `ShopSession`; compose them through a new scene-backed run screen that injects each round into the existing `SingleEncounterScreen` and switches to scene-backed summary and shop views.

**Tech Stack:** Godot 4.6.1, typed GDScript, custom `Resource` content, `.tscn` scene composition, dependency-free synchronous tests, and real `Window.push_input()` scene checks.

## Global Constraints

- Work directly on `master`, as explicitly authorized for this repository.
- Keep design and plan documents staged and uncommitted.
- Preserve the existing unstaged `project.godot` modification; do not edit, stage, or commit that file.
- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` for automated checks.
- Every headless Godot command passes `--log-file` to a writable path under `$env:TEMP`.
- Treat `SCRIPT ERROR` or `Failed to load script` as failure even when Godot exits `0`.
- Keep the existing tutorial hand, fixed dice, and `44→51→44→51` action path unchanged.
- Preview and commit continue to use the same `RoundResolver`.
- UI code never calculates score, cumulative total, ticket balance, or purchase validity.
- The default run seed is exactly `20260726`, the target is exactly `100`, and success grants exactly `2` intelligence tickets.
- The starter deck contains exactly twelve unique IDs; the shop pool contains exactly three non-overlapping IDs.
- The three encounter rounds continue to use `SingleEncounterFixture.make_encounter()`.
- Code commits use `git commit --only` with explicit code, scene, resource, tool, and test paths so staged documentation is excluded.

## File Map

```text
res://
  resources/
    cards/
      stage4/
        starter_*.tres
        shop_*.tres
  scenes/
    components/
      card_token.tscn
      round_summary_panel.tscn
      shop_card_token.tscn
    run/
      single_encounter_screen.tscn
      three_round_run_screen.tscn
    shop/
      shop_screen.tscn
  scripts/
    cards/
      card_catalog.gd
      card_definition.gd
    demo/
      single_encounter_fixture.gd
    resolution/
      round_resolver.gd
    run/
      operation_result.gd
      shop_session.gd
      three_round_encounter_session.gd
    ui/
      card_token.gd
      round_summary_panel.gd
      shop/
        shop_card_token.gd
        shop_screen.gd
      single_encounter_screen.gd
      three_round_run_screen.gd
    validation/
      content_validator.gd
  tests/
    content_validator_test.gd
    shop_session_test.gd
    stage4_card_catalog_test.gd
    three_round_encounter_session_test.gd
    three_round_input_self_check.gd
    three_round_layout_self_check.gd
    ui_component_contract_test.gd
  tools/
    generate_stage4_cards.gd
```

---

### Task 1: Resource-Backed Stage 4 Card Catalog

**Files:**
- Modify: `scripts/cards/card_definition.gd`
- Modify: `scripts/demo/single_encounter_fixture.gd`
- Modify: `scripts/resolution/round_resolver.gd`
- Modify: `scripts/ui/card_token.gd`
- Modify: `scenes/components/card_token.tscn`
- Modify: `scripts/validation/content_validator.gd`
- Modify: `tests/content_validator_test.gd`
- Create: `scripts/cards/card_catalog.gd`
- Create: `tools/generate_stage4_cards.gd`
- Generate: `resources/cards/stage4/*.tres`
- Create: `tests/stage4_card_catalog_test.gd`

**Interfaces:**
- Consumes: existing `CardDefinition`, `EffectSpec`, `ContentValidator`, and `RoundResolver`.
- Produces: `CardCatalog.new()`, `all_cards()`, `starter_deck()`, `starter_ids()`, `shop_pool()`, `shop_ids()`, `find_card(card_id)`, and `validate()`.

- [x] **Step 1: Write the failing catalog test**

Create `tests/stage4_card_catalog_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const CatalogScript = preload("res://scripts/cards/card_catalog.gd")

func run() -> void:
	var catalog = CatalogScript.new()
	assert_equal(catalog.validate(), [], "stage 4 card content should validate")
	assert_equal(catalog.starter_deck().size(), 12, "starter deck should contain twelve cards")
	assert_equal(catalog.shop_pool().size(), 3, "shop pool should contain three cards")

	var all_ids: Dictionary = {}
	for card in catalog.all_cards():
		assert_false(all_ids.has(card.id), "card IDs should be unique")
		all_ids[card.id] = true
		assert_false(card.rule_text.strip_edges().is_empty(), "rule text should be present")
		assert_true(card.tags.size() >= 1, "every card should expose at least one display tag")
	assert_equal(all_ids.size(), 15, "catalog should expose fifteen cards")

	for card_id in catalog.starter_ids():
		assert_false(card_id in catalog.shop_ids(), "starter and shop IDs should not overlap")

	var stable := catalog.find_card(&"starter_stable_repeat")
	assert_true(stable != null, "combined starter card should load")
	if stable != null:
		assert_equal(stable.effects.size(), 2, "stable repeat should contain two effects")
		assert_equal(
			stable.effects[0].operation,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			"stable repeat should modify the coefficient first"
		)
		assert_equal(stable.effects[0].amount, -1, "stable repeat should lower coefficient by one")
		assert_equal(
			stable.effects[1].operation,
			EffectSpec.Operation.REPEAT_TABLE,
			"stable repeat should repeat the table second"
		)

	var missing = catalog.find_card(&"missing_card")
	assert_true(missing == null, "unknown card IDs should return null")
```

- [x] **Step 2: Run the synchronous suite and verify the catalog is missing**

```powershell
$redLog = Join-Path $env:TEMP 'project-joker-stage4-card-catalog-red.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $redLog -s res://tests/run_all.gd
```

Expected: preload failure for `res://scripts/cards/card_catalog.gd`.

- [x] **Step 3: Add card copy fields and keep the teaching fixture complete**

Add to `CardDefinition`:

```gdscript
@export_multiline var rule_text: String
@export var tags: PackedStringArray = []
```

Replace `SingleEncounterFixture.make_hand()` with:

```gdscript
static func make_hand() -> Array[CardDefinition]:
	return [
		_card(
			&"club_nudge",
			"拨码",
			CardDefinition.TargetType.DIE,
			EffectSpec.Operation.ADJUST_DIE,
			-1,
			"令一颗骰子的点数 -1，最终点数限制在 1..6。",
			PackedStringArray(["骰值", "校准"])
		),
		_card(
			&"diamond_map",
			"映射",
			CardDefinition.TargetType.TABLE,
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			1,
			"令一张规则台的系数 +1。",
			PackedStringArray(["规则台", "系数"])
		),
		_card(
			&"spade_link",
			"桥接",
			CardDefinition.TargetType.GAP,
			EffectSpec.Operation.LINK_NEIGHBORS,
			1,
			"把左侧规则台的已解析结果传递到右侧规则台。",
			PackedStringArray(["桌间", "传递"])
		),
		_card(
			&"heart_reverse",
			"倒序",
			CardDefinition.TargetType.GLOBAL,
			EffectSpec.Operation.REVERSE_RESOLUTION,
			0,
			"反转本轮规则台的解析顺序。",
			PackedStringArray(["全局", "顺序"])
		),
	]
```

Replace the fixture helper with:

```gdscript
static func _card(
	id: StringName,
	display_name: String,
	target_type: CardDefinition.TargetType,
	operation: EffectSpec.Operation,
	amount: int,
	rule_text: String,
	tags: PackedStringArray
) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = operation
	effect.amount = amount
	var card := CardDefinition.new()
	card.id = id
	card.display_name = display_name
	card.target_type = target_type
	card.effects = [effect]
	card.rule_text = rule_text
	card.tags = tags
	return card
```

Update `CardToken.bind_card()` to display rules instead of only the target:

```gdscript
text = "%s\n%s\n%s" % [
	definition.display_name,
	_target_copy(definition.target_type),
	definition.rule_text,
]
tooltip_text = "%s；目标：%s；%s" % [
	definition.display_name,
	_target_copy(definition.target_type),
	definition.rule_text,
]
```

In `scenes/components/card_token.tscn`, make the longer deterministic rule copy readable:

```ini
custom_minimum_size = Vector2(164, 112)
autowrap_mode = 2
```

- [x] **Step 4: Validate card copy and enforce the coefficient floor in the resolver**

Inside `ContentValidator.validate()`, after checking `display_name`, add:

```gdscript
if card.rule_text.strip_edges().is_empty():
	errors.append("card %s has no rule text" % card.id)
if card.tags.is_empty():
	errors.append("card %s has no display tags" % card.id)
```

Update the valid card in `tests/content_validator_test.gd`:

```gdscript
valid_card.rule_text = "令一张规则台的系数 +1。"
valid_card.tags = PackedStringArray(["规则台", "系数"])
```

In `RoundResolver`, replace the direct evaluator call with:

```gdscript
var requested_modifier: int = coefficient_modifiers.get(rule.id, 0)
var minimum_modifier := 1 - rule.coefficient
var effective_modifier := maxi(requested_modifier, minimum_modifier)
var result := _evaluator.evaluate(rule, values, effective_modifier)
```

This makes `starter_stable_repeat` obey “coefficient -1, minimum 1” without UI correction.

- [x] **Step 5: Add the deterministic card resource generator**

Create `tools/generate_stage4_cards.gd`:

```gdscript
extends SceneTree

const OUTPUT_DIR := "res://resources/cards/stage4"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK:
		push_error("Cannot create stage 4 card directory: %s" % error_string(directory_error))
		quit(1)
		return

	var definitions: Array[Dictionary] = [
		_spec(&"starter_nudge_down_1", "拨码", "令一颗骰子的点数 -1，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "微调"], [[EffectSpec.Operation.ADJUST_DIE, -1]]),
		_spec(&"starter_nudge_up_1", "推码", "令一颗骰子的点数 +1，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "微调"], [[EffectSpec.Operation.ADJUST_DIE, 1]]),
		_spec(&"starter_nudge_down_2", "深降", "令一颗骰子的点数 -2，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "强调"], [[EffectSpec.Operation.ADJUST_DIE, -2]]),
		_spec(&"starter_nudge_up_2", "跃升", "令一颗骰子的点数 +2，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "强调"], [[EffectSpec.Operation.ADJUST_DIE, 2]]),
		_spec(&"starter_map_1", "映射", "令一张规则台的系数 +1。", CardDefinition.TargetType.TABLE, ["规则台", "系数"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 1]]),
		_spec(&"starter_map_2", "增幅映射", "令一张规则台的系数 +2。", CardDefinition.TargetType.TABLE, ["规则台", "系数"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 2]]),
		_spec(&"starter_repeat_1", "复写", "令一张规则台额外结算 1 次。", CardDefinition.TargetType.TABLE, ["规则台", "重复"], [[EffectSpec.Operation.REPEAT_TABLE, 1]]),
		_spec(&"starter_repeat_2", "双重复写", "令一张规则台额外结算 2 次。", CardDefinition.TargetType.TABLE, ["规则台", "重复"], [[EffectSpec.Operation.REPEAT_TABLE, 2]]),
		_spec(&"starter_stable_repeat", "稳态复写", "令一张规则台的系数 -1（最低为 1），并额外结算 1 次。", CardDefinition.TargetType.TABLE, ["规则台", "权衡"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, -1], [EffectSpec.Operation.REPEAT_TABLE, 1]]),
		_spec(&"starter_amplified_repeat", "增幅复写", "令一张规则台的系数 +1，并额外结算 1 次。", CardDefinition.TargetType.TABLE, ["规则台", "联动"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 1], [EffectSpec.Operation.REPEAT_TABLE, 1]]),
		_spec(&"starter_reverse", "倒序", "反转本轮规则台的解析顺序。", CardDefinition.TargetType.GLOBAL, ["全局", "顺序"], [[EffectSpec.Operation.REVERSE_RESOLUTION, 0]]),
		_spec(&"starter_link", "桥接", "把左侧规则台的已解析结果传递到右侧规则台。", CardDefinition.TargetType.GAP, ["桌间", "传递"], [[EffectSpec.Operation.LINK_NEIGHBORS, 1]]),
		_spec(&"shop_precision_map", "精密映射", "令一张规则台的系数 +3。", CardDefinition.TargetType.TABLE, ["商店", "系数"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 3]]),
		_spec(&"shop_triple_repeat", "三重复写", "令一张规则台额外结算 3 次。", CardDefinition.TargetType.TABLE, ["商店", "重复"], [[EffectSpec.Operation.REPEAT_TABLE, 3]]),
		_spec(&"shop_long_push", "长距推码", "令一颗骰子的点数 +3，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["商店", "骰值"], [[EffectSpec.Operation.ADJUST_DIE, 3]]),
	]

	var failures: Array[String] = []
	for definition in definitions:
		var card := _make_card(definition)
		var path := OUTPUT_DIR.path_join("%s.tres" % String(card.id))
		var save_error := ResourceSaver.save(card, path, ResourceSaver.FLAG_CHANGE_PATH)
		if save_error != OK:
			failures.append("%s: %s" % [path, error_string(save_error)])

	if failures.is_empty():
		print("GENERATED %d STAGE 4 CARDS" % definitions.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _spec(
	id: StringName,
	display_name: String,
	rule_text: String,
	target_type: CardDefinition.TargetType,
	tags: Array,
	effects: Array
) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"rule_text": rule_text,
		"target_type": target_type,
		"tags": tags,
		"effects": effects,
	}

func _make_card(spec: Dictionary) -> CardDefinition:
	var card := CardDefinition.new()
	card.id = spec.id
	card.display_name = spec.display_name
	card.rule_text = spec.rule_text
	card.target_type = spec.target_type
	card.tags = PackedStringArray(spec.tags)
	var effects: Array[EffectSpec] = []
	for effect_spec in spec.effects:
		var effect := EffectSpec.new()
		effect.operation = effect_spec[0]
		effect.amount = effect_spec[1]
		effects.append(effect)
	card.effects = effects
	return card
```

- [x] **Step 6: Generate the resources and import them**

```powershell
$generateLog = Join-Path $env:TEMP 'project-joker-stage4-card-generate.log'
$importLog = Join-Path $env:TEMP 'project-joker-stage4-card-import.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $generateLog -s res://tools/generate_stage4_cards.gd
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $importLog --import
```

Expected: `GENERATED 15 STAGE 4 CARDS`; fifteen `.tres` files exist; neither log contains a script error.

- [x] **Step 7: Implement the catalog**

Create `scripts/cards/card_catalog.gd`:

```gdscript
class_name CardCatalog
extends RefCounted

const STARTER_PATHS := PackedStringArray([
	"res://resources/cards/stage4/starter_nudge_down_1.tres",
	"res://resources/cards/stage4/starter_nudge_up_1.tres",
	"res://resources/cards/stage4/starter_nudge_down_2.tres",
	"res://resources/cards/stage4/starter_nudge_up_2.tres",
	"res://resources/cards/stage4/starter_map_1.tres",
	"res://resources/cards/stage4/starter_map_2.tres",
	"res://resources/cards/stage4/starter_repeat_1.tres",
	"res://resources/cards/stage4/starter_repeat_2.tres",
	"res://resources/cards/stage4/starter_stable_repeat.tres",
	"res://resources/cards/stage4/starter_amplified_repeat.tres",
	"res://resources/cards/stage4/starter_reverse.tres",
	"res://resources/cards/stage4/starter_link.tres",
])

const SHOP_PATHS := PackedStringArray([
	"res://resources/cards/stage4/shop_precision_map.tres",
	"res://resources/cards/stage4/shop_triple_repeat.tres",
	"res://resources/cards/stage4/shop_long_push.tres",
])

var _starter_cards: Array[CardDefinition] = []
var _shop_cards: Array[CardDefinition] = []
var _cards_by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	_starter_cards = _load_cards(STARTER_PATHS)
	_shop_cards = _load_cards(SHOP_PATHS)
	for card in all_cards():
		if _cards_by_id.has(card.id):
			_load_errors.append("duplicate card ID: %s" % card.id)
		else:
			_cards_by_id[card.id] = card

func all_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	cards.append_array(_starter_cards)
	cards.append_array(_shop_cards)
	return cards

func starter_deck() -> Array[CardDefinition]:
	return _starter_cards.duplicate()

func starter_ids() -> Array[StringName]:
	return _ids(_starter_cards)

func shop_pool() -> Array[CardDefinition]:
	return _shop_cards.duplicate()

func shop_ids() -> Array[StringName]:
	return _ids(_shop_cards)

func find_card(card_id: StringName) -> CardDefinition:
	return _cards_by_id.get(card_id) as CardDefinition

func validate() -> Array[String]:
	var errors: Array[String] = _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate([], all_cards()))
	if _starter_cards.size() != 12:
		errors.append("starter deck must contain exactly twelve cards")
	if _shop_cards.size() != 3:
		errors.append("shop pool must contain exactly three cards")
	for card_id in starter_ids():
		if card_id in shop_ids():
			errors.append("starter and shop IDs overlap: %s" % card_id)
	return errors

func _load_cards(paths: PackedStringArray) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for path in paths:
		var resource := load(path)
		if resource is CardDefinition:
			cards.append(resource)
		else:
			_load_errors.append("failed to load card resource: %s" % path)
	return cards

func _ids(cards: Array[CardDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in cards:
		ids.append(card.id)
	return ids
```

- [x] **Step 8: Run synchronous tests**

```powershell
$testLog = Join-Path $env:TEMP 'project-joker-stage4-card-catalog.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $testLog -s res://tests/run_all.gd
```

Expected: catalog and existing suites pass; no script errors.

- [x] **Step 9: Commit card content only**

```powershell
git add scripts/cards/card_definition.gd scripts/cards/card_catalog.gd scripts/cards/card_catalog.gd.uid scripts/demo/single_encounter_fixture.gd scripts/resolution/round_resolver.gd scripts/ui/card_token.gd scenes/components/card_token.tscn scripts/validation/content_validator.gd tests/content_validator_test.gd tests/stage4_card_catalog_test.gd tests/stage4_card_catalog_test.gd.uid tools/generate_stage4_cards.gd tools/generate_stage4_cards.gd.uid resources/cards/stage4
git commit --only -m "feat: add stage four card catalog" -- scripts/cards/card_definition.gd scripts/cards/card_catalog.gd scripts/cards/card_catalog.gd.uid scripts/demo/single_encounter_fixture.gd scripts/resolution/round_resolver.gd scripts/ui/card_token.gd scenes/components/card_token.tscn scripts/validation/content_validator.gd tests/content_validator_test.gd tests/stage4_card_catalog_test.gd tests/stage4_card_catalog_test.gd.uid tools/generate_stage4_cards.gd tools/generate_stage4_cards.gd.uid resources/cards/stage4
```

---

### Task 2: Deterministic Three-Round Encounter Session

**Files:**
- Create: `scripts/run/operation_result.gd`
- Create: `scripts/run/three_round_encounter_session.gd`
- Create: `tests/three_round_encounter_session_test.gd`

**Interfaces:**
- Consumes: `CardCatalog`, `CardDeck`, `RunRng`, `SingleEncounterFixture`, `SingleEncounterSession`, and committed `ResolutionReport` object identity.
- Produces: `OperationResult`, `ThreeRoundEncounterSession.start()`, `accept_committed_report(report)`, `advance_round()`, `current_session`, `current_hand_ids`, `cumulative_total`, `status`, `intel_tickets`, and `shop_offer_ids`.

- [x] **Step 1: Write the failing session test**

Create `tests/three_round_encounter_session_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const RunScript = preload("res://scripts/run/three_round_encounter_session.gd")

func run() -> void:
	var first := _play_empty_run(20260726, 100)
	var second := _play_empty_run(20260726, 100)
	assert_equal(first.dice, second.dice, "same seed should reproduce dice")
	assert_equal(first.hands, second.hands, "same seed should reproduce hands")
	assert_equal(first.offers, second.offers, "same seed should reproduce shop offer order")
	assert_equal(first.seen.size(), 12, "three rounds should expose twelve cards")
	var unique_seen: Dictionary = {}
	for card_id in first.seen:
		unique_seen[card_id] = true
	assert_equal(unique_seen.size(), 12, "three round hands should not repeat cards")
	assert_equal(first.status, RunScript.Status.FAILED, "zero total should fail a target of 100")
	assert_equal(
		first.cumulative,
		first.report_sum,
		"cumulative total should equal the three committed reports"
	)

	var different := _play_empty_run(20260727, 100)
	assert_true(
		first.dice != different.dice or first.hands != different.hands,
		"different seeds should change dice or hand order"
	)

	var successful := _play_empty_run(20260726, 0)
	var successful_repeat := _play_empty_run(20260726, 0)
	assert_equal(successful.status, RunScript.Status.SUCCEEDED, "zero target should succeed")
	assert_equal(successful.intel, 2, "success should grant two intelligence tickets")
	assert_equal(successful.offers.size(), 3, "success should prepare three offers")
	assert_equal(
		successful.offers,
		successful_repeat.offers,
		"same successful seed should reproduce shop offer order"
	)

func _play_empty_run(seed_value: int, target_total: int) -> Dictionary:
	var run_session = RunScript.new(CardCatalog.new(), seed_value, target_total)
	assert_true(run_session.start().accepted, "run should start")
	var dice_by_round: Array = []
	var hands_by_round: Array = []
	var seen: Array[StringName] = []
	var report_sum := 0

	for round_number in range(1, 4):
		var dice_values: Array[int] = []
		for die in run_session.current_session.controller.state.dice:
			dice_values.append(die.value)
		dice_by_round.append(dice_values)
		hands_by_round.append(run_session.current_hand_ids.duplicate())
		seen.append_array(run_session.current_hand_ids)

		var preview := run_session.current_session.preview()
		var report := run_session.current_session.commit()
		assert_equal(report.total, preview.total, "preview and commit totals should match")
		assert_equal(
			report.event_signature(),
			preview.event_signature(),
			"preview and commit events should match"
		)
		report_sum += report.total
		var accepted := run_session.accept_committed_report(report)
		assert_true(accepted.accepted, "committed report should be accepted")
		if round_number == 1:
			var before := run_session.cumulative_total
			var duplicate := run_session.accept_committed_report(report)
			assert_false(duplicate.accepted, "same round should not be accumulated twice")
			assert_equal(run_session.cumulative_total, before, "duplicate should not change total")
		if round_number < 3:
			assert_equal(
				run_session.status,
				RunScript.Status.ROUND_SUMMARY,
				"early rounds should stop at summary"
			)
			assert_true(run_session.advance_round().accepted, "next round should start")

	return {
		"dice": dice_by_round,
		"hands": hands_by_round,
		"seen": seen,
		"status": run_session.status,
		"intel": run_session.intel_tickets,
		"offers": run_session.shop_offer_ids.duplicate(),
		"cumulative": run_session.cumulative_total,
		"report_sum": report_sum,
	}
```

- [x] **Step 2: Run the suite and verify the session is missing**

Run `tests/run_all.gd` with a writable log.

Expected: preload failure for `three_round_encounter_session.gd`.

- [x] **Step 3: Add the generic operation result**

Create `scripts/run/operation_result.gd`:

```gdscript
class_name OperationResult
extends RefCounted

var accepted: bool
var reason: String

func _init(p_accepted: bool, p_reason: String = "") -> void:
	accepted = p_accepted
	reason = p_reason
```

- [x] **Step 4: Implement the three-round session**

Create `scripts/run/three_round_encounter_session.gd`:

```gdscript
class_name ThreeRoundEncounterSession
extends RefCounted

enum Status {
	NOT_STARTED,
	PLAYING,
	ROUND_SUMMARY,
	SUCCEEDED,
	FAILED,
}

const DEFAULT_SEED := 20260726
const DEFAULT_TARGET := 100
const ROUND_COUNT := 3
const SUCCESS_INTEL_REWARD := 2

var catalog: CardCatalog
var seed_value: int
var target_total: int
var status: Status = Status.NOT_STARTED
var current_round: int = 0
var current_session: SingleEncounterSession
var current_hand_ids: Array[StringName] = []
var starter_deck_ids: Array[StringName] = []
var committed_reports: Array[ResolutionReport] = []
var cumulative_total: int = 0
var intel_tickets: int = 0
var shop_offer_ids: Array[StringName] = []
var last_error: String = ""

var _run_rng: RunRng
var _deck := CardDeck.new()

func _init(
	p_catalog: CardCatalog,
	p_seed_value: int = DEFAULT_SEED,
	p_target_total: int = DEFAULT_TARGET
) -> void:
	catalog = p_catalog
	seed_value = p_seed_value
	target_total = p_target_total

func start() -> OperationResult:
	if status != Status.NOT_STARTED:
		return _fail("三轮试局已经开始")
	var content_errors := catalog.validate()
	if not content_errors.is_empty():
		return _fail("卡牌内容无效：%s" % "；".join(content_errors))

	_run_rng = RunRng.new(seed_value)
	starter_deck_ids = catalog.starter_ids()
	_deck.start_encounter(starter_deck_ids, _run_rng)
	current_round = 1
	var begin_result := _begin_round()
	if not begin_result.accepted:
		return begin_result
	status = Status.PLAYING
	last_error = ""
	return OperationResult.new(true)

func accept_committed_report(report: ResolutionReport) -> OperationResult:
	if status != Status.PLAYING:
		return _fail("当前不接受轮次结算")
	if current_session == null or not current_session.controller.committed:
		return _fail("当前轮尚未正式结算")
	var committed_report := current_session.commit()
	if report == null or report != committed_report:
		return _fail("提交的结算报告不是当前轮正式结果")

	committed_reports.append(report)
	cumulative_total += report.total
	if current_round < ROUND_COUNT:
		status = Status.ROUND_SUMMARY
	else:
		if cumulative_total >= target_total:
			status = Status.SUCCEEDED
			intel_tickets = SUCCESS_INTEL_REWARD
			shop_offer_ids.assign(_run_rng.shuffle(catalog.shop_ids()))
		else:
			status = Status.FAILED
	last_error = ""
	return OperationResult.new(true)

func advance_round() -> OperationResult:
	if status != Status.ROUND_SUMMARY:
		return _fail("当前不能进入下一轮")
	current_round += 1
	var begin_result := _begin_round()
	if not begin_result.accepted:
		current_round -= 1
		return begin_result
	status = Status.PLAYING
	last_error = ""
	return OperationResult.new(true)

func _begin_round() -> OperationResult:
	current_hand_ids = _deck.draw_round()
	if current_hand_ids.size() != CardDeck.HAND_SIZE:
		return _fail("当前轮没有抽到四张手法牌")

	var hand: Array[CardDefinition] = []
	for card_id in current_hand_ids:
		var card := catalog.find_card(card_id)
		if card == null:
			return _fail("手牌包含未知卡牌：%s" % card_id)
		hand.append(card)

	var state := RoundState.new()
	for die_index in range(1, 7):
		state.dice.append(DieState.new(
			StringName("d%d" % die_index),
			_run_rng.roll_die()
		))
	current_session = SingleEncounterSession.new(
		state,
		SingleEncounterFixture.make_encounter(),
		hand
	)
	return OperationResult.new(true)

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
```

- [x] **Step 5: Import and run synchronous tests**

Use writable import and test logs.

Expected: deterministic session test and every existing suite pass.

- [x] **Step 6: Commit the run domain**

```powershell
git add scripts/run/operation_result.gd scripts/run/operation_result.gd.uid scripts/run/three_round_encounter_session.gd scripts/run/three_round_encounter_session.gd.uid tests/three_round_encounter_session_test.gd tests/three_round_encounter_session_test.gd.uid
git commit --only -m "feat: add deterministic three round session" -- scripts/run/operation_result.gd scripts/run/operation_result.gd.uid scripts/run/three_round_encounter_session.gd scripts/run/three_round_encounter_session.gd.uid tests/three_round_encounter_session_test.gd tests/three_round_encounter_session_test.gd.uid
```

---

### Task 3: Atomic Shop Session

**Files:**
- Create: `scripts/run/shop_session.gd`
- Create: `tests/shop_session_test.gd`

**Interfaces:**
- Consumes: `CardCatalog`, a twelve-ID deck, three offer IDs, and ticket balance.
- Produces: `ShopSession.purchase(offer_id, replaced_id) -> OperationResult`, `deck_ids`, `offer_ids`, `sold_offer_ids`, `intel_tickets`, and `last_error`.

- [x] **Step 1: Write the failing shop test**

Create `tests/shop_session_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const ShopScript = preload("res://scripts/run/shop_session.gd")

func run() -> void:
	var catalog := CardCatalog.new()
	var starter := catalog.starter_ids()
	var offers := catalog.shop_ids()
	var shop = ShopScript.new(catalog, starter, offers, 2)

	var bought_id: StringName = offers[0]
	var replaced_id: StringName = starter[0]
	var success := shop.purchase(bought_id, replaced_id)
	assert_true(success.accepted, "valid replacement should succeed")
	assert_equal(shop.deck_ids.size(), 12, "purchase should preserve deck size")
	assert_true(bought_id in shop.deck_ids, "new card should enter deck")
	assert_false(replaced_id in shop.deck_ids, "replaced card should leave deck")
	assert_equal(shop.intel_tickets, 1, "purchase should cost one ticket")
	assert_true(bought_id in shop.sold_offer_ids, "bought offer should be sold")

	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase(bought_id, starter[1]),
		"sold offer should be rejected"
	)
	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase(offers[1], &"missing_card"),
		"unknown replaced card should be rejected"
	)

	var final_success := shop.purchase(offers[1], starter[1])
	assert_true(final_success.accepted, "second affordable purchase should succeed")
	assert_equal(shop.intel_tickets, 0, "two purchases should spend both tickets")
	_assert_unchanged_after_failure(
		shop,
		func() -> OperationResult: return shop.purchase(offers[2], starter[2]),
		"insufficient balance should be rejected"
	)

func _assert_unchanged_after_failure(
	shop,
	operation: Callable,
	message: String
) -> void:
	var before_deck: Array[StringName] = shop.deck_ids.duplicate()
	var before_sold: Array[StringName] = shop.sold_offer_ids.duplicate()
	var before_tickets: int = shop.intel_tickets
	var result: OperationResult = operation.call()
	assert_false(result.accepted, message)
	assert_equal(shop.deck_ids, before_deck, "%s; deck should be unchanged" % message)
	assert_equal(shop.sold_offer_ids, before_sold, "%s; offers should be unchanged" % message)
	assert_equal(shop.intel_tickets, before_tickets, "%s; tickets should be unchanged" % message)
```

- [x] **Step 2: Run and verify `ShopSession` is missing**

Run the synchronous suite with a writable log.

Expected: preload failure for `shop_session.gd`.

- [x] **Step 3: Implement atomic replacement**

Create `scripts/run/shop_session.gd`:

```gdscript
class_name ShopSession
extends RefCounted

const CARD_PRICE := 1

var catalog: CardCatalog
var deck_ids: Array[StringName] = []
var offer_ids: Array[StringName] = []
var sold_offer_ids: Array[StringName] = []
var intel_tickets: int
var last_error: String = ""

func _init(
	p_catalog: CardCatalog,
	p_deck_ids: Array[StringName],
	p_offer_ids: Array[StringName],
	p_intel_tickets: int
) -> void:
	catalog = p_catalog
	deck_ids = p_deck_ids.duplicate()
	offer_ids = p_offer_ids.duplicate()
	intel_tickets = p_intel_tickets

func purchase(offer_id: StringName, replaced_id: StringName) -> OperationResult:
	if offer_id not in offer_ids:
		return _fail("候选牌不在当前商店中")
	if offer_id in sold_offer_ids:
		return _fail("这张候选牌已经售出")
	if catalog.find_card(offer_id) == null:
		return _fail("候选牌定义不存在")
	if replaced_id not in deck_ids:
		return _fail("要替换的旧牌不在当前牌组中")
	if catalog.find_card(replaced_id) == null:
		return _fail("旧牌定义不存在")
	if intel_tickets < CARD_PRICE:
		return _fail("情报券不足")
	if offer_id in deck_ids:
		return _fail("牌组中已经存在这张候选牌")

	var next_deck: Array[StringName] = deck_ids.duplicate()
	var replace_index := next_deck.find(replaced_id)
	next_deck[replace_index] = offer_id
	if next_deck.size() != 12:
		return _fail("替换后的牌组必须保持十二张")
	var unique_ids: Dictionary = {}
	for card_id in next_deck:
		if catalog.find_card(card_id) == null:
			return _fail("替换后的牌组包含未知卡牌")
		if unique_ids.has(card_id):
			return _fail("替换后的牌组包含重复卡牌")
		unique_ids[card_id] = true

	deck_ids = next_deck
	intel_tickets -= CARD_PRICE
	sold_offer_ids.append(offer_id)
	last_error = ""
	return OperationResult.new(true)

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
```

- [x] **Step 4: Run synchronous tests**

Expected: catalog, three-round, and shop tests pass with all existing suites.

- [x] **Step 5: Commit the shop domain**

```powershell
git add scripts/run/shop_session.gd scripts/run/shop_session.gd.uid tests/shop_session_test.gd tests/shop_session_test.gd.uid
git commit --only -m "feat: add atomic deck replacement shop" -- scripts/run/shop_session.gd scripts/run/shop_session.gd.uid tests/shop_session_test.gd tests/shop_session_test.gd.uid
```

---

### Task 4: Reusable Single-Encounter Screen Adapter

**Files:**
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `tests/ui_component_contract_test.gd`
- Modify: `tests/single_encounter_layout_self_check.gd`

**Interfaces:**
- Consumes: an externally owned `SingleEncounterSession`.
- Produces: `round_committed(report)`, `bind_external_session(session, area_copy, goal_copy)`, `set_run_status(area_copy, goal_copy)`, and a real “三轮试局” scene entry.

- [x] **Step 1: Add failing adapter contracts**

Inside the existing screen block in `tests/ui_component_contract_test.gd`, add:

```gdscript
assert_true(
	screen.has_signal("round_committed"),
	"screen should report a newly committed round"
)
assert_true(
	screen.has_method("bind_external_session"),
	"screen should accept an externally owned session"
)
assert_true(
	screen.has_method("set_run_status"),
	"screen should expose run header binding"
)
```

In `tests/single_encounter_layout_self_check.gd`, resolve and check the new entry:

```gdscript
var run_trial: Control = screen.get_node("%RunTrialButton")
_assert_inside(screen.get_rect(), run_trial.get_global_rect(), "three round trial button")
```

- [x] **Step 2: Run contracts and verify the adapter is missing**

Run the synchronous suite and base layout self-check with writable logs.

Expected: method and signal assertions fail before implementation.

- [x] **Step 3: Add the adapter API and commit signal**

Add to `single_encounter_screen.gd`:

```gdscript
signal round_committed(report: ResolutionReport)

@onready var area_label: Label = %AreaLabel
@onready var goal_label: Label = %GoalLabel
@onready var replay_tutorial_button: Button = %ReplayTutorialButton
@onready var run_trial_button: Button = %RunTrialButton
```

At the end of `_ready()`:

```gdscript
run_trial_button.pressed.connect(_on_run_trial_pressed)
```

Add:

```gdscript
func bind_external_session(
	p_session: SingleEncounterSession,
	area_copy: String,
	goal_copy: String
) -> void:
	if p_session == null:
		return
	tutorial.active = false
	tutorial.visible = false
	replay_tutorial_button.visible = false
	run_trial_button.visible = false
	session = p_session
	set_run_status(area_copy, goal_copy)
	refresh_from_session()

func set_run_status(area_copy: String, goal_copy: String) -> void:
	area_label.text = area_copy
	goal_label.text = goal_copy

func show_external_error(message: String) -> void:
	session.last_error = message
	error_label.text = message

func _on_run_trial_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/three_round_run_screen.tscn")
```

Replace `_on_confirm_pressed()` with:

```gdscript
func _on_confirm_pressed() -> void:
	if not _tutorial_allows(&"commit", {}):
		return
	var was_committed := session.controller.committed
	var report := session.commit()
	if report.valid and not was_committed and session.controller.committed:
		_record_tutorial_action(&"commit", {})
	refresh_from_session()
	if report.valid and not was_committed and session.controller.committed:
		round_committed.emit(report)
```

This prevents duplicate emissions if a handler is called again after commit.

- [x] **Step 4: Add the entry button and unique header nodes**

In `single_encounter_screen.tscn`, set:

```ini
[node name="AreaLabel" type="Label" parent="SafeArea/RootColumn/TopBar"]
unique_name_in_owner = true

[node name="GoalLabel" type="Label" parent="SafeArea/RootColumn/TopBar"]
unique_name_in_owner = true
```

Add immediately after `ReplayTutorialButton`:

```ini
[node name="RunTrialButton" type="Button" parent="SafeArea/RootColumn/Body/DealerPanel/DealerCopy"]
unique_name_in_owner = true
layout_mode = 2
text = "三轮试局"
tooltip_text = "开始固定种子的三轮牌组与商店试局"
```

- [x] **Step 5: Import and run regression checks**

Run:

- synchronous tests;
- `single_encounter_layout_self_check.gd`;
- `single_encounter_input_self_check.gd`;
- `tutorial_layout_self_check.gd`;
- `tutorial_input_self_check.gd`.

Expected: adapter contract and every existing interaction path pass.

- [x] **Step 6: Commit the encounter adapter**

```powershell
git add scripts/ui/single_encounter_screen.gd scenes/run/single_encounter_screen.tscn tests/ui_component_contract_test.gd tests/single_encounter_layout_self_check.gd
git commit --only -m "feat: expose encounter run adapter" -- scripts/ui/single_encounter_screen.gd scenes/run/single_encounter_screen.tscn tests/ui_component_contract_test.gd tests/single_encounter_layout_self_check.gd
```

---

### Task 5: Round Summary Overlay

**Files:**
- Create: `scripts/ui/round_summary_panel.gd`
- Create: `scenes/components/round_summary_panel.tscn`
- Modify: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: `ThreeRoundEncounterSession` state or final deck count and remaining tickets.
- Produces: `next_round_requested`, `shop_requested`, `retry_requested`, `return_requested`, `show_run_state(session)`, `show_stage_complete(deck_ids, intel_tickets)`, and `close()`.

- [x] **Step 1: Add a failing summary component contract**

Append inside `tests/ui_component_contract_test.gd::run()`:

```gdscript
var summary_scene = load("res://scenes/components/round_summary_panel.tscn")
assert_true(summary_scene != null, "round summary scene should load")
if summary_scene != null:
	var summary = summary_scene.instantiate()
	assert_true(summary.has_method("show_run_state"), "summary should bind run state")
	assert_true(summary.has_signal("next_round_requested"), "summary should emit next round")
	assert_true(summary.has_signal("shop_requested"), "summary should emit shop entry")
	summary.free()
```

- [x] **Step 2: Run and verify the summary scene is missing**

Expected: component scene load assertion fails.

- [x] **Step 3: Create the summary controller**

Create `scripts/ui/round_summary_panel.gd`:

```gdscript
class_name RoundSummaryPanel
extends Control

signal next_round_requested
signal shop_requested
signal retry_requested
signal return_requested

@onready var title_label: Label = %SummaryTitle
@onready var detail_label: Label = %SummaryDetail
@onready var next_button: Button = %NextRoundButton
@onready var shop_button: Button = %EnterShopButton
@onready var retry_button: Button = %RetryRunButton
@onready var return_button: Button = %ReturnTeachingButton

func _ready() -> void:
	visible = false
	next_button.pressed.connect(func() -> void: next_round_requested.emit())
	shop_button.pressed.connect(func() -> void: shop_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	return_button.pressed.connect(func() -> void: return_requested.emit())

func show_run_state(run_session: ThreeRoundEncounterSession) -> void:
	visible = true
	var last_total := 0
	if not run_session.committed_reports.is_empty():
		last_total = run_session.committed_reports[-1].total
	title_label.text = _title_for_status(run_session.status)
	detail_label.text = (
		"本轮解析：%d\n累计解析：%d / %d\n目标差值：%d"
		% [
			last_total,
			run_session.cumulative_total,
			run_session.target_total,
			maxi(run_session.target_total - run_session.cumulative_total, 0),
		]
	)
	next_button.visible = run_session.status == ThreeRoundEncounterSession.Status.ROUND_SUMMARY
	shop_button.visible = run_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED
	retry_button.visible = run_session.status == ThreeRoundEncounterSession.Status.FAILED
	return_button.visible = true

func show_stage_complete(deck_ids: Array[StringName], intel_tickets: int) -> void:
	visible = true
	title_label.text = "阶段试局完成"
	detail_label.text = "最终牌组：%d 张\n剩余情报券：%d" % [
		deck_ids.size(),
		intel_tickets,
	]
	next_button.visible = false
	shop_button.visible = false
	retry_button.visible = true
	return_button.visible = true

func close() -> void:
	visible = false

func _title_for_status(status: ThreeRoundEncounterSession.Status) -> String:
	match status:
		ThreeRoundEncounterSession.Status.ROUND_SUMMARY:
			return "本轮完成"
		ThreeRoundEncounterSession.Status.SUCCEEDED:
			return "解析目标达成"
		ThreeRoundEncounterSession.Status.FAILED:
			return "解析目标未达成"
	return "轮次状态"
```

- [x] **Step 4: Create the scene-first summary overlay**

Create `scenes/components/round_summary_panel.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/round_summary_panel.gd" id="1"]

[node name="RoundSummaryPanel" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
script = ExtResource("1")

[node name="Dimmer" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
color = Color(0.01, 0.008, 0.04, 0.72)

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="PanelContainer" parent="Center"]
custom_minimum_size = Vector2(520, 310)
layout_mode = 2

[node name="Content" type="VBoxContainer" parent="Center/Panel"]
layout_mode = 2
theme_override_constants/separation = 18

[node name="SummaryTitle" type="Label" parent="Center/Panel/Content"]
unique_name_in_owner = true
layout_mode = 2
text = "本轮完成"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 30

[node name="SummaryDetail" type="Label" parent="Center/Panel/Content"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
text = ""
horizontal_alignment = 1
vertical_alignment = 1

[node name="Actions" type="HBoxContainer" parent="Center/Panel/Content"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 10

[node name="NextRoundButton" type="Button" parent="Center/Panel/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "下一轮"

[node name="EnterShopButton" type="Button" parent="Center/Panel/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "进入商店"

[node name="RetryRunButton" type="Button" parent="Center/Panel/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "同种子重试"

[node name="ReturnTeachingButton" type="Button" parent="Center/Panel/Content/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "返回教学"
```

- [x] **Step 5: Import and run the component contract**

Expected: summary scene loads and exposes its methods and signals.

- [x] **Step 6: Commit the summary component**

```powershell
git add scripts/ui/round_summary_panel.gd scripts/ui/round_summary_panel.gd.uid scenes/components/round_summary_panel.tscn tests/ui_component_contract_test.gd
git commit --only -m "feat: add round summary overlay" -- scripts/ui/round_summary_panel.gd scripts/ui/round_summary_panel.gd.uid scenes/components/round_summary_panel.tscn tests/ui_component_contract_test.gd
```

---

### Task 6: Shop Card and Shop Screen Components

**Files:**
- Create: `scripts/ui/shop/shop_card_token.gd`
- Create: `scenes/components/shop_card_token.tscn`
- Create: `scripts/ui/shop/shop_screen.gd`
- Create: `scenes/shop/shop_screen.tscn`
- Modify: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: `ShopSession` and `CardCatalog`.
- Produces: `ShopCardToken.bind_card(card, selected, disabled, role, price)`, `ShopScreen.bind_session(session, catalog)`, `leave_requested`, and real candidate/deck selection.

- [x] **Step 1: Add failing shop UI contracts**

Append inside `tests/ui_component_contract_test.gd::run()`:

```gdscript
var shop_card_scene = load("res://scenes/components/shop_card_token.tscn")
assert_true(shop_card_scene != null, "shop card token scene should load")
if shop_card_scene != null:
	var shop_card = shop_card_scene.instantiate()
	assert_true(shop_card.has_method("bind_card"), "shop card should bind card content")
	assert_true(shop_card.has_signal("card_selected"), "shop card should emit selection")
	shop_card.free()

var shop_scene = load("res://scenes/shop/shop_screen.tscn")
assert_true(shop_scene != null, "shop screen scene should load")
if shop_scene != null:
	var shop = shop_scene.instantiate()
	assert_true(shop.has_method("bind_session"), "shop screen should bind domain state")
	assert_true(shop.has_signal("leave_requested"), "shop should emit leave")
	shop.free()
```

- [x] **Step 2: Run and verify both scenes are missing**

Expected: both scene load assertions fail.

- [x] **Step 3: Create the shop card token**

Create `scripts/ui/shop/shop_card_token.gd`:

```gdscript
class_name ShopCardToken
extends Button

signal card_selected(card_id: StringName, role: StringName)

var card_id: StringName
var role: StringName

func _ready() -> void:
	pressed.connect(func() -> void: card_selected.emit(card_id, role))

func bind_card(
	card: CardDefinition,
	selected: bool,
	p_disabled: bool,
	p_role: StringName,
	price: int = -1
) -> void:
	card_id = card.id
	role = p_role
	button_pressed = selected
	disabled = p_disabled
	var price_copy := "" if price < 0 else "\n售价：%d 情报券" % price
	text = "%s\n目标：%s\n%s%s" % [
		card.display_name,
		_target_copy(card.target_type),
		card.rule_text,
		price_copy,
	]
	tooltip_text = "%s；%s" % [card.display_name, card.rule_text]
	set_meta("shop_role", role)
	set_meta("card_id", card_id)

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

Create `scenes/components/shop_card_token.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/shop/shop_card_token.gd" id="1"]

[node name="ShopCardToken" type="Button"]
custom_minimum_size = Vector2(238, 132)
toggle_mode = true
focus_mode = 1
text = "商店手法牌"
autowrap_mode = 2
script = ExtResource("1")
```

- [x] **Step 4: Create the shop screen controller**

Create `scripts/ui/shop/shop_screen.gd`:

```gdscript
class_name ShopScreen
extends Control

signal leave_requested

const CARD_SCENE = preload("res://scenes/components/shop_card_token.tscn")

@onready var deck_grid: GridContainer = %DeckGrid
@onready var offer_column: VBoxContainer = %OfferColumn
@onready var ticket_label: Label = %TicketLabel
@onready var selection_label: Label = %ShopSelectionLabel
@onready var error_label: Label = %ShopErrorLabel
@onready var confirm_button: Button = %ConfirmReplacementButton
@onready var leave_button: Button = %LeaveShopButton

var shop_session: ShopSession
var catalog: CardCatalog
var selected_offer_id: StringName = &""
var selected_deck_id: StringName = &""

func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	leave_button.pressed.connect(func() -> void: leave_requested.emit())

func bind_session(p_session: ShopSession, p_catalog: CardCatalog) -> void:
	shop_session = p_session
	catalog = p_catalog
	selected_offer_id = &""
	selected_deck_id = &""
	error_label.text = ""
	visible = true
	_refresh()

func _refresh() -> void:
	for child in deck_grid.get_children():
		child.queue_free()
	for child in offer_column.get_children():
		child.queue_free()

	for card_id in shop_session.deck_ids:
		_add_card(deck_grid, card_id, &"deck", selected_deck_id == card_id, false, -1)
	for card_id in shop_session.offer_ids:
		_add_card(
			offer_column,
			card_id,
			&"offer",
			selected_offer_id == card_id,
			card_id in shop_session.sold_offer_ids,
			ShopSession.CARD_PRICE
		)

	ticket_label.text = "情报券：%d" % shop_session.intel_tickets
	selection_label.text = "候选：%s　替换：%s" % [
		_card_name(selected_offer_id),
		_card_name(selected_deck_id),
	]
	confirm_button.disabled = selected_offer_id == &"" or selected_deck_id == &""

func _add_card(
	parent: Control,
	card_id: StringName,
	role: StringName,
	selected: bool,
	disabled: bool,
	price: int
) -> void:
	var card := catalog.find_card(card_id)
	if card == null:
		error_label.text = "卡牌定义不存在：%s" % card_id
		return
	var token: ShopCardToken = CARD_SCENE.instantiate()
	parent.add_child(token)
	token.bind_card(card, selected, disabled, role, price)
	token.card_selected.connect(_on_card_selected)

func _on_card_selected(card_id: StringName, role: StringName) -> void:
	if role == &"offer":
		selected_offer_id = card_id
	elif role == &"deck":
		selected_deck_id = card_id
	error_label.text = ""
	_refresh()

func _on_confirm_pressed() -> void:
	var result := shop_session.purchase(selected_offer_id, selected_deck_id)
	error_label.text = result.reason
	if result.accepted:
		selected_offer_id = &""
		selected_deck_id = &""
	_refresh()

func _card_name(card_id: StringName) -> String:
	if card_id == &"":
		return "未选择"
	var card := catalog.find_card(card_id)
	return "未知" if card == null else card.display_name
```

- [x] **Step 5: Create the scene-first shop layout**

Create `scenes/shop/shop_screen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/shop/shop_screen.gd" id="1"]

[node name="ShopScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.035, 0.025, 0.11, 1)

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

[node name="Header" type="HBoxContainer" parent="SafeArea/RootColumn"]
layout_mode = 2

[node name="Title" type="Label" parent="SafeArea/RootColumn/Header"]
layout_mode = 2
size_flags_horizontal = 3
text = "情报交换站"
theme_override_font_sizes/font_size = 30

[node name="TicketLabel" type="Label" parent="SafeArea/RootColumn/Header"]
unique_name_in_owner = true
layout_mode = 2
text = "情报券：2"

[node name="Body" type="HBoxContainer" parent="SafeArea/RootColumn"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 18

[node name="DeckPanel" type="PanelContainer" parent="SafeArea/RootColumn/Body"]
layout_mode = 2
size_flags_horizontal = 3

[node name="DeckColumn" type="VBoxContainer" parent="SafeArea/RootColumn/Body/DeckPanel"]
layout_mode = 2

[node name="DeckTitle" type="Label" parent="SafeArea/RootColumn/Body/DeckPanel/DeckColumn"]
layout_mode = 2
text = "当前十二张牌"
theme_override_font_sizes/font_size = 22

[node name="DeckGrid" type="GridContainer" parent="SafeArea/RootColumn/Body/DeckPanel/DeckColumn"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
columns = 4
theme_override_constants/h_separation = 8
theme_override_constants/v_separation = 8

[node name="OfferPanel" type="PanelContainer" parent="SafeArea/RootColumn/Body"]
custom_minimum_size = Vector2(320, 0)
layout_mode = 2

[node name="OfferStack" type="VBoxContainer" parent="SafeArea/RootColumn/Body/OfferPanel"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="OfferTitle" type="Label" parent="SafeArea/RootColumn/Body/OfferPanel/OfferStack"]
layout_mode = 2
text = "本次候选"
theme_override_font_sizes/font_size = 22

[node name="OfferColumn" type="VBoxContainer" parent="SafeArea/RootColumn/Body/OfferPanel/OfferStack"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 8

[node name="Footer" type="VBoxContainer" parent="SafeArea/RootColumn"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="ShopSelectionLabel" type="Label" parent="SafeArea/RootColumn/Footer"]
unique_name_in_owner = true
layout_mode = 2
text = "候选：未选择　替换：未选择"

[node name="ShopErrorLabel" type="Label" parent="SafeArea/RootColumn/Footer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 28)
layout_mode = 2
text = ""
theme_override_colors/font_color = Color(1, 0.55, 0.66, 1)

[node name="Actions" type="HBoxContainer" parent="SafeArea/RootColumn/Footer"]
layout_mode = 2
alignment = 2
theme_override_constants/separation = 10

[node name="ConfirmReplacementButton" type="Button" parent="SafeArea/RootColumn/Footer/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "确认替换（1 情报券）"

[node name="LeaveShopButton" type="Button" parent="SafeArea/RootColumn/Footer/Actions"]
unique_name_in_owner = true
layout_mode = 2
text = "离开商店"
```

- [x] **Step 6: Import and run component contracts**

Expected: both shop scenes load and expose the specified interfaces.

- [x] **Step 7: Commit shop UI components**

```powershell
git add scripts/ui/shop/shop_card_token.gd scripts/ui/shop/shop_card_token.gd.uid scenes/components/shop_card_token.tscn scripts/ui/shop/shop_screen.gd scripts/ui/shop/shop_screen.gd.uid scenes/shop/shop_screen.tscn tests/ui_component_contract_test.gd
git commit --only -m "feat: add deck replacement shop ui" -- scripts/ui/shop/shop_card_token.gd scripts/ui/shop/shop_card_token.gd.uid scenes/components/shop_card_token.tscn scripts/ui/shop/shop_screen.gd scripts/ui/shop/shop_screen.gd.uid scenes/shop/shop_screen.tscn tests/ui_component_contract_test.gd
```

---

### Task 7: Three-Round Run Orchestration Scene

**Files:**
- Create: `scripts/ui/three_round_run_screen.gd`
- Create: `scenes/run/three_round_run_screen.tscn`
- Modify: `tests/ui_component_contract_test.gd`

**Interfaces:**
- Consumes: `ThreeRoundEncounterSession`, injected `SingleEncounterScreen`, `RoundSummaryPanel`, `ShopSession`, and `ShopScreen`.
- Produces: a playable `three_round_run_screen.tscn`, `start_run()`, `open_shop()`, retry, return, and stage completion flow.

- [x] **Step 1: Add a failing run-screen contract**

Append inside `tests/ui_component_contract_test.gd::run()`:

```gdscript
var three_round_scene = load("res://scenes/run/three_round_run_screen.tscn")
assert_true(three_round_scene != null, "three round run scene should load")
if three_round_scene != null:
	var three_round = three_round_scene.instantiate()
	assert_true(three_round.has_method("start_run"), "run screen should start a session")
	assert_true(three_round.has_method("open_shop"), "run screen should expose shop transition")
	three_round.free()
```

- [x] **Step 2: Run and verify the run scene is missing**

Expected: run scene load assertion fails.

- [x] **Step 3: Implement the run orchestrator**

Create `scripts/ui/three_round_run_screen.gd`:

```gdscript
class_name ThreeRoundRunScreen
extends Control

@export var run_seed: int = ThreeRoundEncounterSession.DEFAULT_SEED
@export var run_target: int = ThreeRoundEncounterSession.DEFAULT_TARGET

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var summary_panel: RoundSummaryPanel = %RoundSummaryPanel
@onready var shop_screen: ShopScreen = %ShopScreen

var catalog := CardCatalog.new()
var run_session: ThreeRoundEncounterSession
var shop_session: ShopSession

func _ready() -> void:
	encounter_screen.round_committed.connect(_on_round_committed)
	summary_panel.next_round_requested.connect(_on_next_round_requested)
	summary_panel.shop_requested.connect(open_shop)
	summary_panel.retry_requested.connect(_on_retry_requested)
	summary_panel.return_requested.connect(_on_return_requested)
	shop_screen.leave_requested.connect(_on_shop_leave_requested)
	start_run()

func start_run() -> void:
	run_session = ThreeRoundEncounterSession.new(catalog, run_seed, run_target)
	var result := run_session.start()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	_bind_current_round()

func open_shop() -> void:
	if run_session.status != ThreeRoundEncounterSession.Status.SUCCEEDED:
		encounter_screen.show_external_error("只有达成三轮目标后才能进入商店")
		return
	shop_session = ShopSession.new(
		catalog,
		run_session.starter_deck_ids,
		run_session.shop_offer_ids,
		run_session.intel_tickets
	)
	summary_panel.close()
	encounter_screen.visible = false
	shop_screen.bind_session(shop_session, catalog)

func _bind_current_round() -> void:
	encounter_screen.visible = true
	shop_screen.visible = false
	summary_panel.close()
	encounter_screen.bind_external_session(
		run_session.current_session,
		"三轮试局 · 种子 %d" % run_session.seed_value,
		"累计：%d / %d　轮次 %d / 3　情报券：%d" % [
			run_session.cumulative_total,
			run_session.target_total,
			run_session.current_round,
			run_session.intel_tickets,
		]
	)

func _on_round_committed(report: ResolutionReport) -> void:
	var result := run_session.accept_committed_report(report)
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	encounter_screen.set_run_status(
		"三轮试局 · 种子 %d" % run_session.seed_value,
		"累计：%d / %d　轮次 %d / 3　情报券：%d" % [
			run_session.cumulative_total,
			run_session.target_total,
			run_session.current_round,
			run_session.intel_tickets,
		]
	)
	summary_panel.show_run_state(run_session)

func _on_next_round_requested() -> void:
	var result := run_session.advance_round()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	_bind_current_round()

func _on_shop_leave_requested() -> void:
	shop_screen.visible = false
	summary_panel.show_stage_complete(
		shop_session.deck_ids,
		shop_session.intel_tickets
	)

func _on_retry_requested() -> void:
	get_tree().reload_current_scene()

func _on_return_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/run/single_encounter_screen.tscn")
```

- [x] **Step 4: Create the scene-first orchestration scene**

Create `scenes/run/three_round_run_screen.tscn`:

```ini
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/ui/three_round_run_screen.gd" id="1"]
[ext_resource type="Theme" path="res://resources/themes/neon_dream_theme.tres" id="2"]
[ext_resource type="PackedScene" path="res://scenes/run/single_encounter_screen.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/components/round_summary_panel.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/shop/shop_screen.tscn" id="5"]

[node name="ThreeRoundRunScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("2")
script = ExtResource("1")

[node name="EncounterScreen" parent="." instance=ExtResource("3")]
unique_name_in_owner = true
layout_mode = 1
tutorial_auto_start = false

[node name="ShopScreen" parent="." instance=ExtResource("5")]
unique_name_in_owner = true
layout_mode = 1

[node name="RoundSummaryPanel" parent="." instance=ExtResource("4")]
unique_name_in_owner = true
layout_mode = 1
```

- [x] **Step 5: Import and run component and synchronous checks**

Expected: run scene loads; all synchronous suites pass without script errors.

- [x] **Step 6: Commit run orchestration**

```powershell
git add scripts/ui/three_round_run_screen.gd scripts/ui/three_round_run_screen.gd.uid scenes/run/three_round_run_screen.tscn tests/ui_component_contract_test.gd
git commit --only -m "feat: connect three round run and shop" -- scripts/ui/three_round_run_screen.gd scripts/ui/three_round_run_screen.gd.uid scenes/run/three_round_run_screen.tscn tests/ui_component_contract_test.gd
```

---

### Task 8: Three-Round Layout and Real-Input Checks

**Files:**
- Create: `tests/three_round_layout_self_check.gd`
- Create: `tests/three_round_input_self_check.gd`

**Interfaces:**
- Consumes: the real three-round scene, summary overlay, shop screen, `Window.push_input()`, and target override `0` for a deterministic zero-score success path.
- Produces: layout proof for encounter/summary/shop and real-input proof for entry, three commits, two transitions, shop entry, atomic replacement, and stage completion.

- [x] **Step 1: Create the layout self-check**

Create `tests/three_round_layout_self_check.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var run_screen: ThreeRoundRunScreen = load(
		"res://scenes/run/three_round_run_screen.tscn"
	).instantiate()
	run_screen.run_target = 0
	root.add_child(run_screen)
	await process_frame
	await process_frame
	await process_frame

	var encounter: Control = run_screen.get_node("%EncounterScreen")
	var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
	var shop: ShopScreen = run_screen.get_node("%ShopScreen")
	_assert_inside(run_screen.get_rect(), encounter.get_global_rect(), "encounter screen")

	var report := run_screen.run_session.current_session.commit()
	run_screen.run_session.accept_committed_report(report)
	summary.show_run_state(run_screen.run_session)
	await process_frame
	_assert_inside(run_screen.get_rect(), summary.get_global_rect(), "round summary")
	_assert_inside(
		run_screen.get_rect(),
		summary.get_node("%SummaryTitle").get_global_rect(),
		"summary title"
	)

	summary.close()
	for round_number in range(2, 4):
		run_screen.run_session.advance_round()
		report = run_screen.run_session.current_session.commit()
		run_screen.run_session.accept_committed_report(report)
	run_screen.open_shop()
	await process_frame
	await process_frame
	_assert_inside(run_screen.get_rect(), shop.get_global_rect(), "shop screen")
	_assert_inside(
		run_screen.get_rect(),
		shop.get_node("%DeckGrid").get_global_rect(),
		"shop deck grid"
	)
	_assert_inside(
		run_screen.get_rect(),
		shop.get_node("%OfferColumn").get_global_rect(),
		"shop offer column"
	)
	_assert_true(
		shop.get_node("%DeckGrid").get_child_count() == 12,
		"shop should display twelve deck cards"
	)
	_assert_true(
		shop.get_node("%OfferColumn").get_child_count() == 3,
		"shop should display three offers"
	)

	run_screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS three_round_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(parent_rect.encloses(child_rect), "%s must remain inside root" % label)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
```

- [x] **Step 2: Run the layout check and fix only measured geometry failures**

```powershell
$layoutLog = Join-Path $env:TEMP 'project-joker-stage4-layout.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $layoutLog -s res://tests/three_round_layout_self_check.gd
```

Expected: encounter, summary, twelve deck cards, and three offers remain inside 1920×1080. If the measured shop grid exceeds the root, reduce `ShopCardToken.custom_minimum_size` before changing the scene hierarchy.

- [x] **Step 3: Create the full real-input self-check**

Create `tests/three_round_input_self_check.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []
var pointer_position := Vector2.ZERO
var run_screen: ThreeRoundRunScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var teaching: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	teaching.tutorial_auto_start = false
	root.add_child(teaching)
	current_scene = teaching
	await process_frame
	await process_frame

	await _click(teaching.get_node("%RunTrialButton"))
	await process_frame
	await process_frame
	await process_frame
	run_screen = current_scene as ThreeRoundRunScreen
	_assert_true(run_screen != null, "real entry click should open three round scene")
	if run_screen == null:
		await _finish()
		return
	run_screen.run_session.target_total = 0

	for round_number in range(1, 4):
		var encounter: SingleEncounterScreen = run_screen.get_node("%EncounterScreen")
		await _click(encounter.get_node("%ConfirmButton"))
		var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
		_assert_true(summary.visible, "commit should open the round summary")
		if round_number < 3:
			_assert_true(
				run_screen.run_session.status == ThreeRoundEncounterSession.Status.ROUND_SUMMARY,
				"early commit should stop at summary"
			)
			await _click(summary.get_node("%NextRoundButton"))
			_assert_true(
				run_screen.run_session.current_round == round_number + 1,
				"next-round click should advance exactly once"
			)

	var summary: RoundSummaryPanel = run_screen.get_node("%RoundSummaryPanel")
	_assert_true(
		run_screen.run_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED,
		"zero target should succeed after round three"
	)
	await _click(summary.get_node("%EnterShopButton"))
	var shop: ShopScreen = run_screen.get_node("%ShopScreen")
	_assert_true(shop.visible, "shop entry click should display shop")

	var offer := _find_shop_card(&"offer")
	_assert_true(offer != null, "shop offer target should exist")
	if offer != null:
		var bought_id: StringName = offer.card_id
		await _click(offer)
		var deck_card := _find_shop_card(&"deck")
		_assert_true(deck_card != null, "shop deck target should exist")
		if deck_card != null:
			var replaced_id: StringName = deck_card.card_id
			await _click(deck_card)
			await _click(shop.get_node("%ConfirmReplacementButton"))
			_assert_true(bought_id in run_screen.shop_session.deck_ids, "bought card should enter deck")
			_assert_true(replaced_id not in run_screen.shop_session.deck_ids, "old card should leave deck")
			_assert_true(run_screen.shop_session.deck_ids.size() == 12, "deck should stay at twelve")
			_assert_true(run_screen.shop_session.intel_tickets == 1, "purchase should cost one ticket")

	await _click(shop.get_node("%LeaveShopButton"))
	_assert_true(summary.visible, "leaving shop should show stage completion")
	_assert_true(
		summary.get_node("%SummaryTitle").text == "阶段试局完成",
		"completion summary should use concrete Chinese copy"
	)
	await _finish()

func _find_shop_card(role: StringName) -> ShopCardToken:
	for node in run_screen.find_children("*", "Button", true, false):
		if (
			node is ShopCardToken
			and not node.is_queued_for_deletion()
			and not node.disabled
			and node.role == role
		):
			return node
	return null

func _click(control: Control) -> void:
	_assert_true(control != null, "click target should exist")
	if control == null:
		return
	await _click_at_point(control.get_global_rect().get_center())

func _click_at_point(point: Vector2) -> void:
	await _move_pointer(point)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release, true)
	await process_frame

func _move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = point - pointer_position
	root.push_input(motion, true)
	pointer_position = point
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	if run_screen != null:
		run_screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS three_round_input_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
```

- [x] **Step 4: Import and run the real-input check**

```powershell
$importLog = Join-Path $env:TEMP 'project-joker-stage4-input-import.log'
$inputLog = Join-Path $env:TEMP 'project-joker-stage4-input.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $importLog --import
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $inputLog -s res://tests/three_round_input_self_check.gd
```

Expected: `PASS three_round_input_self_check`; no script errors.

- [x] **Step 5: Run the real-input check three consecutive times**

```powershell
for ($i = 1; $i -le 3; $i++) {
    $log = Join-Path $env:TEMP ("project-joker-stage4-input-stability-{0}.log" -f $i)
    & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $log -s res://tests/three_round_input_self_check.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Failed to load script') { exit 1 }
}
```

Expected: three passes.

- [x] **Step 6: Commit layout and input checks**

```powershell
git add tests/three_round_layout_self_check.gd tests/three_round_layout_self_check.gd.uid tests/three_round_input_self_check.gd tests/three_round_input_self_check.gd.uid
git commit --only -m "test: verify three round run interaction" -- tests/three_round_layout_self_check.gd tests/three_round_layout_self_check.gd.uid tests/three_round_input_self_check.gd tests/three_round_input_self_check.gd.uid
```

---

### Task 9: Full Acceptance and Documentation State

**Files:**
- Modify: `docs/superpowers/plans/2026-07-26-three-round-deck-shop.md`

**Interfaces:**
- Consumes: all completed Stage 4 code, generated resources, scenes, and checks.
- Produces: verified three-round/shop slice, completed plan checkboxes, and exactly the Stage 4 design/plan documents staged alongside the preserved unstaged `project.godot`.

- [x] **Step 1: Run complete automated acceptance**

```powershell
$logs = [ordered]@{
    import = Join-Path $env:TEMP 'project-joker-stage4-accept-import.log'
    core = Join-Path $env:TEMP 'project-joker-stage4-accept-core.log'
    base_layout = Join-Path $env:TEMP 'project-joker-stage4-accept-base-layout.log'
    tutorial_layout = Join-Path $env:TEMP 'project-joker-stage4-accept-tutorial-layout.log'
    run_layout = Join-Path $env:TEMP 'project-joker-stage4-accept-run-layout.log'
    base_input = Join-Path $env:TEMP 'project-joker-stage4-accept-base-input.log'
    tutorial_input = Join-Path $env:TEMP 'project-joker-stage4-accept-tutorial-input.log'
    run_input = Join-Path $env:TEMP 'project-joker-stage4-accept-run-input.log'
    main = Join-Path $env:TEMP 'project-joker-stage4-accept-main.log'
}

& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.import --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.core -s res://tests/run_all.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.base_layout -s res://tests/single_encounter_layout_self_check.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.tutorial_layout -s res://tests/tutorial_layout_self_check.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.run_layout -s res://tests/three_round_layout_self_check.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.base_input -s res://tests/single_encounter_input_self_check.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.tutorial_input -s res://tests/tutorial_input_self_check.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.run_input -s res://tests/three_round_input_self_check.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $logs.main --quit-after 2
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$paths = [string[]]$logs.Values
$bad = Select-String -LiteralPath $paths -Pattern 'SCRIPT ERROR|Failed to load script'
if ($bad) {
    $bad
    exit 1
}
Write-Output 'STAGE4_ACCEPTANCE_PASS=9/9'
```

Expected: all nine commands exit `0`; every suite/self-check passes; log scan is clean.

- [x] **Step 2: Run visible smoke verification**

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64.exe' --path . res://scenes/run/three_round_run_screen.tscn
```

Verify:

- three-round status copy is readable at 1280×720 and 1920×1080;
- four hand cards show name, target, and full Chinese rule text;
- summary blocks the encounter and exposes only valid actions;
- shop shows twelve old cards, three candidates, two tickets, and concrete selection copy;
- one replacement updates deck and ticket count immediately;
- no betting, chips, loans, real-money copy, or probability-trigger language appears.

- [x] **Step 3: Mark the plan complete and stage only Stage 4 documents**

Change every completed `- [x]` in this document to `- [x]`, then run:

```powershell
git add docs/superpowers/specs/2026-07-26-three-round-deck-shop-design.md docs/superpowers/plans/2026-07-26-three-round-deck-shop.md
git status --short
```

Expected:

```text
A  docs/superpowers/plans/2026-07-26-three-round-deck-shop.md
A  docs/superpowers/specs/2026-07-26-three-round-deck-shop-design.md
 M project.godot
```

No code, scene, resource, test, or tool file remains uncommitted.

## Exit Checklist

- [x] Fifteen resource-backed cards load and validate.
- [x] Starter and shop IDs are unique and non-overlapping.
- [x] The teaching hand and tutorial flow remain unchanged.
- [x] Same seed reproduces dice, hands, and offer order.
- [x] Three rounds expose all twelve starter cards exactly once.
- [x] Round reports can be accumulated only once.
- [x] Cumulative total comes only from committed reports.
- [x] Target `100` and reward `2` are visible and domain-owned.
- [x] Shop replacement is atomic and preserves twelve cards.
- [x] Insufficient balance and invalid IDs leave state unchanged.
- [x] Summary overlay blocks encounter input.
- [x] Shop selection uses real card IDs and real mouse input.
- [x] Existing base and tutorial regression checks pass.
- [x] New run layout and input checks pass repeatedly.
- [x] All headless logs are free of script load and compile errors.
- [x] Stage 4 design and plan documents remain staged and uncommitted.
- [x] The pre-existing `project.godot` modification remains unstaged and untouched.
