# Shop Refresh and Route Intel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one deterministic paid refresh and one paid future-intel service to both formal shops in all three standalone areas, including old-card buyback, exact route/dealer previews, transaction summaries, and real-input verification.

**Architecture:** `AreaRunSession` owns the immutable area market, consumes the shared `RunRng` only when opening a shop, and precomputes both a stable market priority and the next-node snapshot. `ShopSession` owns atomic spending, deck replacement, refresh scanning, unlock state, and structured records without holding RNG or area catalogs. Shared `ShopScreen` controls invoke the domain, while a separate read-only `ShopIntelPanel` resolves stable snapshot IDs through the current area catalogs.

**Tech Stack:** Godot 4.6.1, typed GDScript, `.tres` content resources, `.tscn` scene-first UI, synchronous domain suites under `tests/run_all.gd`, SceneTree mouse/layout self-checks.

## Global Constraints

- Work in `D:\Project\ProjectJoker\project-joker` directly on the already-authorized `master` branch.
- Modify files with `apply_patch`; preserve unrelated user changes.
- Design and implementation-plan documents remain staged and must never enter code commits.
- Stage code with explicit paths and commit with `git commit --only ... -- <explicit paths>`.
- Keep the logical canvas at `1920×1080` and the development window override at `1280×720`.
- Do not change existing room rewards, targets, card values, fixed seeds, dealer balance, or the 40-card catalog.
- Do not add rerolls, betting, probability triggers, hidden compensation, random rewards, or future dice/hand/solution previews.
- Stable layout and text containers live in `.tscn`; scripts bind data, refresh state, forward signals, and validate input.
- Prediction and formal submission continue to share `RoundResolver`.
- Every headless command must use `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` and an explicit writable `$env:TEMP` log.
- A check fails when its exit code is nonzero or its log contains `SCRIPT ERROR|Failed to load script`.
- Certificate-read errors, deliberately corrupted `ConfigFile` errors, unknown-SFX warnings, and exit resource-leak warnings are known noise and are not failures by themselves.

---

## File Map

### New domain files

- `scripts/run/shop_intel_snapshot.gd` — immutable stable-ID description of either the next route pair or the dealer.
- `scripts/run/shop_service_record.gd` — structured refresh/intel spend record with shop index, service kind, cost, and intel kind.

### Modified domain files

- `scripts/run/shop_session.gd` — derives visible offers from a stable market priority and executes purchase, refresh, and intel operations atomically.
- `scripts/run/area_run_session.gd` — owns the area market, precomputes shop priorities and future snapshots, transfers service records, and exposes them in completion snapshots.
- `scripts/areas/area_definition.gd` — validates that the entry deck plus shop pool can support six off-deck candidates without changing content resources.

### New UI files

- `scripts/ui/route_brief_formatter.gd` — shared pure route-rule and deck-synergy copy for the real route panel and shop preview.
- `scripts/ui/shop/shop_intel_panel.gd` — validates and binds route/dealer snapshots into read-only presentation.
- `scenes/components/shop_intel_panel.tscn` — fixed route/dealer preview hierarchy with a blocking dimmer and return button.

### Modified UI files

- `scripts/ui/shop/shop_screen.gd` — binds service state, confirms refresh, purchases/reopens intel, and emits an intel-view request.
- `scenes/shop/shop_screen.tscn` — service status labels, refresh/intel buttons, and refresh confirmation dialog.
- `scripts/ui/area_run_screen.gd` — connects shop intel requests to the shared intel panel and closes it on all phase transitions.
- `scenes/run/area_run_screen.tscn` — instantiates `ShopIntelPanel` above `ShopScreen`.
- `scripts/ui/area_complete_panel.gd` — validates and renders service records without inferring them from balance.
- `scenes/components/area_complete_panel.tscn` — gives the transaction history enough fixed layout capacity for purchases and services.

### Tests

- `tests/shop_session_test.gd` — market scanning, all purchase/refresh orders, intel unlock, records, and atomic failures.
- `tests/shop_intel_snapshot_test.gd` — route/dealer snapshot construction and validation.
- `tests/gold_corridor_area_run_test.gd`
- `tests/mirror_hall_area_run_test.gd`
- `tests/faceless_hub_area_run_test.gd` — both-shop integration, exact future identity, service transfer, restart, and RNG invariants.
- `tests/area_run_ui_contract_test.gd` — shared scene and stable node contract.
- `tests/shop_services_input_self_check.gd` — real pointer path for confirmation, refresh, intel, repeat view, close, purchase, and leave.
- `tests/shop_intel_layout_self_check.gd` — route/dealer preview bounds at both required resolutions.
- `tests/gold_corridor_input_self_check.gd` — existing end-to-end path remains compatible and completion history includes service entries when used.

---

### Task 1: Deterministic Shop Market and Atomic Services

**Files:**
- Create: `scripts/run/shop_intel_snapshot.gd`
- Create: `scripts/run/shop_service_record.gd`
- Modify: `scripts/run/shop_session.gd`
- Modify: `tests/shop_session_test.gd`
- Create: `tests/shop_intel_snapshot_test.gd`

