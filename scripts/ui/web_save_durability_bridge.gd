class_name WebSaveDurabilityBridge
extends RefCounted

# Godot 4.6's public force_fs_sync marks a pending sync; it does not acknowledge
# persistence. Manual Save observes its next engine-owned promise. Lifecycle
# requests queue the same engine sync directly because hidden-page RAF can stop.
# Serialize automatic engine callers too, preserving a distinct promise per call.
# Neither path calls FS.syncfs directly or depends on the IndexedDB schema.
const SUPPORTED_ENGINE_HASH_PREFIX := "89cea1439"
const TIMEOUT_MSEC := 15000
const WEB_ADAPTER_SCRIPT := """
(() => {
    const supported = () => typeof GodotOS !== 'undefined'
        && typeof GodotFS !== 'undefined'
        && typeof GodotFS.is_persistent === 'function'
        && GodotFS.is_persistent()
        && GodotOS._fs_sync_promise
        && typeof GodotOS._fs_sync_promise.then === 'function';
    if (!supported()) return false;
    if (globalThis.BTHWebSaveDurability) return globalThis.BTHWebSaveDurability.protocol === 1;
    let sequence = 0;
    let request = null;
    let syncQueueInstalled = false;
    const result = (state) => JSON.stringify({
        request_id: state.id, status: state.status, error_code: state.error || ''
    });
    const fail = (state, code) => {
        if (state.status === 'pending') { state.status = 'failed'; state.error = code; }
    };
    globalThis.BTHWebSaveDurability = {
        protocol: 1,
        request_lifecycle_sync() {
            if (!supported() || typeof GodotFS.sync !== 'function') return false;
            if (!syncQueueInstalled) {
                const engineSync = GodotFS.sync.bind(GodotFS);
                let tail = GodotOS._fs_sync_promise;
                GodotFS.sync = () => {
                    const next = Promise.resolve(tail)
                        .catch(() => undefined)
                        .then(() => engineSync());
                    tail = next;
                    return next;
                };
                syncQueueInstalled = true;
            }
            GodotOS._fs_sync_promise = GodotFS.sync();
            return true;
        },
        begin(timeout) {
            if (request && request.status === 'pending')
                return JSON.stringify({request_id: 0, status: 'failed', error_code: 'browser_sync_busy'});
            if (!supported())
                return JSON.stringify({request_id: 0, status: 'failed', error_code: 'browser_sync_unsupported'});
            request = {
                id: ++sequence, status: 'pending', error: '',
                baseline: GodotOS._fs_sync_promise, observed: null,
                started: performance.now(), timeout: timeout
            };
            return result(request);
        },
        poll(id) {
            const state = request;
            if (!state || state.id !== id)
                return JSON.stringify({request_id: id, status: 'failed', error_code: 'browser_sync_request_missing'});
            if (state.status !== 'pending') return result(state);
            if (performance.now() - state.started >= state.timeout) {
                fail(state, 'browser_sync_timeout');
            } else if (!supported()) {
                fail(state, 'browser_sync_unsupported');
            } else if (!state.observed && GodotOS._fs_sync_promise !== state.baseline) {
                state.observed = GodotOS._fs_sync_promise;
                state.observed.then((error) => {
                    if (state.status !== 'pending') return;
                    if (error !== null && error !== undefined) fail(state, 'browser_sync_failed');
                    else state.status = 'succeeded';
                }, () => fail(state, 'browser_sync_failed'));
            }
            return result(state);
        }
    };
    return true;
})();
"""

var _interface: Variant = null
var _request_id := 0


func begin() -> Dictionary:
	var version := Engine.get_version_info()
	if not OS.has_feature("web") or int(version.get("major", -1)) != 4 \
			or int(version.get("minor", -1)) != 6 or int(version.get("patch", -1)) != 0 \
			or str(version.get("status", "")) != "stable" \
			or not str(version.get("hash", "")).begins_with(SUPPORTED_ENGINE_HASH_PREFIX):
		return _failure("browser_sync_unsupported")
	# The non-global context is required: GodotOS belongs to this engine module.
	if not bool(JavaScriptBridge.eval(WEB_ADAPTER_SCRIPT, false)):
		return _failure("browser_sync_unsupported")
	_interface = JavaScriptBridge.get_interface("BTHWebSaveDurability")
	if _interface == null:
		return _failure("browser_sync_unsupported")
	var result := _decode(_interface.begin(TIMEOUT_MSEC))
	if not bool(result.get("pending", false)):
		return result
	_request_id = int(result.get("request_id", 0))
	# Capture above occurs after VFS installation. Require a distinct future
	# promise, so an older in-flight sync cannot acknowledge this Save.
	JavaScriptBridge.force_fs_sync()
	return result


# A background/pagehide boundary cannot await the manual Save acknowledgement.
# Start an engine-owned sync without waiting for another animation frame.
func request_lifecycle_sync() -> bool:
	if not OS.has_feature("web") or not bool(JavaScriptBridge.eval(WEB_ADAPTER_SCRIPT, false)):
		return false
	var lifecycle_interface: Variant = JavaScriptBridge.get_interface("BTHWebSaveDurability")
	return lifecycle_interface != null and bool(lifecycle_interface.request_lifecycle_sync())


func poll() -> Dictionary:
	if _interface == null or _request_id <= 0:
		return _failure("browser_sync_request_missing")
	return _decode(_interface.poll(_request_id))


func _decode(value: Variant) -> Dictionary:
	var parsed: Variant = JSON.parse_string(str(value))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("browser_sync_invalid_response")
	var status := str(parsed.get("status", ""))
	if not ["pending", "succeeded", "failed"].has(status):
		return _failure("browser_sync_invalid_response")
	return {
		"ok": status == "succeeded", "pending": status == "pending",
		"error_code": str(parsed.get("error_code", "")),
		"request_id": int(parsed.get("request_id", 0)),
	}


func _failure(code: String) -> Dictionary:
	return {"ok": false, "pending": false, "error_code": code}
