// Pruebas de la palabra de invitación: normalizar, hash, extraer del issue y el generador invitaciones.js.
// Se ejecutan con:  npm test   (usa node --test, sin dependencias)

import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import comun from '../acceso/comun.js';

const { normalizar, hash, extraerPalabra } = comun;
const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const script = path.join(raiz, 'invitaciones.js');

describe('normalizar', () => {
  test('quita espacios sobrantes y pasa a minúsculas', () => {
    assert.equal(normalizar('  Bisonte  '), 'bisonte');
  });
  test('quita tildes y diéresis', () => {
    assert.equal(normalizar('Pingüino'), 'pinguino');
    assert.equal(normalizar('Águila real'), 'aguila real');
  });
  test('deja un solo espacio entre palabras', () => {
    assert.equal(normalizar('ÁGUILA  \t  REAL'), 'aguila real');
  });
  test('guiones y guiones bajos cuentan como espacio (por si el animal se guarda como «aguila-real»)', () => {
    assert.equal(normalizar('aguila-real'), 'aguila real');
    assert.equal(normalizar('Aguila_Real'), 'aguila real');
  });
  test('la ñ pierde su tilde, así que se puede escribir sin ella', () => {
    assert.equal(normalizar('Ñandú'), 'nandu');
  });
  test('da igual cómo venga codificada la diéresis', () => {
    assert.equal(normalizar('pingüino'), normalizar('pingüino'));
  });
  test('lo vacío da cadena vacía', () => {
    for (const valor of [null, undefined, '', '   ']) assert.equal(normalizar(valor), '');
  });
});

describe('hash', () => {
  test('es el HMAC-SHA256 en hexadecimal de la palabra normalizada, con la sal como clave', () => {
    const esperado = createHmac('sha256', 'sal-1').update('aguila real').digest('hex');
    assert.equal(hash('  Águila Real ', 'sal-1'), esperado);
    assert.match(esperado, /^[0-9a-f]{64}$/);
  });
  test('es determinista', () => {
    assert.equal(hash('bisonte', 'sal-1'), hash('bisonte', 'sal-1'));
  });
  test('escrituras equivalentes dan el mismo hash', () => {
    assert.equal(hash('Pingüino', 'sal-1'), hash(' pinguino ', 'sal-1'));
  });
  test('cambia con otra sal y con otra palabra', () => {
    assert.notEqual(hash('bisonte', 'sal-1'), hash('bisonte', 'sal-2'));
    assert.notEqual(hash('bisonte', 'sal-1'), hash('bisonta', 'sal-1'));
  });
  test('sin sal falla, para no calcular nunca con una clave vacía', () => {
    assert.throws(() => hash('bisonte', ''), /sal/i);
    assert.throws(() => hash('bisonte', undefined), /sal/i);
  });
});

describe('extraerPalabra', () => {
  test('lee el valor del cuerpo que deja el formulario de GitHub', () => {
    assert.equal(extraerPalabra('### Palabra de invitación\n\nbisonte'), 'bisonte');
  });
  test('tolera saltos de línea de Windows y espacios alrededor', () => {
    assert.equal(extraerPalabra('### Palabra de invitación\r\n\r\n  Águila real \r\n'), 'Águila real');
  });
  test('devuelve null con «_No response_»', () => {
    assert.equal(extraerPalabra('### Palabra de invitación\n\n_No response_'), null);
  });
  test('devuelve null si no hay cuerpo, está vacío o no trae el apartado', () => {
    for (const cuerpo of [null, undefined, '', '   ', 'hola, quiero entrar', '### Otra cosa\n\nbisonte']) {
      assert.equal(extraerPalabra(cuerpo), null);
    }
  });
  test('devuelve null si el apartado está vacío y empieza otro', () => {
    assert.equal(extraerPalabra('### Palabra de invitación\n\n### Otra cosa\n\nbisonte'), null);
  });
  test('se queda con la palabra y deja las secciones siguientes', () => {
    assert.equal(extraerPalabra('### Palabra de invitación\n\nbisonte\n\n### Otra cosa\n\nx'), 'bisonte');
  });
  test('el encabezado que busca es el «label» de la plantilla', () => {
    const plantilla = fs.readFileSync(path.join(raiz, '.github', 'ISSUE_TEMPLATE', 'acceso.yml'), 'utf8');
    const etiqueta = plantilla.match(/^\s*label:\s*(.+?)\s*$/m)[1];
    assert.equal(extraerPalabra(`### ${etiqueta}\n\nbisonte`), 'bisonte');
  });
});

