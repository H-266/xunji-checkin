# 循记打卡隐私政策 / Privacy Policy

更新日期：2026-11-06　版本：1.0.0

## 中文

### 1. 我们收集什么

循记打卡是纯离线工具。我们不收集、不上传、不出售任何个人信息；没有账号系统、没有云端同步、没有广告 SDK、没有统计分析 SDK，应用也没有申请网络权限。

### 2. 数据保存在哪里

任务、打卡、备注、标签、设置和自动备份索引保存在应用私有目录的 SQLite 数据库。只有你主动使用系统文件选择器导出时，数据才写入你指定的本地文件；自动备份也只写入你通过系统文件选择器授权的目录。

### 3. 权限与用途

- 通知权限（POST_NOTIFICATIONS）：仅在你为任务开启提醒时申请，用于本地打卡提醒。拒绝后其他功能仍可用。
- 文件访问：全部通过 Android 系统文件选择器（SAF）完成，不申请存储权限。
- 应用不申请网络、定位、通讯录、相机、麦克风、精确闹钟、开机自启等权限。

### 4. 你的控制权

你可以随时修改或删除任务、打卡、标签和备注；可以在回收站恢复或永久删除；可以导出 JSON 备份；卸载应用会删除应用私有目录中的全部数据。

### 5. 第三方组件

应用使用 Flutter、sqflite、provider、home_widget 等开源组件，均在本机运行。home_widget 依赖中的 WorkManager 权限已在 Manifest 中移除，应用不使用后台联网任务。

### 6. 儿童与敏感信息

应用不面向儿童单独收集信息，也不要求填写身份、联系方式或健康数据。请不要在任务标题、备注或备份文件中写入你不希望留在本机的敏感信息。

### 7. 政策变更与联系

政策变更会在新版本的应用内更新本页，并在更新日志中说明。本项目为开源软件，问题与建议请通过仓库 Issues 反馈。

## English

### 1. What we collect

Xunji Check-in is an offline-only tool. We do not collect, upload, or sell personal information. There is no account, cloud sync, advertising SDK, analytics SDK, or network permission.

### 2. Where data is stored

Tasks, check-ins, notes, tags, settings, and the local backup index are stored in the app-private SQLite database. Data leaves the app only when you explicitly export it through the Android system file picker, or when automatic backup writes to the directory you authorized through SAF.

### 3. Permissions

- POST_NOTIFICATIONS is requested only when you enable a task reminder and is used solely for local notifications. Other features remain available if you deny it.
- File access uses the Android Storage Access Framework. The app does not request storage permission.
- No network, location, contacts, camera, microphone, exact-alarm, or boot permissions are requested.

### 4. Your control

You can edit or delete tasks, check-ins, tags, and notes at any time; restore or permanently delete items from the recycle bin; export a JSON backup. Uninstalling the app removes all data in its private directory.

### 5. Third-party components

The app uses open-source Flutter, sqflite, provider, and home_widget components, all running locally. Unused WorkManager permissions pulled in by home_widget are explicitly removed from the manifest.

### 6. Children and sensitive data

The app does not knowingly collect information from children and does not require identity, contact, or health data. Do not put sensitive information in task titles, notes, or backup files unless you accept that it remains on your device.

### 7. Changes and contact

Material policy changes will be published in-app with a new release and noted in the changelog. This is an open-source project; please use the repository Issues for questions.
