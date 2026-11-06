# 循记打卡 · 1.0.1 正式发布版

纯离线 Flutter 打卡 App，只做 Android。一个格子代表一天的热力月历是核心；每日打卡、一次性待办、周期计划、标签、提醒、桌面卡片、统计、备份与恢复都在本工程内完成。

- **阶段 1**：每日打卡 / 临时待办、跨天自然重置、软归档、今日完成率。
- **阶段 2**：单日一格热力月历、月平均 / 全勤 / 有完成的天、日详情弹窗、左右切月。
- **阶段 3**：打卡任务卡片 + 热力日历卡片，`home_widget` 数据桥，Canvas 位图渲染，00:02 非精确刷新，第三 Tab「小组件」。
- **阶段 4**：全局更名「循记打卡」、深蓝品牌主题与图标、设置页、JSON 导出、电池优化 / 自启动引导。
- **阶段 5**：周期计划 / 标签 / 备注 / 单任务连续统计 / 本地提醒；年度热力图、高级统计、拖拽排序、归档回收站、JSON 导入；四步新手引导与 FAQ。
- **阶段 6**：补卡、滑动操作、待办截止日、任务搜索、批量管理、生效日提醒、Canvas 趋势图、自动备份、标签维度热力图、全局全勤、长图保存、数据库自检、更多 ROM 引导、极简卡片与热力 2×2。
- **阶段 7**：热力图日详情直接补/取消打卡、任务置顶、完成时间与备注编辑、记住上次任务类型、完成待办自动归档；环比 / Top5、六套主题预设、按标签绑定桌面卡片、CSV 导出、1×1 迷你进度卡片；Android 14/15 通知分组、错误日志、批量回收站。
- **阶段 8**：自定义重复周期（每日 / 每周目标 / 自定义星期 / 间隔天数 / 每月日期 / 每年日期）、非生效日统计口径统一；标签 / 类型 / 时段 / 周期表现拆解与标签汇总 CSV；五语言资源（中文兜底、英日法西）、214 条正文/弹窗文案表、设置页语言切换；表单属性、菜单项与引导文案也已接入；长帮助/FAQ 与少量动态错误串仍保留中文兜底，详见“多语言现状”。
- **阶段 9**：性能专项。今日任务行独立重绘、年度热力图按周懒构建、热力月网格/进度环绘制隔离、今日/月统计按数据版本缓存、冷启动 IO 延后、统一 150/220/300ms 动效与系统“减少动画”降级；业务逻辑与统计口径未改。
- **1.0.0 发布闭环**：首次启动隐私同意门、应用内隐私政策与权限说明、正式签名脚本、商店元数据/图标/banner/截图、MIT License、README/CHANGELOG/CONTRIBUTING/Privacy/Issue 模板；多语言资源持续完善。
- **1.0.1 六语言与运行时赞赏**：简体中文、繁體中文（臺灣用語）、English、日本語、Français、Español；原生 `values-zh-rTW` 应用名/小工具/通知；赞赏板块按 App 语言运行时显示，不再有独立 support APK。

工程位于 `stage12/`，与仓库根目录下的旧四阶段版本相互独立。

> 发布状态：**可本地安装的正式签名测试版；简体/繁体/英文已真机全页验收，日/法/西已翻译但未逐页截图**。请先阅读 `docs/TEST_REPORT.md` 的已知问题，再决定是否上架。

| 项 | 值 |
| --- | --- |
| 应用名 | 循记打卡 |
| 包名 / applicationId | `com.xunji.checkin` |
| 数据库 | `xunji_checkin.db`（应用私有目录） |
| deep link | `xunji://` |
| minSdk | 26（Android 8.0） |
| targetSdk | 34 |
| 默认主题 | 深色，色相 220° 深蓝，字体 1.00 |
| 桌面卡片 | 循记打卡-任务、循记打卡-热力 |

## 功能

### 今日打卡

- 每日固定任务：每天都要做；完成状态按 `(task_id, 日期)` 存在 `checkins` 表，跨天只是日期 key 变了，**不会在零点批量重置数据库**。
- 临时待办：一次性任务，勾选后从今日列表消失；完成日仍计入当天热力统计，历史不会被抹掉。
- 支持每日、每周目标、自定义星期、间隔天数、每月多选日期、每年固定日期六种计划；所有周期共用同一口径：非生效日不计入当天任务总数，也不拉低完成率。
- 每月 29–31 日遇到短月自动跳过；每年 2 月 29 日只在闰年生效；间隔天数从任务创建日起算。
- 任务编辑页的「重复周期」二级面板提供隔天、工作日、每月 1 号、每年今天等常用模板；主列表不展示周期标签。
- 任务详情会列出完整周期规则和近期生效日期。
- 任务可设置标签、每日提醒、拖拽排序；长按或点右侧菜单可看统计、编辑、归档。
- 打卡后可写当天备注；备注存进 `checkins.remark`，并出现在热力图日详情和 JSON 备份里。
- 每日任务支持长按「补卡」：选创建日到今天之前的任意一天，可加备注，补卡与当天打卡共用同一张 `checkins` 表。
- 任务行支持左右滑动：右滑编辑，左滑归档（二次确认）；长按菜单仍然保留。
- 临时待办可设截止日；截止日当天仍计入，逾期未完成会弱提示，可一键「延期一天」或归档。
- 下拉今日页打开全屏搜索，按标题模糊匹配所有未归档任务，可直接勾选或查看详情。
- 右上角「批量管理」可多选任务，一次改标签 / 提醒 / 周期，或批量归档；数据库事务保证全成或全败。
- 顶部圆环展示今日完成率；全部完成时给一次轻提示 + 重震动。临时待办完成仍可 6 秒内撤销。
- 热力图日详情中，直接点任务行即可补卡或取消（今天及过去日期），并可就地编辑完成时间/备注。
- 长按任务可置顶/取消置顶；置顶任务固定排在最前，仍可拖拽调整顺序。
- 新建任务会记住上次类型，标题自动聚焦，回车直接创建；标题上限 30 字。
- 设置 → 通用设置可开启“完成待办自动归档”，按 3/7/14/30 天软归档，仍可从回收站恢复。

