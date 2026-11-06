// Prueba del script que lleva el workflow .github/workflows/acceso.yml, sin tocar GitHub.
// Se saca el texto del script del propio YAML y se ejecuta con una GitHub y una API de mentira,
// para comprobar cada camino: qué contesta, cómo cierra el issue y qué llamadas hace.

import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import comun from '../acceso/comun.js';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const requerir = createRequire(import.meta.url);
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

const SAL = 'sal-de-prueba';
const TOKEN = 'token-de-prueba';
const PALABRA = 'bisonte';
const HUELLA = comun.hash(PALABRA, SAL);
const CUERPO = (palabra) => `### Palabra de invitación\n\n${palabra}`;
const URL_ISSUE = 'https://github.com/zoolutionslab/empezar/issues/7';

// Texto del script de actions/github-script tal como está en el YAML.
function scriptDelWorkflow() {
  const lineas = fs.readFileSync(path.join(raiz, '.github', 'workflows', 'acceso.yml'), 'utf8').replace(/\r\n/g, '\n').split('\n');
  const inicio = lineas.findIndex((l) => /^\s+script: \|\s*$/.test(l));
  assert.notEqual(inicio, -1, 'no encuentro el script dentro del workflow');
  const sangriaClave = lineas[inicio].match(/^\s*/)[0].length;
  const cuerpo = [];
  for (const l of lineas.slice(inicio + 1)) {
    if (l.trim() !== '' && l.match(/^\s*/)[0].length <= sangriaClave) break;
    cuerpo.push(l);
  }
  const quitar = cuerpo.find((l) => l.trim() !== '').match(/^\s*/)[0].length;
  return cuerpo.map((l) => l.slice(quitar)).join('\n');
}

// Ejecuta el script con un issue y un estado de GitHub inventados y devuelve lo que ha pasado.
async function ejecutar(opciones = {}) {
  const {
    cuerpo = CUERPO(PALABRA),
    login = 'nuevo-socio',
    secretos = { CODIGO_SAL: SAL, ORG_TOKEN: TOKEN },
    lista = [{ hash: HUELLA, persona: 'Pablo', usado_por: null, fecha: null }],
    miembro = 404,
    anteriores = 0,
    equipo = { status: 200, body: { id: 20566079, slug: 'socios' } },
    invitacion = { status: 201, body: { id: 1 } },
    pendientes = [],
    pushFalla = false,
  } = opciones;

  const espacio = fs.mkdtempSync(path.join(os.tmpdir(), 'acceso-flujo-'));
  try {
    fs.mkdirSync(path.join(espacio, 'acceso'));
    fs.copyFileSync(path.join(raiz, 'acceso', 'comun.js'), path.join(espacio, 'acceso', 'comun.js'));
    const rutaLista = path.join(espacio, 'invitaciones.json');
    const textoInicial = JSON.stringify(lista, null, 2) + '\n';
    fs.writeFileSync(rutaLista, textoInicial);

    const r = { comentarios: [], cierres: [], peticiones: [], busquedas: [], git: [], errores: [], fallos: [], orden: [] };
    const github = {
      rest: {
        issues: {
          createComment: async (p) => { r.comentarios.push(p.body); },
          update: async (p) => { r.cierres.push({ estado: p.state, razon: p.state_reason }); },
        },
      },
      request: async (ruta, p) => {
        r.busquedas.push(p.q);
        const previos = Array.from({ length: anteriores }, (_, i) => ({ number: 100 + i }));
        return { data: { items: [...previos, { number: 7 }] } }; // el propio issue sale también en la búsqueda
      },
    };
    const fetchFalso = async (url, op = {}) => {
      const ruta = url.replace('https://api.github.com', '');
      r.peticiones.push({ metodo: op.method, ruta, cabeceras: op.headers, cuerpo: op.body ? JSON.parse(op.body) : null });
      let res;
      if (op.method === 'GET' && ruta.startsWith('/orgs/zoolutionslab/members/')) res = { status: miembro };
      else if (op.method === 'GET' && ruta === '/orgs/zoolutionslab/teams/socios') res = equipo;
      else if (op.method === 'POST' && ruta === '/orgs/zoolutionslab/invitations') { r.orden.push('invitar'); res = invitacion; }
      else if (op.method === 'GET' && ruta.startsWith('/orgs/zoolutionslab/invitations')) res = { status: 200, body: pendientes };
      else throw new Error(`Petición inesperada: ${op.method} ${ruta}`);
      return { status: res.status, text: async () => (res.body === undefined ? '' : JSON.stringify(res.body)) };
    };
    const requireFalso = (modulo) => {
      if (modulo !== 'child_process') return requerir(modulo);
      return {
        execFileSync: (orden, args) => {
          assert.equal(orden, 'git');
          r.git.push(args.join(' '));
          if (args[0] === 'push') {
            r.orden.push('push');
            if (pushFalla) throw new Error('Command failed: git push origin HEAD:main');
          }
          return '';
        },
      };
    };
    const contexto = {
      repo: { owner: 'zoolutionslab', repo: 'empezar' },
      payload: { issue: { number: 7, body: cuerpo, html_url: URL_ISSUE, user: { login, id: 4242 } } },
    };
    const core = { error: (m) => r.errores.push(String(m)), setFailed: (m) => r.fallos.push(String(m)) };
    const proceso = { env: { GITHUB_WORKSPACE: espacio, CODIGO_SAL: secretos.CODIGO_SAL, ORG_TOKEN: secretos.ORG_TOKEN } };

    const funcion = new AsyncFunction('github', 'context', 'core', 'require', 'process', 'fetch', scriptDelWorkflow());
    await funcion(github, contexto, core, requireFalso, proceso, fetchFalso);

    r.lista = JSON.parse(fs.readFileSync(rutaLista, 'utf8'));
    r.textoLista = fs.readFileSync(rutaLista, 'utf8');
    r.listaIntacta = r.textoLista === textoInicial;
    // Nunca deben salir a la vista la palabra, su hash, la sal ni el token.
    const todoLoVisible = [...r.comentarios, ...r.errores, ...r.fallos].join('\n').toLowerCase();
    for (const secreto of [PALABRA, HUELLA, SAL, TOKEN]) {
      assert.ok(!todoLoVisible.includes(secreto.toLowerCase()), 'se ha colado un secreto en un comentario o en el registro');
    }
    return r;
  } finally {
    fs.rmSync(espacio, { recursive: true, force: true });
  }
}

