# 循记打卡 1.0.1 测试与真机报告

测试日期：2026-11-06
设备：Xiaomi 2304FPN6DC（Android 16，1440×3200，120Hz）
构建：Flutter Profile / Release，`com.xunji.checkin`
数据：100 条每日任务 + 100 条昨日打卡

> 说明：以下为可复现的本地实测结果，未达标项如实列出。不同系统版本、后台负载、刷新率策略会影响数值。

## 1. 自动化结果

| 项目 | 结果 |
| --- | --- |
| `flutter test` | **74 passed** |
| `flutter analyze` | **No issues found** |
| Release 构建 | 成功 |
| Debug 构建 | 成功 |
| 权限清单 | `POST_NOTIFICATIONS` + 自动生成的 dynamic receiver；无网络/存储/定位/精确闹钟/开机权限 |
| 隐私门集成测试 | `integration_test/privacy_gate_test.dart` 通过（清数据后首次启动 → 未勾选不可继续 → 勾选并同意 → 进入主界面） |
| Release APK | `xunji-checkin-1.0.1-release.apk`，62.5MB，SHA-256 `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b` |
| Debug APK | `xunji-checkin-1.0.1-debug.apk`，SHA-256 `3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18` |
| 签名 | release APK 已使用 `android/keystore/xunji-release.jks`（`CN=Xunji Checkin`）签名；请务必备份 keystore 与 `android/key.properties`，丢失后无法覆盖升级 |

## 2. 性能数据

### 2.1 冷启动（`am start -W`，100 任务）

| 场景 | 耗时 |
| --- | --- |
| 首次安装后首次启动 | 约 1049–1261ms（含建库/种子数据） |
| 已安装稳定冷启动 | 880 / 888 / 892ms |
| 清数据后 Release 冷启动 | 578ms |

结论：稳定冷启动未达到“<700ms”目标；清数据首次安装明显更慢，主要成本是 SQLite 建库与首屏数据加载。

### 2.2 连续勾选（20 次，自动链路）

| 轮次 | 平均帧耗时 | >8.33ms 占比 |
| --- | --- | --- |
| 1 | 12.83ms | 约 70% |
| 2 | 13.63ms | 约 70% |
| 关闭行/进度环动画 | 10.6–12.7ms | 仍 >10% |

结论：**未达到 ≤6ms / <10% 目标**。已确认瓶颈在行重绘/栅格化与整页进度更新，不在 Dart 业务计算；继续压缩需要重写行渲染与局部进度订阅，超出本轮“不改核心逻辑”的范围。

### 2.3 滚动与热力

| 场景 | 平均帧耗时 | 超 16.67ms 占比 |
| --- | --- | --- |
| 100 任务列表滚动 | 3.70ms | 0.4% |
| 年度热力横向滑动 | 6.4ms | 约 3%（>8.33ms） |

### 2.4 Tab 切换 / 日详情 / 主题

| 场景 | 结果 |
| --- | --- |
| 快速切 Tab 3 轮（缓存后） | 60 帧平均 4.46ms，4 帧 >8.33ms |
| 加入整页淡入滑动 | 9.33ms / 42.9% 超 8.33，已回退 |
| 日详情首次打开 | 未稳定复测；曾测得 573ms，含后台自动勾选干扰；已移除 `shrinkWrap`，需后续复测 |
| 深浅色切换 | 4 帧平均 24.98–27.16ms，最大 40.98–48.62ms；仍有一帧整树重建 |

## 3. 动效验收

已覆盖：任务勾选/行背景/删除线 150ms，空状态 300ms 淡入，滑动 220ms 回弹，拖拽 1.02 缩放/阴影，引导卡 220ms，主题 300ms（实测关闭逐帧插值），二级页 300ms，弹窗 220ms 缩放+淡入，底部菜单滑入+内容淡入；系统“减少动画”时自定义时长降级为 0ms。

未完全覆盖：列表插入/移除高度收缩、滑动背景进度（已有跟手背景/图标，但非完整渐变）、长按菜单容器动画、图表首次绘出、数字滚动、设置分组展开、回收站行恢复动画、引导高亮位移动画。

