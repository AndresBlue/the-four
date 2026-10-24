param([string]$GodotPath = $env:GODOT_PATH, [int]$Jobs = 0)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Configura GODOT_PATH o pasa -GodotPath.' }
New-Item -ItemType Directory -Force (Join-Path $projectPath 'evidence') | Out-Null
# Checks run side by side, as many at once as -Jobs (by default a third of the
# machine's threads, at most eight). They can: every run of a script with
# --test-profile keeps files of its own, named after the script
# (game/app/hotel_main.gd). Three batches, one after the other:
#   1. Everything on a fixed 60 FPS clock, which only goes slower when the
#      machine is busy, never wrong: the tests, the probes, the light layers and
#      the shaders. The longest start first, by how long each took the last time
#      (evidence/verification.json).
#   2. Online play, the four scenarios at once, each on its own port: host and
#      guests on the real clock.
#   3. The two audio tests, on the real clock as well and with nothing else
#      building floors beside them.
# A check that runs out of time is a failure, and the rest go on.
if ($Jobs -le 0) { $Jobs = [Math]::Max(2, [Math]::Min(8, [int][Math]::Floor([Environment]::ProcessorCount / 3))) }
$evidence = Join-Path $projectPath 'evidence'
$lastSeconds = @{}
$lastResults = Join-Path $evidence 'verification.json'
if (Test-Path -LiteralPath $lastResults) {
    try { foreach ($entry in (Get-Content -LiteralPath $lastResults -Raw | ConvertFrom-Json)) { if ($null -ne $entry.seconds) { $lastSeconds[$entry.test] = [double]$entry.seconds } } } catch { }
}

$checks = @()
function Add-Check([string]$test, [string]$name, [string[]]$arguments, [int]$timeout, [string]$rule = 'plain', [int]$batch = 1, [string]$log = '', [string]$file = '') {
    $script:checks += [PSCustomObject]@{
        test = $test; name = $name; arguments = $arguments; timeout = $timeout; rule = $rule; batch = $batch
        log = $log; file = $(if ($file) { $file } else { $GodotPath }); order = $script:checks.Count
        out = ''; err = ''; process = $null; started = $null; passed = $false; exit_code = -1; seconds = 0.0
    }
}
function Godot-Arguments([string]$source, [string]$log, [bool]$fixed, [string[]]$user) {
    $arguments = @('--headless','--path',$projectPath,'--rendering-method','forward_plus')
    if ($fixed) { $arguments += @('--fixed-fps','60') }
    $arguments += @('--script',$source,'--log-file',$log,'--') + $user
    return ,$arguments
}

