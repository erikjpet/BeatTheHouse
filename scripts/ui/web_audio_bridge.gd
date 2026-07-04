class_name WebAudioBridge
extends RefCounted

const WEB_AUDIO_SCRIPT := """
(function () {
	if (window.BTHWebAudio) {
		return true;
	}
	function hashText(text) {
		var hash = 2166136261 >>> 0;
		var input = String(text || "");
		for (var index = 0; index < input.length; index += 1) {
			hash ^= input.charCodeAt(index);
			hash = Math.imul(hash, 16777619) >>> 0;
		}
		return hash >>> 0;
	}
	function clamp(value, minValue, maxValue) {
		return Math.max(minValue, Math.min(maxValue, value));
	}
	function dbToGain(db) {
		return Math.pow(10, clamp(Number(db || 0), -48, 6) / 20);
	}
	function makeNoiseBuffer(ctx, seed) {
		var frames = Math.max(1, Math.floor(ctx.sampleRate * 2));
		var buffer = ctx.createBuffer(1, frames, ctx.sampleRate);
		var data = buffer.getChannelData(0);
		var state = (seed >>> 0) || 1;
		for (var index = 0; index < frames; index += 1) {
			state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
			data[index] = (((state >>> 8) & 65535) / 32767.5 - 1) * 0.18;
		}
		return buffer;
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
	window.BTHWebAudio = {
		ctx: null,
		master: null,
		music: null,
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
			this.master.gain.value = 0.34;
			this.master.connect(this.ctx.destination);
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
		ensureMusic: function (seed) {
			if (this.music) {
				return;
			}
			var ctx = this.ctx;
			var root = 55 + (seed % 9) * 2;
			var pad = ctx.createOscillator();
			var pad2 = ctx.createOscillator();
			var bass = ctx.createOscillator();
			var lead = ctx.createOscillator();
			var noise = ctx.createBufferSource();
			var padGain = ctx.createGain();
			var bassGain = ctx.createGain();
			var leadGain = ctx.createGain();
			var noiseGain = ctx.createGain();
			var filter = ctx.createBiquadFilter();
			pad.type = "sawtooth";
			pad2.type = "triangle";
			bass.type = "triangle";
			lead.type = "sine";
			pad.frequency.value = root;
			pad2.frequency.value = root * 1.5;
			bass.frequency.value = root * 0.5;
			lead.frequency.value = root * 2.0;
			noise.buffer = makeNoiseBuffer(ctx, seed);
			noise.loop = true;
			filter.type = "lowpass";
			filter.frequency.value = 900;
			filter.Q.value = 0.6;
			padGain.gain.value = 0.0;
			bassGain.gain.value = 0.0;
			leadGain.gain.value = 0.0;
			noiseGain.gain.value = 0.0;
			pad.connect(padGain);
			pad2.connect(padGain);
			bass.connect(bassGain);
			lead.connect(leadGain);
			noise.connect(filter);
			filter.connect(noiseGain);
			padGain.connect(this.master);
			bassGain.connect(this.master);
			leadGain.connect(this.master);
			noiseGain.connect(this.master);
			pad.start();
			pad2.start();
			bass.start();
			lead.start();
			noise.start();
			this.music = {
				seed: seed,
				root: root,
				pad: pad,
				pad2: pad2,
				bass: bass,
				lead: lead,
				noise: noise,
				padGain: padGain,
				bassGain: bassGain,
				leadGain: leadGain,
				noiseGain: noiseGain,
				filter: filter
			};
		},
		playMusic: function (payload) {
			payload = payload || {};
			if (!this.unlock()) {
				return false;
			}
			var theme = String(payload.theme || payload.environment_id || "neon");
			var seed = hashText(theme + ":" + String(payload.palette_id || ""));
			if (!this.music || this.music.seed !== seed) {
				this.stopMusic();
				this.ensureMusic(seed);
			}
			var ctx = this.ctx;
			var now = ctx.currentTime;
			var heat = clamp(Number(payload.heat || 0), 0, 100) / 100;
			var drunk = clamp(Number(payload.drunk_level || 0), 0, 100) / 100;
			var watched = payload.watched ? 1 : 0;
			var pressure = clamp(Math.max(heat, watched * 0.7), 0, 1);
			var root = this.music.root;
			var wobble = 1 + drunk * 0.015;
			this.music.pad.frequency.setTargetAtTime(root * wobble, now, 0.12);
			this.music.pad2.frequency.setTargetAtTime(root * 1.5 * wobble, now, 0.12);
			this.music.bass.frequency.setTargetAtTime(root * 0.5, now, 0.12);
			this.music.lead.frequency.setTargetAtTime(root * (2.0 + pressure * 0.5), now, 0.08);
			this.music.padGain.gain.setTargetAtTime(0.070 - pressure * 0.022, now, 0.18);
			this.music.bassGain.gain.setTargetAtTime(0.030 + pressure * 0.035, now, 0.18);
			this.music.leadGain.gain.setTargetAtTime(0.010 + heat * 0.032, now, 0.18);
			this.music.noiseGain.gain.setTargetAtTime(0.020 + pressure * 0.035, now, 0.18);
			this.music.filter.frequency.setTargetAtTime(650 + heat * 1500 + watched * 500, now, 0.18);
			this.master.gain.setTargetAtTime(0.30, now, 0.12);
			return true;
		},
		stopMusic: function () {
			if (!this.music) {
				return;
			}
			stopNode(this.music.pad);
			stopNode(this.music.pad2);
			stopNode(this.music.bass);
			stopNode(this.music.lead);
			stopNode(this.music.noise);
			this.music = null;
		},
		sfx: function (payload) {
			payload = payload || {};
			if (!this.unlock()) {
				return false;
			}
			var ctx = this.ctx;
			var now = ctx.currentTime;
			var cue = String(payload.cue || "button").toLowerCase();
			var gainScale = dbToGain(payload.volume_db);
			var pitch = clamp(Number(payload.pitch || 1), 0.35, 2.5);
			var duration = 0.075;
			var frequency = 620;
			if (cue.indexOf("jackpot") >= 0 || cue.indexOf("payout") >= 0 || cue.indexOf("bonus") >= 0) {
				frequency = 980;
				duration = 0.18;
			} else if (cue.indexOf("bust") >= 0 || cue.indexOf("lose") >= 0) {
				frequency = 180;
				duration = 0.20;
			} else if (cue.indexOf("reel") >= 0 || cue.indexOf("roulette_ball") >= 0) {
				frequency = 260;
				duration = 0.12;
			} else if (cue.indexOf("card") >= 0 || cue.indexOf("click") >= 0 || cue.indexOf("chip") >= 0) {
				frequency = 740;
				duration = 0.055;
			}
			var osc = ctx.createOscillator();
			var gain = ctx.createGain();
			osc.type = cue.indexOf("reel") >= 0 ? "sawtooth" : "square";
			osc.frequency.value = frequency * pitch;
			gain.gain.setValueAtTime(0.0001, now);
			gain.gain.exponentialRampToValueAtTime(clamp(0.16 * gainScale, 0.005, 0.35), now + 0.012);
			gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
			osc.connect(gain);
			gain.connect(this.master);
			osc.start(now);
			osc.stop(now + duration + 0.02);
			return true;
		}
	};
	return true;
})()
"""


