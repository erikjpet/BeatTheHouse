class_name WebAudioBridge
extends RefCounted

static var _ensured := false
static var _last_music_payload_key := ""
static var _last_music_mix_keys: Dictionary = {}
static var _last_music_mix_msec: Dictionary = {}
static var _registered_pcm_keys: Dictionary = {}
static var _active_music_groups: Dictionary = {}
static var _eval_counts: Dictionary = {}
static var _eval_bytes := 0

const WEB_AUDIO_VERSION := 3
const WEB_MASTER_GAIN := 0.72
const WEB_OUTPUT_GAIN := 0.92
const WEB_HIGHPASS_HZ := 38.0
const WEB_COMPRESSOR_THRESHOLD_DB := -6.0
const WEB_COMPRESSOR_RATIO := 3.0
const WEB_SFX_MAX_GAIN := 1.25
const WEB_AUDIO_BRIDGE_ENABLED := true
const WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED := false
const WEB_MUSIC_MIX_MIN_INTERVAL_MSEC := 140
const WEB_MUSIC_STEM_ROLES := ["pad", "bass", "bass_dark", "lead", "drums_low", "drums_high", "drums_high_double", "tension", "texture"]

const WEB_AUDIO_SCRIPT := """
(function () {
	var BRIDGE_VERSION = 3;
	if (window.BTHWebAudio && window.BTHWebAudio.version === BRIDGE_VERSION) {
		return true;
	}
	if (window.BTHWebAudio && window.BTHWebAudio.stopAll) {
		try {
			window.BTHWebAudio.stopAll();
		} catch (_error) {
		}
	} else if (window.BTHWebAudio && window.BTHWebAudio.stopMusic) {
		try {
			window.BTHWebAudio.stopMusic();
		} catch (_error) {
		}
	}
	function clamp(value, minValue, maxValue) {
		return Math.max(minValue, Math.min(maxValue, value));
	}
	function dbToGain(db) {
		return Math.pow(10, clamp(Number(db || 0), -80, 12) / 20);
	}
	function stopNode(node) {
		if (!node) {
			return;
		}
		try {
			node.stop();
		} catch (_error) {
		}
		try {
			node.disconnect();
		} catch (_error) {
		}
	}
	function base64ToBytes(data) {
		var binary = window.atob(String(data || ""));
		var bytes = new Uint8Array(binary.length);
		for (var index = 0; index < binary.length; index += 1) {
			bytes[index] = binary.charCodeAt(index) & 255;
		}
		return bytes;
	}
	function decodePcm16(payload, ctx) {
		var channels = Math.max(1, Math.min(2, Number(payload.channels || 1) | 0));
		var sampleRate = Math.max(1, Number(payload.sample_rate || 22050) | 0);
		var bytes = base64ToBytes(payload.data);
		var frames = Math.max(1, Math.floor(bytes.length / (channels * 2)));
		var buffer = ctx.createBuffer(channels, frames, sampleRate);
		for (var channel = 0; channel < channels; channel += 1) {
			var output = buffer.getChannelData(channel);
			var byteIndex = channel * 2;
			for (var frame = 0; frame < frames; frame += 1) {
				var lo = bytes[byteIndex] || 0;
				var hi = bytes[byteIndex + 1] || 0;
				var sample = (hi << 8) | lo;
				if (sample >= 32768) {
					sample -= 65536;
				}
				output[frame] = clamp(sample / 32768, -1, 1);
				byteIndex += channels * 2;
			}
		}
		return buffer;
	}
	function stopEntry(entry) {
		if (!entry) {
			return;
		}
		stopNode(entry.source);
		try {
			if (entry.gain) {
				entry.gain.disconnect();
			}
		} catch (_error) {
		}
	}
	window.BTHWebAudio = {
		version: BRIDGE_VERSION,
		ctx: null,
		master: null,
		output: null,
		highpass: null,
		compressor: null,
		sfxBus: null,
		musicBus: null,
		pcmBuffers: {},
		sfxLoops: {},
		musicGroups: {},
		unlocked: false,
		ensure: function () {
			var AudioCtor = window.AudioContext || window.webkitAudioContext;
			if (!AudioCtor) {
				return false;
			}
			if (this.ctx) {
				return true;
			}
			this.ctx = new AudioCtor();
			this.master = this.ctx.createGain();
			this.output = this.ctx.createGain();
			this.highpass = this.ctx.createBiquadFilter();
			this.compressor = this.ctx.createDynamicsCompressor();
			this.sfxBus = this.ctx.createGain();
			this.musicBus = this.ctx.createGain();
			this.master.gain.value = 0.72;
			this.output.gain.value = 0.92;
			this.sfxBus.gain.value = 1.0;
			this.musicBus.gain.value = 1.0;
			this.highpass.type = "highpass";
			this.highpass.frequency.value = 38;
			this.highpass.Q.value = 0.707;
			this.compressor.threshold.value = -6;
			this.compressor.knee.value = 12;
			this.compressor.ratio.value = 3;
			this.compressor.attack.value = 0.003;
			this.compressor.release.value = 0.18;
			this.sfxBus.connect(this.master);
			this.musicBus.connect(this.master);
			this.master.connect(this.highpass);
			this.highpass.connect(this.compressor);
			this.compressor.connect(this.output);
			this.output.connect(this.ctx.destination);
			return true;
		},
		unlock: function () {
			if (!this.ensure()) {
				return false;
			}
			this.unlocked = true;
			if (this.ctx.state !== "running") {
				this.ctx.resume();
			}
			return true;
		},
		registerPcm: function (payload) {
			payload = payload || {};
			if (!this.ensure()) {
				return false;
			}
			var key = String(payload.key || "");
			if (!key) {
				return false;
			}
			if (this.pcmBuffers[key]) {
				return true;
			}
			if (!payload.data) {
				return false;
			}
			this.pcmBuffers[key] = decodePcm16(payload, this.ctx);
			return true;
		},
		playPcm: function (payload) {
			payload = payload || {};
			if (!this.unlock() || !this.registerPcm(payload)) {
				return false;
			}
			var ctx = this.ctx;
			var key = String(payload.key || "");
			var buffer = this.pcmBuffers[key];
			if (!buffer) {
				return false;
			}
			var source = ctx.createBufferSource();
			var gain = ctx.createGain();
			var isLoop = !!payload.loop;
			var loopId = String(payload.loop_id || "");
			source.buffer = buffer;
			source.loop = isLoop;
			source.playbackRate.value = clamp(Number(payload.pitch || 1), 0.35, 2.5);
			if (isLoop) {
				var loopStart = Math.max(0, Number(payload.loop_begin_frame || 0)) / Math.max(1, Number(payload.sample_rate || buffer.sampleRate));
				var loopEnd = Math.max(loopStart + 0.001, Number(payload.loop_end_frame || 0) / Math.max(1, Number(payload.sample_rate || buffer.sampleRate)));
				source.loopStart = clamp(loopStart, 0, buffer.duration);
				source.loopEnd = clamp(loopEnd, source.loopStart + 0.001, buffer.duration);
			}
			gain.gain.value = clamp(dbToGain(payload.volume_db), 0, 1.25);
			source.connect(gain);
			gain.connect(this.sfxBus);
			if (loopId) {
				this.stopLoop(loopId);
			}
			var entry = { source: source, gain: gain, key: key };
			source.onended = function () {
				try {
					gain.disconnect();
				} catch (_error) {
				}
				if (loopId && window.BTHWebAudio && window.BTHWebAudio.sfxLoops[loopId] === entry) {
					delete window.BTHWebAudio.sfxLoops[loopId];
				}
			};
			if (loopId) {
				this.sfxLoops[loopId] = entry;
			}
			source.start(0);
			return true;
		},
		stopLoop: function (loopId) {
			loopId = String(loopId || "");
			if (!loopId || !this.sfxLoops[loopId]) {
				return true;
			}
			stopEntry(this.sfxLoops[loopId]);
			delete this.sfxLoops[loopId];
			return true;
		},
		playMusicStems: function (payload) {
			payload = payload || {};
			if (!this.unlock()) {
				return false;
			}
			var groupId = String(payload.group_id || "music");
			var stems = Array.isArray(payload.stems) ? payload.stems : [];
			if (!stems.length) {
				return false;
			}
			this.stopMusic({ group_id: groupId });
			var ctx = this.ctx;
			var group = {
				key: String(payload.stem_set_key || ""),
				sources: {},
				gains: {},
				startedAt: ctx.currentTime,
				position: Math.max(0, Number(payload.position || 0))
			};
			for (var index = 0; index < stems.length; index += 1) {
				var stem = stems[index] || {};
				var role = String(stem.role || "");
				if (!role || !this.registerPcm(stem)) {
					continue;
				}
				var buffer = this.pcmBuffers[String(stem.key || "")];
				if (!buffer) {
					continue;
				}
				var source = ctx.createBufferSource();
				var gain = ctx.createGain();
				source.buffer = buffer;
				source.loop = true;
				source.loopStart = 0;
				source.loopEnd = buffer.duration;
				source.playbackRate.value = 1.0;
				gain.gain.value = clamp(dbToGain(stem.volume_db), 0, 1.25);
				source.connect(gain);
				gain.connect(this.musicBus);
				var offset = buffer.duration > 0 ? group.position % buffer.duration : 0;
				group.sources[role] = source;
				group.gains[role] = gain;
				source.start(0, offset);
			}
			this.musicGroups[groupId] = group;
			return true;
		},
		setMusicMix: function (payload) {
			payload = payload || {};
			if (!this.ensure()) {
				return false;
			}
			var groupId = String(payload.group_id || "music");
			var group = this.musicGroups[groupId];
			if (!group) {
				return false;
			}
			var volumes = payload.volumes_db || {};
			var now = this.ctx.currentTime;
			for (var role in volumes) {
				if (!Object.prototype.hasOwnProperty.call(volumes, role) || !group.gains[role]) {
					continue;
				}
				group.gains[role].gain.setTargetAtTime(clamp(dbToGain(volumes[role]), 0, 1.25), now, 0.08);
			}
			return true;
		},
		stopMusic: function (payload) {
			payload = payload || {};
			var groupId = "";
			if (typeof payload === "string") {
				groupId = payload;
			} else {
				groupId = String(payload.group_id || "");
			}
			if (groupId) {
				var group = this.musicGroups[groupId];
				if (!group) {
					return true;
				}
				for (var role in group.sources) {
					if (Object.prototype.hasOwnProperty.call(group.sources, role)) {
						stopEntry({ source: group.sources[role], gain: group.gains[role] });
					}
				}
				delete this.musicGroups[groupId];
				return true;
			}
			for (var id in this.musicGroups) {
				if (Object.prototype.hasOwnProperty.call(this.musicGroups, id)) {
					this.stopMusic({ group_id: id });
				}
			}
			return true;
		},
		stopAll: function () {
			this.stopMusic();
			for (var loopId in this.sfxLoops) {
				if (Object.prototype.hasOwnProperty.call(this.sfxLoops, loopId)) {
					this.stopLoop(loopId);
				}
			}
			return true;
		},
		playMusic: function (_payload) {
			return false;
		},
		sfx: function (_payload) {
			return false;
		}
	};
	return true;
})()
"""


