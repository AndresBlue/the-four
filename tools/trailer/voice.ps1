# The trailer's voice: the hotel's own announcements, read by Windows' speech
# synthesis (the OneCore voices every Windows 10/11 has, nothing downloaded),
# one WAV per line into evidence/trailer/voice/. tools/trailer/audio.py treats
# them as a recording played over the hotel's public-address system.
#   ./tools/trailer/voice.ps1 [-Voice 'Microsoft Laura'] [-Rate 0.95] [-Only <id>]
# Saved with a byte-order mark: Windows PowerShell reads a script without one
# as ANSI, and the accents reached the voice as garbage.
param(
    [string]$Voice = 'Microsoft Laura',
    [double]$Rate = 0.95,
    [string]$Only = ''
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $projectPath 'evidence/trailer/voice'
New-Item -ItemType Directory -Force $out | Out-Null

# Id, then what is said (SSML: <break> is a pause). The numbers of the rules
# are lines of their own: after a full stop the voice waits over a second, and
# the edit decides that pause instead (tools/trailer/edit.py places each one).
$lines = [ordered]@{
    'bienvenidos' = 'Bienvenidos al hotel.'
    'normas'      = 'Por su seguridad, respeten las normas.'
    'n1'          = 'Uno.'
    'r1'          = 'No corran por los pasillos.'
    'oye'         = 'Él les oye.'
    'n2'          = 'Dos.'
    'r2'          = 'Enciendan los televisores.'
    'usa'         = 'Él también los usa.'
    'n3'          = 'Tres.'
    'r3'          = 'Si les persigue, escóndanse.'
    'entrar'      = 'Y que nadie les vea entrar.'
    'n4'          = 'Cuatro.'
    'r4'          = 'No crean todo lo que ven.'
    'juntos'      = 'Salgan juntos.'
    'uno_de'      = 'O que uno de ustedes <break time="150ms"/> sea él.'
    'primer'      = 'Esto es solo el primer piso.'
    'quedan'      = 'Quedan tres.'
    'estancia'    = 'Disfruten de su estancia.'
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($operation, [Type]$type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
    $task.Wait(-1) | Out-Null
    $task.Result
}
[Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null
$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$chosen = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -eq $Voice } | Select-Object -First 1
if (-not $chosen) { throw "No voice called $Voice" }
$synth.Voice = $chosen
$synth.Options.SpeakingRate = $Rate
$synth.Options.AppendedSilence = [Windows.Media.SpeechSynthesis.SpeechAppendedSilence]::Min
$lang = $chosen.Language

foreach ($id in $lines.Keys) {
    if ($Only -and $id -ne $Only) { continue }
    $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='$lang'>$($lines[$id])</speak>"
    $stream = Await ($synth.SynthesizeSsmlToStreamAsync($ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
    $reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
    $size = [uint32]$stream.Size
    Await ($reader.LoadAsync($size)) ([uint32]) | Out-Null
    $bytes = New-Object byte[] $size
    $reader.ReadBytes($bytes)
    $path = Join-Path $out "$id.wav"
    [IO.File]::WriteAllBytes($path, $bytes)
    Write-Output ("{0,-12} {1,8} bytes" -f $id, $size)
}
