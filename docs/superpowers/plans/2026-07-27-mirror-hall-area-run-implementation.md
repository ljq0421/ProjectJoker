# 《六面诡局》反照牌厅地区实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不引入跨地区连续单局的前提下，交付可独立进入、完整通关并带有三个一次性情境提示的“反照牌厅 + 镜面夫人”第二地区。

**Architecture:** 先扩展纯数据和结算层，使镜像副本、公开结算方向和镜像刻印都能脱离 UI 独立验证；随后以 `AreaDefinition` 参数化现有 `AreaRunSession`，让金线回廊和反照牌厅共用同一阶段机与场景结构。最后接入镜像显示、独立引导状态和主入口，并用固定种子、真实输入、布局与全量回归共同验收。

**Tech Stack:** Godot 4.6.1、GDScript、`.tres` Resource、`.tscn` 场景、项目内 `TestCase` 同步测试、Godot headless 自检脚本。

## Global Constraints

- 工作目录固定为 `D:\Project\ProjectJoker\project-joker`，直接在 `master` 开发。
- 设计规格以 `docs/superpowers/specs/2026-07-27-mirror-hall-area-run-design.md` 为准。
- 不实现跨地区 `RunDirector`、跨地区存档、第三地区或随机封禁。
- 固定教学种子为 `20260727`；牌组始终为 12 张，每轮手牌为 4 张。
- 每轮最多两次真实出牌；镜像副本不占真实出牌次数、牌组、弃牌堆或实体槽位。
- 镜像副本只来自本轮第一张实际生成副本的合格桌间牌，最多一个且不可递归。
- 预览和正式提交必须使用同一份结算报告语义。
- 引导只能通过页面动作和会话模型观察状态，不得直接修改 `RoundState`、RNG、分数、牌组或商店。
- UI 保持 `canvas_items + keep`，必须覆盖 `1280×720` 和 `1920×1080`。
- 所有 Godot headless 命令必须使用 `D:\Godot\Godot_v4.6.1-stable_win64_console.exe`，并显式传入位于 `$env:TEMP` 的唯一 `--log-file`。
- Godot 退出码非零，或日志包含 `SCRIPT ERROR|Failed to load script`，都视为失败。
- 设计和实施计划文档只暂存、不提交；代码提交使用 `git commit --only` 和明确路径，不能带入已暂存文档。
- 不创建分支、工作树、PR，不推送远端，不改写已有历史。

## Planned File Structure

### Core model and resolution

- Create `scripts/resolution/encounter_rule_profile.gd`: 公开方向与镜像次数规则。
- Create `scripts/cards/mirror_copy_result.gd`: 镜像生成的结构化结果。
- Create `scripts/cards/mirror_copy_resolver.gd`: 合格判断、槽位反照与副本构造。
- Modify `scripts/cards/card_definition.gd`: 增加 `mirror_effects`。
- Modify `scripts/cards/played_card.gd`: 增加运行时效果与来源元数据。
- Modify `scripts/resolution/encounter_definition.gd`: 绑定 `EncounterRuleProfile`。
- Modify `scripts/resolution/resolution_event.gd`: 增加镜像来源字段。
- Modify `scripts/resolution/resolution_report.gd`: 暴露有效结算方向和轨道顺序。
- Modify `scripts/cards/card_rules.gd`: 原牌与副本原子加入状态。
- Modify `scripts/run/round_controller.gd`: 把遭遇规则传给出牌校验。
- Modify `scripts/resolution/round_resolver.gd`: 统一消费运行时效果、方向和镜像事件。
- Modify `scripts/validation/content_validator.gd`: 校验镜像操作、目标及来源。

### Area framework and content

- Create `scripts/areas/area_definition.gd`: 地区配置与只读查询。
- Create `scripts/areas/area_catalog.gd`: 加载金线回廊和反照牌厅定义。
- Create `resources/areas/gold_corridor.tres`: 现有地区的兼容配置。
- Create `resources/areas/mirror_hall.tres`: 第二地区完整配置。
- Create `resources/encounters/gold_corridor/iron_abacus.tres`: 参数化后的铁算盘遭遇。
- Create `resources/encounters/mirror_hall/mirror_lady.tres`: 镜面夫人遭遇。
- Modify `scripts/run/area_run_session.gd`: 消除对 `GoldCorridorCatalog` 和铁算盘常量的依赖。
- Modify `scripts/rooms/gold_corridor_catalog.gd`: 保留兼容查询，但资源来源改为金线地区定义。
- Modify `scripts/dealers/dealer_catalog.gd`: 增加镜面夫人和通用 `find_dealer`。
- Modify `scripts/engravings/engraving_catalog.gd`: 增加四种刻印与分组 ID。
- Modify `scripts/cards/card_catalog.gd`: 增加六张镜像牌，不改变旧 starter/shop 分组。
- Modify `scripts/ui/area_complete_panel.gd`: 按地区和庄家 ID 渲染完成摘要。

### UI and onboarding

- Create `scripts/ui/area_run_screen.gd`: 共用地区 UI 编排。
- Create `scenes/run/area_run_screen.tscn`: 共用地区场景结构。
- Modify `scripts/ui/gold_corridor_run_screen.gd`: 只保留金线地区与旧引导适配。
- Modify `scenes/run/gold_corridor_run_screen.tscn`: 继承共用场景。
- Create `scripts/ui/mirror_hall_run_screen.gd`: 反照牌厅配置与专属引导适配。
- Create `scenes/run/mirror_hall_run_screen.tscn`: 反照牌厅入口。
- Modify `scenes/run/single_encounter_screen.tscn`: 增加方向标记、镜像槽层和入口分组。
- Modify `scripts/ui/single_encounter_screen.gd`: 显示有效方向、虚拟副本并发出选牌事件。
- Modify `scripts/ui/resolution_panel.gd`: 显示镜像来源和真实事件顺序。
- Create `scripts/ui/tutorial/mirror_hall_guide_flow.gd`: 三个提示的触发与文案。
- Create `scripts/ui/tutorial/mirror_hall_guide_progress_store.gd`: 独立配置区段。
- Reuse `scenes/components/iron_abacus_guide_overlay.tscn`: 复用已验证遮罩，不复制视觉组件。

---

### Task 1: 建立镜像与公开方向的数据契约

**Files:**
- Create: `scripts/resolution/encounter_rule_profile.gd`
- Modify: `scripts/resolution/encounter_definition.gd`
- Modify: `scripts/cards/card_definition.gd`
- Modify: `scripts/cards/played_card.gd`
- Modify: `scripts/resolution/resolution_event.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Test: `tests/mirror_data_model_test.gd`

**Interfaces:**
- Produces: `EncounterRuleProfile.ResolutionDirection`
- Produces: `EncounterDefinition.rule_profile: EncounterRuleProfile`
- Produces: `PlayedCard.effective_effects() -> Array[EffectSpec]`
- Produces: `PlayedCard.play_id/source_play_id/source_card_id/source_slot_id`
- Produces: `ResolutionReport.resolution_direction` 与 `ordered_rule_ids`

- [ ] **Step 1: 写失败的数据模型测试**

```gdscript
extends "res://tests/test_case.gd"

func run() -> void:
	var profile := EncounterRuleProfile.new()
	profile.resolution_direction = EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	profile.mirror_first_table_card = true
	profile.mirror_limit_per_round = 1

	var encounter := EncounterDefinition.new()
	encounter.rule_profile = profile
	assert_equal(
		encounter.rule_profile.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"encounter should retain public direction"
	)

	var card := CardDefinition.new()
	card.id = &"mirror_fixture"
	var original := PlayedCard.new(card, &"left", &"middle")
	original.play_id = &"play_1"
	var copy := original.clone()
	copy.is_mirror_copy = true
	copy.source_play_id = original.play_id
	assert_equal(copy.source_play_id, &"play_1", "clone should retain source metadata")
