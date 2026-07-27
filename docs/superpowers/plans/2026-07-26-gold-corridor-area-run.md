# Gold Corridor Complete Area Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the complete playable Gold Corridor area with two public route choices, two three-round normal rooms, two meaningful replacement shops, Iron Abacus, engraving installation, and a final area summary.

**Architecture:** Add a reusable `AreaRunSession` that composes the existing encounter, shop, dealer, engraving, RNG, and resolver services without replacing the verified `IronAbacusSliceSession`. Fixed `RoomDefinition` resources provide the four Gold Corridor rooms. A scene-backed `GoldCorridorRunScreen` switches existing gameplay panels plus new route-choice and area-summary components while all authoritative state remains in the domain session.

**Tech Stack:** Godot 4.6.1, typed GDScript, custom `.tres` resources, `.tscn` scene composition, dependency-free Godot test suites, `Window.push_input()` interaction checks, and dual-resolution visual acceptance.

## Global Constraints

- Work directly on `master`; do not create or switch branches.
- Keep every design and implementation-plan document staged and uncommitted.
- Commit code with `git commit --only` and explicit code paths so staged documents remain excluded.
- Preserve the existing unstaged `project.godot`; do not edit, stage, commit, or discard it.
- Do not push any commit to a remote unless the user explicitly authorizes exporting that exact payload.
- Use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe`.
- Every headless Godot command must pass `--log-file` to a writable path under `$env:TEMP`.
- Treat a nonzero exit, `SCRIPT ERROR`, or `Failed to load script` as failure even when Godot prints other expected sandbox warnings.
- In every task that creates a `.gd`, run a headless editor import before the green test and commit its generated `.gd.uid` beside the script.
- Preserve the base tutorial path `44→51→44→51`.
- Preserve the existing Iron Abacus prototype, engraving verification room, five-checkpoint advanced guide, and their regression entry points.
- Keep preview and formal commit on the same `RoundResolver` path.
- Use stable content IDs across sessions; never store scene node paths as gameplay IDs.
- Keep stable hierarchy and copy containers in `.tscn`; scripts bind data, refresh state, and forward signals.
- Do not add autoloads, external packages, cross-launch saves, probabilistic effects, or gambling-oriented mechanics and copy.

---

## Planned File Map

```text
res://
  resources/
    cards/stage6/
      shop_amplified_chain.tres
      shop_deep_drop.tres
      shop_reverse_backup.tres
    rooms/gold_corridor/
      even_split.tres
      narrow_ledger.tres
      parallel_proof.tres
      precise_steps.tres
  scenes/
    components/
      area_complete_panel.tscn
      route_choice_panel.tscn
    run/
      gold_corridor_run_screen.tscn
  scripts/
    engravings/
      engraving_installation_service.gd
    rooms/
      gold_corridor_catalog.gd
      room_definition.gd
    run/
      area_run_session.gd
      shop_purchase_record.gd
      shop_session.gd
    ui/
      area_complete_panel.gd
      gold_corridor_run_screen.gd
      route_choice_panel.gd
  tests/
    engraving_installation_service_test.gd
    gold_corridor_area_run_test.gd
    gold_corridor_catalog_test.gd
    gold_corridor_input_self_check.gd
    gold_corridor_layout_self_check.gd
    gold_corridor_ui_contract_test.gd
```

Every new `.gd` in this map also produces a tracked sibling `.gd.uid`.

Existing files modified across the tasks:

```text
scripts/cards/card_catalog.gd
scripts/run/iron_abacus_slice_session.gd
scripts/ui/round_summary_panel.gd
scripts/ui/single_encounter_screen.gd
scripts/validation/content_validator.gd
scenes/components/round_summary_panel.tscn
scenes/run/single_encounter_screen.tscn
tests/iron_abacus_slice_session_test.gd
tests/run_all.gd
tests/shop_session_test.gd
tests/stage4_card_catalog_test.gd
tests/stage5_guide_input_self_check.gd
tests/stage5_input_self_check.gd
```

## Task 1: Add Gold Corridor Room Resources and Validation

**Files:**

- Create: `scripts/rooms/room_definition.gd`
- Create: `scripts/rooms/gold_corridor_catalog.gd`
- Create: `resources/rooms/gold_corridor/precise_steps.tres`
- Create: `resources/rooms/gold_corridor/even_split.tres`
- Create: `resources/rooms/gold_corridor/narrow_ledger.tres`
- Create: `resources/rooms/gold_corridor/parallel_proof.tres`
- Modify: `scripts/validation/content_validator.gd`
- Create: `tests/gold_corridor_catalog_test.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**

- Produces: `RoomDefinition`
- Produces: `ContentValidator.validate_rooms(rooms: Array) -> Array[String]`
- Produces: `GoldCorridorCatalog.first_route_ids() -> Array[StringName]`
- Produces: `GoldCorridorCatalog.second_route_ids() -> Array[StringName]`
- Produces: `GoldCorridorCatalog.find_room(room_id: StringName) -> RoomDefinition`
- Produces: `GoldCorridorCatalog.all_rooms() -> Array[RoomDefinition]`
- Produces: `GoldCorridorCatalog.validate() -> Array[String]`

- [x] **Step 1: Register a failing room-catalog test**

Add the suite to `tests/run_all.gd`, then create assertions for exact IDs, grouping,
room values, six total slots, and nonempty display fields:

```gdscript
class_name GoldCorridorCatalogTest
extends TestCase

func run() -> void:
	var catalog := GoldCorridorCatalog.new()
	assert_equal(catalog.validate(), [], "Gold Corridor content should validate")
	assert_equal(
		catalog.first_route_ids(),
		[&"gold_room_precise_steps", &"gold_room_even_split"],
		"first route group should be fixed"
	)
	assert_equal(
		catalog.second_route_ids(),
		[&"gold_room_narrow_ledger", &"gold_room_parallel_proof"],
		"second route group should be fixed"
	)
	assert_equal(catalog.all_rooms().size(), 4, "catalog should contain four rooms")
	for room in catalog.all_rooms():
		assert_equal(room.encounter.rules.size(), 3, "%s should have three lanes" % room.id)
		var slot_total := 0
		for rule in room.encounter.rules:
			slot_total += rule.slot_count
		assert_equal(slot_total, 6, "%s should expose six slots" % room.id)
		assert_true(not room.synergy_tags.is_empty(), "%s should have synergy tags" % room.id)
```