static func available() -> bool:
	return WEB_AUDIO_BRIDGE_ENABLED and OS.has_feature("web")


static func ensure() -> void:
	if not available():
		return
	if _ensured:
		return
	_record_eval("ensure", WEB_AUDIO_SCRIPT.length())
	JavaScriptBridge.eval(WEB_AUDIO_SCRIPT, true)
	_ensured = true


static func unlock() -> void:
	if not available():
		return
	ensure()
	_last_music_payload_key = ""
	var source := "window.BTHWebAudio && window.BTHWebAudio.unlock();"
	_record_eval("unlock", source.length())
	JavaScriptBridge.eval(source, true)


static func play_stream(stream: AudioStream, stream_id: String, volume_db: float = 0.0, pitch: float = 1.0, loop_id: String = "", force_loop: bool = false) -> bool:
	if not available():
		return false
	ensure()
	var payload := _stream_payload(stream, stream_id, volume_db, pitch, loop_id, force_loop)
	if payload.is_empty():
		return false
	var source := "window.BTHWebAudio && window.BTHWebAudio.playPcm(%s);" % JSON.stringify(payload)
	_record_eval("play_pcm", source.length())
	JavaScriptBridge.eval(source, true)
	_mark_pcm_registered(payload)
	return true


static func stop_loop(loop_id: String) -> void:
	if not available():
		return
	var safe_loop_id := loop_id.strip_edges()
	if safe_loop_id.is_empty():
		return
	ensure()
	var source := "window.BTHWebAudio && window.BTHWebAudio.stopLoop(%s);" % JSON.stringify(safe_loop_id)
	_record_eval("stop_loop", source.length())
	JavaScriptBridge.eval(source, true)


