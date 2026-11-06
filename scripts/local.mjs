#!/usr/bin/env node
/**
 * اجرای محلی «گویا» بدون نیاز به PostgreSQL یا انتشار:
 *
 *   npm run local              → ساخت (فقط بار اول) + اجرا + بازکردن مرورگر
 *   npm run local -- --build   → ساخت دوباره (بعد از تغییر کد)
 *   npm run local -- --no-open → بدون بازکردن خودکار مرورگر
 *
 * دیتابیس داخلی در پوشهٔ data/gooya-db ذخیره می‌شود.
 */
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
process.chdir(root);

const args = process.argv.slice(2);
const forceBuild = args.includes("--build");
const noOpen = args.includes("--no-open");
const nextBin = path.join(root, "node_modules", "next", "dist", "bin", "next");

const log = (msg) => console.log(`\x1b[36m[گویا]\x1b[0m ${msg}`);

if (!existsSync(nextBin)) {
  console.error("\x1b[31m[گویا]\x1b[0m وابستگی‌ها نصب نشده‌اند. ابتدا این دستور را اجرا کنید:\n\n    npm install\n");
  process.exit(1);
}

const major = Number(process.versions.node.split(".")[0]);
if (major < 20) {
  console.error(`\x1b[31m[گویا]\x1b[0m Node.js ${process.versions.node} قدیمی است. نسخهٔ LTS را از https://nodejs.org نصب کنید (حداقل 20.9).`);
  process.exit(1);
}

const env = { ...process.env, GOOYA_DB: "embedded", NEXT_TELEMETRY_DISABLED: "1" };

function runNext(cmdArgs, extraEnv = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [nextBin, ...cmdArgs], { stdio: "inherit", env: { ...env, ...extraEnv } });
    child.on("error", reject);
    child.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`next ${cmdArgs[0]} exited with code ${code}`))));
  });
}

function isPortFree(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once("error", () => resolve(false));
    server.once("listening", () => server.close(() => resolve(true)));
    server.listen(port, "0.0.0.0");
  });
}

async function findPort(start) {
  for (let p = start; p < start + 20; p += 1) {
    if (await isPortFree(p)) return p;
  }
  return start;
}

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((i) => i && i.family === "IPv4" && !i.internal)
    .map((i) => i.address);
}

async function waitForServer(url, timeoutMs) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const res = await fetch(url);
      if (res.ok) return true;
    } catch {
      /* not ready yet */
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

function openBrowser(url) {
  try {
    const opts = { detached: true, stdio: "ignore" };
    const child =
      process.platform === "win32"
        ? spawn("cmd", ["/c", "start", "", url], opts)
        : process.platform === "darwin"
          ? spawn("open", [url], opts)
          : spawn("xdg-open", [url], opts);
    child.on("error", () => {});
    child.unref();
  } catch {
    /* ignore */
  }
}

(async () => {
  if (forceBuild || !existsSync(path.join(root, ".next", "BUILD_ID"))) {
    log("در حال آماده‌سازی برنامه (فقط بار اول؛ ممکن است چند دقیقه طول بکشد)…");
    await runNext(["build"]);
  }

  const port = await findPort(Number(process.env.PORT) || 3000);
  log(`در حال اجرا روی پورت ${port}…`);

  const server = spawn(process.execPath, [nextBin, "start", "-H", "0.0.0.0", "-p", String(port)], {
    stdio: "inherit",
    env: { ...env, PORT: String(port) },
  });
  server.on("exit", (code) => process.exit(code ?? 0));
  const shutdown = () => {
    server.kill("SIGINT");
    setTimeout(() => process.exit(0), 1500);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  const localUrl = `http://localhost:${port}`;
  const ready = await waitForServer(`http://127.0.0.1:${port}/api/health`, 120000);
  if (!ready) {
    log("سرور هنوز پاسخ نداده؛ اگر خطایی بالا دیده می‌شود آن را بررسی کنید.");
    return;
  }

  const lan = lanAddresses();
  console.log("\n\x1b[32m✅ گویا آماده است!\x1b[0m");
  console.log(`   روی همین کامپیوتر:        ${localUrl}`);
  for (const ip of lan) console.log(`   روی گوشی (همان Wi-Fi):    http://${ip}:${port}`);
  console.log("   دیتابیس داخلی:            ./data/gooya-db");
  console.log("   برای خروج Ctrl + C را بزنید.\n");

  if (!noOpen) openBrowser(localUrl);
})().catch((err) => {
  console.error("\x1b[31m[گویا]\x1b[0m اجرا ناموفق بود:", err.message);
  process.exit(1);
});
