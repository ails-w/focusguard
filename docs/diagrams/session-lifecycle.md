# Ciclo de sesión

Cómo muere una sesión gráfica y por qué el **cómo** importa tanto.

## Forma correcta (lo que hace el repo)

```mermaid
sequenceDiagram
    participant U as Usuario
    participant SDDM as SDDM (greeter)
    participant H as sddm-helper
    participant S as Sesión (Hyprland / uwsm)
    participant LG as logind
    participant FG as focusguard-enforce

    U->>SDDM: login (dentro de la ventana)
    SDDM->>H: lanza la sesión
    H->>S: inicia el compositor
    Note over FG: cada minuto
    FG->>S: avisos (60/30/15/5)
    Note over FG: fin de la ventana
    FG->>LG: loginctl terminate-user
    LG->>S: cierre ordenado
    S-->>H: sale limpio (exit 0)
    H-->>SDDM: sesión terminada
    SDDM->>SDDM: relanza el greeter
    Note over FG: watchdog
    FG->>LG: ¿usuario sin sesión? ¿hay greeter?
    LG-->>FG: sí → nada más que hacer
```

## Forma incorrecta (el bug de la pantalla negra)

```mermaid
sequenceDiagram
    participant SDDM as SDDM (greeter)
    participant H as sddm-helper
    participant S as Sesión
    participant FG as focusguard-enforce

    FG->>S: pkill -KILL -u
    S--xH: el helper muere a la fuerza (exit 1)
    Note over SDDM: "Process crashed"<br/>no relanza el greeter
    Note over SDDM: pantalla negra con "_"
```

## La lección

El display manager no observa "el usuario se fue": observa **cómo salió su helper**. Un
cierre ordenado (0) dispara el relanzado del greeter; un cierre anómalo (1) lo deja colgado.

Por eso el módulo 02:

1. usa `loginctl terminate-user` (ordenado),
2. tiene un **watchdog** por si igual falla, y
3. tiene un **guard de resume** para no hacerlo justo cuando el DRM se reanuda.