static func play_music_stems(group_id: String, stem_set_key: String, stem_set: Dictionary, role_volume_db: Dictionary, resume_position: float) -> bool:
	if not available():
		return false
	ensure()
	var stems_value: Variant = stem_set.get("stems", {})
	if typeof(stems_value) != TYPE_DICTIONARY:
		return false
	var stems: Dictionary = stems_value
	var safe_group_id := group_id.strip_edges()
	if safe_group_id.is_empty():
		safe_group_id = "music"
	var safe_stem_key := stem_set_key.strip_edges()
	if safe_stem_key.is_empty():
		safe_stem_key = str(stem_set.get("palette_id", stem_set.get("track_id", "music")))
	var payload_identity := "%s|%s" % [safe_group_id, safe_stem_key]
	if _last_music_payload_key == payload_identity and bool(_active_music_groups.get(safe_group_id, false)):
		return true
	var stem_payloads: Array = []
	for role_value in WEB_MUSIC_STEM_ROLES:
		var role := str(role_value)
		var stream_value: Variant = stems.get(role, null)
		if not (stream_value is AudioStream):
			continue
		var stream := stream_value as AudioStream
		if stream is AudioStreamWAV and not _wav_has_signal(stream as AudioStreamWAV):
			continue
		var payload := _stream_payload(stream, "%s:%s:%s" % [safe_group_id, safe_stem_key, role], float(role_volume_db.get(role, -80.0)), 1.0, "", true)
		if payload.is_empty():
			continue
		payload["role"] = role
		stem_payloads.append(payload)
	if stem_payloads.is_empty():
		return false
	var payload := {
		"group_id": safe_group_id,
		"stem_set_key": safe_stem_key,
		"position": maxf(0.0, resume_position),
		"stems": stem_payloads,
	}
	var source := "window.BTHWebAudio && window.BTHWebAudio.playMusicStems(%s);" % JSON.stringify(payload)
	_record_eval("play_music_stems", source.length())
	JavaScriptBridge.eval(source, true)
	for stem_payload_value in stem_payloads:
		if typeof(stem_payload_value) == TYPE_DICTIONARY:
			_mark_pcm_registered(stem_payload_value as Dictionary)
	_last_music_payload_key = payload_identity
	_active_music_groups[safe_group_id] = true
	_last_music_mix_keys.erase(safe_group_id)
	_last_music_mix_msec.erase(safe_group_id)
	return true


