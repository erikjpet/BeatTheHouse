const fs=require('fs'),path=require('path'),cp=require('child_process');
const {chromium}=require('D:/Projects/site/node_modules/playwright');
const sha=process.argv[2],evidence=process.env.BTH_QA_EVIDENCE_DIR,workspace=process.env.BTH_QA_WORKSPACE;
if(!/^[0-9a-f]{40}$/.test(sha))throw Error('Exact commit required');
const inbox=path.join(workspace,'.tmp/aud061-ui-command.json');
const gateCode=`import sys,os,json\nfrom pathlib import Path\nsys.path.insert(0,r'D:\\Projects\\Beat-The-House\\tools')\nfrom bth_qa_storage import Layout,check_launch\nm=json.loads((Path(os.environ['BTH_QA_EVIDENCE_DIR'])/'storage-manifest.json').read_text())\nl=Layout(**{k:Path(v) for k,v in m['paths'].items()},run_id=m['run_id'],token=m['token'],prepared=True,expected_write_bytes=m['expected_write_bytes'],reserve_bytes=m['reserve_bytes'])\nprint(json.dumps(check_launch(l,cwd=os.getcwd(),env=os.environ,extra_write_paths=(l.profile,l.cache,l.temp,l.evidence))))`;
const gate=cp.spawnSync('C:/Users/theep/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',['-B','-c',gateCode],{encoding:'utf8',windowsHide:true});if(gate.status!==0)throw Error(gate.stderr||gate.stdout);
fs.writeFileSync(path.join(evidence,'browser-launch-gate.json'),gate.stdout);
const record={sha,scope:'Unmodified exact NEXT HTML/PCK/engine/native; ordinary Settings, Copy diagnostics, Daily Challenge and Save inputs; no scene/script/path override. Clipboard read occurs only immediately after the owned Copy diagnostics click and returns only the expected report identity/fields.',errors:[],console:[],actions:[],assets:[]};let context;
function save(){fs.writeFileSync(path.join(evidence,'result-partial.json'),JSON.stringify(record,null,2))}
async function info(page){return await page.evaluate(async()=>{const m=engine.rtenv,F=m&&m.FS;const result={fsAvailable:!!F,moduleKeys:m?Object.keys(m).filter(k=>/^(FS|copyToFS|initFS)$/.test(k)):[]};if(!F)return result;let files=[];function walk(p,d){if(d>6||files.length>100)return;let names;try{names=F.readdir(p)}catch{return}for(const n of names){if(n==='.'||n==='..')continue;const x=p+'/'+n;let st;try{st=F.stat(x)}catch{continue}if(F.isDir(st.mode))walk(x,d+1);else if(/foundation_ui_autosave\.json(?:\.bak)?$/.test(x))files.push(x)}}walk('/userfs',0);result.saveFiles=files;const primary=files.find(x=>x.endsWith('/foundation_ui_autosave.json'));if(primary){const bytes=F.readFile(primary);result.path=primary;result.bytes=bytes.length;result.sha256=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');result.backupRollback=F.analyzePath(primary+'.bak.rollback').exists;result.primaryRollback=F.analyzePath(primary+'.rollback').exists;result.tmpExists=F.analyzePath(primary+'.tmp').exists;}return result})}

record.scope='Exact unmodified NEXT assets, ordinary Daily/Sleep/Continue controls. Fresh owned Chrome, public noDefaults attachment, real minimized hidden events. DOM-only trusted-pointer/lifecycle observation; no game state/scene/path override, no helper filesystem sync.';
async function observe(page){await page.evaluate(()=>{window.__AUD08Pointer=null;window.__AUD08LifecycleEvents=[];document.addEventListener('pointerup',e=>{window.__AUD08Pointer={time:e.timeStamp,trusted:e.isTrusted}},true);const log=e=>{const x={event:e.type,time:e.timeStamp,listener_time:performance.now(),hidden:document.hidden,visibility:document.visibilityState,pointer:window.__AUD08Pointer,persisted:!!e.persisted};window.__AUD08LifecycleEvents.push(x);console.info('AUD08_LIFECYCLE '+JSON.stringify(x))};document.addEventListener('visibilitychange',log,true);window.addEventListener('pagehide',log,true)})}
(async()=>{try{
let ownedBrowser,ownedChrome;
const profile=process.env.BTH_QA_PROFILE_DIR;
fs.mkdirSync(path.join(profile,'Default'),{recursive:true});
fs.writeFileSync(path.join(profile,'Default','Preferences'),JSON.stringify({download:{default_directory:process.env.BTH_QA_TEMP_DIR,prompt_for_download:true}}));
const prechild=cp.spawnSync('C:/Users/theep/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',['-B','-c',gateCode],{encoding:'utf8',windowsHide:true});if(prechild.status!==0)throw Error(prechild.stderr||prechild.stdout);fs.writeFileSync(path.join(evidence,'pre-browser-child-launch-gate.json'),prechild.stdout);
ownedChrome=cp.spawn('C:/Users/theep/AppData/Local/ms-playwright/chromium-1243/chrome-win64/chrome.exe',[`--user-data-dir=${profile}`,`--disk-cache-dir=${process.env.XDG_CACHE_HOME}`,`--crash-dumps-dir=${process.env.BTH_QA_TEMP_DIR}`,'--remote-debugging-port=0','--remote-debugging-address=127.0.0.1','--no-first-run','--no-default-browser-check','--disable-component-update','--disable-background-networking','--disable-sync','--enable-unsafe-swiftshader','--disable-backgrounding-occluded-windows','--disable-background-timer-throttling','--disable-renderer-backgrounding','--window-position=-32000,-32000','--window-size=1280,720','about:blank'],{windowsHide:true,stdio:'ignore'});
globalThis.ownedChrome=ownedChrome;record.browserArguments=ownedChrome.spawnargs;
let port;for(let i=0;i<200;i++){try{port=Number(fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split('\n')[0]);if(port)break}catch{}await new Promise(r=>setTimeout(r,100))}if(!port)throw Error('Owned browser debugging endpoint not ready');
ownedBrowser=await chromium.connectOverCDP(`http://127.0.0.1:${port}`,{noDefaults:true,isLocal:true,artifactsDir:evidence});
globalThis.ownedBrowser=ownedBrowser;context=ownedBrowser.contexts()[0];record.frameworkMode='Fresh owned full Chrome; connectOverCDP noDefaults=true, no framework focus/media emulation';

const page=context.pages()[0]||await context.newPage();globalThis.probePage=page;
await page.setViewportSize({width:1280,height:720});await page.bringToFront();
page.on('pageerror',e=>{record.errors.push(String(e));save()});
page.on('console',m=>{const value=m.text();if(value.startsWith('AUD08_LIFECYCLE ')){record.lifecycleEvents=record.lifecycleEvents||[];record.lifecycleEvents.push(JSON.parse(value.slice(16)));save()}else if(m.type()==='error'||m.type()==='warning'){record.console.push({type:m.type(),text:value});save()}});
await page.goto('http://localhost:8088/p/beat-the-house/play/dev/'+sha+'/',{waitUntil:'domcontentloaded',timeout:20000});
await page.waitForSelector('#status',{state:'detached',timeout:60000});await page.waitForTimeout(2500);
await observe(page);await page.screenshot({path:path.join(evidence,'00-startup.png')});record.initial=await info(page);
await page.mouse.click(940,405);await page.waitForTimeout(3500);await page.screenshot({path:path.join(evidence,'01-daily.png')});record.daily=await info(page);
const cdp=await context.newCDPSession(page);const windowInfo=await cdp.send('Browser.getWindowForTarget');record.window=windowInfo;
record.stage='AWAITING_BOUNDED_UI_COMMAND';save();let last=0;try{const prior=JSON.parse(fs.readFileSync(inbox,'utf8'));if(prior.sha===sha)last=Number(prior.id)||0}catch{}
const deadline=Date.now()+15*60*1000;
while(Date.now()<deadline){
 let command;try{command=JSON.parse(fs.readFileSync(inbox,'utf8'))}catch{}
 if(!command||command.sha!==sha||command.id<=last){await page.waitForTimeout(200);continue}
 last=command.id;const entry={command,time:new Date().toISOString()};record.actions.push(entry);
 if(['click','click_hide_reload'].includes(command.type)){
  if(!Number.isFinite(command.x)||!Number.isFinite(command.y)||command.x<0||command.x>1280||command.y<0||command.y>720)throw Error('Point outside owned canvas');
  entry.before=await info(page);entry.beforeVisibility=await page.evaluate(()=>({hidden:document.hidden,visibility:document.visibilityState}));
  if(entry.beforeVisibility.hidden)throw Error('Action must start in actually visible page');
  await page.mouse.click(command.x,command.y);entry.clickCompletedEpoch=Date.now();
  if(command.type==='click_hide_reload'){
   const delay=command.delay??40;if(!Number.isFinite(delay)||delay<0||delay>120)throw Error('Bounded delay required');
   await page.waitForTimeout(delay);entry.minimizeRequestedEpoch=Date.now();
   await cdp.send('Browser.setWindowBounds',{windowId:windowInfo.windowId,bounds:{windowState:'minimized'}});entry.minimizeCompletedEpoch=Date.now();
   await page.waitForTimeout(100);
   entry.hiddenState=await page.evaluate(()=>({hidden:document.hidden,visibility:document.visibilityState,events:window.__AUD08LifecycleEvents,pointer:window.__AUD08Pointer}));
   entry.afterHidden=await info(page);
   const hiddenEvent=entry.hiddenState.events.filter(x=>x.event==='visibilitychange'&&x.hidden).at(-1);
   entry.hideWithin200ms=!!hiddenEvent&&!!hiddenEvent.pointer?.trusted&&hiddenEvent.time-hiddenEvent.pointer.time>=0&&hiddenEvent.time-hiddenEvent.pointer.time<=200;
   entry.eventDeltaMs=hiddenEvent?hiddenEvent.time-hiddenEvent.pointer.time:null;
   entry.hostMinimizeAfterClickMs=entry.minimizeCompletedEpoch-entry.clickCompletedEpoch;
   if(!entry.hiddenState.hidden)throw Error('No real hidden boundary observed');
   if(!entry.hideWithin200ms)record.timingFailure=true;
   save();
   await page.reload({waitUntil:'domcontentloaded',timeout:20000});
   await cdp.send('Browser.setWindowBounds',{windowId:windowInfo.windowId,bounds:{windowState:'normal'}});await page.bringToFront();
   await page.waitForSelector('#status',{state:'detached',timeout:60000});await page.waitForTimeout(2500);await observe(page);entry.afterReload=await info(page);
  }
 }else if(command.type==='key'){
  if(!['Escape','Tab','Shift+Tab','Enter','ArrowDown','ArrowUp'].includes(command.key))throw Error('Undeclared key');
  await page.keyboard.press(command.key);
 }else if(command.type==='snapshot'){}
 else if(command.type==='stop'){record.visual_review=command.visual_review||[];record.state='FINISHED';record.stage='COMPLETE';save();break}
 else throw Error('Undeclared UI operation');
 await page.waitForTimeout(1500);entry.info=await info(page);entry.screenshot=String(last).padStart(2,'0')+'-'+command.type+'.png';await page.screenshot({path:path.join(evidence,entry.screenshot)});save();
}
if(!record.state)throw Error('Bounded UI window ended');
}catch(e){record.failure=String(e);record.state='FAIL';if(globalThis.probePage){try{await globalThis.probePage.screenshot({path:path.join(evidence,'failure.png')})}catch{}}}
finally{
if(globalThis.ownedBrowser){try{const closeSession=await globalThis.ownedBrowser.newBrowserCDPSession();await closeSession.send('Browser.close')}catch{}try{await globalThis.ownedBrowser.close()}catch{}}if(globalThis.ownedChrome&&globalThis.ownedChrome.exitCode===null){await new Promise(r=>setTimeout(r,1000));if(globalThis.ownedChrome.exitCode===null)globalThis.ownedChrome.kill()}
record.finished=new Date().toISOString();fs.writeFileSync(path.join(evidence,'result.json'),JSON.stringify(record,null,2));console.log(JSON.stringify(record));process.exitCode=record.state==='FINISHED'&&!record.errors.length&&!record.timingFailure?0:1;
}})();
