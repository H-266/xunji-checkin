# 本轮修复清单（1.0.0 发布闭环）

| 类别 | 问题 | 处理 | 验证 |
| --- | --- | --- | --- |
| 隐私合规 | 首次启动直接进入首页，未展示隐私政策 | 新增 `PrivacyConsentScreen` + `SettingsProvider.privacyAccepted`；设置读取完成前显示纯色启动页；未同意只显示隐私门 | 真机 `pm clear` 后启动，未勾选时“同意并继续”禁用；集成测试通过 |
| 隐私合规 | 应用内无完整政策/权限说明 | 新增中英双语 `PrivacyPolicyScreen`，设置页增加入口与“关于” | 真机打开政策页，返回正常 |
| 隐私合规 | 拒绝同意后的文案与行为不一致 | 政策页改为“拒绝后应用将退出，不会读取任务数据” | 静态检查 |
| 签名 | release 固定 debug 签名，无正式签名配置 | `build.gradle.kts` 读取 `android/key.properties`，有 keystore 时使用 release 签名；新增示例文件和 `tool/build_release.ps1` | 无 keystore 时构建成功，`apksigner` 仍显示 `CN=Android Debug`；正式签名需用户提供 keystore |
| 开源 | 缺少 LICENSE/PRIVACY/CHANGELOG/CONTRIBUTING/Issue 模板 | 新增 MIT License、双语隐私政策、更新日志、贡献指南、Bug/功能模板、架构文档 | 文件审查 |
| 构建 | 中文路径 release AOT 失败 | `build_release.ps1` 自动 `subst X:`，构建后释放；README 说明手工方案 | 脚本已编写，正式签名路径待用户 keystore 验证 |
| 商店 | 无图标/banner/截图/商店文案 | 生成 512 图标、1024×500 banner、5 张 1080×1920 截图草稿；新增中英文商店元数据 | 本地图片尺寸检查 |
| 动效/引导 | 新手引导高亮框与真实控件错位 | GlobalKey 测量 + 420ms 等待 FAB 入场结束；步骤 1–4 真机截图核对 | 真机截图 |
| 主题 | 浅色模式顶部/底部残留深蓝系统栏 | 系统栏透明，由 App 背景铺满；`AnnotatedRegion` 同步图标明暗 | 真机深/浅色截图 |
| 主题 | 深浅色切换整树逐帧插值卡顿 | `themeAnimationDuration: Duration.zero`，一次性换色；设置/组件同步延后 900ms | 真机测量 4 帧，最大约 41–49ms，仍有一帧整树重建 |
| 数据 | 首次启动设置与任务并发打开数据库 | 数据库单飞打开（`_opening` Future 去重） | 现有测试/启动验证 |
| 数据 | 日详情 100 条任务一次性布局 | `ListView.builder` 固定高度并移除 `shrinkWrap` | 代码修复；最终包未稳定复测 |
| 稳定性 | 数据库完整性异常无修复入口 | 启动自检 + 一键修复 / 回滚本地快照 | 代码路径；未造损坏库实测 |

## 未在本轮解决

- 连续勾选 120Hz 性能未达标（12.8–13.6ms，>8.33ms 约 70%）。
- 用户可见文案仍有中文兜底，未做到零硬编码。
- 小组件逐尺寸、通知杀进程送达、SAF 全流程未逐项真机验收。
- 正式 keystore 未提供，当前 release 仍是 debug 签名。

| 原生 4×4 卡片文字重叠 | 状态文字与第一条任务共用 y 坐标 | 任务列表起点改到状态文字之后，并预留 footer 高度 | 已用 `docs/widget-samples/checkin_4x4.png` 验证 |
| 原生 4×2 卡片右半边空白 | 6 条任务只排单列 | 改为 3+3 两列，列宽按可用宽度均分 | 已用 `checkin_4x2.png` 验证 |

## 搜索标题栏卡顿优化

- 搜索输入加入 120ms 防抖，避免每次按键重建整页结果。
- 结果条数限制 80，结果行改为轻量扁平行 + RepaintBoundary，移除 Card/ListTile 的额外 Material 层。
- 仅代码与构建验证；未采集逐字帧数据。
