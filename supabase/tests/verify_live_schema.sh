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

for t in clinicas perfiles clientes mascotas mascota_pesos consultas citas cita_mascotas; do
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

for rpc in registrar_cliente_con_mascota registrar_mascota generar_codigo_vinculacion registrar_consulta crear_cita actualizar_cita; do
  case "$rpc" in
    registrar_cliente_con_mascota)
      payload='{"cliente_nombre":"probe","cliente_telefono":"3000000000","mascota_nombre":"probe","mascota_especie":"perro","mascota_raza":"","mascota_fecha_nacimiento":null,"mascota_peso_kg":null}'
      ;;
    registrar_mascota)
      payload='{"mascota_dueno_id":"00000000-0000-0000-0000-000000000000","mascota_nombre":"probe","mascota_especie":"perro","mascota_raza":"","mascota_fecha_nacimiento":null,"mascota_peso_kg":null}'
      ;;
    generar_codigo_vinculacion)
      payload='{"p_cliente_id":"00000000-0000-0000-0000-000000000000"}'
      ;;
    registrar_consulta)
      payload='{"p_mascota_id":"00000000-0000-0000-0000-000000000000","p_diagnostico":"x","p_tratamiento":"y"}'
      ;;
    crear_cita)
      payload='{"p_cliente_id":"00000000-0000-0000-0000-000000000000","p_mascota_ids":["00000000-0000-0000-0000-000000000000"],"p_fecha_hora":"2026-01-01T15:00:00Z"}'
      ;;
    actualizar_cita)
      payload='{"p_cita_id":"00000000-0000-0000-0000-000000000000","p_mascota_ids":["00000000-0000-0000-0000-000000000000"],"p_fecha_hora":"2026-01-01T15:00:00Z"}'
      ;;
  esac

  rpc_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$SUPABASE_URL/rest/v1/rpc/$rpc")

  if [ "$rpc_code" = "401" ] || [ "$rpc_code" = "403" ]; then
    echo "OK rpc $rpc protegido $rpc_code"
  elif [ "$rpc_code" = "404" ]; then
    echo "FAIL rpc $rpc 404 (no aplicada)"
    any_fail=1
  else
    echo "FAIL rpc $rpc $rpc_code"
    any_fail=1
  fi
done

# Sonda de embeds de la agenda (Fase 4): valida los hints de relación que usa el
# repositorio de citas. Con anon, RLS oculta todo: se espera 200 con cuerpo [].
embed_select='*, clientes!citas_cliente_misma_clinica_fkey(nombre, telefono, direccion), cita_mascotas(mascotas!cita_mascotas_mascota_fkey(id, nombre, especie, foto_path)), consultas(mascota_id)'
embed_body=$(mktemp)
embed_code=$(curl -s -G -o "$embed_body" -w '%{http_code}' \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  --data-urlencode "select=$embed_select" \
  --data-urlencode "limit=1" \
  "$SUPABASE_URL/rest/v1/citas")
if [ "$embed_code" = "200" ] && [ "$(tr -d '[:space:]' < "$embed_body")" = "[]" ]; then
  echo "OK citas embed"
else
  echo "FAIL citas embed $embed_code"
  cat "$embed_body"
  echo
  rm -f "$embed_body"
  exit 1
fi
rm -f "$embed_body"

if [ "$any_fail" -ne 0 ]; then
  exit 1
fi

echo "LIVE_SCHEMA_OK"
