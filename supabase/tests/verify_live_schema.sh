#!/usr/bin/env bash
# VetApp: prueba de que el proyecto Supabase en la nube expone las 4 tablas
# reales sobre PostgREST y que el rol anon no puede escribir en tablas de
# tenant. No requiere Supabase CLI ni contraseña de base de datos -- solo la
# anon key (pública por diseño, ya embebida en los builds móviles).
#
# Uso:
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... bash supabase/tests/verify_live_schema.sh
#   o, si existe dart_define.json en la raíz del repo (gitignored), sin variables:
#   bash supabase/tests/verify_live_schema.sh
#
# Nunca imprime el valor de la anon key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if { [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; } && [ -f "$REPO_ROOT/dart_define.json" ]; then
  # cd into the repo root and require a relative path -- avoids passing a
  # POSIX-style (git-bash) path into node's Windows-native module resolver.
  if [ -z "$SUPABASE_URL" ]; then
    SUPABASE_URL="$(cd "$REPO_ROOT" && node -e "console.log(require('./dart_define.json').SUPABASE_URL || '')")"
  fi
  if [ -z "$SUPABASE_ANON_KEY" ]; then
    SUPABASE_ANON_KEY="$(cd "$REPO_ROOT" && node -e "console.log(require('./dart_define.json').SUPABASE_ANON_KEY || '')")"
  fi
fi

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "FAIL config: falta SUPABASE_URL / SUPABASE_ANON_KEY (variables de entorno o dart_define.json en la raíz del repo)" >&2
  exit 1
fi

any_fail=0

for t in clinicas perfiles clientes mascotas; do
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    "$SUPABASE_URL/rest/v1/$t?select=id&limit=1")
  if [ "$code" = "200" ]; then
    echo "OK $t 200"
  else
    echo "FAIL $t $code"
    any_fail=1
  fi
done

anon_code=$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=minimal" \
  -d '{"clinica_id":"00000000-0000-0000-0000-000000000000","nombre":"anon-probe"}' \
  "$SUPABASE_URL/rest/v1/clientes")

if [ "$anon_code" = "401" ] || [ "$anon_code" = "403" ]; then
  echo "OK anon insert rechazado $anon_code"
else
  echo "FAIL anon insert $anon_code"
  any_fail=1
fi

if [ "$any_fail" -ne 0 ]; then
  exit 1
fi

echo "LIVE_SCHEMA_OK"
