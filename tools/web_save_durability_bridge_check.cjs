'use strict';

// Exercises the exact adapter installed by GDScript. No browser/save/profile I/O.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../scripts/ui/web_save_durability_bridge.gd'), 'utf8');
const script = source.match(/const WEB_ADAPTER_SCRIPT := """\r?\n([\s\S]*?)\r?\n"""/)[1];
let checks = 0;
function check(actual, expected) { assert.deepEqual(actual, expected); checks++; }
function deferred() {
    let resolve, reject;
    const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
    return {promise, resolve, reject};
}
function runtime(options = {}) {
    const initial = deferred();
    const clock = {now: 0};
    const context = {
        GodotOS: {_fs_sync_promise: initial.promise},
        GodotFS: {is_persistent: () => options.persistent !== false},
        performance: {now: () => clock.now},
    };
    if (options.unsupported) delete context.GodotOS;
    vm.createContext(context);
    const installed = vm.runInContext(script, context);
    return {initial, clock, context, installed, bridge: context.BTHWebSaveDurability};
}
const result = (value) => JSON.parse(value);
async function settle() { await Promise.resolve(); await Promise.resolve(); }

(async () => {
    // An old in-flight sync, including its completion, cannot acknowledge Save.
    const first = runtime();
    check(first.installed, true);
    const request = result(first.bridge.begin(1000));
    check(request.status, 'pending');
    check(result(first.bridge.poll(request.request_id)).status, 'pending');
    first.initial.resolve();
    await settle();
    check(result(first.bridge.poll(request.request_id)).status, 'pending');
    const next = deferred();
    first.context.GodotOS._fs_sync_promise = next.promise;
    check(result(first.bridge.poll(request.request_id)).status, 'pending');
    next.resolve(null);
    await settle();
    check(result(first.bridge.poll(request.request_id)).status, 'succeeded');

    // Engine sync errors arrive asynchronously after the request was accepted.
    const failed = runtime();
    const failedId = result(failed.bridge.begin(1000)).request_id;
    const bad = deferred();
    failed.context.GodotOS._fs_sync_promise = bad.promise;
    check(result(failed.bridge.poll(failedId)).status, 'pending');
    bad.resolve(new Error('IndexedDB write failed'));
    await settle();
    check(result(failed.bridge.poll(failedId)).error_code, 'browser_sync_failed');

    // Rejection is also a failure; unsupported persistence never enters pending.
    const rejected = runtime();
    const rejectedId = result(rejected.bridge.begin(1000)).request_id;
    const rejection = deferred();
    rejected.context.GodotOS._fs_sync_promise = rejection.promise;
    rejected.bridge.poll(rejectedId);
    rejection.reject(new Error('transaction rejected'));
    await settle();
    check(result(rejected.bridge.poll(rejectedId)).status, 'failed');
    check(runtime({unsupported: true}).installed, false);
    check(runtime({persistent: false}).installed, false);

    // Timeout remains failed even when a late callback eventually succeeds.
    const timed = runtime();
    const timedId = result(timed.bridge.begin(1000)).request_id;
    const late = deferred();
    timed.context.GodotOS._fs_sync_promise = late.promise;
    timed.bridge.poll(timedId);
    timed.clock.now = 1000;
    check(result(timed.bridge.poll(timedId)).error_code, 'browser_sync_timeout');
    late.resolve(null);
    await settle();
    check(result(timed.bridge.poll(timedId)).status, 'failed');

    // A missing next sync times out; a request cannot replace one still pending.
    const absent = runtime();
    const absentId = result(absent.bridge.begin(1000)).request_id;
    check(result(absent.bridge.begin(1000)).error_code, 'browser_sync_busy');
    absent.clock.now = 1001;
    check(result(absent.bridge.poll(absentId)).error_code, 'browser_sync_timeout');
    absent.context.GodotOS._fs_sync_promise = null;
    check(result(absent.bridge.begin(1000)).error_code, 'browser_sync_unsupported');
    console.log(JSON.stringify({test: 'web_save_durability_bridge', checks, failures: []}));
})().catch((error) => { console.error(error); process.exitCode = 1; });
