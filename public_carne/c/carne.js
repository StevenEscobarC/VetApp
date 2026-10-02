// Render del carne publico. El DOM se construye SOLO con createElement +
// textContent + setAttribute: ningun texto de la base de datos se interpreta
// como HTML (T-05-16). El token se lee unicamente del fragmento (#) y viaja en
// el cuerpo del POST (D-16).
import { leerToken, modeloVista } from './carne_logica.js';

const raiz = document.getElementById('carne');
const cfg = window.CARNE_CONFIG || {};
let origenSupabase = '';
try {
  origenSupabase = new URL(cfg.functionUrl).origin;
} catch (_) {
  origenSupabase = '';
}

function el(tag, clase, texto) {
  const n = document.createElement(tag);
  if (clase) n.setAttribute('class', clase);
  if (texto !== undefined && texto !== null && texto !== '') n.textContent = texto;
  return n;
}

function limpiar() {
  while (raiz.firstChild) raiz.removeChild(raiz.firstChild);
}

function pie() {
  return el('p', 'pie', 'Hecho con VetApp');
}

function estadoCentrado(titulo, cuerpo, conReintento) {
  limpiar();
  const caja = el('section', 'estado');
  const circulo = el('div', 'circulo-estado', conReintento ? '!' : '⊗');
  circulo.setAttribute('aria-hidden', 'true');
  caja.appendChild(circulo);
  caja.appendChild(el('h1', 'titulo', titulo));
  caja.appendChild(el('p', 'cuerpo', cuerpo));
  if (conReintento) {
    const b = el('button', 'boton', 'Reintentar');
    b.setAttribute('type', 'button');
    b.addEventListener('click', cargar);
    caja.appendChild(b);
  }
  raiz.appendChild(caja);
  raiz.appendChild(pie());
}

function invalido() {
  estadoCentrado(
    'Este enlace no es válido',
    'Es posible que haya sido reemplazado. Pídale a su veterinario que le envíe el enlace actualizado.',
    false,
  );
}

function errorRed() {
  estadoCentrado('No pudimos cargar el carné', 'Revise su conexión e intente de nuevo.', true);
}

function esqueleto() {
  limpiar();
  const a = el('div', 'esqueleto alto-1');
  const b = el('div', 'esqueleto alto-2');
  raiz.appendChild(a);
  raiz.appendChild(b);
  const lento = el('p', 'etiqueta oculto', 'Cargando carné...');
  lento.setAttribute('id', 'cargando-lento');
  raiz.appendChild(lento);
  raiz.appendChild(pie());
  return setTimeout(() => lento.classList.remove('oculto'), 3000);
}

const ICONO = { vencida: '✕', proxima: '◷', al_dia: '✓', completo: '✓' };

function chip(estado, etiqueta) {
  const c = el('span', 'chip estado-' + (estado === 'completo' ? 'al_dia' : estado));
  const i = el('span', 'chip-icono', ICONO[estado] || '✓');
  i.setAttribute('aria-hidden', 'true');
  c.appendChild(i);
  c.appendChild(document.createTextNode(' ' + etiqueta));
  return c;
}

function campo(dl, rotulo, valor) {
  if (!valor) return;
  const fila = el('div', 'campo');
  fila.appendChild(el('dt', 'rotulo', rotulo));
  fila.appendChild(el('dd', 'valor', valor));
  dl.appendChild(fila);
}

function dosisCard(d) {
  const card = el('article', 'dosis' + (d.vigente ? '' : ' historial'));
  const dl = el('dl');
  campo(dl, 'Fecha de aplicación', d.fecha + (d.etiquetaDosis ? ' · ' + d.etiquetaDosis : ''));
  campo(dl, 'Producto', d.producto);
  campo(dl, 'Lote', d.lote);
  if (d.vigente) campo(dl, d.etiquetaProxima || 'Próxima dosis', d.proxima);
  card.appendChild(dl);
  if (d.vigente) {
    const fila = el('div', 'fila-estado');
    fila.appendChild(el('span', 'rotulo', 'Estado'));
    fila.appendChild(chip(d.estado, d.estadoEtiqueta));
    card.appendChild(fila);
  }
  if (d.externa) card.appendChild(el('span', 'etiqueta-externa', 'Otra clínica'));
  if (d.aplico) card.appendChild(el('p', 'etiqueta', d.aplico));
  return card;
}

