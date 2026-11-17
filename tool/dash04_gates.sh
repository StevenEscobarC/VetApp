#!/usr/bin/env bash
# DASH-04 grep gates (08-UI-SPEC "Sweep Rules" > Gates), plus `.icon(` in
# SW-01 and an SW-04 spacing gate. Only greps *.dart under the given paths;
# never reads env files, keys or URLs.
#
# Usage: bash tool/dash04_gates.sh [--selftest] [path ...]   (default: lib)
# Exit 0 + "DASH04_GATES: PASS" when every hit is fixed or exempted below.
set -u

# Exemption table: RULE|grep -E pattern over "file:line:text"|reason.
# Every exemption is printed on each run (EXENTOS) so none hides silently.
EXEMPTIONS='SW-01|FloatingActionButton(\.extended)?\(|\bSwitch\(|SwitchListTile\(|\bCheckbox\(|tematizado en app_theme.dart (08-02)
SW-02|lib/core/utils/recorte_cuadrado\.dart|relleno de canvas dart:ui al recortar la foto, no es color de UI
SW-03|_pdf_service\.dart|_pdf_providers\.dart|estilos del paquete pdf (UI-SPEC Exemptions)
SW-09|kOrigenCobro = '"'"'factura'"'"'|constante de origen en la base, nunca se muestra'

HITS=0
EXEMPT=0
EXEMPT_REASONS=''

# raw_hits RULE PATH... -> prints grep -rn lines (file:line:text) for RULE.
raw_hits() {
  local rule=$1
  shift
  case "$rule" in
    SW-01)
      grep -rnE "\b(ElevatedButton|FilledButton|OutlinedButton|TextButton|AppBar|TextFormField|TextField|ChoiceChip|FilterChip|Chip|Card|FloatingActionButton|Switch|SwitchListTile|Checkbox)(\(|\.extended\(|\.icon\()" "$@" --include=*.dart | grep -v "lib/core/"
      ;;
    SW-02)
      LC_ALL=C.UTF-8 grep -rnP "Color\(0x|\bColors\.(?!transparent)" "$@" --include=*.dart | grep -v "lib/core/theme/"
      ;;
    SW-03)
      grep -rnE "fontSize:|fontFamily:|GoogleFonts\.|FontWeight\.(bold|w[1235789]00)" "$@" --include=*.dart | grep -v "lib/core/theme/app_typography.dart"
      ;;
    SW-04)
      grep -rnE "EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[^a-zA-Z_.0-9][0-9]+\b|SizedBox\((height|width): *[0-9]+(\.[0-9]+)?\)|BorderRadius\.circular\([0-9]+(\.[0-9]+)?\)" "$@" --include=*.dart | grep -v "lib/core/theme/" | grep -v "_pdf_service\.dart"
      ;;
    SW-05)
      grep -rnE "MaterialTapTargetSize\.shrinkWrap|VisualDensity\.compact|BoxConstraints\(\)" "$@" --include=*.dart
      ;;
    SW-08)
      grep -rnE "DateFormat\(|toIso8601String\(\)|'[\\][\$] ?' *[+]" "$@" --include=*.dart | grep "lib/features" | grep -v "/data/"
      ;;
    SW-09)
      grep -rnE "Próximamente|ComingSoon|[Ff]actura" "$@" --include=*.dart
      ;;
  esac
}

# exemption_for RULE LINE -> prints the reason if LINE is exempted.
exemption_for() {
  local rule=$1 hit=$2 entry r rest pat reason
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    r=${entry%%|*}
    rest=${entry#*|}
    reason=${rest##*|}
    pat=${rest%|*}
    if [ "$r" = "$rule" ] && printf '%s\n' "$hit" | grep -qE -- "$pat"; then
      printf '%s\n' "$reason"
      return 0
    fi
  done <<EOF
$EXEMPTIONS
EOF
  return 1
}

run_gates() {
  local rule line reason
  for rule in SW-01 SW-02 SW-03 SW-04 SW-05 SW-08 SW-09; do
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      if reason=$(exemption_for "$rule" "$line"); then
        EXEMPT=$((EXEMPT + 1))
        EXEMPT_REASONS="${EXEMPT_REASONS}${rule}: ${reason}
"
        continue
      fi
      HITS=$((HITS + 1))
      # file:line:text -> "SW-xx file:line: text"
      printf '%s %s\n' "$rule" "$(printf '%s' "$line" | sed -E 's/^([^:]*):([0-9]+):[[:space:]]*/\1:\2: /')"
    done <<EOF
$(raw_hits "$rule" "$@")
EOF
  done
  echo "EXENTOS: $EXEMPT"
  if [ -n "$EXEMPT_REASONS" ]; then
    printf '%s' "$EXEMPT_REASONS" | sort | uniq -c | sed 's/^ */  /'
  fi
  if [ "$HITS" -eq 0 ]; then
    echo "DASH04_GATES: PASS"
    return 0
  fi
  echo "DASH04_GATES: FAIL ($HITS)"
  return 1
}

selftest() {
  local tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/dash04_selftest.XXXXXX")
  trap 'rm -rf "$tmp"' RETURN
  local fails=0
  write_fixture() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }
  expect_hit() {
    local rule=$1 file=$2 body=$3 dir out rc
    dir="$tmp/$rule"
    write_fixture "$dir/$file" "$body"
    out=$(bash "$0" "$dir/lib") && rc=0 || rc=$?
    if [ "$rc" -ne 1 ] || ! printf '%s\n' "$out" | grep -q "^$rule "; then
      echo "SELFTEST FALLA: $rule no detectó la violación (rc=$rc)"
      fails=$((fails + 1))
    fi
  }
  expect_hit SW-01 lib/features/x/a.dart "  child: TextButton.icon(onPressed: f),"
  expect_hit SW-02 lib/features/x/a.dart "  color: Colors.red,"
  expect_hit SW-03 lib/features/x/a.dart "  style: TextStyle(fontSize: 13),"
  expect_hit SW-04 lib/features/x/a.dart "  const SizedBox(height: 12),"
  expect_hit SW-05 lib/features/x/a.dart "  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,"
  expect_hit SW-08 lib/features/x/presentation/a.dart "  final s = DateFormat('d/M').format(f);"
  expect_hit SW-09 lib/features/x/a.dart "  const titulo = 'Próximamente';"
  local clean="$tmp/clean" out rc
  write_fixture "$clean/lib/features/x/a.dart" "  const SizedBox(height: AppSpacing.md),"
  out=$(bash "$0" "$clean/lib") && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "SELFTEST FALLA: fixture limpio salió con $rc"
    fails=$((fails + 1))
  fi
  if [ "$fails" -eq 0 ]; then
    echo "DASH04_SELFTEST_OK"
    return 0
  fi
  echo "DASH04_SELFTEST_FAIL ($fails)"
  return 1
}

if [ "${1:-}" = "--selftest" ]; then
  selftest
  exit $?
fi
[ "$#" -eq 0 ] && set -- lib
run_gates "$@"
exit $?
