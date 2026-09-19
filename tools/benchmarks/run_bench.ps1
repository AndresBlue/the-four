## Runs the hotel benchmark under a label and prints its summary lines.
##   ./tools/benchmarks/run_bench.ps1 -Label base [-Extra '--atlas-quads=2,3,4,4'] [-Compatibility]
param([Parameter(Mandatory)][string]$Label, [string]$Extra = '', [switch]$Compatibility, [string]$GodotPath = $env:GODOT_PATH)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $GodotPath) {
    $GodotPath = @('D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
$log = Join-Path $projectPath "evidence/bench_$Label.log"
$arguments = @('--path', $projectPath)
$arguments += @('--rendering-method', $(if ($Compatibility) { 'gl_compatibility' } else { 'forward_plus' }))
$arguments += @('--script', 'res://tools/benchmarks/hotel_benchmark.gd', '--log-file', $log, '--', '--test-profile', '--automation', '--no-enemy', '--silent', "--bench-label=$Label")
if ($Extra) { $arguments += $Extra.Split(' ') }
$quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
$process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -PassThru
if (-not $process.WaitForExit(900000)) { $process.Kill(); throw "Benchmark timed out: $log" }
Get-Content $log | Select-String 'BENCHMARK|SCRIPT ERROR|^ERROR' | ForEach-Object { $_.Line }
