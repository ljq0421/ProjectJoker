# 《六面诡局》Steam Demo 发布工作区

这里保存不会进入游戏导出包的 Steam Demo 发布资料。`export_presets.cfg` 已排除 `release/*`。

## 当前公开范围

- 产品名：《六面诡局 Demo》
- 版本：`0.1.0-demo.1`
- 平台：Windows x86_64
- Demo 内容：新手引导 + 一次完整三地区远征
- 开发者署名：暂不公开

Steam Demo 构建会隐藏单地区练习、规则档案室和基础牌局演练；这些入口仍保留在编辑器/完整开发构建中，便于调试。

## 目录

- `release_checklist.md`：上线前人工与自动验收清单
- `store_assets_manifest.json`：商店素材规格、文件名和当前状态
- `store_assets/screenshots/`：可重复生成的 1920×1080 实机截图
- `playtests/`：真人试玩记录与结论

## 常用命令

```powershell
tools\capture_steam_demo_screenshots.cmd
tools\verify_steam_demo_release.cmd
tools\build_windows_demo.cmd
```

`verify_steam_demo_release.cmd` 默认允许尚未完成的胶囊图和预告片，但会将其列为警告。准备提交 Steam 审核时使用严格模式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_steam_demo_release.ps1 -RequireStoreAssets -RequireHumanPlaytest
```
