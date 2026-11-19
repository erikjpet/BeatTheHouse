'use strict';

// Screenshot-driven CRT acceptance, launched only by bth_qa_guarded_run.py.
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
// stop. A stop must be the last action and is required for a successful finish.

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const { chromium } = require('D:/Projects/site/node_modules/playwright');

const CHROMIUM = 'C:/Users/theep/AppData/Local/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-win64/chrome-headless-shell.exe';
const APPROVED_ROOT = 'E:\\CodexQA\\BTH';
const HARD_LIMIT_MS = 480000;
const MAX_COMMANDS = 40;
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
    const stop = action.kind === 'stop' && index === value.actions.length - 1;
    if (!pointer && !wheel && !key && !type && !wait && !reload && !stop) throw Error('Invalid bounded action at index ' + index);
  }
  return value;
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
        'Cross-Origin-Resource-Policy': 'same-origin', 'Cache-Control': 'no-store',
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
    schema: 'bth.crt_web_smoke/v1', mode: args['--root'] ? 'private_composite' : 'served_next',
    expected_source_commit: args['--expected-sha'] || null, started_at: new Date(started).toISOString(),
    requested_viewport: args.viewport,
    storage_manifest: paths.manifestPath, stages: [], game_readiness_markers: [], page_errors: [], console_errors: [], non_200_assets: [], failed_requests: [], expected_navigation_aborts: [], asset_network_trace: [], private_server_transfers: [], cleanup_errors: [],
    scope: 'Fresh screenshot-driven normal UI only. No save import, browser storage inspection, forced game state or physical controller claim.',
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
    guardedPaths();
    context = await chromium.launchPersistentContext(paths.profile, {
      headless: true, chromiumSandbox: true, executablePath: CHROMIUM,
      viewport: args.viewport, deviceScaleFactor: 1, hasTouch: true, serviceWorkers: 'block',
      timeout: remaining(60000),
    });
    const page = await context.newPage();
    page.setDefaultTimeout(15000);
    page.on('request', request => {
      pendingRequests.add(request);
      requestStarts.set(request, { sequence: ++requestSequence, at: new Date().toISOString() });
    });
    page.on('requestfinished', request => pendingRequests.delete(request));
    // Observe transport attribution without changing requests, responses or
    // acceptance. Keep only bounded PCK/WASM metadata, never response bodies.
    const cdp = await context.newCDPSession(page);
    const tracedRequestIds = new Set();
    const tracedRequestContexts = new Map();
    const responseHeaders = headers => {
      const lowered = Object.fromEntries(Object.entries(headers || {}).map(([key, value]) => [key.toLowerCase(), value]));
      return {
        content_length: lowered['content-length'] ?? null,
        content_range: lowered['content-range'] ?? null,
        accept_ranges: lowered['accept-ranges'] ?? null,
        content_type: lowered['content-type'] ?? null,
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
      await page.waitForFunction(() => {
        const canvas = document.querySelector('canvas');
        const status = document.getElementById('status');
        const notice = document.getElementById('status-notice');
        const failure = notice && getComputedStyle(notice).display !== 'none'
          && getComputedStyle(notice).visibility !== 'hidden' && notice.textContent.trim();
        return failure || (canvas && canvas.width > 0 && canvas.height > 0 && !status);
      }, null, { timeout: remaining(90000) });
      const marker = await page.evaluate(() => {
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
      record(result.game_readiness_markers, { phase, at: new Date().toISOString(), url: page.url(), ...marker });
      if (marker.loader_notice) throw Error('Godot loader failed: ' + marker.loader_notice);
      if (marker.loader_status_present || !marker.canvas_width || !marker.canvas_height) throw Error('Godot game readiness was not established: ' + phase);
    };
    const response = await page.goto(target, { waitUntil: 'domcontentloaded', timeout: remaining(60000) });
    result.http_status = response?.status() || null;
    if (result.http_status !== 200) throw Error('Candidate entry did not return HTTP 200.');
    await waitForGameReady('initial');
    result.final_url = page.url();
    if (args['--url']) {
      const resolved = new URL(page.url());
      if (resolved.origin !== new URL(target).origin || !resolved.pathname.split('/').includes(args['--expected-sha'])) throw Error('NEXT resolved to an unexpected commit: ' + page.url());
    }
    await sleep(Math.min(2000, remaining(2000)));
    const shot = async (seq, label, actions = []) => {
      checkDeadline();
      const filename = `frame-${String(seq).padStart(2, '0')}-${label}.png`;
      await page.screenshot({ path: path.join(paths.evidence, filename), timeout: remaining() });
      const canvas = await page.locator('canvas').first().evaluate(element => {
        const rect = element.getBoundingClientRect();
        return { width: element.width, height: element.height, visible_width: rect.width, visible_height: rect.height };
      });
      result.stages.push({ seq, label, at: new Date().toISOString(), screenshot: filename, actions, canvas, viewport: page.viewportSize(), url: page.url() });
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
        reloadPendingRequests = action.kind === 'reload' ? new Set(pendingRequests) : null;
        if (reloadPendingRequests) activeUiAction.in_flight_request_sequences = [...reloadPendingRequests].map(request => requestStarts.get(request)?.sequence || null);
        if (action.kind === 'click') await page.mouse.click(action.x, action.y);
        else if (action.kind === 'touch') await page.touchscreen.tap(action.x, action.y);
        else if (action.kind === 'wheel') await page.mouse.wheel(0, action.dy);
        else if (action.kind === 'key') await page.keyboard.press(action.value);
        else if (action.kind === 'type') await page.keyboard.type(action.value);
        else if (action.kind === 'wait') await sleep(Math.min(action.ms, remaining(action.ms)));
        else if (action.kind === 'reload') {
          const reloadResponse = await page.reload({ waitUntil: 'domcontentloaded', timeout: remaining(60000) });
          if (reloadResponse?.status() !== 200) throw Error('Ordinary reload did not return HTTP 200.');
          await waitForGameReady(`reload-${seq}-${actionIndex}`);
          await sleep(Math.min(2000, remaining(2000)));
        }
        else if (action.kind === 'stop') result.stopped = true;
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
    result.passed = result.page_errors.length === 0 && result.console_errors.length === 0 && !result.non_200_assets.some(asset => asset.status >= 400) && !unexpectedRequestFailure;
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