describe('invitaciones.js (proceso aparte)', () => {
  const SAL = 'sal-de-prueba';

  function carpetaTemporal(t) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'empezar-invitaciones-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    return dir;
  }

  function ejecutar(dir, argumentos, sal = SAL) {
    const entorno = { ...process.env };
    delete entorno.CODIGO_SAL;
    if (sal !== null) entorno.CODIGO_SAL = sal;
    const r = spawnSync(process.execPath, [script, ...argumentos], { encoding: 'utf8', env: entorno, cwd: dir });
    return { estado: r.status, salida: r.stdout, error: r.stderr };
  }

  function escribirSocios(dir, socios) {
    const ruta = path.join(dir, 'socios.json');
    fs.writeFileSync(ruta, JSON.stringify({ _nota: 'prueba', socios }, null, 2));
    return ruta;
  }

  test('crea una entrada por socio con animal, conserva lo ya usado y quita las que sobran', (t) => {
    const dir = carpetaTemporal(t);
    const socios = escribirSocios(dir, [
      { nombre: 'Pablo', usuario_github: null, animal: 'Bisonte', avatar: null },
      { nombre: 'Anto', usuario_github: null, animal: null, avatar: null },
    ]);
    const salida = path.join(dir, 'invitaciones.json');
    const huella = hash('bisonte', SAL);
    fs.writeFileSync(salida, JSON.stringify([
      { hash: huella, persona: 'Pablo', usado_por: 'pablo-gh', fecha: '2026-11-07T10:00:00.000Z' },
      { hash: 'a'.repeat(64), persona: 'Jaime', usado_por: null, fecha: null },
    ]));

    const r = ejecutar(dir, [socios, '--salida', salida]);

    assert.equal(r.estado, 0, r.error);
    const texto = fs.readFileSync(salida, 'utf8');
    assert.deepEqual(JSON.parse(texto), [
      { hash: huella, persona: 'Pablo', usado_por: 'pablo-gh', fecha: '2026-11-07T10:00:00.000Z' },
    ]);
    assert.ok(texto.startsWith('[\n  {\n    "hash"'), 'dos espacios de sangría');
    assert.ok(texto.endsWith('}\n]\n'), 'salto de línea final');
    assert.ok(!texto.includes(SAL), 'la sal no se escribe en el fichero');
    // El resumen cuenta, pero no revela ni la palabra, ni el hash, ni la sal.
    assert.match(r.salida, /1 usadas/);
    assert.match(r.salida, /Pablo/);
    for (const secreto of ['bisonte', huella, SAL]) {
      assert.ok(!r.salida.toLowerCase().includes(secreto.toLowerCase()), 'el resumen no debe revelar nada secreto');
    }
  });

  test('un animal nuevo nace sin usar', (t) => {
    const dir = carpetaTemporal(t);
    const socios = escribirSocios(dir, [{ nombre: 'Jaime', usuario_github: null, animal: 'Pingüino', avatar: null }]);
    const salida = path.join(dir, 'salida.json');

    const r = ejecutar(dir, [socios, `--salida=${salida}`]);

    assert.equal(r.estado, 0, r.error);
    assert.deepEqual(JSON.parse(fs.readFileSync(salida, 'utf8')), [
      { hash: hash('pinguino', SAL), persona: 'Jaime', usado_por: null, fecha: null },
    ]);
  });

  test('si ningún socio tiene animal, la lista queda vacía', (t) => {
    const dir = carpetaTemporal(t);
    const socios = escribirSocios(dir, [
      { nombre: 'Anto', usuario_github: null, animal: null, avatar: null },
      { nombre: 'Lucas', usuario_github: 'lucasague', animal: null, avatar: null },
    ]);
    const salida = path.join(dir, 'invitaciones.json');

    const r = ejecutar(dir, [socios, '--salida', salida]);

    assert.equal(r.estado, 0, r.error);
    assert.deepEqual(JSON.parse(fs.readFileSync(salida, 'utf8')), []);
    assert.match(r.salida, /Invitaciones: 0/);
  });

  test('sin CODIGO_SAL falla con un mensaje claro y no escribe nada', (t) => {
    const dir = carpetaTemporal(t);
    const socios = escribirSocios(dir, [{ nombre: 'Pablo', animal: 'Bisonte' }]);
    const salida = path.join(dir, 'invitaciones.json');

    const r = ejecutar(dir, [socios, '--salida', salida], null);

    assert.equal(r.estado, 1);
    assert.match(r.error, /CODIGO_SAL/);
    assert.ok(!fs.existsSync(salida));
  });

  test('dos socios con el mismo animal es un error', (t) => {
    const dir = carpetaTemporal(t);
    const socios = escribirSocios(dir, [
      { nombre: 'Pablo', animal: 'Águila real' },
      { nombre: 'Anto', animal: 'aguila-real' },
    ]);
    const salida = path.join(dir, 'invitaciones.json');

    const r = ejecutar(dir, [socios, '--salida', salida]);

    assert.equal(r.estado, 1);
    assert.match(r.error, /mismo animal/);
    assert.ok(!fs.existsSync(salida));
  });

  test('si falta socios.json lo dice y falla', (t) => {
    const dir = carpetaTemporal(t);
    const r = ejecutar(dir, [path.join(dir, 'no-existe.json'), '--salida', path.join(dir, 'x.json')]);
    assert.equal(r.estado, 1);
    assert.match(r.error, /socios\.json/);
  });
});
