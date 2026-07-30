# 《六面诡局》十八项基础规则台目录实施计划

> 设计规格：`docs/superpowers/specs/2026-07-29-rule-table-catalog-design.md`
> 适用引擎：Godot 4.6.1
> 工作分支：`master`
> 文档边界：只暂存，不提交

## Goal

建立十八项全局规则台模板、参数化规则实例、显式骰位和三种确定性扭曲效果，
把现有全部内容无行为迁移到模板目录，并提供六组可从主菜单进入的规则档案室
练习。

## Architecture

规则语义由 `RuleTableTemplate` 统一定义，遭遇中的 `RuleDefinition` 只保存模板
引用和参数。`RuleTableCatalog` 显式加载十八个模板并执行严格审计。

`RoundState.assignments` 改为固定槽位数组，空槽使用 `StringName()`；领域操作
支持精确槽位放置和原子交换。`RuleEvaluator` 基于模板评估条件，
`RoundResolver` 先预判全部规则，再确定方向并生成基础、回声、桥接和庄家事件。

规则档案室复用现有单场遭遇组件，通过六个资源化档案覆盖全部十八种模板。

## Global Constraints

- 工作目录固定为 `D:\Project\ProjectJoker\project-joker`。
- 直接在 `master` 开发已获本任务授权。
- 新设计规格和本实施计划只暂存，不提交。
- 代码提交必须使用显式路径或 `git commit --only` 排除暂存文档。
- 修改文件使用 `apply_patch`。
- 保护用户已有改动；每个任务开始前检查 `git status --short`。
- 现有三个地区的数值、目标、固定种子结果和事件总分不得变化。
- 不把新增规则编排进现有地区。
- 不实现连续三区远征、商店扩展、存档、演出、无障碍或叙事。
- 稳定 UI 结构保存在 `.tscn`，脚本只绑定数据、刷新状态和处理信号。
- 逻辑画布保持 `1920×1080`，开发窗口 override 保持 `1280×720`。
- 所有 headless 命令必须使用显式可写日志：

```powershell
$log = Join-Path $env:TEMP 'project-joker-<task>.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless `
  --path . `
  --log-file $log `
  -s res://tests/<test>.gd
