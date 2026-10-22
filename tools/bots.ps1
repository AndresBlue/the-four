# Floors played by test bots, many in a row, for finding what breaks with
# nobody at the keyboard (tools/bots/). One Godot process per floor, headless
# and faster than real time, a few at once; each is watched from here too: a
# floor whose heartbeat stops is killed and noted as hung, one that runs past
# the wall-clock limit as out of time, one that dies as fallen, with the end of
# its log. At the end, a table in the terminal and, for every incident worth
# looking at, the command that opens its recording in the observer at the
# right second.
#
#   ./tools/bots.ps1                        # 10 floors, 3 bots, from seed 81
#   ./tools/bots.ps1 -Bots 5 -Runs 40 -Parallel 4 -Mercy
#   ./tools/bots.ps1 -Seeds 81,213,404 -Bots 1 -NoEnemy -Oracle
#   ./tools/bots.ps1 -Difficulty apacible -Skill novato -Runs 20 -Parallel 10
#
# -Difficulty: the creature's (game/floors/difficulty.gd; desafiante is the
# game as it was). -Skill: experto knows where the creature is all the time;
# novato only what it sees and hears (docs/DIFFICULTY.md).
param(
    [ValidateRange(1,5)][int]$Bots = 3,
    [ValidateRange(1,100000)][int]$Runs = 10,
    [int]$Seed = 81,
    [int[]]$Seeds = @(),
    # The floor the bots play (hotel_main.floor_asked()): 1 is the hotel.
    [ValidateRange(1,4)][int]$Floor = 1,
    # The creature's strike only noted: every floor reaches its end.
    [switch]$Mercy,
    # No creature at all, and bots that know everything: routes and doors only.
    [switch]$NoEnemy,
    [switch]$Oracle,
    [ValidateSet('apacible','equilibrada','desafiante','pesadilla')][string]$Difficulty = 'desafiante',
    [ValidateSet('experto','novato')][string]$Skill = 'experto',
    [ValidateRange(1,20)][int]$Parallel = 2,
    [ValidateRange(1,600)][int]$MaxMinutes = 45,
    [ValidateRange(20,3600)][int]$StallSeconds = 120,
    [string]$Label = '',
    # Exit 1 on any serious incident or any floor that did not end.
    [switch]$Strict,
    # For testing the watchdog itself: block, error or hang.
    [string]$Fault = '',
    [string]$GodotPath = $env:GODOT_PATH
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Indica la ruta de Godot con -GodotPath o con la variable GODOT_PATH.' }
$seedList = if ($Seeds.Count -gt 0) { $Seeds } else { 0..($Runs - 1) | ForEach-Object { $Seed + $_ } }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$batchName = if ($Label) { "$stamp-$($Label -replace '[^\w-]', '_')" } else { $stamp }
$batch = Join-Path $projectPath "evidence/bots/$batchName"
New-Item -ItemType Directory -Force $batch | Out-Null
$commit = ''
try { $commit = (& git -C $projectPath rev-parse --short HEAD 2>$null) } catch { }

function Start-Run($index, $seedValue, $worker) {
    $name = '{0:D2}-s{1}-b{2}' -f ($index + 1), $seedValue, $Bots
    $dir = Join-Path $batch $name
    New-Item -ItemType Directory -Force $dir | Out-Null
    $log = Join-Path $dir 'run.log'
    $arguments = @('--headless','--path',$projectPath,'--rendering-method','forward_plus','--fixed-fps','60','--script','res://tools/bots/bot_run.gd','--log-file',$log,'--','--test-profile','--automation','--silent',"--profile-tag=w$worker","--bots=$Bots","--seed=$seedValue","--floor=$Floor","--out=$dir","--commit=$commit")
    if ($Mercy) { $arguments += '--mercy' }
    if ($NoEnemy) { $arguments += '--no-enemy' }
    if ($Oracle) { $arguments += '--knowledge=oracle' }
    $arguments += @("--difficulty=$Difficulty", "--skill=$Skill")
    if ($Fault) { $arguments += "--fault=$Fault" }
    $quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -WindowStyle Hidden -PassThru
    return [PSCustomObject]@{ index = $index; name = $name; seed = $seedValue; dir = $dir; log = $log; process = $process; worker = $worker; started = Get-Date; verdict = '' }
}

# The end of a floor that did not end by itself: its last lines and the
# first errors in it, which is where a crash says what it was.
function Get-LogTail($log) {
    if (-not (Test-Path -LiteralPath $log)) { return @() }
    $lines = Get-Content -LiteralPath $log -Encoding UTF8
    $errors = $lines | Select-String -Pattern 'SCRIPT ERROR:|ERROR:' -Context 0,2 | Select-Object -First 5 | ForEach-Object { $_.Line; $_.Context.PostContext }
    return @($errors) + @('...') + @($lines | Select-Object -Last 40)
}

$queue = [System.Collections.Queue]::new()
for ($i = 0; $i -lt $seedList.Count; $i++) { $queue.Enqueue(@($i, $seedList[$i])) }
$running = @()
$finished = @()
$workers = @{}
Write-Output ("Lote {0}: {1} pisos, {2} bots{3}{4}{5}, {6} a la vez." -f $batchName, $seedList.Count, $Bots, $(if ($Mercy) { ', clemencia' } else { '' }), $(if ($NoEnemy) { ', sin criatura' } else { '' }), $(if ($Oracle) { ', sabiéndolo todo' } else { '' }), $Parallel)
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($queue.Count -gt 0 -and $running.Count -lt $Parallel) {
        $next = $queue.Dequeue()
        $worker = 1
        while ($workers.ContainsKey($worker)) { $worker++ }
        $workers[$worker] = $true
        $running += Start-Run $next[0] $next[1] $worker
    }
    Start-Sleep -Seconds 2
    $still = @()
    foreach ($run in $running) {
        $age = ((Get-Date) - $run.started).TotalSeconds
        $beat = Join-Path $run.dir 'heartbeat.json'
        # Silent for too long: the heartbeat is rewritten every ten seconds of
        # the wall clock while the floor runs, and building one takes seconds.
        $quiet = if (Test-Path -LiteralPath $beat) { ((Get-Date) - (Get-Item -LiteralPath $beat).LastWriteTime).TotalSeconds } else { $age - 60 }
        if (-not $run.process.HasExited -and $quiet -gt $StallSeconds) {
            $run.process.Kill()
            $run.verdict = 'colgado'
        } elseif (-not $run.process.HasExited -and $age -gt $MaxMinutes * 60) {
            $run.process.Kill()
            $run.verdict = 'tiempo_real_agotado'
        }
        if ($run.process.HasExited -or $run.verdict) {
            $run.process.WaitForExit(5000) | Out-Null
            $workers.Remove($run.worker)
            $finished += $run
            Write-Output ("  {0} terminado: {1}" -f $run.name, $(if ($run.verdict) { $run.verdict } elseif (Test-Path -LiteralPath (Join-Path $run.dir 'summary.json')) { (Get-Content -LiteralPath (Join-Path $run.dir 'summary.json') -Raw -Encoding UTF8 | ConvertFrom-Json).result } else { 'caída' }))
        } else { $still += $run }
    }
    $running = $still
}