static func set_music_mix(group_id: String, role_volume_db: Dictionary) -> void:
	if not available():
		return
	ensure()
	var safe_group_id := group_id.strip_edges()
	if safe_group_id.is_empty():
		safe_group_id = "music"
	var volumes_db := {}
	for role_value in WEB_MUSIC_STEM_ROLES:
		var role := str(role_value)
		volumes_db[role] = snappedf(float(role_volume_db.get(role, -80.0)), 0.01)
	var payload_key := JSON.stringify(volumes_db)
	if str(_last_music_mix_keys.get(safe_group_id, "")) == payload_key:
		return
	var now_msec := Time.get_ticks_msec()
	var last_msec := int(_last_music_mix_msec.get(safe_group_id, 0))
	if last_msec > 0 and now_msec - last_msec < WEB_MUSIC_MIX_MIN_INTERVAL_MSEC:
		return
	_last_music_mix_keys[safe_group_id] = payload_key
	_last_music_mix_msec[safe_group_id] = now_msec
	var payload := {
		"group_id": safe_group_id,
		"volumes_db": volumes_db,
	}
	var source := "window.BTHWebAudio && window.BTHWebAudio.setMusicMix(%s);" % JSON.stringify(payload)
	_record_eval("set_music_mix", source.length())
	JavaScriptBridge.eval(source, true)


