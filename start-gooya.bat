@echo off
setlocal
cd /d "%~dp0"
title Gooya - Persian Text to Speech

where node >nul 2>nul
if errorlevel 1 (
  echo [Gooya] Node.js is not installed.
  echo [Gooya] Download the LTS version from https://nodejs.org , install it, then run this file again.
  pause
  exit /b 1
)

if not exist "node_modules\next\package.json" (
  echo [Gooya] Installing dependencies - first run only, this may take a few minutes...
  call npm install
  if errorlevel 1 (
    echo [Gooya] npm install failed. Check your internet connection and try again.
    pause
    exit /b 1
  )
)

node scripts\local.mjs
pause
