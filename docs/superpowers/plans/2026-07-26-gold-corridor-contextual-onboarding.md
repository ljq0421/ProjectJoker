# Gold Corridor Contextual Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 为正式金线回廊增加四个首次出现、可跳过且不改变玩法状态的区域级情境提示，并保留基础教程与旧铁算盘原型引导。

**Architecture:** 新增独立的 `GoldCorridorGuideProgressStore` 和纯逻辑 `GoldCorridorGuideFlow`，复用现有 `IronAbacusGuideOverlay` 作为渲染器。`GoldCorridorRunScreen` 只在阶段界面绑定完成后请求提示、解析真实聚焦目标并路由持久化警告；`SingleEncounterScreen` 负责三个互不干扰的重看入口。

**Tech Stack:** Godot 4.6.1、GDScript、`.tscn` 场景、`ConfigFile`、现有无第三方依赖的自检框架、PowerShell。

## Global Constraints

- 正式区域默认玩家已经完成或主动跳过基础三轨教程；不得重复教授拖骰、校准、用牌、预览、撤销或结算动作。
- 区域提示固定为 `route`、`shop`、`dealer`、`engraving` 四个 ID，进度固定为 `1/4` 到 `4/4`。
- 第二次路线、第二次商店、失败、重试、重开和完成账目不得自动弹出新提示。
- 提示只解释公开取舍，不推荐路线、牌、刻印、骰子或骰面。
- 提示交互不得修改 `AreaRunSession`、牌组、情报券、骰子、RNG、轮次或结算报告。
- 正式区域安装刻印后直接完成，不得增加刻印验证提示。
- 复用 `scenes/components/iron_abacus_guide_overlay.tscn`；不得复制第二套遮罩场景，也不得重命名现有 `IronAbacusGuideOverlay` 类。
- 基础教程、`iron_abacus_guide_v1` 和 `gold_corridor_guide_v1` 必须保留式写入同一个配置文件并互不覆盖。
- 损坏文件不覆盖原内容；加载错误必须阻止后续持久化覆盖该文件。
- 配置损坏、写入失败或聚焦目标缺失不得阻断游戏。
- 生产文案不得新增“下注、筹码、赌注、贷款、借贷、充值、真钱、现金、概率触发、随机触发”等赌博导向表达。
- 已授权直接在 `master` 开发；不得创建工作树、分支、PR 或远端推送。
- 设计与计划文档只暂存、不提交；所有代码提交必须使用显式路径或 `git commit --only`。
- 不修改、不暂存、不提交、不还原现有 `project.godot`。
- 每次运行 Godot 都必须使用 `D:\Godot\Godot_v4.6.1-stable_win64_console.exe` 和显式可写的 `--log-file`。
- Godot 检查只有在退出码为 `0` 且日志不含 `SCRIPT ERROR|Failed to load script` 时才算通过。
- 临时截图脚本、生成 UID 和 PNG 目录必须在最终提交前删除。

## File Structure

### New production files

- `scripts/ui/tutorial/gold_corridor_guide_progress_store.gd`
  - 只负责 `[gold_corridor_guide_v1]` 的保留式读取、写入、永久关闭与重置。
- `scripts/ui/tutorial/gold_corridor_guide_progress_store.gd.uid`
  - 由 Godot 编辑器导入生成并跟踪。
- `scripts/ui/tutorial/gold_corridor_guide_flow.gd`
  - 定义四张提示卡规格和单次运行去重，不访问场景树或领域状态。
- `scripts/ui/tutorial/gold_corridor_guide_flow.gd.uid`
  - 由 Godot 编辑器导入生成并跟踪。

### Modified production files

- `scripts/ui/tutorial/iron_abacus_guide_overlay.gd`
  - 支持可选 `progress_label`，默认仍显示“进阶提示”。
- `scenes/run/gold_corridor_run_screen.tscn`
  - 实例化现有遮罩为 `%GoldCorridorGuideOverlay`，层级高于区域所有面板。
- `scripts/ui/gold_corridor_run_screen.gd`
  - 编排四个提示、目标解析、关闭时机和警告路由。
- `scenes/run/single_encounter_screen.tscn`
  - 重命名旧进阶重看按钮文案并增加“重看区域提示”按钮。
- `scripts/ui/single_encounter_screen.gd`
  - 连接新按钮、重置区域提示并向正式区域传递自定义配置路径。

### New durable test files

- `tests/gold_corridor_guide_progress_store_test.gd`
- `tests/gold_corridor_guide_progress_store_test.gd.uid`
- `tests/gold_corridor_guide_flow_test.gd`
- `tests/gold_corridor_guide_flow_test.gd.uid`
- `tests/gold_corridor_guide_input_self_check.gd`
- `tests/gold_corridor_guide_input_self_check.gd.uid`
- `tests/gold_corridor_guide_layout_self_check.gd`
- `tests/gold_corridor_guide_layout_self_check.gd.uid`

### Modified test files

- `tests/iron_abacus_guide_ui_contract_test.gd`
  - 验证自定义“区域提示”和旧默认“进阶提示”都正确。
- `tests/ui_component_contract_test.gd`
  - 验证正式区域拥有遮罩和入口拥有三个重看按钮。
- `tests/gold_corridor_input_self_check.gd`
  - 显式关闭区域提示，保持原完整流程检查单一职责。
- `tests/gold_corridor_layout_self_check.gd`
  - 显式关闭区域提示，保持原区域布局与可玩性检查单一职责。
- `tests/single_encounter_layout_self_check.gd`
  - 验证新增第四个入口按钮仍在安全区内。
- `tests/stage5_guide_input_self_check.gd`
  - 验证改名后的旧按钮仍进入旧五点原型。
- `tests/stage5_guide_layout_self_check.gd`
  - 验证遮罩默认标签仍是“进阶提示”。

---

### Task 1: Add Independent Gold Corridor Guide Persistence

**Files:**

- Create: `scripts/ui/tutorial/gold_corridor_guide_progress_store.gd`
- Create after import: `scripts/ui/tutorial/gold_corridor_guide_progress_store.gd.uid`
- Create: `tests/gold_corridor_guide_progress_store_test.gd`
- Create after import: `tests/gold_corridor_guide_progress_store_test.gd.uid`

**Interfaces:**

- Produces: `GoldCorridorGuideProgressStore.new(path: String = "user://onboarding.cfg")`
- Produces: `snapshot() -> Dictionary`
- Produces: `initial_load_error() -> Error`
- Produces: `is_dismissed() -> bool`
- Produces: `is_seen(checkpoint_id: StringName) -> bool`
- Produces: `mark_seen(checkpoint_id: StringName) -> Error`
- Produces: `dismiss_all() -> Error`
- Produces: `reset() -> Error`
- Preserves: all existing `ConfigFile` sections and bytes of a corrupt source file

- [x] **Step 1: Write the failing progress-store suite**

Create `tests/gold_corridor_guide_progress_store_test.gd` with these stable IDs:

```gdscript
extends "res://tests/test_case.gd"

const StoreScript = preload(
	"res://scripts/ui/tutorial/gold_corridor_guide_progress_store.gd"
)

const CHECKPOINTS: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

func run() -> void:
	_test_missing_file_and_round_trip()
	_test_section_preservation_and_reset()
	_test_dismiss_does_not_forge_seen()
	_test_unknown_checkpoint_is_atomic()
	_test_corrupt_file_is_not_overwritten()
	_test_write_failure_retains_memory()
```

Implement the six test functions with the following exact assertions:

