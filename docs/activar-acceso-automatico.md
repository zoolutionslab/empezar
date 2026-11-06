# Activar el acceso automático

Para Lucas. Mientras no hagas esto, el acceso funciona en modo manual: quien abre un «Acceso al Zoo» recibe un mensaje que le pide mandarte su usuario de GitHub, y tú lo metes a mano.

## Cómo funciona

1. Cada socio es un animal, y el nombre de su animal es su **palabra de invitación**. Vale una sola vez.
2. `empezar` pide la palabra y abre un issue en `zoolutionslab/empezar` con la plantilla «Acceso al Zoo».
3. El workflow `.github/workflows/acceso.yml` (se llama «Acceso») lee la palabra, la normaliza (minúsculas, sin tildes ni diéresis, sin espacios de más) y calcula su huella con la sal secreta. La busca en `invitaciones.json`, que solo guarda huellas, nunca palabras.
4. Si vale y no está usada, la marca como usada con un commit, invita a esa persona a la organización `zoolutionslab` (equipo `socios`) y cierra el issue con un comentario. La persona acepta en https://github.com/orgs/zoolutionslab/invitation y vuelve a `empezar`.

Hacen falta dos secretos en el repositorio: `CODIGO_SAL` y `ORG_TOKEN`. Si falta cualquiera de los dos, el workflow no invita a nadie y se limita a pedir el usuario de GitHub.

Necesitas `gh` con tu sesión iniciada y Node. Todo lo que sigue se hace desde `C:\Users\lucas\proyectos\zoolutions-empezar`.

## 1. La sal

Es la clave secreta con la que se calculan las huellas. Créala una vez:

```
node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
```

Copia lo que sale (48 letras y números) y guárdalo en tu gestor de contraseñas: GitHub no deja volver a verlo y lo necesitas en el paso 3. Después:

```
gh secret set CODIGO_SAL -R zoolutionslab/empezar
```

`gh` te pide el valor: pégalo y pulsa Intro (no se ve lo que pegas).

## 2. El token de la organización

Es el permiso con el que el workflow invita en tu nombre. Las invitaciones saldrán a nombre de `lucasague`.

1. Entra en https://github.com/settings/personal-access-tokens/new (es: tu foto arriba a la derecha, **Settings**, abajo del todo **Developer settings**, **Personal access tokens**, **Fine-grained tokens**, **Generate new token**).
2. **Token name**: `Acceso Zoolutions`.
3. **Resource owner**: elige `zoolutionslab` (no `lucasague`). Si la organización no aparece en la lista, aún no admite tokens de grano fino: en la organización, **Settings**, **Personal access tokens**, **Settings**, y permite los de grano fino.
4. **Expiration**: un año es lo razonable. Apúntalo en la agenda para renovarlo antes.
5. **Repository access**: **Public repositories**. No hace falta ningún repositorio.
6. **Permissions**: despliega **Organization permissions**, busca **Members** y pon **Read and write**. No marques nada más.
7. Pulsa **Generate token** y copia el token (empieza por `github_pat_`; solo se muestra ahora).
8. Guárdalo en el repositorio:

```
gh secret set ORG_TOKEN -R zoolutionslab/empezar
```

Pega el token y pulsa Intro.

Si la organización exige aprobar los tokens de grano fino, el tuyo quedará «pendiente»: se aprueba en la organización, **Settings**, **Personal access tokens**, **Pending requests**.

## 3. La lista de palabras

`invitaciones.json` se genera desde `identidad/socios.json` del repositorio privado `zoolutionslab/zoo`: una entrada por cada socio que tenga `animal`. En PowerShell, con la misma sal del paso 1:

```
$env:CODIGO_SAL = "la-sal-del-paso-1"
node invitaciones.js C:\Users\lucas\proyectos\zoolutions-zoo\identidad\socios.json
Remove-Item Env:CODIGO_SAL
git add invitaciones.json
git commit -m "chore: lista de invitaciones"
git push
```

(En Mac o Linux: `CODIGO_SAL="la-sal" node invitaciones.js ruta/a/socios.json`.)

El resumen que imprime dice cuántas invitaciones hay y cuáles están usadas, sin revelar ninguna palabra. La sal no se escribe en ningún fichero. El fichero `invitaciones.json` es público: lleva el nombre de pila de cada socio, la huella de su palabra y, cuando se usa, el usuario de GitHub de quien la usó.

Hoy ningún socio tiene `animal` en `socios.json`, así que el resultado es una lista vacía (`[]`). Mientras esté vacía, el workflow responde «Esa palabra no vale» a todo el mundo, aunque los secretos estén bien puestos.

## 4. Probarlo

1. Con tu cuenta (que ya está en la organización) abre https://github.com/zoolutionslab/empezar/issues/new/choose, elige «Acceso al Zoo», escribe cualquier cosa en «Palabra de invitación» y pulsa **Submit new issue**.
2. En medio minuto el issue se cierra solo con un comentario. Lo esperado es «Ya estás dentro de la organización…». Eso prueba que el workflow arranca, que están los dos secretos y que el token puede leer la organización.
   - «El acceso automático todavía no está activado»: falta algún secreto o su nombre está mal escrito (tienen que ser exactamente `CODIGO_SAL` y `ORG_TOKEN`).
   - «Algo ha fallado…»: abre la pestaña **Actions**, la última ejecución de «Acceso» y lee el error. Casi siempre es el token (sin el permiso «Members», sin aprobar o caducado).
3. Para ver la parte de la palabra hace falta una cuenta de GitHub que **no** esté en la organización (una de prueba, o la de un socio). Con una palabra inventada tiene que contestar «Esa palabra no vale…». Con una palabra real invita de verdad y la marca como usada (para repetirlo, mira el apartado siguiente).

## 5. Después: cambios y problemas

**Reponer una palabra usada** (por una prueba o para que alguien repita): abre `invitaciones.json`, busca la entrada con el `"persona"` que toque y pon `"usado_por": null` y `"fecha": null`. Commit y push.

**Cambiar el animal de un socio, o añadir un socio**: cambia `socios.json` y repite el paso 3. Las entradas que ya existían conservan su estado de «usada»; la del animal cambiado desaparece y nace una nueva sin usar. No cambies la sal si no es imprescindible: todas las huellas cambiarían y se perdería qué palabras estaban usadas.

**La misma persona repite su palabra**: si la cuenta que ya usó una palabra la escribe otra vez (porque no vio el aviso o la invitación caducó, a los siete días), se le vuelve a enviar la invitación. Otra cuenta distinta recibe «Esa palabra ya se usó».

**Un issue que se queda abierto sin respuesta**: si llegan tres o más a la vez, GitHub descarta el del medio. Abre **Actions**, entra en la ejecución cancelada y pulsa **Re-run all jobs**.

**Si el token caduca** (cada año): todos los intentos acaban en «Algo ha fallado…» y la ejecución sale en rojo. Repite el paso 2 con un token nuevo.

**Si algún día proteges la rama `main`**: el workflow tiene que poder subir el commit que marca la palabra como usada. Permite que se salte la protección, o dejará de funcionar.

## Seguridad, en corto

- Los dos secretos (la sal y el token) no van nunca en un fichero, un issue ni un chat.
- Un animal es fácil de adivinar. Lo que lo hace aguantar: cada palabra vale una vez, una misma cuenta no puede abrir más de cinco issues al día y, sin la sal, nadie puede probar palabras contra la lista pública sin pasar por un issue.
- Aun así, de vez en cuando mira https://github.com/orgs/zoolutionslab/people (miembros e invitaciones pendientes) y comprueba que son quienes tienen que ser.