```

- [ ] **Step 2: 运行测试并确认缺少类型或字段**

```powershell
$log = "$env:TEMP\project-joker-task01-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
if ($godotExit -eq 0) { throw "Expected mirror_data_model_test.gd to fail before implementation" }
```

- [ ] **Step 3: 实现最小数据契约**

```gdscript
# scripts/resolution/encounter_rule_profile.gd
class_name EncounterRuleProfile
extends Resource

enum ResolutionDirection {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT,
}

@export var resolution_direction := ResolutionDirection.LEFT_TO_RIGHT
@export var mirror_first_table_card := false
@export_range(0, 1, 1) var mirror_limit_per_round := 0
```

```gdscript
# scripts/cards/played_card.gd 的新增核心
var play_id: StringName = &""
var is_mirror_copy := false
var source_card_id: StringName = &""
var source_play_id: StringName = &""
var source_slot_id: StringName = &""
var runtime_effects: Array[EffectSpec] = []

func effective_effects() -> Array[EffectSpec]:
	return runtime_effects if not runtime_effects.is_empty() else definition.effects
```

`clone()` 必须复制所有标量字段，并逐项复制 `runtime_effects`；不能共享镜像副本使用的 `EffectSpec` 实例。`ResolutionEvent` 增加 `is_mirror_copy`、`source_card_id`、`source_slot_id`、`mirror_slot_id`，构造器为新增参数提供默认值，保证旧调用不需要同时修改。`ResolutionReport` 默认方向为左到右，`ordered_rule_ids` 默认为空数组。

- [ ] **Step 4: 运行模型与全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-task01-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 5: 只提交本任务代码**

```powershell
git add -- tests/mirror_data_model_test.gd scripts/resolution/encounter_rule_profile.gd scripts/resolution/encounter_definition.gd scripts/cards/card_definition.gd scripts/cards/played_card.gd scripts/resolution/resolution_event.gd scripts/resolution/resolution_report.gd
git commit --only -m "feat: add mirror encounter data contracts" -- tests/mirror_data_model_test.gd scripts/resolution/encounter_rule_profile.gd scripts/resolution/encounter_definition.gd scripts/cards/card_definition.gd scripts/cards/played_card.gd scripts/resolution/resolution_event.gd scripts/resolution/resolution_report.gd
```

### Task 2: 原子生成镜像副本并接入撤销历史

**Files:**
- Create: `scripts/cards/mirror_copy_result.gd`
- Create: `scripts/cards/mirror_copy_resolver.gd`
- Modify: `scripts/cards/card_rules.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/ui/single_encounter_session.gd`
- Test: `tests/mirror_copy_resolver_test.gd`
- Test: `tests/card_rules_test.gd`
- Test: `tests/round_controller_test.gd`

**Interfaces:**
- Consumes: `PlayedCard.effective_effects()`
- Produces: `MirrorCopyResolver.resolve(original, state, encounter) -> MirrorCopyResult`
- Produces: `CardRules.play_card(state, played_card, context, encounter)`

- [ ] **Step 1: 写槽位映射、次数、不递归和深复制的失败测试**

```gdscript
func _test_left_gap_reflects_to_right_gap() -> void:
	var encounter := _mirror_encounter()
	var original := PlayedCard.new(_mirror_card(), &"left", &"middle")
	var result := MirrorCopyResolver.new().resolve(original, RoundState.new(), encounter)
	assert_true(result.accepted, "valid mirror card should resolve")
	assert_true(result.generated, "eligible card should generate copy")
	assert_equal(result.copy.primary_target, &"right", "reflected source should be right")
	assert_equal(result.copy.secondary_target, &"middle", "reflected target should be middle")
	assert_true(result.copy.is_mirror_copy, "copy should be marked")
	assert_false(
		result.copy.runtime_effects[0] == original.definition.mirror_effects[0],
		"mirror effects must be deep copied"
	)
```

同时覆盖：

```text
middle → right  映射为 middle → left
无 mirror_effects 的 GAP 牌不生成副本且不消耗机会
已有一个镜像副本后不再生成
is_mirror_copy=true 的输入绝不递归
未知或非相邻端点返回失败
第三张真实牌仍被“两张上限”拒绝
撤销一次同时移除原牌和依附副本
```

- [ ] **Step 2: 运行并确认 `MirrorCopyResolver` 尚不存在**

```powershell
$log = "$env:TEMP\project-joker-task02-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror resolver tests to fail" }
```

- [ ] **Step 3: 实现结构化结果和纯镜像解析器**

```gdscript
# scripts/cards/mirror_copy_result.gd
class_name MirrorCopyResult
extends RefCounted

var accepted: bool
var generated: bool
var copy: PlayedCard
var reason: String
```

```gdscript
# scripts/cards/mirror_copy_resolver.gd 的映射核心
func _reflected_targets(primary: StringName, secondary: StringName) -> Array[StringName]:
	if primary == &"left" and secondary == &"middle":
		return [&"right", &"middle"]
	if primary == &"middle" and secondary == &"right":
		return [&"middle", &"left"]
	return []
```

解析器只读取参数，不读取场景节点，也不修改传入 `RoundState`。副本 `runtime_effects` 从 `definition.mirror_effects` 逐项新建 `EffectSpec`，并写入 `source_card_id`、`source_play_id`、`source_slot_id`。

- [ ] **Step 4: 在 `CardRules` 中一次性构建候选状态**

```gdscript
var real_count := state.played_cards.filter(
	func(card: PlayedCard) -> bool: return not card.is_mirror_copy
).size()
played_card.play_id = StringName("play_%d" % (real_count + 1))

var next_state := state.clone()
next_state.played_cards.append(played_card.clone())
var mirror_result := MirrorCopyResolver.new().resolve(
	played_card, next_state, encounter
)
if not mirror_result.accepted:
	return ActionResult.new(false, mirror_result.reason, state)
if mirror_result.generated:
	next_state.played_cards.append(mirror_result.copy)
if encounter != null:
	var validation_report := RoundResolver.new().resolve(
		next_state, encounter, context
	)
	if not validation_report.valid:
		return ActionResult.new(false, validation_report.reason, state)
```

`RoundController.play_card()` 必须把自己的 `encounter` 传入 `CardRules`。`SingleEncounterSession.is_card_used()` 忽略 `is_mirror_copy`，避免副本让同名真实牌误判为已使用。历史仍只 `push()` 一次，因此一次撤销恢复到原牌与副本都不存在的上一快照。
原牌的 `source_slot_id` 留空；副本的 `source_slot_id` 明确写为
`left_gap` 或 `right_gap`，事件中的 `mirror_slot_id` 写入反照后的另一槽。

- [ ] **Step 5: 运行镜像、卡牌、控制器和全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-task02-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 6: 只提交镜像生成代码**

```powershell
git add -- tests/mirror_copy_resolver_test.gd tests/card_rules_test.gd tests/round_controller_test.gd scripts/cards/mirror_copy_result.gd scripts/cards/mirror_copy_resolver.gd scripts/cards/card_rules.gd scripts/run/round_controller.gd scripts/ui/single_encounter_session.gd
git commit --only -m "feat: generate mirror cards atomically" -- tests/mirror_copy_resolver_test.gd tests/card_rules_test.gd tests/round_controller_test.gd scripts/cards/mirror_copy_result.gd scripts/cards/mirror_copy_resolver.gd scripts/cards/card_rules.gd scripts/run/round_controller.gd scripts/ui/single_encounter_session.gd
```

### Task 3: 统一方向、桌间单桌目标与镜像结算事件

**Files:**
- Modify: `scripts/resolution/round_resolver.gd`
- Modify: `scripts/resolution/resolution_event.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Modify: `scripts/validation/content_validator.gd`
- Test: `tests/mirror_resolution_test.gd`
- Test: `tests/resolution_test.gd`
- Test: `tests/content_validator_test.gd`

