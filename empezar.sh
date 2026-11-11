#!/bin/bash
# Empezar en Zoolutions Lab (Mac). Se ejecuta en Terminal con:
#   bash <(curl -fsSL https://zoolutionslab.github.io/empezar/empezar.sh)
# (así, y no con "curl | bash", el teclado sigue conectado al script: las preguntas y la contraseña de Homebrew funcionan).
# Deja el Mac listo (Homebrew, Git, Node.js, GitHub CLI y tu IA: Claude Code o Codex, la de ChatGPT), entra en GitHub, pide
# el acceso con la palabra de invitación, prepara el avatar, descarga el Zoo y lo abre. Solo hace falta una vez por persona y ordenador.
#
# Variables para probar sin efectos:
#   EMPEZAR_RAIZ=<carpeta>     destino en vez de ~/Zoolutions
#   EMPEZAR_SIN_INSTALAR=1     no instala nada (dice qué instalaría)
#   EMPEZAR_SIN_ABRIR=1        no abre el navegador ni el Zoo
#   EMPEZAR_SIN_PAUSAS=1       no espera a que pulses Intro
#   EMPEZAR_REPO=<owner/repo>  repositorio del Zoo (zoolutionslab/zoo)
#   EMPEZAR_IA=claude|codex|ambas  la IA, sin preguntar (claude = Claude Code, codex = ChatGPT)

# Si alguien lo lanzó con "curl | bash", recuperamos el teclado.
if [ ! -t 0 ] && [ -r /dev/tty ]; then exec < /dev/tty; fi

ORG="zoolutionslab"
REPO="${EMPEZAR_REPO:-$ORG/zoo}"
REPO_ACCESO="$ORG/empezar"
RAIZ="${EMPEZAR_RAIZ:-$HOME/Zoolutions}"
DESTINO="$RAIZ/zoo"
SIN_INSTALAR="${EMPEZAR_SIN_INSTALAR:-0}"
SIN_ABRIR="${EMPEZAR_SIN_ABRIR:-0}"
SIN_PAUSAS="${EMPEZAR_SIN_PAUSAS:-0}"
ANIMAL=""
IA="$(printf '%s' "${EMPEZAR_IA:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

titulo() { echo; echo " --- $1 ---"; }
ok() { echo " [OK] $1"; }
mal() { echo " [X] $1"; }
pausa() { [ "$SIN_PAUSAS" = "1" ] && return 0; read -r -p " ${1:-Pulsa Intro para seguir} " _; }
pregunta() { # pregunta "texto" -> 0 si sí
  [ "$SIN_PAUSAS" = "1" ] && return 0
  local r; read -r -p " $1 [s/n] " r; [[ "$r" =~ ^[[:space:]]*[sSyY] ]]
}
abrir() {
  if [ "$SIN_ABRIR" = "1" ]; then echo " (modo prueba) Abriría: $1"; return 0; fi
  if command -v open >/dev/null 2>&1; then open "$1"; else echo " Abre esta dirección en tu navegador: $1"; fi
}
copiar() { if command -v pbcopy >/dev/null 2>&1; then printf '%s' "$1" | pbcopy; fi; }
normalizar() { # minúsculas, sin tildes, espacios colapsados (igual que el workflow de acceso)
  printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed -e "s/[^a-z0-9 ]//g" -e 's/^ *//' -e 's/ *$//' -e 's/  */ /g'
}
cargar_brew() { for ruta in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$ruta" ] && eval "$("$ruta" shellenv)" && return 0; done; return 1; }

clear
cat <<EOF

 ====================================================
   Bienvenido a Zoolutions Lab. Vamos a dejar tu Mac
   listo y a llevarte al Zoo.
 ====================================================

 Haré cinco cosas, y antes de instalar nada te pregunto:
   1. Elegir tu IA (Claude o ChatGPT) y comprobar e instalar lo que falte: Git, Node.js, GitHub y la IA.
   2. Entrar en tu cuenta de GitHub (si no tienes, te ayudo a crearla).
   3. Pedir tu acceso con tu palabra de invitación (tu animal).
   4. Preparar tu avatar para GitHub.
   5. Descargar el Zoo en  $DESTINO  y abrirlo.

EOF
if [ "$SIN_INSTALAR" = "1" ] || [ "$SIN_ABRIR" = "1" ] || [ -n "$EMPEZAR_RAIZ" ]; then echo " (modo prueba activado por variables EMPEZAR_*)"; fi
pausa "Pulsa Intro para empezar"

# ---------- 1. Programas ----------
titulo "Paso 1 de 5: tu IA y los programas necesarios"
case "$IA" in claude|codex|ambas) ;; *)
  echo " En el Zoo trabajas hablando con una IA. Puedes elegir:"
  echo "   1) Claude (recomendada): Claude Code, de Anthropic. Entras con tu cuenta de Claude."
  echo "   2) ChatGPT (Codex): la IA de OpenAI. Entras con tu cuenta de ChatGPT."
  echo "   3) Las dos (eliges cuál usar en el Zoo, en Perfil > Mi IA)."
  if [ "$SIN_PAUSAS" = "1" ]; then IA="claude"; else
    read -r -p " ¿Con qué IA vas a trabajar? [1, 2 o 3; Intro = 1] " r
    case "$(printf '%s' "$r" | tr -d '[:space:]')" in 2*) IA="codex" ;; 3*) IA="ambas" ;; *) IA="claude" ;; esac
  fi ;;
