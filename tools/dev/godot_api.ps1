## Dumps the class reference of the project Godot binary to .claude/godot-api for agents to grep.
$g = 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$d = 'E:/Projects/The Four/.claude/godot-api'
## PS 5.1 reads this file as ANSI, so match the profile folder without its dash
$prof = (Get-ChildItem (Join-Path $env:APPDATA 'Godot\app_userdata') -Directory -Filter 'THE FOUR*Hotel').FullName
$before = (Get-Item -LiteralPath $prof).LastWriteTime
New-Item -ItemType Directory -Force $d | Out-Null
$vout = Join-Path $env:TEMP 'godot_version.txt'
$p = Start-Process -FilePath $g -ArgumentList @('--headless', '--version') -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $vout
(Get-Content $vout -Raw).Trim() | Set-Content -Encoding utf8 (Join-Path $d 'VERSION')
$p = Start-Process -FilePath $g -ArgumentList @('--headless', '--doctool', "`"$d`"") -WorkingDirectory $d -Wait -PassThru -WindowStyle Hidden
"doctool exit: $($p.ExitCode)"
"version: $(Get-Content (Join-Path $d 'VERSION'))"
"xml count: $((Get-ChildItem -Recurse $d -Filter *.xml).Count)"
Get-ChildItem -Recurse -Directory $d | Select-Object -First 15 | ForEach-Object { $_.FullName.Substring($d.Length) }
"Node3D: $((Get-ChildItem -Recurse $d -Filter Node3D.xml).FullName)"
"Logger: $((Get-ChildItem -Recurse $d -Filter Logger.xml).FullName)"
"size MB: $([math]::Round(((Get-ChildItem -Recurse $d -File | Measure-Object Length -Sum).Sum / 1MB), 1))"
"profile untouched: $($before -eq (Get-Item -LiteralPath $prof).LastWriteTime)"