**Interfaces:**
- Consumes: `EncounterRuleProfile.resolution_direction`
- Consumes: `PlayedCard.effective_effects()`
- Produces: `ResolutionReport.ordered_rule_ids`
- Produces: 带 `source_card_id/source_slot_id/mirror_slot_id` 的镜像事件

- [ ] **Step 1: 写左右方向和双事件顺序的失败测试**

```gdscript
func _test_right_to_left_orders_report() -> void:
	var encounter := _three_rule_encounter(
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	)
	var report := RoundResolver.new().resolve(_assigned_state(), encounter)
	assert_equal(report.ordered_rule_ids, [&"right", &"middle", &"left"], "RTL should be public")
	assert_equal(
		report.resolution_direction,
		EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT,
		"report should expose effective direction"
	)
```

再构造一张原牌和一个派生副本，断言：

```text
原牌事件标签使用牌名
副本事件标签使用“镜像副本：牌名”
GAP 的 MODIFY_COEFFICIENT/REPEAT_TABLE 作用于 secondary_target
TABLE 的相同操作仍作用于 primary_target
基础方向右到左再遇到 REVERSE_RESOLUTION 后变为左到右
预览和 commit 返回同一个有效报告对象
```

- [ ] **Step 2: 运行并确认方向仍被硬编码为左到右**

```powershell
$log = "$env:TEMP\project-joker-task03-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected direction tests to fail" }
```

- [ ] **Step 3: 修改解析器使用有效效果和基础方向**

```gdscript
var reverse_order := (
	encounter.rule_profile != null
	and encounter.rule_profile.resolution_direction
		== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
)

for played_card in state.played_cards:
	for effect in played_card.effective_effects():
		var single_table_target := (
			played_card.secondary_target
			if played_card.definition.target_type == CardDefinition.TargetType.GAP
			else played_card.primary_target
		)
```

`REVERSE_RESOLUTION` 继续切换 `reverse_order`。完成 `ordered_rules` 后写入：

```gdscript
report.resolution_direction = (
	EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
	if reverse_order
	else EncounterRuleProfile.ResolutionDirection.LEFT_TO_RIGHT
)
report.ordered_rule_ids.assign(ordered_rule_ids)
```

- [ ] **Step 4: 收紧内容校验**

```gdscript
if not card.mirror_effects.is_empty():
	if card.target_type != CardDefinition.TargetType.GAP:
		errors.append("card %s mirror effects require a gap target" % card.id)
	for effect in card.mirror_effects:
		if effect.operation not in [
			EffectSpec.Operation.MODIFY_COEFFICIENT,
			EffectSpec.Operation.REPEAT_TABLE,
			EffectSpec.Operation.LINK_NEIGHBORS,
		]:
			errors.append("card %s has forbidden mirror operation" % card.id)
```

普通 `effects` 中，`MODIFY_COEFFICIENT` 和 `REPEAT_TABLE` 允许 `TABLE` 或 `GAP`；`LINK_NEIGHBORS` 仍只允许 `GAP` 且 `amount == 1`。

- [ ] **Step 5: 运行结算、内容与全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-task03-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 6: 提交方向与结算代码**

```powershell
git add -- tests/mirror_resolution_test.gd tests/resolution_test.gd tests/content_validator_test.gd scripts/resolution/round_resolver.gd scripts/resolution/resolution_event.gd scripts/resolution/resolution_report.gd scripts/validation/content_validator.gd
git commit --only -m "feat: resolve public direction and mirror effects" -- tests/mirror_resolution_test.gd tests/resolution_test.gd tests/content_validator_test.gd scripts/resolution/round_resolver.gd scripts/resolution/resolution_event.gd scripts/resolution/resolution_report.gd scripts/validation/content_validator.gd
```

### Task 4: 增加反照牌厅的两种刻印操作

**Files:**
- Modify: `scripts/engravings/engraving_definition.gd`
- Modify: `scripts/engravings/engraving_resolver.gd`
- Test: `tests/mirror_engraving_resolution_test.gd`
- Test: `tests/dealer_and_engraving_resolution_test.gd`

**Interfaces:**
- Produces: `EngravingDefinition.Operation.BRIDGE_BACKWARD`
- Produces: `EngravingDefinition.Operation.MIRROR_PRISM`
- Modifies: `EngravingResolver.parity_overrides(..., rule_id)`

- [ ] **Step 1: 写逆流桥和镜棱的失败测试**

```gdscript
func _test_backflow_targets_previous_rule() -> void:
	var outcomes := EngravingResolver.new().table_outcomes(
		state, [&"d3"], true, [&"right", &"middle", &"left"], 1, values, context
	)
	assert_equal(outcomes[0].target_table_id, &"right", "backflow should target previous ordered rule")

func _test_mirror_prism_requires_adjacent_copy() -> void:
	var flags := EngravingResolver.new().parity_overrides(
		state, [&"d3"], &"middle", context
	)
	assert_equal(flags, [true], "adjacent mirror should enable parity override")
```

另测：第一张规则台没有“上一张”时返回 `effect_applied=false`；没有镜像副本、镜像不相邻或刻印面未投出时 `MIRROR_PRISM` 不激活。

- [ ] **Step 2: 运行并确认新枚举不存在**

```powershell
$log = "$env:TEMP\project-joker-task04-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror engraving tests to fail" }
```

- [ ] **Step 3: 实现明确枚举和纯状态判断**

```gdscript
enum Operation {
	ECHO_ADJACENT,
	ANCHOR_DIE,
	BRIDGE_FORWARD,
	PRISM_PARITY,
	BRIDGE_BACKWARD,
	MIRROR_PRISM,
}
```

`BRIDGE_BACKWARD` 使用 `ordered_rule_ids[rule_index - 1]`。`MIRROR_PRISM` 通过 `state.played_cards` 查找 `is_mirror_copy`，并判断当前 `rule_id` 是否等于副本的 `primary_target` 或 `secondary_target`；不得检查任何 UI 节点。

- [ ] **Step 4: 运行刻印与全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-task04-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 5: 提交刻印逻辑**

```powershell
git add -- tests/mirror_engraving_resolution_test.gd tests/dealer_and_engraving_resolution_test.gd scripts/engravings/engraving_definition.gd scripts/engravings/engraving_resolver.gd
git commit --only -m "feat: add mirror hall engraving operations" -- tests/mirror_engraving_resolution_test.gd tests/dealer_and_engraving_resolution_test.gd scripts/engravings/engraving_definition.gd scripts/engravings/engraving_resolver.gd
```

### Task 5: 参数化地区定义并保持金线回廊兼容

**Files:**
- Create: `scripts/areas/area_definition.gd`
- Create: `scripts/areas/area_catalog.gd`
- Create: `resources/areas/gold_corridor.tres`
- Create: `resources/encounters/gold_corridor/iron_abacus.tres`
- Modify: `scripts/run/area_run_session.gd`
- Modify: `scripts/rooms/gold_corridor_catalog.gd`
- Modify: `scripts/dealers/dealer_catalog.gd`
- Modify: `scripts/engravings/engraving_catalog.gd`
- Modify: `scripts/ui/area_complete_panel.gd`
- Test: `tests/area_definition_test.gd`
- Test: `tests/gold_corridor_area_run_test.gd`
- Test: `tests/gold_corridor_catalog_test.gd`

**Interfaces:**
- Produces: `AreaDefinition.find_room(id)` 与两组只读路线 ID 属性
- Produces: `AreaCatalog.gold_corridor()`
- Produces: `DealerCatalog.find_dealer(id)`
- Changes: `AreaRunSession` owns `area_definition` instead of `room_catalog`