### 热力统计

- 一个格子 = 一天；颜色固定同一色相，只改变饱和度/浓度。
- 0% 或当天无任务：浅底色；完成率越高颜色越浓；100% 饱和度拉满并加高亮描边。
- 月指标：月平均完成率、全勤天数、有完成的天。
- 点过去/今天格子弹出当天日期、完成数/总数、完成率和逐任务明细；未来日期灰显且不可点。
- 支持左右滑动或箭头切月，回到本月。
- 顶部标签筛选只影响热力图统计；默认「全部」保持全局视图，全局格子仍是 App 的核心。
- 顶部显示全局「连续全勤」天数；没有任务的日子不打断全勤。
- 右上角可打开年度热力图（GitHub 风格、按年切换、点月份跳回月视图）和高级统计（累计天数、最长连续、12 周柱状 + 30 天折线、本月/上周环比与 Top5，全部 Flutter Canvas 手绘）。
- 高级统计页新增四块维度拆解：标签累计/平均/连续排行、每日与待办的类型对比、24 小时打卡时段分布、最长全勤/最长空窗/最佳月份/平均完成率；全部与热力图同源。
- 右上角菜单可把本月或全年热力图保存为 1080px 宽长图（SAF，无存储权限），带指标和「循记打卡」水印。

### 设置

1. **外观**
   - 色相滑杆 0–359° + 六套专业预设：暗夜蓝 / 森绿 / 赭石 / 莫兰迪粉 / 深空灰 / 落日橙；改色同步热力格子、进度环和桌面卡片。
   - 跟随系统 / 浅色 / 深色三档。
   - 字体大小 0.85–1.30，实时预览；只影响 App 文本，不影响桌面卡片。
2. **数据**
   - 通过系统文件选择器（SAF）导出 / 导入 JSON，不申请存储权限。
   - 导入先校验，再选择「覆盖」或「追加」；追加会重新映射任务/标签 id，不破坏原数据。
   - 支持导出 CSV（打卡明细 / 每日统计 / 任务汇总 / 标签汇总 / 周期汇总），均通过 SAF 保存；表头与字段名固定英文，便于跨语言导入表格软件。
   - 自动备份默认关闭；可选每周 / 每两周 / 每月，选择 SAF 目录后按保留份数清理最旧备份。
   - 标签管理、归档回收站（支持多选批量恢复 / 永久删除）也放在这一组。
   - 错误日志只记录崩溃、数据库与导入导出异常；可查看、导出或清空，不上传。
3. **保活**
   - 读取真实电池优化忽略状态。
   - 一键打开系统电池优化设置。
   - 尝试打开小米 / 华为 / 荣耀 / OPPO / realme / vivo / iQOO / 一加 / 魅族 / 三星自启动管理；失败则回退到本应用详情页。
   - 附国产 ROM 的中文说明，并解释小组件 / 提醒被系统清理时的表现。
4. **语言与教程**
   - 语言默认跟随系统；支持简体中文（兜底）、English、日本語、Français、Español，切换后立即生效。
   - Flutter 侧已接入 `flutter_localizations` + ARB，并维护 214 条正文/弹窗文案的六语言表；Android 侧 `values-en/ja/fr/es` 覆盖应用名、桌面卡片名和通知文案。
   - 桌面卡片 Canvas 文案已接入语言字段：标题、空状态、页脚、最近 4/8 周、月均、完成率说明和日期格式会跟随当前 App 语言。
   - 当前版本已覆盖四个 Tab、页面标题、设置分组、主要按钮、空状态、菜单与 214 条正文文案；`InputDecoration` 属性、菜单、引导与主要动态文案已接入语言表；长帮助/FAQ 段落与图表注释仍有中文回退，尚未达到“零硬编码”标准。
   - 设置底部可重播四步新手引导，并查看打卡重置、卡片刷新、备份、通知等 FAQ。
   - 启动时做一次数据库完整性自检；发现孤立打卡/非法日期等问题时弹窗，可一键修复或去恢复备份。

## 运行

```powershell
# 在 stage12 目录下执行

# 依赖
..\tool\flutter.bat pub get

# 测试
..\tool\flutter.bat test

# 静态检查（中文路径下分析器有 bug，见文末）
..\tool\flutter.bat analyze

# debug APK
..\tool\flutter.bat build apk --debug

# release APK（中文路径下 AOT 可能失败，见文末）
..\tool\flutter.bat build apk --release
```

如果本机已经能直接执行 `flutter`，把 `..\tool\flutter.bat` 换成 `flutter` 即可。`tool/flutter.bat` 只是本机 Flutter / JDK 21 / Android SDK 的启动封装。

### 产物与安装

```text
stage12\build\app\outputs\flutter-apk\app-debug.apk
stage12\build\app\outputs\flutter-apk\app-release.apk
stage12\dist\xunji-checkin-1.0.1-debug.apk
stage12\dist\xunji-checkin-1.0.1-release.apk
```

```powershell
adb install -r "dist\xunji-checkin-1.0.1-release.apk"
```

`dist/` 里的 release 使用 `android/keystore/xunji-release.jks` 正式签名；请备份 keystore 与 `android/key.properties`。各产物的 SHA-256 见 `dist/SHA256SUMS.txt`。

## 桌面小组件

### 添加

App 第三个 Tab「小组件」提供三种卡片，并可按标签绑定：

1. **打卡任务卡片**：2×1、2×2、4×2、4×4；可切换极简列表（隐藏圆环）。
2. **热力日历卡片**：2×2、4×2、4×4。
3. **1×1 迷你进度卡片**：只显示今日完成率，只读。

任务 / 热力卡片各有一个标签选择器，选择「全部」或某个标签后添加；同一桌面可放多张不同标签的卡片。绑定结果按 `appWidgetId` 存入 SharedPreferences，刷新时优先读取对应标签的数据。

