'use strict';

// Screenshot/audio CRT acceptance, launched only by bth_qa_guarded_run.py.
// Every writable path comes from that fresh E: manifest. This worker does not
// import saves, inspect browser storage, or call into Godot's internal state.
//
// Private candidate: --root E:\...\builds\crt-private
// Served NEXT:       --url http://127.0.0.1:8088/.../dev/ --expected-sha <full SHA>
// Viewport:          --viewport 1280x720 (default), 844x390 or 390x844, for
//                    separate fresh desktop/mobile runs of the unchanged app.
// Commands: <BTH_QA_EVIDENCE_DIR>/control/command-01.json through command-40.json
// {"label":"open-games","actions":[{"kind":"click","x":100,"y":100}]}
// Supported kinds: click, touch, wheel(dy), key(value), type(value), wait(ms), reload,
// start_audio_capture(seconds: 1..45, default 42), stop_audio_capture, stop.
// One bounded recording per fresh worker. A stop must be the last action.
// The tap observes ONLY this page's BTHWebAudio.output. It never requests a
// microphone, captures the desktop, changes gain, resumes or unlocks a context.

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const { chromium } = require('D:/Projects/site/node_modules/playwright');

const CHROMIUM = 'C:/Users/theep/AppData/Local/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-win64/chrome-headless-shell.exe';
const APPROVED_ROOT = 'E:\\CodexQA\\BTH';
const HARD_LIMIT_MS = 480000;
const MAX_COMMANDS = 40;
const MAX_AUDIO_BYTES = 8 * 1024 * 1024;
// QA_CACHE_POLICY_ONLY: private loopback header alignment with the separately
// observed baseline. This does not change product hosting or replicate LAN/TLS.
const PRIVATE_CACHE_POLICY = 'no-cache';
const KEYS = new Set(['Escape', 'Enter', 'Space', 'Tab', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Control+A', 'Home', 'End']);
const started = Date.now();
const deadline = started + HARD_LIMIT_MS;
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const bounded = (value, low, high) => Number.isFinite(value) && value >= low && value <= high;
const expectedNavigationAbort = (failure, action, pendingBeforeReload) => failure === 'net::ERR_ABORTED' && action?.kind === 'reload' && pendingBeforeReload === true;
const tracedAssetUrl = value => /\.(?:pck|wasm)(?:$|[?#])/i.test(value);
const samePath = (left, right) => path.resolve(left).toLowerCase() === path.resolve(right).toLowerCase();
const inside = (root, candidate) => {
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  return relative === '' || (!relative.startsWith('..' + path.sep) && relative !== '..' && !path.isAbsolute(relative));
};

function argsFrom(tokens) {
  const result = {};
  for (let index = 0; index < tokens.length; index += 2) {
    const flag = tokens[index];
    if (!['--root', '--url', '--expected-sha', '--viewport'].includes(flag) || result[flag] !== undefined || !tokens[index + 1]) {
      throw Error('Use --root or --url, optional --viewport WIDTHxHEIGHT, and --expected-sha only for served mode.');
    }
    result[flag] = tokens[index + 1];
  }
  if (Boolean(result['--root']) === Boolean(result['--url'])) throw Error('Choose exactly one private-root or served-URL mode.');
  if (result['--url'] && !/^[a-f0-9]{40}$/.test(result['--expected-sha'] || '')) throw Error('Served mode requires the expected full lowercase commit SHA.');
  if (result['--root'] && result['--expected-sha']) throw Error('A private composite must not claim a served commit identity.');
  const viewport = /^(\d{3,4})x(\d{3,4})$/.exec(result['--viewport'] || '1280x720');
  if (!viewport || !bounded(Number(viewport[1]), 320, 1920) || !bounded(Number(viewport[2]), 240, 1200)) {
    throw Error('Viewport must be WIDTHxHEIGHT within 320..1920 by 240..1200 CSS pixels.');
  }
  result.viewport = { width: Number(viewport[1]), height: Number(viewport[2]) };
  return result;
}

function admittedDirectory(value, name) {
  if (!value || !path.isAbsolute(value) || !inside(APPROVED_ROOT, value)) throw Error(name + ' must use explicit approved E: storage.');
  const absolute = path.resolve(value);
  if (!fs.statSync(absolute).isDirectory() || !samePath(fs.realpathSync(absolute), absolute)) throw Error(name + ' must be an existing real directory, without aliases.');
  return absolute;
}

function guardedPaths() {
  const workspace = admittedDirectory(process.env.BTH_QA_WORKSPACE, 'workspace');
  const runRoot = admittedDirectory(process.env.BTH_QA_RUN_DIR, 'run root');
  const profile = admittedDirectory(process.env.BTH_QA_PROFILE_DIR, 'profile');
  const temp = admittedDirectory(process.env.BTH_QA_TEMP_DIR, 'temp');
  const evidence = admittedDirectory(process.env.BTH_QA_EVIDENCE_DIR, 'evidence');
  if (!inside(path.join(APPROVED_ROOT, 'workspaces'), workspace) || !inside(path.join(APPROVED_ROOT, 'runs'), runRoot)) throw Error('Workspace and run must use their maintained E: layout.');
  for (const [name, value] of Object.entries({ profile, temp, evidence })) {
    if (!samePath(path.join(runRoot, name), value)) throw Error(name + ' differs from the admitted fresh run layout.');
  }
  const manifestPath = path.join(evidence, 'storage-manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  if (manifest.schema !== 'bth-qa-storage/v1' || manifest.prepared !== true) throw Error('A prepared fresh storage manifest is required.');
  for (const [name, value] of Object.entries({ workspace, run_root: runRoot, profile, temp, evidence })) {
    if (!samePath(manifest.paths?.[name] || '', value)) throw Error('Manifest mismatch: ' + name);
  }
  if (!samePath(manifest.manifest_path || '', manifestPath) || !fs.existsSync(path.join(evidence, 'launch-claim.json'))) throw Error('Launch this worker through bth_qa_guarded_run.py.');
  if (fs.readdirSync(profile).length !== 0) throw Error('Refusing a nonempty browser profile.');
  if (process.env.BTH_CAPTURED_FIXTURE || process.env.BTH_WEB_STORAGE_PROFILE) throw Error('Captured or retained profiles are outside this fresh smoke check.');
  return { workspace, runRoot, profile, temp, evidence, manifestPath };
}

function validatedCommand(value, viewport) {
  if (!value || !/^[a-z0-9-]{1,36}$/.test(value.label || '') || !Array.isArray(value.actions) || value.actions.length > 25) throw Error('Invalid bounded command structure.');
  for (let index = 0; index < value.actions.length; index++) {
    const action = value.actions[index];
    if (!action || typeof action !== 'object') throw Error('Invalid action.');
    const pointer = ['click', 'touch'].includes(action.kind) && bounded(action.x, 0, viewport.width - 1) && bounded(action.y, 0, viewport.height - 1);
    const wheel = action.kind === 'wheel' && bounded(action.dy, -1000, 1000);
    const key = action.kind === 'key' && KEYS.has(action.value);
    const type = action.kind === 'type' && typeof action.value === 'string' && /^[\x20-\x7e]{0,40}$/.test(action.value);
    const wait = action.kind === 'wait' && bounded(action.ms, 0, 4000);
    const reload = action.kind === 'reload';
    const audioStart = action.kind === 'start_audio_capture' && (action.seconds === undefined || bounded(action.seconds, 1, 45));
    const audioStop = action.kind === 'stop_audio_capture';
    const stop = action.kind === 'stop' && index === value.actions.length - 1;
    if (!pointer && !wheel && !key && !type && !wait && !reload && !audioStart && !audioStop && !stop) throw Error('Invalid bounded action at index ' + index);
  }
  return value;
}

// Playwright's installed evaluateWithArguments uses userGesture:true. Never
// use that utility path for observations: it can unlock audio without input.
async function passiveEvaluate(cdp, callback, argument) {
  const parameter = argument === undefined ? '' : JSON.stringify(argument);
  const evaluated = await cdp.send('Runtime.evaluate', {
    expression: '(' + callback.toString() + ')(' + parameter + ')',
    userGesture: false, awaitPromise: true, returnByValue: true, timeout: 15000,
  });
  if (evaluated.exceptionDetails) throw Error('Passive observation failed: ' + String(evaluated.exceptionDetails.exception?.description || evaluated.exceptionDetails.text).slice(0, 1000));
  return evaluated.result.value;
}

async function audioSnapshot(cdp) {
  return passiveEvaluate(cdp, () => {
    const bridge = window.BTHWebAudio;
    const tap = window.__bthCrtAudioTap;
    return {
      bridge_present: Boolean(bridge), context_state: bridge?.ctx?.state || null,
      bridge_unlocked: Boolean(bridge?.unlocked), sample_rate: bridge?.ctx?.sampleRate || null,
      master_gain: bridge?.master?.gain?.value ?? null, output_gain: bridge?.output?.gain?.value ?? null,
      music_gain: bridge?.musicBus?.gain?.value ?? null, sfx_gain: bridge?.sfxBus?.gain?.value ?? null,
      user_activation: { is_active: Boolean(navigator.userActivation?.isActive), has_been_active: Boolean(navigator.userActivation?.hasBeenActive) },
      trusted_gestures: (window.__bthCrtTrustedGestures || []).slice(),
      capture: tap ? { recording_state: tap.recorder.state, samples: tap.samples.length, bytes: tap.bytes, stopped: tap.stopped } : null,
    };
  });
}

async function startAudioCapture(cdp, seconds) {
  return passiveEvaluate(cdp, ({ milliseconds, maxBytes }) => {
    if (window.__bthCrtAudioTap) throw Error('One audio recording is allowed per fresh worker.');
    const bridge = window.BTHWebAudio;
    if (!bridge?.ctx || !bridge.output || bridge.ctx.state === 'closed') throw Error('The ordinary game has not created a usable BTHWebAudio output.');
    const context = bridge.ctx;
    const mime = ['audio/webm;codecs=opus', 'audio/webm'].find(value => MediaRecorder.isTypeSupported(value));
    if (!mime) throw Error('Installed Chromium does not support WebM audio recording.');
    const analyser = context.createAnalyser();
    analyser.fftSize = 8192; // Overlapping 171-ms windows at 48 kHz catch short UI cues at 100-ms polls.
    const destination = context.createMediaStreamDestination();
    // Parallel passive branches: the original output -> ctx.destination remains intact.
    bridge.output.connect(analyser);
    bridge.output.connect(destination);
    const recorder = new MediaRecorder(destination.stream, { mimeType: mime, audioBitsPerSecond: 128000 });
    const tap = {
      recorder, analyser, destination, samples: [], chunks: [], bytes: 0, stopped: false,
      started_ms: performance.now(), context_started_seconds: context.currentTime, start_state: context.state,
      start_unlocked: Boolean(bridge.unlocked), stop_reason: null, interval: null, timer: null,
    };
    window.__bthCrtAudioTap = tap;
    const data = new Float32Array(analyser.fftSize);
    const sample = () => {
      if (tap.samples.length >= 500) return;
      analyser.getFloatTimeDomainData(data);
      let square = 0, peak = 0, nonzero = 0, finite = true;
      for (const value of data) {
        if (!Number.isFinite(value)) { finite = false; continue; }
        square += value * value; peak = Math.max(peak, Math.abs(value));
        if (Math.abs(value) > 0.000001) nonzero += 1;
      }
      tap.samples.push({ elapsed_ms: performance.now() - tap.started_ms, context_seconds: context.currentTime,
        context_state: context.state, bridge_unlocked: Boolean(bridge.unlocked), rms: Math.sqrt(square / data.length), peak, finite, nonzero_samples: nonzero,
        music_groups: Object.entries(bridge.musicGroups || {}).map(([id, group]) => ({ id, key: String(group?.key || group?.stemSetKey || '') })).slice(0, 8),
        active_sfx_keys: (bridge.sfxOneShots || []).filter(entry => entry && !entry.ended).map(entry => String(entry.key || '')).slice(0, 16),
      });
    };
    let resolveStopped;
    let rejectStopped;
    tap.stoppedPromise = new Promise((resolve, reject) => { resolveStopped = resolve; rejectStopped = reject; });
    tap.stoppedPromise.catch(() => {}); // The bounded Node stop/read path reports any failure later.
    tap.stop = reason => {
      if (tap.stopped) return tap.stoppedPromise;
      tap.stopped = true;
      tap.stop_reason = reason;
      sample();
      clearInterval(tap.interval); clearTimeout(tap.timer);
      if (recorder.state !== 'inactive') recorder.stop();
      return tap.stoppedPromise;
    };
    recorder.ondataavailable = event => {
      if (!event.data.size) return;
      tap.bytes += event.data.size;
      if (tap.bytes <= maxBytes) tap.chunks.push(event.data);
      else { tap.capture_error = 'Eight-MiB audio evidence limit reached.'; tap.stop('byte_limit'); }
    };
    recorder.onerror = event => { tap.capture_error = String(event.error || 'MediaRecorder error'); tap.stop('recorder_error'); };
    recorder.onstop = async () => {
      try {
        bridge.output.disconnect(analyser);
        bridge.output.disconnect(destination);
        for (const track of destination.stream.getTracks()) track.stop();
        const blob = new Blob(tap.chunks, { type: recorder.mimeType });
        const bytes = new Uint8Array(await blob.arrayBuffer());
        let binary = '';
        for (let index = 0; index < bytes.length; index += 32768) binary += String.fromCharCode(...bytes.subarray(index, index + 32768));
        resolveStopped({ mime_type: recorder.mimeType, base64: btoa(binary), bytes: bytes.length, elapsed_ms: performance.now() - tap.started_ms,
          context_elapsed_seconds: context.currentTime - tap.context_started_seconds, start_context_state: tap.start_state, start_unlocked: tap.start_unlocked,
          final_context_state: context.state, final_unlocked: Boolean(bridge.unlocked), sample_rate: context.sampleRate,
          stop_reason: tap.stop_reason, capture_error: tap.capture_error || null, samples: tap.samples,
          analysis_format: 'Actual Float32 mono analyser windows, 8192 frames, polled every 100 ms; WebM records the separate stream destination',
          source: 'BTHWebAudio.output parallel tap after highpass/compressor/output gain; original destination connection unchanged',
          scope: 'Actual own-page mixed PCM time-domain observations and encoded WebM; no microphone, desktop/OS loopback or loudspeaker-hearing claim',
        });
      } catch (error) { rejectStopped(String(error)); }
    };
    recorder.start(250);
    sample();
    tap.interval = setInterval(sample, 100);
    tap.timer = setTimeout(() => tap.stop('bounded_timer'), milliseconds);
    return { started: true, seconds: milliseconds / 1000, context_state: context.state, bridge_unlocked: Boolean(bridge.unlocked), mime_type: recorder.mimeType };
  }, { milliseconds: seconds * 1000, maxBytes: MAX_AUDIO_BYTES });
}

async function sha256File(filename) {
  const hash = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(filename)) hash.update(chunk);
  return hash.digest('hex');
}

function mime(filename) {
  return ({ '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.css': 'text/css; charset=utf-8' })[path.extname(filename).toLowerCase()] || 'application/octet-stream';
}

async function staticServer(root, onTransfer = () => {}) {
  let nextTransferId = 0;
  const server = http.createServer((request, response) => {
    const reject = (status, text) => { response.writeHead(status, { 'Content-Type': 'text/plain' }); response.end(text); };
    if (!['GET', 'HEAD'].includes(request.method)) { reject(405, 'Read only'); return; }
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
      if (pathname.includes('\0') || pathname.includes('\\')) { reject(400, 'Invalid path'); return; }
      let filename = path.resolve(root, '.' + pathname);
      if (!inside(root, filename)) { reject(403, 'Outside candidate root'); return; }
      if (fs.existsSync(filename) && fs.statSync(filename).isDirectory()) filename = path.join(filename, 'index.html');
      if (!fs.existsSync(filename)) { reject(404, 'Missing candidate asset'); return; }
      if (!inside(root, fs.realpathSync(filename)) || !fs.statSync(filename).isFile()) { reject(403, 'Invalid candidate asset'); return; }
      const declaredBytes = fs.statSync(filename).size;
      let input;
      let transfer;
      if (tracedAssetUrl(filename)) {
        transfer = {
          transfer_id: ++nextTransferId, at: new Date().toISOString(),
          url: request.url, method: request.method, requested_range: request.headers.range || null,
          response_status: 200, declared_file_bytes: declaredBytes, stream_bytes_read: 0,
          response_cache_control: PRIVATE_CACHE_POLICY,
          request_aborted: false, response_finished: false, response_closed: false,
        };
        onTransfer(transfer);
        request.on('aborted', () => {
          transfer.request_aborted = true;
          transfer.request_aborted_at = new Date().toISOString();
        });
        response.on('finish', () => {
          transfer.response_finished = true;
          transfer.response_finished_at = new Date().toISOString();
          transfer.stream_bytes_read = input?.bytesRead || 0;
        });
        response.on('close', () => {
          transfer.response_closed = true;
          transfer.response_closed_at = new Date().toISOString();
          transfer.writable_finished_at_close = response.writableFinished;
          transfer.closed_before_finish = !response.writableFinished;
          transfer.stream_bytes_read = input?.bytesRead || 0;
        });
      }
      response.writeHead(200, {
        'Content-Type': mime(filename), 'Content-Length': declaredBytes,
        'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp',
        'Cross-Origin-Resource-Policy': 'same-origin', 'Cache-Control': PRIVATE_CACHE_POLICY,
      });
      if (request.method === 'HEAD') { response.end(); return; }
      input = fs.createReadStream(filename);
      input.on('error', error => {
        if (transfer) transfer.stream_error = String(error).slice(0, 300);
        response.destroy();
      });
      response.on('close', () => input.destroy());
      input.pipe(response);
    } catch (_) { reject(400, 'Invalid request'); }
  });
  server.on('clientError', (_, socket) => socket.destroy());
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  return { server, url: 'http://127.0.0.1:' + server.address().port + '/index.html' };
}

async function main() {
  const args = argsFrom(process.argv.slice(2));
  // Guard and manifest validation precede the first write or browser process.
  const paths = guardedPaths();
  const control = path.join(paths.evidence, 'control');
  if (fs.existsSync(control)) throw Error('Refusing an occupied control directory.');
  fs.mkdirSync(control);
  const result = {
    schema: 'bth.crt_audio_web_smoke/v1', mode: args['--root'] ? 'private_composite' : 'served_next',
    expected_source_commit: args['--expected-sha'] || null, started_at: new Date(started).toISOString(),
    requested_viewport: args.viewport,
    observation_execution: 'CDP Runtime.evaluate userGesture:false; CDP Page.captureScreenshot; no Playwright DOM evaluation utilities',
    private_server_cache_policy: args['--root'] ? {
      classification: 'QA_CACHE_POLICY_ONLY', value: PRIVATE_CACHE_POLICY,
      applies_to: 'Private loopback HTTP harness only', product_override: false,
      scope: 'Cache header alignment only; no LAN/TLS, proxy, deployment or full production transport replication claim',
    } : null,
    storage_manifest: paths.manifestPath, stages: [], game_readiness_markers: [], page_errors: [], console_errors: [], non_200_assets: [], failed_requests: [], expected_navigation_aborts: [], asset_network_trace: [], private_server_transfers: [], cleanup_errors: [], gesture_observations: [],
    scope: 'Fresh normal UI with passive own-page WebAudio output capture. No save import, browser storage inspection, forced game state/unlock, microphone, desktop audio capture, speaker-hearing or physical-controller claim.',
  };
  let context;
  let server;
  let timer;
  let timedOut = false;
  let activeUiAction = null;
  let reloadPendingRequests = null;
  const pendingRequests = new Set();
  const requestStarts = new WeakMap();
  let requestSequence = 0;
  let unexpectedRequestFailure = false;
  let audioCaptureStarted = false;
  let audioCaptureSaved = false;
  let saveAudioCapture = null;
  const record = (collection, value) => {
    if (collection.length < 500) collection.push(value);
    else result.event_log_truncated = true;
  };
  const remaining = (maximum = 30000) => Math.max(1, Math.min(maximum, deadline - Date.now()));
  const checkDeadline = () => { if (timedOut || Date.now() >= deadline) throw Error('480-second Web smoke deadline reached.'); };
  const writeJson = (name, value) => {
    const destination = path.join(paths.evidence, name);
    const temporary = destination + '.tmp';
    fs.writeFileSync(temporary, JSON.stringify(value, null, 2));
    fs.renameSync(temporary, destination);
  };
  try {
    let target;
    if (args['--root']) {
      const root = admittedDirectory(args['--root'], 'private candidate root');
      if (!inside(paths.workspace, root)) throw Error('Private candidate must remain inside the admitted workspace.');
      for (const leaf of ['index.html', 'index.js', 'index.pck', 'index.wasm']) if (!fs.statSync(path.join(root, leaf)).isFile()) throw Error('Incomplete private candidate: ' + leaf);
      result.private_root = root;
      result.candidate_pck_sha256 = await sha256File(path.join(root, 'index.pck'));
      result.private_provenance = 'Disposable composite QA: current candidate PCK over separately recorded unchanged baseline runtime assets; not production deployment evidence.';
      const served = await staticServer(root, transfer => record(result.private_server_transfers, transfer));
      server = served.server;
      target = served.url;
    } else {
      const parsed = new URL(args['--url']);
      if (parsed.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(parsed.hostname)) throw Error('Served mode is restricted to the existing local HTTP endpoint.');
      target = parsed.href;
    }
    checkDeadline();
    timer = setTimeout(() => {
      timedOut = true;
      result.hard_deadline_reached = true;
      activeUiAction = null; // Deadline teardown is not an ordinary reload.
      reloadPendingRequests = null;
      if (context) context.close().catch(() => {});
      if (server) server.close();
    }, remaining(HARD_LIMIT_MS));
    // Recheck fresh ownership immediately before Chromium creation.
    result.chromium_executable = CHROMIUM;
    result.chromium_sha256 = await sha256File(CHROMIUM);
    guardedPaths();
    context = await chromium.launchPersistentContext(paths.profile, {
      headless: true, chromiumSandbox: true, executablePath: CHROMIUM,
      ignoreDefaultArgs: ['--mute-audio', '--autoplay-policy=no-user-gesture-required'],
      // Chromium requires this diagnostic switch for Browser.getBrowserCommandLine.
      // It grants no autoplay permission and does not resume or unlock audio.
      args: ['--enable-automation'],
      viewport: args.viewport, deviceScaleFactor: 1, hasTouch: true, serviceWorkers: 'block',
      timeout: remaining(60000),
    });
    const page = await context.newPage();
    const registerTrustedGestures = () => {
      if (window.__bthCrtGestureObserverInstalled) return;
      window.__bthCrtGestureObserverInstalled = true;
      window.__bthCrtTrustedGestures = [];
      for (const type of ['pointerdown', 'touchstart', 'keydown']) document.addEventListener(type, event => {
        if (!event.isTrusted || window.__bthCrtTrustedGestures.length >= 80) return;
        window.__bthCrtTrustedGestures.push({ type: event.type, pointer_type: event.pointerType || null, at_ms: performance.now(), is_trusted: event.isTrusted,
          activation_is_active: Boolean(navigator.userActivation?.isActive), activation_has_been_active: Boolean(navigator.userActivation?.hasBeenActive) });
      }, { capture: true, passive: true });
    };
    page.setDefaultTimeout(15000);
    page.on('request', request => {
      pendingRequests.add(request);
      requestStarts.set(request, { sequence: ++requestSequence, at: new Date().toISOString() });
    });
    page.on('requestfinished', request => pendingRequests.delete(request));
    // Observe transport attribution without changing requests, responses or
    // acceptance. Keep only bounded PCK/WASM metadata, never response bodies.
    const cdp = await context.newCDPSession(page);
    // Normal new-document listeners do not create browser user activation.
    await cdp.send('Page.enable');
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: '(' + registerTrustedGestures.toString() + ')()' });
    result.browser_spawn_args = (await cdp.send('Browser.getBrowserCommandLine')).arguments;
    if (!Array.isArray(result.browser_spawn_args) || result.browser_spawn_args.some(value => value === '--mute-audio' || value === '--autoplay-policy=no-user-gesture-required')) throw Error('Audio capture requires normal autoplay policy and no browser mute flag.');
    result.ignored_default_args = ['--mute-audio', '--autoplay-policy=no-user-gesture-required'];
    saveAudioCapture = async reason => {
      if (!audioCaptureStarted || audioCaptureSaved) return;
      let readTimer;
      const captured = await Promise.race([
        passiveEvaluate(cdp, async stopReason => {
          const tap = window.__bthCrtAudioTap;
          if (!tap) throw Error('The owned audio tap disappeared before its evidence was read.');
          return await tap.stop(stopReason);
        }, reason),
        new Promise((_, reject) => { readTimer = setTimeout(() => reject(Error('Ten-second audio evidence read deadline reached.')), remaining(10000)); }),
      ]).finally(() => clearTimeout(readTimer));
      const bytes = Buffer.from(captured.base64, 'base64');
      delete captured.base64;
      if (bytes.length !== captured.bytes || bytes.length === 0 || bytes.length > MAX_AUDIO_BYTES) throw Error('Audio evidence is empty, mismatched or over the eight-MiB bound.');
      const audioFile = path.join(paths.evidence, 'crt-output.webm');
      if (fs.existsSync(audioFile)) throw Error('Refusing to replace existing audio evidence.');
      fs.writeFileSync(audioFile, bytes, { flag: 'wx' });
      captured.file = audioFile;
      captured.sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
      captured.nonzero_pcm_observed = captured.samples.some(sample => sample.context_state === 'running' && sample.bridge_unlocked && sample.finite && sample.rms > 0.000001);
      captured.max_rms = Math.max(0, ...captured.samples.map(sample => sample.rms));
      captured.max_peak = Math.max(0, ...captured.samples.map(sample => sample.peak));
      captured.passed = !captured.capture_error && captured.elapsed_ms <= 50000 && captured.nonzero_pcm_observed && captured.samples.every(sample => sample.finite);
      writeJson('audio-capture.json', captured);
      result.audio_capture = { file: audioFile, metadata: path.join(paths.evidence, 'audio-capture.json'), bytes: bytes.length, sha256: captured.sha256,
        elapsed_ms: captured.elapsed_ms, nonzero_pcm_observed: captured.nonzero_pcm_observed, max_rms: captured.max_rms, max_peak: captured.max_peak, passed: captured.passed };
      audioCaptureSaved = true;
    };
    const tracedRequestIds = new Set();
    const tracedRequestContexts = new Map();
    const responseHeaders = headers => {
      const lowered = Object.fromEntries(Object.entries(headers || {}).map(([key, value]) => [key.toLowerCase(), value]));
      return {
        content_length: lowered['content-length'] ?? null,
        content_range: lowered['content-range'] ?? null,
        accept_ranges: lowered['accept-ranges'] ?? null,
        content_type: lowered['content-type'] ?? null,
        cache_control: lowered['cache-control'] ?? null,
      };
    };
    cdp.on('Network.requestWillBeSent', event => {
      if (!tracedAssetUrl(event.request.url)) return;
      if (!tracedRequestIds.has(event.requestId) && tracedRequestIds.size >= 500) { result.event_log_truncated = true; return; }
      tracedRequestIds.add(event.requestId);
      const requestContext = {
        frame_id: event.frameId || null, loader_id: event.loaderId || null,
        document_url: event.documentURL || null,
      };
      tracedRequestContexts.set(event.requestId, requestContext);
      const frames = [];
      let stack = event.initiator?.stack;
      while (stack && frames.length < 10) {
        for (const frame of stack.callFrames || []) {
          if (frames.length === 10) break;
          frames.push({ function_name: frame.functionName, url: frame.url, line_number: frame.lineNumber, column_number: frame.columnNumber });
        }
        stack = stack.parent;
      }
      const headers = event.request.headers || {};
      record(result.asset_network_trace, {
        event: 'request', at: new Date().toISOString(), cdp_timestamp: event.timestamp,
        request_id: event.requestId, url: event.request.url, method: event.request.method,
        ...requestContext,
        requested_range: headers.Range || headers.range || null,
        initiator_type: event.initiator?.type || null, initiator_stack: frames,
      });
    });
    cdp.on('Network.responseReceived', event => {
      if (!tracedRequestIds.has(event.requestId)) return;
      record(result.asset_network_trace, {
        event: 'response', at: new Date().toISOString(), cdp_timestamp: event.timestamp,
        request_id: event.requestId, url: event.response.url, status: event.response.status,
        ...tracedRequestContexts.get(event.requestId),
        frame_id: event.frameId || tracedRequestContexts.get(event.requestId)?.frame_id || null,
        loader_id: event.loaderId || tracedRequestContexts.get(event.requestId)?.loader_id || null,
        from_disk_cache: event.response.fromDiskCache || false,
        from_service_worker: event.response.fromServiceWorker || false,
        ...responseHeaders(event.response.headers),
      });
    });
    cdp.on('Network.loadingFailed', event => {
      if (!tracedRequestIds.has(event.requestId)) return;
      record(result.asset_network_trace, {
        event: 'failed', at: new Date().toISOString(), cdp_timestamp: event.timestamp,
        request_id: event.requestId, error_text: event.errorText, canceled: event.canceled || false,
        ...tracedRequestContexts.get(event.requestId),
        blocked_reason: event.blockedReason || null, cors_error_status: event.corsErrorStatus || null,
      });
    });
    cdp.on('Network.loadingFinished', event => {
      if (!tracedRequestIds.has(event.requestId)) return;
      record(result.asset_network_trace, {
        event: 'finished', at: new Date().toISOString(), cdp_timestamp: event.timestamp,
        request_id: event.requestId, encoded_data_length: event.encodedDataLength,
        ...tracedRequestContexts.get(event.requestId),
      });
    });
    await cdp.send('Network.enable');
    page.on('pageerror', error => record(result.page_errors, String(error.message).slice(0, 500)));
    page.on('console', message => {
      const text = message.text();
      if (message.type() === 'error' || /SCRIPT ERROR|Parse Error|Failed to load script/.test(text)) record(result.console_errors, text.slice(0, 500));
    });
    page.on('response', response => {
      if (response.request().resourceType() !== 'document' && response.status() !== 200) record(result.non_200_assets, { status: response.status(), url: response.url() });
    });
    page.on('requestfailed', request => {
      const failure = request.failure()?.errorText || 'request failed';
      const pendingBeforeReload = reloadPendingRequests?.has(request) === true;
      const expected = expectedNavigationAbort(failure, activeUiAction, pendingBeforeReload);
      pendingRequests.delete(request);
      const entry = {
        at: new Date().toISOString(), url: request.url(), resource_type: request.resourceType(), failure,
        method: request.method(), request_headers: request.headers(),
        request_start: requestStarts.get(request) || null,
        in_flight_before_explicit_reload: pendingBeforeReload,
        active_ui_action: activeUiAction ? { ...activeUiAction } : null,
        expected_navigation_abort: expected,
      };
      // Only an exact Request known in flight before this reload may be an
      // expected cancellation. New/unknown requests still fail, even during it.
      record(result.failed_requests, entry);
      if (expected) record(result.expected_navigation_aborts, entry);
      else unexpectedRequestFailure = true;
    });
    const waitForGameReady = async phase => {
      // This exported shell removes #status only after engine.startGame()
      // resolves. Canvas dimensions alone become nonzero before PCK loading.
      const readyDeadline = Date.now() + remaining(90000);
      let marker;
      do {
        checkDeadline();
        marker = await passiveEvaluate(cdp, () => {
          const canvas = document.querySelector('canvas');
          const notice = document.getElementById('status-notice');
          const noticeVisible = Boolean(notice && getComputedStyle(notice).display !== 'none'
            && getComputedStyle(notice).visibility !== 'hidden');
          return {
            criterion: 'godot_start_game_loader_removed_and_canvas_nonzero',
            loader_status_present: Boolean(document.getElementById('status')),
            loader_notice: noticeVisible ? notice.textContent.trim().slice(0, 500) : '',
            canvas_width: canvas?.width || 0, canvas_height: canvas?.height || 0,
            document_ready_state: document.readyState,
          };
        });
        if (marker.loader_notice || !marker.loader_status_present && marker.canvas_width && marker.canvas_height) break;
        await sleep(Math.min(200, remaining(200)));
      } while (Date.now() < readyDeadline);
      record(result.game_readiness_markers, { phase, at: new Date().toISOString(), url: page.url(), ...marker });
      if (marker.loader_notice) throw Error('Godot loader failed: ' + marker.loader_notice);
      if (marker.loader_status_present || !marker.canvas_width || !marker.canvas_height) throw Error('Godot game readiness was not established: ' + phase);
    };
    const response = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: remaining(60000) });
    result.http_status = response?.status() || null;
    if (result.http_status !== 200) throw Error('Candidate entry did not return HTTP 200.');
    await waitForGameReady('initial');
    await passiveEvaluate(cdp, registerTrustedGestures);
    result.final_url = page.url();
    if (args['--url']) {
      const resolved = new URL(page.url());
      if (resolved.origin !== new URL(target).origin || !resolved.pathname.split('/').includes(args['--expected-sha'])) throw Error('NEXT resolved to an unexpected commit: ' + page.url());
    }
    await sleep(Math.min(2000, remaining(2000)));
    const shot = async (seq, label, actions = []) => {
      checkDeadline();
      const filename = `frame-${String(seq).padStart(2, '0')}-${label}.png`;
      const screenshot = await cdp.send('Page.captureScreenshot', { format: 'png', fromSurface: true, captureBeyondViewport: false });
      fs.writeFileSync(path.join(paths.evidence, filename), Buffer.from(screenshot.data, 'base64'), { flag: 'wx' });
      const canvas = await passiveEvaluate(cdp, () => {
        const element = document.querySelector('canvas');
        if (!element) throw Error('The game canvas is absent.');
        const rect = element.getBoundingClientRect();
        return { width: element.width, height: element.height, visible_width: rect.width, visible_height: rect.height };
      });
      result.stages.push({ seq, label, at: new Date().toISOString(), screenshot: filename, actions, canvas, viewport: page.viewportSize(), url: page.url(), audio: await audioSnapshot(cdp) });
      writeJson('progress.json', result);
      console.log('CRT_WEB_FRAME ' + seq + ' ' + label);
    };
    await shot(0, 'startup');
    for (let seq = 1; seq <= MAX_COMMANDS; seq++) {
      checkDeadline();
      const commandPath = path.join(control, `command-${String(seq).padStart(2, '0')}.json`);
      while (!fs.existsSync(commandPath)) { checkDeadline(); await sleep(200); }
      const command = validatedCommand(JSON.parse(fs.readFileSync(commandPath, 'utf8')), args.viewport);
      for (const [actionIndex, action] of command.actions.entries()) {
        checkDeadline();
        activeUiAction = { seq, command_label: command.label, action_index: actionIndex, kind: action.kind, at: new Date().toISOString() };
        const gesture = ['click', 'touch', 'key', 'type'].includes(action.kind);
        const gestureBefore = gesture ? await audioSnapshot(cdp) : null;
        reloadPendingRequests = action.kind === 'reload' ? new Set(pendingRequests) : null;
        if (reloadPendingRequests) activeUiAction.in_flight_request_sequences = [...reloadPendingRequests].map(request => requestStarts.get(request)?.sequence || null);
        if (action.kind === 'click') await page.mouse.click(action.x, action.y);
        else if (action.kind === 'touch') await page.touchscreen.tap(action.x, action.y);
        else if (action.kind === 'wheel') await page.mouse.wheel(0, action.dy);
        else if (action.kind === 'key') await page.keyboard.press(action.value);
        else if (action.kind === 'type') await page.keyboard.type(action.value);
        else if (action.kind === 'wait') await sleep(Math.min(action.ms, remaining(action.ms)));
        else if (action.kind === 'start_audio_capture') {
          if (audioCaptureStarted) throw Error('Only one bounded recording is allowed in a fresh worker.');
          result.audio_start = await startAudioCapture(cdp, action.seconds ?? 42);
          audioCaptureStarted = true;
        }
        else if (action.kind === 'stop_audio_capture') await saveAudioCapture('explicit_capture_stop');
        else if (action.kind === 'reload') {
          if (audioCaptureStarted && !audioCaptureSaved) throw Error('Stop and preserve the owned audio capture before an ordinary reload.');
          const reloadResponse = await page.reload({ waitUntil: 'domcontentloaded', timeout: remaining(60000) });
          if (reloadResponse?.status() !== 200) throw Error('Ordinary reload did not return HTTP 200.');
          await waitForGameReady(`reload-${seq}-${actionIndex}`);
          await passiveEvaluate(cdp, registerTrustedGestures);
          await sleep(Math.min(2000, remaining(2000)));
        }
        else if (action.kind === 'stop') { await saveAudioCapture('explicit_worker_stop'); result.stopped = true; }
        if (gesture) record(result.gesture_observations, { seq, command_label: command.label, action_index: actionIndex, kind: action.kind, before: gestureBefore, after: await audioSnapshot(cdp) });
        activeUiAction = null;
        reloadPendingRequests = null;
        if (result.stopped) break;
        await sleep(Math.min(350, remaining(350)));
      }
      await sleep(Math.min(400, remaining(400)));
      await shot(seq, command.label, command.actions);
      if (result.stopped) break;
    }
    if (!result.stopped) throw Error('Command limit reached without an explicit stop.');
    result.trusted_ui_gesture_observed = result.stages.some(stage => stage.audio.trusted_gestures.some(gesture => gesture.is_trusted && gesture.activation_has_been_active));
    const firstGestureBefore = result.gesture_observations[0]?.before;
    result.normal_first_gesture_unlock_observed = firstGestureBefore?.user_activation.has_been_active === false && firstGestureBefore.context_state !== 'running'
      && result.stages.some(stage => stage.audio.context_state === 'running' && stage.audio.bridge_unlocked && stage.audio.user_activation.has_been_active);
    result.passed = result.page_errors.length === 0 && result.console_errors.length === 0 && !result.non_200_assets.some(asset => asset.status >= 400) && !unexpectedRequestFailure && result.audio_capture?.passed === true && result.trusted_ui_gesture_observed && result.normal_first_gesture_unlock_observed;
    if (!result.passed) process.exitCode = 1;
  } catch (error) {
    activeUiAction = null;
    reloadPendingRequests = null;
    result.error = String(error).slice(0, 1000);
    result.passed = false;
    process.exitCode = 1;
    console.error('CRT_WEB_ERROR ' + result.error);
  } finally {
    activeUiAction = null;
    reloadPendingRequests = null;
    if (timer) clearTimeout(timer);
    if (saveAudioCapture && audioCaptureStarted && !audioCaptureSaved) {
      try { await saveAudioCapture('worker_finally'); }
      catch (error) { result.cleanup_errors.push('Audio evidence: ' + String(error).slice(0, 300)); }
    }
    if (context) {
      try { await context.close(); result.browser_closed = true; }
      catch (error) { result.cleanup_errors.push('Browser: ' + String(error).slice(0, 300)); }
    }
    if (server) {
      try { await new Promise(resolve => server.close(resolve)); result.server_closed = true; }
      catch (error) { result.cleanup_errors.push('Server: ' + String(error).slice(0, 300)); }
    }
    if (result.cleanup_errors.length) { result.passed = false; process.exitCode = 1; }
    // Include failures delivered while the browser/server were closing too.
    result.unexpected_request_failure = unexpectedRequestFailure;
    if (unexpectedRequestFailure) { result.passed = false; process.exitCode = 1; }
    result.finished_at = new Date().toISOString();
    result.elapsed_ms = Date.now() - started;
    writeJson('result.json', result);
    console.log('CRT_WEB_RESULT ' + JSON.stringify(result));
  }
}

main().catch(error => { console.error('CRT_WEB_ADMISSION_ERROR ' + String(error).slice(0, 1000)); process.exitCode = 1; });