static func play_music(_profile: Dictionary, _music_state: Dictionary) -> void:
	_record_eval("legacy_play_music_blocked", 0)


static func stop_music(group_id: String = "") -> void:
	if not available():
		return
	ensure()
	_last_music_payload_key = ""
	var safe_group_id := group_id.strip_edges()
	if safe_group_id.is_empty():
		if _active_music_groups.is_empty():
			return
		_last_music_mix_keys.clear()
		_last_music_mix_msec.clear()
		_active_music_groups.clear()
	else:
		if not bool(_active_music_groups.get(safe_group_id, false)):
			return
		_last_music_mix_keys.erase(safe_group_id)
		_last_music_mix_msec.erase(safe_group_id)
		_active_music_groups.erase(safe_group_id)
	var payload := {"group_id": safe_group_id}
	var source := "window.BTHWebAudio && window.BTHWebAudio.stopMusic(%s);" % JSON.stringify(payload)
	_record_eval("stop_music", source.length())
	JavaScriptBridge.eval(source, true)


static func play_sfx(_cue_id: String, _volume_db: float = 0.0, _pitch: float = 1.0) -> void:
	_record_eval("legacy_sfx_blocked", 0)


static func reset_debug_stats() -> void:
	_eval_counts = {}
	_eval_bytes = 0
	_last_music_payload_key = ""
	_last_music_mix_keys = {}
	_last_music_mix_msec = {}
	_registered_pcm_keys = {}
	_active_music_groups = {}


static func debug_stats() -> Dictionary:
	return {
		"available": available(),
		"ensured": _ensured,
		"eval_counts": _eval_counts.duplicate(true),
		"eval_bytes": _eval_bytes,
		"registered_pcm_count": _registered_pcm_keys.size(),
		"active_music_group_count": _active_music_groups.size(),
	}