$tests = @('hotel/scene_contract_test','hotel/hotel_test','hotel/survival_test','hotel/capture_test','hotel/intro_test','hotel/echo_test','hotel/loop_test','hotel/stages_test','hotel/rules_test','hotel/difficulty_test','hotel/continue_test','hotel/creature_test','hotel/creature_contract_test','hotel/objectives_test','hotel/palette_scan_test','hotel/room_light_test','hotel/manifest_golden_test','office/office_test','office/office_walk_test','office/conduit_graph_test','office/lurker_shell_test','hotel/sanity_test','hotel/avatar_test','hotel/observer_test','hotel/hotel_audio_test','hotel/spatial_audio_test')
foreach ($test in $tests) {
    $name = ($test -split '/')[-1]
    $log = Join-Path $evidence ('verify_' + $name + '.log')
    # Audio capture needs real time: those two run last, on their own.
    $audio = $name -in @('hotel_audio_test','spatial_audio_test')
    $user = @('--automation','--test-profile','--silent')
    if ($name -in @('hotel_test','intro_test')) { $user += '--no-enemy' }
    # Its own port: a game left open on this machine hosts on the default one,
    # and the observer went and watched that instead of building its floors.
    if ($name -eq 'observer_test') { $user += '--port=24640' }
    # The offices' test makes 64 floors twice, each one validated as it is drawn.
    $limit = if ($name -eq 'office_test') { 600 } else { 360 }
    Add-Check $test $name (Godot-Arguments ('res://tests/' + $test + '.gd') $log (-not $audio) $user) $limit 'plain' $(if ($audio) { 3 } else { 1 }) $log
}
# The creature on its own feet: journeys between rooms, walking and hunting.
# Any stop over two seconds, any hop of its last-resort protocol and any
# journey not finished is a failure (tools/dev/creature_stuck_probe.gd).
$log = Join-Path $evidence 'verify_stuck_probe.log'
Add-Check 'dev/creature_stuck_probe' 'stuck_probe' (Godot-Arguments 'res://tools/dev/creature_stuck_probe.gd' $log $true @('--test-profile','--seeds=81,213','--trips=6','--strict','--automation','--silent')) 480 'plain' 1 $log
# The body of whoever is caught, kept out of the walls: fifty-six captures
# staged against walls, in corners, in doorways and in wardrobes, and no joint
# of it more than four centimetres into anything at any frame
# (tools/dev/body_clip_probe.gd).
$log = Join-Path $evidence 'verify_body_clip_probe.log'
Add-Check 'dev/body_clip_probe' 'body_clip_probe' (Godot-Arguments 'res://tools/dev/body_clip_probe.gd' $log $true @('--test-profile','--strict','--automation','--silent')) 480 'plain' 1 $log
# The test bots (tools/bots): a floor built for their seats, the game's own
# rules on their bodies, and a bot that closes a stage on its own feet
# (tests/hotel/bots_test.gd).
$log = Join-Path $evidence 'verify_bots_test.log'
Add-Check 'hotel/bots_test' 'bots_test' (Godot-Arguments 'res://tests/hotel/bots_test.gd' $log $true @('--automation','--test-profile','--silent')) 600 'plain' 1 $log
# And on floor 2: two oracle bots play the offices to the end on their own
# (tests/office/office_bots_test.gd).
$log = Join-Path $evidence 'verify_office_bots_test.log'
Add-Check 'office/office_bots_test' 'office_bots_test' (Godot-Arguments 'res://tests/office/office_bots_test.gd' $log $true @('--automation','--test-profile','--silent')) 600 'plain' 1 $log
# The creature heard from on top of the furniture: no piece of the floor's
# navigation left up there, and no route to the ear shorter than the straight
# line (tools/dev/hearing_probe.gd).
$log = Join-Path $evidence 'verify_hearing_probe.log'
Add-Check 'dev/hearing_probe' 'hearing_probe' (Godot-Arguments 'res://tools/dev/hearing_probe.gd' $log $true @('--test-profile','--seeds=81,213','--automation','--silent')) 360 'plain' 1 $log
# The lowest preset keeps every lamp in its own room with sixteen render
# layers (game/world/hotel/room_layers.gd): over these seeds none may be left
# sharing a layer with a room one of its lamps reaches.
$log = Join-Path $evidence 'verify_light_layers.log'
Add-Check 'dev/light_layers_scan' 'light_layers' @('--headless','--path',$projectPath,'--script','res://tools/dev/light_layers_scan.gd','--log-file',$log,'--','40') 360 'layers' 1 $log
# Shaders: only a real device compiles them, so this one runs with a window and
# is judged by its log. On a machine without a GPU it reports SHADERS_SKIPPED
# and counts as passed, because a skipped check is not a failed one.
# Every shader drawn once in each renderer: Forward+, and Compatibility, which
# is what modest machines get and compiles its own GLSL.
foreach ($renderer in @('forward_plus','gl_compatibility')) {
    $log = Join-Path $evidence "verify_shaders_$renderer.log"
    Add-Check "dev/check_shaders ($renderer)" "shaders_$renderer" @('--path',$projectPath,'--rendering-method',$renderer,'--script','res://tools/dev/check_shaders.gd','--log-file',$log) 360 'shaders' 1 $log
}
# Online play: real host and guest processes over 127.0.0.1 (tools/net_test.ps1,
# which keeps its own time limit and kills what it started).
$powershell = Join-Path $PSHOME 'powershell.exe'
foreach ($scenario in @('coop', 'versus', 'late', 'observer', 'office_coop')) {
    $port = @{ coop = 24600; versus = 24610; late = 24620; observer = 24630; office_coop = 24650 }[$scenario]
    Add-Check "net/$scenario" "net_$scenario" @('-NoProfile','-File',(Join-Path $PSScriptRoot 'net_test.ps1'),'-GodotPath',$GodotPath,'-Scenario',$scenario,'-Port',$port) 540 'net' 2 '' $powershell
    $checks[-1].out = Join-Path $evidence "verify_net_$($scenario)_out.log"
    $checks[-1].err = Join-Path $evidence "verify_net_$($scenario)_err.log"
}

