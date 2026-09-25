# Módulo 01 — PAM gate

Cómo se convierte una ventana horaria en una **regla de sistema** que niega el login y el
`sudo`. Es la capa que impide *entrar*.

> Implementación → [`modules/01-pam-gate/`](../../modules/01-pam-gate/README.md)

## Glosario del módulo

| Término | Qué significa (en una línea) |
|---|---|
| `time.conf` | Reglas de `pam_time`: `servicios;ttys;usuarios;horarios`. |
| `Wk` / `Wd` | Semana (lun–vie) / fin de semana (sáb–dom). |
| `render` | Script que convierte `policy.conf` en la línea de `pam_time`. |

## Mapa de conceptos

```text
  policy.conf ──(render)──▶ línea de time.conf ──▶ pam_time (fase account)
                                                      │
                                                      ├─ login gráfico → denegado
                                                      ├─ ssh            → denegado
                                                      └─ sudo           → denegado
```

---

## 1. La regla aplicada

### En una frase

Una sola línea de `time.conf` controla **cuatro** vías de entrada a la vez.

### Fundamentos previos

- PAM y `pam_time` (ver [`00-fundamentos.md`](00-fundamentos.md), conceptos 1 y 2).

### Qué es

La línea generada:

```text
sddm|login|sshd|sudo;*;alice;Wk0700-0900 | Wk1800-2200 | Wd1000-1400
```

### Qué problema resuelve

Sin esto, el usuario expulsado podría volver a entrar de inmediato, o entrar fuera de
ventana si nunca llegó a estarlo.

### Cómo funciona paso a paso

1. El servicio (p. ej. `sddm`) llama a PAM.
2. PAM evalúa la fase `account` → `pam_time` lee `time.conf`.
3. Si el usuario está listado y la hora está **fuera** de las franjas → **deniega**.
4. Si la hora está dentro → deja pasar.

### Qué se rompería sin esto

Solo quedaría el timer: expulsa, pero el usuario vuelve a entrar.

### Error común

**Poner `*` en usuarios** para "ampliar". `*` no significa "cualquiera": las reglas solo se
activan si **coinciden los cuatro campos**. Una regla que "no hace nada" suele ser un campo
mal escrito (tty o usuario).

### Para profundizar

- `man 5 time.conf`.

---

## 2. Render: de `policy.conf` a `time.conf`

### En una frase

Un solo archivo manda: `render` traduce la política y `apply` escribe el bloque en `time.conf`.

### Fundamentos previos

- La regla aplicada (1).

### Qué es

`focusguard-render` lee `policy.conf` (que se *sourcea*) y **imprime** la línea de
`pam_time`. `focusguard-apply` la mete en `/etc/security/time.conf` entre marcadores:

```text
# BEGIN focusguard
sddm|login|sshd|sudo;*;alice;...
# END focusguard
```

### Qué problema resuelve

Evita editar dos archivos a mano y que se desincronicen (la política en un lugar, la regla
efectiva en otro).

### Cómo funciona paso a paso

1. `. policy.conf` carga las variables.
2. Por cada ventana de `ALLOWED_WD` se agrega `Wk<ventana>`; por cada una de `ALLOWED_WK`,
   `Wd<ventana>`, separadas por ` | `.
3. `printf` imprime la línea.
4. `apply` hace un `awk` que elimina el bloque viejo y escribe el nuevo, sin tocar el resto
   del archivo.

### Qué se rompería sin esto

Editarías `time.conf` a mano; cualquier cambio de horario podría quedar a medias (policy
cambiada, regla vieja).

### Error común

**Correr `render` con un `policy.conf` roto.** Al ser un archivo de shell, una comilla mal
puesta rompe todo. Detectar: `bash -n /etc/focusguard/policy.conf`.

### Para profundizar

- Módulo 03 (integridad): `focusguard-apply` corre **antes** de `focusguard-lock`.

---

## 3. `sudo` como servicio PAM

### En una frase

Restringir `sudo` es lo que evita que el usuario restringido **escape** de su propia ventana.

### Fundamentos previos

- PAM (1).

### Qué es

`sudo` es un servicio PAM. Al incluirlo en `SERVICES`, la ventana horaria también se aplica
a la escalada de privilegios.

### Qué problema resuelve

Sin eso, el usuario restringido podría, durante su ventana, convertirse en root y desactivar
el bloqueo (o hacerlo fuera de ventana si ya tenía una sesión).

### Cómo funciona paso a paso

1. El usuario ejecuta `sudo`.
2. PAM evalúa `account` para el servicio `sudo`.
3. Fuera de la ventana → denegado, aunque la contraseña sea correcta.

### Qué se rompería sin esto

La barrera se derrumba: root puede todo.

### Error común

**Dejar `NOPASSWD` en `/etc/sudoers.d/`.** Sin contraseña, la regla PAM puede no ser
suficiente según configuración. Revisa con `sudo -l -U <usuario>`.

### Para profundizar

- [`../threat-model.md`](../threat-model.md).

---

## 4. Qué NO hace `pam_time`

### En una frase

Solo actúa **al autenticar**: no expulsa una sesión ya abierta.

### Fundamentos previos

- Todo lo anterior.

### Qué es

El límite documentado del módulo: no hay un daemon que cierre sesiones al terminar la
ventana. Eso es responsabilidad del módulo 02.

### Qué problema resuelve

Saber dónde termina la capa 1 y por qué existe la 2.

### Para qué sirve aquí

Justifica la arquitectura de tres capas.

### Error común

**Asumir que el usuario "sale solo" al terminar la ventana.** No: sigue dentro hasta que el
timer lo expulsa.

### Para profundizar

- Siguiente: [`02-enforce.md`](02-enforce.md).
