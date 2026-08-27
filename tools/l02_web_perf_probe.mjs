#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const args = parseArgs(process.argv.slice(2));
if (boolArg(args.selfTestConsolePolicy ?? args["self-test-console-policy"] ?? false)) {
  runConsolePolicySelfTest();
  process.exit(0);
}

const workspacePlaywrightPackage = path.resolve(".tmp/l02_playwright/package.json");
const requireFromPlaywrightInstall = fs.existsSync(workspacePlaywrightPackage)
  ? createRequire(pathToFileURL(workspacePlaywrightPackage))
  : createRequire(import.meta.url);
const { chromium, firefox } = requireFromPlaywrightInstall("playwright");
const browserName = String(args.browser ?? "chrome");
const url = String(args.url ?? "http://127.0.0.1:8060/?bth_perf=1&bth_perf_plan=l02&bth_perf_auto_quit=1");
const outputPath = String(args.out ?? ".tmp/l02_baseline/web_report.json");
const diagnosticPath = String(args.diagnosticOut ?? args["diagnostic-out"] ?? `${outputPath}.diagnostic.json`);
const profileDir = String(args.profile ?? `.tmp/l02_playwright/${browserName}_profile`);
const timeoutMs = Number(args.timeoutMs ?? args["timeout-ms"] ?? 900000);
const cpuRate = Number(args.cpu ?? 1);
const chromePath = resolveChromePath(String(args.chromePath ?? args["chrome-path"] ?? ""));
const coldCache = boolArg(args.coldCache ?? args["cold-cache"] ?? false);
const readyOnly = boolArg(args.readyOnly ?? args["ready-only"] ?? false);

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
let page;
let report = null;
let ready = null;
const started = Date.now();
let navigationStarted = 0;
let readyPageMsec = 0;
const startupConsole = [];
const pageErrors = [];
const requestFailures = [];
const failedResponses = [];

