# Fundamentos

Antes de los módulos: el vocabulario y las piezas de sistema que `focusguard` combina.

## Glosario global

| Término | Qué significa (en una línea) |
|---|---|
| **PAM** | Capa que decide quién entra y qué puede hacer, en cualquier servicio. |
| **`pam_time`** | Módulo PAM que permite/niega el acceso según hora, día, servicio y usuario. |
| **`time.conf`** | Archivo de reglas de `pam_time`. |
| **`chattr`** | Cambia *atributos* de archivo (no permisos); `+i` = inmutable. |
| **timer (systemd)** | Unidad que dispara otra según un horario. |
| **oneshot** | Servicio que corre, termina y no queda residente. |
| **logind** | Gestor de sesiones de systemd (`loginctl`). |
| **display manager** | El programa que muestra el login gráfico (SDDM, GDM…). |
| **greeter** | La pantalla de login del display manager. |
| **VT** | Virtual terminal (tty1, tty2…). |

## Mapa de conceptos

```text
  PAM (1) ──usa──▶ pam_time (2) ──lee──▶ time.conf
     │
     └── fase "account" ──▶ niega login/sudo fuera de la ventana

  systemd timers (3) ──disparan──▶ enforce ──▶ logind ──▶ cierra la sesión
                                     │
                                     └── chattr +i (4) protege la config

  ciclo de sesión (5)  ←── entenderlo es lo que evita la pantalla negra
```

---

## 1. PAM

### En una frase

PAM es la capa que separa *qué* se pide de *cómo* se verifica: los programas preguntan y PAM resuelve.

### Fundamentos previos

Nada. Es la base del control de acceso en Linux.

### Qué es

Una biblioteca (`libpam`) y un conjunto de módulos. Cada programa (`login`, `sshd`, `sudo`,
`gdm`…) llama a PAM diciendo *"soy el servicio X, el usuario es Y"*, y PAM ejecuta los
módulos configurados en `/etc/pam.d/X`, en **cuatro fases**: `auth`, `account`, `session`,
`password`.

### Qué problema resuelve

Sin PAM, cada programa implementaría su propia lógica de autenticación. Con PAM, la política
de acceso se define **una vez** y aplica a todos.

### Cómo funciona paso a paso

1. Un programa llama a PAM con su nombre de servicio.
2. PAM lee `/etc/pam.d/<servicio>` (y sus `include`).
3. Ejecuta los módulos en orden, fase por fase.
4. La fase `account` responde: *"¿puede usarse esta cuenta **ahora**?"*.

### Qué se rompería sin esto

No habría un punto único para negar el acceso según reglas (horario, caducidad, etc.).

### Para qué sirve aquí

`focusguard` no autentica nada: usa la fase **`account`** para decir *"este usuario no
puede, a esta hora"*. Es la fase correcta porque un horario no es un secreto.

### Cómo se usa (archivos reales)

```bash
grep -n pam_time /etc/pam.d/system-auth
# account    required    pam_time.so
```

### Error común

**Creer que hay que tocar `/etc/pam.d/*`.** Normalmente el módulo ya está incluido; solo
falta *decirle qué reglas* (`time.conf`). Detectar: si `pam_time.so` no aparece en la fase
`account`, primero agrégalo ahí.

### Para profundizar

- `man 5 pam.d`, `man 8 pam_time`.

---

## 2. `pam_time` y `time.conf`

### En una frase

Un módulo PAM que permite o niega el acceso según servicio, terminal, usuario y horario.

### Fundamentos previos

- PAM (1).

### Qué es

`pam_time` lee `/etc/security/time.conf`. Cada línea tiene cuatro campos:

```text
servicios;ttys;usuarios;horarios
```

### Qué problema resuelve

Restringir una cuenta a ciertas franjas horarias **sin tocar cada aplicación**: aplica al
login gráfico, a la consola, a ssh y a `sudo` a la vez.

### Cómo funciona paso a paso

1. Una regla **solo se activa** si coinciden servicio + tty + usuario.
2. Si se activa, permite **solo dentro** de las franjas listadas; fuera, niega.
3. Los horarios se combinan con `|` (o) y `&` (y), cada uno con prefijo de día.

### Qué se rompería sin esto

Sin puerta PAM, el timer solo expulsa a quien ya está dentro: el usuario podría volver a
entrar al instante.

### Para qué sirve aquí

Es la capa 1, la puerta. Y por incluir `sudo`, también evita la escalada de privilegios
fuera de la ventana.

### Cómo se usa (archivos reales)

```text
# /etc/security/time.conf
sddm|login|sshd|sudo;*;alice;Wk0700-0900 | Wk1800-2200 | Wd1000-1400
```

### Error común

**La trampa `Wk`/`Wd`.** `Wk` = *week* (lun–vie) y `Wd` = *weekend* (sáb–dom). Parece al
revés porque `Wk` suena a "weekend". Verificado en `pam_time.c`. Otro error: creer que
`pam_time` **expulsa** sesiones abiertas — no lo hace, solo niega al autenticar.

### Para profundizar

- `man 5 time.conf`; módulo 01.

---

## 3. systemd: `oneshot` + `timer`

### En una frase

Un *.timer* dispara un *.service* `oneshot` cada minuto; el servicio corre y muere.

### Fundamentos previos

Nada de systemd. La idea de "tarea periódica" alcanza.

### Qué es

Un timer con `OnCalendar=*-*-* *:*:00` dispara en el segundo 0 de cada minuto. `Type=oneshot`
significa que el servicio hace su trabajo y termina: **no hay daemon residente**.

