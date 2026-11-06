# Empezar en Zoolutions Lab (Windows). Se ejecuta con:  irm https://zoolutionslab.github.io/empezar/empezar.ps1 | iex
# Deja el ordenador listo (Git, Node.js, GitHub CLI, Claude Code), entra en GitHub, pide el acceso con la palabra de
# invitación, prepara el avatar, descarga el Zoo y lo abre. Solo hace falta una vez por persona y ordenador.
#
# Variables para probar sin efectos:
#   EMPEZAR_RAIZ=<carpeta>     destino en vez de %USERPROFILE%\Zoolutions
#   EMPEZAR_SIN_INSTALAR=1     no instala nada (dice qué instalaría)
#   EMPEZAR_SIN_ABRIR=1        no abre el navegador ni el Zoo
#   EMPEZAR_SIN_PAUSAS=1       no espera a que pulses Intro
#   EMPEZAR_REPO=<owner/repo>  repositorio del Zoo (zoolutionslab/zoo)

function Empezar {
  $ErrorActionPreference = 'Continue'
  try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

  $Org = 'zoolutionslab'
  $Repo = if ($env:EMPEZAR_REPO) { $env:EMPEZAR_REPO } else { "$Org/zoo" }
  $RepoAcceso = "$Org/empezar"
  $Raiz = if ($env:EMPEZAR_RAIZ) { $env:EMPEZAR_RAIZ } else { Join-Path $env:USERPROFILE 'Zoolutions' }
  $Destino = Join-Path $Raiz 'zoo'
  $SinInstalar = $env:EMPEZAR_SIN_INSTALAR -eq '1'
  $SinAbrir = $env:EMPEZAR_SIN_ABRIR -eq '1'
  $SinPausas = $env:EMPEZAR_SIN_PAUSAS -eq '1'
  $script:Animal = $null

  function Titulo($t) { Write-Host ''; Write-Host " --- $t ---" -ForegroundColor Cyan }
  function Ok($t) { Write-Host " [OK] $t" -ForegroundColor Green }
  function Mal($t) { Write-Host " [X] $t" -ForegroundColor Red }
  function Pausa($t) {
    if ($SinPausas) { return }
    if (-not $t) { $t = 'Pulsa Intro para seguir' }
    Read-Host " $t" | Out-Null
  }
  function Pregunta($t) {  # devuelve $true si la respuesta empieza por s (sí)
    if ($SinPausas) { return $true }
    $r = Read-Host " $t [s/n]"
    return ($r -match '^\s*[sSyY]')
  }
  function Abrir($url) {
    if ($SinAbrir) { Write-Host " (modo prueba) Abriría: $url"; return }
    try { Start-Process $url | Out-Null } catch { Write-Host " Abre esta dirección en tu navegador: $url" }
  }
  function Refrescar-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
  }
  function Hay($comando) { return [bool](Get-Command $comando -ErrorAction SilentlyContinue) }
  function Normalizar($texto) {  # minúsculas, sin tildes, sin espacios sobrantes (igual que el workflow de acceso)
    $t = $texto.Trim().ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $t = -join ($t.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    return ($t -replace '\s+', ' ')
  }

  Clear-Host
  Write-Host ''
  Write-Host ' ====================================================' -ForegroundColor Cyan
  Write-Host '   Bienvenido a Zoolutions Lab. Vamos a dejar tu' -ForegroundColor Cyan
  Write-Host '   ordenador listo y a llevarte al Zoo.' -ForegroundColor Cyan
  Write-Host ' ====================================================' -ForegroundColor Cyan
  Write-Host ''
  Write-Host ' Haré cinco cosas, y antes de instalar nada te pregunto:'
  Write-Host '   1. Comprobar e instalar lo que falte: Git, Node.js, GitHub y Claude Code.'
  Write-Host '   2. Entrar en tu cuenta de GitHub (si no tienes, te ayudo a crearla).'
  Write-Host '   3. Pedir tu acceso con tu palabra de invitación (tu animal).'
  Write-Host '   4. Preparar tu avatar para GitHub.'
  Write-Host "   5. Descargar el Zoo en  $Destino  y abrirlo."
  Write-Host ''
  if ($SinInstalar -or $SinAbrir -or $env:EMPEZAR_RAIZ) { Write-Host ' (modo prueba activado por variables EMPEZAR_*)' -ForegroundColor DarkGray }
  Pausa 'Pulsa Intro para empezar'

  # ---------- 1. Programas ----------
  Titulo 'Paso 1 de 5: programas necesarios'
  $instalados = 0
  function Instalar-Winget($nombre, $id, $paraQue) {
    Write-Host ''
    Write-Host " Falta $nombre`: $paraQue."
    if ($SinInstalar) { Write-Host " (modo prueba) Lo instalaría con winget ($id)."; return $true }
    if (-not (Hay 'winget')) {
      Mal 'Tu Windows no tiene "winget", que uso para instalar programas.'
      Write-Host '   Abre Microsoft Store, busca "Instalador de aplicación" y actualízalo; luego vuelve a ejecutar esto.'
      Write-Host '   Si el ordenador es de una empresa y la Store está bloqueada, pide ayuda a alguien técnico.'
      Abrir 'https://apps.microsoft.com/detail/9nblggh4nns1'
      return $false
    }
    if (-not (Pregunta "¿Lo instalo ahora?")) { Write-Host " Sin $nombre no puedo seguir. Vuelve a ejecutar esto cuando quieras instalarlo."; return $false }
    & winget install --id $id -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Mal "No se ha podido instalar $nombre. Haz una captura de esta ventana y mándasela a Lucas."; return $false }
    Refrescar-Path
    $script:instalados++
    return $true
  }
  function Instalar-Claude {
    Write-Host ''
    Write-Host ' Falta Claude Code: es la IA con la que vas a trabajar.'
    if ($SinInstalar) { Write-Host ' (modo prueba) Lo instalaría con el instalador oficial (irm https://claude.ai/install.ps1 | iex) o, si falla, con winget (Anthropic.ClaudeCode).'; return $true }
    if (-not (Pregunta '¿Lo instalo ahora?')) { Write-Host ' Sin Claude Code no puedo seguir. Vuelve a ejecutar esto cuando quieras instalarlo.'; return $false }
    # Instalador oficial (se actualiza solo). En proceso aparte para que sus "exit" no cierren esta ventana.
    & powershell -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    Refrescar-Path
    if (-not (Hay 'claude')) {
      Write-Host ' El instalador oficial no ha terminado bien; pruebo con winget.'
      if (-not (Hay 'winget')) { Mal 'No se ha podido instalar Claude Code. Haz una captura y mándasela a Lucas.'; return $false }
      & winget install --id Anthropic.ClaudeCode -e --accept-source-agreements --accept-package-agreements
      Refrescar-Path
      if (-not (Hay 'claude')) { Mal 'No se ha podido instalar Claude Code. Haz una captura y mándasela a Lucas.'; return $false }
    }
    $script:instalados++
    return $true
  }

  if (-not (Hay 'git')) { if (-not (Instalar-Winget 'Git' 'Git.Git' 'guarda el historial de lo que haces y lo comparte con tu equipo')) { Pausa 'Pulsa Intro para cerrar'; return } }
  if (-not (Hay 'node')) { if (-not (Instalar-Winget 'Node.js' 'OpenJS.NodeJS.LTS' 'es el motor que hace funcionar las herramientas')) { Pausa 'Pulsa Intro para cerrar'; return } }
  if (-not (Hay 'gh')) { if (-not (Instalar-Winget 'GitHub CLI' 'GitHub.cli' 'te conecta con GitHub, donde viven los proyectos')) { Pausa 'Pulsa Intro para cerrar'; return } }
  if (-not (Hay 'claude')) { if (-not (Instalar-Claude)) { Pausa 'Pulsa Intro para cerrar'; return } }

  if (-not $SinInstalar) {
    $faltan = @('git', 'node', 'gh', 'claude') | Where-Object { -not (Hay $_) }
    if ($faltan.Count) {
      Write-Host ''
      Write-Host " He instalado programas nuevos, pero esta ventana todavía no los ve ($($faltan -join ', '))."
      Write-Host ' Cierra esta ventana, abre otra igual y vuelve a pegar la misma línea: seguirá justo donde lo dejamos.'
      Pausa 'Pulsa Intro para cerrar'
      return
    }
  }
  Ok 'Todos los programas están instalados.'

  # ---------- 2. GitHub ----------
  Titulo 'Paso 2 de 5: tu cuenta de GitHub'
  & gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host ' GitHub es la web donde viven los proyectos. Necesitas una cuenta gratuita.'
    if (-not (Pregunta '¿Ya tienes cuenta de GitHub?')) {
      Write-Host ''
      Write-Host ' Te abro la página para crearla. Pon tu correo, una contraseña y un nombre de usuario'
      Write-Host ' (el que quieras, pero acuérdate de él). Verifica tu correo cuando te lo pida.'
      Abrir 'https://github.com/signup'
      Pausa 'Cuando la tengas creada, pulsa Intro'
    }
    Write-Host ''
    Write-Host ' Ahora conectamos este ordenador con tu cuenta. Te va a preguntar dos cosas:'
    Write-Host '   1) si quieres usar tu cuenta también para Git: pulsa Intro (sí);'
    Write-Host '   2) "Press Enter to open github.com": pulsa Intro. Se abre el navegador con un cuadro de 8 letras.'
    Write-Host ' El código ya está copiado: pégalo (Ctrl+V), pulsa Continue y después Authorize.'
    Write-Host ''
    & gh auth login --hostname github.com --git-protocol https --web --clipboard
    if ($LASTEXITCODE -ne 0) { Mal 'No se ha podido iniciar sesión. Vuelve a ejecutar esto para repetirlo.'; Pausa 'Pulsa Intro para cerrar'; return }
    & gh auth setup-git 2>&1 | Out-Null
  }
  $Usuario = (& gh api user --jq .login 2>$null)
  if (-not $Usuario) { Mal 'No consigo hablar con GitHub (¿hay internet?). Vuelve a ejecutar esto dentro de un rato.'; Pausa 'Pulsa Intro para cerrar'; return }
  Ok "Has iniciado sesión en GitHub como: $Usuario"

  # ---------- 3. Acceso ----------
  Titulo 'Paso 3 de 5: tu acceso a Zoolutions Lab'
  function Estado-Membresia {
    $s = (& gh api "user/memberships/orgs/$Org" --jq .state 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $s) { return 'ninguna' }
    return $s.Trim()
  }
  function Copiar-Usuario {
    try { Set-Clipboard -Value $Usuario } catch {}
    Write-Host ''
    Write-Host "   Tu usuario de GitHub es:  $Usuario" -ForegroundColor Yellow
    Write-Host '   Mándaselo a Lucas (ya lo tienes copiado: solo tienes que pegarlo en un mensaje)'
    Write-Host '   y vuelve a ejecutar esto cuando te diga que ya estás dentro.'
  }
  function Leer-Json-Del-Repo($repositorio, $ruta) {  # fichero de un repositorio al que ya se tiene acceso, o $null
    $b64 = (& gh api "repos/$repositorio/contents/$ruta" --jq .content 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $b64) { return $null }
    try { return ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($b64 -replace '\s', ''))) | ConvertFrom-Json) } catch { return $null }
  }
  function Animal-De-Socio {  # el animal de esta cuenta según identidad/socios.json del Zoo
    $json = Leer-Json-Del-Repo $Repo 'identidad/socios.json'
    if (-not $json) { return $null }
    $yo = @($json.socios | Where-Object { $_.usuario_github -and ($_.usuario_github.ToLower() -eq $Usuario.ToLower()) })
    if ($yo.Count -and $yo[0].animal) { return $yo[0].animal }
    return $null
  }
  $estado = Estado-Membresia
  if ($estado -eq 'active') {
    # Segundo aparato de la misma persona: no se pide palabra ninguna (la palabra es de un solo uso y ya se usó).
    $script:Animal = Animal-De-Socio
    if ($script:Animal) { Ok "Ya eres del Zoo (tu animal: $($script:Animal)); esto es tu segundo aparato. No hace falta palabra." }
    else { Ok 'Ya eres del Zoo; esto es tu segundo aparato. No hace falta palabra.' }
  } else {
    if ($estado -ne 'pending') {
      # Si todavía no hay palabras registradas (invitaciones.json vacío), no hay nada que comprobar: camino manual.
      $registradas = Leer-Json-Del-Repo $RepoAcceso 'invitaciones.json'
      if ($null -eq $registradas -or @($registradas).Count -eq 0) {
        Write-Host ' El acceso automático todavía no está activado (no hay palabras registradas).'
        Copiar-Usuario
        Pausa 'Pulsa Intro para cerrar'
        return
      }
      Write-Host ' Para entrar hace falta tu palabra de invitación: es tu animal, y te lo ha dicho Lucas.'
      Write-Host ' (Si ya la usaste en otro ordenador, no la necesitas: entra en GitHub con la misma cuenta y el Zoo te reconoce.)'
      $intentos = 0
      $parar = $false
      while ($estado -eq 'ninguna' -and $intentos -lt 3 -and -not $parar) {
        $intentos++
        $palabra = Read-Host ' Tu palabra de invitación'
        if (-not $palabra.Trim()) { continue }
        $script:Animal = (Normalizar $palabra) -replace ' ', '-'
        $cuerpo = "### Palabra de invitación`n`n$($palabra.Trim())"
        $urlIssue = (& gh issue create -R $RepoAcceso --title "Acceso: $Usuario" --body $cuerpo 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $urlIssue) { Mal 'No he podido pedir el acceso (¿hay internet? ¿está verificado tu correo en GitHub?).'; Copiar-Usuario; $parar = $true; break }
        $numero = ($urlIssue.Trim() -split '/')[-1]
        Write-Host " Pedido enviado ($($urlIssue.Trim())). Espero la respuesta (suele tardar menos de un minuto)..."
        $respuesta = $null
        $limite = (Get-Date).AddMinutes(4)
        while ((Get-Date) -lt $limite) {
          Start-Sleep -Seconds 6
          $v = (& gh issue view $numero -R $RepoAcceso --json state,comments 2>$null | ConvertFrom-Json)
          if ($v -and $v.state -eq 'CLOSED') {
            if ($v.comments.Count) { $respuesta = $v.comments[-1].body } else { $respuesta = '' }
            break
          }
        }
        if ($null -eq $respuesta) { Write-Host ' GitHub no ha contestado todavía. Te lo dirá en el propio pedido (te llega un correo).'; Copiar-Usuario; $parar = $true; break }
        Write-Host ''
        Write-Host ' Respuesta:' -ForegroundColor Cyan
        ($respuesta -split "`n") | Where-Object { $_ -notmatch '^\s*<!--' } | ForEach-Object { Write-Host "   $_" }
        $estado = Estado-Membresia
        # La marca oculta del comentario (<!-- acceso:x -->) dice qué pasó sin interpretar la prosa.
        if ($respuesta -match 'acceso:usada') { $parar = $true; break }   # ya explica cómo vincular un segundo aparato
        if ($estado -eq 'ninguna') {
          if ($respuesta -match 'acceso:no-vale|no vale') { Write-Host ' Prueba otra vez (comprueba la palabra con Lucas).'; continue }
          Copiar-Usuario; $parar = $true
        }
      }
      if ($estado -eq 'ninguna') { Pausa 'Pulsa Intro para cerrar'; return }
    }
    if ($estado -eq 'pending') {
      Write-Host ''
      Write-Host ' Tienes una invitación esperándote. Te abro la página: pulsa el botón verde "Join Zoolutions Lab"'
      Write-Host ' (también te ha llegado por correo). Yo espero aquí.'
      Abrir "https://github.com/orgs/$Org/invitation"
      $limite = (Get-Date).AddMinutes(20)
      while ((Get-Date) -lt $limite) {
        Start-Sleep -Seconds 5
        if ((Estado-Membresia) -eq 'active') { break }
      }
      if ((Estado-Membresia) -ne 'active') { Mal 'Sigo sin verte dentro. Acepta la invitación y vuelve a ejecutar esto.'; Pausa 'Pulsa Intro para cerrar'; return }
      Ok 'Ya estás dentro de Zoolutions Lab.'
    }
  }

  # ---------- 4. Avatar ----------
  Titulo 'Paso 4 de 5: tu avatar'
  if (-not $script:Animal) {
    $a = Read-Host ' ¿Cuál es tu animal? (Intro para saltar este paso)'
    if ($a.Trim()) { $script:Animal = (Normalizar $a) -replace ' ', '-' }
  }
  if ($script:Animal) {
    if (-not (Test-Path $Raiz)) { New-Item -ItemType Directory -Path $Raiz -Force | Out-Null }
    $avatar = Join-Path $Raiz 'mi-avatar.png'
    $b64 = (& gh api "repos/$Repo/contents/identidad/avatares/$($script:Animal).png" --jq .content 2>$null)
    if ($LASTEXITCODE -eq 0 -and $b64) {
      [IO.File]::WriteAllBytes($avatar, [Convert]::FromBase64String(($b64 -replace '\s', '')))
      Ok "Tu avatar está en  $avatar"
      Write-Host ' GitHub no deja cambiar la foto de perfil desde aquí, así que ese clic es tuyo. Te abro la página:'
      Write-Host '   1) Pulsa en la foto redonda (arriba a la izquierda) y elige "Upload a photo...".'
      Write-Host "   2) Busca la carpeta  $Raiz  y elige  mi-avatar.png."
      Write-Host '   3) Pulsa "Set new profile picture".'
      Abrir 'https://github.com/settings/profile'
      Pausa 'Cuando lo tengas (o si prefieres hacerlo luego), pulsa Intro'
    } else {
      Write-Host " Todavía no hay avatar para «$($script:Animal)» en el Zoo. No pasa nada: Lucas lo prepara y lo subes luego desde el Zoo."
    }
  } else {
    Write-Host ' Saltado. Podrás ponerte el avatar desde el Zoo más adelante.'
  }

  # ---------- 5. El Zoo ----------
  Titulo 'Paso 5 de 5: descargar el Zoo'
  if (-not (Test-Path $Raiz)) { New-Item -ItemType Directory -Path $Raiz -Force | Out-Null }
  if (Test-Path (Join-Path $Destino '.git')) {
    Write-Host ' Ya lo tenías descargado. Lo pongo al día...'
    & git -C $Destino pull --ff-only 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host ' No he podido ponerlo al día (puede que tengas cambios sin guardar). Sigo con lo que hay; díselo a tu IA al abrir el Zoo.' }
  } else {
    & gh repo view $Repo --json name 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Mal 'Todavía no tienes acceso al Zoo.'; Copiar-Usuario; Pausa 'Pulsa Intro para cerrar'; return }
    & gh repo clone $Repo $Destino 2>&1 | ForEach-Object { Write-Host "   $_" }
    if (-not (Test-Path (Join-Path $Destino '.git'))) { Mal 'No se ha podido descargar el Zoo. Haz una captura de esta ventana y mándasela a Lucas.'; Pausa 'Pulsa Intro para cerrar'; return }
  }
  Ok "El Zoo está en  $Destino"

  $lanzador = Join-Path $Destino 'Zoo.cmd'
  Write-Host ''
  Write-Host ' Ya está todo. A partir de ahora, para trabajar: abre la carpeta del Zoo y haz doble clic en  Zoo.cmd'
  if ($SinAbrir) {
    Write-Host " (modo prueba) Abriría: $lanzador"
  } elseif (Test-Path $lanzador) {
    Write-Host ' Lo abro ahora.'
    Start-Process -FilePath $lanzador -WorkingDirectory $Destino | Out-Null
  } else {
    Write-Host " (Todavía no encuentro Zoo.cmd en $Destino. Abre la carpeta y mira si está; si no, avisa a Lucas.)"
  }
  Pausa 'Pulsa Intro para cerrar esta ventana'
}

Empezar
