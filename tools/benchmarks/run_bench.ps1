## Runs the hotel benchmark under a label and prints its summary lines.
##   ./tools/benchmarks/run_bench.ps1 -Label base [-Extra '--atlas-quads=2,3,4,4'] [-Compatibility]
## -Modest stands for a modest laptop's processor (docs/PERFORMANCE.md, "Equipo
## modesto"): the game is held to four cores, one thread each, and the other
## thread of each of those cores is kept busy, so the game's threads run at
## about 60 % of this processor's speed all the time (no time slicing: the
## slowdown is the two threads of a core sharing it). Its graphics card is
## stood for with -Extra '--pixels=9'.
param([Parameter(Mandatory)][string]$Label, [string]$Extra = '', [switch]$Compatibility, [switch]$Modest, [string]$GodotPath = $env:GODOT_PATH)
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
$busy = @()
if ($Modest) {
    # Logical processors 1, 3, 5 and 7: the second threads of cores 0 to 3.
    foreach ($mask in 0x2, 0x8, 0x20, 0x80) {
        $load = Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile', '-Command', 'while ($true) { }' -WindowStyle Hidden -PassThru
        $load.ProcessorAffinity = [IntPtr]$mask
        $busy += $load
    }
}
try {
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -PassThru
    # Logical processors 0, 2, 4 and 6: the first threads of those cores.
    if ($Modest) { $process.ProcessorAffinity = [IntPtr]0x55 }
    if (-not $process.WaitForExit(1800000)) { $process.Kill(); throw "Benchmark timed out: $log" }
} finally {
    foreach ($load in $busy) { if (-not $load.HasExited) { $load.Kill() } }
}
Get-Content $log | Select-String 'BENCHMARK|SCRIPT ERROR|^ERROR' | ForEach-Object { $_.Line }