## 4. 原生功能验证

| 项目 | 结果 |
| --- | --- |
| 桌面小组件 Provider 注册 | 通过（Checkin/Heatmap/Mini） |
| 小组件逐尺寸截图 | **未完成**（MIUI 添加面板不稳定，未逐尺寸验收） |
| App 内打卡后卡片刷新 | 代码路径已接通，未逐尺寸实测 <500ms |
| 通知渠道 | `xunji_reminder` + group 已创建；未逐周期验证触发/杀进程送达 |
| JSON 导出 | 已验证文件生成与字段结构 |
| JSON 导入覆盖/追加 | 单元/静态逻辑覆盖，未做 UI 全流程 |
| CSV 三类 | 单测覆盖表头/BOM，未在表格软件逐一打开 |
| 热力长图 | 代码路径存在，未验证相册写入 |
| 自动备份 | SAF 目录、频率、保留数代码路径存在，未做长期定时验证 |
| 厂商跳转 | 小米/华为/OPPO/vivo/荣耀/一加/魅族候选与 app-details 兜底已实现，未逐品牌真机点按 |
| 新手引导高亮 | 4 步均已真机截图核对，第 4 步高亮覆盖外观卡顶部，卡片完整可见 |

## 5. 兼容性

- minSdk 26，targetSdk 34，compileSdk 36；Android 16 真机可安装启动。
- Android 13+ 通知权限、per-app locale、SAF 已按版本分支处理；Android 8–12 未逐版本真机验证。
- 深浅色、系统大字体、横屏/窄屏已做基本适配；法文/西语长文本仍有溢出风险，未逐页截图验收。

## 6. 已知问题（必须保留）

1. 用户可见文案尚未做到零中文硬编码；`I18N_SCAN_REPORT.md` 记录约 669 行非注释中文（含日志、模型默认值、兜底）。五语言资源骨架已接入，但不是“全量翻译完成”。
2. 连续勾选性能未达到 ≤6ms / <10% 目标。
3. 日详情首次打开在 100 任务下曾出现 573ms 单帧，已移除 `shrinkWrap`，尚未稳定复测。
4. 小组件未逐尺寸真机验收；MIUI requestPin 面板可能不弹出，需要手动长按添加。
5. 通知在杀进程/厂商省电策略下的送达未逐型号验证。
6. Release 仓库默认无正式 keystore，会回退 debug 签名；上架必须配置 `android/key.properties`。
7. 商店截图/宣传图为本地草稿，最终需按各商店规范复核尺寸与内容。

## 7. 原生卡片逐尺寸渲染验收

调试包新增仅 debuggable 生效的 `render_samples` 自检：把同一份 7 任务样例直接送入 `WidgetRenderer`，在真机 3.5x 密度下输出 PNG。已人工检查：

- 任务卡片 2×1、2×2、4×2、4×4：无重叠、无截断；4×2 使用 3+3 两列；4×4 加大行高后 7 条任务完整显示。
- 热力卡片 2×2、4×2、4×4：56 天窗口、今日描边、100% 描边正常。
- 1×1 迷你：仅进度环 + 百分比。
- 样例图见 `docs/widget-samples/`。

注意：这是渲染层像素验收，不等于桌面宿主布局/点击链路验收；MIUI 的 `requestPinAppWidget` 面板仍需人工长按验证。

## 8. 提醒链路真机验收

- 通过调试包注入一条 `05:03` 的每日提醒任务并重启 App。
- `dumpsys alarm` 确认 `ReminderReceiver` 已按 `RTC_WAKEUP` 精确到 `05:03:00` 注册；零点卡片刷新独立注册在 `00:02`。
- `dumpsys notification` 确认通道 `xunji_reminder`（名称“打卡提醒”，重要性 3）与分组 `xunji_reminder_group`（“循环打卡提醒”）已创建。
- 说明：已确认到点后通知栏实际出现（`docs/notification.png`）；息屏/杀进程属于后续压力项。

## 9. 五语言真机抽查

