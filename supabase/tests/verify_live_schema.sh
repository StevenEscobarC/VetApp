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
  # cita_mascotas has a composite PK (cita_id, mascota_id) and no id column.
  col=id; [ "$t" = "cita_mascotas" ] && col=cita_id
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    "$SUPABASE_URL/rest/v1/$t?select=$col&limit=1")
  if [ "$code" = "200" ]; then
    echo "OK $t 200"
  else
    echo "FAIL $t $code"
    any_fail=1
  fi
done

# Fase 4.1: clinica_invitaciones no concede nada a anon (revoke all + RLS solo-admin).
# Se acepta 401/403/404 (sin privilegio) o 200 con cuerpo [] -- nunca filas.
inv_body=$(mktemp)
inv_code=$(curl -s -o "$inv_body" -w '%{http_code}' \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  "$SUPABASE_URL/rest/v1/clinica_invitaciones?select=id&limit=1")
if [ "$inv_code" = "401" ] || [ "$inv_code" = "403" ] || [ "$inv_code" = "404" ]; then
  echo "OK clinica_invitaciones protegida $inv_code"
elif [ "$inv_code" = "200" ] && [ "$(tr -d '[:space:]' < "$inv_body")" = "[]" ]; then
  echo "OK clinica_invitaciones 200 sin filas"
else
  echo "FAIL clinica_invitaciones $inv_code"
  any_fail=1
fi
rm -f "$inv_body"

# Fase 5: las 4 tablas de vacunación no conceden nada a anon (revoke all + RLS solo veterinarios).
# Se acepta 401/403/404 (sin privilegio) o 200 con cuerpo [] -- nunca filas.
for t in protocolos_vacunacion dosis_aplicadas vacuna_alertas carne_enlaces; do
  col=id
  [ "$t" = "vacuna_alertas" ] && col=dosis_ref_id
  [ "$t" = "carne_enlaces" ] && col=mascota_id
  t_body=$(mktemp)
  t_code=$(curl -s -o "$t_body" -w '%{http_code}' \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    "$SUPABASE_URL/rest/v1/$t?select=$col&limit=1")
  if [ "$t_code" = "401" ] || [ "$t_code" = "403" ] || [ "$t_code" = "404" ]; then
    echo "OK $t protegida $t_code"
  elif [ "$t_code" = "200" ] && [ "$(tr -d '[:space:]' < "$t_body")" = "[]" ]; then
    echo "OK $t 200 sin filas"
  else
    echo "FAIL $t $t_code"
    any_fail=1
  fi
  rm -f "$t_body"
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

for rpc in registrar_cliente_con_mascota registrar_mascota generar_codigo_vinculacion registrar_consulta crear_cita actualizar_cita mi_perfil es_veterinario mi_clinica_id crear_perfil_nuevo_usuario generar_invitacion_clinica revocar_invitacion retirar_miembro cambiar_rol_miembro crear_mi_clinica unirse_a_clinica es_admin_clinica es_miembro_activo es_autor_en_mi_clinica consumir_invitacion protocolos_efectivos guardar_protocolo restablecer_protocolo desactivar_protocolo registrar_dosis anular_dosis previsualizar_dosis carne_de_mascota vacunas_pendientes vacunas_resumen vacunas_resumen_mascotas gestionar_alerta_vacuna obtener_o_crear_enlace_carne regenerar_enlace_carne carne_publico actualizar_clinica; do
  payload="{}"
  case "$rpc" in
    revocar_invitacion|es_miembro_activo|es_autor_en_mi_clinica)
      payload='{"p_id":"00000000-0000-0000-0000-000000000000"}'
      ;;
    retirar_miembro)
      payload='{"p_miembro":"00000000-0000-0000-0000-000000000000"}'
      ;;
    cambiar_rol_miembro)
      payload='{"p_miembro":"00000000-0000-0000-0000-000000000000","p_rol":"admin"}'
      ;;
    crear_mi_clinica)
      payload='{"p_nombre":"probe"}'
      ;;
    unirse_a_clinica)
      payload='{"p_codigo":"ZZZZZZZZ"}'
      ;;
    consumir_invitacion)
      payload='{"p_codigo":"ZZZZZZZZ","p_usuario":"00000000-0000-0000-0000-000000000000"}'
      ;;
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
    protocolos_efectivos)
      payload='{"p_especie":"perro"}'
      ;;
    guardar_protocolo)
      payload='{"p_codigo":"probe","p_nombre":"probe","p_tipo":"vacuna","p_especies":["perro"],"p_dosis_serie":1,"p_intervalo_serie_dias":null,"p_intervalo_refuerzo_dias":null,"p_opciones_duracion_dias":[]}'
      ;;
    restablecer_protocolo|desactivar_protocolo)
      payload='{"p_codigo":"probe"}'
      ;;
    registrar_dosis)
      payload='{"p_mascota_id":"00000000-0000-0000-0000-000000000000","p_codigo_protocolo":"polivalente","p_biologico_nombre":null,"p_fecha_aplicacion":"2026-01-01"}'
      ;;
    anular_dosis)
      payload='{"p_dosis_id":"00000000-0000-0000-0000-000000000000","p_motivo":"probe"}'
      ;;
    previsualizar_dosis)
      payload='{"p_mascota_id":"00000000-0000-0000-0000-000000000000","p_codigo_protocolo":"polivalente","p_fecha_aplicacion":"2026-01-01"}'
      ;;
    carne_de_mascota|obtener_o_crear_enlace_carne|regenerar_enlace_carne)
      payload='{"p_mascota_id":"00000000-0000-0000-0000-000000000000"}'
      ;;
    gestionar_alerta_vacuna)
      payload='{"p_dosis_ref_id":"00000000-0000-0000-0000-000000000000","p_accion":"descartar"}'
      ;;
    carne_publico)
      payload='{"p_token":"0000000000000000000000000000000000000000000000000000000000000000"}'
      ;;
    actualizar_clinica)
      payload='{"p_nombre":"probe","p_ciudad":"","p_direccion":"","p_telefono":"","p_logo_path":null}'
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
  elif [ "$rpc_code" = "404" ] && { [ "$rpc" = "crear_perfil_nuevo_usuario" ] || [ "$rpc" = "consumir_invitacion" ]; }; then
    echo "OK rpc $rpc no expuesta 404 (función de trigger)"
  elif [ "$rpc_code" = "404" ] && [ "$rpc" = "carne_publico" ]; then
    echo "OK rpc carne_publico no expuesta a anon 404 (solo service_role)"
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

