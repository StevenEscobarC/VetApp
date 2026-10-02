// Edge Function `carne`: unica superficie anonima de VetApp (D-25).
//
// - Devuelve JSON y NO HTML: Supabase reescribe text/html a text/plain en el
//   dominio gratuito (RESEARCH Pitfall 1). El HTML vive en GitHub Pages.
// - El token viaja en el cuerpo POST (y en el fragmento # de la pagina), nunca
//   en query string, para no quedar en Referer ni en logs del servidor (D-16).
// - El 404 es uniforme (token mal formado, desconocido o regenerado): no hay
//   oraculo de enumeracion.
// - SUPABASE_SERVICE_ROLE_KEY es un secreto de runtime provisto por Supabase;
//   jamas debe aparecer en la pagina ni en el repositorio (D-18: el dueno no
//   tiene cuenta, por eso verify_jwt = false en config.toml).
// - Foto de la mascota y logo de la clinica se firman 300 s; logo_path y
//   foto_path nunca se devuelven (D-26).
// - Sin imports: solo fetch nativo (sin dependencias de terceros).

const ORIGEN = Deno.env.get('CARNE_ORIGEN') ?? 'https://stevenescobarc.github.io';
const TOKEN_RE = /^[0-9a-f]{64}$/;
const MAX_BODY_BYTES = 1024;
const LOGO_RE = /^[0-9a-f-]{36}\/logo-[0-9]{10,16}\.jpg$/;

function cors(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': ORIGEN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Max-Age': '600',
    'Vary': 'Origin',
  };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors(),
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
  });
}

const noEncontrado = () => json(404, { error: 'no_encontrado' });

// Firma 300 s una ruta de storage; null ante cualquier fallo.
async function firmar(
  base: string,
  headers: Record<string, string>,
  bucket: string,
  path: string,
): Promise<string | null> {
  try {
    const firma = await fetch(
      `${base}/storage/v1/object/sign/${bucket}/${encodeURI(path)}`,
      { method: 'POST', headers, body: JSON.stringify({ expiresIn: 300 }) },
    );
    if (firma.status !== 200) {
      await firma.body?.cancel();
      return null;
    }
    const f = await firma.json().catch(() => null);
    if (f && typeof f.signedURL === 'string') {
      return `${base}/storage/v1${f.signedURL}`;
    }
    return null;
  } catch (_) {
    return null;
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors() });
  }
  if (req.method !== 'POST') {
    return json(405, { error: 'metodo_no_permitido' });
  }

  try {
    const largo = Number(req.headers.get('content-length') ?? '0');
    if (largo > MAX_BODY_BYTES) return noEncontrado();

    const cuerpo = await req.json().catch(() => null);
    const token = cuerpo && typeof cuerpo.token === 'string' ? cuerpo.token : '';
    // Validacion ANTES de cualquier llamada a la base de datos.
    if (!TOKEN_RE.test(token)) return noEncontrado();

    const base = Deno.env.get('SUPABASE_URL');
    const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!base || !key) return json(500, { error: 'interno' });

    const headers = {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'content-type': 'application/json',
    };

    const rpc = await fetch(`${base}/rest/v1/rpc/carne_publico`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ p_token: token }),
    });
    if (rpc.status !== 200) {
      await rpc.body?.cancel();
      return noEncontrado();
    }
    const carne = await rpc.json().catch(() => null);
    if (!carne || typeof carne !== 'object' || !carne.mascota) return noEncontrado();

    const mascota = carne.mascota;
    const path = mascota.foto_path;
    mascota.foto_url = null;
    if (typeof path === 'string' && path.length > 0) {
      // Degradar sin foto ante cualquier fallo (Pitfall 7).
      mascota.foto_url = await firmar(base, headers, 'mascota-fotos', path);
    }
    delete mascota.foto_path;

    // Logo de la clinica (D-26): solo rutas con la forma esperada se firman;
    // logo_path nunca sale en la respuesta.
    const clinica = carne.clinica;
    if (clinica && typeof clinica === 'object') {
      const lp = clinica.logo_path;
      clinica.logo_url =
        typeof lp === 'string' && LOGO_RE.test(lp)
          ? await firmar(base, headers, 'clinica-logos', lp)
          : null;
      delete carne.clinica.logo_path;
    }

    return json(200, carne);
  } catch (_) {
    // No se devuelve ni se registra el error: podria contener token o clave.
    return json(500, { error: 'interno' });
  }
});