```

- 判失败条件：退出码非零，或日志含 `SCRIPT ERROR|Failed to load script`。
- 证书读取、故意损坏 ConfigFile、未知 SFX 和退出资源泄漏是已知噪声。

## Planned File Structure

### Rule templates and catalog

- Create: `scripts/rules/rule_table_template.gd`
- Create: `scripts/rules/rule_table_catalog.gd`
- Create: `resources/rules/templates/*.tres`（十八项）
- Create: `tests/rule_table_catalog_test.gd`
- Create: `tests/rule_table_template_validation_test.gd`

### Parameterized evaluation

- Modify: `scripts/rules/rule_definition.gd`
- Modify: `scripts/rules/rule_evaluator.gd`
- Modify: `scripts/validation/content_validator.gd`
- Modify: `scripts/run/round_controller.gd`
- Create: `tests/rule_table_evaluator_test.gd`
- Modify: `tests/rule_evaluator_test.gd`

### Explicit slots

- Modify: `scripts/run/round_state.gd`
- Modify: `scripts/run/round_actions.gd`
- Modify: `scripts/run/round_controller.gd`
- Modify: `scripts/ui/rule_lane.gd`
- Modify: `scenes/components/rule_lane.tscn`
- Modify: `scripts/ui/single_encounter_screen.gd`
- Modify: `scripts/ui/single_encounter_session.gd`
- Create: `tests/explicit_slot_assignment_test.gd`
- Create: `tests/rule_slot_input_self_check.gd`

### Content migration

- Modify: `resources/rooms/**/*.tres`
- Modify: `resources/encounters/**/*.tres`
- Modify: `scripts/demo/single_encounter_fixture.gd`
- Modify: existing test fixtures that construct `RuleDefinition`
- Create: `tests/rule_template_migration_regression_test.gd`

### Distortion resolution

- Modify: `scripts/resolution/round_resolver.gd`
- Modify: `scripts/resolution/resolution_report.gd`
- Create: `tests/rule_table_distortion_test.gd`

### Rule archive

- Create: `scripts/rules/rule_archive_definition.gd`
- Create: `scripts/rules/rule_archive_catalog.gd`
- Create: `resources/rule_archive/*.tres`
- Create: `scenes/run/rule_archive_screen.tscn`
- Create: `scripts/ui/rule_archive_screen.gd`
- Create: `scenes/run/rule_archive_encounter_screen.tscn`
- Create: `scripts/ui/rule_archive_encounter_screen.gd`
- Modify: `scenes/run/main_menu_screen.tscn`
- Modify: `scripts/ui/main_menu_screen.gd`
- Create: `tests/rule_archive_catalog_test.gd`
- Create: `tests/rule_archive_ui_contract_test.gd`
- Create: `tests/rule_archive_input_self_check.gd`
- Create: `tests/rule_archive_layout_self_check.gd`
- Create: `tests/rule_archive_playability_self_check.gd`

## Task 1: Establish the eighteen-template catalog

- [ ] Write failing tests for exact template IDs, categories `4 / 7 / 4 / 3`,
      unique paths, copy, slot bounds and modifier compatibility.
- [ ] Run the focused test and verify missing types/resources fail.
- [ ] Implement `RuleTableTemplate` enums and validation.
- [ ] Implement the explicit-path `RuleTableCatalog`.
- [ ] Create eighteen `.tres` template resources.
- [ ] Verify catalog lookup by ID and category.
- [ ] Run focused tests and `tests/run_all.gd`.
- [ ] Commit only Task 1 code and tests.

Acceptance:

- Catalog contains exactly eighteen unique templates.
- Template resources contain no room-specific target or coefficient.
- Three distortion templates use `ANY_FILLED` plus explicit post-pass effects.
- No existing room is migrated yet.

## Task 2: Parameterize rule instances and implement all conditions

- [ ] Write failing tests for all fifteen condition kinds.
- [ ] Cover boundaries, invalid parameters and ordered versus unordered values.
- [ ] Add template reference and condition parameters to `RuleDefinition`.
- [ ] Replace legacy `ConditionType` evaluation with template-driven evaluation.
- [ ] Implement per-template condition-modifier compatibility.
- [ ] Extend `ContentValidator` with instance parameter validation.
- [ ] Update condition summaries and concrete invalid reasons.
- [ ] Run evaluator, card-rule, controller and full synchronous tests.
- [ ] Commit only Task 2 code and tests.

Acceptance:

- Exact, minimum, maximum and range sums handle inclusive boundaries.
- Equal, distinct, even, odd, parity, consecutive and fixed-difference semantics
  match the confirmed specification.
- Ascending, descending, mirrored and slot-target conditions preserve input order.
- Invalid or unreachable parameters fail before gameplay starts.

## Task 3: Introduce explicit slots and atomic swaps

- [ ] Write failing domain tests for empty middle slots, exact placement, moves,
      same-lane swaps, cross-lane swaps and one-step undo.
- [ ] Write failing UI contract and real-input tests for direct slot targets.
- [ ] Change assignments to fixed arrays with explicit empty markers.
- [ ] Update every assignment reader to skip empty markers.
- [ ] Add `assign_die_to_slot()` and `swap_assigned_dice()` domain operations.
- [ ] Keep lane-level assignment as “first empty slot”.
- [ ] Build stable slot controls in `rule_lane.tscn`.
- [ ] Bind click, drag, highlight, target copy and invalid reasons.
- [ ] Verify `Esc` cancels selection without changing state.
- [ ] Run domain, UI, tutorial, restriction and full regression tests.
- [ ] Commit only Task 3 code, scene and tests.

Acceptance:

- Position conditions read visual slot order.
- Illegal occupied-slot placement leaves state and history unchanged.
- A two-die swap is atomic and undone in one step.
- Old lane-click and lane-drop paths still work.

## Task 4: Migrate all existing content without behavior changes

- [ ] Capture baseline reports for the existing teaching encounter, twelve rooms,
      three dealers and the faceless three-round schedule.
- [ ] Add external template references to every shipped rule instance.
- [ ] Migrate code-created and test-created rule fixtures.
- [ ] Remove final runtime dependence on legacy `ConditionType`.
- [ ] Require catalog membership for all formal content.
- [ ] Compare migrated baseline rule validity, event order and totals.
- [ ] Run all old area, guide, layout, playability and end-to-end checks.
- [ ] Commit only Task 4 resources, fixtures and regression tests.

Acceptance:

- No formal encounter contains an empty or catalog-external template.
- Existing rule names, parameters, room targets and rewards remain unchanged.
- All fixed-seed old-region outcomes match the captured baseline.

## Task 5: Resolve echo, reverse and bridge tables

- [ ] Write failing tests for a single reverse, multiple reverses and card/table
      reverse parity.
- [ ] Write failing tests proving echo copies only one base result.
- [ ] Write failing tests for bridge success, target failure and both directions.
- [ ] Refactor resolution into condition preflight, direction planning, base events,
      intrinsic effects and dealer completion.
- [ ] Store final direction in the report before score events.
- [ ] Add explicit zero-delta events for inactive distortion effects.
- [ ] Enforce bridge placement on the middle track.
- [ ] Verify no card, engraving or distortion effect recursively copies another.
- [ ] Run preview/commit equivalence and full regression.
- [ ] Commit only Task 5 code and tests.

Acceptance:

- Preview and commit reports are structurally identical.
- Echo, card repeat and engraving events have distinct sources.
- Bridge always targets the adjacent table in final resolution direction.
- Existing encounters without distortion templates keep their event order.

## Task 6: Build the six rule archive exercises

- [ ] Write failing archive catalog tests for six entries and exact template coverage.
- [ ] Define six resource-backed archive encounters with six total slots each.
- [ ] Prove each fixed dice sample has at least two multi-table scoring allocations.
- [ ] Build a scene-first archive selection page.
- [ ] Build a thin archive encounter orchestrator that reuses the shared encounter UI.
- [ ] Add retry, return-to-archive and return-home controls.
- [ ] Add the main-menu archive entry.
- [ ] Verify no intel, engraving, area reward or persistent progress is written.
- [ ] Run UI contracts, real-input navigation and both layout resolutions.
- [ ] Commit only Task 6 code, scenes, resources and tests.

Acceptance:

- All eighteen templates appear exactly once across six exercises.
- All exercises are immediately available and infinitely retryable.
- Position and distortion explanations are visible before commit.
- Main menu and every return route work through real pointer clicks.

## Task 7: Final acceptance

- [ ] Run `tests/run_all.gd`.
- [ ] Run focused template, slot, distortion and archive tests.
- [ ] Run all three area end-to-end checks.
- [ ] Run tutorial, settings, SFX and navigation regression.
- [ ] Run archive real-input, layout and playability checks.
- [ ] Start the main scene headlessly with an explicit temp log.
- [ ] Inspect every log for `SCRIPT ERROR|Failed to load script`.
- [ ] Inspect `git diff --check`, `git diff --stat` and `git status --short`.
- [ ] Confirm the design and plan remain staged and excluded from code commits.
- [ ] Commit only final code/test corrections with explicit paths.

## Final Acceptance Checklist

- [ ] Eighteen independent rule templates load and validate.
- [ ] Category counts are exactly `4 / 7 / 4 / 3`.
- [ ] All formal encounters reference catalog templates.
- [ ] Explicit slot placement, cross-track swapping and one-step undo work.
- [ ] All fifteen conditions produce correct positive and negative results.
- [ ] Echo, reverse and bridge effects are public, deterministic and non-recursive.
- [ ] Preview and commit reports match exactly.
- [ ] Existing region balance and fixed-seed outcomes do not change.
- [ ] Six archive exercises cover all templates exactly once.
- [ ] Every archive has at least two multi-table scoring solutions.
- [ ] `1280×720` and `1920×1080` layouts pass.
- [ ] Real mouse navigation passes from main menu through completion and back.
- [ ] All headless logs are free of script load and compile errors.
- [ ] Design and plan documents remain staged and uncommitted.
