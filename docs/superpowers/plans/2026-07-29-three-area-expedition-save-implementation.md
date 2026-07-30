# 三区域连续远征与边界存档实施计划

> 日期：2026-07-29  
> 对应设计：`2026-07-29-three-area-expedition-save-design.md`

## 1. TDD 顺序

1. 为 `ExpeditionSession` 写失败测试：固定顺序、跨区继承、失败和最终完成。
2. 实现最小远征领域模型。
3. 为 `AreaRunSession` 写失败测试：入口状态、边界快照和恢复原子性。
4. 实现入口注入、边界导出与恢复。
5. 为 `ShopSession` 边界序列化和事务回滚写失败测试。
6. 实现商店快照与恢复。
7. 为 `ExpeditionSaveStore` 写失败测试：版本、往返、损坏保留和替换。
8. 实现存档仓库。
9. 为主菜单与远征容器写 UI 合同测试。
10. 建立 `.tscn` 稳定结构并绑定开始、继续、放弃、区域切换和最终总结。
11. 写真实输入与布局检查。
12. 跑专项、完整回归和主场景启动。
13. 检查差异，只提交代码。

## 2. 领域文件

计划新增：

- `scripts/run/expedition_session.gd`
- `scripts/run/expedition_save_store.gd`
- `scripts/run/expedition_snapshot_validator.gd`
- `scripts/ui/expedition_run_screen.gd`
- `scenes/run/expedition_run_screen.tscn`
- `scenes/components/expedition_summary_panel.tscn`
- `scripts/ui/expedition_summary_panel.gd`

计划修改：

- `scripts/run/area_run_session.gd`
- `scripts/run/shop_session.gd`
- `scripts/ui/area_run_screen.gd`
- `scripts/ui/main_menu_screen.gd`
- `scripts/ui/shop/shop_screen.gd`
- `scripts/ui/area_complete_panel.gd`
- 对应 `.tscn`
- `project.godot`
- `tests/run_all.gd`

文件清单可根据 TDD 得到的最小结构收缩，但不得把稳定布局改为脚本运行时拼装。

## 3. 提交切分

建议代码提交：

1. `test: define expedition and save boundaries`
2. `feat: carry state across the three area expedition`
3. `feat: persist expedition room boundaries`
4. `feat: connect expedition navigation and summary`
5. `test: verify expedition recovery end to end`

每次提交使用显式代码路径，四份既有暂存文档和本阶段两份文档都不得进入提交。

## 4. 验证命令

所有命令显式使用可写日志：

```powershell
$log = Join-Path $env:TEMP 'project-joker-expedition.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $log `
  -s res://tests/expedition_session_test.gd
```

专项完成后运行：

```powershell
$log = Join-Path $env:TEMP 'project-joker-run-all.log'
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --path . --log-file $log `
  -s res://tests/run_all.gd
```

任一退出码非零或日志含 `SCRIPT ERROR|Failed to load script` 即失败。
已知证书、故意损坏配置、未知 SFX 和退出泄漏噪声按既有口径处理。