function render(modelo) {
  limpiar();
  document.title = 'Carné de vacunación · ' + modelo.mascota.nombre;

  const cab = el('header', 'banda');
  const cl = [modelo.clinica.nombre, modelo.clinica.ciudad].filter(Boolean).join(' · ');
  const logoUrl = modelo.clinica.logoUrl;
  const logoValido = !!(logoUrl && origenSupabase && logoUrl.startsWith(origenSupabase + '/'));
  if (logoValido || cl) {
    const banda = el('div', 'banda-clinica');
    if (logoValido) {
      const logo = el('img', 'logo-clinica');
      logo.setAttribute('src', logoUrl);
      logo.setAttribute(
        'alt',
        modelo.clinica.nombre ? 'Logo de ' + modelo.clinica.nombre : 'Logo de la clínica',
      );
      logo.setAttribute('referrerpolicy', 'no-referrer');
      logo.setAttribute('width', '40');
      logo.setAttribute('height', '40');
      // Sin handlers inline (CSP): si el logo falla, queda solo el nombre.
      logo.addEventListener('error', () => logo.remove());
      banda.appendChild(logo);
    }
    if (cl) banda.appendChild(el('p', 'etiqueta', cl));
    cab.appendChild(banda);
  }
  cab.appendChild(el('h2', 'encabezado', 'Carné de vacunación'));
  raiz.appendChild(cab);

  const bloque = el('section', 'tarjeta mascota');
  const avatar = el('div', 'avatar');
  const m = modelo.mascota;
  if (m.fotoUrl && origenSupabase && m.fotoUrl.startsWith(origenSupabase + '/')) {
    const img = el('img');
    img.setAttribute('src', m.fotoUrl);
    img.setAttribute('alt', 'Foto de ' + m.nombre);
    img.setAttribute('referrerpolicy', 'no-referrer');
    avatar.appendChild(img);
  } else {
    avatar.textContent = m.inicial;
    avatar.setAttribute('aria-hidden', 'true');
  }
  bloque.appendChild(avatar);
  const datos = el('div', 'datos-mascota');
  datos.appendChild(el('h1', 'nombre-mascota', m.nombre));
  datos.appendChild(el('p', 'etiqueta', [m.especie, m.raza].filter(Boolean).join(' · ')));
  if (m.nacimiento) {
    datos.appendChild(
      el('p', 'cuerpo', 'Nació el ' + m.nacimiento + (m.edad ? ' · ' + m.edad : '')),
    );
  }
  if (modelo.propietario) datos.appendChild(el('p', 'cuerpo', 'Propietario: ' + modelo.propietario));
  bloque.appendChild(datos);
  raiz.appendChild(bloque);

  if (modelo.vacio) {
    raiz.appendChild(el('p', 'cuerpo vacio', 'Esta mascota aún no tiene vacunas registradas.'));
  } else {
    const resumen = el('div', 'resumen');
    resumen.appendChild(chip(modelo.estadoGeneral, modelo.estadoGeneralEtiqueta));
    if (modelo.hoy) resumen.appendChild(el('span', 'etiqueta', 'Actualizado el ' + modelo.hoy));
    raiz.appendChild(resumen);

    for (const g of modelo.grupos) {
      const sec = el('section', 'grupo');
      sec.appendChild(el('h2', 'encabezado', g.nombre));
      for (const d of g.dosis) sec.appendChild(dosisCard(d));
      raiz.appendChild(sec);
    }
  }

  const c = modelo.clinica;
  if (c.nombre || c.direccion || c.telefono) {
    const cb = el('section', 'clinica');
    if (c.nombre) cb.appendChild(el('p', 'etiqueta fuerte', c.nombre));
    if (c.direccion) cb.appendChild(el('p', 'etiqueta', c.direccion));
    if (c.telefono) cb.appendChild(el('p', 'etiqueta', c.telefono));
    raiz.appendChild(cb);
  }

  raiz.appendChild(
    el(
      'p',
      'etiqueta tenue',
      'Este carné es informativo. Para trámites de viaje o certificados oficiales, solicite el documento firmado a su veterinario.',
    ),
  );
  raiz.appendChild(pie());
}

let solicitud = 0;

async function cargar() {
  const token = leerToken(location.hash);
  if (!token) {
    // Sin token valido no hay llamada de red.
    invalido();
    return;
  }
  const id = ++solicitud;
  const temporizador = esqueleto();
  try {
    const r = await fetch(cfg.functionUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token }),
      referrerPolicy: 'no-referrer',
      cache: 'no-store',
    });
    if (id !== solicitud) return;
    clearTimeout(temporizador);
    if (r.status === 404) return invalido();
    if (!r.ok) return errorRed();
    const json = await r.json();
    render(modeloVista(json));
  } catch (_) {
    if (id !== solicitud) return;
    clearTimeout(temporizador);
    errorRed();
  }
}

window.addEventListener('hashchange', cargar);
cargar();
