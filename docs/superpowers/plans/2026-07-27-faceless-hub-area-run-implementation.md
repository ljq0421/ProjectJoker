# 《六面诡局》无面中枢地区实施计划

> **For agentic workers:** 如果当前环境提供 `superpowers:executing-plans`，
> 按任务逐项执行；若未提供，则保持相同的测试先行、逐任务验证和明确提交边界。
> 所有步骤使用复选框追踪。

**Goal:** 在不实现连续三区域远征的前提下，交付可独立进入、完整通关并带有三个一次性情境提示的“无面中枢 + 无面主人”第三地区，同时把内容目录扩展到四十张牌、十二种刻印和三名庄家。

**Architecture:** 先建立资源驱动的三回合日程和结构化限制模型，让旧遭遇保持兼容；再把限制接入 `RoundController`、`CardRules` 和统一结算报告。随后补全牌面元数据、新效果原语、十六张牌与四种刻印，最后创建无面地区资源、日程条、限制面板、双目标交互和独立引导。所有玩法判断留在领域层，`.tscn` 保存稳定布局。

**Tech Stack:** Godot 4.6.1、GDScript、`.tres` Resource、`.tscn` 场景、项目内同步 `TestCase`、Godot headless 自检脚本。

## Global Constraints

- 工作目录固定为 `D:\Project\ProjectJoker\project-joker`，直接在 `master` 开发。
- 设计规格以 `docs/superpowers/specs/2026-07-27-faceless-hub-area-run-design.md` 为准。
- 不实现连续三区域 `RunDirector`、跨区域存档、混合奖励或第三刻印槽。
- 不把嵌入规则资源数量伪装成十八项独立规则台目录。
- 固定样板种子为 `20260727`，牌组为十二张，每轮手牌为四张。
- 无面入口初始情报为 `8`，预装 `engraving_backflow_bridge` 到 `d3` 的 `4` 面。
- 所有最终限制从首领开战起公开，第二回合后选择，且只作用于第三回合。
- 普通房固定限制与首领选择限制共用同一个结构化校验器。
- UI 不自行判断卡牌、限制、刻印或结算是否合法。
- 预演和正式提交共享同一解析器；情报奖励只能由正式报告兑现一次。
- 新牌不增加重投或概率触发效果。
- 稳定 UI 结构保存在 `.tscn`，脚本只绑定数据、刷新状态和处理信号。
- 主要验收分辨率为 `1920×1080`；现有 `canvas_items + keep` 行为不得回退。
- 所有 Godot headless 命令必须使用：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\<unique-log>.log" `
  -s res://tests/<test>.gd
