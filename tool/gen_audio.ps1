# Generates small chiptune-style WAV assets (music loops + SFX) for Crazy Egg Dash.
# Run once: powershell -ExecutionPolicy Bypass -File tool\gen_audio.ps1

$ErrorActionPreference = 'Stop'
$rate = 22050
$outDir = Join-Path $PSScriptRoot '..\assets\audio'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Write-Wav {
    param([string]$Path, [double[]]$Samples)
    $n = $Samples.Length
    $bytes = New-Object byte[] ($n * 2)
    for ($i = 0; $i -lt $n; $i++) {
        $v = $Samples[$i]
        if ($v -gt 1) { $v = 1 } elseif ($v -lt -1) { $v = -1 }
        $s = [int][math]::Round($v * 32767)
        $bytes[$i * 2] = $s -band 0xFF
        $bytes[$i * 2 + 1] = ($s -shr 8) -band 0xFF
    }
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $dataLen = $bytes.Length
    $bw.Write([char[]]'RIFF')
    $bw.Write([int](36 + $dataLen))
    $bw.Write([char[]]'WAVE')
    $bw.Write([char[]]'fmt ')
    $bw.Write([int]16)          # subchunk size
    $bw.Write([int16]1)         # PCM
    $bw.Write([int16]1)         # mono
    $bw.Write([int]$rate)       # sample rate
    $bw.Write([int]($rate * 2)) # byte rate
    $bw.Write([int16]2)         # block align
    $bw.Write([int16]16)        # bits per sample
    $bw.Write([char[]]'data')
    $bw.Write([int]$dataLen)
    $bw.Write($bytes)
    $bw.Flush()
    [System.IO.File]::WriteAllBytes((Join-Path $outDir $Path), $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
    Write-Host ("  {0}  ({1:N0} bytes)" -f $Path, $dataLen)
}

# Oscillators (t in seconds, f in Hz) -> -1..1
function Osc-Square([double]$t, [double]$f) { if ([math]::Sin(2 * [math]::PI * $f * $t) -ge 0) { 1.0 } else { -1.0 } }
function Osc-Tri([double]$t, [double]$f) { (2.0 / [math]::PI) * [math]::Asin([math]::Sin(2 * [math]::PI * $f * $t)) }
function Osc-Sine([double]$t, [double]$f) { [math]::Sin(2 * [math]::PI * $f * $t) }

# Note name -> frequency
$NOTE = @{
    'C3'=130.81;'D3'=146.83;'E3'=164.81;'F3'=174.61;'G3'=196.00;'A3'=220.00;'B3'=246.94;
    'C4'=261.63;'D4'=293.66;'E4'=329.63;'F4'=349.23;'G4'=392.00;'A4'=440.00;'B4'=493.88;
    'C5'=523.25;'D5'=587.33;'E5'=659.25;'F5'=698.46;'G5'=783.99;'A5'=880.00;'R'=0.0
}

# Build a music loop from melody + bass note lists.
# Each note = @{n='E4'; b=1.0}  (b = beats)
function Build-Music {
    param([array]$Melody, [array]$Bass, [double]$Bpm, [double]$MelAmp = 0.22, [double]$BassAmp = 0.16)
    $beat = 60.0 / $Bpm

    # total duration = max of melody / bass sequences
    $melBeats = 0.0; foreach ($m in $Melody) { $melBeats += $m.b }
    $bassBeats = 0.0; foreach ($m in $Bass) { $bassBeats += $m.b }
    $melDur = $melBeats * $beat
    $bassDur = $bassBeats * $beat
    $total = [math]::Max($melDur, $bassDur)
    $count = [int]($total * $rate)
    $buf = New-Object double[] $count

    function Render([array]$Seq, [double]$beatLen, [double]$amp, [string]$wave, [double[]]$target) {
        $tpos = 0.0
        foreach ($note in $Seq) {
            $dur = $note.b * $beatLen
            $f = $NOTE[$note.n]
            $start = [int]($tpos * $rate)
            $len = [int]($dur * $rate)
            if ($f -gt 0) {
                for ($i = 0; $i -lt $len; $i++) {
                    $idx = $start + $i
                    if ($idx -ge $target.Length) { break }
                    $lt = $i / [double]$rate
                    # short attack + gentle decay envelope, tiny gap between notes
                    $env = 1.0
                    $atk = 0.008
                    if ($lt -lt $atk) { $env = $lt / $atk }
                    $rel = $dur * 0.85
                    if ($lt -gt $rel) { $env = [math]::Max(0.0, (1 - ($lt - $rel) / ($dur - $rel))) }
                    $sv = 0.0
                    switch ($wave) {
                        'square' { $sv = Osc-Square $lt $f }
                        'tri'    { $sv = Osc-Tri $lt $f }
                        default  { $sv = Osc-Sine $lt $f }
                    }
                    $target[$idx] += $sv * $amp * $env
                }
            }
            $tpos += $dur
        }
    }

    Render $Melody $beat $MelAmp 'square' $buf
    Render $Bass $beat $BassAmp 'tri' $buf
    return $buf
}

function N($n, $b) { @{ n = $n; b = $b } }

Write-Host 'Generating music...'

# ---- Menu music: relaxed, cheerful C major (~ loops seamlessly) ----
$menuMel = @(
    (N 'E4' 1),(N 'G4' 1),(N 'C5' 2),
    (N 'A4' 1),(N 'G4' 1),(N 'E4' 2),
    (N 'F4' 1),(N 'A4' 1),(N 'C5' 1),(N 'A4' 1),
    (N 'G4' 4),
    (N 'D4' 1),(N 'F4' 1),(N 'A4' 2),
    (N 'G4' 1),(N 'E4' 1),(N 'C4' 2),
    (N 'D4' 1),(N 'E4' 1),(N 'F4' 1),(N 'G4' 1),
    (N 'C4' 4)
)
$menuBass = @(
    (N 'C3' 2),(N 'G3' 2),
    (N 'A3' 2),(N 'E3' 2),
    (N 'F3' 2),(N 'C3' 2),
    (N 'G3' 4),
    (N 'D3' 2),(N 'A3' 2),
    (N 'C3' 2),(N 'G3' 2),
    (N 'F3' 2),(N 'G3' 2),
    (N 'C3' 4)
)
Write-Wav 'music_menu.wav' (Build-Music $menuMel $menuBass 104)

# ---- Game music: upbeat, driving ----
$gameMel = @(
    (N 'C5' 0.5),(N 'E5' 0.5),(N 'G4' 0.5),(N 'C5' 0.5),(N 'A4' 0.5),(N 'C5' 0.5),(N 'E4' 0.5),(N 'G4' 0.5),
    (N 'D5' 0.5),(N 'F5' 0.5),(N 'A4' 0.5),(N 'D5' 0.5),(N 'B4' 0.5),(N 'D5' 0.5),(N 'G4' 0.5),(N 'B4' 0.5),
    (N 'C5' 0.5),(N 'E5' 0.5),(N 'G5' 1),(N 'E5' 0.5),(N 'C5' 1.5),
    (N 'G4' 0.5),(N 'B4' 0.5),(N 'D5' 1),(N 'G4' 0.5),(N 'D4' 1.5)
)
$gameBass = @(
    (N 'C3' 1),(N 'C3' 1),(N 'A3' 1),(N 'A3' 1),
    (N 'D3' 1),(N 'D3' 1),(N 'G3' 1),(N 'G3' 1),
    (N 'C3' 1),(N 'E3' 1),(N 'C3' 2),
    (N 'G3' 1),(N 'G3' 1),(N 'G3' 2)
)
Write-Wav 'music_game.wav' (Build-Music $gameMel $gameBass 150 0.2 0.17)

Write-Host 'Generating SFX...'

# Generic SFX helpers
function New-Sweep {
    param([double]$Dur, [double]$F0, [double]$F1, [string]$Wave = 'square', [double]$Amp = 0.35)
    $count = [int]($Dur * $rate)
    $buf = New-Object double[] $count
    $phase = 0.0
    for ($i = 0; $i -lt $count; $i++) {
        $t = $i / [double]$rate
        $frac = $i / [double]$count
        $f = $F0 + ($F1 - $F0) * $frac
        $phase += 2 * [math]::PI * $f / $rate
        $env = [math]::Min(1.0, ($count - $i) / ($count * 0.5))
        $atk = [math]::Min(1.0, $i / ($rate * 0.005))
        $s = if ($Wave -eq 'sine') { [math]::Sin($phase) } elseif ($Wave -eq 'tri') { (2/[math]::PI)*[math]::Asin([math]::Sin($phase)) } else { if ([math]::Sin($phase) -ge 0) {1.0} else {-1.0} }
        $buf[$i] = $s * $Amp * $env * $atk
    }
    return $buf
}

function New-Tone {
    param([double]$Dur, [double]$F, [string]$Wave = 'sine', [double]$Amp = 0.35)
    New-Sweep $Dur $F $F $Wave $Amp
}

function Concat-Buf { param([double[]]$A, [double[]]$B) $A + $B }

# Jump: quick upward blip
Write-Wav 'sfx_jump.wav' (New-Sweep 0.16 320 720 'square' 0.32)
# Coin: bright two-tone ding
Write-Wav 'sfx_coin.wav' (Concat-Buf (New-Tone 0.06 988 'square' 0.3) (New-Tone 0.12 1319 'square' 0.3))
# Egg collect: soft pop
Write-Wav 'sfx_egg.wav' (New-Sweep 0.12 500 900 'sine' 0.34)
# Hatch: happy 3-note chime
Write-Wav 'sfx_hatch.wav' (Concat-Buf (Concat-Buf (New-Tone 0.09 523 'square' 0.28) (New-Tone 0.09 659 'square' 0.28)) (New-Tone 0.16 784 'square' 0.3))
# Hit: harsh down-thud
Write-Wav 'sfx_hit.wav' (New-Sweep 0.22 300 90 'square' 0.4)
# Game over: descending sad arpeggio
Write-Wav 'sfx_gameover.wav' (Concat-Buf (Concat-Buf (New-Tone 0.14 392 'tri' 0.32) (New-Tone 0.14 311 'tri' 0.32)) (New-Tone 0.30 196 'tri' 0.34))
# Button: short click
Write-Wav 'sfx_button.wav' (New-Sweep 0.06 900 500 'square' 0.26)
# Purchase / reward: cash chime
Write-Wav 'sfx_reward.wav' (Concat-Buf (Concat-Buf (New-Tone 0.07 784 'square' 0.28) (New-Tone 0.07 988 'square' 0.28)) (New-Tone 0.18 1319 'square' 0.3))

Write-Host 'Done.'
