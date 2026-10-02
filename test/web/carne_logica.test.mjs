import test from 'node:test';
import assert from 'node:assert/strict';
import {
  leerToken,
  tokenValido,
  formatearFecha,
  edadTexto,
  etiquetaEstado,
  aplicoTexto,
  modeloVista,
} from '../../public_carne/c/carne_logica.js';

const TOKEN = 'a1'.repeat(32);

test('leerToken acepta solo 64 hex minusculas tras #', () => {
  assert.equal(leerToken('#' + TOKEN), TOKEN);
  assert.equal(leerToken('#ABC'), null);
  assert.equal(leerToken(''), null);
  assert.equal(leerToken('#' + TOKEN + 'x'), null);
  assert.equal(leerToken(undefined), null);
  assert.equal(tokenValido(TOKEN), true);
  assert.equal(tokenValido('zz'), false);
});

test('formatearFecha y edadTexto', () => {
  assert.equal(formatearFecha('2026-10-05'), '05/10/2026');
  assert.equal(formatearFecha(null), '');
  assert.equal(edadTexto('2025-03-12', '2026-10-01'), '1 año 6 meses');
  assert.equal(edadTexto('2026-08-01', '2026-10-01'), '2 meses');
  assert.equal(edadTexto('2024-10-01', '2026-10-01'), '2 años');
});

test('etiquetaEstado', () => {
  assert.equal(etiquetaEstado('al_dia'), 'Al día');
  assert.equal(etiquetaEstado('completo'), 'Al día');
  assert.equal(etiquetaEstado('proxima'), 'Próxima');
  assert.equal(etiquetaEstado('vencida'), 'Vencida');
});

test('aplicoTexto', () => {
  assert.equal(
    aplicoTexto({ veterinario: { nombre: 'Laura Gómez', matricula: '12345' } }),
    'Aplicó: Dr(a). Laura Gómez · Mat. 12345',
  );
  assert.equal(
    aplicoTexto({ veterinario: { nombre: 'Laura Gómez', matricula: null } }),
    'Aplicó: Dr(a). Laura Gómez',
  );
  assert.equal(
    aplicoTexto({ externa: true, clinica_externa: 'Vet Sur' }),
    'Aplicada en Vet Sur',
  );
  assert.equal(aplicoTexto({ externa: true, clinica_externa: null }), 'Aplicada en otra clínica');
  assert.equal(aplicoTexto({ veterinario: null }), '');
});

const base = () => ({
  hoy: '2026-10-01',
  mascota: {
    nombre: 'Firulais',
    especie: 'perro',
    raza: 'Criollo',
    fecha_nacimiento: '2025-03-12',
    foto_url: 'https://x.supabase.co/storage/v1/o.jpg',
    foto_path: 'secreto/ruta.jpg',
  },
  propietario: 'Ana R.',
  clinica: { nombre: 'Vet Sol', ciudad: 'Cali', direccion: 'Cra 1', telefono: '300', extra: 'no' },
  biologicos: [
    { biologico_nombre: 'Rabia', tipo: 'vacuna', estado: 'al_dia', proxima_fecha: '2027-01-01', etiqueta_proxima: 'Vigente hasta' },
    { biologico_nombre: 'Parvovirus', tipo: 'vacuna', estado: 'vencida', proxima_fecha: '2026-09-01', etiqueta_proxima: 'Próxima dosis' },
    { biologico_nombre: 'Antiparasitario', tipo: 'desparasitante', estado: 'proxima', proxima_fecha: '2026-10-10', etiqueta_proxima: 'Próxima dosis' },
  ],
  dosis: [
    { biologico_nombre: 'Rabia', tipo: 'vacuna', fecha_aplicacion: '2025-01-01', etiqueta_dosis: 'Refuerzo', es_ultima: false, producto: 'A', lote: 'L1', externa: false, veterinario: { nombre: 'X', matricula: '1' } },
    { biologico_nombre: 'Rabia', tipo: 'vacuna', fecha_aplicacion: '2026-01-01', etiqueta_dosis: 'Refuerzo', es_ultima: true, producto: 'B', lote: 'L2', externa: false, veterinario: { nombre: 'X', matricula: '1' } },
    { biologico_nombre: 'Rabia', tipo: 'vacuna', fecha_aplicacion: '2025-06-01', etiqueta_dosis: 'Refuerzo', es_ultima: false, producto: 'C', lote: null, externa: true, clinica_externa: null, veterinario: null },
    { biologico_nombre: 'Parvovirus', tipo: 'vacuna', fecha_aplicacion: '2025-09-01', etiqueta_dosis: '1/3', es_ultima: true, producto: null, lote: null, externa: false, veterinario: null },
    { biologico_nombre: 'Antiparasitario', tipo: 'desparasitante', fecha_aplicacion: '2026-09-10', etiqueta_dosis: 'Dosis', es_ultima: true, producto: null, lote: null, externa: false, veterinario: null },
  ],
});

test('modeloVista agrupa, ordena y toma el peor estado', () => {
  const m = modeloVista(base());
  assert.equal(m.vacio, false);
  assert.deepEqual(m.grupos.map((g) => g.nombre), ['Parvovirus', 'Antiparasitario', 'Rabia']);
  assert.equal(m.estadoGeneral, 'vencida');
  const rabia = m.grupos[2];
  assert.equal(rabia.dosis[0].fecha, '01/01/2026');
  assert.equal(rabia.dosis[0].vigente, true);
  assert.deepEqual(rabia.dosis.slice(1).map((d) => d.fecha), ['01/06/2025', '01/01/2025']);
  assert.equal(rabia.dosis[1].externa, true);
  assert.equal(rabia.dosis[1].aplico, 'Aplicada en otra clínica');
  assert.equal(m.mascota.nombre, 'Firulais');
  assert.equal(m.mascota.edad, '1 año 6 meses');
});

test('modeloVista no expone claves fuera del contrato', () => {
  const m = modeloVista(base());
  const txt = JSON.stringify(m);
  assert.ok(!txt.includes('foto_path'));
  assert.ok(!txt.includes('secreto'));
  assert.ok(!txt.includes('"extra"'));
  assert.deepEqual(Object.keys(m.clinica).sort(), [
    'ciudad',
    'direccion',
    'logoUrl',
    'nombre',
    'telefono',
  ]);
});

test('modeloVista expone clinica.logoUrl y nunca logo_path', () => {
  const j = base();
  j.clinica.logo_url = 'https://x.supabase.co/storage/v1/object/sign/clinica-logos/a?token=t';
  j.clinica.logo_path = 'secreto/logo-1234567890.jpg';
  const m = modeloVista(j);
  assert.equal(m.clinica.logoUrl, j.clinica.logo_url);
  const txt = JSON.stringify(m);
  assert.ok(!txt.includes('logo_path'));
  assert.ok(!txt.includes('logo-1234567890'));
});

test('modeloVista logoUrl vacio si falta o no es string', () => {
  assert.equal(modeloVista(base()).clinica.logoUrl, '');
  const j = base();
  j.clinica.logo_url = 42;
  assert.equal(modeloVista(j).clinica.logoUrl, '');
  j.clinica.logo_url = null;
  assert.equal(modeloVista(j).clinica.logoUrl, '');
});

test('modeloVista sin dosis marca vacio', () => {
  const j = base();
  j.dosis = [];
  j.biologicos = [];
  assert.equal(modeloVista(j).vacio, true);
});