- [ ] **Step 1: 写金线地区定义与兼容失败测试**

```gdscript
func _test_gold_area_definition() -> void:
	var area := AreaCatalog.new().gold_corridor()
	assert_equal(area.id, &"gold_corridor", "gold area ID should be stable")
	assert_equal(area.starting_deck_ids.size(), 12, "gold deck stays twelve")
	assert_equal(area.first_route_ids.size(), 2, "first route stays two")
	assert_equal(area.second_route_ids.size(), 2, "second route stays two")
	assert_equal(area.dealer_id, &"dealer_iron_abacus", "dealer stays Iron Abacus")
	assert_equal(area.dealer_target, 150, "dealer target stays 150")
```

更新 `gold_corridor_area_run_test.gd`，用 `area.area_definition.find_room()` 替换 `area.room_catalog.find_room()`，并断言旧固定种子路径、奖励池、完成摘要和失败重开结果不变。

- [ ] **Step 2: 运行并确认 `AreaCatalog` 不存在**

```powershell
$log = "$env:TEMP\project-joker-task05-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected area definition tests to fail" }
```

- [ ] **Step 3: 实现 `AreaDefinition`**

```gdscript
class_name AreaDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var first_route_ids: Array[StringName] = []
@export var second_route_ids: Array[StringName] = []
@export var rooms: Array[RoomDefinition] = []
@export var starting_deck_ids: Array[StringName] = []
@export var starting_intel_tickets := 0
@export var initial_engraving_id: StringName = &""
@export var initial_engraving_die_id: StringName = &""
@export_range(0, 6, 1) var initial_engraving_face := 0
@export var dealer_id: StringName
@export var dealer_encounter: EncounterDefinition
@export var dealer_target := 0
@export var shop_offer_ids: Array[StringName] = []
@export var engraving_offer_ids: Array[StringName] = []
```

`validate(card_catalog, dealer_catalog, engraving_catalog)` 明确校验两组各两个不重复房间、12 张唯一牌、合法初始刻印位置、至少 3 张可售牌、庄家与遭遇存在、奖励池至少 3 项。

- [ ] **Step 4: 用地区定义驱动 `AreaRunSession`**

保留兼容构造顺序：

```gdscript
func _init(
	p_seed_value: int = DEFAULT_SEED,
	p_area_definition: AreaDefinition = null,
	p_card_catalog: CardCatalog = null,
	p_dealer_catalog: DealerCatalog = null,
	p_engraving_catalog: EngravingCatalog = null
) -> void:
	area_definition = (
		p_area_definition
		if p_area_definition != null
		else AreaCatalog.new().gold_corridor()
	)
```

下列硬编码全部改为地区字段：

```text
GoldCorridorCatalog → area_definition
card_catalog.starter_ids() → area_definition.starting_deck_ids
card_catalog.shop_ids() → area_definition.shop_offer_ids
dealer_catalog.iron_abacus() → dealer_catalog.find_dealer(area_definition.dealer_id)
SingleEncounterFixture.make_encounter() → area_definition.dealer_encounter
DEALER_TARGET → area_definition.dealer_target
engraving_catalog.all_ids() → area_definition.engraving_offer_ids
```

`start()` 根据地区定义创建六颗骰子，并原子安装可选初始刻印。`completion_snapshot()` 增加 `area_id`、`rng_state`、完整 `die_profiles`，庄家 ID 从定义读取。`AreaCompletePanel` 使用 `AreaDefinition` 和 `DealerCatalog` 查中文名，不能再写死“铁算盘”。

- [ ] **Step 5: 运行金线兼容与全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-task05-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 6: 提交地区框架**

```powershell
git add -- tests/area_definition_test.gd tests/gold_corridor_area_run_test.gd tests/gold_corridor_catalog_test.gd scripts/areas/area_definition.gd scripts/areas/area_catalog.gd resources/areas/gold_corridor.tres resources/encounters/gold_corridor/iron_abacus.tres scripts/run/area_run_session.gd scripts/rooms/gold_corridor_catalog.gd scripts/dealers/dealer_catalog.gd scripts/engravings/engraving_catalog.gd scripts/ui/area_complete_panel.gd
git commit --only -m "refactor: parameterize area run definitions" -- tests/area_definition_test.gd tests/gold_corridor_area_run_test.gd tests/gold_corridor_catalog_test.gd scripts/areas/area_definition.gd scripts/areas/area_catalog.gd resources/areas/gold_corridor.tres resources/encounters/gold_corridor/iron_abacus.tres scripts/run/area_run_session.gd scripts/rooms/gold_corridor_catalog.gd scripts/dealers/dealer_catalog.gd scripts/engravings/engraving_catalog.gd scripts/ui/area_complete_panel.gd
```

### Task 6: 创建六张牌、四个房间、镜面夫人与四种刻印

**Files:**
- Create: `resources/cards/mirror_hall/*.tres`（6 个文件）
- Create: `resources/rooms/mirror_hall/*.tres`（4 个文件）
- Create: `resources/dealers/mirror_hall/dealer_mirror_lady.tres`
- Create: `resources/engravings/mirror_hall/*.tres`（4 个文件）
- Create: `resources/encounters/mirror_hall/mirror_lady.tres`
- Create: `resources/areas/mirror_hall.tres`
- Modify: `scripts/cards/card_catalog.gd`
- Modify: `scripts/dealers/dealer_catalog.gd`
- Modify: `scripts/engravings/engraving_catalog.gd`
- Modify: `scripts/areas/area_catalog.gd`
- Modify: `scripts/validation/content_validator.gd`
- Test: `tests/mirror_hall_content_catalog_test.gd`
- Test: `tests/stage4_card_catalog_test.gd`
- Test: `tests/stage5_content_catalog_test.gd`

**Interfaces:**
- Produces: `AreaCatalog.mirror_hall()`
- Produces: `CardCatalog.mirror_hall_card_ids()`
- Produces: `EngravingCatalog.mirror_hall_ids()`
- Produces: `DealerCatalog.mirror_lady()`

- [ ] **Step 1: 写精确数量、ID、规则与首手约束的失败测试**

```gdscript
func _test_mirror_content_counts() -> void:
	var cards := CardCatalog.new()
	var engravings := EngravingCatalog.new()
	var dealers := DealerCatalog.new()
	var area := AreaCatalog.new().mirror_hall()
	assert_equal(cards.all_cards().size(), 24, "repository should contain 24 cards")
	assert_equal(engravings.all_engravings().size(), 8, "repository should contain 8 engravings")
	assert_equal(dealers.all_dealers().size(), 2, "repository should contain 2 dealers")
	assert_equal(area.rooms.size(), 4, "mirror area should contain 4 rooms")
	assert_equal(area.dealer_target, 190, "Mirror Lady target should be exact")
	assert_equal(area.starting_intel_tickets, 6, "mirror area starts with six tickets")
```

逐一断言六张新牌的 `target_type == GAP`、原效果、镜像效果和非空中文文案；逐一断言四个房间的方向、目标和奖励；断言 `d3` 第 4 面预装 `engraving_bridge`。

- [ ] **Step 2: 运行并确认资源尚未加载**

```powershell
$log = "$env:TEMP\project-joker-task06-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror content tests to fail" }
```

- [ ] **Step 3: 创建六张卡牌资源**

资源使用以下精确表：

```text
mirror_folded_map       折光映射   effects=系数+2          mirror=系数+1
mirror_soft_echo        轻声复写   effects=额外2次         mirror=额外1次
mirror_hinged_bridge    合页桥     effects=连接+目标系数+1  mirror=连接
mirror_double_exposure  双重曝光   effects=系数+2+额外1次  mirror=系数+1
mirror_deep_echo        深层回声   effects=系数+1+额外2次  mirror=额外1次
mirror_silver_bridge    银面长桥   effects=连接+额外1次    mirror=连接
```

