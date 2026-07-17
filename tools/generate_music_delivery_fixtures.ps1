param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

function Write-U16([System.IO.BinaryWriter]$Writer, [int]$Value) {
    $Writer.Write([byte]($Value -band 0xff))
    $Writer.Write([byte](($Value -shr 8) -band 0xff))
}

function Write-U32([System.IO.BinaryWriter]$Writer, [long]$Value) {
    $Writer.Write([byte]($Value -band 0xff))
    $Writer.Write([byte](($Value -shr 8) -band 0xff))
    $Writer.Write([byte](($Value -shr 16) -band 0xff))
    $Writer.Write([byte](($Value -shr 24) -band 0xff))
}

function Write-FourCC([System.IO.BinaryWriter]$Writer, [string]$Value) {
    $Writer.Write([Text.Encoding]::ASCII.GetBytes($Value))
}

function Write-Pcm24Fixture([string]$Path, [int]$Frames, [double]$Frequency) {
    $sampleRate = 44100
    $channels = 1
    $bits = 24
    $frameBytes = 3
    $dataBytes = [long]$Frames * $frameBytes
    # JUNK is deliberately odd-sized so the validator/loader prove correct
    # RIFF padding and non-audio chunk handling.
    $riffSize = 4 + (8 + 3 + 1) + (8 + 16) + (8 + $dataBytes)
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = [IO.BinaryWriter]::new($stream)
        Write-FourCC $writer "RIFF"
        Write-U32 $writer $riffSize
        Write-FourCC $writer "WAVE"
        Write-FourCC $writer "JUNK"
        Write-U32 $writer 3
        $writer.Write([byte[]](0x42, 0x54, 0x48))
        $writer.Write([byte]0)
        Write-FourCC $writer "fmt "
        Write-U32 $writer 16
        Write-U16 $writer 1
        Write-U16 $writer $channels
        Write-U32 $writer $sampleRate
        Write-U32 $writer ($sampleRate * $frameBytes)
        Write-U16 $writer $frameBytes
        Write-U16 $writer $bits
        Write-FourCC $writer "data"
        Write-U32 $writer $dataBytes
        $amplitude = 0.035 * 8388607.0
        for ($frame = 0; $frame -lt $Frames; $frame++) {
            # Quiet deterministic reference tone; this is deliberately a test
            # signal and is never represented as production music.
            $envelope = if ($frame -lt 2205) { $frame / 2205.0 } elseif ($frame -gt $Frames - 2206) { ($Frames - 1 - $frame) / 2205.0 } else { 1.0 }
            $sample = [int][Math]::Round([Math]::Sin(2.0 * [Math]::PI * $Frequency * $frame / $sampleRate) * $amplitude * $envelope)
            if ($sample -lt 0) { $sample += 0x1000000 }
            $writer.Write([byte]($sample -band 0xff))
            $writer.Write([byte](($sample -shr 8) -band 0xff))
            $writer.Write([byte](($sample -shr 16) -band 0xff))
        }
        $writer.Flush()
        $writer.Dispose()
    }
    finally {
        $stream.Dispose()
    }
}

$fixture8 = Join-Path $ProjectRoot "assets/audio/music/jazz_club_delivery_fixture_8_bar"
$fixture16 = Join-Path $ProjectRoot "assets/audio/music/jazz_club_delivery_fixture_16_bar"
$eightBarFrames = 705600
$sixteenBarFrames = 1411200

Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Chords_Piano_1.wav") $eightBarFrames 130.81
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Chords_Guitar_1.wav") $eightBarFrames 164.81
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Chords_Piano_2.wav") $eightBarFrames 110.00
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Bass_UprightBass_1.wav") $eightBarFrames 65.41
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Bass_UprightBass_2.wav") $eightBarFrames 55.00
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Bass_UprightBass_3.wav") $eightBarFrames 73.42
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Lead_Trumpet_1.wav") $eightBarFrames 261.63
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_DrumsHigh_BrushKit_1.wav") $eightBarFrames 196.00
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Fill_BrushKit_1.wav") 44100 174.61
Write-Pcm24Fixture (Join-Path $fixture8 "JazzClub_Stinger_Trumpet_1.wav") 44100 329.63
Write-Pcm24Fixture (Join-Path $fixture16 "JazzClub_Chords_Piano_2.wav") $sixteenBarFrames 146.83

Write-Host "Generated clearly labelled 24-bit PCM Jazz delivery fixtures under assets/audio/music/."