**Interfaces:**
- Produces: `ShopIntelSnapshot.routes(route_ids: Array[StringName]) -> ShopIntelSnapshot`
- Produces: `ShopIntelSnapshot.dealer(dealer_id: StringName, dealer_target: int) -> ShopIntelSnapshot`
- Produces: `ShopIntelSnapshot.structural_error() -> String`
- Produces: `ShopIntelSnapshot.validate(area_definition: AreaDefinition, dealer_catalog: DealerCatalog) -> String`
- Produces: `ShopServiceRecord.new(shop_index: int, service_type: ServiceType, price: int, intel_kind: ShopIntelSnapshot.Kind = -1)`
- Produces: `ShopSession.refresh_offers() -> OperationResult`
- Produces: `ShopSession.purchase_intel() -> OperationResult`
- Preserves: legacy constructor callers can pass only three offered IDs and receive the same three visible offers with services disabled.

- [ ] **Step 1: Extend the shop tests with a stable 18-card market**

Build a market from the 12 starter IDs and 6 generic shop IDs. Pass a fixed priority ordering and assert that the first three off-deck IDs become visible:

```gdscript
var market: Array[StringName] = starter.duplicate()
market.append_array(catalog.shop_ids())
var snapshot := ShopIntelSnapshot.routes([
	&"gold_room_narrow_ledger",
	&"gold_room_parallel_proof",
])
var shop := ShopSession.new(
	catalog,
	starter,
	market,
	3,
	snapshot,
	0,
	true
)
assert_equal(shop.offer_ids, catalog.shop_ids().slice(0, 3), "first eligible three")
```

Add assertions for prices:

```gdscript
assert_equal(ShopSession.CARD_PRICE, 1, "card price")
assert_equal(ShopSession.REFRESH_PRICE, 1, "refresh price")
assert_equal(ShopSession.INTEL_PRICE, 1, "intel price")
```

- [ ] **Step 2: Add failing refresh-order and buyback cases**

Cover all four purchase counts before refresh. For each `purchase_count` in `0..3`:

1. Create a fresh shop with 12 deck IDs and an 18-ID priority.
2. Buy the first `purchase_count` visible offers, replacing distinct starter cards.
3. Save the three originally shown IDs.
4. Call `refresh_offers()`.
5. Assert exactly three new offers, no overlap with shown IDs, none in the current deck, one ticket spent, and `refresh_used == true`.

Include a priority order that places `starter[0]` after the initial shop IDs and prove that buying a card which replaces `starter[0]` allows that old starter to appear in the refresh batch.

- [ ] **Step 3: Add failing atomic-service cases**

Extend `_assert_unchanged_after_failure()` to snapshot:

```gdscript
{
	"deck": shop.deck_ids.duplicate(),
	"offers": shop.offer_ids.duplicate(),
	"shown": shop.shown_offer_ids.duplicate(),
	"sold": shop.sold_offer_ids.duplicate(),
	"tickets": shop.intel_tickets,
	"refresh_used": shop.refresh_used,
	"intel_unlocked": shop.intel_unlocked,
	"purchase_count": shop.purchase_records.size(),
	"service_count": shop.service_records.size(),
}
```

Assert no mutation for insufficient refresh funds, second refresh, missing three-card reserve, insufficient intel funds, duplicate intel purchase, invalid snapshot, duplicate priority IDs, unknown priority IDs, and priority lists that do not cover the whole market.

- [ ] **Step 4: Add failing snapshot validation tests**

In `tests/shop_intel_snapshot_test.gd`, verify:

```gdscript
var area := AreaCatalog.new().gold_corridor()
var dealers := DealerCatalog.new()
var routes := ShopIntelSnapshot.routes(area.second_route_ids)
assert_equal(routes.validate(area, dealers), "", "valid second routes")
assert_equal(routes.kind, ShopIntelSnapshot.Kind.ROUTE_PAIR, "route kind")

var dealer := ShopIntelSnapshot.dealer(area.dealer_id, area.dealer_target)
assert_equal(dealer.validate(area, dealers), "", "valid dealer")
assert_equal(dealer.kind, ShopIntelSnapshot.Kind.DEALER, "dealer kind")
```

Also reject duplicate routes, unknown rooms, wrong route count, unknown dealer, nonpositive target, dealer mismatch, and a kind with fields from both variants.

- [ ] **Step 5: Run the aggregate domain suite and verify the new tests fail**

Run:

```powershell
$log = Join-Path $env:TEMP 'project-joker-shop-domain-red.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$markers = Select-String -Path $log -Pattern 'SCRIPT ERROR|Failed to load script'
if ($code -ne 0 -or $markers) { exit 1 }
```

Expected before implementation: nonzero exit or load/assertion failures for missing snapshot/service classes and methods.

- [ ] **Step 6: Implement `ShopIntelSnapshot`**

Use stable IDs only:

```gdscript
class_name ShopIntelSnapshot
extends RefCounted

enum Kind { ROUTE_PAIR, DEALER }

var kind: Kind
var route_ids: Array[StringName] = []
var dealer_id: StringName = &""
var dealer_target := 0

static func routes(ids: Array[StringName]) -> ShopIntelSnapshot:
	var snapshot := ShopIntelSnapshot.new()
	snapshot.kind = Kind.ROUTE_PAIR
	snapshot.route_ids.assign(ids)
	return snapshot

static func dealer(id: StringName, target: int) -> ShopIntelSnapshot:
	var snapshot := ShopIntelSnapshot.new()
	snapshot.kind = Kind.DEALER
	snapshot.dealer_id = id
	snapshot.dealer_target = target
	return snapshot
```

`structural_error()` checks kind-specific field shape without catalogs so `ShopSession`
can reject an invalid payload. `validate()` first calls `structural_error()`, then returns
the first concrete Chinese error from checking the selected variant against
`AreaDefinition` and `DealerCatalog`.

- [ ] **Step 7: Implement `ShopServiceRecord`**

```gdscript
class_name ShopServiceRecord
extends RefCounted

enum ServiceType { REFRESH, INTEL }

var shop_index: int
var service_type: ServiceType
var price: int
var intel_kind: int
```

The constructor rejects no data itself; `ShopSession` creates only validated records and `AreaRunSession` clones and validates them at boundaries.

- [ ] **Step 8: Refactor `ShopSession` around a market priority**

Keep the first four positional arguments compatible:

```gdscript
func _init(
	p_catalog: CardCatalog,
	p_deck_ids: Array[StringName],
	p_market_priority_ids: Array[StringName],
	p_intel_tickets: int,
	p_intel_snapshot: ShopIntelSnapshot = null,
	p_shop_index: int = 0,
	p_services_enabled: bool = false
) -> void:
```

For legacy three-offer callers, `p_services_enabled == false` means the passed IDs are the complete visible offer priority and both service methods return `当前商店不提供刷新与情报服务`.

For formal area shops:

- validate 12 unique known deck IDs;
- validate unique known market priority IDs;
- require the priority to contain every market ID passed by `AreaRunSession`;
- select the first three priority IDs not in the deck;
- initialize `shown_offer_ids` with those three IDs.

Implement a pure `_next_offer_batch(deck, shown) -> Array[StringName]` scan and only commit its result after all refresh validations pass.

- [ ] **Step 9: Implement atomic refresh and intel purchase**

```gdscript
func refresh_offers() -> OperationResult:
	if not services_enabled:
		return _fail("当前商店不提供刷新服务")
	if refresh_used:
		return _fail("本店已经刷新过候选")
	if intel_tickets < REFRESH_PRICE:
		return _fail("情报券不足，无法刷新")
	var next_offers := _next_offer_batch(deck_ids, shown_offer_ids)
	if next_offers.size() != 3:
		return _fail("没有三张未展示的新候选可供刷新")
	offer_ids.assign(next_offers)
	shown_offer_ids.append_array(next_offers)
	sold_offer_ids.clear()
	intel_tickets -= REFRESH_PRICE
	refresh_used = true
	service_records.append(
		ShopServiceRecord.new(shop_index, ShopServiceRecord.ServiceType.REFRESH, REFRESH_PRICE)
	)
	last_error = ""
	return OperationResult.new(true)
```

`purchase_intel()` validates service availability, `intel_snapshot.structural_error()`,
duplicate use, and funds before changing `intel_unlocked`, balance, or records.

- [ ] **Step 10: Run the aggregate domain suite and verify it passes**

Run the Task 1 command with log `project-joker-shop-domain-green.log`.

Expected: `PASS shop_session_test.gd`, `PASS shop_intel_snapshot_test.gd`, exit 0, and no script markers.

- [ ] **Step 11: Commit only Task 1 code**

```powershell
git add -- `
  scripts/run/shop_intel_snapshot.gd `
  scripts/run/shop_service_record.gd `
  scripts/run/shop_session.gd `
  tests/shop_session_test.gd `
  tests/shop_intel_snapshot_test.gd
git commit --only -m "feat: add deterministic shop services" -- `
  scripts/run/shop_intel_snapshot.gd `
  scripts/run/shop_service_record.gd `
  scripts/run/shop_session.gd `
  tests/shop_session_test.gd `
  tests/shop_intel_snapshot_test.gd
```

Confirm the staged design and plan documents remain staged after the commit.

---

### Task 2: Area Market, Future Precomputation, and Record Transfer

**Files:**
- Modify: `scripts/areas/area_definition.gd`
- Modify: `scripts/run/area_run_session.gd`
- Modify: `tests/gold_corridor_area_run_test.gd`
- Modify: `tests/mirror_hall_area_run_test.gd`
- Modify: `tests/faceless_hub_area_run_test.gd`

**Interfaces:**
- Consumes: Task 1 `ShopIntelSnapshot`, `ShopServiceRecord`, and formal `ShopSession` constructor.
- Produces: `AreaRunSession.market_ids: Array[StringName]`
- Produces: `AreaRunSession.pending_route_ids: Array[StringName]`
- Produces: `AreaRunSession.shop_service_history: Array[ShopServiceRecord]`
- Produces: `AreaRunSession.current_shop_intel() -> ShopIntelSnapshot`
- Extends: `completion_snapshot()["services"]`

- [ ] **Step 1: Write failing area-market and content-validation tests**