点「添加…卡片」会先同步一次 JSON，再调用 `HomeWidget.requestPinWidget()` 发起系统添加页。

部分国产桌面（尤其 MIUI / HyperOS）会吞掉系统的 `CONFIRM_PIN_APPWIDGET` 页面，表现为“点按钮没反应”。这是桌面宿主行为，不是 App 缺少权限。配置页始终保留手动添加引导：

> 长按桌面空白处 → 添加小部件 / 小组件 → 找到「循记打卡-任务」或「循记打卡-热力」→ 拖到桌面 → 拉伸到需要的尺寸。

卡片只做展示，**不支持在小组件内部勾选**；点击整张卡片会打开 App 并跳到对应 Tab：

- 打卡任务卡片 / 1×1 迷你卡片 → 今日
- 热力日历卡片 → 热力

### 尺寸行为

| 卡片 | 尺寸 | 内容 |
| --- | --- | --- |
| 打卡任务 | 2×1 | 圆环 + 今日完成数；最紧凑，不放任务列表 |
| 打卡任务 | 2×2 | 圆环 + 最多 3 条任务 |
| 打卡任务 | 4×2 | 圆环 + 最多 6 条任务，优先未完成 |
| 打卡任务 | 4×4 | 右侧圆环 + 进度条 + 最多 6 条任务 + 底部提示 |
| 热力日历 | 2×2 | 最近 4 周紧凑方格 |
| 热力日历 | 4×2 | 最近 8 周 × 7 天方格，紧凑显示 |
| 热力日历 | 4×4 | 最近 8 周方格 + 日期范围 + 说明 |

任务卡片可在「小组件」Tab 打开「极简列表」：隐藏圆环，把纵向空间全部让给任务行。任务数超过卡片容量时只绘制能放下的行，避免文字互相覆盖；所有文字都做了截断。卡片使用固定 dp 字号，不跟随系统字体缩放，避免大字号把网格撑破。

### 刷新链路

```text
App 内打卡 / 改任务 / 改色相 / 切深浅色 / 改字号
        ↓
TaskProvider / SettingsProvider notifyListeners
        ↓
AppShell 250ms 防抖
        ↓
WidgetService.updateAllWidgets()
  ├─ 写 xunji_checkin_widget_data（今日任务、完成数、百分比、hue、dark、daily、pending）
  ├─ 写 xunji_heatmap_widget_data（最近 56 天、today、hue、dark、average）
  ├─ HomeWidget.updateWidget(qualifiedAndroidName)
  └─ MethodChannel refreshWidgets → 原生显式广播
        ↓
CheckinWidgetProvider / HeatmapWidgetProvider
        ↓
WidgetRenderer 用 Canvas 画整张 Bitmap，RemoteViews 只放一个 ImageView
```

跨天：

- `AlarmManager.setAndAllowWhileIdle` 在次日 00:02 触发 `MidnightRefreshReceiver`，**不使用精确闹钟权限**。
- 打卡卡片发现 JSON 的 `date` 不是今天时，用 `daily` + `pending` 重建“每日任务全部未完成、昨日已完成待办不再出现”的新一天。
- 热力卡片按当前日期重新计算 56 天窗口，今天补 0。
- 没有申请 `RECEIVE_BOOT_COMPLETED`；设备重启后，打开一次 App 会重新安排下一次 00:02 刷新。

### 颜色

原生 `WidgetRenderer.heatColor()` 与 App 的 `AppTheme.heatColor()` 使用同一口径：

- 0% / 无任务：深色模式 `#1B2436`，浅色模式 `#E7ECF5`；
- 0~100%：固定色相，高饱和色按完成率线性提高不透明度；
- 100%：完全不透明 + 高亮描边。

色相来自 `settings.heatmap_hue`（默认 220），只用于热力格子与桌面卡片；App 外壳固定使用 220° 品牌深蓝，避免改色相后按钮、导航、SnackBar 跟着串色。

## 目录结构

```text
lib/
  main.dart
  core/
    date_utils.dart          # 纯日期函数
    stats.dart               # 纯统计核心
  models/
    task.dart                # TaskType / Task / CheckinRecord
  data/
    app_database.dart        # SQLite 单例与 CRUD
  providers/
    task_provider.dart       # 今日任务、打卡、归档、月统计
    settings_provider.dart   # 色相、明暗模式、字体缩放
  screens/
    today_screen.dart        # 今日打卡 / 补卡 / 滑动 / 搜索 / 批量入口
    heatmap_screen.dart      # 热力月历 + 标签筛选 + 长图导出
    year_heatmap_screen.dart # 年度热力图
    stats_screen.dart        # 累计 / 连击 / Canvas 趋势
    task_search_screen.dart  # 全屏任务搜索
    batch_manage_screen.dart # 批量归档 / 标签 / 提醒 / 周期
    widget_config_screen.dart# 小组件预览 / 添加 / 极简样式
    settings_screen.dart     # 外观 / 数据 / 保活 / 教程
    backup_settings_screen.dart # 自动备份目录与周期
    app_shell.dart           # 四个 Tab 的 IndexedStack 容器
  services/
    platform_service.dart    # MethodChannel：刷新、pin、电池、自启动、导入导出
    widget_service.dart      # JSON 序列化 + home_widget 刷新 + pin
    export_service.dart      # 备份 JSON 组装 + SAF
    import_service.dart      # 校验 + 覆盖/追加
    backup_service.dart      # 自动备份周期与保留份数
    heatmap_image_service.dart # 月/年热力图长图
  theme/
    app_theme.dart           # 单色相热力算法 + Material 3 主题
  widgets/
    task_tile.dart           # 标题 + 勾选框 + 逾期弱提示
    progress_ring.dart       # 今日完成率环形进度
    trend_chart.dart         # 12 周柱状 + 30 天折线（Canvas）

android/app/src/main/kotlin/com/xunji/checkin/
  MainActivity.kt            # MethodChannel、SAF 导入/导出/自动备份/长图
  reminder/
    ReminderScheduler.kt     # 本地提醒排程（非精确）
    ReminderReceiver.kt      # 通知 + 次日重排
  widget/
    CheckinWidgetProvider.kt # 打卡卡片 AppWidgetProvider
    HeatmapWidgetProvider.kt # 热力卡片 AppWidgetProvider
    WidgetRenderer.kt        # Canvas 位图渲染（所有尺寸）
    WidgetUpdateScheduler.kt # 00:02 非精确闹钟
    MidnightRefreshReceiver.kt

android/app/src/main/res/
  layout/widget_image.xml
  xml/checkin_widget_info.xml
  xml/heatmap_widget_info.xml
```

