import os from "node:os";
import { dbMode } from "@/db";

export const dynamic = "force-dynamic";

/** اطلاعات اجرای محلی برای صفحهٔ «نصب روی موبایل» (آدرس‌های Wi-Fi برای بازکردن روی گوشی). */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const port = url.port || (url.protocol === "https:" ? "443" : "80");
  const lan = Object.values(os.networkInterfaces())
    .flat()
    .filter((i): i is os.NetworkInterfaceInfo => Boolean(i) && i!.family === "IPv4" && !i!.internal)
    .map((i) => i.address);

  return Response.json({
    mode: dbMode,
    local: dbMode === "embedded",
    lanUrls: lan.map((ip) => `http://${ip}:${port}`),
  });
}
