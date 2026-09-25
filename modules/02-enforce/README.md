# Módulo 02 — Enforcement

Cierra la sesión del usuario cuando su ventana termina, **sin dejar el equipo en pantalla
negra**. Es la capa que actúa sobre quien ya estaba dentro (el módulo 01 solo bloquea la
entrada).

## Prerrequisitos

- Módulo [`00-base`](../00-base/).
- Un display manager (SDDM por defecto; `display-manager.service` debe existir).

## Archivos

| Archivo | Destino | Qué hace |
|---|---|---|
| `files/usr/local/bin/focusguard-enforce` | `/usr/local/bin/` | decide ventana, avisa y expulsa |
| `files/etc/systemd/system/focusguard-enforce.service` | `/etc/systemd/system/` | corre el script (`oneshot`) |
| `files/etc/systemd/system/focusguard-enforce.timer` | `/etc/systemd/system/` | lo dispara cada minuto (`:00`) |
| `files/etc/systemd/system/focusguard-resume.service` | `/etc/systemd/system/` | marca la hora de resume (`/run/focusguard/resumed`) |

## Aplicar

```bash
sudo install -m 0755 files/usr/local/bin/focusguard-enforce /usr/local/bin/
sudo install -m 0644 files/etc/systemd/system/focusguard-*.service \
                    files/etc/systemd/system/focusguard-*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now focusguard-enforce.timer focusguard-resume.service
```

## Cómo funciona (una pasada)

1. Lee `policy.conf` y calcula la ventana de hoy (`Wk` = lun–vie, `Wd` = sáb–dom).
2. **Guard de resume:** si hubo un resume hace menos de `RESUME_GRACE` (60 s), se salta la
   pasada (evita matar la sesión mientras la GPU se reanuda).
3. Dentro de la ventana: avisa al entrar y a los `WARN_MINUTES`.
4. Fuera de la ventana y con sesión activa: `loginctl terminate-user` y luego
   `recover_greeter` (watchdog).
5. El estado vive en `/run/focusguard` (tmpfs), así que se limpia en cada arranque.

## Verificar

```bash
bash -n /usr/local/bin/focusguard-enforce

# Simulacion sin expulsar a nadie
sudo DRY_RUN=1 /usr/local/bin/focusguard-enforce && echo "dry-run OK"
sudo journalctl -t focusguard -n 10 --no-pager

systemctl list-timers 'focusguard*' --no-pager
systemctl is-enabled focusguard-resume.service
```

Prueba real (controlada): inicia sesión con el usuario restringido en su ventana, deja que
termine, y observa:

```bash
journalctl -f -t focusguard -u sddm -u display-manager
```

Debe expulsar y **volver el greeter** de SDDM (no una pantalla negra).

## Rollback

```bash
sudo systemctl disable --now focusguard-enforce.timer focusguard-resume.service
sudo rm -f /etc/systemd/system/focusguard-enforce.service \
           /etc/systemd/system/focusguard-enforce.timer \
           /etc/systemd/system/focusguard-resume.service \
           /usr/local/bin/focusguard-enforce
sudo systemctl daemon-reload
```

## Notas de diseño (léelas antes de tocar el código)

- **NUNCA expulsar con `pkill -KILL -u`.** Matar la sesión a lo bruto hace que el *helper*
  de SDDM salga con error; SDDM cree que el cierre fue anómalo y **no vuelve a levantar el
  greeter** → pantalla negra con un `_` parpadeando. Usa `loginctl terminate-user`: cierra
  ordenadamente y escala solo. (Este bug está documentado en `docs/learning/02-enforce.md`.)
- **Watchdog `recover_greeter`:** tras expulsar, espera a que (a) el usuario ya no tenga
  sesión y (b) exista una sesión en un *seat* (el greeter). Si en 40 s no ocurre, reinicia
  `display-manager.service`. Nunca más te quedas atrapado.
- **Guard de resume:** el incidente original ocurrió **justo al abrir la tapa**, mientras el
  DRM se reinicializaba. Saltarse la primera pasada tras un resume elimina esa carrera.
- **Estado `killed`:** evita expulsar en bucle; se limpia al entrar en una ventana nueva.
- **`DRY_RUN=1`** permite simular todo sin expulsar a nadie.
