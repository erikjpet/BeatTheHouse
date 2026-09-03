#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const args = parseArgs(process.argv.slice(2));
const playwrightPackage = path.resolve(String(args.playwrightPackage ?? args["playwright-package"] ?? ".tmp/l02_playwright/package.json"));
if (!fs.existsSync(playwrightPackage)) throw new Error(`Playwright package not found: ${playwrightPackage}`);
const { chromium } = createRequire(pathToFileURL(playwrightPackage))("playwright");
const url = String(args.url ?? "http://127.0.0.1:18143/index.html");
const outputPath = path.resolve(String(args.out ?? ".tmp/game06_3_closeout/platform_web.json"));
const chromePath = String(args.chrome ?? "C:/Program Files/Google/Chrome/Application/chrome.exe");
const timeoutMs = Number(args.timeoutMs ?? args["timeout-ms"] ?? 180000);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });

let browser;
let report = null;
const consoleErrors = [];
const pageErrors = [];
try {
  browser = await chromium.launch({
    executablePath: chromePath,
    headless: true,
    args: ["--disable-background-timer-throttling", "--disable-renderer-backgrounding"],
  });
  const page = await browser.newPage();
  page.on("console", (message) => {
    const text = message.text();
    if (text.startsWith("GAME06_3_PLATFORM_PARITY=")) {
      report = JSON.parse(text.slice("GAME06_3_PLATFORM_PARITY=".length));
    } else if (message.type() === "error") {
      consoleErrors.push(text);
    }
  });
  page.on("pageerror", (error) => pageErrors.push(String(error?.stack ?? error)));
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
  const deadline = Date.now() + timeoutMs;
  while (report === null && Date.now() < deadline) await page.waitForTimeout(100);
  if (report === null) throw new Error(`Timed out after ${timeoutMs}ms waiting for GAME06_3_PLATFORM_PARITY.`);
  report.browser_capture = {
    browser: "chrome",
    browser_version: await browser.version(),
    console_errors: consoleErrors,
    page_errors: pageErrors,
    url,
  };
  if (consoleErrors.length > 0 || pageErrors.length > 0) {
    report.ok = false;
    report.failures = [
      ...(Array.isArray(report.failures) ? report.failures : []),
      `Browser emitted console=${consoleErrors.length} page=${pageErrors.length} errors.`,
    ];
  }
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
  if (!report.ok || report.platform !== "Web" || !report.web_feature || !report.semantic_sha256) {
    throw new Error(`Web game06_3 parity probe failed: ${JSON.stringify(report.failures ?? [])}`);
  }
  console.log(`GAME06_3_WEB_PARITY_CAPTURE PASS output=${outputPath} semantic=${report.semantic_sha256}`);
} finally {
  if (browser) await browser.close();
}

function parseArgs(tokens) {
  const result = {};
  for (const token of tokens) {
    if (!token.startsWith("--")) continue;
    const clean = token.slice(2);
    const separator = clean.indexOf("=");
    result[separator < 0 ? clean : clean.slice(0, separator)] = separator < 0 ? true : clean.slice(separator + 1);
  }
  return result;
}