### Qué problema resuelve

Correr tareas periódicas sin cron, con logs en `journald` y dependencias declaradas.

### Cómo funciona paso a paso

1. El timer se arma y espera.
2. Al llegar el horario, systemd arranca el service como root.
3. El script decide (¿dentro de la ventana?) y sale.
4. `AccuracySec=1s` evita que systemd agrupe disparos y los corra tarde.

### Qué se rompería sin esto

La expulsión dependería de que alguien la ejecute a mano.

### Para qué sirve aquí

Es el "reloj" del módulo 02 y del 03.

### Cómo se usa (archivos reales)

```bash
systemctl list-timers 'focusguard*' --no-pager
```

### Error común

**Llamarlo "daemon".** No hay proceso residente. Otro error clásico: un `ExecStart` con un
typo hace fallar el service con `203/EXEC` y el timer sigue "activo" — parece que funciona
y no hace nada.

### Para profundizar

- `man 5 systemd.timer`, `man 5 systemd.service`.

---

## 4. `chattr`: atributos de archivo

### En una frase

`chmod` controla permisos; `chattr` controla *atributos* del inodo, y `+i` hace que ni root
pueda editar sin quitarlo primero.

### Fundamentos previos

Nada especial.

### Qué es

Banderas guardadas en el inodo, al nivel del filesystem. `+i` (immutable): no modificar,
borrar ni renombrar. `+a`: solo agregar al final.

### Qué problema resuelve

Añade una capa más fuerte que `rwx`: editar requiere un paso deliberado y visible.

### Cómo funciona paso a paso

1. `chattr +i archivo` marca el inodo.
2. Cualquier escritura falla con `Operation not permitted`.
3. Para editar: `chattr -i`, editar, `chattr +i`.

### Qué se rompería sin esto

Editar la configuración sería trivial; la integridad igual restauraría, pero sin el freno
previo.

### Para qué sirve aquí

Es la mitad "fricción" del módulo 03.

### Cómo se usa (archivos reales)

```bash
lsattr /etc/security/time.conf
# ----i----------------- /etc/security/time.conf
```

### Error común

**Creer que protege contra root.** Root tiene `CAP_LINUX_IMMUTABLE` y puede quitarlo. Es
fricción, no frontera.

### Para profundizar

- `man 1 chattr`; módulo 03.

---

## 5. Ciclo de sesión y display manager

### En una frase

Entender cómo muere una sesión gráfica (y qué espera el display manager) es lo que separa
"expulsar bien" de "pantalla negra".

### Fundamentos previos

- PAM (1), timers (3).

### Qué es

El recorrido: VT → display manager → greeter → autenticación (`sddm-helper`) → sesión de
usuario (con su compositor) → cierre → vuelta al greeter.

### Qué problema resuelve

Saber **quién** decide relanzar el greeter y qué necesita para hacerlo bien.

### Cómo funciona paso a paso

1. SDDM muestra el greeter en una VT.
2. Al autenticar, lanza un `sddm-helper` que arranca la sesión del usuario.
3. La sesión corre (Hyprland + `uwsm`, por ejemplo) en esa VT.
4. Al terminar **ordenadamente**, el helper sale con 0 y SDDM **relanza el greeter**.
5. Si el helper sale con error (p. ej., porque mataste todo con `SIGKILL`), SDDM puede
   quedarse sin relanzar el greeter → **pantalla negra**.

### Qué se rompería sin esto

Es exactamente el bug del proyecto: `pkill -KILL -u` rompía el paso 4 y dejaba el 5 a medias.

### Para qué sirve aquí

Es el corazón del módulo 02: usar `logind`, y tener un watchdog por si SDDM igual falla.

### Cómo se usa (archivos reales)

```bash
loginctl terminate-user alice      # cierre ordenado
journalctl -u sddm -n 20 --no-pager
```

### Error común

**Mandar `SIGKILL` a toda la sesión.** Parece "más efectivo" y es justo lo que rompe el
ciclo. Detectar: pantalla negra con `_` tras la expulsión, y `sddm-helper ... exited with 1`
en el journal.

### Para profundizar

- Módulo 02 y [`../diagrams/session-lifecycle.md`](../diagrams/session-lifecycle.md).

---

## 6. Modelo de privilegios

### En una frase

Quien puede `sudo` es, en la práctica, root — y `focusguard` es autocontrol, no un muro.

### Fundamentos previos

- Todo lo anterior.

### Qué es

El alcance real de la protección según los privilegios del usuario restringido.

### Qué problema resuelve

Evita falsas expectativas: si el usuario restringido tiene `sudo` (o `NOPASSWD`, o el grupo
`docker`), puede desactivar el bloqueo.

### Cómo funciona paso a paso

1. `sudo` con contraseña pasa por `pam_time` → **también** queda restringido por horario.
2. `NOPASSWD` **no** pregunta → bypass.
3. El grupo `docker` ≈ root → bypass (montar `/` y editar).

### Qué se rompería sin esto

Prometer "imposible de saltar" cuando es "difícil y auditado".

### Para qué sirve aquí

Define el contrato honesto del proyecto (ver `docs/threat-model.md`).

### Cómo se usa (archivos reales)

```bash
sudo -l -U alice        # que puede hacer el usuario restringido
```

### Error común

**Dejar `NOPASSWD` o grupos potentes al usuario restringido.** Detectarlo con `sudo -l -U`.

### Para profundizar

- [`../threat-model.md`](../threat-model.md).
