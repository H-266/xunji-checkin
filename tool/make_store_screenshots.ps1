Add-Type -AssemblyName System.Drawing
$root = (Get-ChildItem 'E:\' -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'stage12') } | Select-Object -First 1).FullName
$srcDir = Join-Path $root 'screenshots'
$out = Join-Path $root 'stage12\store\screenshots-1080x2400'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$map = @{
  'consent.png' = '01-privacy.png'
  'demo-today2.png' = '02-today.png'
  'demo-heat.png' = '03-heatmap.png'
  'demo-widgets.png' = '04-widgets.png'
  'demo-settings.png' = '05-settings.png'
}
foreach ($k in $map.Keys) {
  $src = [Drawing.Image]::FromFile((Join-Path $srcDir $k))
  $dst = New-Object Drawing.Bitmap(1080, 2400)
  $g = [Drawing.Graphics]::FromImage($dst)
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($src, 0, 0, 1080, 2400)
  $dst.Save((Join-Path $out $map[$k]), [Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $dst.Dispose(); $src.Dispose()
}
Write-Host "generated $out"
