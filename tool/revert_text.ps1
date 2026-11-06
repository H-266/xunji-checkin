$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\lib'
$files = Get-ChildItem -Path $root -Recurse -Filter *.dart | Where-Object {
    $_.Name -ne 'l_text.dart'
}
foreach ($f in $files) {
    $text = Get-Content -Raw -LiteralPath $f.FullName
    $next = $text.Replace('LText(', 'Text(')
    $next = $next -replace "(?m)^import '\.\./widgets/l_text\.dart';\r?\n", ''
    $next = $next -replace "(?m)^import 'l_text\.dart';\r?\n", ''
    if ($next -ne $text) {
        Set-Content -LiteralPath $f.FullName -Value $next -Encoding utf8 -NoNewline
    }
}
Write-Output 'reverted'