esac
IA_PRINCIPAL="claude"; [ "$IA" = "codex" ] && IA_PRINCIPAL="codex"
case "$IA" in codex) NOMBRE_IA="ChatGPT (Codex)" ;; ambas) NOMBRE_IA="Claude y ChatGPT (Codex); en el Zoo empiezas con Claude" ;; *) NOMBRE_IA="Claude (Claude Code)" ;; esac
ok "Tu IA: $NOMBRE_IA."
echo " No te pide entrar ahora: la primera vez que abras una conversación en el Zoo, la IA te pedirá entrar con su cuenta"
echo " (Claude: con tu cuenta de Claude; Codex: con tu cuenta de ChatGPT). Solo esa vez."
# El Zoo y los lanzadores de los proyectos leen la elección de ~/.zoo/ajustes.json (clave "ia"). Se guarda al tener Node (abajo).
guardar_ia() {
  local casa fichero
  if [ -n "${ZOO_CASA:-}" ]; then casa="$ZOO_CASA"; elif [ -n "${EMPEZAR_RAIZ:-}" ]; then casa="$RAIZ/.zoo"; else casa="$HOME/.zoo"; fi
  fichero="$casa/ajustes.json"
  mkdir -p "$casa" 2>/dev/null || true
  if command -v node >/dev/null 2>&1 && node -e '
    const fs = require("fs"); const [f, ia] = process.argv.slice(1); let a = {};
    try { a = JSON.parse(fs.readFileSync(f, "utf8").replace(/^\uFEFF/, "")); } catch {}
    if (typeof a !== "object" || a === null || Array.isArray(a)) a = {};
    a.ia = ia; fs.writeFileSync(f, JSON.stringify(a, null, 2) + "\n");' "$fichero" "$IA_PRINCIPAL" 2>/dev/null; then
    echo " (Elección guardada en $fichero)"
  else
    echo " No he podido guardar la elección en $fichero. Podrás cambiarla en el Zoo, en Perfil > Mi IA."
  fi
}
echo
cargar_brew >/dev/null 2>&1 || true
if ! command -v brew >/dev/null 2>&1; then
  echo " Para instalar programas uso Homebrew, y no lo tienes."
  if [ "$SIN_INSTALAR" = "1" ]; then
    echo " (modo prueba) Instalaría Homebrew con su instalador oficial."
  elif pregunta "¿Lo instalo ahora? (te pedirá la contraseña de tu Mac; al escribirla no se ve nada, es normal)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { mal "No se pudo instalar Homebrew. Haz una captura y mándasela a Lucas."; exit 1; }
    cargar_brew || { mal "Homebrew se instaló pero no lo encuentro. Cierra Terminal, ábrela de nuevo y repite la línea."; exit 1; }
    # Que lo encuentren también las ventanas de mañana (el instalador no toca estos ficheros).
    for perfil in "$HOME/.zprofile" "$HOME/.bash_profile"; do
      grep -q 'brew shellenv' "$perfil" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$perfil"
    done
  else
    echo " Sin Homebrew no puedo seguir. Vuelve a ejecutar la línea cuando quieras."; exit 1
  fi