For all three definitions assert:

```gdscript
var area := AreaRunSession.new(SEED, definition)
assert_true(area.start().accepted, "area starts")
assert_true(area.market_ids.size() >= 18, "market contains deck plus offers")
assert_equal(_unique_count(area.market_ids), area.market_ids.size(), "market unique")
for card_id in area.deck_ids:
	assert_true(card_id in area.market_ids, "deck belongs to market")
assert_true(_off_deck(area.market_ids, area.deck_ids).size() >= 6, "six off deck")
```

Add invalid definitions with an unknown shop ID, duplicate shop ID, overlap that leaves fewer than six off-deck cards, and a current deck card outside the market. Invalid `start()` must leave `run_rng == null`.

- [ ] **Step 2: Write failing first-shop future-route tests**

After completing the first normal room:

1. Snapshot RNG before `open_shop()`.
2. Open the shop.
3. Save `shop_session.intel_snapshot.route_ids`.
4. Buy or skip intel and optionally refresh.
5. Save RNG immediately before `leave_shop()`.
6. Leave and assert actual `current_route_ids()` equals the saved route IDs.
7. Assert `leave_shop()` did not consume RNG for the route.

Run the same seed twice with identical operations and compare first offers, refresh offers, snapshot IDs, and final RNG.

- [ ] **Step 3: Write failing second-shop dealer tests**

For each area:

```gdscript
var intel := area.current_shop_intel()
assert_equal(intel.kind, ShopIntelSnapshot.Kind.DEALER, "dealer intel")
assert_equal(intel.dealer_id, area.area_definition.dealer_id, "dealer identity")
assert_equal(intel.dealer_target, area.area_definition.dealer_target, "dealer target")
```

Leave the shop and assert the created `ThreeRoundEncounterSession` uses the same dealer ID, target, encounter or round schedule. Buying or viewing intel must not change the dealer RNG state.

- [ ] **Step 4: Write failing service-transfer and restart tests**

Use both services in both shops. After each `leave_shop()`, assert the area history grows by exactly two validated records with correct shop indices `0` and `1`. Complete the area and assert `completion_snapshot()["services"]` contains dictionaries:

```gdscript
{
	"shop_index": 0,
	"service_type": ShopServiceRecord.ServiceType.REFRESH,
	"price": 1,
	"intel_kind": -1,
}
```

Restart and assert `market_ids`, `pending_route_ids`, histories, and service states reset and replay.

- [ ] **Step 5: Run the aggregate suite and verify the new area tests fail**

Use `project-joker-area-shop-red.log` with `tests/run_all.gd`.

Expected before implementation: failures for missing market, pending route, snapshot, and service history behavior.

- [ ] **Step 6: Add market validation to `AreaDefinition`**

Strengthen `_validate_shop_pool()`:

- shop IDs are known and unique;
- union of `starting_deck_ids` and `shop_offer_ids` is unique as a set;
- at least six union IDs are outside the 12-card entry deck.

Keep current `.tres` files unchanged.

- [ ] **Step 7: Initialize and reset area-owned shop state**

Add:

```gdscript
var market_ids: Array[StringName] = []
var pending_route_ids: Array[StringName] = []
var shop_service_history: Array[ShopServiceRecord] = []
```

In `start()`, build the market in a local array before committing state. In `_reset_owned_state()`, clear all three fields. Extend the test snapshot helper to include them.

- [ ] **Step 8: Precompute market priority and route/dealer snapshot atomically**

Refactor `open_shop()`:

```gdscript
var rng_before := run_rng.snapshot_state()
var priority: Array[StringName] = []
priority.assign(run_rng.shuffle(market_ids))
var intel := _build_shop_intel()
if intel == null:
	run_rng.restore_state(rng_before)
	return _fail(last_error)
var next_shop := ShopSession.new(
	card_catalog,
	deck_ids,
	priority,
	intel_tickets,
	intel,
	room_index,
	true
)
```

For `room_index == 0`, validate and shuffle `second_route_ids`, store them in both `pending_route_ids` and the route snapshot. For `room_index == 1`, build a dealer snapshot without starting the dealer encounter.

Only assign `shop_session`, `pending_route_ids`, and `phase` after all validations pass.

- [ ] **Step 9: Transfer records and consume the precomputed future**

Clone service records exactly as purchase records are cloned. On first leave, use `pending_route_ids` without `run_rng.shuffle()`. On second leave, pass both next histories into `_create_dealer()` and only commit them after the dealer session starts successfully.

Extend `_create_dealer()` parameters:

```gdscript
func _create_dealer(
	next_deck: Array[StringName],
	next_tickets: int,
	next_purchase_history: Array[ShopPurchaseRecord],
	next_service_history: Array[ShopServiceRecord]
) -> OperationResult:
```

- [ ] **Step 10: Extend `completion_snapshot()`**

Serialize service records into dictionaries with stable scalar fields. Do not serialize the live snapshot object or infer services from ticket differences.

- [ ] **Step 11: Run the aggregate suite and focused area suites**

Run `tests/run_all.gd` with `project-joker-area-shop-green.log`.

Expected: all domain suites pass, including the three area tests, exit 0, no script markers.

