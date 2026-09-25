#!/usr/bin/env bash
# Desinstala focusguard (reverso por módulo).
# Uso: sudo scripts/uninstall.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecuta con sudo." >&2
  exit 1
fi

echo "== Módulo 04/03: desarmar y quitar proteccion =="
systemctl disable --now focusguard-enforce.timer focusguard-integrity.timer focusguard-resume.service 2>/dev/null || true
for f in /etc/focusguard/policy.conf /etc/security/time.conf /etc/focusguard/golden/policy.conf /etc/focusguard/golden/time.conf; do
  chattr -i "$f" 2>/dev/null || true
done

echo "== Módulo 03/02/01: binarios y units =="
rm -f /etc/systemd/system/focusguard-enforce.service \
      /etc/systemd/system/focusguard-enforce.timer \
      /etc/systemd/system/focusguard-integrity.service \
      /etc/systemd/system/focusguard-integrity.timer \
      /etc/systemd/system/focusguard-resume.service
rm -f /usr/local/bin/focusguard-render /usr/local/bin/focusguard-apply \
      /usr/local/bin/focusguard-enforce /usr/local/bin/focusguard-lock \
      /usr/local/bin/focusguard-integrity /usr/local/bin/focusguard-disarm
systemctl daemon-reload

echo "== Módulo 01: quitar la regla de pam_time =="
sed -i '/# BEGIN focusguard/,/# END focusguard/d' /etc/security/time.conf

echo "== Módulo 00: base =="
rm -rf /usr/local/lib/focusguard /etc/focusguard

echo
echo "Desinstalado. (El log /var/log/focusguard se conserva a proposito.)"
