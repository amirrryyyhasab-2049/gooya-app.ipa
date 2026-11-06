#!/usr/bin/env bash
# اجرای گویا روی مک/لینوکس:  bash start-gooya.sh
set -e
cd "$(dirname "$0")"
if ! command -v node >/dev/null 2>&1; then
  echo "[Gooya] Node.js نصب نیست. نسخهٔ LTS را از https://nodejs.org نصب کنید و دوباره اجرا کنید."
  exit 1
fi
if [ ! -f node_modules/next/package.json ]; then
  echo "[Gooya] در حال نصب وابستگی‌ها (فقط بار اول)…"
  npm install
fi
exec node scripts/local.mjs
