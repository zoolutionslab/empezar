# empezar

La primera instalación de cada socio de Zoolutions Lab: https://zoolutionslab.github.io/empezar/

Solo se pasa por aquí una vez por persona y ordenador. Deja instalados Git, Node.js, GitHub CLI y Claude Code; entra en GitHub; pide el acceso a la organización con la **palabra de invitación** (el animal de cada socio, de un solo uso); prepara el avatar; descarga el Zoo (`zoolutionslab/zoo`) en `~/Zoolutions/zoo` y lo abre.

## Ficheros

- `index.html`: la página, con el estilo de Zoolutions. Botones Windows / Mac con la línea para copiar.
- `empezar.ps1`: Windows. `irm https://zoolutionslab.github.io/empezar/empezar.ps1 | iex` en PowerShell.
- `empezar.sh`: Mac. `bash <(curl -fsSL https://zoolutionslab.github.io/empezar/empezar.sh)` en Terminal.
- `empezar.cmd`: Windows, para quien prefiere descargar un fichero (lanza la misma línea). Va con CRLF (`.gitattributes: *.cmd -text`).
- `acceso/comun.js`, `.github/workflows/acceso.yml`, `.github/ISSUE_TEMPLATE/acceso.yml`, `invitaciones.json`, `invitaciones.js`: la palabra de invitación. Cómo se activa: `docs/activar-acceso-automatico.md`.
- `probar.ps1` / `probar.sh`: ejecutan el script en modo prueba (carpeta temporal, sin instalar ni abrir nada).

## Probar sin efectos

Variables que entienden los dos scripts: `EMPEZAR_RAIZ` (carpeta destino en vez de `~/Zoolutions`), `EMPEZAR_SIN_INSTALAR=1`, `EMPEZAR_SIN_ABRIR=1`, `EMPEZAR_SIN_PAUSAS=1`, `EMPEZAR_REPO` (otro repositorio en vez de `zoolutionslab/zoo`).

```
npm test            # pruebas del mecanismo de acceso
bash -n empezar.sh  # sintaxis
./probar.sh         # Mac / Git Bash: ejecución en seco
.\probar.ps1        # Windows: ejecución en seco
```

Comprobar lo publicado: `curl -s https://zoolutionslab.github.io/empezar/empezar.cmd | file -` tiene que decir «CRLF».

## Cómo funciona todo

El recorrido completo (de aquí al Zoo y a la Fábrica) está en `docs/como-funciona.md` del repositorio `zoolutionslab/zoo`.
