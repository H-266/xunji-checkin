$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\lib'
$files = Get-ChildItem -Path $root -Recurse -Filter *.dart | Where-Object {
    $_.FullName -notmatch '\\l10n\\' -and $_.Name -ne 'l_text.dart'
}
$changed = 0
foreach ($f in $files) {
    $text = Get-Content -Raw -LiteralPath $f.FullName
    $count = 0
    $next = [regex]::Replace($text, "Text\(\s*'((?:[^'\\]|\\.)*[\u4e00-\u9fff](?:[^'\\]|\\.)*)'", {
        param($m)
        if ($m.Groups[1].Value.Contains('$')) { return $m.Value }
        $script:count++
        return "LText('$($m.Groups[1].Value)'"
    })
    if ($count -gt 0 -and -not $next.Contains("l_text.dart")) {
        $rel = if ($f.FullName -match '\\screens\\') { "../widgets/l_text.dart" } else { "l_text.dart" }
        $next = $next -replace "(import 'package:flutter/material.dart';)", "`$1`r`nimport '$rel';"
    }
    if ($next -ne $text) {
        Set-Content -LiteralPath $f.FullName -Value $next -Encoding utf8 -NoNewline
        $changed++
        Write-Output "$($f.FullName): $count"
    }
}
Write-Output "changed files: $changed"
