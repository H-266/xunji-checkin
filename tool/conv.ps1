Add-Type -AssemblyName Microsoft.VisualBasic
$s = [Microsoft.VisualBasic.Strings]::StrConv('设置数据任务软件网络默认备份导出文件', [Microsoft.VisualBasic.VbStrConv]::TraditionalChinese, 0)
[System.IO.File]::WriteAllText('C:\conv.txt', $s, [System.Text.Encoding]::UTF8)
