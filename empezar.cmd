@echo off
rem Empezar en Zoolutions Lab (Windows), para quien prefiere descargar un fichero y hacer doble clic.
rem Hace lo mismo que la línea de la página:  irm https://zoolutionslab.github.io/empezar/empezar.ps1 | iex
rem Este fichero tiene que ir con finales de línea CRLF (si no, cmd.exe se traga comandos).
setlocal
chcp 65001 >nul
title Empezar - Zoolutions Lab
echo.
echo  Arrancando el asistente de Zoolutions Lab...
echo.
where powershell >nul 2>&1
if errorlevel 1 (
  echo  No encuentro PowerShell en este Windows. Haz una captura de esta ventana y mandasela a Lucas.
  pause
  exit /b 1
)
if exist "%~dp0empezar.ps1" (
  rem Copia local junto a este fichero (pruebas): se usa en vez de la publicada.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText('%~dp0empezar.ps1', [Text.Encoding]::UTF8))"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://zoolutionslab.github.io/empezar/empezar.ps1 | iex"
)
if errorlevel 1 (
  echo.
  echo  Algo no ha ido bien. Haz una captura de esta ventana y mandasela a Lucas.
  pause
)
endlocal