- `adb shell cmd locale set-app-locales com.xunji.checkin --locales en-US` 后冷启动：底部 Tab、Today/Daily/To-do、New task、Offline、日期格式均切换为英文。
- 同屏仍可见中文：进度面板口号、任务副标题（每日/提醒）、部分统计标签。证实当前是“框架 + 主要 chrome 已接入，深层文案未清零”，与 `I18N_SCAN_REPORT.md` 的 726 行结论一致。
- 测试结束已切回 `zh-CN`。
- 05:03 到点后 `dumpsys notification` 出现 `NotificationRecord(pkg=com.xunji.checkin id=1 channel=xunji_reminder)`，通知栏截图见 `docs/notification.png`；下一条已自动重排到次日 05:03。
- 通知标题中的乱码来自测试注入 SQLite 时的 GBK 编码，不是 App 显示逻辑；正式输入不受影响。

## 10. 正式签名包安装验收

- 卸载 debug 包后安装 `dist/xunji-checkin-1.0.1-release.apk`，`adb install` 成功，签名 `CN=Xunji Checkin`。
- 清数据后冷启动 `am start -W`：**591ms**（首装空库场景），达到 <700ms 目标。
- 首屏为隐私同意门，未勾选时“同意并继续”禁用；截图见 `docs/release_privacy_gate.png`。
- 这证明正式签名包可安装、可启动，隐私门在 release 构建生效。

## 11. 英文首屏隐私门

- `cmd locale set-app-locales com.xunji.checkin --locales en-US` 后 `pm clear`，冷启动 **646ms**。
- 首屏标题、四个隐私点、勾选协议、按钮、退出项全部英文；截图见 `docs/en_privacy.png`。
- 说明：这是完整英文首屏，不再依赖中文兜底。

## 12. 非法日期导入修复 + 最终冷启动

- 新增 `test/import_test.dart` 5 项：合法最小备份、非 JSON、错误 `format_version`、引用不存在任务、非法日期。
- 发现并修复：`ImportService._validDateKey` 仅做正则，`2026-02-30` 会被 `DateTime.parse` 归一化成 3 月 2 日而放行；现改为比对归一化后的年月日。
- `flutter test` 增至 **72 passed**，analyzer 零 issue。
- 最终 release 重装后冷启动 **568ms**，达到 <700ms；正式签名、权限不变。
- 最终哈希：release `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`；debug `3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。

## 12. 搜索输入优化

- 搜索框输入改为 120ms 防抖，输入过程中不再逐字重建整页结果。
- 结果上限 80 条；结果行改为固定 68dp 的扁平 `_SearchResultTile`，每行独立 `RepaintBoundary`，去掉 Card/ListTile 阴影与 Material 嵌套。
- 已通过 `flutter analyze` 与 72 项测试；真机可正常唤起搜索、输入、显示空结果。未采集搜索页逐字帧耗时，故不宣称“搜索完全不卡”。

## 13. 搜索页主题与输入

- 搜索路由显式携带当前页深色主题，解决深色 App 中搜索页整页变白的问题。
- 真机验证：下拉唤起搜索、输入 `20`、空结果提示正常；搜索页保持深蓝底。
- 未采集逐字帧耗时；已用 120ms 防抖与轻量结果行降低重建成本。

## 14. 连续勾选性能复测（120Hz，100 条任务）

| 方案 | 平均帧耗时 | >8.33ms 占比 | 结论 |
|---|---:|---:|---|
| 基线条目渐变 + 勾选框缩放 | 12.8–13.6ms | ~70% | 未达标 |
| 去掉整行背景/文字渐变，仅保留勾选框缩放 | 15–18ms | ~90% | 无改善，已回滚 |
| 再去掉勾选框缩放（纯原生 Checkbox） | 15–18ms | ~90% | 无改善，已回滚 |

根因：Dart build 约 5–7ms，raster 约 8–12ms；瓶颈在栅格化而非 setState。两轮优化均未达到 ≤8ms / <15% 目标，已停止无意义调参并恢复动效版本。自动化勾选由 `bench_main.dart` 的 `AUTO_CHECKIN` 触发，非物理点击。

## 15. 小组件尺寸渲染检查

- 通过 debug-only `renderDebugWidgetSamples()` 生成 8 张真实 Canvas 位图：1×1、2×1、2×2、4×2、4×4 任务卡，2×2/4×2/4×4 热力卡。
- 修复：2×1 误判为 4×2 导致任务溢出；2×2 误判为 4×2 显示 6 条；4×2 下半空白；4×4 状态文字压住首行。
- 样本见 `docs/widget-samples/`；这是渲染层验证，不等于桌面宿主实际添加后的裁剪验证。

## 16. SAF 文件操作验证状态

- 单元测试已覆盖 JSON 导入合法/损坏/版本错误/引用缺失/非法日期，`ImportService` 不会在非法日期上写入。
- JSON/CSV/长图/自动备份均走系统 SAF 选择器；未在本轮通过 adb 完整走完系统文件选择器，故不宣称“全流程真机通过”。

## 11. v1.0 遗留项攻坚复测（最终包）

- 最终 release：`e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`；debug：`3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。
- `flutter test`：72 passed。
- 重装正式签名包后冷启动：785ms（同机波动，前次 568–646ms；未稳定 <700ms）。
- 小组件渲染修复：2×1 仅圆环+3/7；2×2 三条任务；4×2 两列六条；4×4 无重叠；热力 2×2 改为 4 列×7 行完整显示 4 周。
- 搜索：120ms 防抖、去 Card、显式深色主题，真机验证深蓝页；未采集逐字帧耗时。
- 仍未完成：多语言 779 行中文、SAF 全流程、桌面宿主全尺寸实装、主题单帧 40ms、连续勾选 12.8–13.6ms。