# --- The summary ------------------------------------------------------------------
$rows = @()
$incidents = @()
foreach ($run in ($finished | Sort-Object index)) {
    $summaryPath = Join-Path $run.dir 'summary.json'
    $logText = if (Test-Path -LiteralPath $run.log) { Get-Content -LiteralPath $run.log -Raw -Encoding UTF8 } else { '' }
    $engineErrors = ([regex]::Matches($logText, 'SCRIPT ERROR:|(?m)^ERROR:')).Count
    $row = [ordered]@{ run = $run.index + 1; name = $run.name; seed = $run.seed; bots = $Bots; result = ''; sim = 0; wall = [math]::Round(((Get-Date) - $run.started).TotalSeconds); sectors = @(); deaths = 0; caught = 0; bot_stuck = 0; bot_grave = 0; creature = 0; not_found = 0; errors = $engineErrors; serious = 0; restarts = 0; encounters = 0; chases = 0; escapes = 0; quiet = 0; dir = $run.dir }
    if (-not $run.verdict -and (Test-Path -LiteralPath $summaryPath)) {
        $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $row.result = $summary.result
        $row.sim = [math]::Round([double]$summary.sim_seconds)
        $row.wall = [math]::Round([double]$summary.wall_seconds)
        $row.sectors = @($summary.sectors | ForEach-Object { [math]::Round([double]$_) })
        $row.deaths = [int]$summary.deaths
        # What the bots lived through with the creature (run_ledger.gd): summed
        # over the team, and the longest stretch any of them had without it.
        if ($summary.team) {
            foreach ($member in $summary.team) {
                $row.encounters += [int]$member.encounters
                $row.chases += [int]$member.chases
                $row.escapes += [int]$member.escapes
                $row.quiet = [math]::Max($row.quiet, [int]$member.quiet)
            }
        }
        if ($summary.restarts) { $row.restarts = [int]$summary.restarts }
        foreach ($entry in $summary.incidents) {
            switch -Wildcard ($entry.kind) {
                'bot_*' { $row.bot_stuck++; if ($entry.severity -eq 'grave') { $row.bot_grave++ } }
                'criatura_*' { $row.creature++ }
                'no_encontrado' { $row.not_found++ }
                'captura' { $row.caught++ }
                'muerte' { }
                'error_motor' { }
            }
            if ($entry.severity -eq 'grave') { $row.serious++ }
            if ($entry.severity -ne 'leve') {
                $at = [math]::Max(0, [math]::Floor([double]$entry.t) - 8)
                $incidents += [PSCustomObject]@{ run = $run.name; t = [double]$entry.t; severity = $entry.severity; kind = $entry.kind; bot = $entry.bot; room = $entry.room_name; words = $entry.words; replay = ('./tools/godot.ps1 bots-replay -Run "{0}" -At {1}' -f $run.dir, $at) }
            }
        }
    } else {
        $row.result = if ($run.verdict) { $run.verdict } else { 'caída' }
        $row.serious++
        $tail = Get-LogTail $run.log
        $tail | Set-Content -LiteralPath (Join-Path $run.dir 'final_del_log.txt') -Encoding UTF8
        # The last second the floor was heard from, which is where to look.
        $last = 0
        $beatFile = Join-Path $run.dir 'heartbeat.json'
        if (Test-Path -LiteralPath $beatFile) { try { $last = [double](Get-Content -LiteralPath $beatFile -Raw -Encoding UTF8 | ConvertFrom-Json).sim } catch { } }
        $row.sim = [math]::Round($last)
        $incidents += [PSCustomObject]@{ run = $run.name; t = $last; severity = 'grave'; kind = $row.result; bot = ''; room = ''; words = ('el proceso no terminó el piso (último latido a los {0} s de juego); ver {1}' -f [math]::Round($last), (Join-Path $run.dir 'final_del_log.txt')); replay = ('./tools/godot.ps1 bots-replay -Run "{0}" -At {1}' -f $run.dir, [math]::Max(0, [math]::Floor($last) - 8)) }
    }
    $rows += [PSCustomObject]$row
}
function Format-Clock($seconds) { '{0:D2}:{1:D2}' -f [int][math]::Floor($seconds / 60), [int]($seconds % 60) }
$lines = @()
$lines += ("LOTE {0} · {1} pisos · {2} bots {3} · {4}{5}{6}{7}" -f $batchName, $rows.Count, $Bots, $(if ($Skill -eq 'novato') { 'novatos' } else { 'expertos' }), $Difficulty, $(if ($Mercy) { ' · clemencia' } else { '' }), $(if ($NoEnemy) { ' · sin criatura' } else { '' }), $(if ($Oracle) { ' · sabiéndolo todo' } else { '' }))
$lines += ''
$lines += ('{0,-14} {1,-20} {2,8} {3,8} {4,-22} {5,7} {6,9} {7,8} {8,9} {9,11} {10,8}' -f 'Partida', 'Resultado', 'Juego', 'Real', 'Sectores', 'Muertes', 'Capturas', 'Atascos', 'Criatura', 'Sin encont.', 'Errores')
foreach ($row in $rows) {
    $sectors = ($row.sectors | ForEach-Object { Format-Clock $_ }) -join ' '
    $lines += ('{0,-14} {1,-20} {2,8} {3,8} {4,-22} {5,7} {6,9} {7,8} {8,9} {9,11} {10,8}' -f $row.name, $row.result, (Format-Clock $row.sim), (Format-Clock $row.wall), $sectors, $row.deaths, $row.caught, ('{0}/{1}' -f $row.bot_stuck, $row.bot_grave), $row.creature, $row.not_found, $row.errors)
}
$won = @($rows | Where-Object { $_.result -eq 'ganada' }).Count
$lines += ''
$lines += ('Ganadas {0} de {1} · incidencias graves {2} · errores del motor {3}' -f $won, $rows.Count, ($rows | Measure-Object serious -Sum).Sum, ($rows | Measure-Object errors -Sum).Sum)
# The numbers docs/DIFFICULTY.md section 6 asks for, over the floors that ran.
$played = @($rows | Where-Object { $_.sim -gt 0 -and $_.result -notin @('colgado', 'caída', 'tiempo_real_agotado', 'no_arranca') })
if ($played.Count -gt 0) {
    $seats = [math]::Max(1, $played.Count * $Bots)
    $chases = ($played | Measure-Object chases -Sum).Sum
    $escapes = ($played | Measure-Object escapes -Sum).Sum
    $quiets = @($played | ForEach-Object { $_.quiet } | Sort-Object)
    $median = $quiets[[int][math]::Floor(($quiets.Count - 1) / 2)]
    $clean = @($played | Where-Object { $_.result -eq 'ganada' -and $_.restarts -eq 0 }).Count
    $lines += ('Dificultad: {0:P0} ganadas ({1:P0} sin derrumbes) · {2:N1} caídas por piso · {3:N1} encuentros y {4:N1} persecuciones por bot y piso · {5} de cada 10 persecuciones acaban en huida · rato más largo sin ella, mediana {6}' -f ($won / $played.Count), ($clean / $played.Count), (($played | Measure-Object deaths -Sum).Sum / $played.Count), (($played | Measure-Object encounters -Sum).Sum / $seats), ($chases / $seats), $(if ($chases -gt 0) { [math]::Round(10.0 * $escapes / $chases) } else { '-' }), (Format-Clock $median))
}
$lines += '(Atascos: todos/graves. Criatura: sus pasos 4-5, encerrada, rezagada o sin ruta.)'
if ($incidents.Count -gt 0) {
    $lines += ''
    $lines += 'INCIDENCIAS (medias y graves; las leves quedan en cada summary.json)'
    foreach ($incident in ($incidents | Sort-Object @{ Expression = { if ($_.severity -eq 'grave') { 0 } else { 1 } } }, run, t)) {
        $lines += ('[{0}] {1} {2} · {3}{4}{5} · {6}' -f $incident.run, (Format-Clock $incident.t), $incident.severity.ToUpper(), $incident.kind, $(if ($incident.bot) { ' · ' + $incident.bot } else { '' }), $(if ($incident.room) { ' · ' + $incident.room } else { '' }), $incident.words)
        $lines += ('    → {0}' -f $incident.replay)
    }
}
$lines | Set-Content -LiteralPath (Join-Path $batch 'resumen.txt') -Encoding UTF8
[PSCustomObject]@{ batch = $batchName; bots = $Bots; difficulty = $Difficulty; skill = $Skill; mercy = [bool]$Mercy; no_enemy = [bool]$NoEnemy; oracle = [bool]$Oracle; commit = $commit; runs = $rows; incidents = $incidents } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $batch 'summary.json') -Encoding UTF8
$lines | Write-Output
Write-Output ''
Write-Output ("Resumen en {0}" -f (Join-Path $batch 'resumen.txt'))
$ended = @($rows | Where-Object { $_.result -in @('colgado', 'caída', 'tiempo_real_agotado') }).Count
if ($Strict -and ($ended -gt 0 -or ($rows | Measure-Object serious -Sum).Sum -gt 0)) { exit 1 }
exit 0