每个 `.tres` 都设置 `target_type = 2`，`LINK_NEIGHBORS amount = 1`，并在 `rule_text` 同时写出原牌和镜像版本。`CardCatalog` 保持旧 `STARTER_PATHS` 12 张和旧 `SHOP_PATHS` 6 张不变，新增独立 `MIRROR_HALL_PATHS`；`all_cards()` 和 `_cards_by_id` 包含三组，避免破坏旧教学局和金线商店。

- [ ] **Step 4: 创建四个普通房和镜面夫人遭遇**

使用下列确定资源：

```text
mirror_room_reverse_drill   逆序校场   RTL  target=110 reward=5
  left=精确为8/2槽/系数3, middle=连续两数/2槽/系数3, right=两枚全偶/2槽/系数3
mirror_room_double_ledger   双影账页   LTR  target=116 reward=6
  left=两枚全偶/2槽/系数3, middle=精确为9/2槽/系数3, right=连续两数/2槽/系数3
mirror_room_echo_bridge     回声桥     RTL  target=132 reward=7
  left=连续两数/2槽/系数4, middle=精确为7/2槽/系数3, right=两枚全偶/2槽/系数4
mirror_room_symmetric_page  对称账页   LTR  target=140 reward=8
  left=精确为10/2槽/系数4, middle=连续三数/3槽/系数3, right=单枚偶数/1槽/系数4
mirror_lady encounter       镜面夫人   RTL  target=190
  left=精确为9/2槽/系数4, middle=连续三数/3槽/系数4, right=两枚全偶/2槽/系数5
```

五个 `EncounterRuleProfile` 都设置 `mirror_first_table_card = true`、`mirror_limit_per_round = 1`。

- [ ] **Step 5: 创建镜像刻印与地区资源**

```text
engraving_afterimage        余像   ECHO_ADJACENT amount=1
engraving_silver_anchor     银锚   ANCHOR_DIE amount=3
engraving_backflow_bridge   逆流桥 BRIDGE_BACKWARD amount=1
engraving_mirror_prism      镜棱   MIRROR_PRISM amount=0
```

`resources/areas/mirror_hall.tres` 精确写入设计规格中的 12 张起始牌、两组房间、6 张商店候选、4 项刻印奖励、`dealer_mirror_lady`、目标 190、初始 6 券和 `d3/4/engraving_bridge`。

- [ ] **Step 6: 运行内容审计和全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-task06-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 7: 提交内容资源**

```powershell
git add -- tests/mirror_hall_content_catalog_test.gd tests/stage4_card_catalog_test.gd tests/stage5_content_catalog_test.gd resources/cards/mirror_hall resources/rooms/mirror_hall resources/dealers/mirror_hall resources/engravings/mirror_hall resources/encounters/mirror_hall resources/areas/mirror_hall.tres scripts/cards/card_catalog.gd scripts/dealers/dealer_catalog.gd scripts/engravings/engraving_catalog.gd scripts/areas/area_catalog.gd scripts/validation/content_validator.gd
git commit --only -m "feat: add mirror hall content catalog" -- tests/mirror_hall_content_catalog_test.gd tests/stage4_card_catalog_test.gd tests/stage5_content_catalog_test.gd resources/cards/mirror_hall resources/rooms/mirror_hall resources/dealers/mirror_hall resources/engravings/mirror_hall resources/encounters/mirror_hall resources/areas/mirror_hall.tres scripts/cards/card_catalog.gd scripts/dealers/dealer_catalog.gd scripts/engravings/engraving_catalog.gd scripts/areas/area_catalog.gd scripts/validation/content_validator.gd
```

### Task 7: 验证反照牌厅完整阶段机与固定种子可玩性

**Files:**
- Modify: `scripts/run/area_run_session.gd`
- Modify: `scripts/run/three_round_encounter_session.gd`
- Test: `tests/mirror_hall_area_run_test.gd`
- Test: `tests/parameterized_three_round_session_test.gd`
- Test: `tests/gold_corridor_area_run_test.gd`

**Interfaces:**
- Consumes: `AreaCatalog.mirror_hall()`
- Produces: 可复现的两房、两店、镜面夫人、三选一刻印、完成快照流程

- [ ] **Step 1: 写完整阶段流和原子失败测试**

```gdscript
func _new_mirror_run() -> AreaRunSession:
	return AreaRunSession.new(20260727, AreaCatalog.new().mirror_hall())

func _test_mirror_area_starts_with_fixed_build() -> void:
	var run := _new_mirror_run()
	assert_true(run.start().accepted, "mirror area should start")
	assert_equal(run.phase, AreaRunSession.Phase.ROUTE_CHOICE, "start opens routes")
	assert_equal(run.deck_ids, run.area_definition.starting_deck_ids, "deck is fixed")
	assert_equal(run.intel_tickets, 6, "tickets are fixed")
	var d3 := run.die_profiles.filter(func(die): return die.id == &"d3")[0]
	assert_equal(d3.engraving_id, &"engraving_bridge", "d3 should be pre-engraved")
	assert_equal(d3.engraved_face, 4, "engraving face should be four")
```

完整测试必须遍历四种路线组合，使用测试辅助器提交确定的合法报告，经过两次商店后进入 `dealer_mirror_lady`，成功后只从四种镜像刻印中得到三个无重复候选，安装后快照包含 `area_id = mirror_hall`、RNG、12 张牌和六颗骰子。另测非法资源、商店不足三张、镜像生成失败和提交报告不一致时，阶段与 RNG 快照都不变。

- [ ] **Step 2: 运行并确认镜像地区流程尚未通过**

```powershell
$log = "$env:TEMP\project-joker-task07-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror area loop tests to fail" }
```

- [ ] **Step 3: 修正固定首手与地区池消费**

`ThreeRoundEncounterSession` 继续使用同一个 `RunRng`，但不得再自行读取全局商店池。固定种子 `20260727` 下首轮四张必须至少包含一个：

```gdscript
const MIRROR_TEACHING_IDS := [
	&"mirror_folded_map",
	&"mirror_soft_echo",
	&"mirror_hinged_bridge",
]
```

约束应通过地区牌组排序和现有确定洗牌得到，不在运行中“发现没抽到再塞牌”。若当前 `CardDeck` 算法无法满足，调整 `resources/areas/mirror_hall.tres` 中 12 张 ID 的顺序，不修改 RNG。

- [ ] **Step 4: 运行镜像地区、金线回归和全量测试**

```powershell
$log = "$env:TEMP\project-joker-task07-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 5: 提交完整地区会话**

```powershell
git add -- tests/mirror_hall_area_run_test.gd tests/parameterized_three_round_session_test.gd tests/gold_corridor_area_run_test.gd scripts/run/area_run_session.gd scripts/run/three_round_encounter_session.gd resources/areas/mirror_hall.tres
git commit --only -m "feat: complete mirror hall area session" -- tests/mirror_hall_area_run_test.gd tests/parameterized_three_round_session_test.gd tests/gold_corridor_area_run_test.gd scripts/run/area_run_session.gd scripts/run/three_round_encounter_session.gd resources/areas/mirror_hall.tres
```

### Task 8: 在三轨界面显示方向、镜像槽与来源事件

**Files:**
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scenes/components/resolution_panel.tscn`
- Modify: `scripts/ui/resolution_panel.gd`
- Modify: `scripts/ui/card_token.gd`
- Test: `tests/mirror_encounter_ui_contract_test.gd`
- Test: `tests/mirror_encounter_input_self_check.gd`
- Test: `tests/single_encounter_layout_self_check.gd`

