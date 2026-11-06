# Ejecuta empezar.ps1 en modo prueba: carpeta temporal, sin instalar ni abrir nada, sin pausas.
$raiz = Join-Path $env:TEMP ("empezar-prueba-" + [guid]::NewGuid().ToString().Substring(0, 8))
Write-Host "Carpeta de prueba: $raiz"
$env:EMPEZAR_RAIZ = $raiz; $env:EMPEZAR_SIN_INSTALAR = '1'; $env:EMPEZAR_SIN_ABRIR = '1'; $env:EMPEZAR_SIN_PAUSAS = '1'
Invoke-Expression ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'empezar.ps1'), [Text.Encoding]::UTF8))
Write-Host "Hecho. Borra $raiz cuando quieras."
