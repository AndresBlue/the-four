param(
    [ValidateSet('play','editor','test','build','capture')][string]$Mode = 'play',
    [string]$GodotPath = $env:GODOT_PATH
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $candidates = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Indica la ruta de Godot con -GodotPath o con la variable GODOT_PATH.'
}
$arguments = @('--path', $projectPath)
switch ($Mode) {
    'editor' { $arguments += '--editor' }
    'test' { $arguments += @('--headless','--script','res://tools/smoke_test.gd') }
    'build' { $arguments += @('--headless','--script','res://tools/build_scene.gd') }
    'capture' { $arguments += @('--','--capture=' + (Join-Path $projectPath 'evidence/corridor.png')) }
}
& $GodotPath @arguments