**Interfaces:**
- Produces signal: `card_selected(card_index: int, card: CardDefinition, token: Control)`
- Produces node: `%DirectionBadge`
- Produces nodes: `%LeftMirrorLayer`, `%RightMirrorLayer`
- Consumes: `ResolutionReport.ordered_rule_ids` 与镜像事件字段

- [ ] **Step 1: 写场景契约失败测试**

```gdscript
var scene := load("res://scenes/run/single_encounter_screen.tscn").instantiate()
assert_true(scene.get_node_or_null("%DirectionBadge") != null, "direction badge is required")
assert_true(scene.get_node_or_null("%LeftMirrorLayer") != null, "left mirror layer is required")
assert_true(scene.get_node_or_null("%RightMirrorLayer") != null, "right mirror layer is required")
```

输入自检通过真实按钮完成：选择 `mirror_folded_map`、点击左槽、确认右槽虚拟层出现“镜像”标签；点击撤销后标签消失；再放置原牌后仍可在右槽放第二张真实牌。

- [ ] **Step 2: 运行 UI 契约并确认节点缺失**

```powershell
$log = "$env:TEMP\project-joker-task08-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/mirror_encounter_input_self_check.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror UI self-check to fail" }
```

- [ ] **Step 3: 在 `.tscn` 中建立稳定结构**

`DirectionBadge` 放在三轨标题和目标状态之间，文本同时包含箭头与中文：

```text
← 从右向左结算
→ 从左向右结算
```

两个镜像层放在对应 `LeftGap`、`RightGap` 的同一布局容器内，使用虚线边框和“镜像”文字；层本身 `mouse_filter = IGNORE`，不替代实体槽按钮。脚本只能绑定可见性和文本，不在运行时创建整块布局。

- [ ] **Step 4: 绑定预览报告和镜像来源**

```gdscript
func _refresh_direction(report: ResolutionReport) -> void:
	%DirectionBadge.text = (
		"← 从右向左结算"
		if report.resolution_direction
			== EncounterRuleProfile.ResolutionDirection.RIGHT_TO_LEFT
		else "→ 从左向右结算"
	)
```

镜像层从 `session.controller.state.played_cards` 中读取 `is_mirror_copy`；`ResolutionPanel` 用事件列表原顺序渲染，不重新排序，镜像行必须显示：

```text
镜像副本：折光映射｜right → middle｜系数 +1
```

- [ ] **Step 5: 运行 1280×720 输入与布局自检**

```powershell
$log = "$env:TEMP\project-joker-task08-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/mirror_encounter_input_self_check.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 6: 提交三轨镜像 UI**

```powershell
git add -- tests/mirror_encounter_ui_contract_test.gd tests/mirror_encounter_input_self_check.gd tests/single_encounter_layout_self_check.gd scenes/run/single_encounter_screen.tscn scripts/ui/single_encounter_screen.gd scenes/components/resolution_panel.tscn scripts/ui/resolution_panel.gd scripts/ui/card_token.gd
git commit --only -m "feat(ui): visualize mirror resolution" -- tests/mirror_encounter_ui_contract_test.gd tests/mirror_encounter_input_self_check.gd tests/single_encounter_layout_self_check.gd scenes/run/single_encounter_screen.tscn scripts/ui/single_encounter_screen.gd scenes/components/resolution_panel.tscn scripts/ui/resolution_panel.gd scripts/ui/card_token.gd
```

### Task 9: 抽取共用地区场景并加入反照牌厅页面

**Files:**
- Create: `scripts/ui/area_run_screen.gd`
- Create: `scenes/run/area_run_screen.tscn`
- Modify: `scripts/ui/gold_corridor_run_screen.gd`
- Modify: `scenes/run/gold_corridor_run_screen.tscn`
- Create: `scripts/ui/mirror_hall_run_screen.gd`
- Create: `scenes/run/mirror_hall_run_screen.tscn`
- Modify: `scripts/ui/area_complete_panel.gd`
- Test: `tests/area_run_ui_contract_test.gd`
- Test: `tests/gold_corridor_ui_contract_test.gd`
- Test: `tests/mirror_hall_input_self_check.gd`

**Interfaces:**
- Produces: `AreaRunScreen.configure(area_definition, seed)`
- Produces hooks: `_after_encounter_bound()`, `_after_card_selected(...)`, `_after_dealer_bound()`
- Consumes: `AreaRunSession`

- [ ] **Step 1: 写两个地区场景的共用契约失败测试**

```gdscript
for path in [
	"res://scenes/run/gold_corridor_run_screen.tscn",
	"res://scenes/run/mirror_hall_run_screen.tscn",
]:
	var screen := load(path).instantiate()
	assert_true(screen is AreaRunScreen, "%s should inherit AreaRunScreen" % path)
	assert_true(screen.get_node_or_null("%EncounterScreen") != null, "encounter is required")
	assert_true(screen.get_node_or_null("%RouteChoicePanel") != null, "routes are required")
	assert_true(screen.get_node_or_null("%ShopScreen") != null, "shop is required")
	assert_true(screen.get_node_or_null("%EngravingRewardPanel") != null, "reward is required")
```

- [ ] **Step 2: 运行并确认反照牌厅场景不存在**

```powershell
$log = "$env:TEMP\project-joker-task09-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected shared area screen tests to fail" }
```

- [ ] **Step 3: 提取阶段编排，不复制 400 行页面脚本**

`AreaRunScreen` 持有当前金线页面中的通用逻辑：

```text
start / route selection / bind encounter / round summary
open and leave shop / create dealer
engraving select and install
complete / fail / restart / return
settings and shared SFX
```

只保留以下可覆盖方法：

```gdscript
func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().gold_corridor()

func build_seed() -> int:
	return AreaRunSession.DEFAULT_SEED

func _after_encounter_bound() -> void:
	pass

func _after_card_selected(
	_card_index: int, _card: CardDefinition, _token: Control
) -> void:
	pass

func _after_dealer_bound() -> void:
	pass
```

`GoldCorridorRunScreen` 返回金线定义并保留旧四点引导适配；`MirrorHallRunScreen` 返回反照定义与 `20260727`。两者都继承 `area_run_screen.tscn`，不各自复制子场景树。

- [ ] **Step 4: 用真实输入走到首个反照房**

`mirror_hall_input_self_check.gd` 必须通过真实路线按钮进入第一房，断言：

```text
页面地区文案为“反照牌厅”
目标与所选房间资源一致
方向标记与资源一致
首手四张中至少一张可镜像
返回按钮回到 single_encounter_screen.tscn
```

- [ ] **Step 5: 运行两个地区 UI 回归**

```powershell
$log = "$env:TEMP\project-joker-task09-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 6: 提交共用地区页面**

```powershell
git add -- tests/area_run_ui_contract_test.gd tests/gold_corridor_ui_contract_test.gd tests/mirror_hall_input_self_check.gd scripts/ui/area_run_screen.gd scenes/run/area_run_screen.tscn scripts/ui/gold_corridor_run_screen.gd scenes/run/gold_corridor_run_screen.tscn scripts/ui/mirror_hall_run_screen.gd scenes/run/mirror_hall_run_screen.tscn scripts/ui/area_complete_panel.gd
git commit --only -m "refactor(ui): share area run orchestration" -- tests/area_run_ui_contract_test.gd tests/gold_corridor_ui_contract_test.gd tests/mirror_hall_input_self_check.gd scripts/ui/area_run_screen.gd scenes/run/area_run_screen.tscn scripts/ui/gold_corridor_run_screen.gd scenes/run/gold_corridor_run_screen.tscn scripts/ui/mirror_hall_run_screen.gd scenes/run/mirror_hall_run_screen.tscn scripts/ui/area_complete_panel.gd
```

