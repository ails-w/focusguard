# Aprendizaje

Conceptos del proyecto, **un archivo por módulo**. Se leen en orden: cada uno se entiende
solo, pero juntos explican todo el sistema.

| Módulo | Archivo | Qué aprenderás |
|---|---|---|
| — | [`00-fundamentos.md`](00-fundamentos.md) | PAM, `pam_time`, `chattr`, timers, ciclo de sesión |
| 01 | [`01-pam-gate.md`](01-pam-gate.md) | la puerta de entrada y la semántica de `time.conf` |
| 02 | [`02-enforce.md`](02-enforce.md) | **el bug de la pantalla negra** y la expulsión correcta |
| 03 | [`03-integrity.md`](03-integrity.md) | golden + `chattr +i` + verificación |
| 04 | [`04-disarm.md`](04-disarm.md) | el interruptor deliberado |

## Esquema de cada concepto

- **En una frase** — la idea mínima.
- **Fundamentos previos** — lo que hay que entender antes, explicado ahí mismo.
- **Qué es** / **Qué problema resuelve** / **Cómo funciona paso a paso**.
- **Qué se rompería sin esto** — contrafactual concreto de *este* proyecto.
- **Para qué sirve aquí** / **Cómo se usa (archivos reales)**.
- **Error común** — qué se hace mal y cómo detectarlo.
- **Para profundizar**.

## Reglas

- Se acumula: los conceptos aprendidos **nunca** se borran.
- Glosario + mapa de conceptos obligatorios al inicio de cada archivo.
- Cada concepto debe tener su **Error común**.
- Plantilla para un módulo nuevo: [`template.md`](template.md).
