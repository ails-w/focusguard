# Verificación

Cómo comprobar cada capa. Si una falla, no sigas.

> Automatización: `scripts/verify.sh` reproduce esta batería. Los comandos de abajo son
> para inspeccionar cada capa a mano cuando algo falla.

## Capa 1 — Puerta PAM

```bash
focusguard-render                       # imprime la linea de pam_time
grep -A2 'BEGIN focusguard' /etc/security/time.conf
grep -n pam_time /etc/pam.d/system-auth
```

**Esperado:** la línea generada coincide con tu `policy.conf`, y `pam_time.so` está en la
fase `account`.

Prueba real: inicia sesión con el usuario restringido **fuera** de la ventana → debe ser
rechazado; **dentro** → debe entrar. Y `sudo` fuera de la ventana → rechazado.

## Capa 2 — Enforcement

```bash
bash -n /usr/local/bin/focusguard-enforce
sudo DRY_RUN=1 /usr/local/bin/focusguard-enforce && echo "dry-run OK"
systemctl list-timers 'focusguard*' --no-pager
systemctl is-enabled focusguard-resume.service
```

**Esperado:** sin errores de sintaxis, el dry-run no expulsa a nadie, el timer corre cada
minuto y el unit de resume está `enabled`.

Prueba real controlada:

1. Entra con el usuario restringido dentro de su ventana.
2. En otra terminal: `journalctl -f -t focusguard -u sddm -u display-manager`
3. Espera el fin de la ventana (o acorta la ventana en `policy.conf`).
4. Debe expulsar y **volver el greeter** (no pantalla negra).

## Capa 3 — Integridad

```bash
lsattr /etc/focusguard/policy.conf /etc/security/time.conf     # ambos con 'i'
ls -la /etc/focusguard/golden/

# Sabotaje controlado:
sudo chattr -i /etc/security/time.conf
sudo sh -c 'echo "# sabotage" >> /etc/security/time.conf'
sudo systemctl start focusguard-integrity.service
grep -c sabotage /etc/security/time.conf     # debe ser 0
lsattr /etc/security/time.conf               # vuelve a tener 'i'
sudo journalctl -t focusguard -n 5 --no-pager
```

## Capa 4 — Disarm

```bash
sudo focusguard-disarm                  # pide frase + 60 s
lsattr /etc/focusguard/policy.conf      # ya sin 'i'
sudo tail -5 /var/log/focusguard/audit.log
```

## Checklist final

- [ ] `policy.conf` editado con el usuario y horarios reales.
- [ ] Login y `sudo` denegados fuera de la ventana.
- [ ] Sesión expulsada al terminar la ventana, con el greeter de vuelta.
- [ ] `policy.conf` y `time.conf` inmutables, con golden.
- [ ] Sabotaje revertido en ≤1 minuto.
- [ ] `focusguard-disarm` funciona (frase + espera).
