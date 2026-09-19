## Prints benchmark reports side by side: one row per view and quality.
##   ./tools/benchmarks/bench_table.ps1 base,f1a
param([Parameter(Mandatory, Position = 0)][string[]]$Labels, [string]$Renderer = 'forward_plus')
$projectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($label in $Labels) {
    $report = Get-Content (Join-Path $projectPath "evidence/bench/${label}_$Renderer/report.json") -Raw | ConvertFrom-Json
    Write-Output "== $label ($($report.adapter))"
    $report.results | Where-Object { $_.view -ne 'memory' } | ForEach-Object {
        [PSCustomObject]@{
            q = $_.quality; view = $_.view
            frame = '{0:N2}/{1:N2}/{2:N2}' -f $_.frame_ms.mean, $_.frame_ms.p99, $_.frame_ms.max
            gpu = '{0:N2}/{1:N2}' -f $_.gpu_ms.mean, $_.gpu_ms.p99
            cpu = '{0:N2}/{1:N2}' -f $_.render_cpu_ms.mean, $_.render_cpu_ms.p99
            draws = $_.draws.mean; shadow = $_.shadow_draws.mean; prims = $_.primitives.mean
        }
    } | Format-Table -AutoSize | Out-String -Width 160
    $report.results | Where-Object { $_.view -eq 'memory' } | ForEach-Object { 'q{0} VRAM {1:N0} MB (textures {2:N0} MB)' -f $_.quality, ($_.video_mem_used / 1MB), ($_.texture_mem_used / 1MB) }
}

