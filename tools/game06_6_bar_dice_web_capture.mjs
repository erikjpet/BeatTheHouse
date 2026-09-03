#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import http from "node:http";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const args = parseArgs(process.argv.slice(2));
const playwrightPackage = path.resolve(String(args["playwright-package"]));
const { chromium } = createRequire(pathToFileURL(playwrightPackage))("playwright");
const webRoot = path.resolve(String(args.root));
const outputPath = path.resolve(String(args.out));
const profilePath = path.resolve(String(args.profile));
const port = Number(args.port ?? 18146);
const cpu = Math.max(1, Number(args.cpu ?? 4));
const timeoutMs = Number(args["timeout-ms"] ?? 180000);
const url = `http://127.0.0.1:${port}/index.html`;
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.mkdirSync(profilePath, { recursive: true });

let server;
let context;
let report = null;
const consoleErrors = [];
const pageErrors = [];
const requestFailures = [];
try {
  server = http.createServer((request, response) => {
    const requestPath = request.url === "/" ? "/index.html" : String(request.url).split("?")[0];
    const filePath = path.resolve(webRoot, `.${requestPath}`);
    if (!filePath.startsWith(webRoot) || !fs.existsSync(filePath)) {
      response.writeHead(404);
      response.end();
      return;
    }
    const extension = path.extname(filePath);
    const contentType = extension === ".wasm" ? "application/wasm" : extension === ".js" ? "text/javascript" : extension === ".pck" ? "application/octet-stream" : "text/html";
    response.writeHead(200, {
      "Content-Type": contentType,
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
    });
    fs.createReadStream(filePath).pipe(response);
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", resolve);
  });
  context = await chromium.launchPersistentContext(profilePath, {
    executablePath: String(args.chrome ?? "C:/Program Files/Google/Chrome/Application/chrome.exe"),
    headless: true,
    args: ["--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-features=CalculateNativeWinOcclusion"],
  });
  const page = context.pages()[0] ?? await context.newPage();
  page.on("console", (message) => {
    const text = message.text();
    if (text.startsWith("GAME06_6_BAR_DICE_PLATFORM=")) {
      report = JSON.parse(text.slice("GAME06_6_BAR_DICE_PLATFORM=".length));
    } else if (message.type() === "error") {
      consoleErrors.push(text);
    }
  });
  page.on("pageerror", (error) => pageErrors.push(String(error?.stack ?? error)));
  page.on("requestfailed", (request) => requestFailures.push({
    url: request.url(),
    resource_type: request.resourceType(),
    error_text: String(request.failure()?.errorText ?? "unknown"),
  }));
  const cdp = await context.newCDPSession(page);
  await cdp.send("Emulation.setCPUThrottlingRate", { rate: cpu });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
  const deadline = Date.now() + timeoutMs;
  while (report === null && Date.now() < deadline) await page.waitForTimeout(100);
  if (report === null) throw new Error("Timed out waiting for Bar Dice Web report.");
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
  if (consoleErrors.length || pageErrors.length || requestFailures.length) {
    report.ok = false;
    report.failures = [
      ...(report.failures ?? []),
      `Browser emitted console=${consoleErrors.length} page=${pageErrors.length} request=${requestFailures.length} failures.`,
    ];
  }
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));
  if (!report.ok || report.platform !== "Web" || !report.semantic_sha256) {
    throw new Error(`Bar Dice Web probe failed: ${JSON.stringify(report.failures ?? [])}`);
  }
  console.log(`GAME06_6_BAR_DICE_WEB PASS output=${outputPath} semantic=${report.semantic_sha256} cpu=${cpu}`);
} finally {
  if (context) await context.close();
  if (server) await new Promise((resolve) => server.close(resolve));
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
