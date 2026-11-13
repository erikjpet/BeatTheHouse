// Diagnostic for the observed repeated-reload failure, separate from room QA.
// Connect to an already storage-admitted/capped disposable browser; spawn none.
const fs = require('fs');
const path = require('path');
const {chromium} = require('D:/Projects/site/node_modules/playwright');
(async () => {
  const evidence = process.env.BTH_QA_EVIDENCE_DIR;
  const profile = 'E:/CodexQA/BTH/runs/BTH-ENVART-001-' + process.env.BTH_ENVART_BROWSER_RUN + '/profile';
  const port = fs.readFileSync(path.join(profile,'DevToolsActivePort'),'utf8').split(/\r?\n/)[0];
  const browser = await chromium.connectOverCDP('http://127.0.0.1:' + port);
  const context = browser.contexts()[0], page = context.pages()[0];
  const messages = [], iterations = [];
  page.on('console',m=>messages.push({type:m.type(),text:m.text()}));
  page.on('pageerror',e=>messages.push({type:'pageerror',text:e.message}));
  await page.setViewportSize({width:1280,height:720});
  try {
    for(let index=0;index<8;index++) {
      let error = null;
      const began=messages.length;
      try {
        await page.goto(process.env.BTH_ENVART_RELOAD_URL,{waitUntil:'domcontentloaded'});
        await page.waitForFunction(()=>!document.getElementById('status'),null,{timeout:30000});
        await page.waitForTimeout(2000);
      } catch(e) {error=String(e);}
      const body=await page.locator('body').innerText().catch(()=>'<unavailable>');
      const row={index,error,body,messages:messages.slice(began),heap:await page.evaluate(()=>performance.memory.usedJSHeapSize).catch(()=>null)};
      iterations.push(row);
      await page.screenshot({path:path.join(evidence,'reload-'+index+'.png')}).catch(()=>{});
      fs.writeFileSync(path.join(evidence,'reload.json'),JSON.stringify({url:process.env.BTH_ENVART_RELOAD_URL,scope:'Eight-reload bounded startup diagnostic; not a gameplay or release pass',iterations},null,2));
      if(error || body.includes('unreachable')) break;
    }
  } finally {
    const session=await context.newCDPSession(page);
    await session.send('Browser.close');
  }
  const failures=iterations.filter(x=>x.error || x.body.includes('unreachable') || x.messages.some(m=>m.type==='pageerror'||m.type==='error'));
  console.log(JSON.stringify({iterations:iterations.length,failures:failures.length}));
  process.exit(failures.length?1:0);
})().catch(e=>{console.error(e);process.exit(1);});
