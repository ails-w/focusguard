# Arquitectura

`focusguard` limita una cuenta de Linux a una **ventana horaria** con tres mecanismos
independientes que actúan en momentos distintos:

| # | Capa | Actúa... | Módulo |
|---|------|----------|--------|
| 1 | Puerta PAM | al **entrar** (login gráfico, consola, ssh, `sudo`) | `01-pam-gate` |
| 2 | Enforcement | mientras hay una **sesión abierta** | `02-enforce` |
| 3 | Integridad | **siempre** (vigila la configuración) | `03-integrity` |

Y dos piezas de soporte: `00-base` (configuración única + auditoría) y `04-disarm` (el
interruptor de rollback).

## Mapa

```text
        ┌───────────────────────────────────────────────────────┐
        │  /etc/focusguard/policy.conf   (fuente única)         │
        └───────────────┬───────────────────────────────────────┘
                        │
        ┌───────────────┴────────────────┐
        ▼                                ▼
  focusguard-render                focusguard-enforce
        │ genera                         │ cada minuto
        ▼                                ▼
  /etc/security/time.conf          ¿dentro de la ventana?
  (pam_time: login, ssh, sudo)       ├── sí → avisa / recuerda
                                     └── no → loginctl terminate-user
                                              + watchdog del greeter
        ▲                                ▲
        └───────────────┬────────────────┘
                        │
              focusguard-integrity (cada minuto)
              golden + chattr +i → restaura y re-bloquea
```

## Ciclo de vida de una sesión

1. **Login dentro de la ventana:** `pam_time` deja pasar. `focusguard-enforce` avisa
   "uso permitido hasta las HH:MM".
2. **Recordatorios:** a los minutos definidos en `WARN_MINUTES` (60/30/15/5 por defecto).
3. **Fin de la ventana:** `loginctl terminate-user` cierra la sesión **ordenadamente**, y el
   watchdog verifica que el greeter del display manager vuelva.
4. **Fuera de la ventana:** `pam_time` niega login y `sudo`; el timer no tiene nada que hacer.

## Decisiones clave

- **¿Por qué PAM y no solo un timer?** El timer solo expulsa a quien ya entró. Sin la puerta
  PAM, el usuario podría volver a entrar un segundo después.
- **¿Por qué incluir `sudo` en los servicios?** Sin eso, el usuario restringido podría
  escalar a root dentro de su ventana y desactivar el bloqueo.
- **¿Por qué `loginctl terminate-user` y no `pkill -KILL -u`?** Matar la sesión a lo bruto
  hace que el helper de SDDM salga con error y el greeter **no vuelva** (pantalla negra).
  Historia completa en [`learning/02-enforce.md`](learning/02-enforce.md).
- **¿Por qué `chattr +i`?** Es **fricción deliberada** + reversión automática + auditoría.
  No es una frontera contra root: ver [`threat-model.md`](threat-model.md).
- **¿Por qué un módulo de `disarm`?** Un bloqueo de autocontrol sin salida deliberada se
  rompe de forma caótica. Con salida, se apaga limpio y queda registrado.

## Interacción con el display manager

`focusguard` **no** habla con SDDM: cierra la sesión vía `logind` y deja que SDDM relance el
greeter. El watchdog `recover_greeter` solo interviene si ese paso no ocurre. Flujo completo
en [`diagrams/session-lifecycle.md`](diagrams/session-lifecycle.md).
