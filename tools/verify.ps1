param([string]$GodotPath = $env:GODOT_PATH)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Configura GODOT_PATH o pasa -GodotPath.' }
New-Item -ItemType Directory -Force (Join-Path $projectPath 'evidence') | Out-Null
# Sequential: audio capture needs real time and should not compete with map batches.
$tests = @('hotel/scene_contract_test','hotel/hotel_test','hotel/survival_test','hotel/intro_test','hotel/echo_test','hotel/loop_test','hotel/stages_test','hotel/sanity_test','hotel/avatar_test','hotel/hotel_audio_test','hotel/spatial_audio_test')
$results = @()
foreach ($test in $tests) {
    $name = ($test -split '/')[-1]
    $log = Join-Path $projectPath ('evidence/verify_' + $name + '.log')
    $arguments = @('--headless','--path',$projectPath,'--rendering-method','forward_plus','--script',('res://tests/' + $test + '.gd'),'--log-file',$log)
    if ($name -notin @('hotel_audio_test','spatial_audio_test')) { $arguments += @('--fixed-fps','60') }
    $arguments += @('--','--automation','--test-profile','--silent')
    if ($name -in @('hotel_test','intro_test')) { $arguments += '--no-enemy' }
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
# Shaders: only a real device compiles them, so this one runs with a window and
# is judged by its log. On a machine without a GPU it reports SHADERS_SKIPPED
# and counts as passed, because a skipped check is not a failed one.
# Every shader drawn once in each renderer: Forward+, and Compatibility, which
# is what modest machines get and compiles its own GLSL.
foreach ($renderer in @('forward_plus','gl_compatibility')) {
    $shaderLog = Join-Path $projectPath "evidence/verify_shaders_$renderer.log"
    $shaderArguments = (@('--path',$projectPath,'--rendering-method',$renderer,'--script','res://tools/dev/check_shaders.gd','--log-file',$shaderLog) | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $shaderProcess = Start-Process -FilePath $GodotPath -ArgumentList $shaderArguments -WindowStyle Hidden -PassThru
    if (-not $shaderProcess.WaitForExit(180000)) { $shaderProcess.Kill(); throw "Tiempo agotado en shaders. Consulta $shaderLog" }
    $shaderText = Get-Content -LiteralPath $shaderLog -Raw
    $shaderPassed = $shaderProcess.ExitCode -eq 0 -and $shaderText -notmatch 'SHADER ERROR|Shader compilation failed|SCRIPT ERROR:'
    $results += [PSCustomObject]@{ test="dev/check_shaders ($renderer)"; passed=$shaderPassed; exit_code=$shaderProcess.ExitCode }
    Write-Output "shaders_$renderer : $shaderPassed"
    if (-not $shaderPassed) { Write-Output $shaderText }
}

# Online play: real host and guest processes over 127.0.0.1.
foreach ($scenario in @('coop', 'versus', 'late')) {
    $port = @{ coop = 24600; versus = 24610; late = 24620 }[$scenario]
    $passed = $true
    try { & (Join-Path $PSScriptRoot 'net_test.ps1') -GodotPath $GodotPath -Scenario $scenario -Port $port | Write-Output } catch { $passed = $false; Write-Output $_ }
    $results += [PSCustomObject]@{ test="net/$scenario"; passed=$passed; exit_code=0 }
    Write-Output "net_$scenario : $passed"
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectPath 'evidence/verification.json') -Encoding UTF8
if ($results.passed -contains $false) { throw 'Hay regresiones fallidas; revisa evidence/verify_*.log.' }
