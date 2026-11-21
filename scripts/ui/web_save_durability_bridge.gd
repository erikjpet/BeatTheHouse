class_name WebSaveDurabilityBridge
extends RefCounted

# This bridge requires the separately pinned BTH Web template capability.
# The template binds each manual request ID to its own FS.syncfs callback;
# a changed or already-resolved engine Promise is never treated as an ack.
const SUPPORTED_ENGINE_HASH_PREFIX := "89cea1439"
const TIMEOUT_MSEC := 15000
const WEB_ADAPTER_SCRIPT := """
(() => {
    const engine = () => typeof Module !== 'undefined' && Module['bthSaveSyncV1'];
    const supported = () => engine() && typeof engine().begin === 'function'
        && typeof engine().poll === 'function' && typeof engine().consume === 'function'
        && typeof engine().lifecycle === 'function';
    if (!supported()) return false;
    if (globalThis.BTHWebSaveDurability) return globalThis.BTHWebSaveDurability.protocol === 4;
    let request = null;
    const result = (state) => JSON.stringify({
        request_id: state.id, generation: state.generation,
        status: state.status, slow: !!state.slow, cancelled: !!state.cancelled,
        error_code: state.error || ''
    });
    const fail = (state, code) => {
        if (state.status === 'pending') { state.status = 'failed'; state.error = code; }
    };
    globalThis.BTHWebSaveDurability = {
        protocol: 4,
        request_lifecycle_sync() {
            return !!(supported() && engine().lifecycle());
        },
        begin(generation, timeout) {
            if (request && request.status === 'pending')
                return JSON.stringify({request_id: 0, status: 'failed',
                    error_code: request.cancelled ? 'browser_sync_prior_unconfirmed' : 'browser_sync_busy'});
            if (!supported())
                return JSON.stringify({request_id: 0, status: 'failed', error_code: 'browser_sync_unsupported'});
            let started;
            try { started = JSON.parse(engine().begin(generation)); }
            catch (_) { return JSON.stringify({request_id: 0, status: 'failed', error_code: 'browser_sync_invalid_response'}); }
            if (started && started.protocol === 1 && started.status === 'failed')
                return JSON.stringify({request_id: 0, generation: generation, status: 'failed',
                    error_code: started.error_code || 'browser_sync_failed'});
            if (!started || started.protocol !== 1 || started.status !== 'pending'
                || !Number.isInteger(started.request_id) || started.request_id <= 0
                || started.generation !== generation)
                return JSON.stringify({request_id: 0, status: 'failed', error_code: 'browser_sync_invalid_response'});
            request = {
                id: started.request_id, generation: generation, status: 'pending', error: '',
                started: performance.now(), timeout: timeout, slow: false, cancelled: false
            };
            return result(request);
        },
        cancel(id) {
            const state = request;
            if (!state || state.id !== id || state.status !== 'pending')
                return JSON.stringify({request_id: id, status: 'failed', error_code: 'browser_sync_request_missing'});
            // The physical operation cannot be canceled. Keep it identifiable
            // and prevent another manual generation until its callback settles.
            state.cancelled = true;
            return result(state);
        },
        poll(id) {
            const state = request;
            if (!state || state.id !== id)
                return JSON.stringify({request_id: id, status: 'failed', error_code: 'browser_sync_request_missing'});
            if (state.status !== 'pending') return result(state);
            if (!supported()) {
                state.slow = true;
                return result(state); // Unknown physical outcome: fail closed.
            } else {
                let observed;
                try { observed = JSON.parse(engine().poll(id)); }
                catch (_) { state.slow = true; return result(state); }
                if (!observed || observed.protocol !== 1 || observed.request_id !== id
                    || observed.generation !== state.generation) {
                    state.slow = true; // Cannot prove the physical callback ended.
                } else if (observed.status === 'succeeded') {
                    if (engine().consume(id)) {
                        state.status = state.cancelled ? 'failed' : 'succeeded';
                        if (state.cancelled) state.error = 'browser_sync_unconfirmed';
                    } else state.slow = true;
                } else if (observed.status === 'failed') {
                    if (engine().consume(id))
                        fail(state, state.cancelled ? 'browser_sync_unconfirmed' : observed.error_code || 'browser_sync_failed');
                    else state.slow = true;
                } else if (observed.status !== 'pending') {
                    state.slow = true;
                }
            }
            // The 15-second marker is only an honest pending UI state. Check the
            // exact engine result first, including a callback settled this frame.
            if (state.status === 'pending' && performance.now() - state.started >= state.timeout)
                state.slow = true;
            return result(state);
        }
    };
    return true;
})();
"""

var _interface: Variant = null
var _request_id := 0


func begin(generation: String) -> Dictionary:
	if generation.is_empty():
		return _failure("browser_sync_invalid_request")
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
	var result := _decode(_interface.begin(generation, TIMEOUT_MSEC))
	if not bool(result.get("pending", false)):
		return result
	_request_id = int(result.get("request_id", 0))
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


func cancel() -> Dictionary:
	if _interface == null or _request_id <= 0:
		return _failure("browser_sync_request_missing")
	return _decode(_interface.cancel(_request_id))


func _decode(value: Variant) -> Dictionary:
	var parsed: Variant = JSON.parse_string(str(value))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("browser_sync_invalid_response")
	var status := str(parsed.get("status", ""))
	if not ["pending", "succeeded", "failed"].has(status):
		return _failure("browser_sync_invalid_response")
	return {
		"ok": status == "succeeded", "pending": status == "pending",
		"slow": bool(parsed.get("slow", false)),
		"cancelled": bool(parsed.get("cancelled", false)),
		"error_code": str(parsed.get("error_code", "")),
		"request_id": int(parsed.get("request_id", 0)),
		"generation": str(parsed.get("generation", "")),
	}


func _failure(code: String) -> Dictionary:
	return {"ok": false, "pending": false, "error_code": code}