fi

instalar() { # instalar "nombre" "comando" "orden de brew" "para qué sirve"
  command -v "$2" >/dev/null 2>&1 && return 0
  echo
  echo " Falta $1: $4."
  if [ "$SIN_INSTALAR" = "1" ]; then echo " (modo prueba) Lo instalaría con: $3"; return 0; fi
  if pregunta "¿Lo instalo ahora?"; then
    eval "$3" || { mal "No se pudo instalar $1. Haz una captura y mándasela a Lucas."; exit 1; }
  else
    echo " Sin $1 no puedo seguir. Vuelve a ejecutar la línea cuando quieras instalarlo."; exit 1
  fi
}
instalar "Git" git "brew install git" "guarda el historial de lo que haces y lo comparte con tu equipo"
instalar "Node.js" node "brew install node" "es el motor que hace funcionar las herramientas"
instalar "GitHub CLI" gh "brew install gh" "te conecta con GitHub, donde viven los proyectos"
guardar_ia
if { [ "$IA" = "claude" ] || [ "$IA" = "ambas" ]; } && ! command -v claude >/dev/null 2>&1; then
  echo
  echo " Falta Claude Code: es la IA con la que vas a trabajar."
  if [ "$SIN_INSTALAR" = "1" ]; then
    echo " (modo prueba) Lo instalaría con el instalador oficial (curl -fsSL https://claude.ai/install.sh | bash) o, si falla, con brew install --cask claude-code."
  elif pregunta "¿Lo instalo ahora?"; then
    curl -fsSL https://claude.ai/install.sh | bash || true   # instalador oficial: se actualiza solo
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v claude >/dev/null 2>&1; then
      echo " El instalador oficial no ha terminado bien; pruebo con Homebrew."
      brew install --cask claude-code || { mal "No se pudo instalar Claude Code. Haz una captura y mándasela a Lucas."; exit 1; }
    fi
    grep -q '.local/bin' "$HOME/.zprofile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zprofile"
  else
    echo " Sin Claude Code no puedo seguir. Vuelve a ejecutar la línea cuando quieras instalarlo."; exit 1
  fi
fi
if { [ "$IA" = "codex" ] || [ "$IA" = "ambas" ]; } && ! command -v codex >/dev/null 2>&1; then
  echo
  echo " Falta Codex: la IA de ChatGPT con la que vas a trabajar."
  if [ "$SIN_INSTALAR" = "1" ]; then
    echo " (modo prueba) Lo instalaría con el instalador oficial (curl -fsSL https://chatgpt.com/codex/install.sh | sh) o, si falla, con brew install --cask codex."
  elif pregunta "¿Lo instalo ahora?"; then
    curl -fsSL https://chatgpt.com/codex/install.sh | sh || true   # instalador oficial de OpenAI
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v codex >/dev/null 2>&1; then
      echo " El instalador oficial no ha terminado bien; pruebo con Homebrew."
      brew install --cask codex || { mal "No se pudo instalar Codex. Haz una captura y mándasela a Lucas."; exit 1; }
    fi
    grep -q '.local/bin' "$HOME/.zprofile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zprofile"
  else
    echo " Sin Codex no puedo seguir. Vuelve a ejecutar la línea cuando quieras instalarlo."; exit 1
  fi
fi
ok "Todos los programas están instalados."

