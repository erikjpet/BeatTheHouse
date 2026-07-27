param(
	[switch]$SkipCapture,
	[switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TrailerRoot = Join-Path $Root "branding\trailer"
$TempRoot = Join-Path $Root ".tmp\trailer"
$RawRoot = Join-Path $TempRoot "raw"
$ClipRoot = Join-Path $TempRoot "clips"
$RuntimeRoot = Join-Path $TempRoot "runtime"
$CardRoot = Join-Path $TrailerRoot "cards"
$Godot = Join-Path $Root ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"

function Resolve-Tool {
	param(
		[string]$Name
	)
	$command = Get-Command $Name -ErrorAction SilentlyContinue
	if ($null -ne $command) {
		return $command.Source
	}
	$packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
	if (Test-Path -LiteralPath $packageRoot) {
		$match = Get-ChildItem -LiteralPath $packageRoot -Recurse -Filter "$Name.exe" -ErrorAction SilentlyContinue |
			Where-Object { $_.FullName -match "Gyan\.FFmpeg" } |
			Select-Object -First 1
		if ($null -ne $match) {
			return $match.FullName
		}
	}
	throw "$Name.exe was not found. Install Gyan.FFmpeg with winget before rendering."
}

function Assert-ExitCode {
	param(
		[string]$Label
	)
	if ($LASTEXITCODE -ne 0) {
		throw "$Label failed with exit code $LASTEXITCODE."
	}
}

function Invoke-Ffmpeg {
	param(
		[string[]]$Arguments,
		[string]$Label
	)
	& $script:Ffmpeg @Arguments
	Assert-ExitCode $Label
}

function New-GameplayClip {
	param(
		[string]$ClipId,
		[string]$Segment,
		[double]$Start,
		[double]$Duration,
		[int]$CropX = 437,
		[switch]$Vertical
	)
	$folderName = "vertical"
	if (-not $Vertical) {
		$folderName = "full"
	}
	$folder = Join-Path $ClipRoot $folderName
	New-Item -ItemType Directory -Force -Path $folder | Out-Null
	$output = Join-Path $folder "$ClipId.mp4"
	if ((Test-Path -LiteralPath $output) -and -not $Force) {
		return $output
	}
	$input = Join-Path $RawRoot "$Segment.avi"
	if (-not (Test-Path -LiteralPath $input)) {
		throw "Missing raw trailer segment: $input"
	}
	$filter = "scale=1920:1080:flags=neighbor,setsar=1,fps=60"
	if ($Vertical) {
		$filter = "crop=405:720:${CropX}:0,scale=1080:1920:flags=neighbor,setsar=1,fps=60"
	}
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-ss", $Start.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
		"-i", $input,
		"-t", $Duration.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
		"-an",
		"-vf", $filter,
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "14",
		"-pix_fmt", "yuv420p",
		"-r", "60",
		"-video_track_timescale", "60000",
		"-movflags", "+faststart",
		"-y", $output
	) "clip $ClipId"
	return $output
}

function New-CardClip {
	param(
		[string]$ClipId,
		[string]$CardId,
		[double]$Duration,
		[switch]$Vertical
	)
	$folderName = "vertical"
	if (-not $Vertical) {
		$folderName = "full"
	}
	$folder = Join-Path $ClipRoot $folderName
	New-Item -ItemType Directory -Force -Path $folder | Out-Null
	$output = Join-Path $folder "$ClipId.mp4"
	if ((Test-Path -LiteralPath $output) -and -not $Force) {
		return $output
	}
	$suffix = "vertical"
	if (-not $Vertical) {
		$suffix = "1080p"
	}
	$input = Join-Path $CardRoot "${CardId}_${suffix}.png"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-loop", "1",
		"-framerate", "60",
		"-i", $input,
		"-t", $Duration.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
		"-an",
		"-vf", "fps=60,format=yuv420p",
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "14",
		"-pix_fmt", "yuv420p",
		"-r", "60",
		"-video_track_timescale", "60000",
		"-movflags", "+faststart",
		"-y", $output
	) "card clip $ClipId"
	return $output
}

