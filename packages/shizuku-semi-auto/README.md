# shizuku-semi-auto

*[English](#english) · [Español](#español)*

---

## English

Semi-automatic Shizuku activation using Termux + Termux:Boot + a loopback
ADB connection, for both Android generations:

- **Android 10 and below** (no native wireless-debugging toggle): once
  per boot, connect a cable (or a second Android/PC) and run
  `adb tcpip 5555` from that side. `adb-connect` detects the open port
  within a second, connects to itself over 127.0.0.1, and applies a
  USB-mode "priming" step on these versions to avoid a transition-freeze
  bug diagnosed on specific devices/ROMs (see caveat below).
- **Android 11 and above**: run `shizuku-pair` after each boot and type
  the port shown in Settings > Wireless debugging. The first time it
  also asks for the pairing code; credentials persist across reboots,
  only the TLS port rotates. The script pairs, connects over loopback,
  pins adbd to the fixed port 5555 (independent of WiFi), and hands off
  to the daemons. Full automation is not possible without root: the
  rotating port is only readable from the Settings UI (mdns discovery
  is not available in the Termux adb build).

In both cases, `shizuku-watchdog` then keeps Shizuku alive: it detects
the version of the installed Shizuku app and uses the right start
command automatically:

| Shizuku | Command |
|---|---|
| 13.6.0+ | direct exec of `libshizuku.so`, path resolved at runtime with a glob (its random per-install suffixes change on every update) |
| V4+ (Android 7+) | `sh /data/user_de/0/moe.shizuku.privileged.api/start.sh` |
| V4+ (Android 6) | `sh /data/user/0/moe.shizuku.privileged.api/start.sh` |
| V3.x | `sh /sdcard|/storage/emulated/0/.../start.sh` |

The method that works is cached (`~/.local/tmp/shizuku-method.txt`) and
re-probed automatically if it ever stops working (e.g. after a Shizuku
update). Success is verified by checking the `shizuku_server` process,
not by parsing script output. On some ROMs `user_de`/`user/0` are not
readable by the shell user at all — the fallback chain handles that.

### Requirements

- Termux:Boot installed and **opened at least once**.
- Termux:Boot and Termux:API (if used) must come from the **same
  source** as the main Termux app (GitHub or F-Droid — Android refuses
  to install apps that share Termux's signature scope if the signing
  keys differ). Check your current source with
  `echo $TERMUX_APK_RELEASE`.
- Shizuku app installed. For versions before 13.6: open its "ADB" tab
  once so it generates `start.sh`.
- Android 10-: a second Android device (or PC) with `adb`, once per
  boot.
- Android 11+: wireless debugging capable, Settings access per boot
  (to read the port).
- Optional: `pkg install -y termux-api` + the Termux:API app, for the
  notification when the watchdog reactivates Shizuku.

### ⚠️ About the USB-mode priming (Android 10 and below only)

The priming in `adb-connect` (`svc usb setFunctions none` → `mtp`)
exists because of a freeze diagnosed on a specific device/ROM:
disconnecting the cable without a real USB-mode transition left the
ADB-over-WiFi shell permanently unresponsive. **There is no guarantee
this exact bug exists on a different device.** It only runs on SDK ≤
29; leaving it in does no harm on affected devices. To check whether a
device needs it:

1. Run `tail -f ~/.local/tmp/adb-connect.log` in a second session.
2. Cable connected, run `adb tcpip 5555` from the other device,
   disconnect the cable.
3. Try `adb -s 127.0.0.1:5555 shell echo hola`. If it never hangs,
   this device likely doesn't have the bug.

### Quick post-boot check

```bash
cat ~/.local/tmp/boot-adb-connect.log
cat ~/.local/tmp/boot-shizuku-watchdog.log
pgrep -fl adb-connect
pgrep -fl shizuku-watchdog
cat ~/.local/tmp/shizuku-method.txt   # start method in use
```

### Known limitations

- Android 11+: one manual step per boot (read the TLS port from
  Settings and type it into `shizuku-pair`). Root would remove this.
- Android 10-: detecting the open port is a race against the cable
  being disconnected too early — not a mathematical guarantee, though
  the margin is wide (polling every second; a human takes longer to
  react).
- If the daemon triggers priming while the cable is in active use for
  something mode-sensitive (e.g. an active MTP transfer), it can
  interrupt it. Infrequent edge case, Android 10- only.
- Logs are truncated on every run on purpose — one log per cycle, not
  an accumulated history.

### Troubleshooting

- **`adb` fails with `CANNOT LINK EXECUTABLE ... cannot locate symbol
  "_ZNSt6__ndk113__hash_memoryEPKvm"`**: your `libc++` is older than the
  installed `android-tools` build (stale/partial Termux upgrade, or
  mixing F-Droid and GitHub builds). Fix:
  `pkg update && pkg upgrade -y`, then `pkg reinstall android-tools`.
  The postinst prints this same hint when it detects the broken state.
- **Android 11+: `shizuku-pair` can't connect**: the port rotates; make
  sure you typed the one from the MAIN wireless-debugging screen (not
  the pairing dialog), and that the screen stayed open while typing.

### Uninstall

```bash
pkg uninstall shizuku-semi-auto
```

---

## Español

Activación semi-automática de Shizuku usando Termux + Termux:Boot + una
conexión ADB por loopback, para las dos generaciones de Android:

- **Android 10 y anteriores** (sin toggle nativo de depuración
  inalámbrica): una vez por boot, conectá un cable (o otro Android/PC)
  y corré `adb tcpip 5555` desde ese lado. `adb-connect` detecta el
  puerto abierto en menos de un segundo, se conecta a sí mismo por
  127.0.0.1 y, solo en estas versiones, aplica un "priming" de modo USB
  para evitar un freeze de transición diagnosticado en
  dispositivos/ROMs concretos (ver advertencia abajo).
- **Android 11 y superiores**: corrés `shizuku-pair` tras cada boot y
  tipeás el puerto que muestra Ajustes > Depuración inalámbrica. La
  primera vez también pide el código de emparejamiento; las
  credenciales persisten entre boots, solo el puerto TLS rota. El
  script empareja, conecta por loopback, fija adbd al puerto 5555
  (independiente del WiFi) y le pasa el control a los daemons. La
  automatización total no es posible sin root: el puerto rotativo solo
  se puede leer desde la UI de Ajustes (mdns no está disponible en el
  build de adb de Termux).

En ambos casos, `shizuku-watchdog` mantiene Shizuku vivo: detecta la
versión de la app Shizuku instalada y usa el comando de arranque
correcto automáticamente:

| Shizuku | Comando |
|---|---|
| 13.6.0+ | ejecución directa de `libshizuku.so`, ruta resuelta en runtime con glob (sus sufijos aleatorios por instalación cambian en cada actualización) |
| V4+ (Android 7+) | `sh /data/user_de/0/moe.shizuku.privileged.api/start.sh` |
| V4+ (Android 6) | `sh /data/user/0/moe.shizuku.privileged.api/start.sh` |
| V3.x | `sh /sdcard|/storage/emulated/0/.../start.sh` |

El método que funciona queda cacheado (`~/.local/tmp/shizuku-method.txt`)
y se vuelve a detectar automáticamente si alguna vez deja de funcionar
(ej. tras una actualización de Shizuku). El éxito se verifica mirando el
proceso `shizuku_server`, no parseando el output del script. En algunas
ROMs `user_de`/`user/0` ni siquiera son legibles por el usuario shell —
la cadena de fallback lo maneja.

### Requisitos

- Termux:Boot instalada y **abierta al menos una vez**.
- Termux:Boot y Termux:API (si se usa) tienen que venir de la **misma
  fuente** que el Termux principal (GitHub o F-Droid — Android rechaza
  instalar apps que comparten el alcance de firma de Termux si las
  claves de firma difieren). Confirmá tu fuente actual con
  `echo $TERMUX_APK_RELEASE`.
- App Shizuku instalada. En versiones anteriores a 13.6: entrá una vez
  a su pestaña "ADB" para que genere `start.sh`.
- Android 10-: un segundo dispositivo Android (o PC) con `adb`, una
  vez por boot.
- Android 11+: compatible con depuración inalámbrica; acceso a Ajustes
  por boot (para leer el puerto).
- Opcional: `pkg install -y termux-api` + la app Termux:API, para la
  notificación cuando el watchdog reactiva Shizuku.

### ⚠️ Sobre el priming de modo USB (solo Android 10 y anteriores)

El priming de `adb-connect` (`svc usb setFunctions none` → `mtp`) existe
por un freeze diagnosticado en un dispositivo/ROM concreto: al
desconectar el cable sin una transición real de modo USB, el shell ADB
por WiFi quedaba permanentemente congelado. **No hay garantía de que
este bug exista en otro dispositivo.** Solo corre en SDK ≤ 29; dejarlo
activo no hace daño en equipos afectados. Para verificar si un equipo lo
necesita:

1. Corré `tail -f ~/.local/tmp/adb-connect.log` en una segunda sesión.
2. Con el cable puesto, corré `adb tcpip 5555` desde el otro equipo y
   desconectá el cable.
3. Probá `adb -s 127.0.0.1:5555 shell echo hola`. Si nunca se cuelga,
   este equipo probablemente no tiene el bug.

### Chequeo rápido post-boot

```bash
cat ~/.local/tmp/boot-adb-connect.log
cat ~/.local/tmp/boot-shizuku-watchdog.log
pgrep -fl adb-connect
pgrep -fl shizuku-watchdog
cat ~/.local/tmp/shizuku-method.txt   # método de arranque en uso
```

### Limitaciones conocidas

- Android 11+: un paso manual por boot (leer el puerto TLS de Ajustes
  y tipearlo en `shizuku-pair`). Con root esto desaparecería.
- Android 10-: detectar el puerto abierto compite contra la
  desconexión del cable — no es garantía matemática, aunque el margen
  es amplio (sondeo cada segundo; un humano tarda más en reaccionar).
- Si el daemon dispara el priming mientras el cable está en uso para
  algo sensible al modo (ej. una transferencia MTP activa), puede
  interrumpirla. Caso borde infrecuente, solo Android 10-.
- Los logs se truncan en cada corrida a propósito — 1 log por ciclo, no
  un historial acumulado.

### Solución de problemas

- **`adb` falla con `CANNOT LINK EXECUTABLE ... cannot locate symbol
  "_ZNSt6__ndk113__hash_memoryEPKvm"`**: tu `libc++` es más vieja que el
  build de `android-tools` instalado (Termux desactualizado a medias, o
  mezcla de builds de F-Droid y GitHub). Arreglo:
  `pkg update && pkg upgrade -y` y después `pkg reinstall android-tools`.
  El postinst imprime esta misma ayuda si detecta el estado roto.
- **Android 11+: `shizuku-pair` no conecta**: el puerto rota; asegurate
  de tipear el de la pantalla PRINCIPAL de depuración inalámbrica (no el
  del diálogo de emparejamiento), y de que la pantalla siga abierta
  mientras tipeás.

### Desinstalar

```bash
pkg uninstall shizuku-semi-auto
```