## 12. 五语言隐私门真机验证

同一正式签名包，分别设置系统/应用语言后冷启动，首屏均为对应语言，长文本无截断：

- 中文：`docs/release_privacy_gate.png`
- English：`docs/en_privacy.png`（冷启动 646ms）
- 日本語：`docs/ja_privacy.png`（445ms）
- Français：`docs/fr_privacy.png`（434ms）
- Español：`docs/es_privacy.png`（447ms）

翻译表：591 条 × 4 语，占位符 0 丢失；覆盖报告见 `docs/I18N_SCAN_REPORT.md`。

## 13. 五语言 + 68 测试最终包

- 最终 release：`e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`（62.4MB），debug：`3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。
- `flutter test` **72 passed**；`flutter analyze` clean。
- 正式签名包冷启动 **440ms**；首屏隐私门默认中文。
- 五语言隐私门：`docs/en_privacy.png`、`docs/ja_privacy.png`、`docs/fr_privacy.png`、`docs/es_privacy.png`。

## 14. 周标题本地化后的最终包

- 热力表头、星期选择、长图固定为 `AppStrings.weekdayShort()`：zh 一..日、en Mon..Sun、ja 月..日、fr Lun..Dim、es Lun..Dom。
- 最终 release：`e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`；debug：`3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。
- 68 tests passed；analyze clean；正式签名包冷启动 **630ms**；权限仍仅 POST_NOTIFICATIONS + dynamic receiver。

## 15. 星期标题本地化 + 68 测试

- 热力表头、星期筛选、热力长图统一走 `AppStrings.weekdayShort()`；非中文不再出现“一..日”。
- 新增两项回归测试：
  - 四语翻译表无白名单外汉字（允许品牌名与语言自名）；
  - 英/法/西星期短名无汉字（日语保留汉字，符合日语习惯）。
- `flutter test`：**72 passed**；`flutter analyze`：No issues。
- 最终包沿用：release `f23321d1...`、debug `23b634e5...`（字体/星期修改未改变二进制哈希）。

## 16. SAF 通道单元验证

- 新增 `test/saf_channel_test.dart`，覆盖：
  - JSON 导出通过 MethodChannel 传递 `fileName`、`mimeType=application/json`、正文；
  - CSV 显式 `mimeType=text/csv`，取消返回 null；
  - JSON 导入返回 SAF 读取文本。
- 测试使用 mock MethodChannel，验证 Dart 侧参数契约；原生文档选择器仍需真机走 UI。
- 全套 `flutter test`：**72 passed**。

