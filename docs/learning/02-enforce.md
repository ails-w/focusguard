# Módulo 02 — Enforcement

Cómo se expulsa, cada minuto, a quien quedó dentro de su sesión al terminar la ventana — y
**cómo NO hacerlo** (el bug de la pantalla negra).

> Implementación → [`modules/02-enforce/`](../../modules/02-enforce/README.md)

## Glosario del módulo

| Término | Qué significa (en una línea) |
|---|---|
| `loginctl` | Herramienta para gestionar sesiones de systemd-logind. |
| `terminate-user` | Cierre ordenado de todas las sesiones de un usuario. |
| helper | Proceso que lanza el display manager para una sesión. |
| greeter | Pantalla de login del display manager. |
| resume | Reanudación tras suspender el equipo. |
| `DRY_RUN` | Modo que simula sin expulsar a nadie. |

## Mapa de conceptos

```text
  cada minuto (timer)
        │
        ├─ ¿vencina de resume? ──▶ skip (4)
        │
        ├─ dentro de ventana ──▶ avisa (1)
        │
        └─ fuera + sesión ──▶ loginctl terminate-user (2) ──▶ watchdog (3)
```

---

## 1. El reloj: ventana, avisos y disparo

### En una frase

Cada minuto se recalcula si estás dentro de la ventana; si no, y hay sesión, se dispara la
expulsión.

### Fundamentos previos

- Timers de systemd (ver [`00-fundamentos.md`](00-fundamentos.md), concepto 3).

### Qué es

`focusguard-enforce` calcula `inside` comparando la hora actual con las ventanas del día
(`ALLOWED_WD` en semana, `ALLOWED_WK` en fin de semana).

### Qué problema resuelve

No necesitas un daemon: el estado se recalcula en cada pasada, y el estado temporal vive en
`/run/focusguard` (tmpfs, se limpia en cada arranque).

### Cómo funciona paso a paso

1. Lee `policy.conf` y arma las ventanas del día.
2. Si está dentro: avisa al iniciar sesión y a los `WARN_MINUTES`.
3. Si está fuera y hay sesión: cierra (concepto 2).
4. Marca `/run/focusguard/killed` para no repetir; se limpia al entrar en una ventana nueva.

### Qué se rompería sin esto

Nadie cerraría la sesión al terminar la ventana.

### Error común

**Ventanas que cruzan medianoche.** El chequeo `now >= inicio && now < fin` no soporta
`2300-0200`. Si necesitas eso, hay que partir la ventana en dos.

### Para profundizar

- `man 1 loginctl`.

---

## 2. El bug de la pantalla negra (lo más importante del módulo)

### En una frase

Expulsar con `pkill -KILL -u` deja al display manager sin greeter; hay que usar
`loginctl terminate-user`.

### Fundamentos previos

- Ciclo de sesión y display manager (ver [`00-fundamentos.md`](00-fundamentos.md), concepto 5).

### Qué es

La secuencia **incorrecta** que tenía la primera versión:

```bash
pkill -TERM -u "$USER" || true
sleep 5
pkill -KILL -u "$USER" || true
loginctl terminate-user "$USER" || true
```

y su síntoma: **pantalla negra con un `_` parpadeando**, como si el greeter no arrancara.

### Qué problema resuelve (el correcto)

La secuencia correcta:

```bash
loginctl terminate-user "$USER" || true
recover_greeter
```

`terminate-user` pide a logind un cierre **ordenado**: el helper de SDDM sale con 0, SDDM
entiende que la sesión terminó bien y **relanza el greeter**.

### Cómo funciona paso a paso (la evidencia real)

1. Al reanudar de un suspend, el timer dispara y expulsa.
2. Con `pkill -KILL`, el helper de SDDM muere a la fuerza → el journal registra
   `sddm-helper ... exited with 1` (`ERROR_INTERNAL "Process crashed"`).
3. SDDM no relanza el greeter (además, con el DRM recién reinicializado tras el resume).
4. Resultado: pantalla negra. Sin nada que recupere, te quedas atrapado.

### Qué se rompería sin esto

La expulsión "funciona" (el usuario sale) pero el equipo queda inutilizable hasta apagarlo a
la fuerza.

### Cómo se usa (archivos reales)

```bash
grep -n 'terminate-user\|pkill' /usr/local/bin/focusguard-enforce
```