function Start-Check($check) {
    foreach ($path in @($check.log, $check.out, $check.err)) { if ($path -and (Test-Path -LiteralPath $path)) { Remove-Item -LiteralPath $path } }
    $quoted = ($check.arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $options = @{ FilePath = $check.file; ArgumentList = $quoted; WindowStyle = 'Hidden'; PassThru = $true }
    if ($check.out) { $options.RedirectStandardOutput = $check.out; $options.RedirectStandardError = $check.err }
    $check.process = Start-Process @options
    # Without its handle taken now, a process that has exited reports no code.
    $null = $check.process.Handle
    $check.started = Get-Date
}
function Read-Text([string]$path) { if ($path -and (Test-Path -LiteralPath $path)) { return [string](Get-Content -LiteralPath $path -Raw) } return '' }
function Complete-Check($check, [bool]$finished) {
    $check.seconds = [Math]::Round(((Get-Date) - $check.started).TotalSeconds, 1)
    if ($finished) { $check.process.WaitForExit(); $check.exit_code = $check.process.ExitCode }
    $text = Read-Text $check.log
    $passed = $finished -and $check.exit_code -eq 0
    if ($check.rule -eq 'plain') { $passed = $passed -and $text -notmatch 'SCRIPT ERROR:|ERROR:' }
    elseif ($check.rule -eq 'layers') { $passed = $passed -and $text -match 'LIGHT_LAYERS' -and $text -notmatch 'SCRIPT ERROR:' }
    elseif ($check.rule -eq 'shaders') { $passed = $passed -and $text -notmatch 'SHADER ERROR|Shader compilation failed|SCRIPT ERROR:' }
    elseif ($check.rule -eq 'net') {
        # Its own lines, one per player, as it wrote them.
        $out = Read-Text $check.out
        if ($out) { Write-Output ($out.TrimEnd() -split "`r?`n") }
        if (-not $passed) { $text = $out + (Read-Text $check.err) }
    }
    $check.passed = [bool]$passed
    Write-Output ("{0} : {1}  ({2} s)" -f $check.name, $check.passed, $check.seconds)
    if (-not $check.passed) {
        if (-not $finished) { Write-Output "Tiempo agotado en $($check.name). Consulta $(if ($check.log) { $check.log } else { $check.out })" }
        Write-Output $text
    }
}
function Invoke-Batch($batch, [int]$limit) {
    $waiting = [System.Collections.Generic.Queue[object]]::new()
    foreach ($check in ($batch | Sort-Object -Property @{ Expression = { if ($lastSeconds.ContainsKey($_.test)) { $lastSeconds[$_.test] } else { 60.0 } }; Descending = $true })) { $waiting.Enqueue($check) }
    $running = @()
    try {
        while ($waiting.Count -gt 0 -or $running.Count -gt 0) {
            while ($running.Count -lt $limit -and $waiting.Count -gt 0) { $check = $waiting.Dequeue(); Start-Check $check; $running += $check }
            Start-Sleep -Milliseconds 250
            $still = @()
            foreach ($check in $running) {
                if ($check.process.HasExited) { Complete-Check $check $true }
                elseif (((Get-Date) - $check.started).TotalSeconds -gt $check.timeout) {
                    $check.process.Kill()
                    $check.process.WaitForExit(10000) | Out-Null
                    $check.exit_code = -1
                    Complete-Check $check $false
                }
                else { $still += $check }
            }
            $running = $still
        }
    } finally {
        # Stopped half way (Ctrl+C): nothing of ours left running.
        foreach ($check in $running) { if (-not $check.process.HasExited) { $check.process.Kill() } }
    }
}

$clock = Get-Date
Write-Output "Comprobando con $Jobs a la vez."
Invoke-Batch ($checks | Where-Object { $_.batch -eq 1 }) $Jobs
Invoke-Batch ($checks | Where-Object { $_.batch -eq 2 }) 4
Invoke-Batch ($checks | Where-Object { $_.batch -eq 3 }) 2
Write-Output ("Hecho en {0:N0} s." -f ((Get-Date) - $clock).TotalSeconds)
$results = $checks | Sort-Object order | ForEach-Object { [PSCustomObject]@{ test = $_.test; passed = $_.passed; exit_code = $_.exit_code; seconds = $_.seconds } }
$results | ConvertTo-Json | Set-Content -LiteralPath $lastResults -Encoding UTF8
if ($results.passed -contains $false) { throw 'Hay regresiones fallidas; revisa evidence/verify_*.log.' }
