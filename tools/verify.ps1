param([string]$GodotPath = $env:GODOT_PATH)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Configura GODOT_PATH o pasa -GodotPath.' }
New-Item -ItemType Directory -Force (Join-Path $projectPath 'evidence') | Out-Null
# Sequential: audio capture needs real time and should not compete with map batches.
$tests = @('hotel/scene_contract_test','hotel/hotel_test','hotel/survival_test','hotel/hotel_audio_test','legacy/smoke_test')
$results = @()
foreach ($test in $tests) {
    $name = ($test -split '/')[-1]
    $log = Join-Path $projectPath ('evidence/verify_' + $name + '.log')
    $arguments = @('--headless','--path',$projectPath,'--script',('res://tests/' + $test + '.gd'),'--log-file',$log)
    if ($name -ne 'hotel_audio_test') { $arguments += @('--fixed-fps','60') }
    $arguments += @('--','--automation','--test-profile','--silent')
    if ($name -eq 'hotel_test') { $arguments += '--no-enemy' }
    $quotedArguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quotedArguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(180000)) {
        $process.Kill()
        throw "Tiempo agotado en $name. Consulta $log"
    }
    $logText = Get-Content -LiteralPath $log -Raw
    $passed = $process.ExitCode -eq 0 -and $logText -notmatch 'SCRIPT ERROR:|ERROR:'
    $results += [PSCustomObject]@{ test=$test; passed=$passed; exit_code=$process.ExitCode }
    Write-Output "$name : $passed"
    if (-not $passed) { Write-Output $logText }
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectPath 'evidence/verification.json') -Encoding UTF8
if ($results.passed -contains $false) { throw 'Hay regresiones fallidas; revisa evidence/verify_*.log.' }