```gdscript
func _test_missing_file_and_round_trip() -> void:
	var path := _temp_path("round-trip")
	DirAccess.remove_absolute(path)
	var first = StoreScript.new(path)
	assert_equal(first.initial_load_error(), OK, "missing file should load")
	assert_false(first.is_dismissed(), "fresh guide should not be dismissed")
	for checkpoint_id in CHECKPOINTS:
		assert_false(first.is_seen(checkpoint_id), "checkpoint should begin unseen")
		assert_equal(first.mark_seen(checkpoint_id), OK, "checkpoint should save")
		assert_true(first.is_seen(checkpoint_id), "memory should update")
	var reloaded = StoreScript.new(path)
	for checkpoint_id in CHECKPOINTS:
		assert_true(reloaded.is_seen(checkpoint_id), "seen state should reload")
	DirAccess.remove_absolute(path)

func _test_section_preservation_and_reset() -> void:
	var path := _temp_path("preserve")
	DirAccess.remove_absolute(path)
	var seeded := ConfigFile.new()
	seeded.set_value("onboarding", "done", true)
	seeded.set_value("iron_abacus_guide_v1", "seen_shop", true)
	seeded.set_value("foreign_section", "value", "keep")
	assert_equal(seeded.save(path), OK, "fixture config should save")

	var store = StoreScript.new(path)
	assert_equal(store.mark_seen(&"route"), OK, "route should save")
	assert_equal(store.dismiss_all(), OK, "dismiss should save")
	assert_equal(store.reset(), OK, "reset should save")

	var reloaded := ConfigFile.new()
	assert_equal(reloaded.load(path), OK, "saved config should reload")
	assert_true(
		bool(reloaded.get_value("onboarding", "done", false)),
		"base tutorial section should survive"
	)
	assert_true(
		bool(reloaded.get_value("iron_abacus_guide_v1", "seen_shop", false)),
		"old guide section should survive"
	)
	assert_equal(
		reloaded.get_value("foreign_section", "value", ""),
		"keep",
		"foreign section should survive"
	)
	for checkpoint_id in CHECKPOINTS:
		assert_false(store.is_seen(checkpoint_id), "reset should clear seen")
	assert_false(store.is_dismissed(), "reset should clear dismissed")
	DirAccess.remove_absolute(path)

func _test_dismiss_does_not_forge_seen() -> void:
	var path := _temp_path("dismiss")
	DirAccess.remove_absolute(path)
	var store = StoreScript.new(path)
	assert_equal(store.dismiss_all(), OK, "dismiss should save")
	assert_true(store.is_dismissed(), "dismiss should update memory")
	for checkpoint_id in CHECKPOINTS:
		assert_false(
			store.is_seen(checkpoint_id),
			"dismiss should not forge checkpoint history"
		)
	DirAccess.remove_absolute(path)

func _test_unknown_checkpoint_is_atomic() -> void:
	var path := _temp_path("unknown")
	DirAccess.remove_absolute(path)
	var store = StoreScript.new(path)
	var before: Dictionary = store.snapshot()
	assert_equal(
		store.mark_seen(&"unknown"),
		ERR_INVALID_PARAMETER,
		"unknown checkpoint should be rejected"
	)
	assert_equal(store.snapshot(), before, "unknown checkpoint must be atomic")
	assert_false(FileAccess.file_exists(path), "unknown ID should not create file")

func _test_corrupt_file_is_not_overwritten() -> void:
	var path := _temp_path("corrupt")
	DirAccess.remove_absolute(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "corrupt fixture should open")
	if file == null:
		return
	file.store_string("[broken\nvalue")
	file.close()
	var original := FileAccess.get_file_as_string(path)
	var store = StoreScript.new(path)
	assert_true(store.initial_load_error() != OK, "corruption should report")
	assert_true(store.mark_seen(&"route") != OK, "corrupt file should block save")
	assert_true(store.is_seen(&"route"), "failed save should retain memory")
	assert_equal(
		FileAccess.get_file_as_string(path),
		original,
		"corrupt bytes must remain unchanged"
	)
	DirAccess.remove_absolute(path)

func _test_write_failure_retains_memory() -> void:
	var missing_parent := OS.get_temp_dir().path_join(
		"project-joker-missing-guide-dir-%d" % Time.get_ticks_usec()
	)
	var path := missing_parent.path_join("onboarding.cfg")
	var store = StoreScript.new(path)
	assert_true(store.mark_seen(&"dealer") != OK, "write should fail")
	assert_true(store.is_seen(&"dealer"), "failed write should retain memory")
	assert_false(FileAccess.file_exists(path), "failed write should create nothing")

func _temp_path(label: String) -> String:
	return OS.get_temp_dir().path_join(
		"project-joker-gold-guide-%s-%d.cfg" % [
			label,
			Time.get_ticks_usec(),
		]
	)
```

- [x] **Step 2: Run the suite and confirm the new store is missing**

Run:

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-guide-store-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  -s res://tests/run_all.gd
$code = $LASTEXITCODE
Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
exit $code
```

Expected: nonzero exit because
`gold_corridor_guide_progress_store.gd` does not exist. This missing-script
failure is the intended red state.

- [x] **Step 3: Implement the minimal preserving store**

Create:

```gdscript
class_name GoldCorridorGuideProgressStore
extends RefCounted

const SECTION := "gold_corridor_guide_v1"
const DISMISSED_KEY := "dismissed"
const CHECKPOINT_KEY_BY_ID := {
	&"route": "seen_route",
	&"shop": "seen_shop",
	&"dealer": "seen_dealer",
	&"engraving": "seen_engraving",
}

var config_path: String
var _values: Dictionary = {}
var _initial_error: Error = OK
var _write_blocked := false

func _init(path: String = "user://onboarding.cfg") -> void:
	config_path = path
	_values = _default_values()
	_load_existing()

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func initial_load_error() -> Error:
	return _initial_error

func is_dismissed() -> bool:
	return bool(_values.get(DISMISSED_KEY, false))

func is_seen(checkpoint_id: StringName) -> bool:
	if not CHECKPOINT_KEY_BY_ID.has(checkpoint_id):
		return false
	return bool(_values.get(CHECKPOINT_KEY_BY_ID[checkpoint_id], false))

func mark_seen(checkpoint_id: StringName) -> Error:
	if not CHECKPOINT_KEY_BY_ID.has(checkpoint_id):
		return ERR_INVALID_PARAMETER
	_values[CHECKPOINT_KEY_BY_ID[checkpoint_id]] = true
	return _persist()

func dismiss_all() -> Error:
	_values[DISMISSED_KEY] = true
	return _persist()

func reset() -> Error:
	_values = _default_values()
	return _persist()

func _default_values() -> Dictionary:
	var values := {DISMISSED_KEY: false}
	for key in CHECKPOINT_KEY_BY_ID.values():
		values[key] = false
	return values

func _load_existing() -> void:
	var config := ConfigFile.new()
	var result := config.load(config_path)
	if result == ERR_FILE_NOT_FOUND:
		return
	if result != OK:
		_initial_error = result
		_write_blocked = true
		return
	_values[DISMISSED_KEY] = bool(
		config.get_value(SECTION, DISMISSED_KEY, false)
	)
	for key in CHECKPOINT_KEY_BY_ID.values():
		_values[key] = bool(config.get_value(SECTION, key, false))

func _persist() -> Error:
	if _write_blocked:
		return _initial_error
	var config := ConfigFile.new()
	var load_result := config.load(config_path)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		_initial_error = load_result
		_write_blocked = true
		return load_result
	config.set_value(SECTION, DISMISSED_KEY, is_dismissed())
	for key in CHECKPOINT_KEY_BY_ID.values():
		config.set_value(SECTION, key, bool(_values.get(key, false)))
	return config.save(config_path)
```

Do not subclass `IronAbacusGuideProgressStore`; the new class owns a different
schema and must remain independently resettable.

- [x] **Step 4: Import scripts and verify generated UIDs**

Run:

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-guide-store-import.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --editor `
  --quit `
  --path . `
  --log-file $log