# ---------- 2. GitHub ----------
titulo "Paso 2 de 5: tu cuenta de GitHub"
if ! gh auth status >/dev/null 2>&1; then
  echo " GitHub es la web donde viven los proyectos. Necesitas una cuenta gratuita."
  if ! pregunta "¿Ya tienes cuenta de GitHub?"; then
    echo
    echo " Te abro la página para crearla. Pon tu correo, una contraseña y un nombre de usuario"
    echo " (el que quieras, pero acuérdate de él). Verifica tu correo cuando te lo pida."
    abrir "https://github.com/signup"
    pausa "Cuando la tengas creada, pulsa Intro."
  fi
  echo
  echo " Ahora conectamos este Mac con tu cuenta. Te va a preguntar dos cosas:"
  echo "   1) si quieres usar tu cuenta también para Git: pulsa Intro (sí);"
  echo "   2) \"Press Enter to open github.com\": pulsa Intro. Se abre el navegador con un cuadro de 8 letras."
  echo " El código ya está copiado: pégalo (Cmd+V), pulsa Continue y después Authorize."
  echo
  gh auth login --hostname github.com --git-protocol https --web --clipboard || { mal "No se pudo iniciar sesión. Vuelve a ejecutar la línea para repetirlo."; exit 1; }
  gh auth setup-git >/dev/null 2>&1
fi
USUARIO="$(gh api user --jq .login 2>/dev/null)"
[ -n "$USUARIO" ] || { mal "No consigo hablar con GitHub (¿hay internet?). Vuelve a ejecutar la línea dentro de un rato."; exit 1; }
ok "Has iniciado sesión en GitHub como: $USUARIO"

# ---------- 3. Acceso ----------
titulo "Paso 3 de 5: tu acceso a Zoolutions Lab"
estado_membresia() { local s; s="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)" || s=""; [ -n "$s" ] && echo "$s" || echo "ninguna"; }
copiar_usuario() {
  copiar "$USUARIO"
  echo
  echo "   Tu usuario de GitHub es:  $USUARIO"
  echo "   Mándaselo a Lucas (ya lo tienes copiado: solo tienes que pegarlo en un mensaje)"
  echo "   y vuelve a ejecutar la línea cuando te diga que ya estás dentro."
}
leer_fichero_del_repo() { gh api "repos/$1/contents/$2" --jq .content 2>/dev/null | base64 --decode 2>/dev/null; }
animal_de_socio() { # el animal de esta cuenta según identidad/socios.json del Zoo
  leer_fichero_del_repo "$REPO" "identidad/socios.json" | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      try { const yo = (JSON.parse(s).socios || []).find(x => x.usuario_github && x.usuario_github.toLowerCase() === process.argv[1].toLowerCase());
        if (yo && yo.animal) process.stdout.write(yo.animal); } catch {} });' "$USUARIO" 2>/dev/null
}
ESTADO="$(estado_membresia)"
if [ "$ESTADO" = "active" ]; then
  # Segundo aparato de la misma persona: no se pide palabra ninguna (la palabra es de un solo uso y ya se usó).
  ANIMAL="$(animal_de_socio)"
  if [ -n "$ANIMAL" ]; then ok "Ya eres del Zoo (tu animal: $ANIMAL); esto es tu segundo aparato. No hace falta palabra."
  else ok "Ya eres del Zoo; esto es tu segundo aparato. No hace falta palabra."; fi
