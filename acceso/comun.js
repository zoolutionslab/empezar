'use strict';

// Piezas comunes del acceso por palabra de invitación (sin dependencias).
// Las usan el workflow .github/workflows/acceso.yml y el generador invitaciones.js.
// Las dos tienen que normalizar la palabra y calcular el hash exactamente igual,
// por eso viven en un solo sitio.

const crypto = require('node:crypto');

// Deja la palabra en una forma única: minúsculas, sin tildes ni diéresis y con un
// solo espacio entre palabras. «  Águila   Real », «aguila-real» y «AGUILA REAL»
// dan todas «aguila real». La ñ también pierde su tilde («ñandú» -> «nandu»), así
// que quien no sepa escribir una tilde en el teclado entra igual.
function normalizar(palabra) {
  if (palabra === null || palabra === undefined) return '';
  return String(palabra)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[\s_-]+/g, ' ')
    .trim();
}

// HMAC-SHA256 en hexadecimal de la palabra ya normalizada, con la sal como clave.
// Sin la sal (el secreto CODIGO_SAL) no se puede probar palabras contra la lista pública.
function hash(palabra, sal) {
  if (typeof sal !== 'string' || sal === '') {
    throw new Error('Falta la sal (CODIGO_SAL) para calcular el hash.');
  }
  return crypto.createHmac('sha256', sal).update(normalizar(palabra), 'utf8').digest('hex');
}

// El formulario de GitHub (.github/ISSUE_TEMPLATE/acceso.yml) deja el cuerpo así:
//
//   ### Palabra de invitación
//
//   <lo que escribió la persona>
//
// Devuelve ese valor, o null si no está, está vacío o GitHub puso «_No response_».
// El texto del encabezado tiene que coincidir con el «label» del formulario
// (lo comprueba una prueba).
const ENCABEZADO = /^#{1,6}\s+Palabra de invitaci[oó]n\s*$/i;

function extraerPalabra(cuerpoIssue) {
  if (typeof cuerpoIssue !== 'string') return null;
  const lineas = cuerpoIssue.replace(/\r\n?/g, '\n').split('\n');
  const inicio = lineas.findIndex((linea) => ENCABEZADO.test(linea.trim()));
  if (inicio === -1) return null;
  for (let i = inicio + 1; i < lineas.length; i++) {
    const linea = lineas[i].trim();
    if (linea === '') continue;
    if (linea.startsWith('#')) return null; // empieza otra sección sin haber valor
    return /^_no response_$/i.test(linea) ? null : linea;
  }
  return null;
}

module.exports = { normalizar, hash, extraerPalabra };