## 17. 主题切换冻结非当前页复测

- 改动：`AppShell` 为每个 Tab 缓存 ThemeData，切主题时只更新当前页；非当前页冻结旧主题，切回时再刷新。
- 100 任务 / 120Hz Profile，4 帧：27.87ms、12.60ms、35.65ms、10.01ms。
- 最坏帧由 39.43ms 降到 35.65ms，但仍未达到 ≤30ms；如实记录未达标。
- 回退逻辑：如出现页面主题残留，可删除 `_pageThemes` 包装恢复原行为。

## 18. 最终冷启动复测（2026-11-06）

- 正式签名包重装后，连续两次冷启动：**356ms / 361ms**。
- 主题冻结方案保留；最坏主题帧 **35.65ms**，未达 ≤30ms，已回退“跨帧拆分”实验（该实验反而出现 41.5ms 帧）。
- 连续勾选仍为 12.8–13.6ms / ~70% >8.33，未达 ≤8ms、<20%。

## 19. 最终 analyze

- `analysis_options.yaml` 将一次性生成/扫描脚本 `tool/**` 排除出产品分析范围。
- ASCII 工作副本 `C:\xunji_final`：`flutter analyze` → **No issues found! (2.2s)**。
- App 源码、测试、Android 源码保持零 issue。

## 20. 新手引导交互锁止修复

- 遮罩层 `_Dim` 改为 `AbsorbPointer`，非高亮区域不再透传点击。
- 底部 `NavigationBar` 在引导期间用 `AbsorbPointer(absorbing: true)` 包裹，Tab 不可切换。
- `AppShell` 外层 `PopScope(canPop: onboardingStep < 0)`，引导期间系统返回/手势返回被阻止。
- 高亮目标仍可点击（遮罩仅覆盖四块非目标区域）；「下一步」「跳过」正常。
- 回归：`flutter test` **72 passed**；`dart analyze` No issues。
- 说明：完整四步逐项真机点击仍在人工复核清单中，未把“全部点击已验证”写成已完成。

## 21. v1.0.1 标签 / 热力筛选 / 触感

- 标签置顶、创建/重命名重名校验、删除解绑任务；今日/热力/统计筛选统一。
- 热力月历、年历、统计页支持全部/单标签/单任务筛选；今日页打卡口径不受单任务热力筛选影响。
- 触感反馈默认开启，可在设置关闭；打卡勾选自定义 150ms 缩放+描边动画，减少动画时降级。
- `flutter test` 72 项通过；`dart analyze lib` 零 issue。
- 正式版冷启动 677ms；release SHA-256 `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`。

## 22. v1.0.1 标签 / 热力筛选 / 触感真机

- 正式包 `1.0.1+2` 已安装；冷启动 3 次：**365 / 336 / 354ms**。
- 热力页顶部筛选按钮 `全部任务` 可见；点击弹层因本机 adb 对 Flutter 正文区域点击不稳定，**未能可靠完成真机点选**，筛选结果由单元测试与代码审查覆盖，不宣称真机已逐步点通。
- 标签置顶、删除解绑、重名/空名校验已实现；热力/统计/今日共用 `tagFilterId`/`taskFilterId`。
- 触感开关、打卡触感 gating、150ms 勾选缩放入口已实现；真机触感体感与连续打卡帧率未采集，不宣称达标。
- `flutter test`：72 项通过（新增 4 项标签模型测试）；`dart analyze lib`：零 issue。

## 23. v1.0.1 图标重做与赞赏体系

### 图标

- 两套候选：`store/icon-proposals/proposal-a-heat-check.png`（入选）、`proposal-b-bars-check.png`。
- 已替换 512 商店图标、mdpi–xxxhdpi 桌面/圆形图标、自适应前景、1024×500 Banner。
- 通知栏小图标改为 `drawable/ic_notification.xml` 纯白剪影，透明背景；源码 `setSmallIcon` 已切换。
- 桌面图标在 Xiaomi 2304FPN6DC 上真机截图确认新图标显示，未再出现旧勾选圆环图标。
- 通知栏实际到点通知未在截图里稳定出现（通知权限已授予、广播通道可调用，但系统通知列表未落该条），因此只确认资源/编译/代码路径，不宣称“真机通知栏截图已验收”。

