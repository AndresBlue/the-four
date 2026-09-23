param([string]$GodotPath = $env:GODOT_PATH, [int]$Port = 24600, [int]$TimeoutSeconds = 420, [ValidateSet('coop','versus','late','observer')][string]$Scenario = 'coop')
# Online play test: starts a host and guests as separate headless Godot
# processes on this machine and collects their checks (evidence/net_*.json).
# coop: host and two guests; versus: host survivor and a guest as The Locust.
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
New-Item -ItemType Directory -Force (Join-Path $projectPath 'evidence') | Out-Null
$processes = @()
$roles = if ($Scenario -eq 'versus') { @('vs_host', 'vs_hunter') } elseif ($Scenario -eq 'late') { @('late_host', 'late_guest') } elseif ($Scenario -eq 'observer') { @('watcher', 'watch_host', 'watch_guest') } else { @('host', 'alpha', 'bravo') }
foreach ($role in $roles) {
    $json = Join-Path $projectPath "evidence/net_$role.json"
    if (Test-Path $json) { Remove-Item $json }
    $log = Join-Path $projectPath "evidence/verify_net_$role.log"
    $arguments = @('--headless', '--path', $projectPath, '--rendering-method', 'forward_plus', '--script', 'res://tests/net/net_test.gd', '--log-file', $log, '--', '--automation', '--test-profile', '--silent', "--role=$role", "--port=$Port")
    $quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $processes += [PSCustomObject]@{ role = $role; log = $log; json = $json; process = (Start-Process -FilePath $GodotPath -ArgumentList $quoted -WindowStyle Hidden -PassThru) }
    Start-Sleep -Milliseconds 700
}
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
foreach ($entry in $processes) {
    $left = [int][Math]::Max(1000, ($deadline - (Get-Date)).TotalMilliseconds)
    if (-not $entry.process.WaitForExit($left)) { $entry.process.Kill() }
}
$allPassed = $true
foreach ($entry in $processes) {
    $passed = $false
    if (Test-Path $entry.json) { $passed = (Get-Content $entry.json -Raw | ConvertFrom-Json).passed }
    $logText = if (Test-Path $entry.log) { Get-Content -LiteralPath $entry.log -Raw } else { '' }
    if ($logText -match 'SCRIPT ERROR:') { $passed = $false }
    Write-Output "net_$($entry.role) : $passed"
    if (-not $passed) {
        $allPassed = $false
        Write-Output (($logText -split "`n") | Where-Object { $_ -match 'FAIL|SCRIPT ERROR|at: ' } | Select-Object -First 30)
    }
}
if (-not $allPassed) { throw 'La prueba en red falló; revisa evidence/verify_net_*.log.' }