### Task 10: 实现三个一次性反照牌厅提示

**Files:**
- Create: `scripts/ui/tutorial/mirror_hall_guide_flow.gd`
- Create: `scripts/ui/tutorial/mirror_hall_guide_progress_store.gd`
- Modify: `scripts/ui/mirror_hall_run_screen.gd`
- Test: `tests/mirror_hall_guide_flow_test.gd`
- Test: `tests/mirror_hall_guide_progress_store_test.gd`
- Test: `tests/mirror_hall_guide_input_self_check.gd`

**Interfaces:**
- Produces: `MirrorHallGuideFlow.card_spec(checkpoint_id)`
- Produces: `MirrorHallGuideProgressStore` 区段 `[mirror_hall_guide_v1]`
- Reuses: `IronAbacusGuideOverlay.open_card(card_spec, targets)`

- [ ] **Step 1: 写顺序、精确文案和持久化隔离的失败测试**

```gdscript
const EXPECTED_ORDER: Array[StringName] = [
	&"direction",
	&"mirror",
	&"dealer",
]

func _test_exact_order() -> void:
	var flow := MirrorHallGuideFlow.new()
	assert_equal(flow.checkpoint_ids(), EXPECTED_ORDER, "mirror guide order is fixed")
	assert_equal(flow.card_spec(&"direction")["progress_index"], 1, "direction is 1/3")
	assert_equal(flow.card_spec(&"mirror")["progress_index"], 2, "mirror is 2/3")
	assert_equal(flow.card_spec(&"dealer")["progress_index"], 3, "dealer is 3/3")
```

持久化测试先写入 `[onboarding]`、`[iron_abacus_guide_v1]`、`[gold_corridor_guide_v1]`，调用 `reset()` 后断言只有 `[mirror_hall_guide_v1]` 四个键恢复为 false。

- [ ] **Step 2: 运行并确认新流程不存在**

```powershell
$log = "$env:TEMP\project-joker-task10-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror guide tests to fail" }
```

- [ ] **Step 3: 实现精确三卡规格**

```gdscript
const CARD_SPECS := {
	&"direction": {
		"id": &"direction",
		"progress_label": "反照提示",
		"progress_index": 1,
		"progress_total": 3,
		"title": "先看方向，再看路线",
		"instruction": "反照牌厅的每场遭遇都会公开标记结算方向。路线卡会说明从左向右或从右向左；右侧结算轨迹按真实顺序预演，不要仅按桌面位置判断先后。",
		"target_ids": [&"encounter_goal", &"direction_badge", &"resolution_panel"],
	},
	&"mirror": {
		"id": &"mirror",
		"progress_label": "反照提示",
		"progress_index": 2,
		"progress_total": 3,
		"title": "原牌与镜像一起预演",
		"instruction": "本场启用镜像规则。每轮第一张桌间槽手法牌会在另一侧生成弱化副本；副本不占出牌次数，也不会继续复制。放入槽位后，结算轨迹会同时显示原牌与镜像结果。",
		"target_ids": [&"selected_card", &"left_gap", &"right_gap", &"resolution_panel"],
	},
	&"dealer": {
		"id": &"dealer",
		"progress_label": "反照提示",
		"progress_index": 3,
		"progress_total": 3,
		"title": "镜面夫人",
		"instruction": "本场固定从右向左结算。每轮第一张桌间槽牌都会生成资源中声明的弱化镜像版本；撤销原牌会同时撤销副本，确认前仍可调整完整方案。",
		"target_ids": [&"dealer_panel", &"direction_badge", &"left_gap", &"right_gap", &"resolution_panel"],
	},
}
```

- [ ] **Step 4: 接入三个真实触发点**

```text
direction：第一次选定路线且对应遭遇界面绑定完成后
mirror：第一次选择 mirror_effects 非空的 GAP 牌，且当前遭遇启用镜像时
dealer：镜面夫人遭遇 UI 绑定完成后
```

第二次路线、商店、失败、重试、重开、奖励和完成页不调用 `_request_guide()`。目标缺失时输出包含 checkpoint 和 target 的 `push_error`，不打开半张遮罩，也不写 seen。Enter、数字键盘 Enter、Esc 和“知道了”调用 `mark_seen()`；“不再提示”只写 `dismissed`。

- [ ] **Step 5: 验证引导前后业务快照一致**

输入自检在打开和关闭每张提示前后比较：

```gdscript
{
	"round": encounter_session.current_round,
	"deck": area_session.deck_ids.duplicate(),
	"tickets": area_session.intel_tickets,
	"rng": area_session.run_rng.snapshot_state(),
	"round_state": encounter_session.current_session.controller.state.clone(),
}
```

除“玩家关闭提示后继续执行的真实操作”外，提示本身不得改变任何字段。

- [ ] **Step 6: 运行引导同步与真实输入测试**

```powershell
$log = "$env:TEMP\project-joker-task10-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/mirror_hall_guide_input_self_check.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 7: 提交反照引导**

```powershell
git add -- tests/mirror_hall_guide_flow_test.gd tests/mirror_hall_guide_progress_store_test.gd tests/mirror_hall_guide_input_self_check.gd scripts/ui/tutorial/mirror_hall_guide_flow.gd scripts/ui/tutorial/mirror_hall_guide_progress_store.gd scripts/ui/mirror_hall_run_screen.gd
git commit --only -m "feat(ui): guide mirror hall mechanics" -- tests/mirror_hall_guide_flow_test.gd tests/mirror_hall_guide_progress_store_test.gd tests/mirror_hall_guide_input_self_check.gd scripts/ui/tutorial/mirror_hall_guide_flow.gd scripts/ui/tutorial/mirror_hall_guide_progress_store.gd scripts/ui/mirror_hall_run_screen.gd
```

### Task 11: 重组主入口并加入反照试玩与重看提示

**Files:**
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `tests/single_encounter_input_self_check.gd`
- Test: `tests/main_entry_ui_contract_test.gd`
- Test: `tests/mirror_hall_guide_replay_input_self_check.gd`

**Interfaces:**
- Produces node: `%MirrorHallRunButton`
- Produces node: `%ReplayMirrorHallGuideButton`
- Preserves node: `%RunTrialButton`
- Preserves node: `%ReplayGoldCorridorGuideButton`

- [ ] **Step 1: 写入口分组和跳转失败测试**

```gdscript
assert_equal(screen.get_node("%RunTrialButton").text, "进入金线回廊", "gold copy is exact")
assert_equal(screen.get_node("%MirrorHallRunButton").text, "进入反照牌厅", "mirror copy is exact")
assert_true(screen.get_node_or_null("%PracticeEntryGroup") != null, "practice group is required")
assert_true(screen.get_node_or_null("%AreaTrialEntryGroup") != null, "area group is required")
```

真实输入测试分别按下两个地区按钮并断言目标场景；重看反照提示按钮先在临时配置写入三个 seen 和 dismissed，再按按钮，断言只重置 `[mirror_hall_guide_v1]` 并进入反照场景。

- [ ] **Step 2: 运行并确认新按钮缺失**

```powershell
$log = "$env:TEMP\project-joker-task11-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/mirror_hall_guide_replay_input_self_check.gd
if ($LASTEXITCODE -eq 0) { throw "Expected mirror entry test to fail" }
```

- [ ] **Step 3: 在场景中建立两组稳定入口**

```text
练习
  重看引导
  重看铁算盘原型引导

地区试玩
  金线回廊：进入金线回廊 / 重看金线回廊提示
  反照牌厅：进入反照牌厅 / 重看反照牌厅提示