- [ ] **Step 12: Commit only Task 2 code**

```powershell
git add -- `
  scripts/areas/area_definition.gd `
  scripts/run/area_run_session.gd `
  tests/gold_corridor_area_run_test.gd `
  tests/mirror_hall_area_run_test.gd `
  tests/faceless_hub_area_run_test.gd
git commit --only -m "feat: precompute shop routes and dealer intel" -- `
  scripts/areas/area_definition.gd `
  scripts/run/area_run_session.gd `
  tests/gold_corridor_area_run_test.gd `
  tests/mirror_hall_area_run_test.gd `
  tests/faceless_hub_area_run_test.gd
```

---

### Task 3: Shop Service Controls and Refresh Confirmation

**Files:**
- Modify: `scenes/shop/shop_screen.tscn`
- Modify: `scripts/ui/shop/shop_screen.gd`
- Modify: `tests/area_run_ui_contract_test.gd`
- Modify: `tests/sfx_ui_contract_test.gd`

**Interfaces:**
- Consumes: Task 1 `ShopSession.refresh_offers()` and `purchase_intel()`.
- Produces: `ShopScreen.intel_view_requested(snapshot: ShopIntelSnapshot)`
- Produces stable nodes: `%ShopServiceStatusLabel`, `%RefreshOffersButton`, `%PurchaseIntelButton`, `%RefreshConfirmationDialog`.

- [ ] **Step 1: Write failing UI contract assertions**

Extend `area_run_ui_contract_test.gd` and `sfx_ui_contract_test.gd` to require:

```gdscript
for node_name in [
	"ShopServiceStatusLabel",
	"RefreshOffersButton",
	"PurchaseIntelButton",
	"RefreshConfirmationDialog",
]:
	assert_true(shop.get_node_or_null("%" + node_name) != null, node_name)
```

Bind a legacy service-disabled shop and assert the new service row is hidden. Bind a formal shop and assert the row is visible with both prices.

- [ ] **Step 2: Write failing script-level interaction tests**

Call the handlers directly after binding a formal session:

- refresh press opens the confirmation dialog without spending;
- cancel keeps the full shop snapshot;
- confirm calls `refresh_offers()`, spends one, and clears both selections;
- intel press purchases once and emits `intel_view_requested`;
- a second intel press emits again without spending;
- accepted refresh plays one specific confirmation cue;
- rejected service plays `error`;
- no generic click and specific service cue stack.

- [ ] **Step 3: Run `tests/run_all.gd` and verify UI contracts fail**

Use `project-joker-shop-ui-red.log`.

Expected: missing node/signal/handler failures.

- [ ] **Step 4: Add stable shop scene controls**

In `shop_screen.tscn`:

- add `ShopServiceStatusLabel` above the error row;
- add `RefreshOffersButton` and `PurchaseIntelButton` before `LeaveShopButton`;
- add a scene-owned `ConfirmationDialog` with explicit irreversible-refresh copy;
- keep all controls inside the existing 1920×1080 safe area.

Do not create these controls from script.

- [ ] **Step 5: Bind service state in `ShopScreen`**

Add:

```gdscript
signal intel_view_requested(snapshot: ShopIntelSnapshot)
```

`_refresh()` must set:

```gdscript
service_status_label.text = "刷新：%s　%s：%s" % [
	"已使用" if shop_session.refresh_used else "可用",
	"路线情报" if shop_session.intel_snapshot.kind == ShopIntelSnapshot.Kind.ROUTE_PAIR else "庄家情报",
	"已购" if shop_session.intel_unlocked else "未购",
]
```

Hide the service controls when `services_enabled == false`.

- [ ] **Step 6: Implement confirmation, refresh, and intel handlers**

On refresh button press, only open the dialog. On confirmed:

```gdscript
var result := shop_session.refresh_offers()
error_label.text = result.reason
if result.accepted:
	selected_offer_id = &""
	selected_deck_id = &""
	SfxAccess.play(self, &"shop_purchase")
else:
	SfxAccess.play(self, &"error")
_refresh()
```

On intel press, purchase only if locked; after success or when already unlocked, emit the snapshot. Never emit an invalid or locked snapshot.

- [ ] **Step 7: Run aggregate tests and verify they pass**

Use `project-joker-shop-ui-green.log`.

Expected: UI contract and SFX tests pass, exit 0, no script markers.

- [ ] **Step 8: Commit only Task 3 code**

```powershell
git add -- `
  scenes/shop/shop_screen.tscn `
  scripts/ui/shop/shop_screen.gd `
  tests/area_run_ui_contract_test.gd `
  tests/sfx_ui_contract_test.gd
git commit --only -m "feat: add shop refresh and intel controls" -- `
  scenes/shop/shop_screen.tscn `
  scripts/ui/shop/shop_screen.gd `
  tests/area_run_ui_contract_test.gd `
  tests/sfx_ui_contract_test.gd
```

---

### Task 4: Read-Only Route and Dealer Intel Overlay

