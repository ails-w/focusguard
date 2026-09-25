# Módulo 04 — Disarm

El **interruptor de rollback**: detiene los timers y quita la inmutabilidad para poder
editar la configuración. Es deliberado, lento y auditado — esa es toda su razón de ser.

## Prerrequisitos

- Módulos 00–03 instalados.

## Archivos

| Archivo | Destino | Qué hace |
|---|---|---|
| `files/usr/local/bin/focusguard-disarm` | `/usr/local/bin/` | pide `sudo` + frase + 60 s; baja timers y desbloquea |

## Aplicar

```bash
sudo install -m 0755 files/usr/local/bin/focusguard-disarm /usr/local/bin/
```

## Uso

```bash
sudo focusguard-disarm
# Esto DETIENE el bloqueo del usuario restringido.
# Escribe "desarmar" para confirmar: _
```

Después de editar, **rearma**:

```bash
sudo focusguard-apply            # regenera time.conf desde policy.conf (modulo 01)
sudo focusguard-lock             # nueva golden + bloquear (modulo 03)
sudo systemctl start focusguard-enforce.timer focusguard-integrity.timer
```

## Verificar

```bash
sudo tail -5 /var/log/focusguard/audit.log
sudo journalctl -t focusguard -n 10 --no-pager     # disarm / disarm-aborted
lsattr /etc/focusguard/policy.conf /etc/security/time.conf   # sin 'i' tras desarmar
```

## Rollback (volver a desarmar todo el sistema)

`focusguard-disarm` **detiene** los timers, no los deshabilita. Si quieres desinstalar:

```bash
sudo focusguard-disarm
sudo systemctl disable --now focusguard-enforce.timer focusguard-integrity.timer focusguard-resume.service
sudo rm -f /etc/systemd/system/focusguard-*.service /etc/systemd/system/focusguard-*.timer
sudo rm -f /usr/local/bin/focusguard-{render,apply,enforce,lock,integrity,disarm}
sudo rm -rf /usr/local/lib/focusguard /etc/focusguard
sudo sed -i '/# BEGIN focusguard/,/# END focusguard/d' /etc/security/time.conf
sudo systemctl daemon-reload
```

## Notas de diseño

- **No sourcea `policy.conf` a propósito.** Si la configuración está rota o a medio editar,
  el interruptor de emergencia debe funcionar igual.
- **No hace `disable`, solo `stop`.** Si el equipo se reinicia entre el desarme y el rearme,
  el timer vuelve a arrancar y la integridad restaura la golden vieja: **perderías tus
  cambios**. Es el comportamiento querido del candado (fricción), pero tenlo presente: edita
  y rearma en la misma sesión.
- **`sudo` pasa por `pam_time`.** Si el usuario restringido tuviera `sudo`, su ventana
  también limitaría cuándo puede desarmar. Para el administrador, no aplica.
- Cada intento (y cada cancelación) queda en `journalctl -t focusguard` y en
  `/var/log/focusguard/audit.log`.