function Write-ConcatList {
	param(
		[string]$Path,
		[string[]]$Files
	)
	$lines = @()
	foreach ($file in $Files) {
		$resolved = (Resolve-Path -LiteralPath $file).Path.Replace("\", "/").Replace("'", "''")
		$lines += "file '$resolved'"
	}
	Set-Content -LiteralPath $Path -Value $lines -Encoding ASCII
}

if (-not (Test-Path -LiteralPath $Godot)) {
	throw "Godot 4.6 is missing at $Godot"
}
$Ffmpeg = Resolve-Tool "ffmpeg"
$Ffprobe = Resolve-Tool "ffprobe"
New-Item -ItemType Directory -Force -Path $TrailerRoot, $RawRoot, $ClipRoot, $RuntimeRoot | Out-Null

Push-Location $Root
try {
	python "tools\generate_trailer_cards.py"
	Assert-ExitCode "title-card generation"

	$segments = @(
		"music_bed",
		"roadside",
		"game_blackjack",
		"game_roulette",
		"game_slot",
		"game_scratch_tickets",
		"game_bar_dice",
		"game_baccarat",
		"game_video_poker",
		"game_pull_tabs",
		"heat_cheat",
		"world_map",
		"grand_casino",
		"cage_card",
		"rourke_call",
		"rourke_duel"
	)
	if (-not $SkipCapture) {
		foreach ($segment in $segments) {
			$output = Join-Path $RawRoot "$segment.avi"
			if ((Test-Path -LiteralPath $output) -and -not $Force) {
				Write-Host "Reuse raw segment: $segment"
				continue
			}
			Write-Host "Capture segment: $segment"
			& $Godot --path $Root --fixed-fps 60 --write-movie $output --script res://tools/trailer_capture.gd -- "--segment=$segment" "--runtime-dir=.tmp/trailer/runtime"
			Assert-ExitCode "capture $segment"
		}
	}

	$music = Join-Path $TempRoot "music_bed_60s.wav"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-ss", "8.0",
		"-i", (Join-Path $RawRoot "music_bed.avi"),
		"-t", "60",
		"-vn",
		"-af", "loudnorm=I=-16:LRA=10:TP=-1.5,afade=t=in:st=0:d=0.15,afade=t=out:st=59.5:d=0.5",
		"-ar", "48000",
		"-ac", "2",
		"-c:a", "pcm_s16le",
		"-y", $music
	) "music-bed extraction"

	$full = @()
	$full += New-GameplayClip "00_hook" "rourke_duel" 2.75 2.5
	$full += New-CardClip "01_logo" "logo" 1.5
	$full += New-GameplayClip "02_roadside" "roadside" 2.42 5.5
	$full += New-CardClip "03_eight_games" "eight_games" 1.0
	$full += New-GameplayClip "04_blackjack" "game_blackjack" 2.85 1.5
	$full += New-GameplayClip "05_roulette" "game_roulette" 3.45 1.5
	$full += New-GameplayClip "06_slot" "game_slot" 2.75 1.5
	$full += New-GameplayClip "07_scratch" "game_scratch_tickets" 3.25 1.5
	$full += New-GameplayClip "08_bar_dice" "game_bar_dice" 2.75 1.5
	$full += New-GameplayClip "09_baccarat" "game_baccarat" 3.45 1.5
	$full += New-GameplayClip "10_video_poker" "game_video_poker" 2.75 1.5
	$full += New-GameplayClip "11_pull_tabs" "game_pull_tabs" 2.75 1.5
	$full += New-GameplayClip "12_slot_result" "game_slot" 4.65 1.5
	$full += New-CardClip "13_dodge_heat" "dodge_heat" 1.0
	$full += New-GameplayClip "14_heat" "heat_cheat" 2.75 4.0
	$full += New-CardClip "15_cheat" "cheat_dare" 1.0
	$full += New-GameplayClip "16_cheat_action" "heat_cheat" 4.75 4.0
	$full += New-CardClip "17_beat_house" "beat_house" 1.0
	$full += New-GameplayClip "18_map" "world_map" 2.68 5.0
	$full += New-GameplayClip "19_grand" "grand_casino" 2.32 5.0
	$full += New-GameplayClip "20_cage" "cage_card" 2.52 4.0
	$full += New-GameplayClip "21_call" "rourke_call" 2.30 3.0
	$full += New-GameplayClip "22_duel" "rourke_duel" 2.75 3.5
	$full += New-CardClip "23_cta" "cta" 4.5
	$fullList = Join-Path $TempRoot "full_concat.txt"
	Write-ConcatList $fullList $full

	$fullOutput = Join-Path $TrailerRoot "beat_the_house_trailer_1080p.mp4"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-f", "concat", "-safe", "0", "-i", $fullList,
		"-i", $music,
		"-map", "0:v:0", "-map", "1:a:0",
		"-c:v", "copy",
		"-c:a", "aac", "-b:a", "192k", "-ar", "48000",
		"-t", "60",
		"-movflags", "+faststart",
		"-y", $fullOutput
	) "1080p trailer assembly"

	$vertical = @()
	$vertical += New-GameplayClip "00_hook" "rourke_duel" 2.75 2.5 -Vertical
	$vertical += New-CardClip "01_logo" "logo" 1.5 -Vertical
	$vertical += New-GameplayClip "02_roadside" "roadside" 2.42 3.0 -Vertical
	$vertical += New-CardClip "03_eight_games" "eight_games" 1.0 -Vertical
	$vertical += New-GameplayClip "04_blackjack" "game_blackjack" 2.85 1.5 -Vertical
	$vertical += New-GameplayClip "05_roulette" "game_roulette" 3.45 1.5 -Vertical
	$vertical += New-GameplayClip "06_slot" "game_slot" 2.75 1.5 -Vertical
	$vertical += New-GameplayClip "07_scratch" "game_scratch_tickets" 3.25 1.5 -Vertical
	$vertical += New-GameplayClip "08_bar_dice" "game_bar_dice" 2.75 1.5 -Vertical
	$vertical += New-GameplayClip "09_baccarat" "game_baccarat" 3.45 1.5 -Vertical
	$vertical += New-GameplayClip "10_video_poker" "game_video_poker" 2.75 1.5 -Vertical
	$vertical += New-GameplayClip "11_pull_tabs" "game_pull_tabs" 2.75 1.5 -Vertical
	$vertical += New-CardClip "12_dodge_heat" "dodge_heat" 1.0 -Vertical
	$vertical += New-GameplayClip "13_heat" "heat_cheat" 2.75 3.0 -Vertical
	$vertical += New-CardClip "14_cheat" "cheat_dare" 1.0 -Vertical
	$vertical += New-GameplayClip "15_cheat_action" "heat_cheat" 4.75 3.0 -Vertical
	$vertical += New-CardClip "16_beat_house" "beat_house" 1.0 -Vertical
	$vertical += New-GameplayClip "17_map" "world_map" 2.68 3.0 -Vertical
	$vertical += New-GameplayClip "18_grand" "grand_casino" 2.32 3.0 -Vertical
	$vertical += New-GameplayClip "19_cage" "cage_card" 2.52 3.0 -CropX 300 -Vertical
	$vertical += New-GameplayClip "20_call" "rourke_call" 2.30 2.5 -Vertical
	$vertical += New-GameplayClip "21_duel" "rourke_duel" 2.75 2.5 -Vertical
	$vertical += New-CardClip "22_cta" "cta" 2.0 -Vertical
	$verticalList = Join-Path $TempRoot "vertical_concat.txt"
	Write-ConcatList $verticalList $vertical

	$verticalOutput = Join-Path $TrailerRoot "beat_the_house_trailer_vertical.mp4"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-f", "concat", "-safe", "0", "-i", $verticalList,
		"-i", $music,
		"-map", "0:v:0", "-map", "1:a:0",
		"-c:v", "copy",
		"-c:a", "aac", "-b:a", "192k", "-ar", "48000",
		"-t", "45",
		"-movflags", "+faststart",
		"-y", $verticalOutput
	) "vertical trailer assembly"

	$loop = @(
		(New-GameplayClip "00_roulette" "game_roulette" 3.45 1.5),
		(New-GameplayClip "01_slot" "game_slot" 2.75 1.5),
		(New-GameplayClip "02_scratch" "game_scratch_tickets" 3.25 1.5),
		(New-GameplayClip "03_grand" "grand_casino" 2.32 2.0),
		(New-GameplayClip "04_duel" "rourke_duel" 2.75 1.5)
	)
	$loopList = Join-Path $TempRoot "loop_concat.txt"
	Write-ConcatList $loopList $loop
	$loopOutput = Join-Path $TrailerRoot "beat_the_house_trailer_loop.webm"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-f", "concat", "-safe", "0", "-i", $loopList,
		"-an",
		"-vf", "fps=30",
		"-c:v", "libvpx-vp9",
		"-crf", "32",
		"-b:v", "0",
		"-row-mt", "1",
		"-pix_fmt", "yuv420p",
		"-t", "8",
		"-y", $loopOutput
	) "header loop assembly"

	foreach ($deliverable in @($fullOutput, $verticalOutput, $loopOutput)) {
		& $Ffprobe -v error -show_entries stream=codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels -show_entries format=duration,size -of json $deliverable
		Assert-ExitCode "probe $deliverable"
	}
}
finally {
	Pop-Location
}
