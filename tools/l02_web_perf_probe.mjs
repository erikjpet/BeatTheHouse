#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const workspacePlaywrightPackage = path.resolve(".tmp/l02_playwright/package.json");
const requireFromPlaywrightInstall = fs.existsSync(workspacePlaywrightPackage)
  ? createRequire(pathToFileURL(workspacePlaywrightPackage))
  : createRequire(import.meta.url);
const { chromium, firefox } = requireFromPlaywrightInstall("playwright");

const args = parseArgs(process.argv.slice(2));
const browserName = String(args.browser ?? "chrome");
const url = String(args.url ?? "http://127.0.0.1:8060/?bth_perf=1&bth_perf_plan=l02&bth_perf_auto_quit=1");
const outputPath = String(args.out ?? ".tmp/l02_baseline/web_report.json");
const profileDir = String(args.profile ?? `.tmp/l02_playwright/${browserName}_profile`);
const timeoutMs = Number(args.timeoutMs ?? args["timeout-ms"] ?? 900000);
const cpuRate = Number(args.cpu ?? 1);
const chromePath = resolveChromePath(String(args.chromePath ?? args["chrome-path"] ?? ""));
const coldCache = boolArg(args.coldCache ?? args["cold-cache"] ?? false);

if (coldCache && fs.existsSync(profileDir)) {
  fs.rmSync(profileDir, { recursive: true, force: true });
}
fs.mkdirSync(profileDir, { recursive: true });
fs.mkdirSync(path.dirname(outputPath), { recursive: true });

const browserType = browserName === "firefox" ? firefox : chromium;
const launchOptions = {
  headless: boolArg(args.headless ?? false),
};
if (browserName === "chrome" && chromePath.length > 0) {
  launchOptions.executablePath = chromePath;
}
if (browserName === "chrome") {
  launchOptions.args = [
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
  ];
}

let context;
let report = null;
let ready = null;
const started = Date.now();

try {
  context = await browserType.launchPersistentContext(profileDir, launchOptions);
  const page = context.pages()[0] ?? await context.newPage();
  if (browserName === "chrome" && cpuRate > 1) {
    const cdp = await context.newCDPSession(page);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: cpuRate });
  }
  page.on("console", (message) => {
    const text = message.text();
    if (text.startsWith("BTH_PERF_READY ")) {
      ready = {
        wall_msec: Date.now() - started,
        payload: safeJson(text.slice("BTH_PERF_READY ".length)),
      };
      console.log(text);
    } else if (text.startsWith("BTH_PERF_REPORT ")) {
      report = safeJson(text.slice("BTH_PERF_REPORT ".length));
      console.log(`BTH_PERF_REPORT_CAPTURED scenarios=${report?.scenario_count ?? "?"}`);
    } else if (text.includes("BTH_PERF")) {
      console.log(text);
    }
  });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
  const deadline = Date.now() + timeoutMs;
  while (report === null && Date.now() < deadline) {
    await page.waitForTimeout(1000);
  }
  if (report === null) {
    throw new Error(`Timed out after ${timeoutMs}ms waiting for BTH_PERF_REPORT.`);
  }
  const userAgent = await page.evaluate(() => navigator.userAgent);
  const browserVersion = context.browser()?.version?.() ?? browserName;
  const output = {
    browser: browserName,
    browser_version: browserVersion,
    user_agent: userAgent,
    cpu_throttle_rate: cpuRate,
    url,
    cold_cache: coldCache,
    ready,
    wall_msec: Date.now() - started,
    report,
  };
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
  console.log(`L0.2 web perf report written to ${outputPath}`);
} finally {
  if (context) {
    await context.close();
  }
}

function parseArgs(tokens) {
  const result = {};
  for (const token of tokens) {
    if (!token.startsWith("--")) {
      continue;
    }
    const clean = token.slice(2);
    const eq = clean.indexOf("=");
    if (eq === -1) {
      result[clean] = true;
    } else {
      result[clean.slice(0, eq)] = clean.slice(eq + 1);
    }
  }
  return result;
}

function boolArg(value) {
  if (typeof value === "boolean") {
    return value;
  }
  const raw = String(value ?? "").trim().toLowerCase();
  return raw === "1" || raw === "true" || raw === "yes" || raw === "on";
}

function safeJson(text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    return { parse_error: String(error), raw: text };
  }
}

function resolveChromePath(explicitPath) {
  if (explicitPath.length > 0) {
    return explicitPath;
  }
  const candidates = [
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return "";
}