static func available() -> bool:
	return OS.has_feature("web")


static func ensure() -> void:
	if not available():
		return
	JavaScriptBridge.eval(WEB_AUDIO_SCRIPT, true)


static func unlock() -> void:
	if not available():
		return
	ensure()
	JavaScriptBridge.eval("window.BTHWebAudio && window.BTHWebAudio.unlock();", true)


static func play_music(profile: Dictionary, music_state: Dictionary) -> void:
	if not available():
		return
	ensure()
	var payload := {
		"environment_id": str(profile.get("environment_id", "")),
		"theme": str(profile.get("theme", "")),
		"palette_id": str(profile.get("palette_id", "")),
		"heat": int(music_state.get("heat", music_state.get("suspicion_level", 0))),
		"drunk_level": int(music_state.get("drunk_level", 0)),
		"watched": bool(music_state.get("watched", false)) or bool(music_state.get("watch_active", false)),
	}
	JavaScriptBridge.eval("window.BTHWebAudio && window.BTHWebAudio.playMusic(%s);" % JSON.stringify(payload), true)


static func stop_music() -> void:
	if not available():
		return
	ensure()
	JavaScriptBridge.eval("window.BTHWebAudio && window.BTHWebAudio.stopMusic();", true)


static func play_sfx(cue_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not available():
		return
	ensure()
	var payload := {
		"cue": cue_id,
		"volume_db": volume_db,
		"pitch": pitch,
	}
	JavaScriptBridge.eval("window.BTHWebAudio && window.BTHWebAudio.sfx(%s);" % JSON.stringify(payload), true)