## 依赖

```yaml
provider: ^6.1.2
sqflite: ^2.4.1
path_provider: ^2.1.5
intl: ^0.19.0
home_widget: ^0.10.0
```

说明：本工程**没有引入 `flutter_localizations`**。Flutter 3.47 的 `flutter_localizations` 会把 `intl` 锁到 `0.20.3`，与需求里的 `intl: ^0.19.0` 冲突；中文文案直接写在代码里，`intl` 只用于数字日期格式 `yyyy-MM-dd`。

## SQLite 设计

```sql
tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  type TEXT NOT NULL,              -- daily / todo
  created_at INTEGER NOT NULL,     -- 毫秒时间戳
  completed_at INTEGER,            -- 临时待办专用
  archived_at INTEGER,             -- 软归档
  sort_order INTEGER NOT NULL,
  schedule_type TEXT NOT NULL,     -- daily / weekly_target / weekdays
  weekly_target INTEGER NOT NULL,
  weekday_mask INTEGER NOT NULL,   -- 周一 bit0 ... 周日 bit6
  tag_id INTEGER,
  reminder_time TEXT,              -- HH:mm
  reminder_enabled INTEGER NOT NULL,
  due_at INTEGER,                  -- 临时待办截止日
  reminder_effective_only INTEGER NOT NULL -- 仅生效日提醒
)

checkins (
  task_id INTEGER NOT NULL,
  date TEXT NOT NULL,              -- yyyy-MM-dd
  completed_ts INTEGER NOT NULL,
  remark TEXT,                     -- 当天备注
  PRIMARY KEY (task_id, date),
  FOREIGN KEY (task_id) REFERENCES tasks (id)
)

tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color INTEGER NOT NULL,
  created_at INTEGER NOT NULL
)

settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
```

普通删除只写 `archived_at`，不物理删除；归档前的 `checkins` 和任务创建日期都还在，所以历史热力图不会被破坏。只有“回收站 → 永久删除”会按用户明确确认硬删除任务及其打卡记录。数据库版本为 v3，v1/v2 数据通过 `ALTER TABLE` 原地升级。

## 核心口径

### 跨天重置

每日任务没有“完成/未完成”字段，完成状态只看：

```text
checkins(task_id, 今天 yyyy-MM-dd)
```

跨天后日期 key 变了，新的一天自然查不到昨天的打卡，所以显示为未完成。**不会在零点批量改数据库**。

### 任务有效期

- 每日任务：创建日 ~ 归档日前一天，每天都计入总数；
- 临时待办：创建日 ~ 完成日（含）计入；未完成待办只计入到今天，不会提前影响未来日期；
- 归档当天起不再计入；归档日之前的历史保持不变。

### 单日完成率

```text
完成率 = 当天完成数 / 当天有效任务数
```

当天完成的临时待办会从今日列表消失，但**仍然计入当天总数与完成数**。否则“完成待办”反而会让完成率下降，也不会有 100% 全勤。

### 月统计

- 月平均完成率：只对“有有效任务的天”求平均，避免空白日稀释；
- 全勤天数：当天有任务且全部完成；
- 有完成的天：当天至少完成 1 项；
- 当前月只统计到今天，未来日期不参与。

## JSON 备份

导出通过 `ACTION_CREATE_DOCUMENT`（SAF）完成，不申请存储权限。结构固定为：

```json
{
  "app": "循记打卡",
  "format_version": 1,
  "exported_at": "2026-11-05T12:00:00.000Z",
  "tasks": [
    {
      "id": 1,
      "title": "喝水",
      "type": "daily",
      "created_at": 1762300000000,
      "completed_at": null,
      "archived_at": null,
      "sort_order": 0,
      "schedule_type": "daily",
      "weekly_target": 7,
      "weekday_mask": 127,
      "tag_id": 1,
      "reminder_time": "08:00",
      "reminder_enabled": 0,
      "due_at": null,
      "reminder_effective_only": 0
    }
  ],
  "checkins": [
    {
      "task_id": 1,
      "date": "2026-11-05",
      "completed_ts": 1762300000000,
      "remark": "今天状态不错"
    }
  ],
  "tags": [
    {"id": 1, "name": "健康", "color": 4282351572, "created_at": 1762300000000}
  ],
  "settings": {
    "heatmap_hue": "220.0",
    "theme_mode": "dark",
    "font_scale": "1.00"
  }
}
```

导入入口在设置 → 数据管理。先完整校验 `format_version`、任务/标签/打卡引用和数量上限，再让你选择覆盖或追加；写入使用单事务，失败不会留下半套数据。文件由系统文件选择器决定位置，App 不申请外部存储权限。

自动备份同样走 SAF：在设置 → 数据管理 → 自动备份中选择一个目录并授权持久访问，之后按 7/14/30 天的周期写入 `xunji-auto-时间.json`，保留最近 5/10/20/30 份，超过后删除最旧文件。默认关闭，不会在后台偷偷执行。

## 权限

release APK 只包含：

```text
android.permission.POST_NOTIFICATIONS
com.xunji.checkin.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
```

`POST_NOTIFICATIONS` 只用于任务到点提醒，Android 13+ 首次设置提醒时才会弹出系统授权。没有 `INTERNET`、`ACCESS_NETWORK_STATE`、`WAKE_LOCK`、`RECEIVE_BOOT_COMPLETED`、`FOREGROUND_SERVICE`、存储、定位、精确闹钟权限。

