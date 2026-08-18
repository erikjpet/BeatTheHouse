#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const args = parseArgs(process.argv.slice(2));
const playwrightPackage = path.resolve(String(args.playwrightPackage ?? args["playwright-package"] ?? ".tmp/l02_playwright/package.json"));
if (!fs.existsSync(playwrightPackage)) {
  throw new Error(`Playwright package not found: ${playwrightPackage}`);
}
const { chromium } = createRequire(pathToFileURL(playwrightPackage))("playwright");
const url = String(args.url ?? "http://127.0.0.1:18061/index.html");
const outputPath = path.resolve(String(args.out ?? ".tmp/coin_pusher_input_parity/web_process.json"));
const chromePath = String(args.chrome ?? "C:/Program Files/Google/Chrome/Application/chrome.exe");
const timeoutMs = Number(args.timeoutMs ?? args["timeout-ms"] ?? 120000);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });

let browser;
let report = null;
const consoleErrors = [];
try {
  browser = await chromium.launch({
    executablePath: chromePath,
    headless: true,
    args: ["--disable-background-timer-throttling", "--disable-renderer-backgrounding"],
  });
  const page = await browser.newPage();
  page.on("console", (message) => {
    const text = message.text();
    if (text.startsWith("COIN_PUSHER_V3_SMOKE_RESULT=")) {
      report = JSON.parse(text.slice("COIN_PUSHER_V3_SMOKE_RESULT=".length));
    } else if (message.type() === "error") {
      consoleErrors.push(text);
    }
  });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
  const deadline = Date.now() + timeoutMs;
  while (report === null && Date.now() < deadline) {
    await page.waitForTimeout(100);
  }
  if (report === null) {
    throw new Error(`Timed out after ${timeoutMs}ms waiting for the parity result marker.`);
  }
  report.browser_capture = {
    browser: "chrome",
    browser_version: await browser.version(),
    console_errors: consoleErrors,
    url,
  };
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
  if (!report.ok) {
    throw new Error(`Web parity harness failed: ${JSON.stringify(report.failures ?? [])}`);
  }
  console.log(`COIN_PUSHER_WEB_PARITY_CAPTURE PASS output=${outputPath} payload=${report.parity_payload_sha256}`);
} finally {
  if (browser) await browser.close();
}

function parseArgs(tokens) {
  const result = {};
  for (const token of tokens) {
    if (!token.startsWith("--")) continue;
    const clean = token.slice(2);
    const eq = clean.indexOf("=");
    result[eq < 0 ? clean : clean.slice(0, eq)] = eq < 0 ? true : clean.slice(eq + 1);
  }
  return result;
}
