param(
	[switch]$SkipCapture,
	[switch]$SkipCards,
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

function Get-TrailerMarker {
	param(
		[string]$Segment,
		[string]$Marker = "active",
		[double]$Offset = 0.0
	)
	$timingPath = Join-Path $RuntimeRoot "timing_${Segment}.json"
	if (-not (Test-Path -LiteralPath $timingPath)) {
		throw "Missing timing markers for ${Segment}: $timingPath"
	}
	$timing = Get-Content -Raw -LiteralPath $timingPath | ConvertFrom-Json
	$property = $timing.markers.PSObject.Properties[$Marker]
	if ($null -eq $property) {
		throw "Marker '$Marker' is missing for trailer segment '$Segment'."
	}
	return [Math]::Max(0.0, [double]$property.Value + $Offset)
}

function New-GameplayClip {
	param(
		[string]$ClipId,
		[string]$Segment,
		[double]$Duration,
		[string]$Marker = "active",
		[double]$MarkerOffset = 0.0,
		[string]$OverlayId = "",
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
	$start = Get-TrailerMarker -Segment $Segment -Marker $Marker -Offset $MarkerOffset
	$filter = "scale=1920:1080:flags=neighbor,setsar=1,fps=60"
	if ($Vertical) {
		$filter = "crop=405:720:${CropX}:0,scale=1080:1920:flags=neighbor,setsar=1,fps=60"
	}
	$commonOutput = @(
		"-t", $Duration.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
		"-an",
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "14",
		"-pix_fmt", "yuv420p",
		"-r", "60",
		"-video_track_timescale", "60000",
		"-movflags", "+faststart",
		"-y", $output
	)
	if ([string]::IsNullOrWhiteSpace($OverlayId)) {
		Invoke-Ffmpeg (@(
			"-hide_banner", "-loglevel", "warning",
			"-ss", $start.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
			"-i", $input,
			"-vf", $filter
		) + $commonOutput) "clip $ClipId"
	} else {
		$suffix = "vertical"
		if (-not $Vertical) {
			$suffix = "1080p"
		}
		$overlay = Join-Path $CardRoot "${OverlayId}_${suffix}.png"
		if (-not (Test-Path -LiteralPath $overlay)) {
			throw "Missing trailer overlay: $overlay"
		}
		$complex = "[0:v]${filter}[base];[base][1:v]overlay=0:0:format=auto,format=yuv420p[outv]"
		Invoke-Ffmpeg (@(
			"-hide_banner", "-loglevel", "warning",
			"-ss", $start.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
			"-i", $input,
			"-loop", "1", "-i", $overlay,
			"-filter_complex", $complex,
			"-map", "[outv]"
		) + $commonOutput) "clip $ClipId"
	}
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
	if (-not $SkipCards) {
		python "tools\generate_trailer_cards.py"
		Assert-ExitCode "trailer-overlay generation"
	}

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

	$music = Join-Path $TempRoot "music_bed_30s.wav"
	$musicPeak = Join-Path $TempRoot "music_peak_16s.wav"
	$musicStart = Get-TrailerMarker -Segment "music_bed"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-ss", $musicStart.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
		"-i", (Join-Path $RawRoot "music_bed.avi"),
		"-t", "16",
		"-vn",
		"-ar", "48000",
		"-ac", "2",
		"-c:a", "pcm_s16le",
		"-y", $musicPeak
	) "music-peak extraction"
	Invoke-Ffmpeg @(
		"-hide_banner", "-loglevel", "warning",
		"-stream_loop", "2",
		"-i", $musicPeak,
		"-t", "30",
		"-vn",
		"-af", "loudnorm=I=-15:LRA=8:TP=-1.5,afade=t=in:st=0:d=0.08,afade=t=out:st=29.5:d=0.5",
		"-ar", "48000",
		"-ac", "2",
		"-c:a", "pcm_s16le",
		"-y", $music
	) "upbeat music-bed assembly"

	$full = @()
	$full += New-GameplayClip "00_hook" "rourke_duel" 1.0 -Marker "duel_ready"
	$full += New-GameplayClip "01_logo" "game_roulette" 2.4 -Marker "action_roulette_spin_1" -MarkerOffset -0.15 -OverlayId "logo"
	$full += New-GameplayClip "02_roadside" "roadside" 2.0 -OverlayId "eight_games"
	$full += New-GameplayClip "03_blackjack" "game_blackjack" 1.0
	$full += New-GameplayClip "04_roulette" "game_roulette" 1.0 -Marker "action_roulette_spin_1" -MarkerOffset -0.15
	$full += New-GameplayClip "05_slot" "game_slot" 1.0
	$full += New-GameplayClip "06_scratch" "game_scratch_tickets" 0.5 -Marker "action_scratch_all_1" -MarkerOffset -0.15
	$full += New-GameplayClip "07_bar_dice" "game_bar_dice" 1.0
	$full += New-GameplayClip "08_baccarat" "game_baccarat" 1.0 -Marker "action_baccarat_deal_1" -MarkerOffset -0.15
	$full += New-GameplayClip "09_video_poker" "game_video_poker" 0.75 -Marker "action_video_poker_draw_1" -MarkerOffset -0.15
	$full += New-GameplayClip "10_pull_tabs" "game_pull_tabs" 0.75 -Marker "action_pull_tab_collect_tray_1" -MarkerOffset -0.15
	$full += New-GameplayClip "11_heat_cheat" "heat_cheat" 2.5 -OverlayId "cheat_dare"
	$full += New-GameplayClip "12_grand" "grand_casino" 2.5 -OverlayId "beat_house"
	$full += New-GameplayClip "14_call" "rourke_call" 2.5
	$full += New-GameplayClip "15_duel" "rourke_duel" 1.1 -Marker "duel_ready"
	$full += New-GameplayClip "16_payoff_roulette" "game_roulette" 0.75 -Marker "action_roulette_spin_1" -MarkerOffset -0.1
	$full += New-GameplayClip "17_payoff_slot" "game_slot" 0.75
	$full += New-GameplayClip "18_payoff_dice" "game_bar_dice" 0.75
	$full += New-GameplayClip "19_payoff_baccarat" "game_baccarat" 0.75 -Marker "action_baccarat_deal_1" -MarkerOffset -0.1
	$full += New-GameplayClip "20_payoff_scratch" "game_scratch_tickets" 0.75 -Marker "action_scratch_all_1" -MarkerOffset -0.1
	$full += New-GameplayClip "21_payoff_poker" "game_video_poker" 0.75 -Marker "action_video_poker_draw_1" -MarkerOffset -0.1
	$full += New-GameplayClip "22_cta_roulette" "game_roulette" 0.9 -Marker "action_roulette_spin_1" -MarkerOffset -0.1 -OverlayId "cta"
	$full += New-GameplayClip "23_cta_slot" "game_slot" 0.9 -OverlayId "cta"
	$full += New-GameplayClip "24_cta_scratch" "game_scratch_tickets" 0.9 -Marker "action_scratch_all_1" -MarkerOffset -0.1 -OverlayId "cta"
	$full += New-GameplayClip "25_cta_dice" "game_bar_dice" 0.9 -OverlayId "cta"
	$full += New-GameplayClip "26_cta_baccarat" "game_baccarat" 0.9 -Marker "action_baccarat_deal_1" -MarkerOffset -0.1 -OverlayId "cta"
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
		"-t", "30",
		"-movflags", "+faststart",
		"-y", $fullOutput
	) "1080p trailer assembly"

	$vertical = @()
	$vertical += New-GameplayClip "00_hook" "rourke_duel" 1.0 -Marker "duel_ready" -Vertical
	$vertical += New-GameplayClip "01_logo" "game_roulette" 2.15 -OverlayId "logo" -Vertical
	$vertical += New-GameplayClip "02_blackjack" "game_blackjack" 0.75 -Vertical
	$vertical += New-GameplayClip "03_roulette" "game_roulette" 0.75 -Marker "action_roulette_spin_1" -MarkerOffset -0.1 -Vertical
	$vertical += New-GameplayClip "04_slot" "game_slot" 0.75 -Vertical
	$vertical += New-GameplayClip "05_scratch" "game_scratch_tickets" 0.5 -Marker "action_scratch_all_1" -MarkerOffset -0.1 -Vertical
	$vertical += New-GameplayClip "06_bar_dice" "game_bar_dice" 0.75 -Vertical
	$vertical += New-GameplayClip "07_baccarat" "game_baccarat" 0.75 -Marker "action_baccarat_deal_1" -MarkerOffset -0.1 -Vertical
	$vertical += New-GameplayClip "08_video_poker" "game_video_poker" 0.75 -Marker "action_video_poker_draw_1" -MarkerOffset -0.1 -Vertical
	$vertical += New-GameplayClip "09_pull_tabs" "game_pull_tabs" 0.75 -Marker "action_pull_tab_collect_tray_1" -MarkerOffset -0.1 -Vertical
	$vertical += New-GameplayClip "10_heat" "heat_cheat" 2.0 -OverlayId "cheat_dare" -Vertical
	$vertical += New-GameplayClip "11_grand" "grand_casino" 1.5 -OverlayId "beat_house" -Vertical
	$vertical += New-GameplayClip "13_call" "rourke_call" 2.0 -Vertical
	$vertical += New-GameplayClip "14_duel" "rourke_duel" 1.1 -Marker "duel_ready" -Vertical
	$vertical += New-GameplayClip "15_payoff_roulette" "game_roulette" 0.5 -Marker "action_roulette_spin_1" -MarkerOffset -0.05 -Vertical
	$vertical += New-GameplayClip "16_payoff_slot" "game_slot" 0.5 -Vertical
	$vertical += New-GameplayClip "17_payoff_scratch" "game_scratch_tickets" 0.5 -Marker "action_scratch_all_1" -MarkerOffset -0.05 -Vertical
	$vertical += New-GameplayClip "18_payoff_dice" "game_bar_dice" 0.5 -Vertical
	$vertical += New-GameplayClip "19_payoff_baccarat" "game_baccarat" 0.5 -Marker "action_baccarat_deal_1" -MarkerOffset -0.05 -Vertical
	$vertical += New-GameplayClip "20_cta_roulette" "game_roulette" 0.8 -Marker "action_roulette_spin_1" -MarkerOffset -0.05 -OverlayId "cta" -Vertical
	$vertical += New-GameplayClip "21_cta_slot" "game_slot" 0.8 -OverlayId "cta" -Vertical
	$vertical += New-GameplayClip "22_cta_scratch" "game_scratch_tickets" 0.8 -Marker "action_scratch_all_1" -MarkerOffset -0.05 -OverlayId "cta" -Vertical
	$vertical += New-GameplayClip "23_cta_dice" "game_bar_dice" 0.8 -OverlayId "cta" -Vertical
	$vertical += New-GameplayClip "24_cta_baccarat" "game_baccarat" 0.8 -Marker "action_baccarat_deal_1" -MarkerOffset -0.05 -OverlayId "cta" -Vertical
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
		"-t", "22",
		"-movflags", "+faststart",
		"-y", $verticalOutput
	) "vertical trailer assembly"

	$loop = @(
		(New-GameplayClip "00_loop_roulette" "game_roulette" 0.8 -Marker "action_roulette_spin_1" -MarkerOffset -0.05),
		(New-GameplayClip "01_loop_slot" "game_slot" 0.8),
		(New-GameplayClip "02_loop_scratch" "game_scratch_tickets" 0.8 -Marker "action_scratch_all_1" -MarkerOffset -0.05),
		(New-GameplayClip "03_loop_dice" "game_bar_dice" 0.8),
		(New-GameplayClip "04_loop_baccarat" "game_baccarat" 0.8 -Marker "action_baccarat_deal_1" -MarkerOffset -0.05),
		(New-GameplayClip "05_loop_blackjack" "game_blackjack" 0.8),
		(New-GameplayClip "06_loop_roulette" "game_roulette" 0.8 -Marker "action_roulette_spin_1" -MarkerOffset 0.15),
		(New-GameplayClip "07_loop_slot" "game_slot" 0.8 -MarkerOffset 0.25),
		(New-GameplayClip "08_loop_scratch" "game_scratch_tickets" 0.8 -Marker "action_scratch_all_1" -MarkerOffset 0.15),
		(New-GameplayClip "09_loop_duel" "rourke_duel" 0.8 -Marker "duel_ready")
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