### Error común

**Pensar que `SIGKILL` es "más seguro".** Es más *brutal*, no más correcto: rompe el
protocolo entre sesión y display manager. Detectar: `exited with 1` en `journalctl -u sddm`.

### Para profundizar

- [`../diagrams/session-lifecycle.md`](../diagrams/session-lifecycle.md).

---

## 3. Watchdog del greeter

### En una frase

Tras expulsar, verifica que el greeter vuelva; si en 40 s no vuelve, reinicia el display
manager.

### Fundamentos previos

- El ciclo de sesión (concepto 2).

### Qué es

`recover_greeter()` espera en pasos de 2 segundos a que se cumplan **dos** condiciones:

1. el usuario expulsado ya no tiene sesión (`loginctl show-user` falla), y
2. existe alguna sesión en un *seat* (el greeter).

Si no ocurre en ~40 s, `systemctl restart display-manager.service`.

### Qué problema resuelve

Convierte "pantalla negra y reinicio forzado" en "recuperación automática".

### Cómo funciona paso a paso

1. `loginctl terminate-user` (cierre ordenado).
2. `recover_greeter` espera a que la sesión muera y aparezca el greeter.
3. Si el greeter aparece → fin, nada más.
4. Si no → reinicia el display manager.

### Qué se rompería sin esto

Volverías a depender de que SDDM se recupere solo (y ya vimos que no siempre lo hace).

### Error común

**Dos detalles que arruinan el watchdog:**
(a) filtrar por "hay alguna sesión en un seat" **sin** esperar a que el usuario salga → la
sesión moribunda todavía aparece y da falso OK;
(b) escribir mal el comando (`greep` en vez de `grep`) → la condición nunca se cumple y el
watchdog **reinicia el display manager siempre**, expulsando también al administrador.

### Para profundizar

- `man 1 systemctl` (`restart display-manager`).

---

## 4. Guard de resume

### En una frase

Si hubo un resume hace menos de 60 s, se salta la pasada: no se mata la sesión mientras la
GPU se reanuda.

### Fundamentos previos

- Suspend/resume en Linux; el ciclo de sesión (2).

### Qué es

Un unit (`focusguard-resume.service`) que, al reanudar, toca `/run/focusguard/resumed`.
`enforce` compara la fecha del archivo y, si es reciente, no hace nada.

### Qué problema resuelve

El incidente original ocurrió **justo al reanudar**, con el DRM reinicializándose. Matar la
sesión en ese instante es lo que disparó el fallo del greeter.

### Cómo funciona paso a paso

1. `suspend.target` se alcanza al reanudar.
2. El unit corre y crea el marcador.
3. La siguiente pasada de `enforce` ve `age < 60` y sale.
4. Un minuto después, ya reanudado, actúa normal.

### Qué se rompería sin esto

La expulsión coincidiría con el resume (la peor ventana posible), aumentando el riesgo de
pantalla negra.

### Error común

**Poner `RESUME_GRACE=0` "para que sea inmediato".** Justamente el caso que queremos evitar.

### Para profundizar

- `man 5 systemd.special` (`suspend.target`).

---

## 5. Estado y `DRY_RUN`

### En una frase

Todo el estado temporal vive en `/run/focusguard`, y con `DRY_RUN=1` puedes simular sin
expulsar a nadie.

### Fundamentos previos

- Todo lo anterior.

### Qué es

Archivos de estado: `session`, `window`, `warn-*`, `killed`, `resumed`. En `/run` (tmpfs),
así que no sobreviven un reinicio.

### Qué problema resuelve

Idempotencia: no repetir avisos ni expulsar en bucle; y poder probar sin consecuencias.

### Cómo funciona paso a paso

1. `killed` evita expulsar dos veces en la misma ventana; se limpia al entrar en una nueva.
2. `DRY_RUN=1` registra `stop ... dry_run=1` y **no** ejecuta `terminate-user`.
3. `POLICY` permite apuntar a otra config en pruebas.

### Qué se rompería sin esto

`DRY_RUN` es lo que te deja iterar sin romperle la sesión a nadie.

### Error común

**Probar en producción sin `DRY_RUN`.** Úsalo siempre primero; el flujo completo se prueba
después, de forma controlada.

### Para profundizar

- Módulo 03: la integridad protege `policy.conf`, así que para editarla usa `disarm`.
