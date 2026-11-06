#!/bin/bash
# Ejecuta empezar.sh en modo prueba: carpeta temporal, sin instalar ni abrir nada, sin pausas.
cd "$(dirname "$0")" || exit 1
RAIZ="${TMPDIR:-/tmp}/empezar-prueba-$$"
echo "Carpeta de prueba: $RAIZ"
EMPEZAR_RAIZ="$RAIZ" EMPEZAR_SIN_INSTALAR=1 EMPEZAR_SIN_ABRIR=1 EMPEZAR_SIN_PAUSAS=1 bash ./empezar.sh
echo "Código de salida: $?  (borra $RAIZ cuando quieras)"