`home_widget 0.10.0` 的 `androidx.work` 依赖会间接合并 4 个权限，但本工程不使用 WorkManager，已在 `AndroidManifest.xml` 用 `tools:node="remove"` 显式移除，并用 `aapt2 dump badging` 复验。

debug APK 会带 Flutter 调试所需的 `INTERNET`，这是 debug 构建的预期行为；release 没有。

## 高刷适配

`MainActivity.applyMaxRefreshRate()` 启动时读取 `DisplayManager` 的 `supportedModes`，在**同分辨率**模式中选最高刷新率并设置 `preferredDisplayModeId`。这样不会为了 180Hz 把 1440×3200 降到低分辨率。

- 本机实测 `dumpsys display`：支持 60/90/120Hz，最高 120Hz，不存在 180Hz 模式；启动后 `mActiveModeId=2`、`renderFrameRate=120.0`。
- 因此本轮**无法提供 180Hz 真机数据**，也没有虚构 180Hz 指标；所有帧数据来自 120Hz 设备。
- Android Manifest 没有“声明 120/144/180Hz”的标准属性，刷新率必须运行时选 Display Mode；这是本轮采用的方式。
- 动效继续按 150/220/300ms 时间锚定，随高刷自动增加中间帧，不改变时长。

## 多语言扫描

详见 [I18N_SCAN_REPORT.md](I18N_SCAN_REPORT.md)。扫描结果：资源骨架、主要页面/原生资源/动态文案已接入，但 `lib/` 非注释行仍有约 669 行中文（含模型默认标签、日志和兜底文案），**零硬编码验收未通过**。

## 动效与系统栏

- 系统状态栏/导航栏改为 `@android:color/transparent`，由 App 自身背景铺满；深色模式显示深蓝 `#0B1220`，浅色模式显示 `#F5F7FC`，状态栏图标由 `AnnotatedRegion` 按深浅色切换明暗。真机浅色模式截图确认不再残留深蓝顶边。
- 已接入：任务行 150ms 背景/文字过渡、Checkbox 原生过渡、空状态 300ms 淡入上移、自定义左右滑（背景颜色/图标随位移连续变化、松手 220ms 回弹）、拖拽 1.02 倍浮起、引导卡片 220ms 淡入且高亮框/卡片 220ms 移动、页面 FadeUpwards 300ms、日详情弹窗 220ms 缩放入场/150ms 出场、趋势图 300ms 自左向右揭示、教程 FAQ 220ms 展开、进度环 150/300ms、NavigationBar 指示器动画。
- 深浅色切换使用 `themeAnimationDuration: Duration.zero`：`AnimatedTheme` 的 300ms 全局 ThemeData 插值会让整棵树每帧重建，真机表现为严重卡顿；改为一次换色，保留颜色跳变但不逐帧插值。
- 新手引导高亮改为真实 `GlobalKey` 测量：`OnboardingTargets` 绑定今日 FAB、热力月卡、小组件添加按钮、设置外观卡；等 FAB 入场位移结束后（420ms）再取 `RenderBox` 相对遮罩的位置，步骤 1/2/3 已真机截图核对，高亮框与控件对齐。
- 所有二级菜单/弹窗统一入口：`showAppDialog` 220ms 淡入 + 0.96→1 缩放；`showAppSheet` 系统 250ms 上滑 + 内容 220ms 淡入/8px 上移。顶部“更多”、标签管理、热力图导出、任务行操作均改为底部动效面板，不再使用无容器过渡的 PopupMenu；系统“减少动画”时统一归零。
- 备注：`DropdownButton` / `showDatePicker` / `showTimePicker` 使用 Flutter/Material 自带菜单与页面动画，不再叠加自定义时长，避免双动画。
- 系统「减少动画」：自定义动效归零；页面转场直接返回 child；主题过渡 0ms。
- 未接入：列表增删高度收缩、pin 排名移动补间、回收站行移除收缩。原因是 Sliver 列表增删需要改数据源/AnimatedList，pin 移动需要稳定 key 的补间布局；已完成的滑动手势、图表揭示、弹窗、教程展开、引导移动见上。
- Tab 整页淡入/位移实测两轮均掉帧（8.56/8.95ms，31–38% 超 8.33ms），按纪律降级为保活 + 无整页过渡。

## 真机性能记录（Profile）

设备：Xiaomi 2304FPN6DC，Android 16，1440×3200，最高 120Hz。数据：100 条每日任务。采样入口 `lib/bench_main.dart`（仅本地 profile 使用，不进入 release）。

