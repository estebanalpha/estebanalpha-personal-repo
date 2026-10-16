# shizuku-semi-auto

*[English](#english) · [Español](#español)*

---

## English

Semi-automatic Shizuku activation using Termux + Termux:Boot + a loopback
ADB connection. After a one-time setup, the services start at boot,
connect to this same device over 127.0.0.1 and restart Shizuku whenever
it stops.

### How it works

Two connection modes (chosen by `shizuku-setup`, default by Android
version):

- **Wireless (Android 11+)**: pair once with `shizuku-pair`. From then on
  `adb-connect` finds the Wireless debugging port by itself, connects over
  TLS and pins adbd to the fixed loopback port 5555 (independent of
  WiFi). No input is needed at boot while Wireless debugging is on and
  its port can be read (see below).
- **Cable (any Android)**: once per boot, connect a cable (or a second
  Android/PC) and run `adb tcpip 5555` from that side. `adb-connect`
  detects the open port within a second and connects to itself. An
  optional USB-mode "priming" step runs before the cable is unplugged
  (see the caveat below).

**How the wireless port is found.** The TLS port changes every time
Wireless debugging is switched on and Android does not expose it to
Termux, so it is read from a notification of another app that shows it.
Order of attempts, at most 5 candidates per cycle, each confirmed with a
real `adb connect` and shell round-trip:

1. The last known port, if it still accepts connections.
2. Notifications of the configured app (default KeepADB, package
   `de.hohnepeople.keepadb`; any app if left empty). Patterns, in order:
   your custom filter, `Puerto`/`Port` followed by 4-5 digits, and as a
   last resort a 5-digit number inside a notification that mentions adb
   or debugging. Built-in patterns only accept ports 32768-60999.
3. If nothing works, a notification is shown (once) and `shizuku-pair`
   asks for the port.

Reading notifications needs `termux-api`, the Termux:API app, and notification access
granted to it. **That permission exposes ALL notifications to
Termux:API.** The scripts only inspect the configured app's
notification and store nothing but the port. Scanning the port range is
deliberately not used: it is far too slow to be practical.

**Shizuku start.** `shizuku-watchdog` detects the installed Shizuku
version and uses the right start command:

| Shizuku | Command |
|---|---|
| 13.6.0+ | direct exec of `libshizuku.so`, path resolved at runtime with a glob (its random per-install suffixes change on every update) |
| V4+ (Android 7+) | `sh /data/user_de/0/moe.shizuku.privileged.api/start.sh` |
| V4+ (Android 6) | `sh /data/user/0/moe.shizuku.privileged.api/start.sh` |
| V3.x | `sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh` (or `/sdcard/Android/data/<pkg>/files/start.sh`) |

The method that works is cached (`~/.local/tmp/shizuku-method.txt`),
tried first, and re-probed automatically if it stops working (for
example after a Shizuku update). Success is verified by checking the
`shizuku_server` process, not by parsing script output.

**Logs and notifications.** Each log is truncated when its service
starts. Identical consecutive messages are collapsed: the first one, a
second one as-is, and from the third on the second line is rewritten
with an `xN` suffix (N = repetitions after the first). Status
notifications (Termux:API) are sent once per state change and removed
when the problem clears: waiting for the ADB link, wireless port not
found, pairing missing, ADB not responding, Shizuku could not be
started, and an informational "restarted automatically".

### Setup and configuration

`shizuku-setup` runs at install time when a terminal is attached (on an
upgrade it asks whether to repeat the setup) and can be run again at any
time. It asks for the mode, the notification app and filter, the
priming policy and whether to show notifications; runs `shizuku-pair`
when needed; optionally lifts Android 12+'s child-process limit; and
starts the services right away. Settings live in
`~/.config/shizuku-semi-auto/config` (plain `KEY=value` lines):

| Key | Values | Meaning |
|---|---|---|
| `MODE` | `wireless`, `cable` | Connection mode (default: wireless on Android 11+, cable below) |
| `PRIMING` | `auto`, `on`, `off` | USB priming: `auto` = only in cable mode, `on` = always, `off` = never |
| `NOTIFY` | `1`, `0` | Status notifications |
| `PORT_APP` | package name, or empty | App whose notifications show the port (empty = any app) |
| `PORT_PATTERN` | extended regex, or empty | Custom filter that matches text containing the port |

The configuration is user data: uninstalling the package keeps it.

Optional, global system setting: on Android 12+ the setup can remove
the limit on background child processes (`max_phantom_processes`), which
otherwise may kill Termux sessions with `Process completed (signal 9)`.
It is applied through adb and is off by default; the services of this
package use few processes, so it is usually unnecessary.

### Requirements

- Termux:Boot installed and **opened at least once**.
- Termux:Boot and Termux:API (if used) must come from the **same
  source** as the main Termux app (GitHub or F-Droid — Android refuses
  to install apps that share Termux's signature scope if the signing
  keys differ). Check your current source with
  `echo $TERMUX_APK_RELEASE`.
- Shizuku app installed. For versions before 13.6: open its "ADB" tab
  once so it generates `start.sh`.
- Wireless mode: Android 11+ with Wireless debugging, and an app that
  shows its port in a notification (recommended: KeepADB). The first
  call to `termux-notification-list` may hang while Android asks for
  notification access; grant it and run the command again.
- Cable mode: a second Android device (or PC) with `adb`, once per boot.
- Optional: `pkg install -y termux-api` + the Termux:API app, for status
  notifications and for reading the wireless port.

### ⚠️ About the USB-mode priming

The priming in `adb-connect` exists because of a freeze diagnosed on a
specific device/ROM: unplugging the cable without a real USB-mode
transition left the ADB-over-WiFi shell permanently unresponsive.
**There is no guarantee this bug exists on a different device.** It
works by switching the USB functions to a different mode and then back
to the one you had, so your USB mode is not changed. With the default
`auto` it only runs in cable mode. To check whether a device needs it:

1. Set `PRIMING=off`, then run `tail -f ~/.local/tmp/adb-connect.log`
   in a second session.
2. With the cable connected, run `adb tcpip 5555` from the other device
   and unplug the cable.
3. Try `adb -s 127.0.0.1:5555 shell echo hola`. If it never hangs,
   this device probably does not have the bug.

Separate note: on some devices, keeping the default USB configuration on
"File transfer" together with ADB makes the ADB connection drop when the
screen turns off, while "Charging only" avoids it. If you need file
transfer and accept that the watchdog brings the connection back, keep it.

### Quick post-boot check

```bash
cat ~/.local/tmp/boot-adb-connect.log
cat ~/.local/tmp/boot-shizuku-watchdog.log
cat ~/.local/tmp/adb-connect.log
cat ~/.local/tmp/shizuku-watchdog.log
pgrep -fl adb-connect
pgrep -fl shizuku-watchdog
cat ~/.local/tmp/shizuku-method.txt   # start method in use
```

### Known limitations

- Wireless mode depends on the port being readable: Wireless debugging
  must be on (an app such as KeepADB can keep it on) and some app must
  show the port in a notification. Otherwise `shizuku-pair` asks for it.
- Cable mode: detecting the open port is a race against the cable being
  unplugged too early — not a mathematical guarantee, though the margin
  is wide (polling every second; a human takes longer to react).
- If the priming runs while the cable is in active use for something
  mode-sensitive (for example an active MTP transfer), it can interrupt it.
- Logs are truncated on every start on purpose — one log per cycle, not
  an accumulated history.

### Troubleshooting

- **`adb` fails with `CANNOT LINK EXECUTABLE ... cannot locate symbol
  "_ZNSt6__ndk113__hash_memoryEPKvm"`**: your `libc++` is older than the
  installed `android-tools` build (stale/partial Termux upgrade, or
  mixing F-Droid and GitHub builds). Fix:
  `pkg update && pkg upgrade -y`, then `pkg reinstall android-tools`.
  The postinst prints this same hint when it detects the broken state.
- **Wireless mode keeps notifying "port not found"**: check that Wireless
  debugging is on, that the notification app is running, and that
  `shizuku-setup` has the right package name. You can test the filter by
  running `shizuku-pair`: it reports the port it found.
- **Wireless mode notifies "could not connect"**: the pairing is missing
  or was removed. Run `shizuku-pair` and pair again.

### Uninstall

```bash
pkg uninstall shizuku-semi-auto
```

The configuration (`~/.config/shizuku-semi-auto`) and the logs are kept.

---

## Español

Activación semi-automática de Shizuku usando Termux + Termux:Boot + una
conexión ADB por loopback. Tras una configuración inicial, los servicios
arrancan con el equipo, se conectan a este mismo dispositivo por
127.0.0.1 y reinician Shizuku cada vez que se detiene.

### Cómo funciona

Dos modos de conexión (los elige `shizuku-setup`, por defecto según la
versión de Android):

- **Inalámbrico (Android 11+)**: se empareja una vez con `shizuku-pair`.
  Desde entonces `adb-connect` encuentra solo el puerto de la depuración
  inalámbrica, conecta por TLS y fija adbd al puerto loopback 5555
  (independiente del WiFi). No hace falta ninguna acción al arrancar
  mientras la depuración inalámbrica esté activa y su puerto se pueda
  leer (ver abajo).
- **Cable (cualquier Android)**: una vez por arranque, conecta un cable
  (u otro Android/PC) y ejecuta `adb tcpip 5555` desde ese lado.
  `adb-connect` detecta el puerto abierto en menos de un segundo y se
  conecta a sí mismo. Un paso opcional de "priming" de modo USB se
  ejecuta antes de desconectar el cable (ver la advertencia abajo).

**Cómo se encuentra el puerto inalámbrico.** El puerto TLS cambia cada
vez que se activa la depuración inalámbrica y Android no lo expone a
Termux, así que se lee de una notificación de otra app que lo muestre.
Orden de intentos, como máximo 5 candidatos por ciclo, cada uno
confirmado con un `adb connect` real y una respuesta de shell:

1. El último puerto conocido, si todavía acepta conexiones.
2. Notificaciones de la app configurada (por defecto KeepADB, paquete
   `de.hohnepeople.keepadb`; cualquier app si se deja vacío). Patrones,
   en orden: tu filtro personalizado, `Puerto`/`Port` seguido de 4-5
   dígitos y, como último recurso, un número de 5 dígitos dentro de una
   notificación que mencione adb o depuración. Los patrones integrados
   solo aceptan puertos entre 32768 y 60999.
3. Si nada funciona, se muestra una notificación (una vez) y
   `shizuku-pair` pide el puerto.

Leer notificaciones requiere `termux-api`, la app Termux:API y que se le
conceda el acceso a notificaciones. **Ese permiso expone TODAS las
notificaciones a Termux:API.** Los scripts solo examinan la notificación
de la app configurada y no guardan nada salvo el puerto. No se usa el
escaneo del rango de puertos a propósito: es demasiado lento para ser
práctico.

**Arranque de Shizuku.** `shizuku-watchdog` detecta la versión de
Shizuku instalada y usa el comando de arranque correcto:

| Shizuku | Comando |
|---|---|
| 13.6.0+ | ejecución directa de `libshizuku.so`, ruta resuelta en tiempo de ejecución con glob (sus sufijos aleatorios por instalación cambian en cada actualización) |
| V4+ (Android 7+) | `sh /data/user_de/0/moe.shizuku.privileged.api/start.sh` |
| V4+ (Android 6) | `sh /data/user/0/moe.shizuku.privileged.api/start.sh` |
| V3.x | `sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh` (o `/sdcard/Android/data/<pkg>/files/start.sh`) |

El método que funciona queda en caché (`~/.local/tmp/shizuku-method.txt`),
se prueba primero y se vuelve a detectar solo si deja de funcionar (por
ejemplo tras una actualización de Shizuku). El éxito se verifica mirando
el proceso `shizuku_server`, no analizando la salida del script.

**Registros y notificaciones.** Cada registro se vacía cuando arranca su
servicio. Los mensajes idénticos consecutivos se agrupan: el primero, un
segundo tal cual y, desde el tercero, la segunda línea se reescribe con
el sufijo `xN` (N = repeticiones después de la primera). Las
notificaciones de estado (Termux:API) se envían una vez por cambio de
estado y se quitan cuando el problema desaparece: esperando el enlace
ADB, puerto inalámbrico no encontrado, falta el emparejamiento, ADB no
responde, no se pudo iniciar Shizuku, y un aviso informativo de
"reiniciado automáticamente".

### Configuración

`shizuku-setup` se ejecuta al instalar cuando hay una terminal conectada
(en una actualización pregunta si se repite la configuración) y se puede
volver a ejecutar cuando quieras. Pregunta el modo, la app de
notificaciones y su filtro, la política de priming y si mostrar
notificaciones; ejecuta `shizuku-pair` cuando hace falta; opcionalmente
quita el límite de procesos secundarios de Android 12+; e inicia los
servicios al instante. Los ajustes viven en
`~/.config/shizuku-semi-auto/config` (líneas `CLAVE=valor`):

| Clave | Valores | Significado |
|---|---|---|
| `MODE` | `wireless`, `cable` | Modo de conexión (por defecto: inalámbrico en Android 11+, cable en versiones anteriores) |
| `PRIMING` | `auto`, `on`, `off` | Priming USB: `auto` = solo en modo cable, `on` = siempre, `off` = nunca |
| `NOTIFY` | `1`, `0` | Notificaciones de estado |
| `PORT_APP` | nombre de paquete, o vacío | App cuyas notificaciones muestran el puerto (vacío = cualquier app) |
| `PORT_PATTERN` | regex extendida, o vacío | Filtro personalizado que coincide con el texto que contiene el puerto |

La configuración es dato del usuario: desinstalar el paquete la conserva.

Opcional, ajuste global del sistema: en Android 12+ la configuración
puede quitar el límite de procesos secundarios en segundo plano
(`max_phantom_processes`), que de otro modo puede cerrar sesiones de
Termux con `Process completed (signal 9)`. Se aplica por adb y está
desactivado por defecto; los servicios de este paquete usan pocos
procesos, así que normalmente no hace falta.

### Requisitos

- Termux:Boot instalada y **abierta al menos una vez**.
- Termux:Boot y Termux:API (si se usa) tienen que venir de la **misma
  fuente** que el Termux principal (GitHub o F-Droid — Android rechaza
  instalar apps que comparten el alcance de firma de Termux si las
  claves de firma difieren). Comprueba tu fuente actual con
  `echo $TERMUX_APK_RELEASE`.
- App Shizuku instalada. En versiones anteriores a 13.6: entra una vez
  a su pestaña "ADB" para que genere `start.sh`.
- Modo inalámbrico: Android 11+ con depuración inalámbrica, y una app
  que muestre su puerto en una notificación (recomendada: KeepADB). La
  primera llamada a `termux-notification-list` puede quedarse colgada
  mientras Android pide el acceso a notificaciones; concédelo y vuelve a
  ejecutar el comando.
- Modo cable: un segundo dispositivo Android (o PC) con `adb`, una vez
  por arranque.
- Opcional: `pkg install -y termux-api` + la app Termux:API, para las
  notificaciones de estado y para leer el puerto inalámbrico.

### ⚠️ Sobre el priming de modo USB

El priming de `adb-connect` existe por un cuelgue diagnosticado en un
dispositivo/ROM concreto: al desconectar el cable sin una transición
real de modo USB, el shell ADB por WiFi quedaba permanentemente sin
respuesta. **No hay garantía de que este fallo exista en otro
dispositivo.** Funciona cambiando las funciones USB a un modo distinto
y volviendo después al que tenías, de modo que tu modo USB no cambia.
Con el valor `auto` solo se ejecuta en modo cable. Para comprobar si un
equipo lo necesita:

1. Pon `PRIMING=off` y ejecuta `tail -f ~/.local/tmp/adb-connect.log` en
   una segunda sesión.
2. Con el cable conectado, ejecuta `adb tcpip 5555` desde el otro equipo
   y desconecta el cable.
3. Prueba `adb -s 127.0.0.1:5555 shell echo hola`. Si nunca se cuelga,
   este equipo probablemente no tiene el fallo.

Nota aparte: en algunos equipos, dejar la configuración USB
predeterminada en "Transferencia de archivos" junto con ADB hace que la
conexión ADB se caiga al apagar la pantalla, mientras que "Solo carga"
lo evita. Si necesitas la transferencia de archivos y aceptas que el
watchdog restablezca la conexión, puedes dejarlo así.

### Comprobación rápida tras el arranque

```bash
cat ~/.local/tmp/boot-adb-connect.log
cat ~/.local/tmp/boot-shizuku-watchdog.log
cat ~/.local/tmp/adb-connect.log
cat ~/.local/tmp/shizuku-watchdog.log
pgrep -fl adb-connect
pgrep -fl shizuku-watchdog
cat ~/.local/tmp/shizuku-method.txt   # método de arranque en uso
```

### Limitaciones conocidas

- El modo inalámbrico depende de que el puerto se pueda leer: la
  depuración inalámbrica debe estar activa (una app como KeepADB puede
  mantenerla activa) y alguna app debe mostrar el puerto en una
  notificación. Si no, `shizuku-pair` lo pide.
- Modo cable: detectar el puerto abierto compite contra la desconexión
  prematura del cable — no es una garantía matemática, aunque el margen
  es amplio (sondeo cada segundo; una persona tarda más en reaccionar).
- Si el priming se ejecuta mientras el cable se usa para algo sensible
  al modo (por ejemplo una transferencia MTP activa), puede
  interrumpirla.
- Los registros se vacían en cada arranque a propósito — un registro por
  ciclo, no un historial acumulado.

### Solución de problemas

- **`adb` falla con `CANNOT LINK EXECUTABLE ... cannot locate symbol
  "_ZNSt6__ndk113__hash_memoryEPKvm"`**: tu `libc++` es más antigua que
  el build de `android-tools` instalado (actualización de Termux a
  medias, o mezcla de builds de F-Droid y GitHub). Arreglo:
  `pkg update && pkg upgrade -y` y después `pkg reinstall android-tools`.
  El postinst imprime esta misma ayuda si detecta el estado roto.
- **El modo inalámbrico avisa una y otra vez "puerto no encontrado"**:
  comprueba que la depuración inalámbrica esté activa, que la app de
  notificaciones esté en ejecución y que `shizuku-setup` tenga el nombre
  de paquete correcto. Puedes probar el filtro ejecutando `shizuku-pair`:
  informa del puerto que encontró.
- **El modo inalámbrico avisa "no se pudo conectar"**: falta el
  emparejamiento o se eliminó. Ejecuta `shizuku-pair` y empareja de
  nuevo.

### Desinstalar

```bash
pkg uninstall shizuku-semi-auto
```

La configuración (`~/.config/shizuku-semi-auto`) y los registros se conservan.
