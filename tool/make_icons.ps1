Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$res = Join-Path $root 'android/app/src/main/res'
$densities = @{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}

function New-RoundedPath([float]$size, [float]$radius) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $radius * 2
  $path.AddArc(0, 0, $d, $d, 180, 90)
  $path.AddArc($size - $d, 0, $d, $d, 270, 90)
  $path.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
  $path.AddArc(0, $size - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

foreach ($entry in $densities.GetEnumerator()) {
  $size = [int]$entry.Value
  $dir = Join-Path $res $entry.Key
  New-Item -ItemType Directory -Path $dir -Force | Out-Null

  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  $bg = [System.Drawing.ColorTranslator]::FromHtml('#1F3A8A')
  $brush = New-Object System.Drawing.SolidBrush($bg)
  $path = New-RoundedPath $size ($size * 0.22)
  $g.FillPath($brush, $path)

  $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, ($size * 0.038))
  $g.DrawEllipse($ringPen, ($size * 0.19), ($size * 0.19), ($size * 0.62), ($size * 0.62))

  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, ($size * 0.06))
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $points = @(
    (New-Object System.Drawing.PointF(($size * 0.39), ($size * 0.52))),
    (New-Object System.Drawing.PointF(($size * 0.47), ($size * 0.61))),
    (New-Object System.Drawing.PointF(($size * 0.62), ($size * 0.43)))
  )
  $g.DrawLines($pen, $points)
  $bmp.Save((Join-Path $dir 'ic_launcher.png'), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Save((Join-Path $dir 'ic_launcher_round.png'), [System.Drawing.Imaging.ImageFormat]::Png)

  $pen.Dispose()
  $ringPen.Dispose()
  $brush.Dispose()
  $path.Dispose()
  $g.Dispose()
  $bmp.Dispose()
}
Write-Output 'icons generated'