else
  if [ "$ESTADO" != "pending" ]; then
    # Si todavía no hay palabras registradas (invitaciones.json vacío), no hay nada que comprobar: camino manual.
    REGISTRADAS="$(leer_fichero_del_repo "$REPO_ACCESO" "invitaciones.json" | tr -d '[:space:]')"
    if [ -z "$REGISTRADAS" ] || [ "$REGISTRADAS" = "[]" ]; then
      echo " El acceso automático todavía no está activado (no hay palabras registradas)."
      copiar_usuario; exit 1
    fi
    echo " Para entrar hace falta tu palabra de invitación: es tu animal, y te lo ha dicho Lucas."
    echo " (Si ya la usaste en otro ordenador, no la necesitas: entra en GitHub con la misma cuenta y el Zoo te reconoce.)"
    intentos=0
    while [ "$ESTADO" = "ninguna" ] && [ $intentos -lt 3 ]; do
      intentos=$((intentos + 1))
      read -r -p " Tu palabra de invitación: " PALABRA
      [ -n "$(printf '%s' "$PALABRA" | tr -d '[:space:]')" ] || continue
      ANIMAL="$(normalizar "$PALABRA" | tr ' ' '-')"
      CUERPO="$(printf '### Palabra de invitación\n\n%s' "$(printf '%s' "$PALABRA" | sed -e 's/^ *//' -e 's/ *$//')")"
      URL_ISSUE="$(gh issue create -R "$REPO_ACCESO" --title "Acceso: $USUARIO" --body "$CUERPO" 2>/dev/null)" || URL_ISSUE=""
      if [ -z "$URL_ISSUE" ]; then mal "No he podido pedir el acceso (¿hay internet? ¿está verificado tu correo en GitHub?)."; copiar_usuario; exit 1; fi
      NUMERO="${URL_ISSUE##*/}"
      echo " Pedido enviado ($URL_ISSUE). Espero la respuesta (suele tardar menos de un minuto)..."
      RESPUESTA=""; CERRADO=0; vueltas=0
      while [ $vueltas -lt 40 ]; do
        vueltas=$((vueltas + 1)); sleep 6
        if [ "$(gh issue view "$NUMERO" -R "$REPO_ACCESO" --json state --jq .state 2>/dev/null)" = "CLOSED" ]; then
          CERRADO=1; RESPUESTA="$(gh issue view "$NUMERO" -R "$REPO_ACCESO" --json comments --jq '.comments[-1].body // ""' 2>/dev/null)"; break
        fi
      done
      if [ $CERRADO = 0 ]; then echo " GitHub no ha contestado todavía. Te lo dirá en el propio pedido (te llega un correo)."; copiar_usuario; exit 1; fi
      echo; echo " Respuesta:"; printf '%s\n' "$RESPUESTA" | grep -v '^[[:space:]]*<!--' | sed 's/^/   /'
      ESTADO="$(estado_membresia)"
      # La marca oculta del comentario (<!-- acceso:x -->) dice qué pasó sin interpretar la prosa.
      if printf '%s' "$RESPUESTA" | grep -q "acceso:usada"; then exit 1; fi   # ya explica cómo vincular un segundo aparato
      if [ "$ESTADO" = "ninguna" ]; then
        if printf '%s' "$RESPUESTA" | grep -q -E "acceso:no-vale|no vale"; then echo " Prueba otra vez (comprueba la palabra con Lucas)."; continue; fi
        copiar_usuario; exit 1
      fi
    done
    [ "$ESTADO" != "ninguna" ] || exit 1
  fi
  if [ "$ESTADO" = "pending" ]; then
    echo
    echo " Tienes una invitación esperándote. Te abro la página: pulsa el botón verde \"Join Zoolutions Lab\""
    echo " (también te ha llegado por correo). Yo espero aquí."
    abrir "https://github.com/orgs/$ORG/invitation"
    vueltas=0
    while [ $vueltas -lt 240 ]; do vueltas=$((vueltas + 1)); sleep 5; [ "$(estado_membresia)" = "active" ] && break; done
    [ "$(estado_membresia)" = "active" ] || { mal "Sigo sin verte dentro. Acepta la invitación y vuelve a ejecutar la línea."; exit 1; }
    ok "Ya estás dentro de Zoolutions Lab."
  fi
fi

# ---------- 4. Avatar ----------
titulo "Paso 4 de 5: tu avatar"
if [ -z "$ANIMAL" ]; then
  read -r -p " ¿Cuál es tu animal? (Intro para saltar este paso) " A
  [ -n "$(printf '%s' "$A" | tr -d '[:space:]')" ] && ANIMAL="$(normalizar "$A" | tr ' ' '-')"
fi
if [ -n "$ANIMAL" ]; then
  mkdir -p "$RAIZ"
  AVATAR="$RAIZ/mi-avatar.png"
  if gh api "repos/$REPO/contents/identidad/avatares/$ANIMAL.png" --jq .content 2>/dev/null | base64 --decode > "$AVATAR" 2>/dev/null && [ -s "$AVATAR" ]; then
    ok "Tu avatar está en  $AVATAR"
    echo " GitHub no deja cambiar la foto de perfil desde aquí, así que ese clic es tuyo. Te abro la página:"
    echo "   1) Pulsa en la foto redonda (arriba a la izquierda) y elige \"Upload a photo...\"."
    echo "   2) Busca la carpeta  $RAIZ  y elige  mi-avatar.png."
    echo "   3) Pulsa \"Set new profile picture\"."
    abrir "https://github.com/settings/profile"
    pausa "Cuando lo tengas (o si prefieres hacerlo luego), pulsa Intro."
  else
    rm -f "$AVATAR"
    echo " Todavía no hay avatar para «$ANIMAL» en el Zoo. No pasa nada: Lucas lo prepara y lo subes luego desde el Zoo."
  fi
