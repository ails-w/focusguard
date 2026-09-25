#!/usr/bin/env bash
# Verifica el estado de focusguard (solo lectura).
# Uso: scripts/verify.sh
set -u

OK=0
FAIL=0
ok()   { printf '  [OK] %s\n' "$1"; OK=$((OK + 1)); }
fail() { printf '  [!!] %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "== Capa 0: base =="
[ -f /etc/focusguard/policy.conf ]          && ok "policy.conf presente"   || fail "falta policy.conf"
[ -f /usr/local/lib/focusguard/common.sh ]  && ok "common.sh presente"     || fail "falta common.sh"

echo "== Capa 1: PAM gate =="
command -v focusguard-render >/dev/null     && ok "focusguard-render instalado" || fail "falta focusguard-render"
grep -q 'BEGIN focusguard' /etc/security/time.conf && ok "bloque en time.conf" || fail "no hay bloque en time.conf"
grep -q pam_time /etc/pam.d/system-auth     && ok "pam_time en system-auth"    || fail "pam_time no habilitado"

echo "== Capa 2: enforcement =="
bash -n /usr/local/bin/focusguard-enforce 2>/dev/null && ok "enforce sin errores de sintaxis" || fail "enforce con errores"
if grep -q pkill /usr/local/bin/focusguard-enforce 2>/dev/null; then
  fail "enforce usa pkill (riesgo de pantalla negra)"
else
  ok "sin pkill"
fi
systemctl is-active --quiet focusguard-enforce.timer && ok "timer de enforcement activo" || fail "timer de enforcement inactivo"
systemctl is-enabled --quiet focusguard-resume.service 2>/dev/null && ok "resume unit habilitado" || fail "resume unit no habilitado"

echo "== Capa 3: integridad =="
lsattr /etc/focusguard/policy.conf 2>/dev/null | grep -q '^....i' && ok "policy.conf inmutable" || fail "policy.conf sin atributo i"
lsattr /etc/security/time.conf     2>/dev/null | grep -q '^....i' && ok "time.conf inmutable"   || fail "time.conf sin atributo i"
[ -d /etc/focusguard/golden ] && ok "golden presente" || fail "falta el directorio golden"
systemctl is-active --quiet focusguard-integrity.timer && ok "timer de integridad activo" || fail "timer de integridad inactivo"

echo "== Capa 4: disarm =="
command -v focusguard-disarm >/dev/null && ok "focusguard-disarm instalado" || fail "falta focusguard-disarm"

echo
printf 'Resultado: %d OK, %d fallos\n' "$OK" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