describe('workflow de acceso', () => {
  test('sin secretos: modo manual, pide el usuario y no llama a nadie', async () => {
    for (const secretos of [{ CODIGO_SAL: '', ORG_TOKEN: TOKEN }, { CODIGO_SAL: SAL, ORG_TOKEN: '' }, { CODIGO_SAL: '', ORG_TOKEN: '' }]) {
      const r = await ejecutar({ secretos });
      assert.equal(r.comentarios.length, 1);
      assert.match(r.comentarios[0], /todavía no está activado/);
      assert.match(r.comentarios[0], /`@nuevo-socio`/);
      assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
      assert.equal(r.peticiones.length, 0);
      assert.equal(r.git.length, 0);
      assert.equal(r.fallos.length, 0);
    }
  });

  test('si ya es miembro, lo dice, cierra como completado y no hace nada más', async () => {
    const r = await ejecutar({ miembro: 204 });
    assert.match(r.comentarios[0], /Ya eres del Zoo/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'completed' }]);
    assert.equal(r.peticiones.length, 1);
    assert.equal(r.busquedas.length, 0);
    assert.equal(r.git.length, 0);
  });

  test('tope diario: con 5 issues anteriores hoy no comprueba nada', async () => {
    const r = await ejecutar({ anteriores: 5 });
    assert.match(r.comentarios[0], /Demasiados intentos hoy; pídele a Lucas que te meta/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
    assert.ok(r.peticiones.every((p) => !p.ruta.includes('invitations') && !p.ruta.includes('teams')));
    assert.equal(r.git.length, 0);
    const hoy = new Date().toISOString().slice(0, 10);
    assert.match(r.busquedas[0], new RegExp(`repo:zoolutionslab/empezar is:issue author:nuevo-socio created:>=${hoy}`));
  });

  test('tope diario: con 4 anteriores (y el actual, el quinto) todavía se atiende', async () => {
    const r = await ejecutar({ anteriores: 4 });
    assert.match(r.comentarios[0], /Invitación enviada/);
  });

  test('sin palabra en el cuerpo: lo dice y cierra', async () => {
    for (const cuerpo of ['### Palabra de invitación\n\n_No response_', '', 'hola']) {
      const r = await ejecutar({ cuerpo });
      assert.match(r.comentarios[0], /No encuentro tu palabra/);
      assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
      assert.equal(r.git.length, 0);
    }
  });

  test('palabra que no está en la lista: «no vale», sin invitar ni gastar nada', async () => {
    const r = await ejecutar({ cuerpo: CUERPO('canguro') });
    assert.match(r.comentarios[0], /Esa palabra no vale/);
    assert.match(r.comentarios[0], /`@nuevo-socio`/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
    assert.equal(r.git.length, 0);
    assert.ok(r.peticiones.every((p) => p.metodo === 'GET' && !p.ruta.includes('teams')));
    assert.ok(r.listaIntacta);
  });

  test('lista vacía: todo es «no vale»', async () => {
    const r = await ejecutar({ lista: [] });
    assert.match(r.comentarios[0], /Esa palabra no vale/);
  });

  test('palabra ya usada por otra cuenta: no invita', async () => {
    const lista = [{ hash: HUELLA, persona: 'Pablo', usado_por: 'otra-persona', fecha: '2026-11-07T10:00:00.000Z' }];
    const r = await ejecutar({ lista });
    assert.match(r.comentarios[0], /otro aparato[^]*segundo aparato[^]*pídele a Lucas la tuya/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
    assert.equal(r.git.length, 0);
    assert.ok(r.listaIntacta);
  });

  test('palabra válida: la marca usada, sube el commit y DESPUÉS invita al equipo', async () => {
    const r = await ejecutar({ cuerpo: CUERPO('  BISONTE ') });
    assert.match(r.comentarios[0], /Invitación enviada\. Acéptala en https:\/\/github\.com\/orgs\/zoolutionslab\/invitation/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'completed' }]);
    assert.equal(r.comentarios.length, 1);
    assert.equal(r.fallos.length, 0);
    assert.deepEqual(r.git, [
      'config user.name zoolutionslab-bot',
      'config user.email bot@zoolutionslab.com',
      'add invitaciones.json',
      'commit -m chore: invitación usada por nuevo-socio',
      'pull --rebase origin main',
      'push origin HEAD:main',
    ]);
    assert.equal(r.lista[0].usado_por, 'nuevo-socio');
    assert.match(r.lista[0].fecha, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    assert.ok(r.textoLista.startsWith('[\n  {\n    "hash"') && r.textoLista.endsWith('}\n]\n'));
    const invitar = r.peticiones.find((p) => p.metodo === 'POST');
    assert.deepEqual(invitar.cuerpo, { invitee_id: 4242, role: 'direct_member', team_ids: [20566079] });
    assert.equal(invitar.cabeceras.Authorization, `Bearer ${TOKEN}`);
    assert.equal(invitar.cabeceras['X-GitHub-Api-Version'], '2022-11-28');
    assert.deepEqual(r.orden, ['push', 'invitar']);
  });

  test('si GitHub dice que ya tenía una invitación pendiente (422), cuenta como éxito', async () => {
    const r = await ejecutar({ invitacion: { status: 422, body: { message: 'Validation Failed' } }, pendientes: [{ login: 'Nuevo-Socio' }] });
    assert.match(r.comentarios[0], /Invitación enviada/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'completed' }]);
    assert.equal(r.fallos.length, 0);
  });

  test('un 422 sin invitación pendiente es un fallo, no un éxito', async () => {
    const r = await ejecutar({ invitacion: { status: 422, body: { message: 'Validation Failed' } }, pendientes: [{ login: 'otro' }] });
    assert.match(r.comentarios[0], /Algo ha fallado al comprobar tu palabra/);
    assert.ok(r.comentarios[0].includes(URL_ISSUE));
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
    assert.equal(r.fallos.length, 1);
  });

  test('la misma cuenta que ya la usó puede repetir: se reenvía la invitación sin tocar el fichero', async () => {
    const lista = [{ hash: HUELLA, persona: 'Pablo', usado_por: 'Nuevo-Socio', fecha: '2026-11-07T10:00:00.000Z' }];
    const r = await ejecutar({ lista });
    assert.match(r.comentarios[0], /Invitación enviada/);
    assert.equal(r.git.length, 0);
    assert.ok(r.listaIntacta);
    assert.deepEqual(r.orden, ['invitar']);
  });

  test('si falla subir el commit no se invita a nadie', async () => {
    const r = await ejecutar({ pushFalla: true });
    assert.match(r.comentarios[0], /Algo ha fallado al comprobar tu palabra/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
    assert.ok(!r.orden.includes('invitar'));
    assert.equal(r.fallos.length, 1);
  });

  test('si no se puede leer el equipo, falla antes de marcar nada', async () => {
    const r = await ejecutar({ equipo: { status: 404, body: { message: 'Not Found' } } });
    assert.match(r.comentarios[0], /Algo ha fallado/);
    assert.equal(r.git.length, 0);
    assert.ok(r.listaIntacta);
    assert.match(r.errores[0], /equipo socios.*404/);
  });

  test('con un token malo (401) falla con un aviso claro y deja el trabajo en rojo', async () => {
    const r = await ejecutar({ miembro: 401 });
    assert.match(r.comentarios[0], /Algo ha fallado al comprobar tu palabra; mándale a Lucas tu usuario `@nuevo-socio`/);
    assert.deepEqual(r.cierres, [{ estado: 'closed', razon: 'not_planned' }]);
    assert.equal(r.fallos.length, 1);
  });
});
