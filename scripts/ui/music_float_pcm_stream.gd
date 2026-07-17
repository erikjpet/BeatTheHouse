class_name MusicFloatPcmStream
extends AudioStreamGenerator

# Cached 24-bit integer PCM decoded into Godot mixer float frames. Playback is
# fed by ProceduralMusicPlayer so all parallel stems share one source cursor.

var pcm_frames := PackedVector2Array()
var source_channels := 1
var source_bit_depth := 24
var frame_count := 0
var loop_enabled := true
var loop_begin_frame := 0
var loop_end_frame := 0
var samples_beyond_16_bit := 0
var max_reconstruction_error_lsb := 0


func configure(source_frames: PackedVector2Array, sample_rate: int, channels: int, should_loop: bool, loop_begin: int, loop_end: int, precision_samples: int, reconstruction_error_lsb: int) -> void:
	pcm_frames = source_frames
	mix_rate = maxi(1, sample_rate)
	buffer_length = 0.25
	source_channels = clampi(channels, 1, 2)
	frame_count = pcm_frames.size()
	loop_enabled = should_loop
	loop_begin_frame = clampi(loop_begin, 0, maxi(0, frame_count - 1))
	loop_end_frame = clampi(loop_end if loop_end > 0 else frame_count, loop_begin_frame + 1, frame_count)
	samples_beyond_16_bit = maxi(0, precision_samples)
	max_reconstruction_error_lsb = maxi(0, reconstruction_error_lsb)


func frame_at(index: int) -> Vector2:
	return pcm_frames[index] if index >= 0 and index < pcm_frames.size() else Vector2.ZERO


func precision_snapshot() -> Dictionary:
	return {
		"provider": "cached_float_pcm_generator",
		"source_bit_depth": source_bit_depth,
		"mixer_sample_type": "float32_stereo_frames",
		"frames": frame_count,
		"samples_beyond_16_bit": samples_beyond_16_bit,
		"max_reconstruction_error_lsb": max_reconstruction_error_lsb,
		"low_order_information_preserved": samples_beyond_16_bit > 0 and max_reconstruction_error_lsb <= 1,
		"phase_model": "director_position_authoritative_group_launch",
	}


static func pcm24_to_float(sample_24: int) -> float:
	return clampf(float(sample_24) / 8388608.0, -1.0, 8388607.0 / 8388608.0)