```

- Godot 退出码非零，或日志包含 `SCRIPT ERROR|Failed to load script`，均视为失败。
- 设计与实施计划文档只暂存、不提交。
- 代码提交必须使用 `git commit --only` 和明确路径，不得带入已暂存文档。
- 不创建分支、工作树或 PR，不推送远端，不改写已有历史。
- 开始每个任务前检查 `git status --short`，保留无关更改。

## Planned File Structure

### Round schedule and restrictions

- Create `scripts/run/encounter_round_plan.gd`
- Create `scripts/run/final_restriction_definition.gd`
- Create `scripts/run/dealer_round_schedule.gd`
- Create `scripts/run/round_restriction_evaluator.gd`
- Modify `scripts/run/encounter_run_setup.gd`
- Modify `scripts/run/three_round_encounter_session.gd`
- Modify `scripts/run/round_controller.gd`
- Modify `scripts/rooms/room_definition.gd`
- Modify `scripts/areas/area_definition.gd`
- Modify `scripts/run/area_run_session.gd`
- Modify `scripts/resolution/resolution_report.gd`

### Cards and resolution

- Modify `scripts/cards/card_definition.gd`
- Modify `scripts/cards/effect_spec.gd`
- Modify `scripts/cards/card_rules.gd`
- Modify `scripts/cards/card_catalog.gd`
- Modify `scripts/cards/played_card.gd`
- Modify `scripts/run/round_state.gd`
- Modify `scripts/ui/single_encounter_session.gd`
- Modify `scripts/resolution/round_resolver.gd`
- Modify `scripts/rules/rule_evaluator.gd`
- Modify `scripts/ui/card_token.gd`
- Modify `scripts/ui/rule_lane.gd`
- Modify `scripts/validation/content_validator.gd`
- Create `resources/cards/faceless_hub/*.tres`（十六张）
- Modify existing twenty-four card resources with suit/rank/rarity metadata

### Engravings

- Modify `scripts/engravings/engraving_definition.gd`
- Modify `scripts/engravings/engraving_resolver.gd`
- Modify `scripts/engravings/engraving_catalog.gd`
- Create `resources/engravings/faceless_hub/*.tres`（四种）

### Faceless Hub content

- Create `resources/restrictions/faceless_hub/solo_verdict.tres`
- Create `resources/restrictions/faceless_hub/three_seats_present.tres`
- Create `resources/rooms/faceless_hub/*.tres`（四个房间）
- Create `resources/encounters/faceless_hub/faceless_master_schedule.tres`
- Create `resources/dealers/faceless_hub/dealer_faceless_master.tres`
- Create `resources/areas/faceless_hub.tres`
- Modify `scripts/areas/area_catalog.gd`
- Modify `scripts/dealers/dealer_catalog.gd`

### UI and onboarding

- Create `scripts/ui/round_schedule_strip.gd`
- Create `scenes/components/round_schedule_strip.tscn`
- Create `scripts/ui/final_restriction_panel.gd`
- Create `scenes/components/final_restriction_panel.tscn`
- Create `scripts/ui/faceless_hub_run_screen.gd`
- Create `scenes/run/faceless_hub_run_screen.tscn`
- Create `scripts/ui/tutorial/faceless_hub_guide_flow.gd`
- Create `scripts/ui/tutorial/faceless_hub_guide_progress_store.gd`
- Modify `scripts/ui/area_run_screen.gd`
- Modify `scenes/run/area_run_screen.tscn`
- Modify `scripts/ui/single_encounter_screen.gd`
- Modify `scenes/run/single_encounter_screen.tscn`

---

## Task 1: 建立回合计划与限制资源契约

**Files:**

- Create: `scripts/run/encounter_round_plan.gd`
- Create: `scripts/run/final_restriction_definition.gd`
- Create: `scripts/run/dealer_round_schedule.gd`
- Modify: `scripts/run/encounter_run_setup.gd`
- Modify: `scripts/rooms/room_definition.gd`
- Modify: `scripts/areas/area_definition.gd`
- Modify: `scripts/validation/content_validator.gd`
- Test: `tests/faceless_round_schedule_model_test.gd`
- Test: `tests/area_definition_test.gd`
- Test: `tests/content_validator_test.gd`

**Interfaces:**

- Produces: `EncounterRoundPlan.encounter`
- Produces: `FinalRestrictionDefinition.Category`
- Produces: `FinalRestrictionDefinition.Operation`
- Produces: `DealerRoundSchedule.round_plans`
- Produces: `EncounterRunSetup.round_schedule`
- Produces: `EncounterRunSetup.fixed_restriction`
- Produces: `RoomDefinition.restriction`
- Produces: `AreaDefinition.dealer_round_schedule`

- [ ] **Step 1: 写失败的数据契约测试**

```gdscript
func _test_schedule_requires_three_rounds_and_two_categories() -> void:
	var schedule := DealerRoundSchedule.new()
	schedule.round_plans = [_round(&"one"), _round(&"two"), _round(&"three")]
	schedule.operation_restriction = _restriction(
		&"solo",
		FinalRestrictionDefinition.Category.OPERATION,
		FinalRestrictionDefinition.Operation.MAX_REAL_CARDS,
		1
	)
	schedule.distribution_restriction = _restriction(
		&"seats",
		FinalRestrictionDefinition.Category.DISTRIBUTION,
		FinalRestrictionDefinition.Operation.REQUIRE_ALL_TABLES_OCCUPIED,
		3
	)
	assert_empty(schedule.validate(), "valid schedule should pass")
```

同时覆盖：

```text
回合计划不是三个时拒绝
回合计划 encounter 为空时拒绝
两个限制类别相同时拒绝
MAX_REAL_CARDS amount < 1 时拒绝
REQUIRE_ALL_TABLES_OCCUPIED 使用错误类别时拒绝
RoomDefinition 可选限制为空时保持旧资源兼容
AreaDefinition 没有 dealer_round_schedule 时保持旧地区兼容
```

- [ ] **Step 2: 运行并确认新类型尚不存在**

```powershell
$log = "$env:TEMP\project-joker-faceless-task01-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected faceless schedule model tests to fail" }
```

- [ ] **Step 3: 实现最小资源类型**

```gdscript
# scripts/run/encounter_round_plan.gd
class_name EncounterRoundPlan
extends Resource

@export var id: StringName
@export var display_name: String
@export var encounter: EncounterDefinition
@export_multiline var public_summary: String
```

```gdscript
# scripts/run/final_restriction_definition.gd
class_name FinalRestrictionDefinition
extends Resource

enum Category { OPERATION, DISTRIBUTION }
enum Operation { MAX_REAL_CARDS, REQUIRE_ALL_TABLES_OCCUPIED }

@export var id: StringName
@export var display_name: String
@export var category: Category
@export_multiline var rule_text: String
@export var operation: Operation
@export var amount: int
```

`DealerRoundSchedule.validate()` 返回 `Array[String]`，逐项校验 ID、中文文案、
回合数量、遭遇内容、类别和参数。`ContentValidator` 只委托这些资源自己的
校验，不复制规则常量。

- [ ] **Step 4: 把可选资源接入现有定义**

```text
EncounterRunSetup.round_schedule
EncounterRunSetup.fixed_restriction
RoomDefinition.restriction
AreaDefinition.dealer_round_schedule
```

`AreaDefinition._validate_dealer()` 规则：

- 有日程时校验日程，`dealer_encounter` 允许作为第一回合兼容引用。
- 无日程时继续要求 `dealer_encounter`。
- 金线和反照资源无需修改即可继续通过。

- [ ] **Step 5: 运行模型、地区和全量同步测试**

```powershell
$log = "$env:TEMP\project-joker-faceless-task01-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 6: 只提交本任务代码**

```powershell
git add -- `
  scripts/run/encounter_round_plan.gd `
  scripts/run/final_restriction_definition.gd `
  scripts/run/dealer_round_schedule.gd `
  scripts/run/encounter_run_setup.gd `
  scripts/rooms/room_definition.gd `
  scripts/areas/area_definition.gd `
  scripts/validation/content_validator.gd `
  tests/faceless_round_schedule_model_test.gd `
  tests/area_definition_test.gd `
  tests/content_validator_test.gd
git commit --only -m "feat: add encounter round schedule contracts" -- `
  scripts/run/encounter_round_plan.gd `
  scripts/run/final_restriction_definition.gd `
  scripts/run/dealer_round_schedule.gd `
  scripts/run/encounter_run_setup.gd `
  scripts/rooms/room_definition.gd `
  scripts/areas/area_definition.gd `
  scripts/validation/content_validator.gd `
  tests/faceless_round_schedule_model_test.gd `
  tests/area_definition_test.gd `
  tests/content_validator_test.gd
```

---

## Task 2: 扩展三回合会话状态机

**Files:**

- Modify: `scripts/run/three_round_encounter_session.gd`
- Modify: `scripts/run/encounter_run_setup.gd`
- Modify: `scripts/run/area_run_session.gd`
- Test: `tests/faceless_round_schedule_session_test.gd`
- Test: `tests/three_round_encounter_session_test.gd`
- Test: `tests/parameterized_three_round_session_test.gd`
- Test: `tests/mirror_hall_area_run_test.gd`
- Test: `tests/gold_corridor_area_run_test.gd`

**Interfaces:**

- Produces: `ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION`
- Produces: `current_round_plan()`
- Produces: `public_restriction_options()`
- Produces: `choose_final_restriction(restriction_id)`
- Produces: `active_restriction()`
- Produces: `AreaRunSession.choose_dealer_restriction(restriction_id)`

- [ ] **Step 1: 写失败的会话状态测试**

固定三回合日程，逐轮提交有效报告并断言：

```text
第一回合使用 plan_1
第一回合后仍进入 ROUND_SUMMARY
第二回合使用 plan_2
第二回合后进入 AWAITING_RESTRICTION
等待期间 advance_round 被拒绝
未知限制 ID 被拒绝且状态不变
确认限制后原子创建第三回合并进入 PLAYING
第三回合使用 plan_3
第三回合 active_restriction 为已选项
选择确认后不能更换
```

再构造无日程 setup，确认旧三回合仍连续使用 `setup.encounter`。

- [ ] **Step 2: 运行并确认仍只有旧状态**

```powershell
$log = "$env:TEMP\project-joker-faceless-task02-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected round schedule session tests to fail" }
```

- [ ] **Step 3: 修改 `_begin_round()` 按计划取遭遇**

```gdscript
func _encounter_for_round(round_number: int) -> EncounterDefinition:
	if setup.round_schedule == null:
		return setup.encounter
	return setup.round_schedule.round_plans[round_number - 1].encounter
```

`_begin_round()` 只在完成所有牌、骰和遭遇校验后替换 `current_session`。
失败时不得消耗额外 RNG 或留下半创建状态。

- [ ] **Step 4: 添加等待选择边界**

第二回合报告接受成功后：

```gdscript
if setup.round_schedule != null and current_round == 2:
	status = Status.AWAITING_RESTRICTION
```

`choose_final_restriction()`：

1. 验证当前状态。
2. 验证 ID 属于公开两个候选。
3. 暂存旧回合、状态和选择。
4. 写入选择并创建第三回合。
5. 创建失败时完整恢复。
6. 成功后进入 `PLAYING`。

- [ ] **Step 5: 在地区会话增加最薄包装**

`AreaRunSession.choose_dealer_restriction()` 只允许 `Phase.DEALER`，
委托当前三回合会话，不重复规则判断。

- [ ] **Step 6: 运行新状态机和两个旧地区回归**

```powershell
$log = "$env:TEMP\project-joker-faceless-task02-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 7: 提交会话状态机**

```powershell
git add -- `
  scripts/run/three_round_encounter_session.gd `
  scripts/run/encounter_run_setup.gd `
  scripts/run/area_run_session.gd `
  tests/faceless_round_schedule_session_test.gd `
  tests/three_round_encounter_session_test.gd `
  tests/parameterized_three_round_session_test.gd `
  tests/mirror_hall_area_run_test.gd `
  tests/gold_corridor_area_run_test.gd
git commit --only -m "feat: schedule three encounter rounds" -- `
  scripts/run/three_round_encounter_session.gd `
  scripts/run/encounter_run_setup.gd `
  scripts/run/area_run_session.gd `
  tests/faceless_round_schedule_session_test.gd `
  tests/three_round_encounter_session_test.gd `
  tests/parameterized_three_round_session_test.gd `
  tests/mirror_hall_area_run_test.gd `
  tests/gold_corridor_area_run_test.gd
```

---

## Task 3: 把限制接入操作、预演与提交

**Files:**

- Create: `scripts/run/round_restriction_evaluator.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/cards/card_rules.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Modify: `scripts/ui/single_encounter_session.gd`
- Modify: `scripts/run/three_round_encounter_session.gd`
- Test: `tests/round_restriction_evaluator_test.gd`
- Test: `tests/card_rules_test.gd`
- Test: `tests/round_controller_test.gd`

**Interfaces:**

- Produces: `validate_card_play(state, restriction) -> OperationResult`
- Produces: `evaluate_commit(state, encounter, restriction) -> OperationResult`
- Produces: `coverage_copy(state, encounter) -> String`
- Produces: `ResolutionReport.restriction_satisfied`
- Produces: `ResolutionReport.restriction_reason`

- [ ] **Step 1: 写操作限制失败测试**

```text
上限一张时第一张真实牌成功
第二张真实牌失败且状态对象不变
镜像副本不计入上限
撤销真实牌后可以再次出牌
无固定限制时仍使用默认两张上限
```

- [ ] **Step 2: 写分配限制失败测试**

```text
左中右都有骰时满足
缺左时原因包含“左侧规则台”
缺中时原因包含“中间规则台”
缺右时原因包含“右侧规则台”
preview 返回 restriction_satisfied=false 但仍可继续调整
commit 在不满足时拒绝，controller.committed 仍为 false
```

- [ ] **Step 3: 运行并确认限制尚未接入**

```powershell
$log = "$env:TEMP\project-joker-faceless-task03-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected restriction evaluator tests to fail" }
```

- [ ] **Step 4: 实现纯限制校验器**

校验器只读取 `RoundState`、`EncounterDefinition` 和限制资源。
它不读取场景，不修改状态，也不播放反馈。

`MAX_REAL_CARDS` 统计：

```gdscript
var count := 0
for card in state.played_cards:
	if card is PlayedCard and not card.is_mirror_copy:
		count += 1
```

`REQUIRE_ALL_TABLES_OCCUPIED` 按遭遇规则 ID 检查 `state.assignments`，
错误按左、中、右显示缺失位置。

- [ ] **Step 5: 在 `RoundController` 中统一接入**

- 构造器新增可选 `active_restriction`。
- `play_card()` 先做限制预检，再调用 `CardRules`。
- `preview()` 总是解析当前状态，并附加限制满足情况。
- `commit()` 先做限制提交校验，再调用统一解析器。
- 限制失败不设置 `committed`，不缓存正式报告。

`CardRules.MAX_CARDS_PER_ROUND` 继续作为默认上限；
限制校验器只允许收紧，不允许把默认上限扩大到三张以上。

- [ ] **Step 6: 让普通房固定限制与首领选择限制共用入口**

`ThreeRoundEncounterSession._begin_round()` 选择：

```text
第三回合已选限制
否则 setup.fixed_restriction
否则 null
```

并传入新 `SingleEncounterSession` / `RoundController`。

- [ ] **Step 7: 运行限制、控制器和全量测试**

```powershell
$log = "$env:TEMP\project-joker-faceless-task03-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 8: 提交限制核心**

```powershell
git add -- `
  scripts/run/round_restriction_evaluator.gd `
  scripts/run/round_controller.gd `
  scripts/cards/card_rules.gd `
  scripts/resolution/resolution_report.gd `
  scripts/ui/single_encounter_session.gd `
  scripts/run/three_round_encounter_session.gd `
  tests/round_restriction_evaluator_test.gd `
  tests/card_rules_test.gd `
  tests/round_controller_test.gd
git commit --only -m "feat: enforce public round restrictions" -- `
  scripts/run/round_restriction_evaluator.gd `
  scripts/run/round_controller.gd `
  scripts/cards/card_rules.gd `
  scripts/resolution/resolution_report.gd `
  scripts/ui/single_encounter_session.gd `
  scripts/run/three_round_encounter_session.gd `
  tests/round_restriction_evaluator_test.gd `
  tests/card_rules_test.gd `
  tests/round_controller_test.gd
```

---

## Task 4: 补齐花色、牌面与稀有度元数据

**Files:**

- Modify: `scripts/cards/card_definition.gd`
- Modify: `scripts/cards/card_catalog.gd`
- Modify: `scripts/ui/card_token.gd`
- Modify: `scripts/validation/content_validator.gd`
- Modify: all 24 existing `.tres` card resources
- Test: `tests/card_suit_catalog_test.gd`
- Test: `tests/stage4_card_catalog_test.gd`
- Test: `tests/mirror_hall_content_catalog_test.gd`

**Interfaces:**

- Produces: `CardDefinition.Suit`
- Produces: `CardDefinition.Rarity`
- Produces: `CardDefinition.suit_copy()`
- Produces: `CardDefinition.rank_label`
- Produces: `CardDefinition.rarity`

- [ ] **Step 1: 写元数据审计失败测试**

在新牌加入前，测试只要求现有二十四张：

```text
每张有有效 suit
每张 rank_label 非空
每张 rarity 有效
四种花色各六张
卡牌 UI 文案同时包含花色符号或文字、牌面和目标类型
```

- [ ] **Step 2: 运行并确认当前模型缺少字段**

```powershell
$log = "$env:TEMP\project-joker-faceless-task04-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected card metadata tests to fail" }
```

- [ ] **Step 3: 增加字段并保持旧逻辑兼容**

```gdscript
enum Suit { CLUBS, HEARTS, DIAMONDS, SPADES }
enum Rarity { COMMON, UNCOMMON, RARE }

@export var suit: Suit
@export var rank_label: String
@export var rarity: Rarity
```

花色图标复制：

```text
梅花 ♣
红桃 ♥
方片 ♦
黑桃 ♠
```

UI 同时显示中文花色或可访问文本，不只显示红黑颜色。

- [ ] **Step 4: 给现有二十四张牌分组六张**

```text
梅花：
starter_nudge_down_1
starter_nudge_up_1
starter_nudge_down_2
starter_nudge_up_2
shop_long_push
shop_deep_drop

红桃（稳定、冗余与弱化补偿）：
starter_stable_repeat
starter_amplified_repeat
mirror_soft_echo
mirror_hinged_bridge
mirror_deep_echo
mirror_silver_bridge

方片（系数与资源效率）：
starter_map_1
starter_map_2
shop_precision_map
shop_amplified_chain
mirror_folded_map
mirror_double_exposure

黑桃（重复、顺序与传递）：
starter_repeat_1
starter_repeat_2
starter_reverse
starter_link
shop_triple_repeat
shop_reverse_backup
```

牌面按实际强度填写，稀有度不改变商店价格或现有出牌行为。

- [ ] **Step 5: 运行目录、UI 合同与全量测试**

```powershell
$log = "$env:TEMP\project-joker-faceless-task04-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 6: 审核本任务实际路径后提交**

提交前运行：

```powershell
git diff --name-only
git diff --check
```

仅把 `card_definition.gd`、`card_catalog.gd`、`card_token.gd`、
`content_validator.gd`、二十四张明确卡牌资源和对应测试列入
`git add --` 与 `git commit --only`，不得使用会吸入无关文件的
仓库根目录路径。新增测试必须先显式 `git add --`。

- [ ] **Step 7: 用明确资源列表提交牌面元数据**

```powershell
$legacyCardResources = @(
  'resources/cards/stage4/starter_nudge_down_1.tres',
  'resources/cards/stage4/starter_nudge_up_1.tres',
  'resources/cards/stage4/starter_nudge_down_2.tres',
  'resources/cards/stage4/starter_nudge_up_2.tres',
  'resources/cards/stage4/starter_map_1.tres',
  'resources/cards/stage4/starter_map_2.tres',
  'resources/cards/stage4/starter_repeat_1.tres',
  'resources/cards/stage4/starter_repeat_2.tres',
  'resources/cards/stage4/starter_stable_repeat.tres',
  'resources/cards/stage4/starter_amplified_repeat.tres',
  'resources/cards/stage4/starter_reverse.tres',
  'resources/cards/stage4/starter_link.tres',
  'resources/cards/stage4/shop_precision_map.tres',
  'resources/cards/stage4/shop_triple_repeat.tres',
  'resources/cards/stage4/shop_long_push.tres',
  'resources/cards/stage6/shop_deep_drop.tres',
  'resources/cards/stage6/shop_amplified_chain.tres',
  'resources/cards/stage6/shop_reverse_backup.tres',
  'resources/cards/mirror_hall/mirror_folded_map.tres',
  'resources/cards/mirror_hall/mirror_soft_echo.tres',
  'resources/cards/mirror_hall/mirror_hinged_bridge.tres',
  'resources/cards/mirror_hall/mirror_double_exposure.tres',
  'resources/cards/mirror_hall/mirror_deep_echo.tres',
  'resources/cards/mirror_hall/mirror_silver_bridge.tres'
)
$metadataCode = @(
  'scripts/cards/card_definition.gd',
  'scripts/cards/card_catalog.gd',
  'scripts/ui/card_token.gd',
  'scripts/validation/content_validator.gd',
  'tests/card_suit_catalog_test.gd',
  'tests/stage4_card_catalog_test.gd',
  'tests/mirror_hall_content_catalog_test.gd'
)
git add -- $metadataCode $legacyCardResources
git commit --only -m "feat: classify technique card suits" -- `
  $metadataCode $legacyCardResources
```

---

## Task 5: 实现双骰、翻面、锁定与校准回收

**Files:**

- Modify: `scripts/cards/card_definition.gd`
- Modify: `scripts/cards/effect_spec.gd`
- Modify: `scripts/cards/card_rules.gd`
- Modify: `scripts/cards/played_card.gd`
- Modify: `scripts/run/round_state.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/resolution/round_resolver.gd`
- Modify: `scripts/engravings/engraving_resolver.gd`
- Modify: `scripts/validation/content_validator.gd`
- Test: `tests/faceless_die_card_effects_test.gd`
- Test: `tests/round_actions_test.gd`
- Test: `tests/resolution_test.gd`

**Interfaces:**

- Adds: `CardDefinition.TargetType.DICE_PAIR`
- Adds: `EffectSpec.Operation.SWAP_DICE`
- Adds: `EffectSpec.Operation.COPY_DIE`
- Adds: `EffectSpec.Operation.FLIP_DIE`
- Adds: `EffectSpec.Operation.LOCK_DIE_WITH_BONUS`
- Adds: `EffectSpec.Operation.REFUND_CALIBRATION`
- Produces: `RoundState.locked_die_ids()`

- [ ] **Step 1: 写效果顺序和目标失败测试**

覆盖：

```text
换位需要两个不同且存在的骰子
复刻保留来源值并覆盖目标有效值
翻面 1→6、2→5、3→4、4→3、5→2、6→1
效果按真实出牌顺序执行
定格后校准被拒绝
定格后 ADJUST_DIE、COPY_DIE 目标修改被拒绝
定格牌撤销后锁定解除
定格骰所在规则台通过才获得固定奖励
校准回收只在已使用至少一点时合法
校准点最多恢复到二
```

- [ ] **Step 2: 运行并确认新操作未知**

```powershell
$log = "$env:TEMP\project-joker-faceless-task05-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected faceless die effect tests to fail" }
```

- [ ] **Step 3: 扩展有限效果原语**

`DICE_PAIR` 使用：

- `primary_target`：来源或第一颗骰。
- `secondary_target`：目标或第二颗骰。

`CardRules` 先校验目标数量、目标不同、刻印锁定与现有卡牌锁定，
再把牌加入候选状态。`REFUND_CALIBRATION` 在候选 `RoundState`
中立即恢复一点，因此同轮后续校准可见；撤销依靠历史快照恢复。

- [ ] **Step 4: 在解析器中按牌序计算有效骰值**

保持 `DieState.value` 为操作前状态；手法牌效果继续在
`RoundResolver` 的候选 `die_values` 上按顺序计算。

定格状态由当前 `played_cards` 推导，不写进持久骰子配置。
锁定奖励作为可见 `ResolutionEvent` 写入报告。

- [ ] **Step 5: 运行效果、操作保护和全量测试**

```powershell
$log = "$env:TEMP\project-joker-faceless-task05-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 6: 提交骰值效果核心**

```powershell
git add -- `
  scripts/cards/card_definition.gd `
  scripts/cards/effect_spec.gd `
  scripts/cards/card_rules.gd `
  scripts/cards/played_card.gd `
  scripts/run/round_state.gd `
  scripts/run/round_controller.gd `
  scripts/resolution/round_resolver.gd `
  scripts/engravings/engraving_resolver.gd `
  scripts/validation/content_validator.gd `
  tests/faceless_die_card_effects_test.gd `
  tests/round_actions_test.gd `
  tests/resolution_test.gd
git commit --only -m "feat: add deterministic faceless die effects" -- `
  scripts/cards/card_definition.gd `
  scripts/cards/effect_spec.gd `
  scripts/cards/card_rules.gd `
  scripts/cards/played_card.gd `
  scripts/run/round_state.gd `
  scripts/run/round_controller.gd `
  scripts/resolution/round_resolver.gd `
  scripts/engravings/engraving_resolver.gd `
  scripts/validation/content_validator.gd `
  tests/faceless_die_card_effects_test.gd `
  tests/round_actions_test.gd `
  tests/resolution_test.gd
```

---

## Task 6: 实现条件修改与情报奖励

**Files:**

- Modify: `scripts/cards/effect_spec.gd`
- Modify: `scripts/cards/card_rules.gd`
- Modify: `scripts/resolution/round_resolver.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Modify: `scripts/rules/rule_evaluator.gd`
- Modify: `scripts/run/three_round_encounter_session.gd`
- Modify: `scripts/run/area_run_session.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/ui/single_encounter_session.gd`
- Modify: `scripts/ui/rule_lane.gd`
- Modify: `scripts/validation/content_validator.gd`
- Test: `tests/faceless_condition_card_effects_test.gd`
- Test: `tests/faceless_intel_card_effects_test.gd`
- Test: `tests/rule_evaluator_test.gd`
- Test: `tests/resolution_test.gd`

**Interfaces:**

- Adds: `EffectSpec.Operation.MODIFY_CONDITION`
- Adds: `EffectSpec.Operation.GRANT_INTEL_ON_CONDITION`
- Adds: `EffectSpec.ConditionModifier`
- Adds: `EffectSpec.IntelCondition`
- Produces: `ResolutionReport.intel_delta`
- Produces: `ThreeRoundEncounterSession.earned_intel_tickets`

- [ ] **Step 1: 写四种条件修改失败测试**

```text
EXACT_TOLERANCE 接受目标值 ±1，不接受 ±2
ALLOW_ONE_ODD 只允许一颗奇数
ALLOW_ONE_GAP 只允许连续序列中一个差二缺口
INCREASE_SLOT_COUNT 增加一个所需骰位
条件修改只影响指定规则台和当前轮
不匹配的条件牌目标被拒绝
加严后总骰位超过六或单台超过六时被拒绝
```

- [ ] **Step 2: 写四种情报触发失败测试**

```text
TARGET_TABLE_PASSED
ALL_DICE_ASSIGNED
ALL_TABLES_OCCUPIED
ALL_TABLES_PASSED
```

每种覆盖：

- 预演显示 `intel_delta`。
- 条件不满足时为零并生成可见事件。
- 正式报告每次只接受一次。
- 撤销、失败提交和重复点击不增加情报。

- [ ] **Step 3: 运行并确认当前评估器不支持修饰**

```powershell
$log = "$env:TEMP\project-joker-faceless-task06-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected condition and intel tests to fail" }
```

- [ ] **Step 4: 扩展规则评估器**

`RoundResolver` 按规则台收集 `ConditionModifier`，并把有效骰位数和
条件修饰传给 `RuleEvaluator`。`RuleDefinition` 资源本身不得被修改，
避免一轮牌效果污染后续回合。

`RuleLane.bind_lane()` 接收有效骰位数和条件摘要，
显示原条件到修改条件的可见变化。

`RoundController.effective_slot_count(table_id)` 和
`SingleEncounterSession` 的分配入口使用同一有效骰位数，
不能继续把原始 `rule.slot_count` 传给 `assign_die()`。

- [ ] **Step 5: 扩展报告与情报兑现**

`ResolutionReport.intel_delta` 默认 `0`。
所有规则台结果已知后统一判断情报触发，生成带来源牌 ID 的事件。

`ThreeRoundEncounterSession.accept_committed_report()`：

- 报告身份仍必须等于当前正式报告。
- 每轮只追加一次。
- 累加 `earned_intel_tickets`。
- 遭遇成功时：

```text
intel_tickets = setup.success_intel_reward + earned_intel_tickets
```

`AreaRunSession` 只在普通房成功完成后把总情报加入地区钱包。

- [ ] **Step 6: 运行规则、情报和旧地区回归**

```powershell
$log = "$env:TEMP\project-joker-faceless-task06-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 7: 提交条件与情报效果**

```powershell
git add -- `
  scripts/cards/effect_spec.gd `
  scripts/cards/card_rules.gd `
  scripts/resolution/round_resolver.gd `
  scripts/resolution/resolution_report.gd `
  scripts/rules/rule_evaluator.gd `
  scripts/run/three_round_encounter_session.gd `
  scripts/run/area_run_session.gd `
  scripts/run/round_controller.gd `
  scripts/ui/single_encounter_session.gd `
  scripts/ui/rule_lane.gd `
  scripts/validation/content_validator.gd `
  tests/faceless_condition_card_effects_test.gd `
  tests/faceless_intel_card_effects_test.gd `
  tests/rule_evaluator_test.gd `
  tests/resolution_test.gd
git commit --only -m "feat: resolve condition and intel card effects" -- `
  scripts/cards/effect_spec.gd `
  scripts/cards/card_rules.gd `
  scripts/resolution/round_resolver.gd `
  scripts/resolution/resolution_report.gd `
  scripts/rules/rule_evaluator.gd `
  scripts/run/three_round_encounter_session.gd `
  scripts/run/area_run_session.gd `
  scripts/run/round_controller.gd `
  scripts/ui/single_encounter_session.gd `
  scripts/ui/rule_lane.gd `
  scripts/validation/content_validator.gd `
  tests/faceless_condition_card_effects_test.gd `
  tests/faceless_intel_card_effects_test.gd `
  tests/rule_evaluator_test.gd `
  tests/resolution_test.gd
```

---

## Task 7: 创建十六张牌并完成四十张目录审计

**Files:**

- Create: `resources/cards/faceless_hub/*.tres`
- Modify: `scripts/cards/card_catalog.gd`
- Modify: `scripts/validation/content_validator.gd`
- Test: `tests/faceless_card_catalog_test.gd`
- Test: `tests/card_suit_catalog_test.gd`

**Content IDs:**

```text
faceless_swap_values
faceless_copy_value
faceless_flip_value
faceless_lock_bonus
faceless_refund_calibration
faceless_exact_tolerance
faceless_even_tolerance
faceless_sequence_tolerance
faceless_table_receipt
faceless_full_allocation
faceless_three_seats
faceless_complete_dossier
faceless_strict_mapping
faceless_reverse_replay
faceless_compressed_repeat
faceless_closed_circuit
```

- [ ] **Step 1: 写目录失败测试**

要求：

```text
CardCatalog 总数为 40
faceless_hub_card_ids 总数为 16
每种花色总数为 10
所有 ID 唯一
所有牌面、稀有度、规则文本、标签和效果有效
每张新牌至少有一个正向效果测试
新牌与 starter/shop/mirror ID 不重叠
```

- [ ] **Step 2: 运行并确认目录仍为二十四张**

```powershell
$log = "$env:TEMP\project-joker-faceless-task07-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected forty-card catalog test to fail" }
```

- [ ] **Step 3: 创建资源**

每种花色新增四张。资源必须明确填写：

- `id`
- `display_name`
- `rule_text`
- `tags`
- `target_type`
- `suit`
- `rank_label`
- `rarity`
- `effects`
- 条件或触发参数

镜像效果只在设计明确允许的桌间牌上设置；
非桌间牌不得为方便展示伪造 `mirror_effects`。

- [ ] **Step 4: 扩展目录与验证**

`CardCatalog` 增加 `FACELESS_HUB_PATHS`、
`faceless_hub_card_ids()`，并把总数约束更新为：

```text
starter 12
legacy shop 6
mirror hall 6
faceless hub 16
all 40
```

- [ ] **Step 5: 运行目录与全量测试**

```powershell
$log = "$env:TEMP\project-joker-faceless-task07-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 6: 只提交十六张牌和目录**

```powershell
git add -- `
  scripts/cards/card_catalog.gd `
  scripts/validation/content_validator.gd `
  resources/cards/faceless_hub `
  tests/faceless_card_catalog_test.gd `
  tests/card_suit_catalog_test.gd
git commit --only -m "feat: add sixteen faceless technique cards" -- `
  scripts/cards/card_catalog.gd `
  scripts/validation/content_validator.gd `
  resources/cards/faceless_hub `
  tests/faceless_card_catalog_test.gd `
  tests/card_suit_catalog_test.gd
```

提交前确认 `resources/cards/faceless_hub` 是本任务新目录，
不存在并发用户文件。

---

## Task 8: 实现四种无面刻印

**Files:**

- Modify: `scripts/engravings/engraving_definition.gd`
- Modify: `scripts/engravings/engraving_resolver.gd`
- Modify: `scripts/engravings/engraving_catalog.gd`
- Modify: `scripts/rules/rule_evaluator.gd`
- Modify: `scripts/validation/content_validator.gd`
- Create: `resources/engravings/faceless_hub/engraving_low_murmur.tres`
- Create: `resources/engravings/faceless_hub/engraving_terminal_anchor.tres`
- Create: `resources/engravings/faceless_hub/engraving_two_way_bridge.tres`
- Create: `resources/engravings/faceless_hub/engraving_sequence_prism.tres`
- Test: `tests/faceless_engraving_resolution_test.gd`
- Test: `tests/engraving_installation_service_test.gd`

- [ ] **Step 1: 写四种刻印失败测试**

覆盖：

```text
低鸣选择同台相邻骰中的较低有效值
低鸣没有相邻骰时生成未触发事件
终点锚只在最后结算有效台触发 +5
终点锚激活时阻止点数修改
双向桥向前后各传递 floor(value / 2)
边界只有一侧时只向存在的一侧传递
序列棱镜允许高一或低一关系值
序列棱镜不修改规则台计分所用真实点数
刻印面未朝上或骰子未分配时不触发
```

- [ ] **Step 2: 运行并确认新枚举未知**

```powershell
$log = "$env:TEMP\project-joker-faceless-task08-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected faceless engraving tests to fail" }
```

- [ ] **Step 3: 增加显式枚举并实现**

```text
ECHO_LOWER_ADJACENT
ANCHOR_LAST_TABLE
BRIDGE_BIDIRECTIONAL
PRISM_SEQUENCE
```

不得通过 ID、显示名或标签分支。
双向桥返回两个 `EngravingOutcome`，由现有 pending bridge 机制分别处理。
序列棱镜向 `RuleEvaluator` 提供关系覆盖，不改变 `die_values`。

- [ ] **Step 4: 扩展目录到十二种**

`EngravingCatalog` 增加 `FACELESS_HUB_PATHS` 和
`faceless_hub_ids()`，总数校验改为十二。

- [ ] **Step 5: 运行刻印、目录和全量测试**

```powershell
$log = "$env:TEMP\project-joker-faceless-task08-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 6: 提交无面刻印**

```powershell
git add -- `
  scripts/engravings/engraving_definition.gd `
  scripts/engravings/engraving_resolver.gd `
  scripts/engravings/engraving_catalog.gd `
  scripts/rules/rule_evaluator.gd `
  scripts/validation/content_validator.gd `
  resources/engravings/faceless_hub `
  tests/faceless_engraving_resolution_test.gd `
  tests/engraving_installation_service_test.gd
git commit --only -m "feat: add faceless die engravings" -- `
  scripts/engravings/engraving_definition.gd `
  scripts/engravings/engraving_resolver.gd `
  scripts/engravings/engraving_catalog.gd `
  scripts/rules/rule_evaluator.gd `
  scripts/validation/content_validator.gd `
  resources/engravings/faceless_hub `
  tests/faceless_engraving_resolution_test.gd `
  tests/engraving_installation_service_test.gd
```

---

## Task 9: 创建无面地区、房间、庄家和日程资源

**Files:**

- Create: `resources/restrictions/faceless_hub/solo_verdict.tres`
- Create: `resources/restrictions/faceless_hub/three_seats_present.tres`
- Create: `resources/rooms/faceless_hub/crossed_archive.tres`
- Create: `resources/rooms/faceless_hub/reverse_index.tres`
- Create: `resources/rooms/faceless_hub/single_hand_agenda.tres`
- Create: `resources/rooms/faceless_hub/three_seat_protocol.tres`
- Create: `resources/encounters/faceless_hub/faceless_master_schedule.tres`
- Create: `resources/dealers/faceless_hub/dealer_faceless_master.tres`
- Create: `resources/areas/faceless_hub.tres`
- Modify: `scripts/areas/area_catalog.gd`
- Modify: `scripts/dealers/dealer_catalog.gd`
- Modify: `scripts/run/area_run_session.gd`
- Test: `tests/faceless_hub_content_catalog_test.gd`
- Test: `tests/faceless_hub_area_run_test.gd`

- [ ] **Step 1: 写内容目录和完整阶段失败测试**

断言：

```text
AreaCatalog 有三个地区
DealerCatalog 有三名庄家
无面地区有四个不同房间
两组选路各两个且无重复
固定牌组为设计规格中的十二张
初始情报为 8
预装逆流桥在 d3 的 4 面
商店池不与固定牌组重复到无法提供三项
庄家日程为正面、反面、无面
两个限制类别和参数正确
奖励池为四种无面刻印
```

阶段测试覆盖两条路线组合、两次商店、等待选择、第三回合、
奖励安装和完成快照。

- [ ] **Step 2: 运行并确认无面资源不存在**

```powershell
$log = "$env:TEMP\project-joker-faceless-task09-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected faceless area content tests to fail" }
```

- [ ] **Step 3: 创建两个复用限制资源**

两个资源同时用于：

- 第二组选路中的固定限制。
- 无面主人第二回合后的候选限制。

因此房间与首领不会维护两套同义参数。

- [ ] **Step 4: 创建四房与庄家日程**

首轮目标值先由固定可玩性夹具生成候选，再写入资源。
禁止为了让测试通过直接把目标设为明显过低值。

庄家：

```text
Round 1: LEFT_TO_RIGHT, mirror off
Round 2: RIGHT_TO_LEFT, mirror off
Round 3: LEFT_TO_RIGHT, mirror first eligible gap card
```

- [ ] **Step 5: 创建地区资源与目录**

`AreaCatalog` 增加：

```gdscript
const FACELESS_HUB_PATH := "res://resources/areas/faceless_hub.tres"
func faceless_hub() -> AreaDefinition
```

`DealerCatalog` 增加无面主人和 `all_dealers()` 第三项。
`AreaRunSession._create_normal_room()` 传入 `room.restriction`；
`_create_dealer()` 传入 `area_definition.dealer_round_schedule`。

- [ ] **Step 6: 运行内容、阶段和旧地区回归**

```powershell
$log = "$env:TEMP\project-joker-faceless-task09-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 7: 提交地区内容**

```powershell
git add -- `
  resources/restrictions/faceless_hub `
  resources/rooms/faceless_hub `
  resources/encounters/faceless_hub `
  resources/dealers/faceless_hub `
  resources/areas/faceless_hub.tres `
  scripts/areas/area_catalog.gd `
  scripts/dealers/dealer_catalog.gd `
  scripts/run/area_run_session.gd `
  tests/faceless_hub_content_catalog_test.gd `
  tests/faceless_hub_area_run_test.gd
git commit --only -m "feat: add the faceless hub area" -- `
  resources/restrictions/faceless_hub `
  resources/rooms/faceless_hub `
  resources/encounters/faceless_hub `
  resources/dealers/faceless_hub `
  resources/areas/faceless_hub.tres `
  scripts/areas/area_catalog.gd `
  scripts/dealers/dealer_catalog.gd `
  scripts/run/area_run_session.gd `
  tests/faceless_hub_content_catalog_test.gd `
  tests/faceless_hub_area_run_test.gd
```

---

## Task 10: 接入日程条、限制面板与双目标交互

**Files:**

- Create: `scripts/ui/round_schedule_strip.gd`
- Create: `scenes/components/round_schedule_strip.tscn`
- Create: `scripts/ui/final_restriction_panel.gd`
- Create: `scenes/components/final_restriction_panel.tscn`
- Create: `scripts/ui/faceless_hub_run_screen.gd`
- Create: `scenes/run/faceless_hub_run_screen.tscn`
- Modify: `scripts/ui/area_run_screen.gd`
- Modify: `scenes/run/area_run_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`
- Modify: `scripts/ui/card_token.gd`
- Modify: `scripts/ui/rule_lane.gd`
- Test: `tests/faceless_hub_ui_contract_test.gd`
- Test: `tests/faceless_restriction_input_self_check.gd`
- Test: `tests/faceless_dual_target_input_self_check.gd`

- [ ] **Step 1: 写 UI 合同失败测试**

要求稳定节点：

```text
%RoundScheduleStrip
%RoundOneCard
%RoundTwoCard
%RoundThreeCard
%FinalRestrictionPanel
%OperationRestrictionButton
%DistributionRestrictionButton
%RestrictionConfirmButton
%ActiveRestrictionBadge
```

并断言日程条和面板存在于 `.tscn`，不是脚本运行时创建。

- [ ] **Step 2: 写真实输入失败测试**

覆盖：

```text
首领开始显示三张公开日程
完成第二回合后限制面板自动打开
默认未选且确认按钮禁用
点击两个候选可以切换
面板打开时骰子、卡牌和确认不响应
确认后直接绑定第三回合
第三回合显示已选限制
独手裁决第二张真实牌显示具体原因
三席到场缺台时显示具体位置
```

双目标牌覆盖：

```text
点击牌后显示“选择来源”
选择来源后显示“选择目标”
不能选择同一骰两次
只高亮合法骰子
完成第二目标后一次性提交牌操作
Esc 或再次点牌取消未完成选择
```

- [ ] **Step 3: 运行并确认组件不存在**

```powershell
$log = "$env:TEMP\project-joker-faceless-task10-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected faceless UI contract tests to fail" }
```

- [ ] **Step 4: 构建场景组件**

`round_schedule_strip.tscn`：

- 三个固定卡片。
- 方向文字与箭头。
- 镜像状态文字。
- 当前、已完成、待选择和已限制状态。

`final_restriction_panel.tscn`：

- 全屏模态遮罩。
- 两个并列候选。
- “仅影响第三回合”说明。
- 无默认选择。
- 具体确认按钮与错误标签。

- [ ] **Step 5: 在共享地区页面只增加通用钩子**

`AreaRunScreen` 增加：

```text
_after_round_report_accepted()
_show_restriction_choice_if_needed()
_after_restriction_confirmed()
```

无面页面绑定组件；金线与反照页面保持无组件兼容。
限制确认调用 `AreaRunSession.choose_dealer_restriction()`，
成功后调用现有 `bind_current_encounter()`。

- [ ] **Step 6: 扩展选牌交互状态**

不要在 `SingleEncounterScreen` 增加无面牌 ID 判断。
根据 `CardDefinition.TargetType.DICE_PAIR` 和效果参数驱动两阶段选择。

`RuleLane` 显示领域层提供的有效骰位和条件摘要，
不得自行重算条件修改。

- [ ] **Step 7: 运行 UI、输入和旧页面回归**

```powershell
$log = "$env:TEMP\project-joker-faceless-task10-green.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 8: 提交 UI 与输入**

```powershell
git add -- `
  scripts/ui/round_schedule_strip.gd `
  scenes/components/round_schedule_strip.tscn `
  scripts/ui/final_restriction_panel.gd `
  scenes/components/final_restriction_panel.tscn `
  scripts/ui/faceless_hub_run_screen.gd `
  scenes/run/faceless_hub_run_screen.tscn `
  scripts/ui/area_run_screen.gd `
  scenes/run/area_run_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/card_token.gd `
  scripts/ui/rule_lane.gd `
  tests/faceless_hub_ui_contract_test.gd `
  tests/faceless_restriction_input_self_check.gd `
  tests/faceless_dual_target_input_self_check.gd
git commit --only -m "feat: add faceless schedule and restriction UI" -- `
  scripts/ui/round_schedule_strip.gd `
  scenes/components/round_schedule_strip.tscn `
  scripts/ui/final_restriction_panel.gd `
  scenes/components/final_restriction_panel.tscn `
  scripts/ui/faceless_hub_run_screen.gd `
  scenes/run/faceless_hub_run_screen.tscn `
  scripts/ui/area_run_screen.gd `
  scenes/run/area_run_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  scripts/ui/card_token.gd `
  scripts/ui/rule_lane.gd `
  tests/faceless_hub_ui_contract_test.gd `
  tests/faceless_restriction_input_self_check.gd `
  tests/faceless_dual_target_input_self_check.gd
```

---

## Task 11: 增加主入口、三个提示与最终验收

**Files:**

- Create: `scripts/ui/tutorial/faceless_hub_guide_flow.gd`
- Create: `scripts/ui/tutorial/faceless_hub_guide_progress_store.gd`
- Modify: `scripts/ui/faceless_hub_run_screen.gd`
- Modify: `scenes/run/faceless_hub_run_screen.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scenes/run/single_encounter_screen.tscn`
- Test: `tests/faceless_hub_guide_flow_test.gd`
- Test: `tests/faceless_hub_guide_progress_store_test.gd`
- Test: `tests/faceless_hub_guide_input_self_check.gd`
- Test: `tests/faceless_hub_guide_layout_self_check.gd`
- Test: `tests/faceless_hub_layout_self_check.gd`
- Test: `tests/faceless_hub_end_to_end_self_check.gd`
- Test: `tests/faceless_hub_playability_self_check.gd`
- Test: `tests/main_entry_ui_contract_test.gd`

- [ ] **Step 1: 写引导流与持久化失败测试**

区段：

```ini
[faceless_hub_guide_v1]
seen_composite=false
seen_schedule=false
seen_restriction=false
dismissed=false
```

覆盖：

```text
checkpoint 顺序 composite → schedule → restriction
每个提示只请求一次
不再提示只影响无面区段
重看入口只重置无面区段
损坏配置保留原文件并安全放行
写入失败显示瞬时警告
目标缺失不标记已读
```

- [ ] **Step 2: 写入口、布局和端到端失败测试**

主入口稳定节点：

```text
%FacelessHubRunButton
%ReplayFacelessHubGuideButton
```

端到端真实路径：

```text
进入无面中枢
选择普通房
完成三轮
进入商店并离开
选择第二房
完成三轮
进入第二商店并离开
完成首领前两轮
选择最终限制
完成第三回合
选择并安装第二刻印
进入完成页
```

- [ ] **Step 3: 运行并确认入口和提示不存在**

```powershell
$log = "$env:TEMP\project-joker-faceless-task11-red.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file $log -s res://tests/run_all.gd
if ($LASTEXITCODE -eq 0) { throw "Expected faceless onboarding tests to fail" }
```

- [ ] **Step 4: 实现三个提示**

触发：

```text
composite：首次普通房绑定并稳定布局后
schedule：无面主人日程条绑定后
restriction：第二回合结束、限制面板稳定打开后
```

限制提示与模态面板共存时：

- 先打开限制面板。
- 等待两个渲染帧。
- 再让引导遮罩聚焦候选。
- 关闭提示后仍停留在限制选择，不自动选择。

- [ ] **Step 5: 增加主入口与独立重看**

`SingleEncounterScreen` 增加：

- 无面入口按钮连接。
- 无面重看按钮连接。
- 使用窗口 meta 传入测试配置路径。
- 正常进入不重置提示。

- [ ] **Step 6: 完成可玩性与布局校准**

`faceless_hub_playability_self_check.gd` 使用固定骰序验证：

- 四房常见夹具各至少两个不同合法方案。
- 两种首领限制均可通关。
- 两种限制的最佳操作序列不完全相同。
- 情报牌没有重复兑现。

`faceless_hub_layout_self_check.gd` 在 `1920×1080` 验证：

- 日程条、三轨、手牌、结算轨迹均在安全区。
- 限制面板两项内容无裁切。
- 三个提示聚焦框不越界。
- 完成、失败、设置和引导层级正确。

- [ ] **Step 7: 运行无面专项自检**

```powershell
$tests = @(
  'faceless_hub_guide_input_self_check.gd',
  'faceless_hub_guide_layout_self_check.gd',
  'faceless_hub_layout_self_check.gd',
  'faceless_hub_playability_self_check.gd',
  'faceless_hub_end_to_end_self_check.gd'
)
foreach ($test in $tests) {
  $log = "$env:TEMP\project-joker-$($test.Replace('.gd','')).log"
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file $log `
    -s "res://tests/$test"
  $code = $LASTEXITCODE
  $errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
  if ($code -ne 0 -or $errors) { exit 1 }
}
```

- [ ] **Step 8: 运行全量同步测试与主场景启动**

```powershell
$log = "$env:TEMP\project-joker-faceless-run-all.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  -s res://tests/run_all.gd
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

```powershell
$log = "$env:TEMP\project-joker-faceless-main.log"
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file $log `
  --quit
$code = $LASTEXITCODE
$errors = Select-String -LiteralPath $log -Pattern "SCRIPT ERROR|Failed to load script"
if ($code -ne 0 -or $errors) { exit 1 }
```

- [ ] **Step 9: 检查最终工作树和内容边界**

```powershell
git diff --check
git status --short
git diff --name-only
```

确认：

- 设计与实施计划仍在暂存区。
- 代码提交不包含两个文档。
- 手法牌为四十张、刻印十二种、庄家三名。
- 未新增连续三区域远征或十八项规则台目录的虚假完成标记。

- [ ] **Step 10: 提交入口、引导和最终验证**

```powershell
git add -- `
  scripts/ui/tutorial/faceless_hub_guide_flow.gd `
  scripts/ui/tutorial/faceless_hub_guide_progress_store.gd `
  scripts/ui/faceless_hub_run_screen.gd `
  scenes/run/faceless_hub_run_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  tests/faceless_hub_guide_flow_test.gd `
  tests/faceless_hub_guide_progress_store_test.gd `
  tests/faceless_hub_guide_input_self_check.gd `
  tests/faceless_hub_guide_layout_self_check.gd `
  tests/faceless_hub_layout_self_check.gd `
  tests/faceless_hub_playability_self_check.gd `
  tests/faceless_hub_end_to_end_self_check.gd `
  tests/main_entry_ui_contract_test.gd
git commit --only -m "feat: complete the faceless hub vertical slice" -- `
  scripts/ui/tutorial/faceless_hub_guide_flow.gd `
  scripts/ui/tutorial/faceless_hub_guide_progress_store.gd `
  scripts/ui/faceless_hub_run_screen.gd `
  scenes/run/faceless_hub_run_screen.tscn `
  scripts/ui/single_encounter_screen.gd `
  scenes/run/single_encounter_screen.tscn `
  tests/faceless_hub_guide_flow_test.gd `
  tests/faceless_hub_guide_progress_store_test.gd `
  tests/faceless_hub_guide_input_self_check.gd `
  tests/faceless_hub_guide_layout_self_check.gd `
  tests/faceless_hub_layout_self_check.gd `
  tests/faceless_hub_playability_self_check.gd `
  tests/faceless_hub_end_to_end_self_check.gd `
  tests/main_entry_ui_contract_test.gd
```

## Final Acceptance Checklist

- [ ] 无面中枢可从主入口独立进入。
- [ ] 两组选路、两房、两店、首领、刻印和完成页可完整运行。
- [ ] 三回合日程从首领开战起公开。
- [ ] 第二回合后必须选择最终限制。
- [ ] 操作与分配限制共享通用领域校验。
- [ ] 普通房使用同一限制资源提前教学。
- [ ] 十六张新牌均有合法目标、非法原因和结算测试。
- [ ] 四十张牌按四种花色各十张。
- [ ] 四种无面刻印均只在指定骰面和有效分配中触发。
- [ ] 一局最多安装两个刻印。
- [ ] 三个无面提示独立持久化且可以重看。
- [ ] `1920×1080` 下日程、三轨、手牌与结算轨迹无裁切。
- [ ] 固定样本中两种最终限制均可通关且策略不同。
- [ ] 金线回廊、反照牌厅、教程、设置和音效回归通过。
- [ ] 所有 headless 命令使用显式临时 `--log-file`。
- [ ] 设计与实施计划只暂存、未提交。
- [ ] 未宣称完整三区域远征或十八项规则台目录已经完成。
