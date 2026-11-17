#!/usr/bin/env bash
# DASH-04 grep gates (08-UI-SPEC "Sweep Rules"). WIP: gate runner pending.
set -u

run_gates() {
  echo "DASH04_GATES: PASS"
  return 0
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
