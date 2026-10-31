#!/usr/bin/env bash
# Stop hook de VetApp: si cambió algún .dart de lib/ o test/ desde la última
# corrida verde, ejecuta `flutter analyze` + `flutter test`. Si algo falla,
# bloquea el cierre del turno y le devuelve los fallos a Claude para que los
# corrija. Tras 3 bloqueos seguidos en la misma sesión deja terminar (evita
# bucles) y avisa que la suite sigue en rojo.
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" || exit 0
INPUT="$(cat)"

STATE_DIR="$ROOT/.dart_tool/claude_gate"
mkdir -p "$STATE_DIR"
SESSION="$(printf '%s' "$INPUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).session_id||"nosession")}catch{console.log("nosession")}})')"
COUNTER="$STATE_DIR/blocks_$SESSION"

# Huella del contenido actual de los .dart (incluye archivos sin commit y nuevos).
FINGERPRINT="$(git ls-files -co --exclude-standard -- lib test | grep '\.dart$' | sort \
  | git hash-object --stdin-paths 2>/dev/null | sha1sum | cut -d' ' -f1)"
if [ "$(cat "$STATE_DIR/last_green" 2>/dev/null)" = "$FINGERPRINT" ]; then
  rm -f "$COUNTER"
  exit 0
fi

emit() { # $1 = JSON a devolver (construido con node para escapar bien)
  printf '%s\n' "$1"
}

ANALYZE_OUT="$(flutter analyze --no-pub 2>&1)"; ANALYZE_RC=$?
TEST_OUT="$(set -o pipefail; flutter test --no-pub --reporter json 2>&1 | node -e '
let buf="";process.stdin.on("data",d=>buf+=d).on("end",()=>{
  const suites={},tests={},errs={},out=[];
  for(const l of buf.split("\n")){let e;try{e=JSON.parse(l)}catch{continue}
    if(e.type==="suite")suites[e.suite.id]=(e.suite.path||"").replace(/^.*[\\/]test[\\/]/,"test/");
    if(e.type==="testStart")tests[e.test.id]=e.test;
    if(e.type==="error")(errs[e.testID]=errs[e.testID]||[]).push(String(e.error).split("\n").slice(0,8).join("\n"));
    if(e.type==="testDone"&&!e.hidden&&e.result!=="success"){const t=tests[e.testID]||{};
      out.push("FALLA "+(suites[t.suiteID]||"?")+" :: "+t.name+"\n"+(errs[e.testID]||[]).join("\n"))}}
  console.log(out.length?out.slice(0,15).join("\n\n"):"(sin detalle por prueba; posible error de compilación)\n"+buf.split("\n").filter(l=>!l.startsWith("{")).slice(-30).join("\n"));
})')"; TEST_RC=$?

if [ $ANALYZE_RC -eq 0 ] && [ $TEST_RC -eq 0 ]; then
  printf '%s' "$FINGERPRINT" > "$STATE_DIR/last_green"
  rm -f "$COUNTER"
  emit '{"systemMessage":"Compuerta Flutter: analyze limpio y flutter test en verde."}'
  exit 0
fi

BLOCKS=$(( $(cat "$COUNTER" 2>/dev/null || echo 0) + 1 ))
printf '%s' "$BLOCKS" > "$COUNTER"

DETAIL="$(
  [ $ANALYZE_RC -ne 0 ] && { echo "== flutter analyze (exit $ANALYZE_RC) =="; printf '%s\n' "$ANALYZE_OUT" | grep -E 'error|warning|info|issue' | tail -40; }
  [ $TEST_RC -ne 0 ] && { echo "== flutter test (exit $TEST_RC) =="; printf '%s\n' "$TEST_OUT" | tail -80; }
)"

if [ "$BLOCKS" -gt 3 ]; then
  rm -f "$COUNTER"
  emit "$(DETAIL="$DETAIL" node -e 'console.log(JSON.stringify({systemMessage:"Compuerta Flutter sigue en ROJO tras 3 intentos; se deja terminar el turno. Revisa los fallos:\n"+process.env.DETAIL}))')"
  exit 0
fi

emit "$(DETAIL="$DETAIL" BLOCKS="$BLOCKS" node -e 'console.log(JSON.stringify({decision:"block",reason:"Compuerta Flutter en ROJO (intento "+process.env.BLOCKS+"/3). Corrige la causa raíz, vuelve a correr las pruebas y documenta el resultado en el VALIDATION de la fase antes de terminar. Si el rojo es intencional (fase RED de TDD), escribe el código mínimo para ponerlo en verde.\n\n"+process.env.DETAIL}))')"
exit 0
