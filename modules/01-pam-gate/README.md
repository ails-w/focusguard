# Módulo 01 — PAM gate

La **puerta de entrada**: PAM niega el login (gráfico, consola, ssh) y **`sudo`** fuera de
la ventana horaria. Es la capa que impide *entrar*, no la que expulsa (eso es el módulo 02).

## Prerrequisitos

- Módulo [`00-base`](../00-base/).
- `pam_time.so` presente en la fase `account` de PAM (en Arch viene así por defecto):

```bash
grep -n pam_time /etc/pam.d/system-auth
# account    required    pam_time.so
```

## Archivos

| Archivo | Destino | Qué hace |
|---|---|---|
| `files/usr/local/bin/focusguard-render` | `/usr/local/bin/focusguard-render` | imprime la línea de `pam_time` desde `policy.conf` |
| `files/usr/local/bin/focusguard-apply` | `/usr/local/bin/focusguard-apply` | reemplaza el bloque de `time.conf` con la línea generada |
| `files/etc/security/time.conf.example` | (referencia) | cómo queda el bloque en `time.conf` |

## Aplicar

```bash
sudo install -m 0755 files/usr/local/bin/focusguard-render files/usr/local/bin/focusguard-apply /usr/local/bin/
sudo focusguard-apply
```

`focusguard-apply` conserva el resto de `/etc/security/time.conf` y solo reemplaza lo que
está entre `# BEGIN focusguard` y `# END focusguard`.

## Verificar

```bash
focusguard-render                      # imprime la linea generada
grep -A2 'BEGIN focusguard' /etc/security/time.conf
```

Prueba real: intenta iniciar sesión con el usuario restringido **fuera** de la ventana →
debe ser rechazado. Dentro de la ventana → debe entrar.

## Rollback

```bash
sudo sed -i '/# BEGIN focusguard/,/# END focusguard/d' /etc/security/time.conf
sudo rm -f /usr/local/bin/focusguard-render /usr/local/bin/focusguard-apply
```

## Notas

- **`Wk` = semana (lun–vie) y `Wd` = fin de semana (sáb–dom).** El nombre engaña
  (*weekend* parecería `Wk`), pero es al revés; está verificado en `pam_time.c`.
- **`pam_time` no expulsa sesiones abiertas**: solo actúa al autenticar. Si el usuario ya
  está dentro, hay que cerrarle la sesión — eso lo hace el módulo 02.
- Incluir `sudo` en `SERVICES` es clave: sin eso, el usuario restringido podría escalar a
  root **dentro** de su sesión y desactivar el bloqueo.
- Si tu display manager no es SDDM, cambia `sddm` por `gdm`/`lightdm`/`greetd` en
  `policy.conf`.
