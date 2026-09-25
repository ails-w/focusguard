#!/usr/bin/env bash
# FocusGuard shared helpers (sourced, not executed)

fg_audit() {
  logger -t focusguard "$1"
  mkdir -p /var/log/focusguard 2>/dev/null || true
  printf '%s %s\n' "$(date -Is)" "$1" >> /var/log/focusguard/audit.log 2>/dev/null || true
}
