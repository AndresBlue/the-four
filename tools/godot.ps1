param(
    [ValidateSet('play','gallery','lurker','build-gallery','playtest','locust','rehearsal','bench','bench-films','survival-test','editor','test','hotel-batch','hotel-walkthrough','hotel-audio','hotel-benchmark','compatibility','observer','bots','hunt','bots-run','bots-replay','export','export-mac')][string]$Mode = 'play',
    [int]$Seed = 81,
    # Extra flags for the script behind the mode, e.g. -Extra '--shots'.
    [string]$Extra = '',
    # bots-replay: the folder of one recorded floor (tools/bots.ps1 prints it)
    # and the second to open it at.
    [string]$Run = '',
    [double]$At = 0,
    # bots: how many play, and whether the creature only notes its captures.
    [ValidateRange(1,5)][int]$Bots = 3,
    [switch]$Mercy,
    # export: skip the zip (a quicker export to try something locally).
    [switch]$NoZip,
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
# The player's renderer choice (Ajustes, user://renderer.cfg) is for playing:
# tests, captures and benchmarks run the renderer they were written for.
if ($Mode -notin @('play','playtest','locust','rehearsal','bench','editor','gallery','lurker','compatibility','observer','bots','hunt','bots-replay','export','export-mac')) { $arguments += @('--rendering-method','forward_plus') }
switch ($Mode) {
    'gallery' { $arguments += 'res://tools/workbenches/module_gallery.tscn' }
    # The Lurker coming down a corridor at you, played (tools/workbenches/lurker_test.gd).
    'lurker' { $arguments += 'res://tools/workbenches/lurker_test.tscn' }
    'build-gallery' { $arguments += @('--headless','--script','res://tools/editor/build_gallery.gd') }
    # The parentheses matter: inside an array literal, PowerShell reads
    # @('--', 'x=' + $Seed) as @('--','x=') + $Seed and splits it in two.
    'playtest' { $arguments += @('--', ('--playtest-seed=' + $Seed)) }
    'locust' { $arguments += @('--', '--locust', ('--playtest-seed=' + $Seed)) }
    # Watching, not playing: it joins a room open on this machine (or the one
    # -Extra '--address=...' names) and takes no seat; with nobody hosting it
    # builds a floor of its own to walk (game/app/observer_view.gd).
    'observer' { $arguments += @('--', '--observer', ('--playtest-seed=' + $Seed)) }
    'rehearsal' { $arguments += @('--script','res://tools/dev/echo_rehearsal.gd','--',('--rehearsal-seed=' + $Seed)) }
    # The bench of the capture, played (tools/dev/capture_bench.gd): the
    # creature catches you whenever you ask, in the light, by the way in and
    # with the ending you choose; the keys are on the screen. With your own
    # settings, and nothing of it is kept.
    'bench' { $arguments += @('--script','res://tools/dev/capture_bench.gd','--',('--seed=' + $Seed)) }
    'survival-test' { $arguments += @('--headless','--fixed-fps','60','--script','res://tests/hotel/survival_test.gd','--','--test-profile','--automation') }
    'editor' { $arguments += '--editor' }
    'test' { $arguments += @('--headless','--fixed-fps','60','--script','res://tests/hotel/hotel_test.gd','--','--test-profile','--automation','--no-enemy') }
    'hotel-batch' { $arguments += @('--headless','--fixed-fps','60','--script','res://tests/hotel/hotel_batch.gd','--','--test-profile','--automation','--no-enemy','--silent') }
    'hotel-walkthrough' { $arguments += @('--script','res://tests/hotel/hotel_walkthrough.gd','--','--test-profile','--automation','--no-enemy','--silent') }
    'hotel-audio' { $arguments += @('--headless','--script','res://tests/hotel/hotel_audio_test.gd','--','--test-profile','--automation','--silent') }
    'hotel-benchmark' { $arguments += @('--script','res://tools/benchmarks/hotel_benchmark.gd','--','--test-profile','--automation','--no-enemy','--silent') }
    'compatibility' { $arguments += @('--rendering-method','gl_compatibility') }
    # Bots playing floor after floor, watched live in the observer
    # (tools/bots/bot_watch.gd): a floor over, won or lost, and the next seed.
    'bots' {
        $arguments += @('--', '--bots-watch', ('--bots=' + $Bots), ('--seed=' + $Seed), '--test-profile', '--profile-tag=vivo')
        if ($Mercy) { $arguments += '--mercy' }
    }
    # You are The Locust, hunting test bots floor after floor (five unless
    # -Bots says otherwise), with your own settings: a bot floor keeps no
    # checkpoint and no best time. Back to the menu ends it.
    'hunt' {
        $hunters = if ($PSBoundParameters.ContainsKey('Bots')) { $Bots } else { 5 }
        $arguments += @('--', '--bots-hunt', ('--bots=' + $hunters), ('--seed=' + $Seed))
    }
    # A recorded bot floor, watched again in the observer (tools/bots/bot_replay.gd).
    'bots-replay' {
        if (-not $Run) { throw 'Indica la carpeta de la partida con -Run.' }
        $folder = (Resolve-Path -LiteralPath $Run).Path
        $arguments += @('--', ('--bots-replay=' + $folder), ('--bots-at=' + [string]$At), '--test-profile', '--profile-tag=replay')
    }
    # One floor played by test bots, headless (tools/bots/bot_run.gd): -Extra
    # '--bots=3 --mercy --knowledge=oracle --no-enemy'. Many in a row, with the
    # watchdog and the summary: ./tools/bots.ps1.
    'bots-run' { $arguments += @('--headless','--fixed-fps','60','--script','res://tools/bots/bot_run.gd','--','--test-profile','--automation','--silent',('--seed=' + $Seed)) }
    'export' {
        New-Item -ItemType Directory -Force (Join-Path $projectPath 'exports/windows') | Out-Null
        # Godot caches every scene it converts for export and only redoes one
        # when that file changes, not its dependencies: a scene could ship an
        # old copy of a resource it embeds (the hotel environment did). Start clean.
        $cache = Join-Path $projectPath '.godot/exported'
        if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force }
        # Not headless: the shader baker (export_presets.cfg shader_baker) needs a
        # GPU to compile every shader into the pack, and skips without a word
        # under --headless. The window stays hidden (Start-Process below).
        $arguments += @('--export-release','Windows Desktop',(Join-Path $projectPath 'exports/windows/TheFour.exe'))
    }
    # The Mac's build (preset "macOS": Intel and Apple chips in one app, signed
    # ad hoc, not notarized), a zip with the .app inside. The shader baker does
    # not bake for Metal from Windows: a Mac compiles its shaders as it loads.
    'export-mac' {
        New-Item -ItemType Directory -Force (Join-Path $projectPath 'exports/macos') | Out-Null
        $cache = Join-Path $projectPath '.godot/exported'
        if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force }
        $arguments += @('--export-release','macOS',(Join-Path $projectPath 'exports/macos/TheFour.zip'))
    }
}
# Flags for the script behind the mode, after everything it already passes.
if ($Extra -and $Mode -notin @('export','export-mac')) {
    if ($arguments -notcontains '--') { $arguments += '--' }
    $arguments += ($Extra -split ' ' | Where-Object { $_ })
}
if ($Mode -eq 'bench-films') {
    # The capture filmed with its sound, nobody at the keys (the engine's movie
    # writer, one run of the bench each): caught from the front, from behind
    # and in a wardrobe. Written to evidence/, each run with its window
    # hidden; -Extra '--light=torch' films them in another light.
    $films = @(
        @{ name = 'captura_frente'; entry = 'front' },
        @{ name = 'captura_espalda'; entry = 'back' },
        @{ name = 'captura_armario'; entry = 'wardrobe' }
    )
    New-Item -ItemType Directory -Force (Join-Path $projectPath 'evidence') | Out-Null
    foreach ($film in $films) {
        $file = Join-Path $projectPath ('evidence/' + $film.name + '.avi')
        $log = Join-Path $projectPath ('evidence/' + $film.name + '.log')
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
        $filmArguments = @('--path', $projectPath, '--rendering-method', 'forward_plus', '--resolution', '1280x720', '--write-movie', $file, '--fixed-fps', '60', '--script', 'res://tools/dev/capture_bench.gd', '--log-file', $log, '--', '--test-profile', '--no-warmup', ('--film=' + $film.name), ('--entry=' + $film.entry), ('--seed=' + $Seed))
        if ($Extra) { $filmArguments += ($Extra -split ' ' | Where-Object { $_ }) }
        $quoted = ($filmArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
        $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -PassThru -WindowStyle Hidden
        if (-not $process.WaitForExit(600000)) { $process.Kill(); throw "La grabación de $($film.name) no terminó. Consulta $log" }
        $said = if (Test-Path -LiteralPath $log) { (Get-Content -LiteralPath $log | Where-Object { $_ -match 'CAPTURE_FILM' }) -join ' | ' } else { '' }
        if (-not (Test-Path -LiteralPath $file) -or $said -match 'FAILED' -or $said -notmatch 'done') { throw "La grabación de $($film.name) falló: $said. Consulta $log" }
        Get-Item -LiteralPath $file | Select-Object Name, @{ n = 'MB'; e = { [Math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize -HideTableHeaders | Out-String | ForEach-Object { $_.Trim() } | Write-Output
    }
} elseif ($Mode -eq 'export') {
    # The editor binary is a GUI program: wait so the command ends with the export.
    $quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "La exportación falló (código $($process.ExitCode))." }
    # The game is a folder: the engine, its data beside it, and Steam's two
    # libraries. They go together, always.
    $folder = Join-Path $projectPath 'exports/windows'
    # What the exporter leaves behind while it writes the exe's resources
    # (icon, version): not part of the game, which runs without it.
    Get-ChildItem $folder -Filter '*.truncated' -File | Remove-Item -Force
    $game = @('TheFour.exe', 'TheFour.pck', 'steam_api64.dll', 'libgodotsteam.windows.template_release.x86_64.dll') | ForEach-Object { Get-Item (Join-Path $folder $_) }
    $game | Select-Object Name, LastWriteTime, Length | Format-Table -AutoSize | Out-String | Write-Output
    if (-not $NoZip) {
        # What is handed to players: those four files in a folder "The Four",
        # in exports/TheFour.zip, replaced by each export.
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        $zipPath = Join-Path $projectPath 'exports/TheFour.zip'
        Get-ChildItem (Join-Path $projectPath 'exports') -Filter 'TheFour*.zip' -File | Remove-Item -Force
        $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in $game) { [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, 'The Four/' + $file.Name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null }
        } finally { $zip.Dispose() }
        Get-Item $zipPath | Select-Object FullName, Length | Format-List | Out-String | Write-Output
    }
} elseif ($Mode -eq 'export-mac') {
    $quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "La exportación para macOS falló (código $($process.ExitCode))." }
    Get-Item (Join-Path $projectPath 'exports/macos/TheFour.zip') | Select-Object FullName, LastWriteTime, Length | Format-List | Out-String | Write-Output
} else {
    & $GodotPath @arguments
}