$code = $LASTEXITCODE
$bad = @(Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script")
Write-Output "EXIT=$code SCRIPT_FAILURES=$($bad.Count)"
Write-Output "SCRIPT_UID=$(Test-Path scripts/ui/tutorial/gold_corridor_guide_progress_store.gd.uid)"
Write-Output "TEST_UID=$(Test-Path tests/gold_corridor_guide_progress_store_test.gd.uid)"
if ($code -ne 0 -or $bad.Count -gt 0) { exit 1 }
```

Expected: exit `0`, empty script-error scan, and both UID checks are `True`.
Ignore only the known sandbox warning about saving global Godot editor settings.

- [x] **Step 5: Run all synchronous suites**

Run with
`$env:TEMP\project-joker-gold-guide-store-green.log`:

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-guide-store-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  -s res://tests/run_all.gd
$code = $LASTEXITCODE
$bad = @(Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script")
Write-Output "EXIT=$code SCRIPT_FAILURES=$($bad.Count)"
if ($code -ne 0 -or $bad.Count -gt 0) { exit 1 }
```

Expected: all suites pass. The corrupt-file fixture may intentionally write a
`ConfigFile parse error`; it is not a script-load failure and the suite must
still exit `0`.

- [x] **Step 6: Commit only the store and its test**

```powershell
git add -- `
  scripts/ui/tutorial/gold_corridor_guide_progress_store.gd `
  scripts/ui/tutorial/gold_corridor_guide_progress_store.gd.uid `
  tests/gold_corridor_guide_progress_store_test.gd `
  tests/gold_corridor_guide_progress_store_test.gd.uid

git commit --only -m "feat: add gold corridor guide progress" -- `
  scripts/ui/tutorial/gold_corridor_guide_progress_store.gd `
  scripts/ui/tutorial/gold_corridor_guide_progress_store.gd.uid `
  tests/gold_corridor_guide_progress_store_test.gd `
  tests/gold_corridor_guide_progress_store_test.gd.uid
```

Confirm staged documents remain staged and `project.godot` remains unstaged.

---

### Task 2: Define the Four-Checkpoint Pure Guide Flow

**Files:**

- Create: `scripts/ui/tutorial/gold_corridor_guide_flow.gd`
- Create after import: `scripts/ui/tutorial/gold_corridor_guide_flow.gd.uid`
- Create: `tests/gold_corridor_guide_flow_test.gd`
- Create after import: `tests/gold_corridor_guide_flow_test.gd.uid`

**Interfaces:**

- Consumes: progress snapshots from
  `GoldCorridorGuideProgressStore.snapshot() -> Dictionary`
- Produces: `checkpoint_ids() -> Array[StringName]`
- Produces: `card_spec(checkpoint_id: StringName) -> Dictionary`
- Produces:
  `should_present(checkpoint_id: StringName, snapshot: Dictionary) -> bool`
- Produces: `mark_requested(checkpoint_id: StringName) -> bool`
- Card-spec keys: `id`, `progress_label`, `progress_index`,
  `progress_total`, `title`, `instruction`, `target_ids`

- [x] **Step 1: Write the failing flow suite**

Create `tests/gold_corridor_guide_flow_test.gd`:

```gdscript
extends "res://tests/test_case.gd"

const FlowScript = preload(
	"res://scripts/ui/tutorial/gold_corridor_guide_flow.gd"
)
const EXPECTED_ORDER: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

func run() -> void:
	_test_order_and_complete_specs()
	_test_exact_strategy_copy()
	_test_seen_and_dismissed_filtering()
	_test_run_request_deduplication()
	_test_unknown_checkpoint_is_rejected()
```

The complete-spec test must assert:

```gdscript
var flow = FlowScript.new()
assert_equal(flow.checkpoint_ids(), EXPECTED_ORDER, "order should be stable")
for index in range(EXPECTED_ORDER.size()):
	var checkpoint_id := EXPECTED_ORDER[index]
	var spec: Dictionary = flow.card_spec(checkpoint_id)
	assert_equal(spec.get("id"), checkpoint_id, "spec should retain ID")
	assert_equal(spec.get("progress_label"), "区域提示", "label should be exact")
	assert_equal(spec.get("progress_index"), index + 1, "index should be stable")
	assert_equal(spec.get("progress_total"), 4, "total should be four")
	assert_false(String(spec.get("title", "")).is_empty(), "title is required")
	assert_false(
		String(spec.get("instruction", "")).is_empty(),
		"instruction is required"
	)
	assert_true(
		Array(spec.get("target_ids", [])).size() > 0,
		"targets are required"
	)
```

The exact-copy assertions must check:

```gdscript
assert_true(
	String(flow.card_spec(&"route").get("instruction")).contains(
		"三轮共同完成累计目标"
	),
	"route copy should explain shared accumulation"
)
assert_true(
	String(flow.card_spec(&"shop").get("instruction")).contains(
		"第二个房间和铁算盘"
	),
	"shop copy should explain inheritance"
)
assert_true(
	String(flow.card_spec(&"shop").get("instruction")).contains(
		"不购买直接离开"
	),
	"shop copy should allow leaving"
)
assert_true(
	String(flow.card_spec(&"dealer").get("instruction")).contains("150"),
	"dealer copy should state target"
)
assert_true(
	String(flow.card_spec(&"dealer").get("instruction")).contains("减少 2"),
	"dealer copy should state penalty"
)
assert_true(
	String(flow.card_spec(&"engraving").get("instruction")).contains(
		"不再进入刻印验证局"
	),
	"engraving copy should state direct completion"
)
```

Use a progress fixture with exactly
`dismissed`, `seen_route`, `seen_shop`, `seen_dealer`, and
`seen_engraving`. After `mark_requested(&"route")`, assert route is hidden but
shop remains presentable. Do not add a public `reset_run_requests()` method.

- [x] **Step 2: Run all suites and verify the flow is missing**

Use `$env:TEMP\project-joker-gold-guide-flow-red.log` with the standard
`tests/run_all.gd` command.

Expected: nonzero exit because `gold_corridor_guide_flow.gd` does not exist.

- [x] **Step 3: Implement the exact four-card flow**

Create:

```gdscript
class_name GoldCorridorGuideFlow
extends RefCounted

const CHECKPOINT_ORDER: Array[StringName] = [
	&"route",
	&"shop",
	&"dealer",
	&"engraving",
]

const CARD_SPECS := {
	&"route": {
		"id": &"route",
		"progress_label": "区域提示",
		"progress_index": 1,
		"progress_total": 4,
		"title": "先比较，再选择",
		"instruction": (
			"每个房间用三轮共同完成累计目标。目标、情报券奖励、"
			+ "三条规则与当前牌组呼应均已公开；选择更适合当前构筑的路线。"
		),
		"target_ids": [&"route_left", &"route_right"],
	},
	&"shop": {
		"id": &"shop",
		"progress_label": "区域提示",
		"progress_index": 2,
		"progress_total": 4,
		"title": "替换会影响后续整个区域",
		"instruction": (
			"每次花费 1 张情报券，用一张候选牌替换一张旧牌；"
			+ "牌组始终保持十二张。离店后的牌组与余额会带入第二个房间"
			+ "和铁算盘，也可以不购买直接离开。"
		),
		"target_ids": [&"shop_tickets", &"shop_deck", &"shop_offers"],
	},
	&"dealer": {
		"id": &"dealer",
		"progress_label": "区域提示",
		"progress_index": 3,
		"progress_total": 4,
		"title": "完整分配会保住固定奖励",
		"instruction": (
			"铁算盘的三轮累计目标为 150。每轮固定奖励从 12 开始，"
			+ "每颗未分配骰子使奖励减少 2，最低为 0；"
			+ "当前结果会在结算轨迹中实时显示。"
		),
		"target_ids": [&"dealer_panel", &"resolution_panel"],
	},
	&"engraving": {
		"id": &"engraving",
		"progress_label": "区域提示",
		"progress_index": 4,
		"progress_total": 4,
		"title": "这次安装将封存区域",
		"instruction": (
			"依次选择一种刻印、一颗骰子和它的 1–6 面；"
			+ "安装前可以自由修改三项选择。正式区域安装后直接进入"
			+ "完成账目，不再进入刻印验证局。"
		),
		"target_ids": [&"reward_offers", &"reward_dice", &"reward_faces"],
	},
}

var _requested: Dictionary = {}

func checkpoint_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(CHECKPOINT_ORDER)
	return result

func card_spec(checkpoint_id: StringName) -> Dictionary:
	if not CARD_SPECS.has(checkpoint_id):
		return {}
	var spec: Dictionary = CARD_SPECS[checkpoint_id]
	return spec.duplicate(true)

func should_present(
	checkpoint_id: StringName,
	progress_snapshot: Dictionary
) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	if bool(progress_snapshot.get("dismissed", false)):
		return false
	if bool(progress_snapshot.get("seen_%s" % checkpoint_id, false)):
		return false
	return not _requested.has(checkpoint_id)

func mark_requested(checkpoint_id: StringName) -> bool:
	if not CARD_SPECS.has(checkpoint_id):
		return false
	_requested[checkpoint_id] = true
	return true
```

- [x] **Step 4: Import, run all suites, and scan both logs**

Run an editor import with
`$env:TEMP\project-joker-gold-guide-flow-import.log`, verify both new UID
files exist, then run `tests/run_all.gd` with
`$env:TEMP\project-joker-gold-guide-flow-green.log`.

Expected: both commands exit `0`; both logs have zero
`SCRIPT ERROR|Failed to load script` matches.

- [x] **Step 5: Commit only the pure flow and its test**

```powershell
git add -- `
  scripts/ui/tutorial/gold_corridor_guide_flow.gd `
  scripts/ui/tutorial/gold_corridor_guide_flow.gd.uid `
  tests/gold_corridor_guide_flow_test.gd `
  tests/gold_corridor_guide_flow_test.gd.uid

git commit --only -m "feat: define gold corridor guide flow" -- `
  scripts/ui/tutorial/gold_corridor_guide_flow.gd `
  scripts/ui/tutorial/gold_corridor_guide_flow.gd.uid `
  tests/gold_corridor_guide_flow_test.gd `
  tests/gold_corridor_guide_flow_test.gd.uid
```

---

### Task 3: Extend the Existing Overlay Without Changing the Old Guide

**Files:**

- Modify: `scripts/ui/tutorial/iron_abacus_guide_overlay.gd`
- Modify: `tests/iron_abacus_guide_ui_contract_test.gd`
- Modify: `tests/stage5_guide_layout_self_check.gd`

**Interfaces:**

- Consumes: optional `card_spec["progress_label"]`
- Preserves: `open_card(card_spec: Dictionary, targets: Array) -> bool`
- Preserves: all existing signals, methods, default copy and old five-card behavior
- Produces: progress text
  `"<progress_label> <progress_index>/<progress_total>"`
- Default: `progress_label == "进阶提示"` when absent

- [x] **Step 1: Add failing custom-label and default-label assertions**

In `tests/iron_abacus_guide_ui_contract_test.gd`, add
`"progress_label": "区域提示"` to the existing spec and assert:

```gdscript
assert_equal(
	overlay.get_node("%GuideProgress").text,
	"区域提示 3/5",
	"overlay should render a custom progress label"
)
```

Then close and reopen with a copy that erases `progress_label`:

```gdscript
overlay.close_card()
var legacy_spec: Dictionary = spec.duplicate(true)
legacy_spec.erase("progress_label")
assert_true(
	overlay.open_card(legacy_spec, [target]),
	"legacy guide card should still open"
)
assert_equal(
	overlay.get_node("%GuideProgress").text,
	"进阶提示 3/5",
	"legacy guide should keep its original label"
)
```

In `tests/stage5_guide_layout_self_check.gd`, inside `_assert_card()`, add:

```gdscript
_assert_true(
	overlay.get_node("%GuideProgress").text.begins_with("进阶提示 "),
	"%s old guide should retain the advanced-guide label" % checkpoint_id
)
```

- [x] **Step 2: Run the focused contract and confirm custom copy fails**

Run `tests/run_all.gd` with
`$env:TEMP\project-joker-guide-progress-label-red.log`.

Expected: `iron_abacus_guide_ui_contract_test.gd` fails because the overlay
still hardcodes “进阶提示”.

- [x] **Step 3: Implement the backward-compatible label**

Replace the hardcoded progress assignment in `open_card()` with:

```gdscript
var progress_copy := String(card_spec.get("progress_label", "进阶提示"))
progress_label.text = "%s %d/%d" % [
	progress_copy,
	int(card_spec.get("progress_index", 0)),
	int(card_spec.get("progress_total", 5)),
]
```

Do not change the scene, signal names, keyboard behavior, focus geometry, or
default total.

- [x] **Step 4: Run synchronous and old-guide visual checks**

Run:

```powershell
$log = Join-Path $env:TEMP "project-joker-guide-progress-label-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --log-file $log -s res://tests/run_all.gd
```

Then run:

```powershell
$log = Join-Path $env:TEMP "project-joker-old-guide-layout-after-label.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --log-file $log `
  -s res://tests/stage5_guide_layout_self_check.gd
```

Expected: both exit `0`, no script-load matches, and the old guide still shows
“进阶提示”.

- [x] **Step 5: Commit the renderer compatibility change**

```powershell
git add -- `
  scripts/ui/tutorial/iron_abacus_guide_overlay.gd `
  tests/iron_abacus_guide_ui_contract_test.gd `
  tests/stage5_guide_layout_self_check.gd

git commit --only -m "feat: support contextual guide labels" -- `
  scripts/ui/tutorial/iron_abacus_guide_overlay.gd `
  tests/iron_abacus_guide_ui_contract_test.gd `
  tests/stage5_guide_layout_self_check.gd
```

---

### Task 4: Integrate Four Checkpoints Into the Formal Area Screen

**Files:**

- Modify: `scenes/run/gold_corridor_run_screen.tscn`
- Modify: `scripts/ui/gold_corridor_run_screen.gd`
- Modify: `tests/ui_component_contract_test.gd`
- Modify: `tests/gold_corridor_input_self_check.gd`
- Modify: `tests/gold_corridor_layout_self_check.gd`
- Create: `tests/gold_corridor_guide_input_self_check.gd`
- Create after import: `tests/gold_corridor_guide_input_self_check.gd.uid`

**Interfaces:**

- Consumes: `GoldCorridorGuideProgressStore`
- Consumes: `GoldCorridorGuideFlow`
- Consumes: `IronAbacusGuideOverlay.open_card()`
- Produces exports:
  `guide_auto_start: bool = true`,
  `guide_config_path: String = "user://onboarding.cfg"`
- Produces node: `%GoldCorridorGuideOverlay`
- Produces internal methods:
  `_apply_launch_guide_path() -> void`,
  `_request_guide(checkpoint_id: StringName) -> void`,
  `_resolve_guide_target(target_id: StringName) -> Control`,
  `_close_guide() -> void`
- Preserves: all `AreaRunSession` transitions and existing player entry behavior

- [x] **Step 1: Write the failing real-input guide path**

Create `tests/gold_corridor_guide_input_self_check.gd` as a `SceneTree` script.
Use a unique temporary `guide_path`, instantiate
`gold_corridor_run_screen.tscn` directly, set `guide_config_path` before adding
it to the tree, and assert the first route prompt opens.

The test must include these helpers:

```gdscript
func _area_snapshot() -> Dictionary:
	return {
		"phase": run_screen.area_session.phase,
		"route_ids": run_screen.area_session.route_ids.duplicate(),
		"selected_room_ids": run_screen.area_session.selected_room_ids.duplicate(),
		"completed_rooms": run_screen.area_session.completed_rooms.duplicate(true),
		"deck_ids": run_screen.area_session.deck_ids.duplicate(),
		"intel_tickets": run_screen.area_session.intel_tickets,
		"die_profiles": _profile_signatures(),
		"rng_state": run_screen.area_session.run_rng.snapshot_state(),
		"room_index": run_screen.area_session.room_index,
		"encounter": _encounter_snapshot(),
		"shop": _shop_snapshot(),
		"engraving_offer_ids": (
			run_screen.area_session.engraving_offer_ids.duplicate()
		),
		"selected_engraving_id": (
			run_screen.area_session.selected_engraving_id
		),
		"installed_die_id": run_screen.area_session.installed_die_id,
		"installed_face": run_screen.area_session.installed_face,
	}

func _encounter_snapshot() -> Dictionary:
	var encounter := run_screen.area_session.encounter_session
	if encounter == null:
		return {}
	var round_state := encounter.current_session.controller.state
	var dice: Array[String] = []
	for die in round_state.dice:
		dice.append("%s|%d|%d|%s|%d" % [
			die.id,
			die.rolled_value,
			die.value,
			die.engraving_id,
			die.engraved_face,
		])
	var reports: Array = []
	for report in encounter.committed_reports:
		reports.append({
			"total": report.total,
			"events": report.event_signature(),
		})
	return {
		"status": encounter.status,
		"current_round": encounter.current_round,
		"target_total": encounter.target_total,
		"cumulative_total": encounter.cumulative_total,
		"intel_tickets": encounter.intel_tickets,
		"hand_ids": encounter.current_hand_ids.duplicate(),
		"reports": reports,
		"dice": dice,
		"assignments": round_state.assignments.duplicate(true),
		"calibration_points": round_state.calibration_points,
		"played_card_count": round_state.played_cards.size(),
	}

func _shop_snapshot() -> Dictionary:
	var shop := run_screen.area_session.shop_session
	if shop == null:
		return {}
	var records: Array[String] = []
	for record in shop.purchase_records:
		records.append("%s|%s|%d" % [
			record.offer_id,
			record.replaced_id,
			record.price,
		])
	return {
		"deck_ids": shop.deck_ids.duplicate(),
		"offer_ids": shop.offer_ids.duplicate(),
		"sold_offer_ids": shop.sold_offer_ids.duplicate(),
		"intel_tickets": shop.intel_tickets,
		"records": records,
	}

func _acknowledge_without_domain_change(
	overlay: IronAbacusGuideOverlay,
	checkpoint_id: StringName
) -> void:
	var before := _area_snapshot()
	_assert_true(overlay.active_checkpoint_id() == checkpoint_id)
	await _click(overlay.get_node("%GuideAcknowledgeButton"))
	_assert_equal(_area_snapshot(), before, "%s guide must preserve area state" % checkpoint_id)
```

Drive this exact path with real clicks:

```text
route prompt
→ acknowledge
→ first route button
→ force target_total=0 and complete three rounds
→ enter first shop
→ shop prompt
→ acknowledge with Enter
→ leave first shop
→ assert second route has no prompt
→ choose second route and complete three rounds
→ enter second shop
→ assert second shop has no prompt
→ leave second shop
→ dealer prompt
→ acknowledge with Esc
→ force dealer target_total=0 and complete three rounds
→ engraving prompt
→ acknowledge
→ select engraving, d1, face 2 and install
→ assert COMPLETE and no verification phase
```

Before acknowledging the route prompt, click the underlying left route button
position and assert `AreaRunSession.phase` remains `ROUTE_CHOICE`. After each
acknowledgement, reload `GoldCorridorGuideProgressStore` from the temporary
path and assert the corresponding checkpoint is seen.

Send `InputEventKey` with `KEY_ENTER` for the shop checkpoint and `KEY_ESCAPE`
for the dealer checkpoint. Assert both close the overlay, persist only the
current checkpoint, and preserve the complete snapshot.

Add a second fresh-screen case that clicks `%GuideDismissButton` on the route
prompt, advances the domain directly to the first shop, and asserts no later
prompt opens while every `seen_*` flag remains false and `dismissed=true`.

Add three fail-open cases:

1. Start with a corrupt config containing `[broken\nvalue`; assert the route
   prompt still opens from memory defaults, `RouteErrorLabel` reports that the
   status could not be read, acknowledgement closes the overlay, and the corrupt
   bytes remain unchanged.
2. Use a config path under a missing parent directory; acknowledge the route
   prompt and assert `RouteErrorLabel` reports that the status could not be
   saved while the route remains selectable.
3. Instantiate with `guide_auto_start=false`, free
   `RouteChoicePanel/%LeftRoutePage`, enable auto-start, call
   `_request_guide(&"route")`, and assert the overlay stays closed and the area
   remains in `ROUTE_CHOICE`.

- [x] **Step 2: Add failing scene and regression contracts**

In `tests/ui_component_contract_test.gd`, extend the Gold Corridor scene block:

```gdscript
assert_true(
	gold.get_node_or_null("%GoldCorridorGuideOverlay") != null,
	"Gold Corridor should own the contextual guide overlay"
)
assert_true(
	gold.has_method("_request_guide"),
	"Gold Corridor should request guide checkpoints"
)
```

In `tests/gold_corridor_layout_self_check.gd`, before adding each screen:

```gdscript
screen.guide_auto_start = false
```

In `tests/gold_corridor_input_self_check.gd`, after the normal entry changes
scene and `run_screen` is assigned:

```gdscript
run_screen.guide_auto_start = false
run_screen.get_node("%GoldCorridorGuideOverlay").close_card()
```

This preserves the existing full-area input test as a guide-free gameplay
regression.

- [x] **Step 3: Run red checks**

Run `tests/run_all.gd` with
`$env:TEMP\project-joker-gold-guide-screen-contract-red.log`, then run the new
input script with
`$env:TEMP\project-joker-gold-guide-input-red.log`.

Expected: contracts fail because `%GoldCorridorGuideOverlay` and guide methods
do not exist; the focused input script also fails before the route checkpoint.

- [x] **Step 4: Add the existing overlay scene above every area panel**

In `gold_corridor_run_screen.tscn`, add the existing packed scene resource and:

```text
[node name="GoldCorridorGuideOverlay" parent="." instance=ExtResource("guide_overlay")]
unique_name_in_owner = true
layout_mode = 1
z_index = 50
```

The node must come after `%AreaCompletePanel`. Do not duplicate or modify the
overlay scene.

- [x] **Step 5: Initialize guide state and connect the renderer**

Add to `GoldCorridorRunScreen`:

```gdscript
@export var guide_auto_start := true
@export var guide_config_path := "user://onboarding.cfg"

@onready var guide_overlay: IronAbacusGuideOverlay = %GoldCorridorGuideOverlay

var guide_store: GoldCorridorGuideProgressStore
var guide_flow := GoldCorridorGuideFlow.new()
var _guide_load_warning_pending := false
```

At the beginning of `_ready()`:

```gdscript
_apply_launch_guide_path()
guide_store = GoldCorridorGuideProgressStore.new(guide_config_path)
_guide_load_warning_pending = guide_store.initial_load_error() != OK
```

Implement the metadata consumer in this task so the screen is complete before
the entry task starts:

```gdscript
func _apply_launch_guide_path() -> void:
	var root_window := get_tree().root
	if not root_window.has_meta("gold_corridor_guide_config_path"):
		return
	guide_config_path = String(
		root_window.get_meta("gold_corridor_guide_config_path")
	)
	root_window.remove_meta("gold_corridor_guide_config_path")
```

Connect:

```gdscript
encounter_screen.view_refreshed.connect(guide_overlay.refresh_targets)
guide_overlay.acknowledged.connect(_on_guide_acknowledged)
guide_overlay.dismiss_all_requested.connect(_on_guide_dismiss_all_requested)
```

Do not reset `guide_flow` inside `start_run()` or `_on_restart_requested()`.

- [x] **Step 6: Request the four checkpoints only after successful binding**

Add deferred requests at these exact accepted points:

```gdscript
# _show_route_choice(), after bind_routes() returns true
call_deferred("_request_guide", &"route")

# _on_shop_requested(), after shop_screen.bind_session()
call_deferred("_request_guide", &"shop")

# bind_current_encounter(), after bind_external_session(), dealer phase only
if area_session.phase == AreaRunSession.Phase.DEALER:
	call_deferred("_request_guide", &"dealer")

# _on_round_committed(), after reward_panel.bind_reward()
call_deferred("_request_guide", &"engraving")
```

Because `guide_flow.mark_requested()` is permanent for the scene instance,
the second route and second shop calls are automatically ignored.

- [x] **Step 7: Implement target resolution and fail-open requests**

Use child-scene roots:

```gdscript
func _resolve_guide_target(target_id: StringName) -> Control:
	match target_id:
		&"route_left":
			return route_panel.get_node_or_null("%LeftRoutePage")
		&"route_right":
			return route_panel.get_node_or_null("%RightRoutePage")
		&"shop_tickets":
			return shop_screen.get_node_or_null("%TicketLabel")
		&"shop_deck":
			return shop_screen.get_node_or_null("%DeckGrid")
		&"shop_offers":
			return shop_screen.get_node_or_null("%OfferColumn")
		&"dealer_panel":
			return encounter_screen.get_node_or_null("%DealerPanel")
		&"resolution_panel":
			return encounter_screen.get_node_or_null("%ResolutionPanel")
		&"reward_offers":
			return reward_panel.get_node_or_null("%OfferRow")
		&"reward_dice":
			return reward_panel.get_node_or_null("%DieRow")
		&"reward_faces":
			return reward_panel.get_node_or_null("%FaceGrid")
	return null
```

Implement `_request_guide()` so it:

1. Returns when auto-start is false, store is null, or `should_present()` is false.
2. Calls `mark_requested()` before resolving targets.
3. Resolves every target ID.
4. On the first missing target, calls
   `push_error("Gold Corridor guide target missing: checkpoint=%s target=%s")`
   and returns without opening or persisting.
5. Calls `guide_overlay.open_card()` and logs a checkpoint-specific error if it
   returns false.

- [x] **Step 8: Persist acknowledgement, dismiss all, and route warnings**

Implement:

```gdscript
func _on_guide_acknowledged(checkpoint_id: StringName) -> void:
	var result := guide_store.mark_seen(checkpoint_id)
	guide_overlay.close_card()
	if result != OK:
		_show_guide_persistence_warning()

func _on_guide_dismiss_all_requested(_checkpoint_id: StringName) -> void:
	var result := guide_store.dismiss_all()
	guide_overlay.close_card()
	if result != OK:
		_show_guide_persistence_warning()

func _show_guide_persistence_warning() -> void:
	var message := "无法保存区域提示状态；下次启动可能再次显示。"
	if route_panel.visible:
		route_panel.show_error(message)
	elif shop_screen.visible:
		shop_screen.get_node("%ShopErrorLabel").text = message
	elif reward_panel.visible:
		reward_panel.show_error(message)
	else:
		encounter_screen.show_external_error(message)
```

When `_guide_load_warning_pending` is true, show
`"无法读取区域提示状态；本次仍可正常游玩。"` on the first visible route
panel and clear the pending flag. The request may still open from memory
defaults.

- [x] **Step 9: Close the guide on every transition**

Call `_close_guide()` before:

- accepting a route selection;
- opening or leaving a shop;
- advancing an encounter round;
- handling a committed report;
- installing an engraving;
- restarting the area;
- returning to the entry;
- showing a start error.

Use:

```gdscript
func _close_guide() -> void:
	if is_instance_valid(guide_overlay):
		guide_overlay.close_card()
```

Calling close while already closed must remain harmless.

- [x] **Step 10: Import and run focused plus regression checks**

Run an editor import with
`$env:TEMP\project-joker-gold-guide-screen-import.log`, verify the new input
test UID exists, then run:

```text
tests/run_all.gd
tests/gold_corridor_guide_input_self_check.gd
tests/gold_corridor_input_self_check.gd
tests/gold_corridor_layout_self_check.gd
tests/stage5_guide_input_self_check.gd
tests/stage5_guide_layout_self_check.gd
```

Use a separate explicit `$env:TEMP` log for every script and scan every log for
`SCRIPT ERROR|Failed to load script`.

Expected: all exit `0`; the guide input path reaches `COMPLETE`; existing area
and old-guide checks remain green.

- [x] **Step 11: Commit the formal screen integration**

```powershell
git add -- `
  scenes/run/gold_corridor_run_screen.tscn `
  scripts/ui/gold_corridor_run_screen.gd `
  tests/ui_component_contract_test.gd `
  tests/gold_corridor_input_self_check.gd `
  tests/gold_corridor_layout_self_check.gd `
  tests/gold_corridor_guide_input_self_check.gd `
  tests/gold_corridor_guide_input_self_check.gd.uid

git commit --only -m "feat: guide the gold corridor run" -- `
  scenes/run/gold_corridor_run_screen.tscn `
  scripts/ui/gold_corridor_run_screen.gd `
  tests/ui_component_contract_test.gd `
  tests/gold_corridor_input_self_check.gd `
  tests/gold_corridor_layout_self_check.gd `
  tests/gold_corridor_guide_input_self_check.gd `
  tests/gold_corridor_guide_input_self_check.gd.uid
```

---

### Task 5: Add the Independent Region-Guide Replay Entry

**Files:**

- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `tests/ui_component_contract_test.gd`
- Modify: `tests/single_encounter_layout_self_check.gd`
- Modify: `tests/stage5_guide_input_self_check.gd`
- Modify: `tests/gold_corridor_input_self_check.gd`
- Modify: `tests/gold_corridor_guide_input_self_check.gd`

**Interfaces:**

- Produces node: `%ReplayGoldCorridorGuideButton`
- Produces:
  `_on_replay_gold_corridor_guide_pressed() -> void`
- Produces:
  `_launch_gold_corridor() -> void`
- Produces one-time root metadata:
  `gold_corridor_guide_config_path: String`
- Preserves:
  `_on_replay_advanced_guide_pressed()` and old
  `iron_abacus_guide_config_path`
- Preserves:
  `RunTrialButton` normal entry into the formal area

- [x] **Step 1: Add failing entry contracts**

In `tests/ui_component_contract_test.gd`, assert the entry owns:

```gdscript
for button_name in [
	"ReplayTutorialButton",
	"ReplayAdvancedGuideButton",
	"ReplayGoldCorridorGuideButton",
	"RunTrialButton",
]:
	assert_true(
		screen.get_node_or_null("%" + button_name) != null,
		"entry should expose %s" % button_name
	)
```

Assert the texts are exactly:

```text
重看引导
重看铁算盘原型引导
重看区域提示
进入六面诡局
```

In `tests/single_encounter_layout_self_check.gd`, add all four buttons to the
safe-area bounds assertions.

In `tests/stage5_guide_input_self_check.gd`, assert the old renamed button text,
click it, and retain the existing assertion that the scene becomes
`IronAbacusSliceScreen`.

In `tests/gold_corridor_input_self_check.gd`, use a unique temporary
`tutorial_config_path` on its existing entry scene before clicking the normal
`%RunTrialButton`. Assert the resulting
`GoldCorridorRunScreen.guide_config_path` equals that path. Close the route
guide before continuing the existing guide-free full-area assertions, and
remove the temporary config during cleanup.

- [x] **Step 2: Extend the region-guide input test for replay isolation**

Change the beginning of `gold_corridor_guide_input_self_check.gd` to:

1. Seed the same config with:
   - `onboarding/done=true`;
   - `iron_abacus_guide_v1/seen_shop=true`;
   - all `gold_corridor_guide_v1` flags true and `dismissed=true`.
2. Instantiate `single_encounter_screen.tscn`.
3. Set `tutorial_auto_start=false` and `tutorial_config_path=guide_path`.
4. Click `%ReplayGoldCorridorGuideButton`.
5. Assert the current scene is `GoldCorridorRunScreen`.
6. Assert `run_screen.guide_config_path == guide_path`.
7. Assert route prompt opens.
8. Reload the config and assert base tutorial and old guide values remain true.

Add a reset-failure case with a path under a missing parent directory. Emit the
new replay button and assert the current scene remains the entry and the entry
error label contains:

```text
无法重置区域提示；仍可正常进入六面诡局。
```

- [x] **Step 3: Run the red contracts**

Run `tests/run_all.gd`,
`tests/gold_corridor_guide_input_self_check.gd`, and
`tests/stage5_guide_input_self_check.gd` with distinct logs.

Expected: failures because the new button and replay handler do not exist.
The old-guide test must still reach its old entry before the new assertions.

- [x] **Step 4: Add and connect the new entry button**

In `single_encounter_screen.tscn`:

- Keep `%ReplayAdvancedGuideButton` but set:
  - text: `重看铁算盘原型引导`;
  - tooltip: `重置旧五点提示并进入包含刻印验证的铁算盘原型`.
- Insert `%ReplayGoldCorridorGuideButton` immediately before
  `%RunTrialButton`:
  - text: `重看区域提示`;
  - tooltip: `重置四个正式区域提示并从金线回廊第一组选路开始`.

In `SingleEncounterScreen`, add:

```gdscript
@onready var replay_gold_corridor_guide_button: Button = (
	%ReplayGoldCorridorGuideButton
)
```

Connect it in `_ready()` and hide it in `bind_external_session()` together
with the other entry-only controls.

- [x] **Step 5: Implement reset-before-launch and normal path propagation**

Implement:

```gdscript
func _on_replay_gold_corridor_guide_pressed() -> void:
	var store := GoldCorridorGuideProgressStore.new(tutorial_config_path)
	var result := store.reset()
	if result != OK:
		_on_tutorial_persistence_warning(
			"无法重置区域提示；仍可正常进入六面诡局。"
		)
		return
	_launch_gold_corridor()

func _on_run_trial_pressed() -> void:
	_launch_gold_corridor()

func _launch_gold_corridor() -> void:
	get_tree().root.set_meta(
		"gold_corridor_guide_config_path",
		tutorial_config_path
	)
	get_tree().change_scene_to_file(
		"res://scenes/run/gold_corridor_run_screen.tscn"
	)
```

Task 4 already consumes and removes this metadata before constructing the
store. The normal entry now propagates custom test/config paths without
resetting guide state; the replay entry resets first and uses the same
launcher.

- [x] **Step 6: Run entry, old-guide, and full guide checks**

Run with separate logs:

```text
tests/run_all.gd
tests/single_encounter_layout_self_check.gd
tests/stage5_guide_input_self_check.gd
tests/gold_corridor_guide_input_self_check.gd
tests/gold_corridor_input_self_check.gd
```

Expected: all exit `0` with no script-load matches. The old button opens
`IronAbacusSliceScreen`; the new button opens `GoldCorridorRunScreen`; the
normal button still opens `GoldCorridorRunScreen`.

- [x] **Step 7: Commit only entry and compatibility changes**

```powershell
git add -- `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  tests/ui_component_contract_test.gd `
  tests/single_encounter_layout_self_check.gd `
  tests/stage5_guide_input_self_check.gd `
  tests/gold_corridor_input_self_check.gd `
  tests/gold_corridor_guide_input_self_check.gd

git commit --only -m "feat: add region guide replay entry" -- `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  tests/ui_component_contract_test.gd `
  tests/single_encounter_layout_self_check.gd `
  tests/stage5_guide_input_self_check.gd `
  tests/gold_corridor_input_self_check.gd `
  tests/gold_corridor_guide_input_self_check.gd
```

---

### Task 6: Add Dual-Resolution Guide Layout Acceptance

**Files:**

- Create: `tests/gold_corridor_guide_layout_self_check.gd`
- Create after import: `tests/gold_corridor_guide_layout_self_check.gd.uid`
- Modify only when a measured defect requires it:
  - `scenes/run/single_encounter_screen.tscn`
  - `scenes/run/gold_corridor_run_screen.tscn`
  - `scripts/ui/gold_corridor_run_screen.gd`
  - `scripts/ui/tutorial/iron_abacus_guide_overlay.gd`

**Interfaces:**

- Consumes: the complete formal guide flow from Tasks 1–5
- Produces: durable layout checks for all four checkpoints at
  `1280×720` and `1920×1080`
- Preserves: existing route, shop, dealer, reward and old-guide layouts

- [x] **Step 1: Write the dual-resolution layout script**

Create a `SceneTree` script that calls:

```gdscript
root.content_scale_size = Vector2i(1920, 1080)
root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
await _verify_size(Vector2i(1280, 720))
await _verify_size(Vector2i(1920, 1080))
```

For each size:

1. Use a fresh temporary guide config.
2. Instantiate `GoldCorridorRunScreen` with that path.
3. Inspect route, first shop, dealer and engraving prompts.
4. Acknowledge each prompt before advancing.
5. Remove the temporary config after freeing the screen.

For every checkpoint assert:

```gdscript
var overlay: IronAbacusGuideOverlay = screen.get_node(
	"%GoldCorridorGuideOverlay"
)
var bounds := Rect2(Vector2.ZERO, overlay.size)
var card: Control = overlay.get_node("%GuideCard")
_assert_true(overlay.is_open(), "guide should open")
_assert_true(
	overlay.active_checkpoint_id() == checkpoint_id,
	"active checkpoint should match"
)
_assert_true(bounds.encloses(card.get_rect()), "guide card should stay in bounds")
_assert_true(
	overlay.mouse_filter == Control.MOUSE_FILTER_STOP,
	"open guide should block background input"
)
_assert_true(
	overlay.z_index > screen.get_node("%AreaCompletePanel").z_index,
	"guide should render above completion"
)
_assert_true(
	overlay.get_node("%GuideProgress").text
	== "区域提示 %d/4" % progress_index,
	"guide progress copy should be exact"
)
```

Resolve the card spec through `guide_flow`, resolve the real targets through
the screen, and assert:

- one focus frame per target;
- every focus frame remains inside overlay bounds;
- every frame tracks its target within floating-point approximation;
- the guide card does not overlap any focus frame;
- both guide buttons remain inside the card;
- closing removes all focus frames and restores `MOUSE_FILTER_IGNORE`.

- [x] **Step 2: Run the new layout script**

Use
`$env:TEMP\project-joker-gold-guide-layout-first.log`.

Expected: exit `0` if the existing reusable overlay fits all targets. If it
fails, treat the reported rectangle as a measured defect; change only the
listed production files and rerun both sizes before continuing.

- [x] **Step 3: Run neighboring layout regressions**

Run separately:

```text
tests/single_encounter_layout_self_check.gd
tests/tutorial_layout_self_check.gd
tests/three_round_layout_self_check.gd
tests/stage5_layout_self_check.gd
tests/stage5_guide_layout_self_check.gd
tests/gold_corridor_layout_self_check.gd
tests/gold_corridor_guide_layout_self_check.gd
```

Every command uses its own writable log. Expected: all exit `0` and all
script-load scans are empty.

- [x] **Step 4: Import the durable layout script and verify its UID**

Run an editor import with
`$env:TEMP\project-joker-gold-guide-layout-import.log`.

Expected:

```text
tests/gold_corridor_guide_layout_self_check.gd.uid exists
editor exit code = 0
script-load scan = empty
```

- [x] **Step 5: Commit the durable layout acceptance and measured fixes**

The minimum commit is:

```powershell
git add -- `
  tests/gold_corridor_guide_layout_self_check.gd `
  tests/gold_corridor_guide_layout_self_check.gd.uid

git commit --only -m "test: verify gold corridor guide layout" -- `
  tests/gold_corridor_guide_layout_self_check.gd `
  tests/gold_corridor_guide_layout_self_check.gd.uid
```

If a measured production fix is required, include only its exact path in both
commands. Never include staged documents or `project.godot`.

---

### Task 7: Complete Visual, Stability, Language, and Full Regression Acceptance

**Files:**

- Modify only when a measured defect requires it:
  - files explicitly listed in Tasks 3–6
- Temporary and remove before commit:
  - `tests/_gold_corridor_guide_visual_capture.gd`
  - `tests/_gold_corridor_guide_visual_capture.gd.uid`
  - `tmp/gold_corridor_guide_captures/*.png`
- Modify and restage without committing:
  - `docs/superpowers/plans/2026-07-26-gold-corridor-contextual-onboarding.md`
  - `docs/superpowers/specs/2026-07-26-gold-corridor-contextual-onboarding-design.md`

**Interfaces:**

- Produces: eight inspected screenshots, three stable real-input runs, final
  regression logs and verified Git boundaries
- Preserves: no visual artifacts, no remote push, staged-only documents

- [x] **Step 1: Capture eight real rendered guide states**

Create a temporary `SceneTree` capture script that drives the formal flow and
saves:

```text
1280x720-route-guide.png
1280x720-shop-guide.png
1280x720-dealer-guide.png
1280x720-engraving-guide.png
1920x1080-route-guide.png
1920x1080-shop-guide.png
1920x1080-dealer-guide.png
1920x1080-engraving-guide.png
```

Use a fresh config for each rendered size and deterministic accepted reports
that preserve the real room/dealer targets in displayed summaries.

Run non-headless Godot with an explicit log:

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-guide-visual.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --path . `
  --log-file $log `
  -s res://tests/_gold_corridor_guide_visual_capture.gd
```

Inspect every image for card clipping, focus accuracy, target visibility,
background dimming, card/target overlap, button clarity and correct
`区域提示 n/4` copy.

- [x] **Step 2: Remove all capture artifacts**

Resolve the absolute capture directory, verify it equals
`D:\Project\ProjectJoker\project-joker\tmp\gold_corridor_guide_captures`,
then delete only that exact directory. Remove the temporary script and UID.

Confirm:

```text
tests/_gold_corridor_guide_visual_capture.gd absent
tests/_gold_corridor_guide_visual_capture.gd.uid absent
tmp/gold_corridor_guide_captures absent
```

- [x] **Step 3: Run the guide input path three consecutive times**

Use distinct logs:

```text
project-joker-gold-guide-input-stability-1.log
project-joker-gold-guide-input-stability-2.log
project-joker-gold-guide-input-stability-3.log
```

Each run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  -s res://tests/gold_corridor_guide_input_self_check.gd
```

Expected: all three exit `0`, all three script-load scans are empty, and every
temporary config is removed by the test.

- [x] **Step 4: Run the final editor import**

Run:

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-guide-editor-import.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --editor `
  --quit `
  --path . `
  --log-file $log
```

Verify every new production and durable test `.gd` file has its tracked
`.gd.uid` sibling. Ignore only the known global editor-settings save warning;
script-load errors remain failures.

- [x] **Step 5: Run the final synchronous, layout, and input matrix**

Run every item with a distinct writable log:

```text
tests/run_all.gd
tests/single_encounter_layout_self_check.gd
tests/tutorial_layout_self_check.gd
tests/three_round_layout_self_check.gd
tests/stage5_layout_self_check.gd
tests/stage5_guide_layout_self_check.gd
tests/gold_corridor_layout_self_check.gd
tests/gold_corridor_guide_layout_self_check.gd
tests/single_encounter_input_self_check.gd
tests/tutorial_input_self_check.gd
tests/three_round_input_self_check.gd
tests/stage5_input_self_check.gd
tests/stage5_guide_input_self_check.gd
tests/gold_corridor_input_self_check.gd
tests/gold_corridor_guide_input_self_check.gd
```

Expected: every command exits `0`; all logs have zero
`SCRIPT ERROR|Failed to load script` matches.

- [x] **Step 6: Start the project main scene**

```powershell
$log = Join-Path $env:TEMP "project-joker-gold-guide-main-scene.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  --quit-after 2
```

Expected: exit `0`, empty script-load scan.

- [x] **Step 7: Audit production gambling-oriented language**

```powershell
$sourceFiles = Get-ChildItem `
  -Path scripts,scenes,resources `
  -Recurse -File |
  Where-Object { $_.Extension -in ".gd",".tscn",".tres",".json" }

$matches = @($sourceFiles | Select-String `
  -Pattern "下注|筹码|赌注|贷款|借贷|充值|真钱|现金|概率触发|随机触发|\bbet\b|\bwager\b|\bchips?\b|\bloan\b|real.?money" `
  -CaseSensitive:$false)

Write-Output "GAMBLING_LANGUAGE_MATCHES=$($matches.Count)"
if ($matches.Count -gt 0) {
  $matches | Select-Object Path,LineNumber,Line
  exit 1
}
```

Expected: zero matches.

- [x] **Step 8: Verify final Git boundaries**

Run:

```powershell
git diff --check
git diff --cached --check
git status --short
```

Expected:

- staged paths are design and plan documents only;
- the only unrelated unstaged file is `project.godot`;
- all guide code and durable tests are committed;
- no capture script, capture UID, PNG directory, `.superpowers`, worktree or
  visual companion artifact exists.

- [x] **Step 9: Commit only measured acceptance fixes**

If Steps 1–8 required no production or durable-test fixes, do not create an
empty commit. If a measured defect required a fix, run its focused test and
full regression, then use this fixed allowlist:

```powershell
$allowedFixPaths = @(
  "scripts/ui/tutorial/iron_abacus_guide_overlay.gd",
  "scenes/run/gold_corridor_run_screen.tscn",
  "scripts/ui/gold_corridor_run_screen.gd",
  "scenes/run/single_encounter_screen.tscn",
  "scripts/ui/single_encounter_screen.gd",
  "tests/gold_corridor_guide_input_self_check.gd",
  "tests/gold_corridor_guide_layout_self_check.gd"
)
$changedFixPaths = @(git diff --name-only -- $allowedFixPaths)
if ($changedFixPaths.Count -gt 0) {
  git add -- $changedFixPaths
  git commit --only -m "fix: harden gold corridor guide acceptance" -- `
    $changedFixPaths
}
```

Any changed path outside the allowlist is a scope violation and must be
investigated before committing.

- [x] **Step 10: Mark this plan complete and keep documents staged**

Mechanically replace every `- [x]` in this plan with `- [x]`, then:

```powershell
git add -- `
  docs/superpowers/plans/2026-07-26-gold-corridor-contextual-onboarding.md `
  docs/superpowers/specs/2026-07-26-gold-corridor-contextual-onboarding-design.md
```

Confirm both documents remain staged and absent from every code commit.

## Final Acceptance Summary

- [x] Four formal-area prompts appear once at route, first shop, dealer and engraving.
- [x] Route copy explains three-round accumulation without a second immediate prompt.
- [x] First-shop copy explains twelve-card replacement, cross-area inheritance and optional departure.
- [x] Dealer copy exposes target `150`, fixed reward `12` and `−2` per unassigned die.
- [x] Engraving copy states installation directly completes the area without verification.
- [x] Second route, second shop, failure, retry, restart and completion do not add prompts.
- [x] “知道了”, `Enter` and `Esc` mark only the current checkpoint seen.
- [x] “不再提示” sets only `dismissed=true`.
- [x] Replay resets only `[gold_corridor_guide_v1]`.
- [x] Base tutorial and old Iron Abacus guide state remain untouched.
- [x] Old replay button still launches the old five-checkpoint verification prototype.
- [x] New replay button launches the formal Gold Corridor with four reset prompts.
- [x] Normal entry launches the formal Gold Corridor without resetting guide state.
- [x] Missing targets, corrupt configs and write failures never block gameplay.
- [x] Guide open, acknowledge, dismiss and close preserve the full area snapshot.
- [x] The reused overlay shows “区域提示 n/4” while the old guide keeps “进阶提示 n/5”.
- [x] All eight dual-resolution visuals pass inspection.
- [x] Synchronous, layout, input, import and main-scene checks pass.
- [x] Production source remains free of gambling-oriented mechanics and copy.
- [x] Code commits exist directly on `master`; no remote push occurs.
- [x] Documents remain staged and uncommitted.
- [x] `project.godot` remains untouched and unstaged.