**Files:**
- Create: `scenes/components/shop_intel_panel.tscn`
- Create: `scripts/ui/route_brief_formatter.gd`
- Create: `scripts/ui/shop/shop_intel_panel.gd`
- Modify: `scenes/run/area_run_screen.tscn`
- Modify: `scripts/ui/area_run_screen.gd`
- Modify: `scripts/ui/route_choice_panel.gd`
- Modify: `tests/area_run_ui_contract_test.gd`
- Create: `tests/shop_intel_panel_test.gd`

**Interfaces:**
- Consumes: `ShopScreen.intel_view_requested`.
- Produces: `ShopIntelPanel.bind_snapshot(snapshot, area_definition, deck_ids, card_catalog, dealer_catalog) -> bool`
- Produces: `ShopIntelPanel.close() -> void`
- Produces stable node: `%ShopIntelPanel`.
- Produces: `RouteBriefFormatter.rule_text(rule: RuleDefinition) -> String`
- Produces: `RouteBriefFormatter.matching_card_names(room: RoomDefinition, deck_ids: Array[StringName], card_catalog: CardCatalog) -> Array[String]`
- Produces: `RouteBriefFormatter.synergy_text(names: Array[String]) -> String`

- [ ] **Step 1: Write failing panel content tests**

Instantiate `shop_intel_panel.tscn` and bind:

1. Gold route snapshot — assert both names, goals, rewards, three rule rows each, and current-deck synergy.
2. Gold dealer snapshot — assert 铁算盘, target 150, fixed mechanism, three repeated-round labels, and rule details.
3. Mirror dealer snapshot — assert 镜面夫人, reverse direction, and mirror-copy mechanism.
4. Faceless dealer snapshot — assert three distinct rounds, each direction, both final restriction names, and their descriptions.

Invalid snapshot, missing area, unknown card in deck, dealer mismatch, and incomplete schedule must fail closed.

- [ ] **Step 2: Extend the shared scene contract**

Require `%ShopIntelPanel` under all three inherited formal area scenes and require its stable route/dealer/close nodes. Assert it starts hidden with `MOUSE_FILTER_IGNORE`.

- [ ] **Step 3: Run aggregate tests and verify the panel tests fail**

Use `project-joker-intel-panel-red.log`.

Expected: scene/script/nodes do not yet exist.

- [ ] **Step 4: Build the scene-first blocking overlay**

Create `shop_intel_panel.tscn` with:

- full-screen dimmer;
- safe-area ledger;
- title and subtitle;
- `RouteMode` containing two fixed route columns and three fixed rule labels per column;
- `DealerMode` containing dealer header, mechanism, target, three fixed round panels, direction labels, and a restrictions section;
- `IntelErrorLabel`;
- `CloseIntelButton`.

Use a `ScrollContainer` inside dealer mode so 1280×720 can show all content without clipping. Keep the close button outside the scroll body.

- [ ] **Step 5: Implement fail-closed binding**

```gdscript
func bind_snapshot(
	snapshot: ShopIntelSnapshot,
	area_definition: AreaDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog,
	dealer_catalog: DealerCatalog
) -> bool:
	var error := snapshot.validate(area_definition, dealer_catalog)
	if not error.is_empty():
		return _fail_closed(error)
	if snapshot.kind == ShopIntelSnapshot.Kind.ROUTE_PAIR:
		_bind_routes(...)
	else:
		_bind_dealer(...)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	return true
```

Fixed dealer encounters repeat `area_definition.dealer_encounter` for rounds 1–3. Scheduled dealers bind `round_plans[0..2]`, their direction, and `restriction_options()`.

- [ ] **Step 6: Implement and share route copy formatting**

Create `route_brief_formatter.gd` with three static pure functions:

```gdscript
class_name RouteBriefFormatter
extends RefCounted

static func rule_text(rule: RuleDefinition) -> String:
	return "%s\n%d 个骰位 · 系数 ×%d%s" % [
		rule.display_name,
		rule.slot_count,
		rule.coefficient,
		_condition_hint(rule),
	]

static func matching_card_names(
	room: RoomDefinition,
	deck_ids: Array[StringName],
	card_catalog: CardCatalog
) -> Array[String]:
	var names: Array[String] = []
	# Append each known card once when any stable tag matches, then sort.
	return names

static func synergy_text(names: Array[String]) -> String:
	if names.is_empty():
		return "当前牌组无直接标签匹配"
	var visible_names := names.slice(0, 4)
	var copy := "、".join(visible_names)
	if names.size() > 4:
		copy += " 等 %d 张" % names.size()
	return copy
```

`_condition_hint()` must match every `RuleTableTemplate.ConditionKind`:

- `ANY_FILLED` uses the template description;
- exact, minimum, and maximum sums use `target_value`;
- ranges use `minimum_value..maximum_value`;
- fixed difference uses `difference`;
- slot targets join `slot_targets`;
- equal, distinct, even, odd, same-parity, consecutive, strict-order, and mirrored
  use the template display name without an extra numeric parameter.

It must not retain the current exact-sum-only branch.

Update `RouteChoicePanel` to use the same helpers. Preserve its existing button signals, local gold styles, and visible text contract.

- [ ] **Step 7: Wire the overlay through `AreaRunScreen`**

Add:

```gdscript
@onready var shop_intel_panel: ShopIntelPanel = %ShopIntelPanel
```

