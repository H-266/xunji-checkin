# 发布检查清单

## 1. 代码与测试

- [ ] `flutter pub get`
- [ ] `dart format lib test integration_test`
- [ ] `flutter analyze` 零 issue
- [ ] `flutter test` 63 项通过
- [ ] `git status` 无 `build/`、`.dart_tool/`、`dist/`、keystore、`key.properties`
- [ ] 源码与 APK 不含 `laodeng` / `老登` 残留
- [ ] 版本号：`pubspec.yaml` 为 `1.0.0+1`

## 2. 签名与包

- [ ] 复制 `android/key.properties.example` 为 `android/key.properties`
- [ ] 填写 release keystore（不要提交）
- [ ] `powershell -File tool/build_release.ps1`
- [ ] 确认 `apksigner verify --print-certs` 显示正式证书，不再是 `CN=Android Debug`
- [ ] 确认 `aapt2 dump badging`：包名 `com.xunji.checkin`、minSdk 26、targetSdk 34
- [ ] 确认权限仅 `POST_NOTIFICATIONS` + dynamic receiver
- [ ] 校验 `dist/SHA256SUMS.txt`

> 仓库默认没有 keystore 时，`build.gradle.kts` 会回退 debug 签名；这只用于本地安装，**不能上架**。

## 3. 隐私合规

- [ ] 首次启动弹出隐私同意门，默认不勾选，未同意不能进入
- [ ] 应用内可打开完整隐私政策（中文/英文）
- [ ] 权限说明页与实际权限一致：仅通知
- [ ] 商店隐私表单填写“不收集/不共享”
- [ ] 隐私政策公开链接可访问（如使用仓库 raw / Pages 地址）

## 4. 真机冒烟（至少一台 Android 13+ 和一台 Android 8–11）

- [ ] 安装 release，首次启动隐私门
- [ ] 新建每日/临时任务、勾选、补卡、备注、编辑、归档、恢复
- [ ] 月/年热力、标签筛选、年度切换
- [ ] 统计页趋势、Top 5、时段
- [ ] 通知权限拒绝/同意、单次提醒
- [ ] JSON 导出/导入、CSV、长图、自动备份
- [ ] 小组件 1×1/2×1/2×2/4×2/4×4 添加与点击
- [ ] 深浅色、系统大字体、横屏、语言切换
- [ ] 杀进程重启数据保留
- [ ] 厂商电池/自启动跳转或 app-details 兜底

## 5. 商店素材

- [ ] 512×512 图标
- [ ] 1024×500 banner
- [ ] ≥5 张 1080×1920 截图（中文/英文各一套）
- [ ] 应用描述、短描述、关键词、更新日志
- [ ] 分类：效率/工具
- [ ] 隐私政策 URL、开发者主体、版权信息

## 6. 已知限制（发布说明中保留）

- 连续勾选性能未稳定达到 120Hz ≤6ms / <10%。
- 用户可见文案仍有中文兜底，五语言未全量完成。
- 小组件未逐尺寸真机截图验收。
- 通知在部分厂商杀进程后的送达未逐型号验证。

以上未达标项不得在商店描述中宣称“完全流畅”或“全量五语言”。