- [x] **Step 2: Run the suite and verify the new classes are missing**

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-rooms-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  -s res://tests/run_all.gd
```

Expected: nonzero exit or a failing `gold_corridor_catalog_test.gd` because
`RoomDefinition` and `GoldCorridorCatalog` do not exist.

- [x] **Step 3: Implement the room resource type**

```gdscript
class_name RoomDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var encounter: EncounterDefinition
@export var target_total: int
@export var success_intel_reward: int
@export var tags: PackedStringArray = []
@export var synergy_tags: PackedStringArray = []
```

- [x] **Step 4: Add centralized room validation**

Append `validate_rooms()` to `ContentValidator`. It must reject null rooms,
duplicate or empty room IDs, empty copy, nonpositive targets, negative rewards,
missing tags, missing synergy tags, missing encounters, non-three-lane rooms,
non-six-slot rooms, and invalid lane definitions.

```gdscript
func validate_rooms(rooms: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for room in rooms:
		if room == null:
			errors.append("room resource is null")
			continue
		if room.id == &"":
			errors.append("room ID is empty")
		elif seen.has(room.id):
			errors.append("duplicate room ID: %s" % room.id)
		else:
			seen[room.id] = true
		if room.display_name.strip_edges().is_empty():
			errors.append("room %s has no display name" % room.id)
		if room.description.strip_edges().is_empty():
			errors.append("room %s has no description" % room.id)
		if room.target_total <= 0:
			errors.append("room %s target must be positive" % room.id)
		if room.success_intel_reward < 0:
			errors.append("room %s reward cannot be negative" % room.id)
		if room.tags.is_empty():
			errors.append("room %s has no display tags" % room.id)
		if room.synergy_tags.is_empty():
			errors.append("room %s has no synergy tags" % room.id)
		if room.encounter == null:
			errors.append("room %s has no encounter" % room.id)
			continue
		if room.encounter.rules.size() != 3:
			errors.append("room %s must contain exactly three rules" % room.id)
		var slot_total := 0
		for rule in room.encounter.rules:
			slot_total += rule.slot_count
		if slot_total != 6:
			errors.append("room %s must contain exactly six slots" % room.id)
		errors.append_array(validate(room.encounter.rules, []))
	return errors
```

- [x] **Step 5: Create the four exact room resources**

Each `.tres` embeds one `RoomDefinition`, one `EncounterDefinition`, and three
`RuleDefinition` subresources. Use stable spatial rule IDs `left`, `middle`,
and `right`. Populate the exact values below:

| Resource | Room ID | Rules `(condition, slots, coefficient, target)` | Target | Reward | Tags | Synergy tags |
|---|---|---|---:|---:|---|---|
| `precise_steps.tres` | `gold_room_precise_steps` | `(EXACT_SUM,2,2,7)`, `(CONSECUTIVE,3,2,0)`, `(ALL_EVEN,1,3,0)` | 100 | 2 | 点数, 连续, 稳妥 | 骰值, 校准, 重复 |
| `even_split.tres` | `gold_room_even_split` | `(ALL_EVEN,2,3,0)`, `(EXACT_SUM,2,2,9)`, `(CONSECUTIVE,2,2,0)` | 110 | 3 | 奇偶, 关系, 进取 | 骰值, 校准, 系数 |
| `narrow_ledger.tres` | `gold_room_narrow_ledger` | `(EXACT_SUM,2,3,10)`, `(CONSECUTIVE,3,2,0)`, `(ALL_EVEN,1,3,0)` | 120 | 2 | 点数, 连续, 稳妥 | 骰值, 校准, 重复 |
| `parallel_proof.tres` | `gold_room_parallel_proof` | `(ALL_EVEN,2,3,0)`, `(EXACT_SUM,2,3,8)`, `(CONSECUTIVE,2,3,0)` | 135 | 3 | 奇偶, 关系, 进取 | 骰值, 校准, 系数 |

Use the Chinese lane names from the approved design:

```text
精确为 7
连续三数
单枚偶数
两枚全偶
精确为 9
连续两数
精确为 10
精确为 8
```

- [x] **Step 6: Implement the explicit catalog**

```gdscript
class_name GoldCorridorCatalog
extends RefCounted

const FIRST_ROUTE_IDS: Array[StringName] = [
	&"gold_room_precise_steps",
	&"gold_room_even_split",
]
const SECOND_ROUTE_IDS: Array[StringName] = [
	&"gold_room_narrow_ledger",
	&"gold_room_parallel_proof",
]

const ROOM_PATHS := [
	"res://resources/rooms/gold_corridor/precise_steps.tres",
	"res://resources/rooms/gold_corridor/even_split.tres",
	"res://resources/rooms/gold_corridor/narrow_ledger.tres",
	"res://resources/rooms/gold_corridor/parallel_proof.tres",
]

var _rooms_by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	for path in ROOM_PATHS:
		var resource := load(path)
		if not resource is RoomDefinition:
			_load_errors.append("failed to load room resource: %s" % path)
			continue
		var room := resource as RoomDefinition
		if _rooms_by_id.has(room.id):
			_load_errors.append("duplicate room ID: %s" % room.id)
		else:
			_rooms_by_id[room.id] = room

func first_route_ids() -> Array[StringName]:
	return FIRST_ROUTE_IDS.duplicate()

func second_route_ids() -> Array[StringName]:
	return SECOND_ROUTE_IDS.duplicate()

func find_room(room_id: StringName) -> RoomDefinition:
	return _rooms_by_id.get(room_id) as RoomDefinition

func all_rooms() -> Array[RoomDefinition]:
	var result: Array[RoomDefinition] = []
	for room_id in FIRST_ROUTE_IDS + SECOND_ROUTE_IDS:
		var room := find_room(room_id)
		if room != null:
			result.append(room)
	return result

func validate() -> Array[String]:
	var errors := _load_errors.duplicate()
	errors.append_array(ContentValidator.new().validate_rooms(all_rooms()))
	if all_rooms().size() != 4:
		errors.append("Gold Corridor catalog must contain exactly four rooms")
	return errors
```

- [x] **Step 7: Import new scripts, run synchronous tests, and inspect the log**

Run a headless editor import with
`$env:TEMP\project-joker-gold-rooms-import.log`, verify the three new `.gd.uid`
files exist, then run `tests/run_all.gd` with
`$env:TEMP\project-joker-gold-rooms-green.log`. Confirm the new suite passes,
then scan:

```powershell
Select-String `
  -LiteralPath "$env:TEMP\project-joker-gold-rooms-green.log" `
  -Pattern "SCRIPT ERROR|Failed to load script"
```

Expected: zero matches.

- [x] **Step 8: Run whitespace validation**

```powershell
git diff --check
git diff --cached --check
```

- [x] **Step 9: Commit only room content and tests**

```powershell
git add -- `
  scripts/rooms/room_definition.gd `
  scripts/rooms/room_definition.gd.uid `
  scripts/rooms/gold_corridor_catalog.gd `
  scripts/rooms/gold_corridor_catalog.gd.uid `
  scripts/validation/content_validator.gd `
  resources/rooms/gold_corridor/precise_steps.tres `
  resources/rooms/gold_corridor/even_split.tres `
  resources/rooms/gold_corridor/narrow_ledger.tres `
  resources/rooms/gold_corridor/parallel_proof.tres `
  tests/gold_corridor_catalog_test.gd `
  tests/gold_corridor_catalog_test.gd.uid `
  tests/run_all.gd

git commit --only -m "feat: add gold corridor room content" -- `
  scripts/rooms/room_definition.gd `
  scripts/rooms/room_definition.gd.uid `
  scripts/rooms/gold_corridor_catalog.gd `
  scripts/rooms/gold_corridor_catalog.gd.uid `
  scripts/validation/content_validator.gd `
  resources/rooms/gold_corridor/precise_steps.tres `
  resources/rooms/gold_corridor/even_split.tres `
  resources/rooms/gold_corridor/narrow_ledger.tres `
  resources/rooms/gold_corridor/parallel_proof.tres `
  tests/gold_corridor_catalog_test.gd `
  tests/gold_corridor_catalog_test.gd.uid `
  tests/run_all.gd
```

## Task 2: Expand the Shop Pool and Record Atomic Replacements

**Files:**

- Create: `resources/cards/stage6/shop_deep_drop.tres`
- Create: `resources/cards/stage6/shop_amplified_chain.tres`
- Create: `resources/cards/stage6/shop_reverse_backup.tres`
- Create: `scripts/run/shop_purchase_record.gd`
- Modify: `scripts/cards/card_catalog.gd`
- Modify: `scripts/run/shop_session.gd`
- Modify: `tests/stage4_card_catalog_test.gd`
- Modify: `tests/shop_session_test.gd`

**Interfaces:**

- Produces: `CardCatalog.shop_ids()` containing exactly six stable IDs
- Produces: `ShopPurchaseRecord.new(offer_id, replaced_id, price)`
- Produces: `ShopPurchaseRecord.clone() -> ShopPurchaseRecord`
- Produces: `ShopSession.purchase_records: Array[ShopPurchaseRecord]`
- Consumes: existing `ShopSession.purchase(offer_id, replaced_id) -> OperationResult`

- [x] **Step 1: Extend tests before changing production**

In `stage4_card_catalog_test.gd`, change the expected complete content count
from 15 to 18 and shop-pool count from 3 to 6. Assert exact new definitions:

```gdscript
var deep_drop := catalog.find_card(&"shop_deep_drop")
assert_equal(deep_drop.target_type, CardDefinition.TargetType.DIE)
assert_equal(deep_drop.effects[0].operation, EffectSpec.Operation.ADJUST_DIE)
assert_equal(deep_drop.effects[0].amount, -3)

var amplified := catalog.find_card(&"shop_amplified_chain")
assert_equal(amplified.target_type, CardDefinition.TargetType.TABLE)
assert_equal(amplified.effects.size(), 2)
assert_equal(amplified.effects[0].operation, EffectSpec.Operation.MODIFY_COEFFICIENT)
assert_equal(amplified.effects[0].amount, 2)
assert_equal(amplified.effects[1].operation, EffectSpec.Operation.REPEAT_TABLE)
assert_equal(amplified.effects[1].amount, 1)

var reverse_backup := catalog.find_card(&"shop_reverse_backup")
assert_equal(reverse_backup.target_type, CardDefinition.TargetType.GLOBAL)
assert_equal(reverse_backup.effects[0].operation, EffectSpec.Operation.REVERSE_RESOLUTION)
```

In `shop_session_test.gd`, assert a successful purchase creates one detached
value record and every failed purchase leaves the record count unchanged:

```gdscript
var result := session.purchase(offer_id, replaced_id)
assert_true(result.accepted)
assert_equal(session.purchase_records.size(), 1)
assert_equal(session.purchase_records[0].offer_id, offer_id)
assert_equal(session.purchase_records[0].replaced_id, replaced_id)
assert_equal(session.purchase_records[0].price, ShopSession.CARD_PRICE)
```

- [x] **Step 2: Run `tests/run_all.gd` and confirm the new assertions fail**

Use `$env:TEMP\project-joker-shop-expansion-red.log`.

Expected: catalog count and purchase-record assertions fail.

- [x] **Step 3: Create the three card resources**

Use these exact definitions:

```text
shop_deep_drop
  display_name: 深降推码
  rule_text: 令一颗骰子的点数 -3，最终点数限制在 1..6。
  tags: 商店, 骰值
  target_type: DIE
  effect: ADJUST_DIE -3

shop_amplified_chain
  display_name: 增幅连写
  rule_text: 令一张规则台的系数 +2，并额外结算 1 次。
  tags: 商店, 规则台, 联动
  target_type: TABLE
  effects: MODIFY_COEFFICIENT +2; REPEAT_TABLE +1

shop_reverse_backup
  display_name: 回转备份
  rule_text: 反转本轮规则台的解析顺序。
  tags: 商店, 全局, 顺序
  target_type: GLOBAL
  effect: REVERSE_RESOLUTION 0
```

- [x] **Step 4: Add all three paths to `CardCatalog`**

Append the stage-six paths to `SHOP_PATHS` and change validation to require
exactly six shop cards:

```gdscript
const SHOP_PATHS := [
	"res://resources/cards/stage4/shop_precision_map.tres",
	"res://resources/cards/stage4/shop_triple_repeat.tres",
	"res://resources/cards/stage4/shop_long_push.tres",
	"res://resources/cards/stage6/shop_deep_drop.tres",
	"res://resources/cards/stage6/shop_amplified_chain.tres",
	"res://resources/cards/stage6/shop_reverse_backup.tres",
]
```

- [x] **Step 5: Add the focused purchase-record value object**

```gdscript
class_name ShopPurchaseRecord
extends RefCounted

var offer_id: StringName
var replaced_id: StringName
var price: int

func _init(
	p_offer_id: StringName,
	p_replaced_id: StringName,
	p_price: int
) -> void:
	offer_id = p_offer_id
	replaced_id = p_replaced_id
	price = p_price

func clone() -> ShopPurchaseRecord:
	return ShopPurchaseRecord.new(offer_id, replaced_id, price)
```

- [x] **Step 6: Append records only after atomic purchase success**

Add:

```gdscript
var purchase_records: Array[ShopPurchaseRecord] = []
```

At the end of the accepted branch, after assigning `deck_ids` and deducting the
ticket, append:

```gdscript
purchase_records.append(ShopPurchaseRecord.new(
	offer_id,
	replaced_id,
	CARD_PRICE
))
```

Do not append in any `_fail()` branch.

- [x] **Step 7: Import the new script, run synchronous tests, and scan the log**

Run a headless editor import with
`$env:TEMP\project-joker-shop-expansion-import.log`, verify
`shop_purchase_record.gd.uid` exists, then run `tests/run_all.gd` with
`$env:TEMP\project-joker-shop-expansion-green.log`.
Expected: every suite passes and the script-error scan is empty.

- [x] **Step 8: Commit only shop code, resources, and tests**

```powershell
git add -- `
  resources/cards/stage6/shop_deep_drop.tres `
  resources/cards/stage6/shop_amplified_chain.tres `
  resources/cards/stage6/shop_reverse_backup.tres `
  scripts/run/shop_purchase_record.gd `
  scripts/run/shop_purchase_record.gd.uid `
  scripts/cards/card_catalog.gd `
  scripts/run/shop_session.gd `
  tests/stage4_card_catalog_test.gd `
  tests/shop_session_test.gd

git commit --only -m "feat: expand area shop choices" -- `
  resources/cards/stage6/shop_deep_drop.tres `
  resources/cards/stage6/shop_amplified_chain.tres `
  resources/cards/stage6/shop_reverse_backup.tres `
  scripts/run/shop_purchase_record.gd `
  scripts/run/shop_purchase_record.gd.uid `
  scripts/cards/card_catalog.gd `
  scripts/run/shop_session.gd `
  tests/stage4_card_catalog_test.gd `
  tests/shop_session_test.gd
```

## Task 3: Extract Atomic Engraving Installation

**Files:**

- Create: `scripts/engravings/engraving_installation_service.gd`
- Create: `tests/engraving_installation_service_test.gd`
- Modify: `scripts/run/iron_abacus_slice_session.gd`
- Modify: `tests/iron_abacus_slice_session_test.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**

- Produces: `EngravingInstallationService.InstallationResult`
- Produces: `EngravingInstallationService.install(profiles, offer_ids, selected_id, die_id, face, catalog) -> InstallationResult`
- Result fields: `accepted: bool`, `reason: String`, `profiles: Array[DieState]`
- Preserves: `IronAbacusSliceSession.install_selected_engraving(die_id, face) -> OperationResult`

- [x] **Step 1: Add service tests for success and every rejection**

Create six blank profiles and cover:

- selected engraving not in offers;
- missing engraving definition;
- unknown die ID;
- face outside `1..6`;
- target die already engraved;
- malformed profile set;
- successful install modifies only the cloned target profile.

Core success assertion:

```gdscript
var before := _blank_profiles()
var result := EngravingInstallationService.new().install(
	before,
	[&"engraving_anchor"],
	&"engraving_anchor",
	&"d2",
	4,
	EngravingCatalog.new()
)
assert_true(result.accepted)
assert_equal(before[1].engraving_id, &"", "input profiles must remain untouched")
assert_equal(result.profiles[1].engraving_id, &"engraving_anchor")
assert_equal(result.profiles[1].engraved_face, 4)
```

- [x] **Step 2: Run `tests/run_all.gd` and confirm the service is missing**

Use `$env:TEMP\project-joker-engraving-install-red.log`.

- [x] **Step 3: Implement a result-owning pure service**

```gdscript
class_name EngravingInstallationService
extends RefCounted

class InstallationResult extends RefCounted:
	var accepted: bool
	var reason: String
	var profiles: Array[DieState]

	func _init(
		p_accepted: bool,
		p_reason: String = "",
		p_profiles: Array[DieState] = []
	) -> void:
		accepted = p_accepted
		reason = p_reason
		profiles = p_profiles

func install(
	profiles: Array[DieState],
	offer_ids: Array[StringName],
	selected_id: StringName,
	die_id: StringName,
	face: int,
	catalog: EngravingCatalog
) -> InstallationResult:
	if selected_id not in offer_ids:
		return InstallationResult.new(false, "待安装刻印不在本次候选中")
	if catalog == null or catalog.find_engraving(selected_id) == null:
		return InstallationResult.new(false, "待安装刻印定义不存在")
	if die_id not in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]:
		return InstallationResult.new(false, "刻印目标骰子不存在")
	if face < 1 or face > 6:
		return InstallationResult.new(false, "刻印骰面必须在 1 到 6 之间")
	var profile_error := _profiles_error(profiles, catalog)
	if not profile_error.is_empty():
		return InstallationResult.new(false, profile_error)
	var copies: Array[DieState] = []
	for profile in profiles:
		copies.append(profile.clone())
	var target := _find_profile(copies, die_id)
	if target.engraving_id != &"":
		return InstallationResult.new(false, "这颗骰子已经安装刻印")
	target.engraving_id = selected_id
	target.engraved_face = face
	return InstallationResult.new(true, "", copies)
```

Implement `_find_profile()` and `_profiles_error()` with the exact six-ID,
duplicate-ID, empty-engraving-face, known-engraving, and `1..6` checks already
covered by `IronAbacusSliceSession._profiles_error()`.

- [x] **Step 4: Refactor the old slice to consume the service**

Replace only the validation-and-clone block inside
`install_selected_engraving()`:

```gdscript
var install_result := EngravingInstallationService.new().install(
	die_profiles,
	engraving_offer_ids,
	selected_engraving_id,
	die_id,
	face,
	engraving_catalog
)
if not install_result.accepted:
	return _fail(install_result.reason)
die_profiles = install_result.profiles
```

Keep boundary capture, installed IDs, verification creation, error copy, and
phase changes unchanged. Remove old private helpers only when no remaining call
site uses them.

- [x] **Step 5: Import new scripts, then run all suites plus focused Iron Abacus checks**

Run a headless editor import with
`$env:TEMP\project-joker-engraving-install-import.log`, verify both new
`.gd.uid` files exist, then run:

```powershell
$log = Join-Path $env:TEMP "project-joker-engraving-install-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --log-file $log -s res://tests/run_all.gd

$inputLog = Join-Path $env:TEMP "project-joker-engraving-install-input.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --log-file $inputLog `
  -s res://tests/stage5_input_self_check.gd
```

Expected: service tests, old slice tests, and real input all pass.

- [x] **Step 6: Commit the extraction**

```powershell
git add -- `
  scripts/engravings/engraving_installation_service.gd `
  scripts/engravings/engraving_installation_service.gd.uid `
  scripts/run/iron_abacus_slice_session.gd `
  tests/engraving_installation_service_test.gd `
  tests/engraving_installation_service_test.gd.uid `
  tests/iron_abacus_slice_session_test.gd `
  tests/run_all.gd

git commit --only -m "refactor: share engraving installation" -- `
  scripts/engravings/engraving_installation_service.gd `
  scripts/engravings/engraving_installation_service.gd.uid `
  scripts/run/iron_abacus_slice_session.gd `
  tests/engraving_installation_service_test.gd `
  tests/engraving_installation_service_test.gd.uid `
  tests/iron_abacus_slice_session_test.gd `
  tests/run_all.gd
```

## Task 4: Implement the Two-Room Route and Shop Loop

**Files:**

- Create: `scripts/run/area_run_session.gd`
- Create: `tests/gold_corridor_area_run_test.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**

- Produces: `AreaRunSession.Phase`
- Produces: `AreaRunSession.start() -> OperationResult`
- Produces: `AreaRunSession.current_route_ids() -> Array[StringName]`
- Produces: `AreaRunSession.select_route(room_id: StringName) -> OperationResult`
- Produces: `AreaRunSession.accept_encounter_report(report: ResolutionReport) -> OperationResult`
- Produces: `AreaRunSession.advance_encounter_round() -> OperationResult`
- Produces: `AreaRunSession.open_shop() -> OperationResult`
- Produces: `AreaRunSession.leave_shop() -> OperationResult`
- Produces public child references: `encounter_session`, `shop_session`
- Produces history: `selected_room_ids`, `completed_rooms`, `shop_purchase_history`
- Consumes: `GoldCorridorCatalog`, `CardCatalog`, `DealerCatalog`, `EngravingCatalog`, `RunRng`

- [x] **Step 1: Write route and shop state-machine tests**

Register `gold_corridor_area_run_test.gd`, then cover:

- fresh start prepares exactly the first two candidates;
- candidates are a deterministic permutation of the first group;
- invalid route selection preserves a full snapshot including RNG;
- accepted route creates the matching three-round encounter;
- first-room success adds the exact reward once;
- first shop offers three unowned cards;
- leaving the first shop records purchases and prepares group two;
- second route selection creates the matching room;
- second shop again offers three unowned cards;
- leaving the second shop creates the inherited Iron Abacus encounter.

Use a helper that sets only the active test encounter target to zero, commits
three formal reports, and advances between rounds:

```gdscript
func _complete_current_encounter(run: AreaRunSession) -> void:
	run.encounter_session.target_total = 0
	for round_index in range(ThreeRoundEncounterSession.ROUND_COUNT):
		var report := run.encounter_session.current_session.commit()
		assert_true(run.accept_encounter_report(report).accepted)
		if round_index < ThreeRoundEncounterSession.ROUND_COUNT - 1:
			assert_true(run.advance_encounter_round().accepted)
```

- [x] **Step 2: Run the suite and confirm `AreaRunSession` is absent**

Use `$env:TEMP\project-joker-area-route-red.log`.

- [x] **Step 3: Define the complete owned state and constructor**

Use this phase enum and constructor boundary:

```gdscript
class_name AreaRunSession
extends RefCounted

enum Phase {
	NOT_STARTED,
	ROUTE_CHOICE,
	NORMAL_ROOM,
	SHOP,
	DEALER,
	ENGRAVING_REWARD,
	ENGRAVING_INSTALL,
	COMPLETE,
	FAILED,
}

const DEFAULT_SEED := 20260726
const DEALER_TARGET := 150

var phase: Phase = Phase.NOT_STARTED
var seed_value: int
var room_catalog: GoldCorridorCatalog
var card_catalog: CardCatalog
var dealer_catalog: DealerCatalog
var engraving_catalog: EngravingCatalog
var run_rng: RunRng
var room_index := 0
var route_ids: Array[StringName] = []
var selected_room_ids: Array[StringName] = []
var completed_rooms: Array[Dictionary] = []
var deck_ids: Array[StringName] = []
var intel_tickets := 0
var die_profiles: Array[DieState] = []
var encounter_session: ThreeRoundEncounterSession
var shop_session: ShopSession
var shop_purchase_history: Array[ShopPurchaseRecord] = []
var engraving_offer_ids: Array[StringName] = []
var selected_engraving_id: StringName = &""
var installed_die_id: StringName = &""
var installed_face := 0
var failure_origin: Phase = Phase.NOT_STARTED
var last_error := ""

func _init(
	p_seed_value: int = DEFAULT_SEED,
	p_room_catalog: GoldCorridorCatalog = null,
	p_card_catalog: CardCatalog = null,
	p_dealer_catalog: DealerCatalog = null,
	p_engraving_catalog: EngravingCatalog = null
) -> void:
	seed_value = p_seed_value
	room_catalog = p_room_catalog if p_room_catalog != null else GoldCorridorCatalog.new()
	card_catalog = p_card_catalog if p_card_catalog != null else CardCatalog.new()
	dealer_catalog = p_dealer_catalog if p_dealer_catalog != null else DealerCatalog.new()
	engraving_catalog = (
		p_engraving_catalog if p_engraving_catalog != null else EngravingCatalog.new()
	)
```

- [x] **Step 4: Implement atomic start and route preparation**

`start()` first validates all four catalogs, the exact two first-route IDs, the
twelve unique starter IDs, and six blank die profiles without assigning owned
state. It then creates a candidate `RunRng`, shuffles the validated route IDs
with that candidate, and commits the RNG, route, deck, tickets, profiles, and
phase together. A rejected `start()` therefore leaves the session at its
constructor snapshot.

Later route preparation uses:

```gdscript
func _prepare_route(ids: Array[StringName]) -> OperationResult:
	if ids.size() != 2:
		return _fail("路线候选必须恰好包含两个房间")
	for room_id in ids:
		if room_catalog.find_room(room_id) == null:
			return _fail("路线候选包含未知房间：%s" % room_id)
	var next_route_ids: Array[StringName] = []
	next_route_ids.assign(run_rng.shuffle(ids))
	route_ids.assign(next_route_ids)
	phase = Phase.ROUTE_CHOICE
	last_error = ""
	return OperationResult.new(true)
```

All rejection checks precede `run_rng.shuffle()`, so `_prepare_route()` cannot
consume RNG on a rejected call.

`current_route_ids()` returns a duplicate so callers cannot mutate the session.

- [x] **Step 5: Implement route selection and normal-room creation**

Validate the ID before appending it. Build the child session in locals; assign
owned fields only after `start()` succeeds:

```gdscript
func _create_normal_room(room: RoomDefinition) -> OperationResult:
	var rng_before := run_rng.snapshot_state()
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = deck_ids
	setup.encounter = room.encounter
	setup.resolution_context = ResolutionContext.empty()
	setup.success_intel_reward = room.success_intel_reward
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	var next := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		room.target_total,
		setup
	)
	var result := next.start()
	if not result.accepted:
		run_rng.restore_state(rng_before)
		return _fail(result.reason)
	encounter_session = next
	selected_room_ids.append(room.id)
	route_ids.clear()
	phase = Phase.NORMAL_ROOM
	last_error = ""
	return OperationResult.new(true)
```

- [x] **Step 6: Accept normal-room reports exactly once**

Delegate identity and duplicate checks to the active child. On final success:

```gdscript
completed_rooms.append({
	"room_id": selected_room_ids[-1],
	"target_total": encounter_session.target_total,
	"cumulative_total": encounter_session.cumulative_total,
})
intel_tickets += encounter_session.intel_tickets
```

On child failure set `failure_origin = Phase.NORMAL_ROOM` and
`phase = Phase.FAILED`. Do not prepare a shop.

- [x] **Step 7: Generate three unowned shop candidates**

Before consuming RNG:

```gdscript
var available: Array[StringName] = []
for card_id in card_catalog.shop_ids():
	if card_id not in deck_ids:
		available.append(card_id)
if available.size() < 3:
	return _fail("当前牌组之外的商店牌不足三张")
var shuffled := run_rng.shuffle(available)
var offers: Array[StringName] = []
offers.assign(shuffled.slice(0, 3))
var next_shop := ShopSession.new(
	card_catalog,
	deck_ids,
	offers,
	intel_tickets
)
shop_session = next_shop
phase = Phase.SHOP
```

Only `open_shop()` may perform this transition, and only after a successful
normal room.

- [x] **Step 8: Settle each shop and continue the route**

Clone each `ShopPurchaseRecord`, then update deck and ticket fields. If
`room_index == 0`, increment the index and prepare `second_route_ids()`.
If `room_index == 1`, build `next_deck_ids`, `next_intel_tickets`, and
`next_purchase_history` as locals and pass them to `_create_dealer(...)`.
The dealer child must start from the candidate post-shop deck, but the owned
area-run fields must remain unchanged until that start succeeds:

```gdscript
func _create_dealer(
	next_deck_ids: Array[StringName],
	next_intel_tickets: int,
	next_purchase_history: Array[ShopPurchaseRecord]
) -> OperationResult:
	var rng_before := run_rng.snapshot_state()
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = next_deck_ids
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.resolution_context = ResolutionContext.new(
		dealer_catalog.iron_abacus(),
		engraving_catalog
	)
	setup.success_intel_reward = 0
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	var next := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		DEALER_TARGET,
		setup
	)
	var result := next.start()
	if not result.accepted:
		run_rng.restore_state(rng_before)
		return _fail(result.reason)
	deck_ids.assign(next_deck_ids)
	intel_tickets = next_intel_tickets
	shop_purchase_history.assign(next_purchase_history)
	encounter_session = next
	phase = Phase.DEALER
	last_error = ""
	return OperationResult.new(true)
```

For the first shop, likewise compute the candidate deck, tickets, purchase
history, and shuffled second route in locals. Commit all four plus
`room_index = 1` and `phase = ROUTE_CHOICE` only after the route candidates
validate. For both branches, capture `rng_before` before the first shuffle or
child start and restore it on every rejected exit. Thus a rejected shop exit
cannot consume RNG, append purchase history, change the deck/tickets, or advance
the room index.

- [x] **Step 9: Prove route/shop determinism and invariance**

Create two sessions with the same seed, choose the same route IDs, and assert
equal candidate order, dice, hand IDs, shop IDs, deck IDs, tickets, RNG states,
and purchase histories. For every rejected method call compare a snapshot:

```gdscript
func _snapshot(run: AreaRunSession) -> Dictionary:
	return {
		"phase": run.phase,
		"rng": run.run_rng.snapshot_state() if run.run_rng != null else 0,
		"route_ids": run.route_ids.duplicate(),
		"selected": run.selected_room_ids.duplicate(),
		"deck": run.deck_ids.duplicate(),
		"tickets": run.intel_tickets,
		"profiles": _profile_snapshot(run.die_profiles),
		"history": _purchase_snapshot(run.shop_purchase_history),
	}
```

- [x] **Step 10: Import new scripts, run synchronous suites, and commit**

Run a headless editor import with
`$env:TEMP\project-joker-area-route-import.log`, verify both new `.gd.uid`
files exist, then use `$env:TEMP\project-joker-area-route-green.log`, scan
script-load patterns, run both diff checks, and:

```powershell
git add -- `
  scripts/run/area_run_session.gd `
  scripts/run/area_run_session.gd.uid `
  tests/gold_corridor_area_run_test.gd `
  tests/gold_corridor_area_run_test.gd.uid `
  tests/run_all.gd

git commit --only -m "feat: add gold corridor route loop" -- `
  scripts/run/area_run_session.gd `
  scripts/run/area_run_session.gd.uid `
  tests/gold_corridor_area_run_test.gd `
  tests/gold_corridor_area_run_test.gd.uid `
  tests/run_all.gd
```

## Task 5: Complete Dealer, Engraving, Failure, Restart, and Summary State

**Files:**

- Modify: `scripts/run/area_run_session.gd`
- Modify: `tests/gold_corridor_area_run_test.gd`

**Interfaces:**

- Produces: `AreaRunSession.select_engraving(engraving_id) -> OperationResult`
- Produces: `AreaRunSession.install_selected_engraving(die_id, face) -> OperationResult`
- Produces: `AreaRunSession.restart() -> OperationResult`
- Produces: `AreaRunSession.completion_snapshot() -> Dictionary`
- Consumes: `EngravingInstallationService.install(...)`

- [x] **Step 1: Add failing full-area tests**

Cover all four route combinations. For each combination:

1. start;
2. select first room;
3. complete three reports with a zeroed test target;
4. open and leave shop;
5. select second room;
6. complete three reports;
7. open and leave shop;
8. complete Iron Abacus;
9. select one offered engraving;
10. install it on `d1`, face `2`;
11. assert `COMPLETE` and exact completion data.

Also prove first-room, second-room, and dealer failures all enter `FAILED` and
do not expose a boundary-retry method. Extend the Task 4 snapshot helper with
`engraving_offer_ids`, `selected_engraving_id`, `installed_die_id`,
`installed_face`, and `failure_origin`. Before every rejected engraving
selection or installation, capture that full snapshot plus RNG state; afterward
assert it is unchanged. `last_error` is the sole allowed diagnostic mutation.

- [x] **Step 2: Run the suite and confirm completion assertions fail**

Use `$env:TEMP\project-joker-area-completion-red.log`.

- [x] **Step 3: Extend report acceptance for Iron Abacus**

When the active phase is `DEALER` and the child succeeds:

```gdscript
var shuffled := run_rng.shuffle(engraving_catalog.all_ids())
engraving_offer_ids.clear()
engraving_offer_ids.assign(shuffled.slice(0, 3))
selected_engraving_id = &""
phase = Phase.ENGRAVING_REWARD
```

When it fails:

```gdscript
failure_origin = Phase.DEALER
phase = Phase.FAILED
```

Do not add dealer tickets.

- [x] **Step 4: Add candidate selection and shared atomic installation**

```gdscript
func select_engraving(engraving_id: StringName) -> OperationResult:
	if phase != Phase.ENGRAVING_REWARD and phase != Phase.ENGRAVING_INSTALL:
		return _fail("当前不能选择刻印")
	if engraving_id not in engraving_offer_ids:
		return _fail("所选刻印不在本次候选中")
	selected_engraving_id = engraving_id
	phase = Phase.ENGRAVING_INSTALL
	last_error = ""
	return OperationResult.new(true)

func install_selected_engraving(
	die_id: StringName,
	face: int
) -> OperationResult:
	if phase != Phase.ENGRAVING_INSTALL:
		return _fail("请先从候选中选择一个刻印")
	var result := EngravingInstallationService.new().install(
		die_profiles,
		engraving_offer_ids,
		selected_engraving_id,
		die_id,
		face,
		engraving_catalog
	)
	if not result.accepted:
		return _fail(result.reason)
	die_profiles = result.profiles
	installed_die_id = die_id
	installed_face = face
	phase = Phase.COMPLETE
	last_error = ""
	return OperationResult.new(true)
```

Do not create a verification session.

- [x] **Step 5: Return a defensive completion snapshot**

The dictionary keys are stable UI contracts:

```gdscript
func completion_snapshot() -> Dictionary:
	if phase != Phase.COMPLETE:
		return {}
	var purchases: Array[Dictionary] = []
	for record in shop_purchase_history:
		purchases.append({
			"offer_id": record.offer_id,
			"replaced_id": record.replaced_id,
			"price": record.price,
		})
	return {
		"rooms": completed_rooms.duplicate(true),
		"dealer": {
			"id": dealer_catalog.iron_abacus().id,
			"target_total": encounter_session.target_total,
			"cumulative_total": encounter_session.cumulative_total,
		},
		"purchases": purchases,
		"deck_ids": deck_ids.duplicate(),
		"intel_tickets": intel_tickets,
		"engraving_id": selected_engraving_id,
		"die_id": installed_die_id,
		"face": installed_face,
	}
```

- [x] **Step 6: Implement full restart**

`restart()` is valid from every phase except `NOT_STARTED`. Clear every owned
mutable field while retaining the already constructed catalog instances, then
call `start()` with the original seed. The restart test must compare the new
first route order, first dice, and first hand against a fresh session.

- [x] **Step 7: Add dealer and restart determinism proof**

For two same-seed sessions assert:

- both shop histories match;
- Iron Abacus first dice and four-card hands match;
- three engraving candidates match;
- final completion snapshots match.

For different chosen routes, assert the selected IDs and room definitions differ
without asserting that random state must differ before the room begins.

- [x] **Step 8: Run and commit**

Run `tests/run_all.gd` with
`$env:TEMP\project-joker-area-completion-green.log`, scan, run diff checks, then:

```powershell
git add -- `
  scripts/run/area_run_session.gd `
  tests/gold_corridor_area_run_test.gd

git commit --only -m "feat: complete gold corridor run state" -- `
  scripts/run/area_run_session.gd `
  tests/gold_corridor_area_run_test.gd
```

## Task 6: Build Scene-Backed Route and Completion Panels

**Files:**

- Create: `scenes/components/route_choice_panel.tscn`
- Create: `scripts/ui/route_choice_panel.gd`
- Create: `scenes/components/area_complete_panel.tscn`
- Create: `scripts/ui/area_complete_panel.gd`
- Create: `tests/gold_corridor_ui_contract_test.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**

- Produces signal: `RouteChoicePanel.route_selected(room_id: StringName)`
- Produces: `RouteChoicePanel.bind_routes(route_ids, room_catalog, deck_ids, card_catalog) -> bool`
- Produces: `RouteChoicePanel.close() -> void`
- Produces signal: `AreaCompletePanel.restart_requested`
- Produces signal: `AreaCompletePanel.return_requested`
- Produces: `AreaCompletePanel.bind_summary(summary, room_catalog, card_catalog, engraving_catalog) -> bool`
- Produces: `AreaCompletePanel.close() -> void`

- [x] **Step 1: Write packed-scene contract tests first**

Assert that both scenes load and expose stable unique nodes.

Route panel required nodes:

```text
RouteChoicePanel
RouteDimmer
RouteLedger
LeftRouteName
LeftRouteGoal
LeftRouteReward
LeftRouteTags
LeftRouteSynergy
LeftLaneOne
LeftLaneTwo
LeftLaneThree
LeftRouteButton
RightRouteName
RightRouteGoal
RightRouteReward
RightRouteTags
RightRouteSynergy
RightLaneOne
RightLaneTwo
RightLaneThree
RightRouteButton
RouteErrorLabel
```

Completion panel required nodes:

```text
AreaCompletePanel
CompleteDimmer
CompleteTitle
RouteHistoryLabel
ScoreHistoryLabel
PurchaseHistoryLabel
FinalDeckLabel
FinalResourceLabel
FinalEngravingLabel
RestartAreaButton
ReturnEntryButton
CompleteErrorLabel
```

Test both signals, hidden initial state, full-rect anchors, input blocking while
visible, and invalid bind data failing closed.

- [x] **Step 2: Run `tests/run_all.gd` and verify missing scenes fail**

Use `$env:TEMP\project-joker-area-panels-red.log`.

- [x] **Step 3: Create the route panel scene in the approved layout**

Use a full-rect root and dimmer. Put two equal-width route cards in one
`HBoxContainer`. Each card contains stable labels for name, target, reward,
tags, synergy, three lane summaries, and one button. Do not construct these
cards in script.

At 1920 logical pixels use:

```text
outer safe margin: 32
ledger gap: 24
each route card minimum width: 820
lane preview minimum height: 132
choice button minimum height: 52
```

- [x] **Step 4: Bind route resources and current-deck synergy**

`bind_routes()` requires exactly two known IDs. It binds the left and right
cards in the supplied deterministic order. Lane copy format:

```gdscript
"%s\n%d 个骰位 · 系数 ×%d" % [
	rule.display_name,
	rule.slot_count,
	rule.coefficient,
]
```

Goal and reward copy:

```gdscript
goal_label.text = "三轮目标：%d" % room.target_total
reward_label.text = "成功奖励：%d 张情报券" % room.success_intel_reward
```

Synergy matching is exact stable-tag intersection:

```gdscript
func _matching_card_names(
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> Array[String]:
	var names: Array[String] = []
	for card_id in deck_ids:
		var card := card_catalog.find_card(card_id)
		if card == null:
			continue
		for tag in card.tags:
			if tag in room.synergy_tags:
				names.append(card.display_name)
				break
	names.sort()
	return names
```

Display at most four names followed by `等 N 张`; if no card matches, display
`当前牌组无直接标签匹配`.

- [x] **Step 5: Create and bind the completion panel**

Keep two scene-backed columns. `bind_summary()` rejects missing keys, non-two
room summaries, non-twelve-card decks, unknown content IDs, invalid face, or
missing engraving. Format records as:

```gdscript
"%s → %s（%d 情报券）" % [
	card_catalog.find_card(record.replaced_id).display_name,
	card_catalog.find_card(record.offer_id).display_name,
	record.price,
]
```

Do not calculate scores or reconstruct history from UI state.

- [x] **Step 6: Verify signals, bounds, and blocking**

Add synthetic data tests at `1280×720` and `1920×1080`. After three process
frames assert root, cards, lane summaries, deck copy, buttons, and error labels
stay within the panel. Click behind each visible panel and prove the target does
not receive the event.

- [x] **Step 7: Import new scripts, run, and commit**

Run a headless editor import with
`$env:TEMP\project-joker-area-panels-import.log`, verify the three new
`.gd.uid` files exist, then run synchronous suites with
`$env:TEMP\project-joker-area-panels-green.log`, scan, diff-check, then:

```powershell
git add -- `
  scenes/components/route_choice_panel.tscn `
  scripts/ui/route_choice_panel.gd `
  scripts/ui/route_choice_panel.gd.uid `
  scenes/components/area_complete_panel.tscn `
  scripts/ui/area_complete_panel.gd `
  scripts/ui/area_complete_panel.gd.uid `
  tests/gold_corridor_ui_contract_test.gd `
  tests/gold_corridor_ui_contract_test.gd.uid `
  tests/run_all.gd

git commit --only -m "feat: add gold corridor route panels" -- `
  scenes/components/route_choice_panel.tscn `
  scripts/ui/route_choice_panel.gd `
  scripts/ui/route_choice_panel.gd.uid `
  scenes/components/area_complete_panel.tscn `
  scripts/ui/area_complete_panel.gd `
  scripts/ui/area_complete_panel.gd.uid `
  tests/gold_corridor_ui_contract_test.gd `
  tests/gold_corridor_ui_contract_test.gd.uid `
  tests/run_all.gd
```

## Task 7: Connect the Complete Player-Facing Area

**Files:**

- Create: `scenes/run/gold_corridor_run_screen.tscn`
- Create: `scripts/ui/gold_corridor_run_screen.gd`
- Modify: `scenes/components/round_summary_panel.tscn`
- Modify: `scripts/ui/round_summary_panel.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Create: `tests/gold_corridor_input_self_check.gd`
- Modify: `tests/stage5_guide_input_self_check.gd`
- Modify: `tests/stage5_input_self_check.gd`

**Interfaces:**

- Produces: `GoldCorridorRunScreen.start_run() -> void`
- Consumes: all `AreaRunSession` methods from Tasks 4 and 5
- Produces: `RoundSummaryPanel.show_area_failure(run_session: ThreeRoundEncounterSession, dealer_failure: bool) -> void`
- Changes player entry: `RunTrialButton` launches `gold_corridor_run_screen.tscn`
- Preserves advanced-guide entry: `ReplayAdvancedGuideButton` launches `iron_abacus_slice_screen.tscn`

- [x] **Step 1: Write the real-input flow before the owning screen**

Create `gold_corridor_input_self_check.gd` that:

1. instantiates `single_encounter_screen.tscn` with base tutorial auto-start off;
2. clicks `%RunTrialButton`;
3. asserts the current scene is `GoldCorridorRunScreen`;
4. clicks one first-route button;
5. completes three rounds through real `%ConfirmButton` and summary clicks;
6. makes one real first-shop replacement;
7. clicks a second-route button;
8. completes three more rounds;
9. makes one real second-shop replacement;
10. completes Iron Abacus;
11. selects engraving, die, and face through real buttons;
12. asserts the completion panel shows two routes, two purchases, twelve cards,
    tickets, and the installed engraving;
13. clicks restart and proves the first route order and initial dice reproduce.

The fixture may set only the active `ThreeRoundEncounterSession.target_total`
to zero after each route/dealer begins. Every player transition still uses the
real button and signal path.

- [x] **Step 2: Run the focused script and confirm the scene is missing**

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-input-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --log-file $log `
  -s res://tests/gold_corridor_input_self_check.gd
```

- [x] **Step 3: Build the stable owning scene**

`gold_corridor_run_screen.tscn` contains these top-level children in order:

```text
EncounterScreen
ShopScreen
RoundSummaryPanel
RouteChoicePanel
EngravingRewardPanel
AreaCompletePanel
```

Make each child unique in owner. Keep the embedded encounter's
`tutorial_auto_start = false`. Do not create whole panels from script.

- [x] **Step 4: Wire phase transitions in `GoldCorridorRunScreen`**

The script owns one `AreaRunSession` and uses these methods:

```gdscript
func start_run() -> void:
	area_session = AreaRunSession.new(run_seed)
	var result := area_session.start()
	if not result.accepted:
		_show_start_error(result.reason)
		return
	_show_route_choice()

func _on_route_selected(room_id: StringName) -> void:
	var result := area_session.select_route(room_id)
	if not result.accepted:
		route_panel.show_error(result.reason)
		return
	route_panel.close()
	_bind_current_encounter()
```

`_on_round_committed()` delegates the report, then:

- `ROUND_SUMMARY`: show existing next-round summary;
- normal `SUCCEEDED`: show enter-shop summary;
- dealer `SUCCEEDED`: bind engraving reward;
- `FAILED`: call `show_area_failure()` with no boundary retry;
- otherwise refresh the encounter status.

First shop leave opens the next route panel. Second shop leave binds Iron
Abacus immediately. Engraving install success closes the reward panel and binds
`completion_snapshot()` into `AreaCompletePanel`.

- [x] **Step 5: Add an area-specific failure presentation**

Reuse `RetryRunButton` and `ReturnTeachingButton`, but hide dealer and
verification retry buttons:

```gdscript
func show_area_failure(
	run_session: ThreeRoundEncounterSession,
	dealer_failure: bool
) -> void:
	visible = true
	_hide_actions()
	title_label.text = (
		"铁算盘挑战未达标"
		if dealer_failure
		else "金线回廊解析未达标"
	)
	detail_label.text = "累计解析：%d / %d\n目标差值：%d" % [
		run_session.cumulative_total,
		run_session.target_total,
		maxi(run_session.target_total - run_session.cumulative_total, 0),
	]
	retry_button.visible = true
	retry_button.text = "重新开始金线回廊"
	return_button.visible = true
```

The existing prototype-specific methods and buttons remain unchanged.

- [x] **Step 6: Switch only the normal player entry**

Change `_on_run_trial_pressed()` to:

```gdscript
func _on_run_trial_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	)
```

Keep `_on_replay_advanced_guide_pressed()` and
`_launch_iron_abacus_slice()` unchanged. Update the normal button tooltip to:

```text
完成两次路线选择、两个普通房、两次情报交换、铁算盘与区域刻印奖励
```

- [x] **Step 7: Retarget old prototype checks to explicit prototype entry**

`stage5_guide_input_self_check.gd` should click
`%ReplayAdvancedGuideButton`, which resets and launches the advanced-guide
prototype. `stage5_input_self_check.gd` should instantiate
`iron_abacus_slice_screen.tscn` directly instead of assuming the normal
player-facing button still launches it.

Do not weaken any existing Iron Abacus assertions.

- [x] **Step 8: Prove blocking and failure semantics**

In the new input script:

- click an encounter button behind the route panel and prove state is unchanged;
- click behind the completion panel and prove no restart occurs;
- complete a separate failure fixture and assert `%RetryDealerButton` and
  `%RetryVerificationButton` are hidden;
- click `%RetryRunButton` and prove the whole route state resets;
- verify no boundary retry method is invoked by UI.

- [x] **Step 9: Import new scripts, then run focused and regression input checks**

Run a headless editor import with
`$env:TEMP\project-joker-gold-screen-import.log`, verify both new `.gd.uid`
files exist, then run individually with distinct writable logs:

```text
gold_corridor_input_self_check.gd
single_encounter_input_self_check.gd
tutorial_input_self_check.gd
three_round_input_self_check.gd
stage5_input_self_check.gd
stage5_guide_input_self_check.gd
```

Scan every log for both script-load patterns.

- [x] **Step 10: Commit only the integrated code and tests**

```powershell
git add -- `
  scenes/run/gold_corridor_run_screen.tscn `
  scripts/ui/gold_corridor_run_screen.gd `
  scripts/ui/gold_corridor_run_screen.gd.uid `
  scenes/components/round_summary_panel.tscn `
  scripts/ui/round_summary_panel.gd `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  tests/gold_corridor_input_self_check.gd `
  tests/gold_corridor_input_self_check.gd.uid `
  tests/stage5_guide_input_self_check.gd `
  tests/stage5_input_self_check.gd

git commit --only -m "feat: connect gold corridor playable flow" -- `
  scenes/run/gold_corridor_run_screen.tscn `
  scripts/ui/gold_corridor_run_screen.gd `
  scripts/ui/gold_corridor_run_screen.gd.uid `
  scenes/components/round_summary_panel.tscn `
  scripts/ui/round_summary_panel.gd `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  tests/gold_corridor_input_self_check.gd `
  tests/gold_corridor_input_self_check.gd.uid `
  tests/stage5_guide_input_self_check.gd `
  tests/stage5_input_self_check.gd
```

## Task 8: Complete Layout, Playability, Visual, and Full Regression Acceptance

**Files:**

- Create: `tests/gold_corridor_layout_self_check.gd`
- Modify only when a measured defect requires it:
  - `scenes/components/route_choice_panel.tscn`
  - `scripts/ui/route_choice_panel.gd`
  - `scenes/components/area_complete_panel.tscn`
  - `scripts/ui/area_complete_panel.gd`
  - `scenes/run/gold_corridor_run_screen.tscn`
  - `scripts/ui/gold_corridor_run_screen.gd`
  - Gold Corridor room resources whose fixed-seed playability fails

**Interfaces:**

- Produces durable layout and playability acceptance for the complete area
- Preserves all prior test and document boundaries

- [x] **Step 1: Add a real full-area layout self-check**

At the project logical viewport and rendered `1280×720` / `1920×1080`
configurations, inspect:

- both route cards and six lane previews;
- target, reward, tags, synergy, buttons, and error copy;
- both shop layouts with three valid candidates;
- Iron Abacus encounter;
- engraving reward panel;
- both completion-summary columns and all twelve final card names;
- restart and return buttons.

For each visible overlay assert:

```gdscript
var root_bounds := Rect2(Vector2.ZERO, screen.size)
assert_true(root_bounds.encloses(panel.get_rect()))
assert_equal(panel.mouse_filter, Control.MOUSE_FILTER_STOP)
assert_true(panel.z_index > screen.get_node("%EncounterScreen").z_index)
```

- [x] **Step 2: Add fixed-seed playability probes**

For each of the four room resources, run deterministic samples that record
legal assignment counts, calibration/card-created alternatives, unassigned dice,
best preview total, and target difference. Assert:

- at least two distinct valid solution signatures occur across the sample;
- the room is not dependent on a specific shop-only card;
- no hidden or probabilistic bonus is used.

If a room fails, change only that room's target or coefficient, update its exact
catalog assertion, and rerun all four rooms before continuing.

- [x] **Step 3: Capture ten route and completion visuals**

Create a temporary capture script that saves:

```text
1280x720-route-one.png
1280x720-route-two.png
1280x720-shop-one.png
1280x720-shop-two.png
1280x720-complete.png
1920x1080-route-one.png
1920x1080-route-two.png
1920x1080-shop-one.png
1920x1080-shop-two.png
1920x1080-complete.png
```

Run non-headless Godot with an explicit writable `--log-file`. Inspect all ten
images for clipping, hierarchy, text overlap, card density, dimming, input-layer
order, and button clarity. Remove the capture script, generated `.uid`, and PNG
directory after inspection.

- [x] **Step 4: Run the new full input path three consecutive times**

Use three distinct logs:

```text
project-joker-gold-input-stability-1.log
project-joker-gold-input-stability-2.log
project-joker-gold-input-stability-3.log
```

Every run must exit zero and have no script-load matches.

- [x] **Step 5: Run the editor import check**

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-editor-import.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --editor --quit --path . --log-file $log
```

Use the editor import to generate
`tests/gold_corridor_layout_self_check.gd.uid` and audit that every new
production and durable test script already has its tracked sibling `.gd.uid`.
Ignore only known sandbox inability to save global editor settings; script-load
errors remain failures.

- [x] **Step 6: Run the final test matrix**

Run each with its own writable log:

```text
tests/run_all.gd
tests/single_encounter_layout_self_check.gd
tests/tutorial_layout_self_check.gd
tests/three_round_layout_self_check.gd
tests/stage5_layout_self_check.gd
tests/stage5_guide_layout_self_check.gd
tests/gold_corridor_layout_self_check.gd
tests/single_encounter_input_self_check.gd
tests/tutorial_input_self_check.gd
tests/three_round_input_self_check.gd
tests/stage5_input_self_check.gd
tests/stage5_guide_input_self_check.gd
tests/gold_corridor_input_self_check.gd
```

Then start the project main scene:

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-main-scene.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --log-file $log --quit-after 2
```

- [x] **Step 7: Audit gambling-oriented language**

Scan only production sources and content:

```powershell
$sourceFiles = Get-ChildItem `
  -Path scripts,scenes,resources `
  -Recurse -File |
  Where-Object { $_.Extension -in ".gd",".tscn",".tres",".json" }

$sourceFiles | Select-String `
  -Pattern "下注|筹码|赌注|贷款|借贷|充值|真钱|现金|概率触发|随机触发|\bbet\b|\bwager\b|\bchips?\b|\bloan\b|real.?money" `
  -CaseSensitive:$false
```

Expected: zero matches. “庄家” and the dream-casino setting are allowed; real
gambling mechanics and copy are not.

- [x] **Step 8: Verify final Git boundaries**

Run:

```powershell
git diff --check
git diff --cached --check
git status --short
```

Expected before the test commit:

- staged files are design and plan documents only, plus explicitly staged new
  code awaiting this commit;
- the only unrelated unstaged file is `project.godot`;
- no visual-companion or capture artifacts remain.

- [x] **Step 9: Commit the durable acceptance check and measured fixes**

Use explicit paths. The minimum commit is:

```powershell
git add -- `
  tests/gold_corridor_layout_self_check.gd `
  tests/gold_corridor_layout_self_check.gd.uid

git commit --only -m "test: verify gold corridor area run" -- `
  tests/gold_corridor_layout_self_check.gd `
  tests/gold_corridor_layout_self_check.gd.uid
```

If measured layout or playability fixes are required, include only their exact
code/resource paths in both commands. Never include staged documents or
`project.godot`.

- [x] **Step 10: Mark this plan complete without committing it**

Change every plan checkbox to `[x]`, restage:

```powershell
git add -- `
  docs/superpowers/plans/2026-07-26-gold-corridor-area-run.md `
  docs/superpowers/specs/2026-07-26-gold-corridor-area-run-design.md
```

Confirm both documents remain staged and absent from every code commit.

## Final Acceptance Summary

The implementation is complete only when:

- [x] the normal “进入六面诡局” entry starts the complete Gold Corridor;
- [x] both route choices show two complete, public, side-by-side room options;
- [x] all four route combinations can complete the area;
- [x] both normal rooms run exactly three rounds and award the configured tickets;
- [x] both shops show three unowned candidates and preserve a unique twelve-card deck;
- [x] replacement history records the exact incoming card, outgoing card, and price;
- [x] Iron Abacus inherits the selected deck, tickets, dice profiles, and shared RNG;
- [x] normal-room or dealer failure ends the area without a boundary-retry entry;
- [x] engraving installation is shared, atomic, and completes the formal area without a verification room;
- [x] the final summary shows two rooms, three encounter totals, two shop histories, twelve cards, tickets, and engraving placement;
- [x] same-seed, same-choice, same-action runs fully reproduce;
- [x] preview and commit event signatures remain identical;
- [x] base tutorial, old Iron Abacus prototype, engraving verification, and advanced guide remain green;
- [x] fixed-seed playability provides more than one viable path per room;
- [x] all ten dual-resolution visuals pass inspection;
- [x] synchronous, layout, input, import, and main-scene checks pass;
- [x] production source remains free of gambling-oriented mechanics and copy;
- [x] code commits exist directly on `master`;
- [x] no unapproved remote push occurs;
- [x] documents remain staged and uncommitted;
- [x] `project.godot` remains untouched and unstaged.
