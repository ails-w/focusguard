# Instalación

## Prerrequisitos

| Requisito | Para qué |
|---|---|
| Linux con **systemd** | timers, `loginctl` |
| `bash` + `util-linux` | scripts, `logger`, `loginctl` |
| `e2fsprogs` | `chattr` / `lsattr` |
| `pam_time.so` en la fase `account` | la puerta PAM |
| Un display manager (SDDM probado) | cierre y relanzado del greeter |
| root (`sudo`) | todo escribe en `/etc` y `/usr/local` |

Verifica la puerta PAM:

```bash
grep -n pam_time /etc/pam.d/system-auth
# account    required    pam_time.so
```

Si no aparece, agrégalo **antes** de instalar el módulo 01.

## Orden recomendado

```text
00-base → 01-pam-gate → 02-enforce → 03-integrity → 04-disarm
```

`00-base` provee lo compartido; `03-integrity` va al final porque **congela** el estado ya
correcto. Cada módulo tiene su README con aplicar/verificar/rollback.

## Resumen

### 00 — Base

```bash
sudo install -d /etc/focusguard /usr/local/lib/focusguard
sudo cp modules/00-base/files/etc/focusguard/policy.conf /etc/focusguard/policy.conf
sudo cp modules/00-base/files/usr/local/lib/focusguard/common.sh /usr/local/lib/focusguard/common.sh
sudo chmod 0644 /etc/focusguard/policy.conf /usr/local/lib/focusguard/common.sh
```

**Edita `/etc/focusguard/policy.conf`** con tu usuario y tus horarios antes de seguir.

### 01 — PAM gate

```bash
sudo install -m 0755 modules/01-pam-gate/files/usr/local/bin/focusguard-render \
                    modules/01-pam-gate/files/usr/local/bin/focusguard-apply /usr/local/bin/
sudo focusguard-apply
```

### 02 — Enforcement

```bash
sudo install -m 0755 modules/02-enforce/files/usr/local/bin/focusguard-enforce /usr/local/bin/
sudo install -m 0644 modules/02-enforce/files/etc/systemd/system/focusguard-*.service \
                    modules/02-enforce/files/etc/systemd/system/focusguard-*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now focusguard-enforce.timer focusguard-resume.service
```

### 03 — Integridad

```bash
sudo install -m 0755 modules/03-integrity/files/usr/local/bin/focusguard-lock \
                    modules/03-integrity/files/usr/local/bin/focusguard-integrity /usr/local/bin/
sudo install -m 0644 modules/03-integrity/files/etc/systemd/system/focusguard-integrity.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now focusguard-integrity.timer
sudo focusguard-lock
```

### 04 — Disarm

```bash
sudo install -m 0755 modules/04-disarm/files/usr/local/bin/focusguard-disarm /usr/local/bin/
```

## Verificar la instalación

```bash
sudo scripts/verify.sh
```

Detalle en [`verification.md`](verification.md).

## Desinstalación

Ver el rollback del [módulo 04](../modules/04-disarm/README.md#rollback-volver-a-desarmar-todo-el-sistema).
Regla de oro: **desarmar primero** (`sudo focusguard-disarm`) para poder editar los archivos
protegidos.
