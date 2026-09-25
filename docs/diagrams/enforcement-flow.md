# Flujo de enforcement

Una pasada de `focusguard-enforce` (cada minuto):

```mermaid
flowchart TD
    T["timer: cada minuto (:00)"] --> R{"¿hubo resume<br/>hace menos de 60 s?"}
    R -->|"sí"| SKIP["skip<br/>(guard de resume)"]
    R -->|"no"| W{"¿dentro de la ventana?"}
    W -->|"sí"| A["avisar al entrar<br/>y a los WARN_MINUTES"]
    W -->|"no"| C{"¿hay sesión activa?"}
    C -->|"no"| N["nada que hacer"]
    C -->|"sí"| K["loginctl terminate-user"]
    K --> G["recover_greeter<br/>(watchdog)"]
    G -->|"greeter vuelve"| OK["fin"]
    G -->|"40 s sin greeter"| DM["systemctl restart<br/>display-manager"]
```

El estado (`/run/focusguard`, tmpfs) hace la pasada idempotente:

| Archivo | Para qué |
|---|---|
| `session` | detectar el inicio de sesión (aviso de bienvenida) |
| `window` | saber si ya se entró en esta ventana (limpiar avisos) |
| `warn-<m>` | no repetir el aviso de "faltan m minutos" |
| `killed` | no expulsar en bucle |
| `resumed` | guard de resume |