Connect `shop_screen.intel_view_requested` to:

```gdscript
func _on_shop_intel_view_requested(snapshot: ShopIntelSnapshot) -> void:
	var bound := shop_intel_panel.bind_snapshot(
		snapshot,
		area_session.area_definition,
		area_session.shop_session.deck_ids,
		area_session.card_catalog,
		area_session.dealer_catalog
	)
	if not bound:
		shop_screen.get_node("%ShopErrorLabel").text = "已购情报无法显示"
```

Close the panel on start, route selection, encounter binding, shop leave, restart, and return home. Viewing intel must not change the domain.

- [ ] **Step 8: Run aggregate tests and verify they pass**

Use `project-joker-intel-panel-green.log`.

Expected: panel tests and shared route-choice tests pass, exit 0, no script markers.

- [ ] **Step 9: Commit only Task 4 code**

```powershell
git add -- `
  scenes/components/shop_intel_panel.tscn `
  scripts/ui/route_brief_formatter.gd `
  scripts/ui/shop/shop_intel_panel.gd `
  scenes/run/area_run_screen.tscn `
  scripts/ui/area_run_screen.gd `
  scripts/ui/route_choice_panel.gd `
  tests/area_run_ui_contract_test.gd `
  tests/shop_intel_panel_test.gd
git commit --only -m "feat: preview routes and dealers from the shop" -- `
  scenes/components/shop_intel_panel.tscn `
  scripts/ui/route_brief_formatter.gd `
  scripts/ui/shop/shop_intel_panel.gd `
  scenes/run/area_run_screen.tscn `
  scripts/ui/area_run_screen.gd `
  scripts/ui/route_choice_panel.gd `
  tests/area_run_ui_contract_test.gd `
  tests/shop_intel_panel_test.gd
```

---

### Task 5: Service History in the Area Completion Ledger

**Files:**
- Modify: `scripts/ui/area_complete_panel.gd`
- Modify: `scenes/components/area_complete_panel.tscn`
- Modify: `tests/gold_corridor_ui_contract_test.gd`
- Modify: `tests/mirror_hall_area_run_test.gd`
- Modify: `tests/faceless_hub_area_run_test.gd`

**Interfaces:**
- Consumes: `completion_snapshot()["services"]` from Task 2.
- Produces: validated combined transaction copy in `%PurchaseHistoryLabel`.
- Preserves: summaries with zero service records display a concrete no-service sentence.

- [ ] **Step 1: Write failing summary validation tests**

Require `services` in `AreaCompletePanel.REQUIRED_KEYS`. Reject:

- non-array services;
- missing `shop_index`, `service_type`, `price`, or `intel_kind`;
- shop indices outside `0..1`;
- unknown service type;
- non-1 price;
- refresh with a nonempty intel kind;
- intel with an invalid snapshot kind.

Valid zero-service summaries must still bind.

- [ ] **Step 2: Write failing rendering tests**

For two purchases plus four service records, assert `%PurchaseHistoryLabel` contains:

```text
商店 1｜整批刷新（1 情报券）
商店 1｜路线情报（1 情报券）
商店 2｜整批刷新（1 情报券）
商店 2｜庄家情报（1 情报券）
```

Also assert purchase arrow rows remain present and the final balance comes directly from `summary["intel_tickets"]`.

- [ ] **Step 3: Run aggregate tests and verify summary tests fail**

Use `project-joker-service-summary-red.log`.

- [ ] **Step 4: Validate and format service records**

Add `_service_text(services: Array) -> String` and join it with `_purchase_text()` under an `情报交换记录` heading. Do not calculate services from initial/final balance.

- [ ] **Step 5: Adjust the fixed ledger scene**

Increase or restructure the history panel using a `ScrollContainer` inside the existing left column. Preserve the two-column overall layout and all existing unique node names used by input checks.

- [ ] **Step 6: Run aggregate tests and verify they pass**

Use `project-joker-service-summary-green.log`.

- [ ] **Step 7: Commit only Task 5 code**

```powershell
git add -- `
  scripts/ui/area_complete_panel.gd `
  scenes/components/area_complete_panel.tscn `
  tests/gold_corridor_ui_contract_test.gd `
  tests/mirror_hall_area_run_test.gd `
  tests/faceless_hub_area_run_test.gd
git commit --only -m "feat: summarize shop service spending" -- `
  scripts/ui/area_complete_panel.gd `
  scenes/components/area_complete_panel.tscn `
  tests/gold_corridor_ui_contract_test.gd `
  tests/mirror_hall_area_run_test.gd `
  tests/faceless_hub_area_run_test.gd
```

---

### Task 6: Real Input, Dual-Resolution Layout, and Full Regression

**Files:**
- Create: `tests/shop_services_input_self_check.gd`
- Create: `tests/shop_intel_layout_self_check.gd`
- Modify: `tests/gold_corridor_input_self_check.gd`

**Interfaces:**
- Consumes: all previous task interfaces.
- Produces: pointer-level acceptance for the complete service flow.
- Produces: layout acceptance at `1280×720` and `1920×1080`.

- [ ] **Step 1: Build the real-pointer service self-check**

