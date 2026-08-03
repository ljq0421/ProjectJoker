# 表现、失败复盘与音乐收口实施计划

> 对应设计：`2026-07-31-presentation-failure-music-finish-design.md`
> 实施方式：严格 TDD，每项由失败测试开始
> 文档边界：只暂存，不进入阶段代码提交

## 1. 失败复盘红灯

新增测试：

- `tests/failure_review_builder_test.gd`
- 扩展 `tests/resolution_test.gd`
- 扩展 `tests/area_run_ui_contract_test.gd`

先要求：

- 规则失败与未触发效果以结构化字段输出；
- 普通遭遇也记录未分配骰；
- 跨轮分析能找出最弱轮次、去重失效规则和损失奖励；
- 失败面板存在结果、损失与建议节点。

红灯应因类、字段和节点不存在而失败。

## 2. 实现失败诊断

修改：

- `scripts/resolution/resolution_report.gd`
- `scripts/resolution/round_resolver.gd`
- 新增 `scripts/run/failure_review_builder.gd`
- `scripts/ui/round_summary_panel.gd`
- `scenes/components/round_summary_panel.tscn`

保持正式总分与事件顺序不变。运行核心与全量测试，比较既有固定种子结果。

## 3. 布局与视觉红灯

新增：

- `tests/area_presentation_catalog_test.gd`
- `tests/area_identity_ui_contract_test.gd`
- `tests/area_chrome_layout_self_check.gd`

先要求三个合法区域令牌、背景控件、庄家印记和正式顶部预留带；布局检查同时验证返回按钮、标题、设置入口互不相交。

## 4. 实现区域视觉与导航

新增：

- `scripts/ui/area_presentation_catalog.gd`
- `scripts/ui/area_atmosphere.gd`
- `scripts/ui/dealer_sigil.gd`

修改：

- `scenes/run/area_run_screen.tscn`
- `scenes/run/single_encounter_screen.tscn`
- `scenes/shop/shop_screen.tscn`
- `scripts/ui/area_run_screen.gd`
- `scripts/ui/single_encounter_screen.gd`
- `scripts/ui/shop/shop_screen.gd`

场景文件负责稳定层级与留白；脚本只绑定当前区域令牌并刷新绘制。

## 5. 音乐红灯与实现

扩展：

- `tests/music_service_test.gd`
- `tests/music_runtime_self_check.gd`
- `tests/settings_service_test.gd`
- `tests/settings_ui_contract_test.gd`
- `tests/settings_layout_self_check.gd`

新增区域内部音乐上下文测试。随后完成并审计当前音乐、总线、设置和主菜单接入文件，不重写已经通过的实现。

## 6. 资产验证

运行：

```powershell
python tools/verify_music_provenance.py --reproduce
```

确认三首 WAV：

- 集合与运行时引用一致；
- 32 kHz、立体声、16-bit PCM；
- 峰值不超过清单上限；
- 参数哈希与文件哈希一致；
- 重新生成后的 SHA-256 完全一致。

## 7. 产品验证

依次运行：

1. `tests/run_all.gd`
2. 三区布局、输入、可玩性和端到端检查
3. `tests/area_chrome_layout_self_check.gd`
4. `tests/music_runtime_self_check.gd`
5. 1280×720 与 1920×1080 失败页、遭遇页、商店页截图

截图人工检查：

- 顶部控件不重叠；
- 三个区域可在不读标题时凭背景与印记区分；
- 失败事实和建议不混淆；
- 文本无截断，按钮保持可点击。

## 8. 提交边界

先运行 `git diff --check` 和全量状态审计。使用显式路径只提交 D 阶段代码、音乐资产、生成与验证工具和测试。A/B/C/D 八份设计与实施文档保持已暂存、未提交。

提交后再次确认此前未进入范围的临时截图和审计文件未进入提交。