try {
  context = await browserType.launchPersistentContext(profileDir, launchOptions);
  page = context.pages()[0] ?? await context.newPage();
  if (browserName === "chrome" && cpuRate > 1) {
    const cdp = await context.newCDPSession(page);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: cpuRate });
  }
  page.on("pageerror", (error) => {
    pageErrors.push({ message: String(error?.message ?? error), wall_msec: Date.now() - started });
  });
  page.on("requestfailed", (request) => {
    requestFailures.push({
      url: request.url(),
      method: request.method(),
      failure: String(request.failure()?.errorText ?? "request failed"),
      wall_msec: Date.now() - started,
    });
  });
  page.on("response", (response) => {
    if (response.status() >= 400) {
      failedResponses.push({
        url: response.url(),
        status: response.status(),
        status_text: response.statusText(),
        wall_msec: Date.now() - started,
      });
    }
  });
  await page.addInitScript(() => {
    const originalLog = console.log.bind(console);
    console.log = (...values) => {
      const first = values.length > 0 ? String(values[0]) : "";
      if (first.startsWith("BTH_PERF_READY ")) {
        originalLog(`__BTH_READY_PAGE_MSEC__ ${Math.round(performance.now())}`);
      }
      originalLog(...values);
    };
  });
  page.on("console", (message) => {
    const text = message.text();
    if (message.type() === "warning" || message.type() === "error" || text.includes("Blocking on the main thread")) {
      const classification = classifyConsoleEntry(message.type(), text);
      startupConsole.push({ type: message.type(), classification, text, wall_msec: Date.now() - started });
    }
    if (text.startsWith("__BTH_READY_PAGE_MSEC__ ")) {
      readyPageMsec = Number(text.slice("__BTH_READY_PAGE_MSEC__ ".length)) || 0;
    } else if (text.startsWith("BTH_PERF_READY ")) {
      const nodeNavigationWallMsec = navigationStarted > 0 ? Date.now() - navigationStarted : Date.now() - started;
      ready = {
        wall_msec: Date.now() - started,
        navigation_wall_msec: readyPageMsec > 0 ? readyPageMsec : nodeNavigationWallMsec,
        node_navigation_wall_msec: nodeNavigationWallMsec,
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
  navigationStarted = Date.now();
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
  const deadline = Date.now() + timeoutMs;
  while ((readyOnly ? ready === null : report === null) && Date.now() < deadline) {
    await page.waitForTimeout(1000);
  }
  if (readyOnly ? ready === null : report === null) {
    const marker = readyOnly ? "BTH_PERF_READY" : "BTH_PERF_REPORT";
    throw new Error(`Timed out after ${timeoutMs}ms waiting for ${marker}.`);
  }
  const userAgent = await page.evaluate(() => navigator.userAgent);
  const browserVersion = context.browser()?.version?.() ?? browserName;
  const startupTiming = await page.evaluate(() => ({
    now_msec: performance.now(),
    navigation: performance.getEntriesByType("navigation").map((entry) => ({
      dom_content_loaded_msec: entry.domContentLoadedEventEnd,
      load_msec: entry.loadEventEnd,
      response_end_msec: entry.responseEnd,
      transfer_bytes: entry.transferSize,
      encoded_bytes: entry.encodedBodySize,
    })),
    resources: performance.getEntriesByType("resource").map((entry) => ({
      name: entry.name.split("/").pop(),
      start_msec: entry.startTime,
      duration_msec: entry.duration,
      response_end_msec: entry.responseEnd,
      transfer_bytes: entry.transferSize,
      encoded_bytes: entry.encodedBodySize,
      decoded_bytes: entry.decodedBodySize,
    })).sort((left, right) => right.duration_msec - left.duration_msec),
  }));
  const viewportIdentity = await page.evaluate(() => ({
    inner_width: window.innerWidth,
    inner_height: window.innerHeight,
    outer_width: window.outerWidth,
    outer_height: window.outerHeight,
    device_pixel_ratio: window.devicePixelRatio,
    screen_width: window.screen.width,
    screen_height: window.screen.height,
  }));
  const output = {
    browser: browserName,
    browser_version: browserVersion,
    user_agent: userAgent,
    cpu_throttle_rate: cpuRate,
    url,
    cold_cache: coldCache,
    ready_only: readyOnly,
    ready,
    startup_timing: startupTiming,
    startup_console: startupConsole,
    page_errors: pageErrors,
    request_failures: requestFailures,
    failed_responses: failedResponses,
    viewport: viewportIdentity,
    wall_msec: Date.now() - started,
    report,
  };
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
  console.log(`${readyOnly ? "Web startup" : "L0.2 web perf"} report written to ${outputPath}`);
} catch (error) {
  const diagnostic = {
    status: "failed_before_report",
    captured_at: new Date().toISOString(),
    browser: browserName,
    cpu_throttle_rate: cpuRate,
    url,
    cold_cache: coldCache,
    ready_only: readyOnly,
    timeout_ms: timeoutMs,
    wall_msec: Date.now() - started,
    ready,
    report_captured: report !== null,
    startup_console: startupConsole,
    page_errors: pageErrors,
    request_failures: requestFailures,
    failed_responses: failedResponses,
    page_url: page && !page.isClosed() ? page.url() : "",
    error: String(error?.stack ?? error),
  };
  if (!fs.existsSync(diagnosticPath)) {
    fs.mkdirSync(path.dirname(diagnosticPath), { recursive: true });
    fs.writeFileSync(diagnosticPath, JSON.stringify(diagnostic, null, 2));
    console.error(`Web perf failure diagnostic written to ${diagnosticPath}`);
  }
  throw error;
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

function classifyConsoleEntry(type, text) {
  const messageType = String(type ?? "");
  const messageText = String(text ?? "");
  if (messageType === "error") {
    return "error";
  }
  if (messageText.includes("Blocking on the main thread")) {
    return "main_thread_blocking_warning";
  }
  if (messageType === "warning"
      && messageText.includes("The AudioContext was not allowed to start")
      && messageText.includes("after a user gesture")) {
    return "expected_audio_autoplay_warning";
  }
  return "unclassified_warning";
}

function runConsolePolicySelfTest() {
  const cases = [
    ["warning", "The AudioContext was not allowed to start. It must be resumed (or created) after a user gesture on the page.", "expected_audio_autoplay_warning"],
    ["warning", "hostile unexpected warning", "unclassified_warning"],
    ["log", "Blocking on the main thread is very dangerous. See https://emscripten.org/docs/porting/pthreads.html", "main_thread_blocking_warning"],
    ["error", "hostile browser error", "error"],
  ];
  for (const [type, text, expected] of cases) {
    const actual = classifyConsoleEntry(type, text);
    if (actual !== expected) {
      throw new Error(`Console policy self-test failed: expected ${expected}, got ${actual}.`);
    }
  }
  const allowed = cases.filter(([type, text]) => classifyConsoleEntry(type, text) === "expected_audio_autoplay_warning");
  if (allowed.length !== 1) {
    throw new Error(`Console policy self-test failed: expected exactly one allowed warning, got ${allowed.length}.`);
  }
  console.log("Console policy self-test passed (expected autoplay only; hostile warning/error/blocking rejected).");
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
