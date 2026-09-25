# Troubleshooting

Síntoma → causa probable → arreglo.

## Pantalla negra con un `_` parpadeando tras la expulsión

**El bug clásico.** Causa: expulsar con `pkill -KILL -u` hace que el *helper* de SDDM salga
con error y SDDM **no relanza el greeter**.

Arreglo (ya incluido en el repo):

- Usar `loginctl terminate-user` en vez de `pkill`.
- Tener el watchdog `recover_greeter`, que reinicia `display-manager.service` si en 40 s no
  hay greeter.
- Tener el guard de resume, para no matar la sesión mientras la GPU se reanuda.

Verifica que tu `focusguard-enforce` no tenga `pkill`:

```bash
grep -n pkill /usr/local/bin/focusguard-enforce || echo "sin pkill (OK)"
```

## No puedo editar `policy.conf` / `time.conf`

Es el candado. `Operation not permitted` con `chattr +i`. Solución:

```bash
sudo focusguard-disarm      # o: sudo chattr -i /etc/focusguard/policy.conf
```

## Mis cambios se revierten solos

Editaste sin desarmar y la integridad restauró desde la golden. Flujo correcto:

```bash
sudo focusguard-disarm
#   editar policy.conf
sudo focusguard-apply
sudo focusguard-lock
sudo systemctl start focusguard-enforce.timer focusguard-integrity.timer
```

## El usuario no es expulsado al terminar la ventana

| Causa | Arreglo |
|---|---|
| El timer no corre | `systemctl list-timers focusguard-enforce.timer`; `systemctl start focusguard-enforce.timer` |
| Acaba de haber un resume | el guard de 60 s salta una pasada; espera al próximo minuto |
| `loginctl show-user` no detecta sesión | `loginctl list-sessions`; revisa que la sesión sea del usuario correcto |
| `killed` quedó pegado | `sudo rm -f /run/focusguard/killed` |

## Los avisos no llegan a la pantalla

- `notify_user` necesita el bus de sesión: `/run/user/<uid>/bus`.
- Si hay varios sockets Wayland, puede elegir el equivocado.
- Prueba manual: `sudo -u <user> notify-send -u critical Focusguard "test"`.

## Reiniciar el display manager expulsa a TODOS

`systemctl restart display-manager.service` termina la sesión gráfica activa. El watchdog
solo debe ejecutarlo cuando **no hay ninguna** sesión en un *seat*. Si ves que expulsa a
otro usuario que estaba logueado, revisa la condición del watchdog (debe esperar a que no
queden sesiones y luego al greeter).

## Los timers no existen / no están habilitados

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now focusguard-enforce.timer focusguard-integrity.timer
systemctl status focusguard-enforce.service --no-pager
```

Si un `.service` falla con `203/EXEC`, hay un **typo en `ExecStart`**: revisa con
`systemctl cat focusguard-enforce.service`.

## Filosofía de diagnóstico

1. Mira el log antes de tocar: `journalctl -t focusguard -n 30` y
   `sudo tail /var/log/focusguard/audit.log`.
2. Aísla la capa: ¿falla la entrada (PAM), la expulsión (enforce) o el candado (integridad)?
3. Usa `DRY_RUN=1` para probar sin expulsar a nadie.
4. No edites archivos inmutables a mano sin desarmar: la integridad los revertirá.
