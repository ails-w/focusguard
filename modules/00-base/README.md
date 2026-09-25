# Módulo 00 — Base

El fundamento compartido: la **configuración única** (`policy.conf`) y el **helper de
auditoría** (`common.sh`) que todos los demás scripts sourcean.

## Prerrequisitos

- `bash`
- `util-linux` (para `logger`)

## Archivos

| Archivo | Destino | Qué hace |
|---|---|---|
| `files/etc/focusguard/policy.conf` | `/etc/focusguard/policy.conf` | fuente única: usuario, ventanas, avisos |
| `files/usr/local/lib/focusguard/common.sh` | `/usr/local/lib/focusguard/common.sh` | `fg_audit()`: escribe en el journal y en el log |

## Aplicar

```bash
sudo install -d /etc/focusguard /usr/local/lib/focusguard
sudo install -m 0644 files/etc/focusguard/policy.conf /etc/focusguard/policy.conf
sudo install -m 0644 files/usr/local/lib/focusguard/common.sh /usr/local/lib/focusguard/common.sh
```

> **Antes de seguir:** edita `/etc/focusguard/policy.conf` y pon **tu** usuario y **tus**
> horarios. Los valores del repo son de ejemplo.

## Verificar

```bash
cat /etc/focusguard/policy.conf
# fuentearla en una shell de prueba no debe dar error:
bash -c '. /etc/focusguard/policy.conf && echo "USER=$USER ventanas=$ALLOWED_WD"'
```

## Rollback

```bash
sudo rm -f /etc/focusguard/policy.conf /usr/local/lib/focusguard/common.sh
```

## Notas

- Todos los scripts asumen que `common.sh` está en `/usr/local/lib/focusguard/common.sh`.
  Instala este módulo **primero**.
- `fg_audit` escribe en `/var/log/focusguard/audit.log` (crea el directorio si falta) y en
  el journal con la etiqueta `focusguard`: `journalctl -t focusguard`.
- `policy.conf` es un archivo de shell: se *sourcea*, no se parsea. Mantén la sintaxis
  `CLAVE="valor"`.
