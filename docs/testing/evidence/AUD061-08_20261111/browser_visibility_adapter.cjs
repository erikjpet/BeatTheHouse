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
record.scope='Read-only native browser visibility capability probe on exact deployed build; no game state or visibility-property override.';
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

const page=context.pages()[0]||await context.newPage();
await page.setViewportSize({width:1280,height:720});globalThis.probePage=page;
await page.bringToFront();
page.on('pageerror',e=>{record.errors.push(String(e));save()});
page.on('console',m=>{if(m.type()==='error'||m.type()==='warning'){record.console.push({type:m.type(),text:m.text()});save()}});
await page.goto(`http://localhost:8088/p/beat-the-house/play/dev/${sha}/`,{waitUntil:'domcontentloaded'});
record.beforeStartup=await page.evaluate(()=>({hidden:document.hidden,visibility:document.visibilityState,status:document.getElementById('status')?.innerText||''}));save();
await page.waitForSelector('#status',{state:'detached',timeout:60000});
await page.evaluate(()=>{window.__AUD08Visibility=[];document.addEventListener('visibilitychange',()=>window.__AUD08Visibility.push({event:'visibilitychange',hidden:document.hidden,time:performance.now()}));window.addEventListener('pagehide',()=>window.__AUD08Visibility.push({event:'pagehide',hidden:document.hidden,time:performance.now()}))});
const state=async()=>await page.evaluate(()=>({hidden:document.hidden,visibility:document.visibilityState,events:window.__AUD08Visibility}));
record.initial=await state();
const cdp=await context.newCDPSession(page);
await cdp.send('Emulation.setFocusEmulationEnabled',{enabled:false});record.focusEmulationDisabled=true;record.withoutFocusEmulation=await state();
try{const win=await cdp.send('Browser.getWindowForTarget');record.window=win;await cdp.send('Browser.setWindowBounds',{windowId:win.windowId,bounds:{windowState:'minimized'}});await page.waitForTimeout(150);record.minimized=await state();await cdp.send('Browser.setWindowBounds',{windowId:win.windowId,bounds:{windowState:'normal'}});await page.waitForTimeout(150);record.restored=await state()}catch(e){record.minimizeError=String(e)}
const alternate=await context.newPage();await alternate.goto('about:blank');await alternate.bringToFront();await page.waitForTimeout(150);record.otherTab=await state();await page.bringToFront();await page.waitForTimeout(150);record.front=await state();await alternate.close();
await page.screenshot({path:path.join(evidence,'visibility-probe-restored.png')});
record.result=record.minimized?.hidden||record.otherTab?.hidden?'REAL_HIDDEN_AVAILABLE':'REAL_HIDDEN_NOT_OBSERVED';
}catch(e){record.failure=String(e);record.result='PROBE_FAILED';if(globalThis.probePage){try{record.failureState=await globalThis.probePage.evaluate(()=>({hidden:document.hidden,visibility:document.visibilityState,status:document.getElementById('status')?.innerText||''}));await globalThis.probePage.screenshot({path:path.join(evidence,'startup-failure.png')})}catch{}}}finally{if(globalThis.ownedBrowser){try{const closeSession=await globalThis.ownedBrowser.newBrowserCDPSession();await closeSession.send('Browser.close')}catch{}try{await globalThis.ownedBrowser.close()}catch{}}if(globalThis.ownedChrome&&globalThis.ownedChrome.exitCode===null){await new Promise(r=>setTimeout(r,1000));if(globalThis.ownedChrome.exitCode===null)globalThis.ownedChrome.kill()}fs.writeFileSync(path.join(evidence,'result.json'),JSON.stringify(record,null,2));console.log(JSON.stringify(record));process.exitCode=record.failure?1:0}})();
