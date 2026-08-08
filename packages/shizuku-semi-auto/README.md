# shizuku-semi-auto

*[English](#english) · [Español](#español)*

---

## English

Semi-automatic Shizuku activation for Android versions before 11 (no
native wireless-debugging toggle that reconnects on its own), using
Termux + Termux:Boot + a loopback ADB connection.

### How it works

1. Once per boot, connect this device by cable to a second Android
   device (or PC) and run `adb tcpip 5555` from that side — nothing
   else needs to happen there.
2. `adb-connect` runs in the background from boot, polling port 5555
   in loopback every second. As soon as TCP mode is detected, it
   connects to itself (127.0.0.1:5555) and applies a USB-mode "priming"
   step (see caveat below) before the initiating cable is disconnected.
3. `shizuku-watchdog` runs in parallel: activates Shizuku via its
   official `start.sh` and restarts it if it stops, independent of the
   ADB connection itself.
4. Both launch at boot via Termux:Boot, each with its own log.

### Requirements

- Termux:Boot installed and **opened at least once**.
- Termux:Boot and Termux:API (if used) must come from the **same
  source** as the main Termux app (GitHub or F-Droid — Android refuses
  to install apps that share Termux's signature scope if the signing
  keys differ). Check your current source with
  `echo $TERMUX_APK_RELEASE`.
- Shizuku app installed, with `start.sh` already generated (open its
  "ADB" tab once).
- A second Android device (or PC) with `adb`, for the initial
  `adb tcpip 5555`.
- Optional: `pkg install -y termux-api` + the Termux:API app, for the
  notification when the watchdog reactivates Shizuku.

### ⚠️ Before trusting this on a new device

The USB-mode priming in `adb-connect` (`svc usb setFunctions none` →
`mtp`) exists because of a freeze diagnosed on a specific device/ROM:
disconnecting the cable without a real USB-mode transition left the
ADB-over-WiFi shell permanently unresponsive. **There is no guarantee
this exact bug exists on a different device.** Leaving the priming in
does no harm — a couple of extra seconds per reconnection if it isn't
needed — but before assuming it's required:

1. Run `tail -f ~/.local/tmp/adb-connect.log` in a second session.
2. Cable connected, run `adb tcpip 5555` from the other device,
   disconnect the cable.
3. Try `adb -s 127.0.0.1:5555 shell echo hola`. If it never hangs, this
   device likely doesn't have the bug.

### Quick post-boot check

```bash
cat ~/.local/tmp/boot-adb-connect.log
cat ~/.local/tmp/boot-shizuku-watchdog.log
pgrep -fl adb-connect
pgrep -fl shizuku-watchdog
```

### Known limitations

- Detecting the open port is a race against the cable being
  disconnected too early — not a mathematical guarantee, though the
  margin is wide (polling every second; a human takes longer to react).
- If the daemon triggers priming while the cable is in active use for
  something mode-sensitive (e.g. an active MTP transfer), it can
  interrupt it. Infrequent edge case.
- Logs are truncated on every run on purpose — one log per cycle, not
  an accumulated history.

### Uninstall

```bash
pkg uninstall shizuku-semi-auto
```

---

## Español

Activación semi-automática de Shizuku para versiones de Android
anteriores a la 11 (sin toggle nativo de depuración inalámbrica que se
reconecte solo), usando Termux + Termux:Boot + una conexión ADB por
loopback.

### Cómo funciona

1. Una vez por arranque, conectá este equipo por cable a otro Android
   (o PC) y corré `adb tcpip 5555` desde ese lado — no hace falta nada
   más ahí.
2. `adb-connect` corre en background desde el arranque, sondeando el
   puerto 5555 en loopback cada segundo. Apenas detecta el modo TCP, se
   conecta a sí mismo (127.0.0.1:5555) y aplica un "priming" de modo
   USB (ver advertencia abajo) antes de que se desconecte el cable que
   inició la sesión.
3. `shizuku-watchdog` corre en paralelo: activa Shizuku vía su
   `start.sh` oficial y lo reinicia si se detiene, independientemente
   de la conexión ADB.
4. Los dos se lanzan al arrancar vía Termux:Boot, cada uno con su
   propio log.

### Requisitos

- Termux:Boot instalada y **abierta al menos una vez**.
- Termux:Boot y Termux:API (si se usa) tienen que venir de la **misma
  fuente** que el Termux principal (GitHub o F-Droid — Android rechaza
  instalar apps que comparten el alcance de firma de Termux si las
  claves de firma difieren). Confirmá tu fuente actual con
  `echo $TERMUX_APK_RELEASE`.
- App Shizuku instalada, con `start.sh` ya generado (entrá una vez a su
  pestaña "ADB").
- Un segundo dispositivo Android (o PC) con `adb`, para el
  `adb tcpip 5555` inicial.
- Opcional: `pkg install -y termux-api` + la app Termux:API, para la
  notificación cuando el watchdog reactiva Shizuku.

### ⚠️ Antes de confiar en esto en un equipo nuevo

El priming de modo USB en `adb-connect` (`svc usb setFunctions none` →
`mtp`) existe por un freeze diagnosticado en un dispositivo/ROM
concreto: desconectar el cable sin una transición real de modo USB
dejaba el shell por ADB-WiFi permanentemente sin respuesta. **No hay
garantía de que este mismo bug exista en un equipo distinto.** Dejar el
priming no hace daño — un par de segundos extra por reconexión si no
hace falta — pero antes de asumir que es necesario:

1. Corré `tail -f ~/.local/tmp/adb-connect.log` en una segunda sesión.
2. Cable puesto, corré `adb tcpip 5555` desde el otro equipo,
   desconectá el cable.
3. Probá `adb -s 127.0.0.1:5555 shell echo hola`. Si nunca se cuelga,
   este equipo probablemente no tiene el bug.

### Verificación rápida post-boot

```bash
cat ~/.local/tmp/boot-adb-connect.log
cat ~/.local/tmp/boot-shizuku-watchdog.log
pgrep -fl adb-connect
pgrep -fl shizuku-watchdog
```

### Limitaciones conocidas

- La detección del puerto abierto es una carrera contra que el cable
  se desconecte antes de tiempo — no es garantía matemática, aunque el
  margen es amplio (sondeo cada segundo; un humano tarda más en
  reaccionar).
- Si el daemon dispara el priming mientras el cable está en uso activo
  para algo sensible al modo USB (ej. una transferencia MTP activa),
  puede interrumpirla. Caso de borde poco frecuente.
- Los logs se truncan en cada corrida a propósito — un log por ciclo,
  no un historial acumulado.

### Desinstalar

```bash
pkg uninstall shizuku-semi-auto
```
