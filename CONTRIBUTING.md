# 贡献指南

感谢你愿意改进循记打卡。这个项目优先保证三件事：**纯离线、数据不丢、统计口径一致**。

## 开始之前

- Flutter 版本：3.47.9（Dart 3.13.7）。
- Android SDK：compileSdk 36，targetSdk 34，minSdk 26。
- 不要引入网络请求、账号、云同步、广告、统计 SDK 或危险权限。
- 文件读写必须走 Android SAF，不申请存储权限。
- 修改统计、周期、导入导出逻辑时，先补单元测试，再改实现。

## 本地构建

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Windows 下若项目位于中文路径，release AOT 可能失败。可临时映射盘符：

```powershell
subst X: "E:\path\to\stage12"
cd X:\
flutter build apk --release
subst X: /d
```

正式签名包请复制 `android/key.properties.example` 为 `android/key.properties`，填写自己的 keystore。该文件不得提交。

## 提交规范

- 一个 PR 只做一件事；性能改动请附设备、场景、前后帧耗时。
- 不要用“看起来更快”代替数据；未达标请如实写进 `docs/TEST_REPORT.md` 或 PR 描述。
- 新增用户可见文案必须同时补 `lib/l10n/app_*.arb` 与必要的 `AppStrings` 兜底；不要只写中文。
- 任何数据库字段变更都要写 migration，并在 `test/` 增加旧版本升级测试。
- 不要提交 `build/`、`.dart_tool/`、`dist/`、keystore、`key.properties` 或本机绝对路径。

## 问题反馈

请使用 `.github/ISSUE_TEMPLATE/bug_report.yml`，至少提供：

- 设备型号、Android 版本、系统语言；
- App 版本（设置页底部 / APK 名）；
- 复现步骤、预期结果、实际结果；
- 是否开启“减少动画”、深色/浅色、字体缩放；
- 如涉及数据，请先自行脱敏，不要上传真实备份文件。

## 开源协议

提交即表示同意以 MIT License 发布你的贡献。
