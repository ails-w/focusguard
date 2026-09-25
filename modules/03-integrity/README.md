# Módulo 03 — Integridad

Candado anti-manipulación de la configuración: una copia *golden*, `chattr +i`, y una
verificación cada minuto que **restaura y re-bloquea** si algo cambió. Va **después** de
01 y 02, porque congela el estado ya correcto.

## Prerrequisitos

- Módulos [`00-base`](../00-base/), [`01-pam-gate`](../01-pam-gate/) y
  [`02-enforce`](../02-enforce/).
- `e2fsprogs` (`chattr`/`lsattr`).

## Archivos

| Archivo | Destino | Qué hace |
|---|---|---|
| `files/usr/local/bin/focusguard-lock` | `/usr/local/bin/` | copia live → golden y marca `+i` |
| `files/usr/local/bin/focusguard-integrity` | `/usr/local/bin/` | compara, restaura, re-bloquea |
| `files/etc/systemd/system/focusguard-integrity.service` | `/etc/systemd/system/` | corre el check |
| `files/etc/systemd/system/focusguard-integrity.timer` | `/etc/systemd/system/` | cada minuto (`:30`) |

Protege dos archivos: `/etc/focusguard/policy.conf` y `/etc/security/time.conf`.

## Aplicar

```bash
sudo install -m 0755 files/usr/local/bin/focusguard-lock files/usr/local/bin/focusguard-integrity /usr/local/bin/
sudo install -m 0644 files/etc/systemd/system/focusguard-integrity.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now focusguard-integrity.timer

sudo focusguard-lock        # primera foto del estado bueno + bloqueo
```

## Flujo para cambiar la config

```bash
sudo focusguard-disarm          # modulo 04: baja timers y quita la inmutabilidad
#   edit policy.conf ...
sudo focusguard-apply           # regenera time.conf (modulo 01)
sudo focusguard-lock            # nueva golden + bloquear
sudo systemctl start focusguard-enforce.timer focusguard-integrity.timer
```

## Verificar

```bash
lsattr /etc/focusguard/policy.conf /etc/security/time.conf   # ambos con 'i'
ls -la /etc/focusguard/golden/

# Prueba de sabotaje controlado:
sudo chattr -i /etc/security/time.conf
sudo sh -c 'echo "# sabotage" >> /etc/security/time.conf'
sudo systemctl start focusguard-integrity.service
grep -c sabotage /etc/security/time.conf   # debe ser 0
lsattr /etc/security/time.conf             # vuelve a tener 'i'
sudo journalctl -t focusguard -n 5 --no-pager
```

## Rollback

```bash
sudo systemctl disable --now focusguard-integrity.timer
sudo chattr -i /etc/focusguard/policy.conf /etc/security/time.conf /etc/focusguard/golden/* 2>/dev/null || true
sudo rm -f /etc/systemd/system/focusguard-integrity.service /etc/systemd/system/focusguard-integrity.timer
sudo rm -f /usr/local/bin/focusguard-lock /usr/local/bin/focusguard-integrity
sudo rm -rf /etc/focusguard/golden
sudo systemctl daemon-reload
```

## Notas

- **`chattr +i` es fricción, no frontera.** Un root decidido puede quitarlo; lo que aporta
  es que desactivar el bloqueo sea deliberado, se revierta solo y quede auditado.
- **Golden por `basename`.** Aquí alcanza porque los dos archivos tienen nombres distintos.
  Si agregas rutas con el mismo nombre de archivo, usa la ruta completa como nombre de
  golden (como hace `netguard`, el módulo hermano del repo `dns-doh-lockdown`).
- **Sin recarga de servicios:** `pam_time` lee `time.conf` en cada autenticación y
  `focusguard-enforce` lee `policy.conf` en cada ejecución, así que restaurar el archivo
  alcanza. (En configs con estado en memoria — `nftables`, `resolved` — hay que recargar;
  ver `netguard`.)
- El timer corre en `:30` y el de enforcement en `:00`, para no competir.