```

`bind_external_session()` 隐藏整个入口容器，不逐个维护六个按钮。普通进入反照牌厅只设置配置路径元数据并换场景；重看按钮调用 `MirrorHallGuideProgressStore.reset()` 后再换场景。

- [ ] **Step 4: 运行入口、基础教学和旧地区输入回归**

```powershell
$log = "$env:TEMP\project-joker-task11-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 5: 提交主入口**

```powershell
git add -- tests/single_encounter_input_self_check.gd tests/main_entry_ui_contract_test.gd tests/mirror_hall_guide_replay_input_self_check.gd scenes/run/single_encounter_screen.tscn scripts/ui/single_encounter_screen.gd
git commit --only -m "feat(ui): add mirror hall entry points" -- tests/single_encounter_input_self_check.gd tests/main_entry_ui_contract_test.gd tests/mirror_hall_guide_replay_input_self_check.gd scenes/run/single_encounter_screen.tscn scripts/ui/single_encounter_screen.gd
```

### Task 12: 完成双分辨率、端到端与全量回归验收

**Files:**
- Create: `tests/mirror_hall_layout_self_check.gd`
- Create: `tests/mirror_hall_guide_layout_self_check.gd`
- Create: `tests/mirror_hall_end_to_end_self_check.gd`
- Create: `tests/mirror_hall_visual_capture.gd`

**Interfaces:**
- Consumes: 全部前置任务
- Produces: 可重复的正式验收命令和截图证据

- [ ] **Step 1: 写双分辨率布局断言**

每个布局脚本分别设置 `1280×720` 和 `1920×1080`，断言：

```text
方向标记完整位于安全区
左右实体槽和镜像层不覆盖手牌
结算轨迹能显示镜像来源
三个提示卡与所有聚焦框位于安全区
失败、完成、设置层与引导层 z_index 符合模态顺序
主入口两组按钮无裁切
```

- [ ] **Step 2: 写固定种子端到端自检**

`mirror_hall_end_to_end_self_check.gd` 使用真实页面方法和按钮完成：

```text
进入反照牌厅
选择第一路线并完成三轮
进入第一商店并替换一张牌
选择第二路线并完成三轮
进入第二商店后进入镜面夫人
至少一次放置可镜像牌、撤销、重做并确认
完成镜面夫人
从三项刻印中选择一项并安装
确认完成页 area_id、庄家、牌组、资源、骰子和 RNG 均存在
```

- [ ] **Step 3: 运行三个新验收脚本**

```powershell
$tests = @(
	"mirror_hall_layout_self_check.gd",
	"mirror_hall_guide_layout_self_check.gd",
	"mirror_hall_end_to_end_self_check.gd"
)
foreach ($test in $tests) {
	$log = "$env:TEMP\project-joker-$($test.Replace('.gd','')).log"
	& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s "res://tests/$test"
	$godotExit = $LASTEXITCODE
	$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
	if ($godotExit -ne 0 -or $logErrors) { exit 1 }
}
```

- [ ] **Step 4: 生成十张视觉验收截图**

`mirror_hall_visual_capture.gd` 接受 `--state`、`--width`、`--height`、
`--output` 四个用户参数；等待场景稳定两帧后使用
`get_viewport().get_texture().get_image().save_png(output)`。输出到
`$env:TEMP\project-joker-mirror-visual-acceptance`，不加入 Git：

```powershell
$outputDir = "$env:TEMP\project-joker-mirror-visual-acceptance"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$captures = @(
	@("guide_direction",1280,720),
	@("guide_direction",1920,1080),
	@("guide_mirror",1280,720),
	@("guide_mirror",1920,1080),
	@("guide_dealer",1280,720),
	@("guide_dealer",1920,1080),
	@("normal_mirror",1280,720),
	@("reverse_resolution",1280,720),
	@("mirror_lady",1920,1080),
	@("area_complete",1920,1080)
)
foreach ($capture in $captures) {
	$state = $capture[0]
	$width = $capture[1]
	$height = $capture[2]
	$png = Join-Path $outputDir "$state-$width`x$height.png"
	$log = "$env:TEMP\project-joker-capture-$state-$width`x$height.log"
	& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/mirror_hall_visual_capture.gd -- --state $state --width $width --height $height --output $png
	$godotExit = $LASTEXITCODE
	$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
	if ($godotExit -ne 0 -or $logErrors -or -not (Test-Path -LiteralPath $png)) { exit 1 }
}
```

逐张检查：中文无乱码、方向与箭头一致、镜像有文字标签、聚焦框不越界、
卡牌/骰子/弹层不重叠。若发现问题，返回对应的 Task 8、9、10 或 11 修复并重跑，
不要在验收任务中引入新的页面结构。

- [ ] **Step 5: 运行全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-mirror-final-run-all.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$godotExit = $LASTEXITCODE
$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($godotExit -ne 0 -or $logErrors) { exit 1 }
```

- [ ] **Step 6: 运行明确的旧 UI 回归脚本**

```powershell
$tests = @(
	"single_encounter_input_self_check.gd",
	"single_encounter_layout_self_check.gd",
	"tutorial_input_self_check.gd",
	"tutorial_layout_self_check.gd",
	"stage5_input_self_check.gd",
	"stage5_layout_self_check.gd",
	"stage5_guide_input_self_check.gd",
	"stage5_guide_layout_self_check.gd",
	"gold_corridor_input_self_check.gd",
	"gold_corridor_layout_self_check.gd",
	"gold_corridor_guide_input_self_check.gd",
	"gold_corridor_guide_layout_self_check.gd",
	"settings_input_self_check.gd",
	"settings_layout_self_check.gd"
)
foreach ($test in $tests) {
	$log = "$env:TEMP\project-joker-regression-$($test.Replace('.gd','')).log"
	& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s "res://tests/$test"
	$godotExit = $LASTEXITCODE
	$logErrors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
	if ($godotExit -ne 0 -or $logErrors) { exit 1 }
}
```

- [ ] **Step 7: 做最终差异和文档边界检查**

```powershell
git diff --check
git status --short
git diff --cached --name-only
```

期望：代码工作树干净或只包含本任务尚待提交的代码；暂存区包含设计规格和本实施计划，但任何代码提交都不包含它们。

- [ ] **Step 8: 只提交验收代码**

```powershell
git add -- tests/mirror_hall_layout_self_check.gd tests/mirror_hall_guide_layout_self_check.gd tests/mirror_hall_end_to_end_self_check.gd tests/mirror_hall_visual_capture.gd
git commit --only -m "test: verify mirror hall vertical slice" -- tests/mirror_hall_layout_self_check.gd tests/mirror_hall_guide_layout_self_check.gd tests/mirror_hall_end_to_end_self_check.gd tests/mirror_hall_visual_capture.gd
```

## Completion Gate

实施完成前，逐项确认：

- [ ] `AreaRunSession` 不再声明 `GoldCorridorCatalog` 类型或 `DEALER_TARGET` 常量。
- [ ] 金线回廊的固定种子、路线、商店、铁算盘、奖励和旧四点引导全部回归通过。
- [ ] 反照牌厅的四种路线组合均能完成两房、两店、镜面夫人和刻印安装。
- [ ] 24 张牌、8 个普通房、2 位庄家和 8 种刻印通过内容审计。
- [ ] 每轮第一张实际生成镜像的合格牌最多产生一个副本，非合格牌不消耗机会。
- [ ] 原牌和副本一次撤销、一次重做，预览与提交事件完全一致。
- [ ] 三个反照提示只出现一次，重看只重置独立区段，提示前后业务快照一致。
- [ ] `1280×720` 与 `1920×1080` 下主入口、玩法、引导、失败和完成页无裁切。
- [ ] 所有 Godot 命令使用显式 `$env:TEMP` 日志，退出码和日志关键字双重检查。
- [ ] 设计规格和实施计划仍为“已暂存、未提交”。