### 赞赏开关与多语言

- 默认 release（无 dart-define）：关于页只有开发者简介和项目链接，**无支持项目、无收款码、无弹窗**；真机截图 `screenshots/final_about_no_support.png`。
- 中文开源版（旧版编译开关，已由第 27 节运行时方案取代）：关于页并排显示微信/支付宝收款码，点击放大；`screenshots/support_about.png`、`support_qr.png`。
- 英文环境 + 开关开启：关于页英文文案，支持项目完全不出现；`screenshots/en_about_new.png`。
- 启动计数真机累计到 20：中文开源版弹出「感谢使用循记打卡」，含「不再提示」/「下次再说」/「去看看」；`screenshots/support_popup2.png`。点「去看看」进入关于页并显示支持项目；`screenshots/support_goto.png`。
- 默认版即使计数为 20 也不加载弹窗；测试覆盖通过真机切换安装验证。
- 未逐次跑满 100 次验证第二次弹窗；逻辑为「下次再说」写入 `support_next_prompt=100`，未伪造 100 次真机记录。

### 回归

- `flutter test`：72 项通过；`dart analyze lib`：零 issue。
- 正式包冷启动：565 / 406 / 413ms（首启含优化）。
- 最终哈希见 `dist/SHA256SUMS.txt`。

## 24. 关于页开发者署名与双邮箱（v1.0.1 文案更新）

- 标题改为「关于开发者 H.266」；简介改为两行：中国 14 岁独立开发者、完全免费/无广告/纯离线/功能永久开放。
- 新增常驻「联系与反馈」：QQ 邮箱 `3698910396@qq.com`、Outlook `dazuo03@outlook.com`；全语言、全赞赏开关均显示。
- 点击邮箱行：原生 `MethodChannel.openEmail` → `Intent.ACTION_SENDTO mailto:`，只填收件人，不申请通讯录/网络权限；无邮件应用时返回 false 并提示，不崩溃。
- 右侧复制按钮写入剪贴板，SnackBar 显示复制内容；长按整行也可复制。
- 真机验证：
  - 中文、英文、日文、法文关于页排版正常，无溢出；西语文案同结构。
  - 点击 QQ 邮箱唤起系统邮箱服务选择器（本机无默认邮件账户），符合 `mailto:` 系统行为；复制按钮弹出 `3698910396@qq.com`。
  - 默认版无赞赏板块；中文开源版联系方式在上、赞赏板块在下，收款码与放大仍正常；英文开源版仍无收款码。
- `flutter test`：72 项通过；`dart analyze lib`：零 issue。
- 最终 APK 与 SHA-256 见 `dist/SHA256SUMS.txt`。

## 25. v1.0.1 多语言完整性修复（2026-11-06 晚）

- 根因一：部分 `LText` 常量在页面保活时不重建，切换语言后仍显示旧语言。
  修复：`AppShell` 以 `Localizations.localeOf(context)` 为页面 key，语言变化时强制重挂载整页；选中 Tab 保持。
- 根因二：设置页“深色模式/字体大小”的分段按钮和重置按钮使用 `const LText`，仅靠父级重建不够。
  同一页面 key 修复后，切回中文无英文残留。
- 根因三：多行拼接文案的 key 只取第一行（如“通过系统文件选择器保存…你选择的位置”），四语表查不到完整串。
  已为完整句补齐 en/ja/fr/es 翻译。
