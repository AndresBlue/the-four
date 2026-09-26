# Films trailer shots (tools/trailer/shots.gd), one Godot process each, and
# can then cut the trailer (tools/trailer/cut.py).
#   ./tools/trailer/render.ps1 -Shots hall,listen [-Preview]
#   ./tools/trailer/render.ps1 -All
#   ./tools/trailer/render.ps1 -Looks            (stills of evidence/trailer/looks.json)
param(
    [string[]]$Shots = @(),
    [switch]$All,
    [switch]$Preview,
    [switch]$Looks,
    [int]$Seed = 81,
    # Only these frames, at full size (shots.gd --frames).
    [string]$Frames = '',
    # More arguments for shots.gd, e.g. -Extra '--zoom=2.4','--door=7.5,0,-29'.
    [string[]]$Extra = @(),
    # A name for the output folder other than the shot's (to keep variants apart).
    [string]$Tag = '',
    [string]$GodotPath = $env:GODOT_PATH
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $GodotPath) {
    $candidates = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $GodotPath) { throw 'Indica la ruta de Godot con -GodotPath o con la variable GODOT_PATH.' }
# Every shot the cut uses, in the order of the trailer.
$every = @('hall', 'run', 'listen', 'tv_on', 'tv_locust', 'hide_in', 'hide_peek', 'phantom', 'together', 'sheet', 'versus', 'blackout', 'charge', 'intro_glass', 'intro_slam', 'kill', 'floors')
if ($All) { $Shots = $every }
if ($Looks) { $Shots = @('looks') }
$logs = Join-Path $projectPath 'evidence/trailer/logs'
# The script is parsed once first: a mistake in it used to fail every shot
# of a long batch, one after another, each after starting a whole engine.
$ErrorActionPreference = 'Continue'
$check = & $GodotPath --headless --path $projectPath --check-only --script 'res://tools/trailer/shots.gd' 2>&1 | Out-String
$ErrorActionPreference = 'Stop'
$problems = $check -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error' }
if ($problems) { $problems | ForEach-Object { Write-Output $_ }; throw 'shots.gd no compila.' }
New-Item -ItemType Directory -Force $logs | Out-Null
$size = if ($Preview) { '640x360' } else { '1920x1080' }
foreach ($shot in $Shots) {
    $log = Join-Path $logs "$shot.log"
    $arguments = @('--path', $projectPath, '--rendering-method', 'forward_plus', '--fixed-fps', '30', '--windowed', '--resolution', $size, '--script', 'res://tools/trailer/shots.gd', '--log-file', $log, '--', '--automation', '--test-profile', '--silent', "--shot=$shot", "--seed=$Seed")
    if ($Preview) { $arguments += '--preview' }
    if ($Frames) { $arguments += "--frames=$Frames" }
    if ($Tag) { $arguments += "--tag=$Tag" }
    $arguments += $Extra
    $watch = [Diagnostics.Stopwatch]::StartNew()
    # Godot writes its warnings to stderr, which Windows PowerShell would take
    # for a failure under 'Stop'.
    $ErrorActionPreference = 'Continue'
    & $GodotPath @arguments 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
    $done = Select-String -Path $log -Pattern '^SHOT ' | Select-Object -Last 1
    $errors = Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Invalid assignment' | Select-Object -First 3
    Write-Output ("{0,-12} {1,6:N0} s  {2}" -f $shot, $watch.Elapsed.TotalSeconds, $(if ($done) { $done.Line } else { 'NO TERMINÓ' }))
    foreach ($e in $errors) { Write-Output ("    " + $e.Line) }
}
