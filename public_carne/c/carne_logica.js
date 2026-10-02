// Logica pura del carne publico: sin DOM, sin fetch. Probada con node:test.
// El modelo de vista se construye campo a campo para que ninguna clave
// inesperada del JSON llegue a la pagina.

const TOKEN_RE = /^[0-9a-f]{64}$/;

export function tokenValido(t) {
  return typeof t === 'string' && TOKEN_RE.test(t);
}

/** Lee el token del fragmento (#<64 hex>); null si no es valido. */
export function leerToken(hash) {
  if (typeof hash !== 'string' || !hash.startsWith('#')) return null;
  const t = hash.slice(1);
  return tokenValido(t) ? t : null;
}

/** 'yyyy-mm-dd' -> 'dd/mm/aaaa'. */
export function formatearFecha(iso) {
  if (typeof iso !== 'string') return '';
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : '';
}

/** Edad legible entre dos fechas ISO. */
export function edadTexto(nacimiento, hoy) {
  const n = /^(\d{4})-(\d{2})-(\d{2})/.exec(nacimiento ?? '');
  const h = /^(\d{4})-(\d{2})-(\d{2})/.exec(hoy ?? '');
  if (!n || !h) return '';
  let meses = (Number(h[1]) - Number(n[1])) * 12 + (Number(h[2]) - Number(n[2]));
  if (Number(h[3]) < Number(n[3])) meses -= 1;
  if (meses < 0) return '';
  const anios = Math.floor(meses / 12);
  const resto = meses % 12;
  const partes = [];
  if (anios > 0) partes.push(anios === 1 ? '1 año' : `${anios} años`);
  if (resto > 0 || anios === 0) partes.push(resto === 1 ? '1 mes' : `${resto} meses`);
  return partes.join(' ');
}

export function etiquetaEstado(estado) {
  if (estado === 'vencida') return 'Vencida';
  if (estado === 'proxima') return 'Próxima';
  return 'Al día';
}

/** Linea de autoria de la dosis (omitida para vacia). */
export function aplicoTexto(d) {
  if (d && d.externa) {
    return d.clinica_externa ? `Aplicada en ${d.clinica_externa}` : 'Aplicada en otra clínica';
  }
  const v = d && d.veterinario;
  if (!v || !v.nombre) return '';
  return v.matricula ? `Aplicó: Dr(a). ${v.nombre} · Mat. ${v.matricula}` : `Aplicó: Dr(a). ${v.nombre}`;
}

const PESO = { vencida: 0, proxima: 1, al_dia: 2, completo: 2 };
const peso = (e) => (e in PESO ? PESO[e] : 2);
const ESPECIE = { perro: 'Perro', gato: 'Gato', otro: 'Otro' };

const txt = (v) => (typeof v === 'string' ? v : '');

export function modeloVista(json) {
  const m = (json && json.mascota) || {};
  const c = (json && json.clinica) || {};
  const hoy = txt(json && json.hoy);
  const biologicos = Array.isArray(json && json.biologicos) ? json.biologicos : [];
  const dosis = Array.isArray(json && json.dosis) ? json.dosis : [];

  const porNombre = new Map();
  for (const b of biologicos) porNombre.set(b.biologico_nombre, b);

  const mapa = new Map();
  for (const d of dosis) {
    if (!mapa.has(d.biologico_nombre)) mapa.set(d.biologico_nombre, []);
    mapa.get(d.biologico_nombre).push(d);
  }

  const grupos = [];
  for (const [nombre, lista] of mapa) {
    const b = porNombre.get(nombre) || {};
    const estado = txt(b.estado) || 'al_dia';
    const ordenadas = [...lista].sort((a, z) => {
      if (a.es_ultima !== z.es_ultima) return a.es_ultima ? -1 : 1;
      return txt(z.fecha_aplicacion).localeCompare(txt(a.fecha_aplicacion));
    });
    grupos.push({
      nombre,
      tipo: txt(lista[0].tipo),
      estado,
      estadoEtiqueta: etiquetaEstado(estado),
      dosis: ordenadas.map((d) => {
        const vigente = d.es_ultima === true;
        return {
          fecha: formatearFecha(d.fecha_aplicacion),
          etiquetaDosis: txt(d.etiqueta_dosis),
          producto: txt(d.producto),
          lote: txt(d.lote),
          externa: d.externa === true,
          aplico: aplicoTexto(d),
          vigente,
          etiquetaProxima: vigente ? txt(b.etiqueta_proxima) : '',
          proxima: vigente ? formatearFecha(b.proxima_fecha) : '',
          estado: vigente ? estado : '',
          estadoEtiqueta: vigente ? etiquetaEstado(estado) : '',
        };
      }),
    });
  }
  grupos.sort((a, z) => peso(a.estado) - peso(z.estado) || a.nombre.localeCompare(z.nombre, 'es'));

  const estadoGeneral = grupos.reduce(
    (peor, g) => (peso(g.estado) < peso(peor) ? g.estado : peor),
    'al_dia',
  );
  const nombre = txt(m.nombre);
  const nac = txt(m.fecha_nacimiento);

  return {
    vacio: grupos.length === 0,
    mascota: {
      nombre,
      inicial: nombre ? nombre.charAt(0).toUpperCase() : '?',
      especie: ESPECIE[m.especie] || '',
      raza: txt(m.raza),
      nacimiento: formatearFecha(nac),
      edad: edadTexto(nac, hoy),
      fotoUrl: typeof m.foto_url === 'string' ? m.foto_url : '',
    },
    propietario: txt(json && json.propietario),
    hoy: formatearFecha(hoy),
    estadoGeneral,
    estadoGeneralEtiqueta: etiquetaEstado(estadoGeneral),
    clinica: {
      nombre: txt(c.nombre),
      ciudad: txt(c.ciudad),
      direccion: txt(c.direccion),
      telefono: txt(c.telefono),
    },
    grupos,
  };
}
