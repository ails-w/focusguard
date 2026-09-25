# Preguntas frecuentes

## ¿Por qué PAM y no solo un `cron` que cierre la sesión?

Porque el cron solo actúa **después** de que el usuario entró. Sin la puerta PAM, el usuario
expulsado puede volver a entrar un segundo después. PAM (`pam_time`) cierra la entrada;
el timer cierra la salida. Se necesitan **las dos**.

## ¿Por qué no usar `pkill` para echarlo?

Porque rompe el ciclo de vida del display manager. `pkill -KILL -u` mata la sesión a lo
bruto, el helper de SDDM sale con error y SDDM **no relanza el greeter** → pantalla negra.
`loginctl terminate-user` cierra ordenadamente y escala solo. Ver
[`learning/02-enforce.md`](learning/02-enforce.md).

## ¿`chattr +i` no es peligroso?

Es **fricción**, no una frontera. Un root puede quitarlo. Sirve para que desactivar el
bloqueo sea deliberado, se revierta solo (integridad cada minuto) y quede auditado. Si te
preocupa quedarte fuera: `focusguard-disarm` está para eso, y `chattr -i` siempre funciona
como root.

## ¿Funciona fuera de Arch Linux?

Sí en su mayor parte: PAM, `pam_time`, systemd, `loginctl` y `chattr` son estándar. No hay
nada específico de Arch en los scripts. Ajusta el display manager en `SERVICES` (`sddm` por
`gdm`/`lightdm`/`greetd`) si no usas SDDM.

## ¿Sirve para bloquear el uso de un hijo/adolescente?

Sirve como **autocontrol y control doméstico suave**, no como barrera. Si el usuario puede
`sudo`, o está en el grupo `docker`, o tiene acceso físico, puede saltarlo. Para control
parental real, quita privilegios y controla desde el router.

## ¿Por qué `Wk` y `Wd` parecen al revés?

`pam_time` define `Wk` = *week* (lunes–viernes) y `Wd` = *weekend* (sábado–domingo). El
nombre engaña porque `Wk` parece "weekend". Está verificado en `pam_time.c`
(`wk = 076` = lun–vie, `wd = 0101` = sáb–dom).

## ¿Qué pasa si el equipo estaba apagado/suspendido durante el cierre?

- **Apagado:** no hay nada que expulsar. Al arrancar, PAM ya bloquea el login.
- **Suspendido:** al reanudar, el guard de resume salta la primera pasada (60 s) para no
  matar la sesión mientras la GPU se reanuda; en la siguiente pasada expulsa.

## ¿Por qué `focusguard` y no `focusblock`?

Son dos enfoques del mismo objetivo:

- **`focusguard`** (este repo): herramientas de sistema (PAM + systemd + `chattr`), sin
  binarios nuevos, mínimo y auditable.
- **`focusblock`**: una app TUI en .NET con daemon y métricas.

## ¿Puedo usarlo con varios usuarios?

`policy.conf` define **un** `USER`. Para varios, duplica la lógica (no está soportado en
esta versión).
