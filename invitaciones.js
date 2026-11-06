#!/usr/bin/env node
'use strict';

// Genera invitaciones.json: la lista (pública) de palabras de invitación en forma de hash.
//
//   node invitaciones.js <ruta a socios.json> [--salida invitaciones.json]
//
// socios.json es identidad/socios.json del repositorio privado zoolutionslab/zoo.
// Cada socio con «animal» recibe una entrada. La sal sale SOLO de la variable de
// entorno CODIGO_SAL y no se escribe en ningún fichero. Mira docs/activar-acceso-automatico.md.

const fs = require('node:fs');
const path = require('node:path');
const { hash, normalizar } = require('./acceso/comun.js');

const AYUDA = [
  'Uso: node invitaciones.js <ruta a socios.json> [--salida invitaciones.json]',
  '',
  'Hace falta la variable de entorno CODIGO_SAL (la sal secreta).',
  'Si no indicas --salida, escribe invitaciones.json junto a este script.',
].join('\n');

class ErrorDeUso extends Error {}

function leerArgumentos(argumentos) {
  let socios = null;
  let salida = null;
  for (let i = 0; i < argumentos.length; i++) {
    const a = argumentos[i];
    if (a === '-h' || a === '--help') return { ayuda: true };
    if (a === '--salida') {
      salida = argumentos[++i];
      if (!salida) throw new ErrorDeUso('Después de --salida hay que poner la ruta del fichero.');
    } else if (a.startsWith('--salida=')) {
      salida = a.slice('--salida='.length);
    } else if (a.startsWith('-')) {
      throw new ErrorDeUso(`No conozco la opción ${a}.\n\n${AYUDA}`);
    } else if (socios === null) {
      socios = a;
    } else {
      throw new ErrorDeUso(`Sobra el argumento ${a}.\n\n${AYUDA}`);
    }
  }
  if (socios === null) throw new ErrorDeUso(`Falta la ruta a socios.json.\n\n${AYUDA}`);
  return {
    socios: path.resolve(socios),
    salida: salida ? path.resolve(salida) : path.join(__dirname, 'invitaciones.json'),
  };
}

function leerJson(ruta, que) {
  let texto;
  try {
    texto = fs.readFileSync(ruta, 'utf8');
  } catch (error) {
    throw new ErrorDeUso(`No puedo leer ${que} (${ruta}): ${error.message}`);
  }
  try {
    return JSON.parse(texto.replace(/^﻿/, ''));
  } catch (error) {
    throw new ErrorDeUso(`${que} (${ruta}) no es un JSON válido: ${error.message}`);
  }
}

// Devuelve las entradas nuevas, conservando usado_por/fecha de las que ya existían con el mismo
// hash, y quita las que ya no corresponden a ningún socio.
function generar(socios, sal, previas) {
  const conservadas = new Map();
  for (const e of previas) {
    if (e && typeof e.hash === 'string') conservadas.set(e.hash, e);
  }
  const vistos = new Map(); // hash -> nombre, para no aceptar dos socios con el mismo animal
  const entradas = [];
  const sinAnimal = [];
  for (const socio of socios) {
    const nombre = socio && typeof socio.nombre === 'string' ? socio.nombre.trim() : '';
    if (!nombre) throw new ErrorDeUso('Hay un socio sin nombre en socios.json.');
    if (!normalizar(socio.animal)) {
      sinAnimal.push(nombre);
      continue;
    }
    const h = hash(socio.animal, sal);
    if (vistos.has(h)) {
      throw new ErrorDeUso(`${vistos.get(h)} y ${nombre} tienen el mismo animal: cada animal tiene que ser distinto.`);
    }
    vistos.set(h, nombre);
    const previa = conservadas.get(h);
    entradas.push({
      hash: h,
      persona: nombre,
      usado_por: previa && previa.usado_por ? previa.usado_por : null,
      fecha: previa && previa.fecha ? previa.fecha : null,
    });
  }
  const quitadas = [...conservadas.values()]
    .filter((e) => !vistos.has(e.hash))
    .map((e) => (typeof e.persona === 'string' && e.persona ? e.persona : '(sin nombre)'));
  return { entradas, sinAnimal, quitadas };
}

function main() {
  const args = leerArgumentos(process.argv.slice(2));
  if (args.ayuda) {
    console.log(AYUDA);
    return;
  }
  const sal = process.env.CODIGO_SAL;
  if (!sal) {
    throw new ErrorDeUso(
      'Falta la variable de entorno CODIGO_SAL (la sal secreta).\n' +
        'En PowerShell:  $env:CODIGO_SAL = "la-sal"; node invitaciones.js <socios.json>\n' +
        'En Mac o Linux:  CODIGO_SAL="la-sal" node invitaciones.js <socios.json>\n' +
        'Cómo se crea la sal: docs/activar-acceso-automatico.md'
    );
  }

  const datos = leerJson(args.socios, 'socios.json');
  const socios = Array.isArray(datos) ? datos : datos && datos.socios;
  if (!Array.isArray(socios)) {
    throw new ErrorDeUso('socios.json tiene que tener la forma { "socios": [ ... ] }.');
  }

  let previas = [];
  if (fs.existsSync(args.salida)) {
    previas = leerJson(args.salida, 'invitaciones.json');
    if (!Array.isArray(previas)) {
      throw new ErrorDeUso(`${args.salida} tiene que ser una lista. No lo toco para no perder lo ya usado.`);
    }
  }

  const { entradas, sinAnimal, quitadas } = generar(socios, sal, previas);
  fs.writeFileSync(args.salida, JSON.stringify(entradas, null, 2) + '\n');

  // Resumen: solo nombres de personas, nunca las palabras ni los hashes.
  const usadas = entradas.filter((e) => e.usado_por);
  console.log(`Invitaciones: ${entradas.length} (${usadas.length} usadas, ${entradas.length - usadas.length} sin usar).`);
  for (const e of entradas) {
    console.log(`  ${e.persona}: ${e.usado_por ? `usada por @${e.usado_por} el ${e.fecha || 'fecha desconocida'}` : 'sin usar'}`);
  }
  if (entradas.length === 0) console.log('Ningún socio tiene animal todavía: la lista queda vacía.');
  if (sinAnimal.length) console.log(`Sin animal: ${sinAnimal.join(', ')}.`);
  if (quitadas.length) console.log(`Quitadas por no coincidir ya con ningún socio: ${quitadas.join(', ')}.`);
  console.log(`Escrito en ${args.salida}`);
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    if (!(error instanceof ErrorDeUso)) throw error;
    console.error(`Error: ${error.message}`);
    process.exitCode = 1;
  }
}

module.exports = { generar };
