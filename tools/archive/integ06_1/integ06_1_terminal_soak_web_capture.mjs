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
const url = String(args.url ?? "http://127.0.0.1:18141/index.html");
const outputPath = path.resolve(String(args.out ?? ".tmp/integ06_1/terminal_soak/web.json"));
const profilePath = path.resolve(String(args.profile ?? `${outputPath}.profile`));
const chromePath = String(args.chrome ?? "C:/Program Files/Google/Chrome/Application/chrome.exe");
const timeoutMs = Number(args.timeoutMs ?? args["timeout-ms"] ?? 600000);
const cpu = Math.max(1, Number(args.cpu ?? 4));
if (!Number.isFinite(timeoutMs) || timeoutMs < 1) throw new Error("timeout-ms must be positive.");
if (!fs.existsSync(chromePath)) throw new Error(`Chrome executable not found: ${chromePath}`);
if (fs.existsSync(profilePath)) throw new Error(`Profile path must not already exist: ${profilePath}`);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.mkdirSync(profilePath, { recursive: false });

let context;
let report = null;
const consoleErrors = [];
const pageErrors = [];
const requestFailures = [];
try {
  context = await chromium.launchPersistentContext(profilePath, {
    executablePath: chromePath,
    headless: true,
    viewport: { width: 1152, height: 648 },
    deviceScaleFactor: 1,
    args: ["--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-features=CalculateNativeWinOcclusion"],
  });
  const page = context.pages()[0] ?? await context.newPage();
  page.on("console", (message) => {
    const text = message.text();
    if (text.startsWith("INTEG06_1_TERMINAL_SOAK=")) {
      report = JSON.parse(text.slice("INTEG06_1_TERMINAL_SOAK=".length));
    } else if (message.type() === "error") {
      consoleErrors.push(text);
    }
  });
  page.on("pageerror", (error) => pageErrors.push(String(error?.stack ?? error)));
  page.on("requestfailed", (request) => requestFailures.push({
    url: request.url(), resource_type: request.resourceType(), error_text: String(request.failure()?.errorText ?? "unknown request failure"),
  }));
  const cdp = await context.newCDPSession(page);
  await cdp.send("Emulation.setCPUThrottlingRate", { rate: cpu });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
  const deadline = Date.now() + timeoutMs;
  while (report === null && Date.now() < deadline) await page.waitForTimeout(100);
  if (report === null) throw new Error(`Timed out after ${timeoutMs}ms waiting for terminal-soak report.`);
  report.browser_capture = {
    browser: "chrome",
    browser_version: context.browser()?.version() ?? "",
    cpu_throttle_rate: cpu,
    console_errors: consoleErrors,
    page_errors: pageErrors,
    request_failures: requestFailures,
    fresh_profile: profilePath,
    url,
  };
  if (consoleErrors.length > 0 || pageErrors.length > 0 || requestFailures.length > 0) {
    report.passed = false;
    report.failures = [
      ...(Array.isArray(report.failures) ? report.failures : []),
      `Browser emitted console=${consoleErrors.length} page=${pageErrors.length} request=${requestFailures.length} failures.`,
    ];
  }
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
  if (!report.passed || report.platform !== "Web" || !report.semantic_trace_sha256) {
    throw new Error(`Web terminal-soak probe failed: ${JSON.stringify(report.failures ?? [])}`);
  }
  console.log(`INTEG06_1_TERMINAL_SOAK_WEB PASS output=${outputPath} semantic=${report.semantic_trace_sha256} cpu=${cpu}`);
} finally {
  if (context) await context.close();
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
