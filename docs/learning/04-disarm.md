# Módulo 04 — Disarm

Cómo se apaga el sistema de forma **deliberada** en vez de a los golpes. Poca línea de
código, mucha filosofía.

> Implementación → [`modules/04-disarm/`](../../modules/04-disarm/README.md)

## Glosario del módulo

| Término | Qué significa (en una línea) |
|---|---|
| `disarm` | Bajar timers y quitar la inmutabilidad para poder editar. |
| `stop` vs `disable` | Parar ahora vs no volver a arrancar en el próximo boot. |
| auditoría | Registro de quién hizo qué y cuándo. |

## Mapa de conceptos

```text
  disarm (1) ──▶ sudo + frase + 60 s ──▶ stop timers + chattr -i ──▶ audit (2)
       │
       └─ stop ≠ disable (3)  ← la trampa del reboot
       │
       └─ no sourcea policy (4)  ← debe funcionar con la config rota
```

---

## 1. Por qué existe una salida deliberada

### En una frase

Un bloqueo de autocontrol sin salida limpia se termina rompiendo de forma caótica; con
salida, se apaga en orden y queda registrado.

### Fundamentos previos

- Todo el proyecto.

### Qué es

`focusguard-disarm` es el **único** camino previsto para desactivar el sistema. No borra
nada: detiene los timers y quita `+i`.

### Qué problema resuelve

La alternativa realista a "tener un disarm" no es "nunca lo desactivaré", sino "lo
desactivaré a las apuradas" (matando timers, borrando archivos, arrancando en modo rescate).
Eso deja el sistema en un estado inconsistente y sin registro.

### Cómo funciona paso a paso

1. Exige `sudo` (root).
2. Pide escribir una **frase** de confirmación.
3. Espera **60 segundos** (cancelable con Ctrl+C).
4. Detiene los timers y quita `+i` de los archivos protegidos.
5. Registra en `journald` y en el log.

### Qué se rompería sin esto

Se pierde la reversibilidad controlada: el candado se vuelve un estorbo y se rompe sucio.

### Error común

**Automatizar el disarm** (un script que responda la frase solo). Ahí se pierde todo el
valor: la fricción **es** la función.

### Para profundizar

- Módulo 03.

---

## 2. Frase + espera + auditoría

### En una frase

Tres fricciones baratas que convierten un impulso en una decisión.

### Fundamentos previos

- La salida deliberada (1).

### Qué es

- **Frase** (`desarmar`): obliga a leer y escribir, no solo a pulsar Enter.
- **Espera** de 60 s: da tiempo a arrepentirse.
- **Auditoría**: `fg_audit "disarm user=…"` (o `disarm-aborted`).

### Qué problema resuelve

El 90 % de las desactivaciones impulsivas se caen solas al tener que esperar un minuto.

### Cómo funciona paso a paso

1. Se imprime la advertencia y la frase esperada.
2. Si no coincide → `disarm-aborted` y salida.
3. Si coincide → cuenta regresiva de 60 s.
4. Al terminar, desbloquea y registra.

### Qué se rompería sin esto

Un `disarm` de un solo Enter se usaría a la primera incomodidad.

### Error común

**Poner una frase trivial o aceptar Enter vacío.** El valor está en que sea incómodo.

### Para profundizar

- `journalctl -t focusguard` y `/var/log/focusguard/audit.log`.

---

## 3. `stop` ≠ `disable` (la trampa del reboot)

### En una frase

`disarm` **para** los timers, pero no los deshabilita: si reinicias antes de rearmar, el
candado vuelve y revierte tus cambios.

### Fundamentos previos

- systemd timers y `chattr` (ver [`00-fundamentos.md`](00-fundamentos.md)).

### Qué es

`systemctl stop` detiene la unidad en la sesión actual; `systemctl disable` impide que
arranque en el próximo boot. `focusguard-disarm` hace lo primero.

### Qué problema resuelve

Mantener la fricción: desarmar "para siempre" requiere un paso extra explícito.

### Cómo funciona paso a paso

1. `disarm` → `stop` + `chattr -i`.
2. Editas `policy.conf`.
3. Si reinicias antes de `lock`: al arrancar, el timer corre, la integridad ve que el archivo
   difiere de la golden y **restaura la versión vieja**. Pierdes los cambios.
4. Flujo correcto: editar, `apply`, `lock` y `start` en la **misma sesión**.

### Qué se rompería sin esto

Si `disarm` también hiciera `disable`, sería demasiado fácil apagar el sistema "de una" — y
no volvería solo.

### Error común

**Desarmar un día y editar al siguiente.** En el medio, el candado volvió y revirtió todo
(o te encontraste con archivos inmutables otra vez).

### Para profundizar

- `man 1 systemctl` (`stop` vs `disable`).

---

## 4. No sourcea `policy.conf` (a propósito)

### En una frase

El interruptor de emergencia debe funcionar aunque la configuración esté rota.

### Fundamentos previos

- `policy.conf` es un archivo de shell (ver [`00-fundamentos.md`](00-fundamentos.md)).

### Qué es

Todos los demás scripts hacen `. /etc/focusguard/policy.conf`. `disarm` **no**.

### Qué problema resuelve

Si editaste `policy.conf` y dejaste una comilla sin cerrar, `enforce`/`render` fallarán —
pero necesitas poder desarmar para arreglarlo. Un interruptor que depende del archivo que
vas a reparar no sirve.

### Cómo funciona paso a paso

1. `disarm` solo sourcea `common.sh` (que no puede romperse al editar tu política).
2. Desbloquea y sale.

### Qué se rompería sin esto

Quedarías atrapado: no puedes desarmar porque `policy.conf` está roto, y no puedes arreglar
`policy.conf` porque está inmutable.

### Error común

**"Mejorar" `disarm` sourceando la política** para mostrar el nombre del usuario en el
mensaje. Suena inofensivo y rompe el caso de emergencia.

### Para profundizar

- `man 1 bash` (`.` / `source`).