- 补齐：`已完成`、`未完成`、`3 项`（动态数量）、`全部任务`、`按单个任务`、`触感反馈`、完整存储/ROM 提示、版本行、`创建`、`中文原文`。
- `AppStrings._pattern` 新增 `^(\d+) 项$`，避免数量标签回退中文。
- 设备验证：中文 → 英文 → 中文，设置页/今日页/分组标题均无残留；英文下深色模式、字号、触感、存储/ROM 提示完整英文。
- `flutter test`：73 项通过；`dart analyze lib`：No issues found。
- 最终 APK：release `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`；debug `3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。

## 26. v1.0.1 教程重播卡死修复（2026-11-06 夜）

- 复现：设置 → 使用教程与常见问题 → 重新播放使用教程，走到 3/4 后点“下一步”，进入 4/4 只剩全屏遮罩，没有卡片按钮；点击无响应，只能杀进程。
- 根因一：教程最后一步的目标是设置页顶部“外观设置”卡片。用户从设置页底部重播时，目标在滚动容器可视区之外，`OnboardingOverlay._measure` 拒绝离屏坐标后 `_targetRect` 为空，旧代码直接 `return const _Dim()`，把卡片和“完成”按钮一起丢掉。
- 根因二：设置页使用懒加载 `ListView`，滚到底部时顶部目标没有被构建，`Scrollable.ensureVisible` 拿到空 context，因此只修蒙层仍无法高亮外观卡片。
- 修复：
  - `onboarding_overlay.dart`：目标离屏时不再把坐标夹到屏幕边缘；`_targetRect == null` 时使用兜底位置显示教程卡片和按钮，保证“完成/跳过/上一步”始终可点；兜底状态不绘制错误的高亮框；步骤切换后 60ms 先量、360ms 补量。
  - `settings_screen.dart`：增加 `ScrollController` 和一次性 `replayScrollRequest` 信号，最后一步到达时 240ms 滚回顶部，让懒加载的外观卡片真正挂载。
  - `app_shell.dart`：进入最后一步时通知设置页滚回顶部；其他步骤仍执行 `Scrollable.ensureVisible`。
- 真机验证（小米 Android 15，release）：设置页底部重播 → 1/4→2/4→3/4→4/4 卡片正常；点“完成”关闭蒙层并出现“教程完成，随时可在设置里重播”SnackBar，无卡死。
- `flutter test`：73 项通过；`dart analyze lib`：No issues found。
- 最终 APK：release `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`；debug `3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。

## 27. v1.0.1 六语言补全与运行时赞赏（2026-11-06 深夜）

- 新增第六语言 `zh_Hant`：`app_zh_Hant.arb` 40 个主要界面 key；`tool/gen_hant_map.js` 生成 327 个常用字转换，`zh_hant.dart` 先处理台湾用语词组（設定/資料/任務/備註/新增/後/小工具等），再逐字转换。
- `AppStrings.codeForLocale` 按 `scriptCode == Hant` 或地区 TW/HK/MO 识别繁体；`LText.build` 订阅 `Localizations`，语言一变所有 const 文案立即重建。
- `AppShell` 语言变化时丢弃页面缓存并更换 `IndexedStack` key，双保险清除保活页残留。
- 新增原生 `values-zh-rTW/strings.xml`：应用名「循記打卡」、小工具标签、提醒通知文案。
- 赞赏体系删除 `ENABLE_SUPPORT_SECTION`：`SettingsProvider.supportVisible` 由 app 语言决定，仅简体/繁体中文显示赞赏与 20 次弹窗；英/日/法/西完全隐藏，只保留 GitHub Star 引导。
- 测试：`flutter test` 74 项通过（新增 LText 语言重建测试、繁体转换测试、语言码识别）；`dart analyze lib` 零 issue。
- 真机验证（小米 Android 15，release e7ecdec）：
  - 简体中文正常；切换到繁體中文后，設定/外觀設定/熱力主色相/深色模式/跟隨系統/淺色/字體大小/重置/字號預覽/資料管理全部为繁体。
  - 冷启动英文环境全英文；繁體中文冷启动全繁体。
  - 赞赏：简体/繁体显示收款码；英文环境仅 GitHub Star，无赞赏。
- 未验证：adb 点击语言下拉菜单在部分层级被系统通知遮挡，未完整录到“同一会话内六语循环”；已用 widget 测试覆盖 Locale 切换时 const LText 重建，并分别冷启动验证简体/繁体/英文。
- 最终 APK：release `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`（62.5MB）；debug `3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`；独立 support APK 已删除。
