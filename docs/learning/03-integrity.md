# Módulo 03 — Integridad

Cómo impedir que la configuración se desactive en silencio: fricción (`chattr +i`),
reversión (golden) y auditoría.

> Implementación → [`modules/03-integrity/`](../../modules/03-integrity/README.md)

## Glosario del módulo

| Término | Qué significa (en una línea) |
|---|---|
| inodo | Estructura del filesystem que describe un archivo. |
| `chattr +i` | Atributo *immutable*: ni root edita sin quitarlo. |
| golden | Copia de referencia "buena" de un archivo. |
| drift | Diferencia entre el estado actual y el golden. |

## Mapa de conceptos

```text
  chattr +i (1) ──▶ editar exige un paso deliberado
        │
        ▼
  golden + lock/integrity (2,3) ──▶ ¿cambió? → restaura y re-bloquea
        │
        └─ protege: policy.conf + time.conf
```

---

## 1. `chattr +i` aplicado

### En una frase

Marca los dos archivos de configuración como inmutables para que editarlos requiera
`chattr -i` primero.

### Fundamentos previos

- `chattr` (ver [`00-fundamentos.md`](00-fundamentos.md), concepto 4).

### Qué es

`focusguard-lock` aplica `+i` a `/etc/focusguard/policy.conf` y `/etc/security/time.conf`
(y a sus copias golden).

### Qué problema resuelve

Convierte "abrir el archivo y cambiar un horario" en un acto consciente que deja rastro.

### Cómo funciona paso a paso

1. `chattr -i` (por si ya estaba).
2. `cp -a live golden`.
3. `chattr +i live golden`.

### Qué se rompería sin esto

La integridad igual restauraría el contenido, pero editar sería trivial y silencioso.

### Error común

**Editar con un editor que reemplaza el archivo (rename).** Con `+i`, el rename falla y el
editor puede dejar temporales. Solución: `disarm` (que quita la `i`) o `chattr -i` explícito.

### Para profundizar

- `man 1 chattr`.

---

## 2. El patrón golden

### En una frase

Una copia de referencia, una comparación cada minuto, y una restauración automática si algo
cambió.

### Fundamentos previos

- `chattr +i` (1).

### Qué es

- `focusguard-lock`: toma la foto (golden) y bloquea.
- `focusguard-integrity`: compara `cmp -s golden live`; si difieren, restaura y re-bloquea.

### Qué problema resuelve

`chattr +i` solo frena el primer cambio. El golden garantiza que, si el cambio ocurre
igual, **se revierta** en menos de un minuto.

### Cómo funciona paso a paso

1. `integrity` recorre la lista de archivos.
2. Si el archivo tiene golden, compara contenido.
3. Si difieren: `chattr -i`, `cp -a golden live`, `chattr +i`, y registra
   `integrity-restore file=…`.
4. Si el contenido está igual pero le falta la `i`: se la vuelve a poner (`integrity-relock`).

### Qué se rompería sin esto

Un cambio pasaría desapercibido: el sistema "parece" configurado pero su estado real cambió.

### Error común

**Editar sin desarmar y creer que "no se guardó".** La integridad revirtió el cambio. Flujo
correcto: `disarm → editar → apply → lock → start`.

### Para profundizar

- [`../diagrams/netguard-lifecycle.md`](../diagrams/) (patrón hermano en `dns-doh-lockdown`).

---

## 3. Solo se gestiona lo que tiene golden

### En una frase

Si un archivo de la lista no tiene copia de referencia, la integridad lo ignora: nunca
bloquea algo que no puede restaurar.

### Fundamentos previos

- El patrón golden (2).

### Qué es

La línea `[ -f "$golden" ] || continue` al principio del bucle.

### Qué problema resuelve

Evita el estado incoherente "bloqueado pero sin respaldo": si `focusguard-lock` nunca corrió,
`integrity` no debe marcar nada.

### Cómo funciona paso a paso

1. Sin golden → se salta el archivo (ni restaura ni bloquea).
2. Con golden → gestiona normalmente.

### Qué se rompería sin esto

Un bug sutil: `integrity` bloquearía archivos sin poder restaurarlos, y cualquier cambio se
perdería sin retorno.

### Error común

**Correr `integrity` antes de `lock`.** No rompe nada (no hay goldens), pero no protege
nada. El orden es `lock` primero.

### Para profundizar

- Módulo 03 → `focusguard-lock`.

---

## 4. Diferencia con `netguard`

### En una frase

Mismo patrón, distinto alcance: `focusguard` protege **config de PAM/ventanas**; `netguard`
protege **red/NSS/navegadores** y además recarga servicios.

### Fundamentos previos

- Todo lo anterior.

### Qué es

Dos implementaciones del patrón golden con diferencias deliberadas:

| | `focusguard` | `netguard` |
|---|---|---|
| Alcance | `policy.conf`, `time.conf` | nftables, resolved, `/etc/hosts`, políticas, etc. |
| Golden | por `basename` | por ruta completa |
| Recarga tras restaurar | no hace falta | `nft -f`, `resolvectl flush-caches`, `tmpfiles` |
| Timers | `:00` (enforce) y `:30` (integrity) | `:45` |

### Qué problema resuelve

Evita acoplar dos ciclos de vida distintos en un solo interruptor.

### Para qué sirve aquí

Es la razón de que existan **dos** herramientas y no una: editar la red no debe desarmar el
bloqueo de usuario, ni al revés.

### Error común

**Fusionar ambos en un solo "guard" con un único `disarm`.** Tarde o temprano editarás la
red y desarmarás tu bloqueo sin querer (o al contrario).

### Para profundizar

- Repo hermano: `dns-doh-lockdown` → `modules/05-netguard`.
