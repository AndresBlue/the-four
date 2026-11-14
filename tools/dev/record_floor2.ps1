param(
    [ValidateRange(0, 2147483647)][int]$Seed,
    [ValidateRange(1, 3)][int]$Stage,
    [ValidateSet('forward_plus', 'gl_compatibility')][string]$Renderer,
    [string]$GodotPath = $env:GODOT_PATH
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $GodotPath) {
    $GodotPath = @(
        'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
        'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Indica la ruta de Godot con -GodotPath o con la variable GODOT_PATH.'
}

$captureId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID
$capturePath = Join-Path $projectPath "evidence\perf\$captureId"
New-Item -ItemType Directory -Path $capturePath -Force | Out-Null
$trace = Join-Path $capturePath 'session.jsonl'
$log = Join-Path $capturePath 'godot.log'
$arguments = @('--path', $projectPath, '--log-file', $log)
if ($Renderer) { $arguments += @('--rendering-method', $Renderer) }
$arguments += @('--', '--floor=2', '--test-profile', '--profile-tag=rendimiento', "--perf-log=$trace")
if ($PSBoundParameters.ContainsKey('Seed')) { $arguments += "--perf-seed=$Seed" }
if ($PSBoundParameters.ContainsKey('Stage')) { $arguments += "--stage=$Stage" }

Write-Host "Grabando el piso 2 en $capturePath"
Write-Host 'Pulsa F8 al recuperarse de un tiron para marcarlo. Cierra el juego para terminar.'
$quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
$process = Start-Process -FilePath (Resolve-Path -LiteralPath $GodotPath).Path -ArgumentList $quoted -WorkingDirectory $projectPath -PassThru
$process.WaitForExit()
$result = $process.ExitCode
$process.Dispose()

$lastLine = if (Test-Path -LiteralPath $trace -PathType Leaf) { Get-Content -LiteralPath $trace -Tail 1 }
if ($result -ne 0 -or $lastLine -notmatch '"event":"session_end"') {
    throw "La captura termino con codigo $result. Revisa $log y los datos disponibles en $capturePath"
}
Write-Host "Captura guardada en $capturePath"
Write-Host "Indice de tirones y marcas: $(Join-Path $capturePath 'session.hitches.jsonl')"
