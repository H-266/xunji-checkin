$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\lib'
$files = @(
  'screens\app_shell.dart',
  'screens\backup_settings_screen.dart',
  'screens\batch_manage_screen.dart',
  'screens\error_log_screen.dart',
  'screens\heatmap_screen.dart',
  'screens\recycle_bin_screen.dart',
  'screens\settings_screen.dart',
  'screens\stats_screen.dart',
  'screens\tag_management_screen.dart',
  'screens\task_search_screen.dart',
  'screens\today_screen.dart',
  'screens\tutorial_screen.dart',
  'screens\widget_config_screen.dart',
  'screens\year_heatmap_screen.dart',
  'widgets\onboarding_overlay.dart'
)
foreach ($rel in $files) {
  $p = Join-Path $root $rel
  $s = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
  $b = [Text.Encoding]::GetEncoding(936).GetBytes($s)
  $fixed = [Text.Encoding]::UTF8.GetString($b)
  [IO.File]::WriteAllText($p, $fixed, (New-Object Text.UTF8Encoding($false)))
  Write-Output "fixed $rel"
}