- 冷启动 `am start -W`：首次安装后 826 / 900 / 913 / 943 ms；稳定复测 445 / 379 / 394 ms（100 条任务，系统缓存已热）。
- 今日页连续滚动（懒 sliver + 行级 RepaintBoundary）：1548 帧，平均 3.87 ms，最大 25.19 ms，9 帧（0.6%）超过 16.67 ms。
- 连续 20 次勾选（懒 sliver + 行级 RepaintBoundary + 150ms 行动画 + 150ms 进度环 + 300ms 合并 DB 写入）：本轮两轮采样平均 **12.83 ms / 约 70% >8.33 ms**、**13.63 ms / 约 70%**；即使临时关闭行/进度环动画仍有 10.6–12.7 ms。未达到 ≤6ms 且 <10%，按纪律停止继续盲调，不宣称达标。
- 关键根因：每次切 Tab 都在重新 build 热力/统计页。已改为 `IndexedStack` 懒加载保活：首次进入才构建，之后复用 State/滚动位置；离屏页用 `TickerMode` 暂停动画。最终热切换 60 帧平均 **4.46 ms**，最大 11.2 ms，4 帧（6.7%）超过 8.33 ms；首次打开热力页仍有约 660 ms 一次性首帧构建成本。本轮尝试给 Tab 加整页淡入/位移后平均升至 **9.33 ms / 42.9%**，已回退为无整页过渡。
- Tab 整页淡入/位移做过两轮实测：整页 Opacity 平均 8.56 ms（38.6% 超 8.33 ms），仅位移平均 8.95 ms（31.0% 超 8.33 ms），均明显掉帧。按“掉帧立即降级”纪律移除整页过渡，只保留 NavigationBar 自带指示器动画与页面状态保活。
- 勾选行动画加入 150ms 背景/文字过渡后，曾有一轮 24 帧平均 4.06 ms（8.3% 超 8.33 ms）的采样；但后续更大样本复测为 12.83/13.63 ms，说明该结果不稳定，不能作为达标依据。
- 误触修复：任务行不再整行轻点打卡，只有左侧 ≥48dp 勾选圆点触发；行本身只响应长按菜单。
- 进度环改为 `AnimationController`，从当前显示值过渡到新值，不再每次打卡从 0 重播。
- 热力页改为单月页（无全屏双 ListView 过渡）；日详情任务列表改为固定高度 `ListView.builder`，100 条任务也只构建视口附近几行，避免打开详情时一次性布局全部条目。
- 月份切换保留左右箭头；尝试过的整页横滑/淡入会与日期点击争抢手势且掉帧，已移除，优先保证点击可靠。
- 100 条任务滚动最终复测：266 帧平均 **3.70 ms**，最大 22.8 ms，1 帧（0.4%）超过 16.67 ms。
- 年度热力图左右滑动：30 帧，平均 **6.4 ms**，最大 8.62 ms，仅 1 帧超过 8.33 ms，60fps 预算内全部达标。
- 设置页色相/字体滑块改为**拖动只更新本地预览，松手 250ms 后提交全局 Provider**，拖动期间不再整页重建；未单独采集滑块帧数据。
- 深浅色切换（100 任务、120Hz）：去掉 300ms `AnimatedTheme` 插值后，开关各 4 帧，平均 **24.44–27.16 ms**、最大 **41.58–48.62 ms**，仍有 1 帧约 40ms 的整页重建；不再出现原先持续 300ms 的逐帧卡顿，但尚未做到单帧无感，未宣称“完全流畅”。
- 新手引导高亮：真机逐步截图核对，步骤 0 FAB、步骤 1 月热力卡、步骤 2 添加按钮、步骤 3 外观卡均对齐；步骤 3 卡片完整显示在屏幕内。
- 结论：滚动、年度热力图 60fps 达标；连续勾选平均耗时与 120Hz 抖动比例未稳定达标；深浅色切换仍有单帧重建。已按“最多两次优化”纪律停止继续盲调，保留真实采样数据，没有宣称“全链路 120Hz 达标”。

## 验证

- `flutter test`：**74 项全部通过**（日期/统计/周期计划/新增六种周期/间隔闰年/每月 29·31 日/每年 2 月 29 日/近期生效日/单任务连续/年度统计/待办截止日/补卡/全勤/趋势/环比/置顶/主题/组件/今日页/热力页/设置页/六语言资源加载/正文文案表键集合/长帮助/日期与导出前缀/LText 切换/语言切换强重建）。
- `flutter analyze`（ASCII 路径副本 `C:\xunji_verify17`）：`No issues found!`。
- `flutter build apk --debug`：成功。
- `flutter build apk --release`：成功，`aapt2` 校验：
  - `minSdkVersion 26`、`targetSdkVersion 34`、label `循记打卡`；
  - 包名 `com.xunji.checkin`；
  - ABIs：`arm64-v8a`、`armeabi-v7a`、`x86_64`；
  - release 只有通知权限 + 自动生成的 dynamic receiver 权限，无 `INTERNET`；
  - release 签名：`android/keystore/xunji-release.jks`（`CN=Xunji Checkin`），可直接上架；
  - release SHA-256：`e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`；
  - debug SHA-256：`3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`。
  - release 体积约 62.4MB（含三种 ABI）；正式签名需按下文配置 keystore。
- 本轮已在 Xiaomi 2304FPN6DC / Android 16（1440×3200）用 Profile 构建做首屏与 100 任务滚动采样；未做桌面卡片点击、通知到点、SAF 导入导出的逐项人工回归，相关原生行为仍以 Manifest/Kotlin 编译、系统服务查询和代码审查为准。
- 仓库根目录的旧四阶段版本曾在 Xiaomi 2304FPN6DC / Android 16 上跑过今日、热力、导出、设置等流程，但那是另一个工程，不能直接当作本工程的验证记录。

### 手工验收建议

1. 首次安装确认默认深色、色相 220°、字体 1.00，四个 Tab 文案均为「循记打卡」。
2. 新建一个每日任务和一个临时待办；勾选每日任务，确认删除线、进度环、热力当天格子同步。
3. 勾选临时待办，确认它从今日列表消失，但当天热力图仍计入。
4. 长按每日任务 → 补卡，选昨天并写备注；确认热力日详情出现该备注，取消补卡后记录消失。
5. 任务行右滑编辑、左滑归档；确认归档后今日列表消失，历史热力图不变。
6. 给临时待办设昨天的截止日，确认今日列表弱提示“已逾期”，可延期一天或归档。
7. 下拉今日页搜索任务，确认能直接勾选和打开详情；右上角批量管理多选改标签/周期。
8. 热力页左右切月，点今天/过去格子看明细；未来格子灰显不可点。
9. 热力页切换标签筛选，确认格子、月指标、日详情同步变化；切回「全部」恢复全局。
10. 打开高级统计，点 12 周柱状 / 30 天折线，确认弹出对应周/日明细。
11. 设置页改色相、切浅色/深色、拉字体到 130%，确认全局颜色、字号和热力格子同步。
12. 导出 JSON，确认系统选择器文件名 `xunji-checkin-yyyy-MM-dd.json`，结构符合上文字段；再导入并分别测试覆盖 / 追加。
13. 设置 → 数据管理 → 自动备份，选目录并设 7 天 / 保留 5 份，点“立即备份”；确认目录出现 `xunji-auto-*.json`。
14. 添加打卡卡片到桌面，分别拉到 2×1、2×2、4×2、4×4，确认文字不重叠；打开极简列表开关，确认圆环隐藏。
15. 添加热力卡片，确认 2×2 / 4×2 / 4×4 都不溢出、周一在第一列、今天有描边。
16. 点卡片任意位置，确认打开 App 且停在今日 Tab；热力卡片进入热力 Tab。
17. 在 App 内勾选任务，返回桌面确认卡片立即刷新，勾选状态与今日页一致。
18. 在设置页看电池优化状态，点两个按钮确认能跳到系统页或应用详情。
19. 用 `adb shell dumpsys appwidget` 确认两个 Provider 都已注册。
20. 把系统日期改到第二天（或等 00:02 闹钟），确认每日任务全部回到未完成，热力卡片今天补 0。
21. 热力图日详情点任务行补卡/取消，确认今日列表、进度环和格子同步；改完成时间/备注后刷新仍保留。
22. 长按任务置顶，确认排到最前；再取消置顶，顺序恢复。
23. 新建任务时不选类型，确认自动沿用上次类型；输入标题回车直接创建。
24. 设置 → 通用设置开启自动归档（3 天），把待办完成时间改到 4 天前，重启 App 后确认进入回收站且可恢复。
25. 高级统计确认本月/上周环比与 Top5；切换主题预设，确认进度环、热力格子、卡片颜色同步。
26. 小组件页选择某标签后添加卡片，确认卡片只显示该标签数据；添加 1×1 卡片确认只显示百分比。
27. 设置 → 数据管理导出三种 CSV，并用表格软件打开确认中文/时间/备注无乱码。
28. 回收站多选恢复/永久删除；错误日志页查看、导出、清空均正常，权限列表仍只有通知。