Drive a formal Gold Corridor area to the first shop, then use actual mouse events to:

1. Click refresh and verify the confirmation opens without spending.
2. Cancel and verify candidate IDs and balance stay unchanged.
3. Reopen and confirm; assert three new IDs, one ticket spent, selections cleared.
4. Click purchase-route-intel; assert one ticket spent and overlay visible.
5. Click behind the overlay and prove shop state does not change.
6. Close and reopen purchased intel; assert no second spend.
7. Buy a candidate, leave, and assert actual route IDs equal preview IDs.
8. Reach the second shop, purchase dealer intel, and assert 铁算盘 identity, target, mechanism, and three rounds.
9. Leave and assert the actual dealer session matches the preview.

Use a controlled test ticket balance without changing content resources.

- [ ] **Step 2: Add old-card buyback to the input path**

In the first shop, replace a known starter card. At the second shop, use the deterministic priority fixture or injected seed to make that old card visible, click it, replace another deck card, and assert the old card returns to the 12-card deck.

- [ ] **Step 3: Build the dual-resolution layout self-check**

At both root sizes:

```gdscript
for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
	root.size = size
	await _bind_route_mode()
	_assert_inside(%RouteMode, root.get_visible_rect())
	await _bind_dealer_mode()
	_assert_inside(%DealerMode, root.get_visible_rect())
	_assert_true(%CloseIntelButton.get_global_rect().size.x >= 120.0, "close target")
```

Check:

- service buttons fit on the shop footer;
- route columns remain side by side and readable;
- dealer content scrolls instead of clipping;
- both final restrictions are reachable;
- close releases input to the shop.

- [ ] **Step 4: Extend the existing Gold end-to-end check**

Keep its current route, purchase, dealer, engraving, restart, failure, and home contracts. Add assertions that when services are used, `%PurchaseHistoryLabel` contains both service rows and the final ticket balance equals the domain snapshot.

- [ ] **Step 5: Run focused input and layout checks**

Run each with its own explicit log:

```powershell
$checks = @(
  'shop_services_input_self_check.gd',
  'shop_intel_layout_self_check.gd',
  'gold_corridor_input_self_check.gd',
  'mirror_hall_end_to_end_self_check.gd',
  'faceless_hub_end_to_end_self_check.gd',
  'gold_corridor_guide_input_self_check.gd',
  'mirror_hall_guide_input_self_check.gd',
  'faceless_hub_guide_input_self_check.gd',
  'tutorial_input_self_check.gd',
  'settings_input_self_check.gd',
  'main_navigation_input_self_check.gd'
)
foreach ($check in $checks) {
  $log = Join-Path $env:TEMP ("project-joker-" + $check + ".log")
  & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
    --headless --path . --log-file $log -s ("res://tests/" + $check)
  $code = $LASTEXITCODE
  $markers = Select-String -Path $log -Pattern 'SCRIPT ERROR|Failed to load script'
  if ($code -ne 0 -or $markers) { exit 1 }
}
```

Expected: every check prints its PASS marker, exits 0, and has no script markers.

- [ ] **Step 6: Run the full synchronous suite**

```powershell
$log = Join-Path $env:TEMP 'project-joker-shop-services-run-all.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$markers = Select-String -Path $log -Pattern 'SCRIPT ERROR|Failed to load script'
if ($code -ne 0 -or $markers) { exit 1 }
```

Expected: all suites pass, exit 0, no script markers.

- [ ] **Step 7: Run the main scene headlessly**

```powershell
$log = Join-Path $env:TEMP 'project-joker-shop-services-main.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $log --quit
$code = $LASTEXITCODE
$markers = Select-String -Path $log -Pattern 'SCRIPT ERROR|Failed to load script'
if ($code -ne 0 -or $markers) { exit 1 }
```

Expected: exit 0 and no script markers.

- [ ] **Step 8: Audit scope and staged-document boundary**

Run:

```powershell
git diff --check
git diff --cached --check
git status --short
git diff --name-only
git diff --cached --name-only
```

Confirm:

- only intended code/test files are unstaged or committed;
- all design/plan documents remain staged;
- no document appears in any code commit;
- no `.tres` balance content or `project.godot` changed;
- no reroll, betting, probability-trigger, or random-reward copy was added.

- [ ] **Step 9: Commit only Task 6 test code and any proven fixes**

```powershell
git add -- `
  tests/shop_services_input_self_check.gd `
  tests/shop_intel_layout_self_check.gd `
  tests/gold_corridor_input_self_check.gd
git commit --only -m "test: verify shop services end to end" -- `
  tests/shop_services_input_self_check.gd `
  tests/shop_intel_layout_self_check.gd `
  tests/gold_corridor_input_self_check.gd
```

If acceptance uncovered a code defect, include only the exact repaired files in this commit or make a separate explicit-path fix commit. Never include `docs/`.

- [ ] **Step 10: Record final evidence**

Report:

- commit IDs and messages;
- `run_all.gd` suite count;
- each focused self-check PASS;
- main-scene exit and script-marker result;
- `git diff --check` results;
- final `git status --short`;
- explicit confirmation that all design/plan documents remain staged and uncommitted.