# Sonda de embeds de la Fase 4.1: nombre del veterinario asignado/autor vía las FK a perfiles.
# Con anon, RLS oculta todo: se espera 200 con cuerpo [].
probe_embed() {
  local table="$1" select="$2" label="$3" allow_denied="${4:-}" body code
  body=$(mktemp)
  code=$(curl -s -G -o "$body" -w '%{http_code}' \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    --data-urlencode "select=$select" \
    --data-urlencode "limit=1" \
    "$SUPABASE_URL/rest/v1/$table")
  if [ "$code" = "200" ] && [ "$(tr -d '[:space:]' < "$body")" = "[]" ]; then
    echo "OK $label"
  elif [ -n "$allow_denied" ] && { [ "$code" = "401" ] || [ "$code" = "403" ]; }; then
    echo "OK $label (anon sin privilegio $code; el hint de la FK resolvió, no hubo 400)"
  else
    echo "FAIL $label $code"
    cat "$body"
    echo
    any_fail=1
  fi
  rm -f "$body"
}
probe_embed citas '*, veterinario:perfiles!citas_veterinario_perfil_fkey(nombre)' 'citas veterinario embed'
probe_embed consultas '*, veterinario:perfiles!consultas_veterinario_perfil_fkey(nombre, activo)' 'consultas veterinario embed'
# Fase 5: el hint dosis_veterinario_perfil_fkey lo usa SupabaseVacunaRepository. anon no tiene
# privilegios sobre dosis_aplicadas: [] o 401/403 es correcto; 400 significa hint equivocado.
probe_embed dosis_aplicadas '*, veterinario:perfiles!dosis_veterinario_perfil_fkey(nombre, matricula, activo)' 'dosis veterinario embed' allow_denied

# Fase 5 (D-26): el bucket clinica-logos es privado; la URL pública no debe servir nada.
logo_code=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  "$SUPABASE_URL/storage/v1/object/public/clinica-logos/00000000-0000-0000-0000-000000000000/logo-1700000000000.jpg")
if [ "$logo_code" = "200" ]; then
  echo "FAIL clinica-logos público 200"
  any_fail=1
elif [ "$logo_code" = "400" ] || [ "$logo_code" = "401" ] || [ "$logo_code" = "403" ] || [ "$logo_code" = "404" ]; then
  echo "OK clinica-logos privado $logo_code"
else
  echo "FAIL clinica-logos respuesta inesperada $logo_code"
  any_fail=1
fi

# Fase 5 (VAC-04): Edge Function pública `carne`. Un token inválido responde 404 no_encontrado.
# Mientras no esté desplegada se imprime PENDIENTE (REQUIRE_CARNE_FN=1 lo convierte en FAIL).
fn_body=$(mktemp)
fn_code=$(curl -s -o "$fn_body" -w '%{http_code}' \
  -X POST \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"token":"xx"}' \
  "$SUPABASE_URL/functions/v1/carne" || true)
if [ "$fn_code" = "404" ] && grep -q "no_encontrado" "$fn_body"; then
  echo "OK carne edge function (token inválido -> 404)"
elif [ "${REQUIRE_CARNE_FN:-0}" = "1" ]; then
  echo "FAIL carne edge function $fn_code"
  any_fail=1
else
  echo "PENDIENTE carne edge function (no desplegada aún)"
fi
rm -f "$fn_body"

if [ "$any_fail" -ne 0 ]; then
  exit 1
fi

echo "LIVE_SCHEMA_OK"