## 中文路径说明

Flutter 3.47 的 analysis server 在中文路径下会抛：

```text
FormatException: Unterminated string ...
analysis server exited with code 255
```

这是分析器 JSON 路径编码 bug，不是代码错误。验证时把 `lib/`、`test/`、`pubspec.yaml` 复制到 ASCII 路径（例如 `C:\xunji_verify`）后执行 `flutter analyze` 即可。debug 构建不受影响。

release 的 AOT 阶段在中文路径下还可能报：

```text
Unable to read file ... app.dill
AOT snapshotter exited with code 255
```

稳定做法是临时映射一个 ASCII 盘符，构建后删除：

```powershell
subst X: "%CD%"
cd /d X:\
"D:\flutter\bin\flutter.bat" build apk --release
subst X: /d
```

## 隐私与合规

- 首次启动展示隐私同意门，默认不勾选；未同意不进入主界面、不读取任务数据。
- 应用内「设置 → 隐私政策与权限说明」可查看完整中文/英文政策；仓库同文见 `PRIVACY.md`。
- 权限只有通知：仅在用户开启任务提醒时申请；无网络、存储、定位、通讯录、相机、麦克风、精确闹钟、开机自启。
- 文件导入/导出/备份/长图全部走 Android SAF，不申请存储权限。
- 商店 Data safety 可按“不收集、不共享”填写；详细文案见 `docs/STORE_LISTING.md`。

## 正式签名

仓库已生成本地 release keystore；`android/app/build.gradle.kts` 会读取 `android/key.properties`。上架前请先备份：

```powershell
copy android\key.properties.example android\key.properties
# 编辑 key.properties，填写自己的 jks / alias / 密码
powershell -ExecutionPolicy Bypass -File tool/build_release.ps1
# 若 flutter 不在 PATH：
# powershell -ExecutionPolicy Bypass -File tool/build_release.ps1 -FlutterPath "C:\flutter\bin\flutter.bat"
```

脚本依次执行 analyze、test、release/debug 构建、复制到 `dist/`、生成 `SHA256SUMS.txt`。中文路径下会自动 `subst` 到 `X:`，结束后释放。`key.properties`、`*.jks`、`dist/` 已加入 `.gitignore`，不要提交。

> 当前 release 已使用 `CN=Xunji Checkin` 正式签名；请备份 keystore 与 `key.properties`，否则无法覆盖升级。

## 开源与素材

- `LICENSE`：MIT。
- `PRIVACY.md`：中英双语隐私政策。
- `CHANGELOG.md`：1.0.0 功能、修复、性能与已知限制。
- `CONTRIBUTING.md`：构建、提交、隐私与测试要求。
- `FAQ.md`：安装、权限、数据、小组件、多语言与构建常见问题。
- `docs/ARCHITECTURE.md`：分层、统计口径、数据库版本。
- `docs/TEST_REPORT.md`：真机性能/动效/原生验证与未达标项。
- `docs/RELEASE_CHECKLIST.md`：上架前检查清单。
- `docs/STORE_LISTING.md`：中文/英文商店文案、关键词、素材清单。
- `store/icon-512.png`、`store/banner-1024x500.png`、`store/screenshots-1080x2400/01–05`：512 图标、1024×500 banner、1080×2400 商店截图。
- `.github/ISSUE_TEMPLATE/`：Bug / 功能建议模板。

## 已知限制

