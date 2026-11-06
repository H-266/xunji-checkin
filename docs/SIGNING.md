# 正式签名说明

本交付已生成 release keystore：

- keystore：`android/keystore/xunji-release.jks`
- alias：`xunji`
- store/key password：`xunji2026release`
- 证书：`CN=Xunji Checkin, OU=Mobile, O=Xunji, C=CN`

## 必须备份

`android/keystore/xunji-release.jks` 与 `android/key.properties` 是后续覆盖升级的唯一凭证。丢失后无法再更新已上架应用。

## 重建

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_release.ps1
```

脚本会从 `android/key.properties` 读取签名配置。若将项目公开到 GitHub，请勿提交 `.jks` 或 `key.properties`（`.gitignore` 已排除）。
