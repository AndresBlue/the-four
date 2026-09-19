param(
    [ValidateSet('play','gallery','build-gallery','playtest','locust','rehearsal','survival-test','editor','test','hotel-batch','hotel-walkthrough','hotel-audio','hotel-benchmark','compatibility','legacy','legacy-test','h1-test','walkthrough','audio-test','build','capture','export')][string]$Mode = 'play',
    [int]$Seed = 81,
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
    'gallery' { $arguments += 'res://tools/workbenches/module_gallery.tscn' }
    'build-gallery' { $arguments += @('--headless','--script','res://tools/editor/build_gallery.gd') }
    # The parentheses matter: inside an array literal, PowerShell reads
    # @('--', 'x=' + $Seed) as @('--','x=') + $Seed and splits it in two.
    'playtest' { $arguments += @('--', ('--playtest-seed=' + $Seed)) }
    'locust' { $arguments += @('--', '--locust', ('--playtest-seed=' + $Seed)) }
    'rehearsal' { $arguments += @('--script','res://tools/dev/echo_rehearsal.gd','--',('--rehearsal-seed=' + $Seed)) }
    'survival-test' { $arguments += @('--headless','--fixed-fps','60','--script','res://tests/hotel/survival_test.gd','--','--test-profile','--automation') }
    'editor' { $arguments += '--editor' }
    'test' { $arguments += @('--headless','--fixed-fps','60','--script','res://tests/hotel/hotel_test.gd','--','--test-profile','--automation','--no-enemy') }
    'hotel-batch' { $arguments += @('--headless','--fixed-fps','60','--script','res://tests/hotel/hotel_batch.gd','--','--test-profile','--automation','--no-enemy','--silent') }
    'hotel-walkthrough' { $arguments += @('--script','res://tests/hotel/hotel_walkthrough.gd','--','--test-profile','--automation','--no-enemy','--silent') }
    'hotel-audio' { $arguments += @('--headless','--script','res://tests/hotel/hotel_audio_test.gd','--','--test-profile','--automation','--silent') }
    'hotel-benchmark' { $arguments += @('--script','res://tools/benchmarks/hotel_benchmark.gd','--','--test-profile','--automation','--no-enemy','--silent') }
    'compatibility' { $arguments += @('--rendering-method','gl_compatibility') }
    'legacy' { $arguments += 'res://legacy/fuse_prototype/main.tscn' }
    'legacy-test' { $arguments += @('--headless','--script','res://tests/legacy/smoke_test.gd') }
    'h1-test' { $arguments += @('--headless','--script','res://tests/legacy/h1_test.gd') }
    'walkthrough' { $arguments += @('--script','res://tests/legacy/walkthrough_test.gd') }
    'audio-test' { $arguments += @('--headless','--script','res://tests/legacy/audio_test.gd') }
    'build' { $arguments += @('--headless','--script','res://tools/legacy/build_scene.gd') }
    'capture' { $arguments += @('res://legacy/fuse_prototype/main.tscn','--','--capture=' + (Join-Path $projectPath 'evidence/corridor.png')) }
    'export' {
        New-Item -ItemType Directory -Force (Join-Path $projectPath 'exports/windows') | Out-Null
        # Godot caches every scene it converts for export and only redoes one
        # when that file changes, not its dependencies: a scene could ship an
        # old copy of a resource it embeds (the hotel environment did). Start clean.
        $cache = Join-Path $projectPath '.godot/exported'
        if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force }
        $arguments += @('--headless','--export-release','Windows Desktop',(Join-Path $projectPath 'exports/windows/TheFour.exe'))
    }
}
if ($Mode -eq 'export') {
    # The editor binary is a GUI program: wait so the command ends with the export.
    $quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "La exportación falló (código $($process.ExitCode))." }
    Get-Item (Join-Path $projectPath 'exports/windows/TheFour.exe') | Select-Object FullName, LastWriteTime, Length
} else {
    & $GodotPath @arguments
}
