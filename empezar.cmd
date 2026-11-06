@echo off
setlocal
chcp 65001 >nul
title Empezar - herramienta de notarías de Zoolutions
set "REPO=zoolutionslab/notarias"
set "CARPETA=%USERPROFILE%\Zoolutions"
set "DESTINO=%CARPETA%\notarias"
set "NUEVO=0"

cls
echo.
echo  ===================================================
echo   Vamos a dejar tu ordenador listo para trabajar en
echo   la herramienta de notarías de Zoolutions.
echo  ===================================================
echo.
echo  Haré cuatro cosas, y antes de instalar nada te pregunto:
echo    1. Comprobar e instalar lo que falte: Git, Node.js, GitHub y Claude Code.
echo    2. Entrar en tu cuenta de GitHub ^(si no tienes, te ayudo a crearla^).
echo    3. Descargar el proyecto en  %DESTINO%
echo    4. Abrirlo para que empieces.
echo.
pause

where winget >nul 2>&1
if errorlevel 1 (
  echo.
  echo  ✖ Tu Windows no tiene "winget", que uso para instalar programas.
  echo    Ábrelo con Microsoft Store: busca "Instalador de aplicación" y actualízalo; luego vuelve a hacer doble clic aquí.
  start https://apps.microsoft.com/detail/9nblggh4nns1
  pause
  exit /b 1
)

echo.
echo  --- Paso 1: programas necesarios ---
where git >nul 2>&1
if errorlevel 1 call :instalar "Git" "Git.Git" "guarda el historial de lo que haces y lo comparte con tu equipo"
where node >nul 2>&1
if errorlevel 1 call :instalar "Node.js" "OpenJS.NodeJS.LTS" "es el motor que hace funcionar la herramienta"
where gh >nul 2>&1
if errorlevel 1 call :instalar "GitHub CLI" "GitHub.cli" "te conecta con GitHub, donde vive el proyecto"
where claude >nul 2>&1
if errorlevel 1 call :instalar "Claude Code" "Anthropic.ClaudeCode" "es la IA con la que vas a trabajar"

if "%NUEVO%"=="1" (
  echo.
  echo  ✔ He instalado programas nuevos. Para que Windows los reconozca:
  echo    cierra esta ventana y vuelve a hacer doble clic en  empezar.cmd
  echo    ^(seguirá justo donde lo dejamos^).
  pause
  exit /b 0
)
echo  ✔ Todos los programas están instalados.

echo.
echo  --- Paso 2: tu cuenta de GitHub ---
gh auth status >nul 2>&1
if not errorlevel 1 goto :conectado

echo  GitHub es la web donde vive el proyecto. Necesitas una cuenta gratuita.
choice /c SN /m " ¿Ya tienes cuenta de GitHub"
if errorlevel 2 (
  echo.
  echo  Te abro la página para crearla. Pon tu correo, una contraseña y un nombre de usuario
  echo  ^(el que quieras, pero acuérdate de él: se lo darás a Lucas^). Verifica tu correo cuando te lo pida.
  start https://github.com/signup
  echo  Cuando hayas terminado de crearla, vuelve aquí.
  pause
)
echo.
echo  Ahora vamos a conectar este ordenador con tu cuenta. Saldrá un CÓDIGO de 8 letras:
echo  elige "GitHub.com", "HTTPS", "Yes" y "Login with a web browser", copia el código,
echo  pulsa Intro y pégalo en la página que se abre.
echo.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (
  echo.
  echo  ✖ No se ha podido iniciar sesión. Vuelve a hacer doble clic en empezar.cmd para repetirlo.
  pause
  exit /b 1
)
gh auth setup-git >nul 2>&1

:conectado
set "USUARIO="
for /f "usebackq delims=" %%u in (`gh api user --jq .login`) do set "USUARIO=%%u"
echo  ✔ Has iniciado sesión en GitHub como: %USUARIO%

echo.
echo  --- Paso 3: descargar el proyecto ---
if not exist "%CARPETA%" mkdir "%CARPETA%"
if exist "%DESTINO%\.git" (
  echo  Ya lo tenías descargado. Lo actualizo...
  git -C "%DESTINO%" pull --ff-only
  goto :abrir
)
gh repo clone %REPO% "%DESTINO%"
if errorlevel 1 (
  echo.
  echo  ✖ Todavía no tienes acceso al proyecto.
  echo.
  echo    Tu usuario de GitHub es:  %USUARIO%
  echo    Mándaselo a Lucas ^(ya lo tienes copiado: solo tienes que pegarlo en un mensaje^)
  echo    y vuelve a hacer doble clic aquí cuando te diga que ya estás dentro.
  echo %USUARIO%| clip
  echo.
  pause
  exit /b 1
)

:abrir
echo.
echo  --- Paso 4: abrir el proyecto ---
if exist "%DESTINO%\Abrir proyecto.cmd" (
  call "%DESTINO%\Abrir proyecto.cmd"
) else (
  echo  ✖ No encuentro "Abrir proyecto.cmd" en %DESTINO%. Avisa a Lucas.
  pause
)
exit /b 0

:instalar
echo.
echo  Falta %~1: %~3.
choice /c SN /m " ¿Lo instalo ahora"
if errorlevel 2 (
  echo  Sin %~1 no puedo seguir. Vuelve a hacer doble clic cuando quieras instalarlo.
  pause
  exit /b 1
)
winget install --id %~2 -e --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
  echo  ✖ No se ha podido instalar %~1. Haz una captura de esta ventana y mándasela a Lucas.
  pause
  exit /b 1
)
set "NUEVO=1"
goto :eof
