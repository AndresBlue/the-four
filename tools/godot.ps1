param(
    [ValidateSet('play','editor','test','hotel-batch','hotel-walkthrough','hotel-audio','hotel-benchmark','compatibility','legacy','legacy-test','h1-test','walkthrough','audio-test','build','capture')][string]$Mode = 'play',
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
    'test' { $arguments += @('--headless','--fixed-fps','60','--script','res://tools/hotel_test.gd','--','--test-profile','--automation') }
    'hotel-batch' { $arguments += @('--headless','--fixed-fps','60','--script','res://tools/hotel_batch.gd','--','--test-profile','--automation','--silent') }
    'hotel-walkthrough' { $arguments += @('--script','res://tools/hotel_walkthrough.gd','--','--test-profile','--automation','--silent') }
    'hotel-audio' { $arguments += @('--headless','--script','res://tools/hotel_audio_test.gd','--','--test-profile','--automation','--silent') }
    'hotel-benchmark' { $arguments += @('--script','res://tools/hotel_benchmark.gd','--','--test-profile','--automation','--silent') }
    'compatibility' { $arguments += @('--rendering-method','gl_compatibility') }
    'legacy' { $arguments += 'res://scenes/main.tscn' }
    'legacy-test' { $arguments += @('--headless','--script','res://tools/smoke_test.gd') }
    'h1-test' { $arguments += @('--headless','--script','res://tools/h1_test.gd') }
    'walkthrough' { $arguments += @('--script','res://tools/walkthrough_test.gd') }
    'audio-test' { $arguments += @('--headless','--script','res://tools/audio_test.gd') }
    'build' { $arguments += @('--headless','--script','res://tools/build_scene.gd') }
    'capture' { $arguments += @('res://scenes/main.tscn','--','--capture=' + (Join-Path $projectPath 'evidence/corridor.png')) }
}
& $GodotPath @arguments
