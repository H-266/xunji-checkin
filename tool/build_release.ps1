# 循记打卡正式发布构建脚本（Windows PowerShell）
# 用法：
#   1) 准备 release keystore，并复制 android/key.properties.example 为 android/key.properties
#   2) powershell -ExecutionPolicy Bypass -File tool/build_release.ps1
# 可选参数：
#   -FlutterPath  flutter 可执行文件路径（默认从 PATH 查找）
#   -SkipTests    跳过 analyze/test
#   -NoSigningCheck 仅构建本地测试包（允许 debug 签名）
param(
  [string]$FlutterPath = "flutter",
  [switch]$SkipTests,
  [switch]$NoSigningCheck
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$keyProps = Join-Path $project "android\key.properties"
$flutter = $FlutterPath
$ascii = "X:"
$pushed = $false

if (-not $NoSigningCheck -and -not (Test-Path $keyProps)) {
  throw "缺少 android/key.properties。正式上架包必须配置 release keystore；本地测试可加 -NoSigningCheck 使用 debug 签名。"
}


try {
  if (Test-Path "$ascii\") { throw "X: 已被占用，请先释放或修改脚本盘符" }
  & subst $ascii $project
  if ($LASTEXITCODE -ne 0) { throw "subst 失败" }
  Push-Location "$ascii\"
  $pushed = $true

  # 中文路径下 analysis server 会崩溃，因此 analyze/test 也要在 X: 映射内执行。
  if (-not $SkipTests) {
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze 失败" }
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw "flutter test 失败" }
  }

  & $flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw "release 构建失败" }
  & $flutter build apk --debug
  if ($LASTEXITCODE -ne 0) { throw "debug 构建失败" }
  Pop-Location
  $pushed = $false

  $dist = Join-Path $project "dist"
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  Copy-Item "$ascii\build\app\outputs\flutter-apk\app-release.apk" (Join-Path $dist "xunji-checkin-full-1.0.0-release.apk") -Force
  Copy-Item "$ascii\build\app\outputs\flutter-apk\app-debug.apk" (Join-Path $dist "xunji-checkin-full-1.0.0-debug.apk") -Force
  $release = Join-Path $dist "xunji-checkin-full-1.0.0-release.apk"
  $debug = Join-Path $dist "xunji-checkin-full-1.0.0-debug.apk"
  $lines = @(
    "$((Get-FileHash $release -Algorithm SHA256).Hash.ToLower()) *dist/xunji-checkin-full-1.0.0-release.apk",
    "$((Get-FileHash $debug -Algorithm SHA256).Hash.ToLower()) *dist/xunji-checkin-full-1.0.0-debug.apk"
  )
  [IO.File]::WriteAllLines((Join-Path $dist "SHA256SUMS.txt"), $lines, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "构建完成：$dist"
  $lines | ForEach-Object { Write-Host $_ }
}
finally {
  if ($pushed) { Pop-Location }
  if (Test-Path "$ascii\") { & subst $ascii /d | Out-Null }
}
