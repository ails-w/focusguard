# Modelo de amenaza

Documentar lo que un sistema **no** protege es parte del contrato.

## Supuesto de diseño

Pensado para **autocontrol**: que *tú* no uses la cuenta restringida fuera de su horario.
**No** está pensado contra un atacante con root, y no pretende serlo.

## Qué protege

| Intento de bypass | Qué lo detiene | Capa |
|---|---|---|
| Iniciar sesión fuera de la ventana | `pam_time` | 1 |
| `sudo` fuera de la ventana | `pam_time` (servicio `sudo`) | 1 |
| Quedarse dentro tras el cierre | `loginctl terminate-user` | 2 |
| Volver a entrar tras la expulsión | `pam_time` | 1 |
| Editar `policy.conf` / `time.conf` | `chattr +i` + verificación cada minuto | 3 |
| Desarmar "sin pensar" | frase + 60 s de espera + auditoría | 4 |

## Qué NO protege

| Límite | Por qué |
|---|---|
| **Root** | Puede `chattr -i`, parar timers, editar la golden y borrar logs. |
| **`sudo` sin contraseña (`NOPASSWD`)** | Bypass total: el usuario restringido se vuelve root cuando quiera. |
| **Grupos potentes** (`docker`, `wheel` con reglas) | `docker` ≈ root (montar `/` y editar desde un contenedor). |
| **Otro administrador** | Cualquier cuenta con `sudo` puede desarmar; queda auditado, pero puede. |
| **Acceso físico / live USB** | Puede editar el disco desde otro sistema. |
| **Cambiar el reloj del sistema** | `pam_time` y el timer dependen de la hora. |
| **Arranque en modo rescate / single user** | Evita PAM y systemd. |
| **Ya estar dentro con root al cerrar la ventana** | Podría parar el timer antes de la pasada. |

## Si necesitas una barrera (y no autocontrol)

- Quítale `sudo`, `wheel` y grupos potentes a la cuenta restringida.
- Restringe el arranque alternativo (contraseña de BIOS, sin medios externos) — fuera de
  alcance de este proyecto.
- Mueve el control fuera del equipo (router, tercero, cuenta gestionada).

La promesa correcta de `focusguard` es: **fricción + reversión + auditoría**.
