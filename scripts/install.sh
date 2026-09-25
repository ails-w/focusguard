#!/usr/bin/env bash
# Instala todos los módulos de focusguard.
# Uso: sudo scripts/install.sh [--dry-run]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecuta con sudo." >&2
  exit 1
fi

echo "== Módulo 00: base =="
run install -d /etc/focusguard /usr/local/lib/focusguard
run install -m 0644 "$REPO_DIR/modules/00-base/files/etc/focusguard/policy.conf" /etc/focusguard/policy.conf
run install -m 0644 "$REPO_DIR/modules/00-base/files/usr/local/lib/focusguard/common.sh" /usr/local/lib/focusguard/common.sh
if grep -q 'USER="alice"' /etc/focusguard/policy.conf 2>/dev/null; then
  echo "  AVISO: policy.conf sigue con el usuario de EJEMPLO (alice). Edítalo antes de confiar en esto."
fi

echo "== Módulo 01: PAM gate =="
run install -m 0755 "$REPO_DIR/modules/01-pam-gate/files/usr/local/bin/focusguard-render" \
                    "$REPO_DIR/modules/01-pam-gate/files/usr/local/bin/focusguard-apply" /usr/local/bin/
run focusguard-apply

echo "== Módulo 02: enforcement =="
run install -m 0755 "$REPO_DIR/modules/02-enforce/files/usr/local/bin/focusguard-enforce" /usr/local/bin/
run install -m 0644 "$REPO_DIR/modules/02-enforce/files/etc/systemd/system/focusguard-enforce.service" \
                    "$REPO_DIR/modules/02-enforce/files/etc/systemd/system/focusguard-enforce.timer" \
                    "$REPO_DIR/modules/02-enforce/files/etc/systemd/system/focusguard-resume.service" \
                    /etc/systemd/system/
run systemctl daemon-reload
run systemctl enable --now focusguard-enforce.timer focusguard-resume.service

echo "== Módulo 03: integridad =="
run install -m 0755 "$REPO_DIR/modules/03-integrity/files/usr/local/bin/focusguard-lock" \
                    "$REPO_DIR/modules/03-integrity/files/usr/local/bin/focusguard-integrity" /usr/local/bin/
run install -m 0644 "$REPO_DIR/modules/03-integrity/files/etc/systemd/system/focusguard-integrity.service" \
                    "$REPO_DIR/modules/03-integrity/files/etc/systemd/system/focusguard-integrity.timer" \
                    /etc/systemd/system/
run systemctl daemon-reload
run systemctl enable --now focusguard-integrity.timer
run focusguard-lock

echo "== Módulo 04: disarm =="
run install -m 0755 "$REPO_DIR/modules/04-disarm/files/usr/local/bin/focusguard-disarm" /usr/local/bin/

echo
echo "Instalado. Verifica con: sudo scripts/verify.sh"
