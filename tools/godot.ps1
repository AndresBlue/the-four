param(
    [ValidateSet('play','gallery','build-gallery','playtest','locust','rehearsal','execution','survival-test','editor','test','hotel-batch','hotel-walkthrough','hotel-audio','hotel-benchmark','compatibility','observer','bots','hunt','bots-run','bots-replay','export')][string]$Mode = 'play',
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
if ($Mode -notin @('play','playtest','locust','rehearsal','execution','editor','gallery','compatibility','observer','bots','hunt','bots-replay','export')) { $arguments += @('--rendering-method','forward_plus') }
switch ($Mode) {
    'gallery' { $arguments += 'res://tools/workbenches/module_gallery.tscn' }
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
    'execution' { $arguments += @('--script','res://tools/dev/execution_rehearsal.gd','--',('--rehearsal-seed=' + $Seed)) }
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
}
# Flags for the script behind the mode, after everything it already passes.
if ($Extra -and $Mode -ne 'export') {
    if ($arguments -notcontains '--') { $arguments += '--' }
    $arguments += ($Extra -split ' ' | Where-Object { $_ })
}
if ($Mode -eq 'export') {
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
} else {
    & $GodotPath @arguments
}