static func mix_contract_snapshot() -> Dictionary:
	return {
		"version": WEB_AUDIO_VERSION,
		"master_gain": WEB_MASTER_GAIN,
		"output_gain": WEB_OUTPUT_GAIN,
		"highpass_hz": WEB_HIGHPASS_HZ,
		"compressor_threshold_db": WEB_COMPRESSOR_THRESHOLD_DB,
		"compressor_ratio": WEB_COMPRESSOR_RATIO,
		"sfx_max_gain": WEB_SFX_MAX_GAIN,
		"music_mix_min_interval_msec": WEB_MUSIC_MIX_MIN_INTERVAL_MSEC,
		"stream_bridge_enabled": WEB_AUDIO_BRIDGE_ENABLED,
		"fallback_enabled": WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED,
		"oscillator_fallback_enabled": WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED,
		"pcm_stream_bridge_default": WEB_AUDIO_BRIDGE_ENABLED and not WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED,
		"native_godot_audio_default": false,
		"script_has_version_guard": WEB_AUDIO_SCRIPT.find("version === BRIDGE_VERSION") >= 0,
		"script_has_highpass": WEB_AUDIO_SCRIPT.find("this.highpass.type = \"highpass\"") >= 0 and WEB_AUDIO_SCRIPT.find("this.highpass.frequency.value = 38") >= 0,
		"script_has_compressor": WEB_AUDIO_SCRIPT.find("createDynamicsCompressor") >= 0 and WEB_AUDIO_SCRIPT.find("this.compressor.threshold.value = -6") >= 0,
		"script_has_pcm_decoder": WEB_AUDIO_SCRIPT.find("decodePcm16") >= 0 and WEB_AUDIO_SCRIPT.find("createBuffer(channels, frames, sampleRate)") >= 0,
		"script_has_music_stems": WEB_AUDIO_SCRIPT.find("playMusicStems") >= 0 and WEB_AUDIO_SCRIPT.find("setMusicMix") >= 0,
		"script_has_loop_stop": WEB_AUDIO_SCRIPT.find("stopLoop") >= 0,
		"script_has_oscillator_fallback": WEB_AUDIO_SCRIPT.find("createOscillator") >= 0,
		"bridge_skips_silent_music_stems": true,
		"bridge_skips_duplicate_music_stems": true,
		"bridge_skips_duplicate_music_stops": true,
		"script_limits_sfx_gain": WEB_AUDIO_SCRIPT.find("clamp(dbToGain(payload.volume_db), 0, 1.25)") >= 0,
	}


static func _stream_payload(stream: AudioStream, stream_id: String, volume_db: float, pitch: float, loop_id: String, force_loop: bool) -> Dictionary:
	if not (stream is AudioStreamWAV):
		return {}
	var wav := stream as AudioStreamWAV
	if wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return {}
	var data := wav.data
	var channels := 2 if wav.stereo else 1
	var bytes_per_frame := maxi(1, channels * 2)
	var frames := maxi(1, int(data.size() / bytes_per_frame))
	if data.size() < bytes_per_frame:
		return {}
	var sample_rate := maxi(1, wav.mix_rate)
	var loop_begin := clampi(int(wav.loop_begin), 0, maxi(0, frames - 1))
	var loop_end := int(wav.loop_end)
	if loop_end <= loop_begin:
		loop_end = frames
	loop_end = clampi(loop_end, loop_begin + 1, frames)
	var is_loop := force_loop
	var safe_stream_id := stream_id.strip_edges()
	if safe_stream_id.is_empty():
		safe_stream_id = "pcm"
	var stream_key := "%s|sr%d|ch%d|bytes%d|loop%d:%d" % [safe_stream_id, sample_rate, channels, data.size(), loop_begin, loop_end]
	var registered := bool(_registered_pcm_keys.get(stream_key, false))
	var payload := {
		"key": stream_key,
		"sample_rate": sample_rate,
		"channels": channels,
		"frames": frames,
		"volume_db": volume_db,
		"pitch": clampf(pitch, 0.35, 2.5),
		"loop": is_loop,
		"loop_id": loop_id,
		"loop_begin_frame": loop_begin,
		"loop_end_frame": loop_end,
		"registered": registered,
	}
	if not registered:
		payload["data"] = Marshalls.raw_to_base64(data)
	return payload


static func _mark_pcm_registered(payload: Dictionary) -> void:
	if payload.has("data"):
		_registered_pcm_keys[str(payload.get("key", ""))] = true


static func _wav_has_signal(wav: AudioStreamWAV) -> bool:
	var data := wav.data
	for byte_value in data:
		if int(byte_value) != 0:
			return true
	return false


static func _record_eval(kind: String, byte_count: int) -> void:
	_eval_counts[kind] = int(_eval_counts.get(kind, 0)) + 1
	_eval_bytes += maxi(0, byte_count)
