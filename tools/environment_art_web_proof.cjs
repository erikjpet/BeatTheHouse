const fs = require('fs');
const path = require('path');
const {chromium} = require('D:/Projects/site/node_modules/playwright');
let observedPage, observedMessages=[], observedEvidence;
(async () => {
  const evidence = process.env.BTH_QA_EVIDENCE_DIR;
  const portFile = 'E:/CodexQA/BTH/runs/BTH-ENVART-001-' + (process.env.BTH_ENVART_BROWSER_RUN || 'p0-web-browser-01') + '/profile/DevToolsActivePort';
  const port = fs.readFileSync(portFile, 'utf8').split(/\r?\n/)[0];
  // Connect only to a separately guarded disposable browser. Call library,
  // firstscenario, then sequence for exact mouse-selected scenario proof.
  // No process, profile, save or server is created by this worker.
  const browser = await chromium.connectOverCDP('http://127.0.0.1:' + port);
  const context = browser.contexts()[0];
  const page = context.pages()[0];
  const messages = observedMessages; observedPage=page; observedEvidence=evidence;
  page.on('console', m => {messages.push({type:m.type(),text:m.text()});});
  page.on('pageerror', e => {messages.push({type:'pageerror',text:e.message});});
  await page.setViewportSize({width:1280,height:720});
  if (['boot','bootgas','library','bootbase'].includes(process.argv[2])) {
    await page.goto(process.env.BTH_ENVART_WEB_BASE + '/index.html?bth_perf=1&bth_perf_overlay=1', {waitUntil:'domcontentloaded'});
    await page.waitForFunction(() => !document.getElementById('status'), null, {timeout:150000});
    await page.waitForTimeout(3000);
  } else if (process.argv[2] === 'click') {
    await page.mouse.click(Number(process.argv[3]),Number(process.argv[4]));
    await page.waitForTimeout(2000);
  } else if (process.argv[2] === 'key') {
    await page.keyboard.press(process.argv[3]);
    await page.waitForTimeout(2000);
  }
  if (process.argv[2] === 'bootgas') {
    await page.mouse.click(365,48);
    await page.waitForTimeout(700);
    await page.mouse.click(216,334);
    await page.waitForTimeout(200);
  }
  if (['library','bootbase'].includes(process.argv[2])) {
    await page.mouse.click(365,48); await page.waitForTimeout(500);
    await page.mouse.click(216,334); await page.waitForTimeout(150);
    await page.mouse.click(200,353); await page.waitForTimeout(200);
    await page.mouse.click(610,334); await page.waitForTimeout(200);
  }
  if (['gas','bootgas'].includes(process.argv[2])) {
    await page.mouse.click(200,353);
    await page.waitForTimeout(200);
    await page.mouse.click(610,334);
    await page.keyboard.press('Home');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('Enter');
    await page.mouse.click(300,245);
    await page.keyboard.press('Control+A');
    await page.keyboard.type('LAYOUT-SURVEY-QA',{delay:25});
    const before = await page.evaluate(() => ({used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}));
    await page.mouse.click(940,483);
    await page.waitForTimeout(4000);
    await page.screenshot({path:path.join(evidence,'gas-before-idle.png')});
    await page.waitForTimeout(450);
    await page.screenshot({path:path.join(evidence,'gas-after-idle.png')});
    const sample = await page.evaluate(() => new Promise(resolve => {
      const times=[]; let last=performance.now();
      function tick(now) {times.push(now-last);last=now;if(times.length<180) requestAnimationFrame(tick); else resolve({times,heap:{used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}});}
      requestAnimationFrame(tick);
    }));
    fs.writeFileSync(path.join(evidence,'gas-web-idle.json'),JSON.stringify({source:'browser_requestAnimationFrame_whole_frame_upper_bound',before,sample},null,2));
  }
  if (process.argv[2] === 'bootbase') {
    await page.mouse.click(610,395); await page.waitForTimeout(180);
    await page.mouse.click(300,245); await page.keyboard.press('Control+A'); await page.waitForTimeout(100); await page.keyboard.type('LAYOUT-SURVEY-QA',{delay:25});
    await page.screenshot({path:path.join(evidence,'base-selection.png')});
    const before=await page.evaluate(()=>({used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}));
    await page.mouse.click(940,483); await page.waitForTimeout(2400);
    await page.screenshot({path:path.join(evidence,'gas-before-idle.png')});
    const sample=await page.evaluate(()=>new Promise(resolve=>{const times=[];let last=performance.now();function tick(now){times.push(now-last);last=now;if(times.length<180)requestAnimationFrame(tick);else resolve({times,heap:{used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}});}requestAnimationFrame(tick);}));
    fs.writeFileSync(path.join(evidence,'gas-web-idle.json'),JSON.stringify({source:'browser_requestAnimationFrame_whole_frame_upper_bound',before,sample},null,2));
    await page.waitForTimeout(450);
    await page.screenshot({path:path.join(evidence,'gas-after-idle.png')});
  }
  if (process.argv[2] === 'firstscenario') {
    await page.mouse.click(610,423); await page.waitForTimeout(250);
    await page.mouse.click(300,245); await page.keyboard.press('Control+A'); await page.waitForTimeout(100); await page.keyboard.type('LAYOUT-SURVEY-QA',{delay:25});
    await page.screenshot({path:path.join(evidence,'trucker-selection.png')});
    await page.mouse.click(940,483); await page.waitForTimeout(2200);
    await page.screenshot({path:path.join(evidence,'trucker-play.png')});
    await page.mouse.click(962,48); await page.waitForTimeout(300);
    await page.mouse.move(700,450); await page.mouse.wheel(0,650); await page.waitForTimeout(300);
    await page.mouse.click(640,552); await page.waitForTimeout(400);
  }
  if (process.argv[2] === 'sequence') {
    const scenarios=['trucker_convoy','tour_bus_stop','graveyard_shift','road_crew_payday','storm_shelter'];
    const results=[];
    for(let i=0;i<scenarios.length;i++) {
      await page.mouse.click(610,270); await page.waitForTimeout(180);
      await page.mouse.click(610,306+27*(i+2)); await page.waitForTimeout(200);
      await page.screenshot({path:path.join(evidence,scenarios[i]+'-selection.png')});
      await page.mouse.click(940,420); await page.waitForTimeout(1600);
      const a=await page.screenshot({path:path.join(evidence,scenarios[i]+'-idle-a.png')});
      await page.waitForTimeout(450);
      const b=await page.screenshot({path:path.join(evidence,scenarios[i]+'-idle-b.png')});
      results.push({requested_scenario:'gas_station_'+scenarios[i],selection_capture:scenarios[i]+'-selection.png',visible_idle_change:!a.equals(b)});
      await page.mouse.click(962,48); await page.waitForTimeout(250);
      await page.mouse.move(700,450); await page.mouse.wheel(0,650); await page.waitForTimeout(250);
      if(i<scenarios.length-1) {await page.mouse.click(640,552); await page.waitForTimeout(300);}
    }
    await page.screenshot({path:path.join(evidence,'settings-for-reduce-motion.png')});
    await page.mouse.click(266,99); await page.waitForTimeout(150);
    await page.screenshot({path:path.join(evidence,'reduce-motion-checked.png')});
    await page.mouse.click(915,640); await page.waitForTimeout(200);
    await page.mouse.click(365,640); await page.waitForTimeout(500);
    await page.mouse.move(3,710);
    const region={x:18,y:128,width:1244,height:592};
    const a=await page.screenshot({path:path.join(evidence,'reduce-motion-room-a.png'),clip:region});
    await page.waitForTimeout(450);
    const b=await page.screenshot({path:path.join(evidence,'reduce-motion-room-b.png'),clip:region});
    fs.writeFileSync(path.join(evidence,'five-web-scenarios.json'),JSON.stringify({results,messages},null,2));
    fs.writeFileSync(path.join(evidence,'reduce-motion-web.json'),JSON.stringify({pixel_identical:a.equals(b),interval_ms:450,region},null,2));
    if(results.some(x=>!x.visible_idle_change)) throw Error('A scenario did not visibly animate');
    if(!a.equals(b)) throw Error('Web Reduce Motion room changed');
  }
  const metadata = {scope:'isolated_branch_Web_QA; not NEXT',source:process.env.BTH_ENVART_SOURCE || 'feature branch'};
  await page.screenshot({path:path.join(evidence,'web.png')});
  fs.writeFileSync(path.join(evidence,'web-observation.json'),JSON.stringify({url:page.url(),metadata,messages,body:await page.locator('body').innerText(),heap:await page.evaluate(() => performance.memory ? {usedJSHeapSize:performance.memory.usedJSHeapSize,totalJSHeapSize:performance.memory.totalJSHeapSize,jsHeapSizeLimit:performance.memory.jsHeapSizeLimit}:null)},null,2));
  if (['close','bootgas','bootbase','sequence'].includes(process.argv[2])) {
    await page.request.post(process.env.BTH_ENVART_WEB_BASE + '/__shutdown');
    const session = await context.newCDPSession(page);
    await session.send('Browser.close');
  }
  const errors=messages.filter(m=>m.type==='error'||m.type==='pageerror'||m.text.startsWith('ERROR:'));
  if(errors.length) throw Error('Web errors: '+JSON.stringify(errors));
  console.log('WEB_OBSERVATION',evidence);
  process.exit(0);
})().catch(async e => {console.error(e); if(observedEvidence){fs.writeFileSync(path.join(observedEvidence,'web-failure.json'),JSON.stringify({error:String(e),messages:observedMessages},null,2)); if(observedPage) await observedPage.screenshot({path:path.join(observedEvidence,'failure.png')}).catch(()=>{});} process.exit(1);});
