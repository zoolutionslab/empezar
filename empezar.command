#!/bin/bash
# Empezar desde cero en Mac: instala lo que falte, conecta con GitHub, descarga el proyecto y lo abre.
REPO="zoolutionslab/notarias"
CARPETA="$HOME/Zoolutions"
DESTINO="$CARPETA/notarias"

pregunta() { # pregunta "texto" -> 0 si sí
  local r
  read -r -p " $1 [s/n] " r
  [[ "$r" =~ ^[sSyY] ]]
}

clear
cat <<EOF

 ===================================================
  Vamos a dejar tu Mac listo para trabajar en
  la herramienta de notarías de Zoolutions.
 ===================================================

 Haré cuatro cosas, y antes de instalar nada te pregunto:
   1. Comprobar e instalar lo que falte: Git, Node.js, GitHub y Claude Code.
   2. Entrar en tu cuenta de GitHub (si no tienes, te ayudo a crearla).
   3. Descargar el proyecto en  $DESTINO
   4. Abrirlo para que empieces.

EOF
read -r -p " Pulsa Intro para empezar. " _

echo
echo " --- Paso 1: programas necesarios ---"
if ! command -v brew >/dev/null 2>&1; then
  echo " Para instalar programas uso Homebrew, y no lo tienes."
  if pregunta "¿Lo instalo ahora? (te pedirá la contraseña de tu Mac)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo " ✖ No se pudo instalar Homebrew. Mándale una captura a Lucas."; exit 1; }
    for ruta in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$ruta" ] && eval "$($ruta shellenv)"; done
  else
    echo " Sin Homebrew no puedo seguir. Vuelve a abrirme cuando quieras."; exit 1
  fi
fi

instalar() { # instalar "nombre" "comando para saber si está" "orden brew" "para qué sirve"
  if ! command -v "$2" >/dev/null 2>&1; then
    echo
    echo " Falta $1: $4."
    if pregunta "¿Lo instalo ahora?"; then
      eval "$3" || { echo " ✖ No se pudo instalar $1. Mándale una captura a Lucas."; exit 1; }
    else
      echo " Sin $1 no puedo seguir. Vuelve a abrirme cuando quieras instalarlo."; exit 1
    fi
  fi
}
instalar "Git" git "brew install git" "guarda el historial de lo que haces y lo comparte con tu equipo"
instalar "Node.js" node "brew install node@24 && brew link --overwrite --force node@24" "es el motor que hace funcionar la herramienta"
instalar "GitHub CLI" gh "brew install gh" "te conecta con GitHub, donde vive el proyecto"
instalar "Claude Code" claude "brew install --cask claude-code" "es la IA con la que vas a trabajar"
echo " ✔ Todos los programas están instalados."

echo
echo " --- Paso 2: tu cuenta de GitHub ---"
if ! gh auth status >/dev/null 2>&1; then
  echo " GitHub es la web donde vive el proyecto. Necesitas una cuenta gratuita."
  if ! pregunta "¿Ya tienes cuenta de GitHub?"; then
    echo
    echo " Te abro la página para crearla. Pon tu correo, una contraseña y un nombre de usuario"
    echo " (el que quieras, pero acuérdate de él: se lo darás a Lucas). Verifica tu correo cuando te lo pida."
    open https://github.com/signup
    read -r -p " Cuando hayas terminado de crearla, pulsa Intro. " _
  fi
  echo
  echo " Ahora conectamos este Mac con tu cuenta. Saldrá un CÓDIGO de 8 letras:"
  echo " elige GitHub.com, HTTPS, Yes y \"Login with a web browser\", copia el código,"
  echo " pulsa Intro y pégalo en la página que se abre."
  echo
  gh auth login --hostname github.com --git-protocol https --web || { echo " ✖ No se pudo iniciar sesión. Vuelve a abrirme para repetirlo."; exit 1; }
  gh auth setup-git >/dev/null 2>&1
fi
USUARIO="$(gh api user --jq .login)"
echo " ✔ Has iniciado sesión en GitHub como: $USUARIO"

echo
echo " --- Paso 3: descargar el proyecto ---"
mkdir -p "$CARPETA"
if [ -d "$DESTINO/.git" ]; then
  echo " Ya lo tenías descargado. Lo actualizo..."
  git -C "$DESTINO" pull --ff-only
elif ! gh repo clone "$REPO" "$DESTINO"; then
  echo
  echo " ✖ Todavía no tienes acceso al proyecto."
  echo
  echo "   Tu usuario de GitHub es:  $USUARIO"
  echo "   Mándaselo a Lucas (ya lo tienes copiado: solo tienes que pegarlo en un mensaje)"
  echo "   y vuelve a abrirme cuando te diga que ya estás dentro."
  printf '%s' "$USUARIO" | pbcopy
  exit 1
fi

echo
echo " --- Paso 4: abrir el proyecto ---"
if [ -f "$DESTINO/Abrir proyecto.command" ]; then
  bash "$DESTINO/Abrir proyecto.command"
else
  echo " ✖ No encuentro \"Abrir proyecto.command\" en $DESTINO. Avisa a Lucas."
fi
