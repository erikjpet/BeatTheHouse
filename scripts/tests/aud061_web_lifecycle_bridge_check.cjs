const fs=require('fs'),vm=require('vm'),path=require('path');
const source=fs.readFileSync(path.resolve('scripts/ui/web_save_durability_bridge.gd'),'utf8');
const script=source.match(/const WEB_ADAPTER_SCRIPT := """([\s\S]*?)"""/)[1];
let checks=0;const failures=[];const observations=[];
function check(ok,label){checks++;if(!ok)failures.push(label)}
function setup(previous=Promise.resolve(null)){
 const state={generation:1,persisted:0,calls:0,persistent:true};
 const context={GodotOS:{_fs_sync_promise:previous},GodotFS:{is_persistent:()=>state.persistent,sync:()=>{state.calls++;const generation=state.generation;return Promise.resolve().then(()=>{state.persisted=generation;return null})}},performance:{now:()=>0}};
 vm.createContext(context);check(vm.runInContext(script,context)===true,'Actual adapter installs');
 return {state,context,bridge:context.BTHWebSaveDurability};
}
(async()=>{
 let release;const older=new Promise(r=>release=r);let x=setup(older);
 check(typeof x.bridge.request_lifecycle_sync==='function','Actual adapter has immediate lifecycle request API');
 if(typeof x.bridge.request_lifecycle_sync!=='function'){console.log('AUD061_08_BRIDGE '+JSON.stringify({checks,failures,scope:'Actual shipping adapter JavaScript, controlled engine promises; not IndexedDB or exported runtime evidence.'}));process.exitCode=1;return}
 check(x.bridge.request_lifecycle_sync()===true,'Lifecycle request accepted without a frame');
 const requested=x.context.GodotOS._fs_sync_promise;
 check(requested!==older,'Engine owns a new promise immediately');
 check(x.state.calls===0,'Existing engine sync drains before new sync starts');
 x.state.generation=2;release(null);await requested;
 check(x.state.calls===1&&x.state.persisted===2,'New sync persists current generation after older sync');
 observations.push({case:'older_sync',calls:x.state.calls,persisted:x.state.persisted});
 let manual=JSON.parse(x.bridge.begin(15000));check(manual.status==='pending','Manual acknowledgement flow still begins');
 check(x.bridge.request_lifecycle_sync()===true,'Lifecycle request does not consume manual request slot');
 check(JSON.parse(x.bridge.begin(15000)).error_code==='browser_sync_busy','Existing manual busy guard remains');
 await x.context.GodotOS._fs_sync_promise;
 let poll=JSON.parse(x.bridge.poll(manual.request_id));await Promise.resolve();poll=JSON.parse(x.bridge.poll(manual.request_id));
 check(poll.status==='succeeded','Manual acknowledgement observes exact future engine promise');
 manual=JSON.parse(x.bridge.begin(15000));check(manual.status==='pending','Later manual Save remains usable');
 x.context.GodotFS.sync=()=>Promise.resolve(new Error('controlled IDB failure'));
 check(x.bridge.request_lifecycle_sync()===true,'Failing asynchronous request is still submitted');
 await x.context.GodotOS._fs_sync_promise;x.bridge.poll(manual.request_id);await Promise.resolve();
 check(JSON.parse(x.bridge.poll(manual.request_id)).error_code==='browser_sync_failed','Existing manual ack does not report failed sync as success');
 x=setup(Promise.reject(new Error('older rejected sync')));
 check(x.bridge.request_lifecycle_sync()===true,'Request retries after older rejected engine promise');
 await x.context.GodotOS._fs_sync_promise;
 check(x.state.calls===1&&x.state.persisted===1,'Older rejection does not prevent current sync');
 x=setup();x.state.persistent=false;const unchanged=x.context.GodotOS._fs_sync_promise;
 check(x.bridge.request_lifecycle_sync()===false,'Unavailable persistence rejects request');
 check(x.context.GodotOS._fs_sync_promise===unchanged&&x.state.calls===0,'Rejected request leaves engine queue unchanged');
 x=setup();delete x.context.GodotFS.sync;
 check(x.bridge.request_lifecycle_sync()===false,'Missing engine sync method rejects safely');
 console.log('AUD061_08_BRIDGE '+JSON.stringify({checks,failures,observations,scope:'Actual shipping adapter JavaScript evaluated in Node VM with controlled engine promises. Tests sequencing/current generation/manual acknowledgement/error propagation. Not IndexedDB or exported runtime evidence; exact deployed Web capture is separate.'}));
 process.exitCode=failures.length?1:0;
})().catch(e=>{console.error(e);process.exitCode=1});