else
  echo " Saltado. Podrás ponerte el avatar desde el Zoo más adelante."
fi

# ---------- 5. El Zoo ----------
titulo "Paso 5 de 5: descargar el Zoo"
mkdir -p "$RAIZ"
if [ -d "$DESTINO/.git" ]; then
  echo " Ya lo tenías descargado. Lo pongo al día..."
  git -C "$DESTINO" pull --ff-only >/dev/null 2>&1 || echo " No he podido ponerlo al día (puede que tengas cambios sin guardar). Sigo con lo que hay; díselo a tu IA al abrir el Zoo."
else
  gh repo view "$REPO" --json name >/dev/null 2>&1 || { mal "Todavía no tienes acceso al Zoo."; copiar_usuario; exit 1; }
  gh repo clone "$REPO" "$DESTINO" 2>&1 | sed 's/^/   /'
  [ -d "$DESTINO/.git" ] || { mal "No se ha podido descargar el Zoo. Haz una captura de esta ventana y mándasela a Lucas."; exit 1; }
fi
chmod +x "$DESTINO"/*.command 2>/dev/null || true
ok "El Zoo está en  $DESTINO"

# Acceso directo «Zoo» en el Escritorio: una pequeña app (osacompile, viene con el Mac), con la cabra de icono
# (iconutil, también del sistema). No abre Zoo.command a secas: llama a app/scripts/acceso.sh del Zoo, que si el Zoo
# ya está abierto trae su ventana al frente sin abrir otra Terminal, y si no lo arranca (si ese script no existiera,
# abre Zoo.command como siempre). La marca zoo-acceso le dice al Zoo que este icono ya es el nuevo (app/servidor/acceso.ts).
# En modo prueba (EMPEZAR_RAIZ) se deja dentro de la carpeta de prueba.
LANZADOR="$DESTINO/Zoo.command"
ACCESO="$DESTINO/app/scripts/acceso.sh"
if command -v osacompile >/dev/null 2>&1; then
  ESCRITORIO="$HOME/Desktop"; [ -n "$EMPEZAR_RAIZ" ] && ESCRITORIO="$RAIZ"
  APP="$ESCRITORIO/Zoo.app"
  rm -rf "$APP"
  if osacompile -o "$APP" -e "do shell script \"if [ -f '$ACCESO' ]; then /bin/bash '$ACCESO'; else open '$LANZADOR'; fi\"" >/dev/null 2>&1; then
    echo 2 > "$APP/Contents/Resources/zoo-acceso" 2>/dev/null || true
    if command -v iconutil >/dev/null 2>&1 && [ -d "$DESTINO/identidad/marca/zoo.iconset" ]; then
      iconutil -c icns "$DESTINO/identidad/marca/zoo.iconset" -o "$APP/Contents/Resources/applet.icns" 2>/dev/null && touch "$APP"
    fi
    ok "Acceso directo «Zoo» creado en  $ESCRITORIO"
  else
    echo " No he podido crear el acceso directo en el Escritorio. Puedes abrir el Zoo desde la carpeta $DESTINO (Zoo.command)."
  fi
else
  echo " (En este sistema no hay osacompile: sin acceso directo. Abre el Zoo desde la carpeta $DESTINO.)"
fi
echo
echo " Ya está todo. A partir de ahora, para trabajar: doble clic en «Zoo», en el Escritorio."
if [ "$SIN_ABRIR" = "1" ]; then
  echo " (modo prueba) Abriría: $LANZADOR"
elif [ -f "$LANZADOR" ]; then
  echo " Lo abro ahora."
  open "$LANZADOR" 2>/dev/null || bash "$LANZADOR"
else
  echo " (Todavía no encuentro Zoo.command en $DESTINO. Abre la carpeta y mira si está; si no, avisa a Lucas.)"
fi
