# The whole trailer, from nothing: the voice, every shot, the sound, the cut
# and the two versions to share (docs/TRAILER.md). About forty minutes, most
# of it filming.
#   ./tools/trailer/make.ps1            everything
#   ./tools/trailer/make.ps1 -SkipShots  keep the filmed shots (sound and cut only)
param(
    [switch]$SkipShots,
    [switch]$SkipVoice,
    [string]$FFmpeg = $env:FFMPEG
)
# Python and ffmpeg write warnings to stderr, which Windows PowerShell takes
# for failures under 'Stop': exit codes are checked instead.
$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$projectPath = Split-Path -Parent (Split-Path -Parent $here)
if (-not $FFmpeg) {
    $FFmpeg = @('C:\Users\Poblete\AppData\Local\Programs\Stremio\ffmpeg.exe', 'C:\Program Files\MediaHuman\YouTube to MP3 Converter\ffmpeg\ffmpeg.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $FFmpeg) { throw 'Hace falta ffmpeg con libx264: indícalo con -FFmpeg o la variable FFMPEG.' }
$env:FFMPEG = $FFmpeg
if (-not $SkipVoice) { & (Join-Path $here 'voice.ps1') | Out-Null }
if (-not $SkipShots) { & (Join-Path $here 'render.ps1') -All }
python (Join-Path $here 'audio.py')
if ($LASTEXITCODE -ne 0) { throw 'audio.py falló.' }
python (Join-Path $here 'analyze.py') | Select-String -Pattern 'integrated|tapada|limiter'
python (Join-Path $here 'cut.py')
if ($LASTEXITCODE -ne 0) { throw 'cut.py falló.' }
$master = Join-Path $projectPath 'evidence/trailer/The_Four_trailer.mp4'
$final = Join-Path $projectPath 'evidence/trailer/final'
New-Item -ItemType Directory -Force $final | Out-Null
Push-Location $final
try {
    $ErrorActionPreference = 'Continue'
    # Two passes to a fixed rate: the tape's grain is new on every frame, and a
    # constant quality spent over half a gigabyte on it.
    & $FFmpeg -y -v error -i $master -c:v libx264 -preset slow -b:v 14M -pass 1 -an -f null NUL
    & $FFmpeg -y -v error -i $master -c:v libx264 -preset slow -b:v 14M -maxrate 20M -bufsize 28M -pass 2 -pix_fmt yuv420p -colorspace bt709 -color_primaries bt709 -color_trc bt709 -c:a copy -movflags +faststart The_Four_trailer_1080p.mp4
    & $FFmpeg -y -v error -i $master -vf 'scale=1280:720:flags=lanczos' -c:v libx264 -preset slow -b:v 6M -pass 1 -an -f null NUL
    & $FFmpeg -y -v error -i $master -vf 'scale=1280:720:flags=lanczos' -c:v libx264 -preset slow -b:v 6M -maxrate 9M -bufsize 12M -pass 2 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart The_Four_trailer_720p.mp4
    # And a light one, under the 30 MB a phone is sent.
    & $FFmpeg -y -v error -i $master -vf 'scale=1280:720:flags=lanczos' -c:v libx264 -preset slow -b:v 3300k -pass 1 -an -f null NUL
    & $FFmpeg -y -v error -i $master -vf 'scale=1280:720:flags=lanczos' -c:v libx264 -preset slow -b:v 3300k -maxrate 5M -bufsize 7M -pass 2 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart The_Four_trailer_ligero.mp4
    Remove-Item ffmpeg2pass-0.log* -ErrorAction SilentlyContinue
} finally { Pop-Location }
python (Join-Path $here 'sync_check.py') | Select-Object -Last 12
Get-ChildItem $final | ForEach-Object { '{0,-34} {1,8:N1} MB' -f $_.Name, ($_.Length / 1MB) }