- **六语言覆盖**：591 条用户文案已翻译为英/日/法/西；`zh_Hant` 由 ARB + 台湾用语转换器覆盖全部可见文案，简体/繁体/英文已真机全页验收；日文仅保留同形汉字与日期兜底。赞赏板块按 App 语言运行时显示/隐藏，无独立 APK。
- **原生标签同步**：Android 13+ 通过 per-app locale 同步应用名/通知/小工具标签；Android 8–12 无系统 per-app locale API，App 内文案正常切换，但桌面原生标签仍跟随系统语言。
- **新手引导交互锁止**：已用 `AbsorbPointer` 锁底栏、遮罩吸收非目标点击、`PopScope` 阻止返回；代码级与 74 项测试通过，完整四步真机点击流程仍建议人工复核。
- **连续勾选性能未达标**：120Hz、100 任务实测平均 12.8–13.6ms，超 8.33ms 约 70%；未达到 ≤8ms/<20%。
- **主题切换**：最坏 35.65ms，未达到 ≤30ms；跨帧拆分实验更差，已回退。
- **SAF / 小组件宿主**：Dart 通道与 8 尺寸位图已验证；系统选择器逐项操作、桌面逐尺寸添加/裁剪/杀进程仍需人工授权复测。
- **商店截图**：1080×2400 五张，含演示数据；正式上架前请替换为干净数据并复核各商店规范。
- 桌面卡片只做展示，点击整卡进入 App 打卡；这是为了避免 Android 桌面端 RemoteViews 的交互兼容性问题。
- 部分国产桌面会拦截 `requestPinAppWidget`；请按配置页的中文手动添加引导操作。
- 没有申请开机广播，重启后需要打开一次 App 恢复 00:02 刷新；这是为了满足“不申请多余权限”的硬约束。
- 自动备份在 App 启动 / 回到前台时检查周期并执行，不做后台定时任务；这样不需要 WorkManager、精确闹钟或额外保活权限。
- 本地提醒由 `AlarmManager` 非精确触发，系统省电策略可能延迟几分钟；国产 ROM 需按设置页说明关闭电池优化。
- release 已使用本地 keystore 正式签名；公开仓库时不要提交 keystore 与 `key.properties`。
- 旧四阶段版本在仓库根目录，与本工程数据、包名、数据库完全独立。

## v1.0.1 标签与热力单维筛选

- 标签支持置顶、重名/空名/超长校验、删除后任务自动解绑；今日/热力/统计共用同一筛选状态。
- 热力月历、年历与统计页统一筛选面板：全部任务 / 按标签 / 按单个任务；单任务筛选不影响今日页打卡口径。
- 新增触感反馈开关（默认开启），关闭后打卡不触发系统触感；自定义勾选动画 150ms，跟随“减少动画”降级。
- 测试：73 项通过（新增 4 项标签模型测试与 1 项语言切换强重建测试）。

## v1.0.1 多语言完整性修复

- 设置页、今日页、热力/统计/小组件页在语言切换时按 `Localizations.localeOf(context)` 换页 key，并让 `LText` 在 build 中订阅 `Localizations`，强制重建常量文案，切回中文不再残留英文。
- 六种语言：简体中文、繁體中文（臺灣用語）、English、日本語、Français、Español。
- 补齐完整多行 key（系统文件选择器/国产 ROM 提示）、`已完成`/`未完成`、动态数量 `N 项`、`全部任务`/`按单个任务`、`触感反馈`、版本行等中英日法西翻译。
- `AppStrings._pattern` 新增纯数量标签模式，避免 `3 项` 回退中文。
- 繁体转换：`tool/gen_hant_map.js` 生成常用字表，`lib/core/zh_hant.dart` 做词组优先的台湾用语转换；`lib/l10n/app_zh_Hant.arb` 覆盖 40 个主要界面 key。
- 原生 `values-zh-rTW/strings.xml`：应用名「循記打卡」、小工具标签、提醒通知文案。
- 真机已验证：中文 → 英文 → 中文，设置页分段按钮、重置、存储/ROM 提示均无残留；繁体、英文、日文、法文、西班牙文页面与关于页完整显示。
- 审计脚本：`tool/i18n_audit.js`（键覆盖）与 `tool/i18n_literals.js`（源码汉字常量）可重复运行；剩余未命中仅为运行时拼接模板，由 `_pattern` 覆盖。

## v1.0.1 图标重做与赞赏体系

### 新图标

- 方案 A 入选：深蓝渐变底 + 白色勾选 + 2×2 热力方格；两套候选图在 `store/icon-proposals/`。
- 已覆盖：`store/icon-512.png`、`mipmap-mdpi..xxxhdpi` 的 `ic_launcher.png` / `ic_launcher_round.png`、自适应前景 `drawable-nodpi/ic_launcher_foreground.png`、1024×500 Banner。
- 通知栏使用独立纯白剪影 `drawable/ic_notification.xml`，透明背景，`ReminderReceiver` 已从桌面图标切换为该资源。

### 赞赏体系（运行时语言自适应）

- 不再使用 `ENABLE_SUPPORT_SECTION` 编译开关，只构建一个 APK。
- 赞赏板块与 20 次启动弹窗由当前 App 语言决定：`languageCode == 'zh'`（简体或繁体）时显示；英/日/法/西完全隐藏，只保留 GitHub Star 引导。
- 判断基于 `Localizations.localeOf(context)`，随设置内语言即时切换，无需重启。
- 关于页「联系与反馈」全语言常驻：QQ 邮箱 `3698910396@qq.com`、Outlook `dazuo03@outlook.com`。点击行通过原生 `mailto:` 唤起系统邮件应用并自动填充收件人；右侧复制按钮只写入剪贴板，不申请通讯录/网络权限。
- 启动计数：`support_launch_count`，本地计数；20 次触发，勾选「不再提示」永久关闭，「下次再说」下次阈值 100。
- 项目主页常量 `projectUrl` 当前为 `https://github.com/xunji-checkin/xunji-checkin`，发布前请改成真实仓库地址。

### v1.0.1 最终产物

- release：`dist/xunji-checkin-1.0.1-release.apk`，62.5MB，SHA-256 `e7ecdec92812a8c81acc1273b7928f0951730060814e369391ddd04564682c8b`
- debug：`dist/xunji-checkin-1.0.1-debug.apk`，SHA-256 `3d63a8bcb1d18c8898cd528dc42416b7a8ac780f5d81c6fe5c2427e9625c6a18`
- 已删除独立 support APK；赞赏内容由运行时语言控制。
- 正式包冷启动实测 565 / 406 / 413ms（安装后首启含 dex 优化，后两次更稳定）。
- 已真机验证：简体、繁体、英文界面；繁体标签、深色模式分段按钮、字体大小与关于页全量转换；英文环境无赞赏板块；中文赞赏收款码并排显示、点击可放大；第 20 次启动弹窗出现。
- 未验证：通知栏实际到点通知的小图标视觉（已通过资源/代码审查与编译，未在通知栏截到该条）；自适应图标在不同桌面（尤其 MIUI 主题）下的最终裁切。
