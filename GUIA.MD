# Guía para IA: empaquetado en estebanalpha-personal-repo

Esta guía define cómo crear, modificar, revisar y depurar paquetes para este repositorio personal de Termux. El objetivo es producir paquetes consistentes, instalables con `pkg`/`apt`, y seguros en Android/Termux sin root. No se debe asumir un sistema Linux de escritorio.

## 0. Decisiones fijas del proyecto

- Textos visibles para usuarios: inglés y español.
- Español del proyecto: neutro.
- Comentarios de código: inglés.
- No incluir referencias a sesiones de depuración locales, dispositivos concretos, pruebas privadas ni intentos anteriores.
- Shebang obligatorio para scripts instalados y maintainer scripts:

```sh
#!/data/data/com.termux/files/usr/bin/bash
```

- Declarar dependencias reales siempre, aunque Termux normalmente traiga la herramienta.
- Documentación instalable: usar convención FHS/Debian bajo `$PREFIX/share/...`.
- Versionado:
  - Si no hay upstream claro: `X.Y.Z`.
  - Si hay upstream claro: usar versión upstream más revisión de empaquetado, por ejemplo `13.5.4-1`.
- Commits: mensajes en inglés, cortos y descriptivos.
- El paquete debe funcionar aunque el usuario no tenga configuraciones locales especiales.

## 1. Contexto del repo

Repo:

```text
https://github.com/estebanalpha/estebanalpha-personal-repo
```

GitHub Pages sirve el directorio `docs/`.

El repo se agrega en un dispositivo con:

```sh
curl -sL https://estebanalpha.github.io/estebanalpha-personal-repo/add-repo.sh | bash
```

Eso crea:

```text
$PREFIX/etc/apt/sources.list.d/estebanalpha-repo.list
```

con una línea tipo:

```sh
deb [trusted=yes] https://estebanalpha.github.io/estebanalpha-personal-repo/ ./
```

El índice es flat y sin firmar. `[trusted=yes]` es intencional.

El build se realiza con:

```sh
./build.sh
```

Ese script reconstruye los `.deb` bajo `docs/` y regenera:

```text
docs/Packages
docs/Packages.gz
```

No usar `dpkg-scanpackages` ni `apt-ftparchive`. El método del repo usa `dpkg-deb -f`, checksums y `gzip`.

## 2. Entorno real: Termux/Android

Cualquier solución debe asumir este entorno:

- Prefix de Termux:

```text
/data/data/com.termux/files/usr
```

- Home de Termux:

```text
/data/data/com.termux/files/home
```

- No hay root.
- `/system` es read-only para Termux.
- `/` no es escribible por dpkg.
- No existe `/usr/bin/env` como shebang portable.
- No existe `/bin/bash` como shebang portable.
- No hay systemd.
- No hay sudo.
- No hay cron del sistema.
- No hay gestores de servicios tradicionales.
- Los binarios de Termux viven bajo `$PREFIX/bin`.
- Los binarios del sistema Android viven bajo `/system/bin`.
- Un binario de Termux y uno del sistema pueden ser de distinta arquitectura/bitness en un mismo dispositivo.
- Termux suele exportar:

```text
LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec-ld-preload.so
```

Eso puede romper binarios del sistema si hay mismatch 32/64.

## 3. Reglas duras

### Sí hacer

- Instalar comandos package-managed en `$PREFIX/bin`.
- Instalar librerías, loaders o recursos en `$PREFIX/lib/<paquete>/` cuando corresponda.
- Usar shebang absoluto de Termux.
- Limpiar `LD_PRELOAD` antes de ejecutar binarios del sistema.
- Declarar dependencias reales.
- Hacer scripts idempotentes.
- Hacer mensajes bilingüe EN/ES.
- Usar español neutro en textos de proyecto.
- Escribir comentarios de código en inglés.
- Mantener README de paquete fuera del payload del `.deb`.
- Verificar contenido del `.deb` con `dpkg-deb -c`.
- Bump de versión cuando cambia el contenido publicado.
- Commitear `docs/` después de `./build.sh`.

### No hacer

- No usar `#!/bin/bash`.
- No usar `#!/usr/bin/env bash`.
- No usar `#!/system/bin/sh` para comandos de usuario lanzados desde Termux.
- No confiar en limpiar `LD_PRELOAD` dentro de un intérprete del sistema si ese intérprete puede no arrancar.
- No instalar binarios package-managed en `$HOME/.local/bin` o `$HOME/.local/lib`.
- No instalar nada en `/README.md`, `/build.sh`, `/DEBIAN`, etc.
- No poner el README del paquete al mismo nivel que `DEBIAN/` si el build no hace staging.
- No editar `docs/Packages` a mano.
- No reutilizar una versión ya publicada si el `.deb` cambió o estaba roto.
- No asumir comandos de Linux desktop.
- No usar `sudo`, `systemctl`, `service`, `crontab`, `update-rc.d`, `useradd`, `chown root`, `mount`, `setenforce`, etc.
- No modificar `/system`.
- No descargar archivos obligatorios durante `postinst` salvo decisión explícita y documentada.
- No hacer `postinst` interactivo.
- No mezclar fuentes de Termux y add-ons: F-Droid con GitHub rompe firmas.

## 4. Estructura canónica de un paquete

Paquete normal que instala comandos bajo `$PREFIX`:

```text
packages/<name>/
├── DEBIAN/
│   ├── control
│   ├── postinst        # optional
│   └── prerm           # optional
├── README.md           # repo documentation, NOT payload
└── data/
    └── data/
        └── com.termux/
            └── files/
                └── usr/
                    ├── bin/
                    │   └── <command>
                    ├── lib/
                    │   └── <name>/
                    │       └── <resources>
                    └── share/
                        ├── doc/
                        │   └── <name>/
                        ├── man/
                        └── examples/
```

Ejemplo real:

```text
packages/rish-shizuku/
├── DEBIAN/
│   ├── control
│   └── postinst
├── README.md
└── data/data/com.termux/files/usr/
    ├── bin/rish
    └── lib/rish/
        ├── rish_shizuku.dex
        └── rish_shizuku.so -> rish_shizuku.dex
```

El archivo `packages/<name>/README.md` está bien para GitHub, pero no debe entrar al `.deb` como `/README.md`.

## 5. build.sh correcto

El build correcto debe empaquetar solamente:

```text
DEBIAN/
data/
```

Cualquier otra cosa en `packages/<name>/`, como `README.md`, debe quedar fuera del payload.

La forma correcta es usar un directorio de staging temporal, por ejemplo:

```text
.build/<name>/
```

y copiar allí solo:

```text
packages/<name>/DEBIAN
packages/<name>/data
```

Luego:

```sh
dpkg-deb --build --root-owner-group .build/<name> docs/
```

Verificación rápida:

```sh
grep -n 'BUILD_DIR' build.sh
grep -n 'cp -a "$pkgdir/DEBIAN"' build.sh
grep -n 'cp -a "$pkgdir/data"' build.sh
```

Si esas líneas no existen, el `build.sh` está en versión vieja y puede empaquetar archivos no deseados, causando errores como:

```text
unable to create '/README.md.dpkg-new': Read-only file system
```

No usar directamente:

```sh
dpkg-deb --build "$pkgdir" docs/
```

si `$pkgdir` contiene archivos que no son payload.

## 6. DEBIAN/control

Plantilla recomendada:

```text
Package: nombre-del-paquete
Version: 1.0.0
Architecture: all
Maintainer: estebanalpha
Depends: bash
Section: utils
Priority: optional
Description: Short English description
 Long description line 1.
 Long description line 2.
```

Reglas:

- `Package`: minúsculas, guiones, sin espacios.
- `Version`: no reutilizar versiones ya publicadas si el contenido cambió.
- `Architecture: all`: solo si no hay binarios nativos específicos.
- Si el paquete contiene ELF nativos, `Architecture: all` está mal.
- `Description`: primera línea corta en inglés.
- Líneas largas comienzan con espacio.
- No usar Markdown dentro de `Description`.
- No usar caracteres raros si no hacen falta.

### Versionado

Si el paquete no tiene upstream claro:

```text
1.0.0
1.0.1
1.1.0
2.0.0
```

Si el paquete envuelve un upstream con versión clara:

```text
<upstream-version>-<package-revision>
```

Ejemplos:

```text
13.5.4-1
13.5.4-2
2026.07.30-1
```

Si el upstream cambia, se actualiza la parte upstream. Si solo cambia el empaquetado, se incrementa la revisión.

Si no se puede determinar la versión upstream, usar `X.Y.Z` y documentar el origen del archivo en el README del paquete.

### Política de dependencias

Declarar dependencias reales siempre.

Ejemplos:

- Shebang bash:

```text
Depends: bash
```

- Comandos básicos de GNU:

```text
Depends: bash, coreutils
```

- Si usa `grep`:

```text
Depends: grep
```

- Si usa `sed`:

```text
Depends: sed
```

- Si usa `awk`:

```text
Depends: gawk
```

- Si usa `find` o `xargs`:

```text
Depends: findutils
```

- Si usa `curl`:

```text
Depends: curl
```

- Si usa `jq`:

```text
Depends: jq
```

- Si usa `python`:

```text
Depends: python
```

- Si usa `adb`:

```text
Depends: android-tools
```

- Si usa `termux-notification`, `termux-toast`, etc.:

```text
Depends: termux-api
```

Si se usan binarios del sistema como `/system/bin/getprop`, `/system/bin/app_process`, `/system/bin/am`, `/system/bin/pm`, no se declara dependencia Debian, pero se deben usar rutas absolutas y probarlos.

Las apps Android externas, como Termux:API, Termux:Boot o Shizuku, no van en `Depends`. Se documentan en `postinst` y README.

## 7. Maintainer scripts

Shebang obligatorio:

```sh
#!/data/data/com.termux/files/usr/bin/bash
```

Inicio recomendado:

```sh
set -e
```

Reglas:

- No interactivo.
- Idempotente.
- Debe poder correr dos veces sin romper.
- No descargar archivos obligatorios durante instalación.
- No imprimir contexto personal ni referencias a dispositivos concretos.
- Mensaje final bilingüe EN/ES.
- Español neutro.
- Si toca `$HOME`, debe ser por una razón Android/Termux concreta.
- Si modifica archivos del usuario, usar bloques marcados y deduplicados.
- `prerm` debe limpiar solo lo que el paquete instaló, no datos del usuario.

Ejemplo de `postinst`:

```sh
#!/data/data/com.termux/files/usr/bin/bash
set -e

# Termux prefix, with fallback for environments where PREFIX is unset.
P="${PREFIX:-/data/data/com.termux/files/usr}"

chmod 755 "$P/bin/example" 2>/dev/null || true

cat <<'MSG'
== example installed / instalado ==
EN - Example package installed.
     Run it with: example

ES - Paquete example instalado.
     Ejecuta con: example
MSG
```

Ejemplo de `prerm` solo si hace falta:

```sh
#!/data/data/com.termux/files/usr/bin/bash
set -e

# Termux home, with fallback for environments where HOME is unset.
DEST_HOME="${HOME:-/data/data/com.termux/files/home}"

rm -f "$DEST_HOME/.termux/boot/example-boot" 2>/dev/null || true

exit 0
```

## 8. Payload: dónde va cada cosa

### Comandos ejecutables

```text
$PREFIX/bin/<comando>
```

Permisos: `755`.

### Librerías, loaders o recursos privados del paquete

```text
$PREFIX/lib/<paquete>/
```

Ejemplo:

```text
$PREFIX/lib/rish/rish_shizuku.dex
```

### Documentación instalable

Usar convención FHS/Debian:

```text
$PREFIX/share/doc/<paquete>/
```

Ejemplo:

```text
$PREFIX/share/doc/example/README.md
$PREFIX/share/doc/example/copyright
```

No instalar documentación por defecto si no aporta. El README principal puede vivir solo en `packages/<paquete>/README.md`.

### Man pages

```text
$PREFIX/share/man/man1/<comando>.1.gz
```

### Ejemplos

```text
$PREFIX/share/examples/<paquete>/
```

### Bash completion

```text
$PREFIX/share/bash-completion/completions/<comando>
```

### Configuración global

```text
$PREFIX/etc/
```

Si el usuario puede editarla y no debe perderse al actualizar, considerar `Conffiles`.

### Recursos internos que no van en PATH

```text
$PREFIX/opt/<paquete>/
```

Este patrón es útil cuando un `postinst` debe copiar cosas a `$HOME`, por ejemplo scripts de Termux:Boot.

### HOME y ~/.local

`$HOME` no es el lugar principal para binarios package-managed.

`~/.local/bin` y `~/.local/lib` son para pruebas del usuario o scripts manuales, no para paquetes formales.

Excepciones razonables en `$HOME`:

- configs del usuario: `~/.config/<paquete>/`
- estado: `~/.local/state/<paquete>/`
- cache: `~/.cache/<paquete>/`
- scripts de boot copiados por `postinst`: `~/.termux/boot/`
- datos de apps que siguen XDG por sí mismas

Si un paquete instala binarios en `~/.local/bin`, está mal salvo contexto muy especial.

## 9. Scripts instalados

### Shebang

Para comandos instalados por paquetes:

```sh
#!/data/data/com.termux/files/usr/bin/bash
```

Para scripts Python, si se instalan como comandos:

```sh
#!/data/data/com.termux/files/usr/bin/python
```

No usar variables sin expandir en shebang:

```sh
#!/usr/bin/env python
#!/bin/bash
```

### Comentarios

Los comentarios deben estar en inglés y explicar el porqué estable, no el historial local.

Correcto:

```bash
# Use Termux bash because system sh may fail when LD_PRELOAD has a
# Termux library with a different bitness.
```

Incorrecto:

```bash
# fixed after Huawei test
# previous attempt failed here
```

No dejar comentarios que hagan referencia a sesiones locales, dispositivos concretos o parches temporales.

### Minimizar dependencias de comandos externos

Para lógica interna, preferir builtins de bash.

Evitar depender de `printf` externo, `dirname` externo, `basename` externo, etc., si se puede resolver con bash.

Mal para un wrapper crítico:

```sh
DEX=$(find_loader)
```

donde `find_loader` imprime con `printf` externo.

Mejor:

```bash
LOADER=""
for dir in ...; do
    [[ -d "$dir" ]] || continue
    for name in ...; do
        if [[ -f "$dir/$name" ]]; then
            LOADER="$dir/$name"
            break 2
        fi
    done
done
```

### Debug

Si un script soporta debug:

```bash
[[ -n "${EXAMPLE_DEBUG:-}" ]] && echo "[example] message" >&2
```

El debug va a stderr, nunca a stdout si stdout se usa para devolver datos.

### Overrides

Si el script busca archivos, permitir override por variable de entorno:

```bash
if [[ -n "${EXAMPLE_LOADER:-}" && -f "${EXAMPLE_LOADER:-}" ]]; then
    LOADER="${EXAMPLE_LOADER}"
fi
```

Documentar esa variable en README.

### Exit codes

Si el wrapper lanza otro proceso como comando principal, usar `exec`:

```bash
exec /system/bin/app_process ...
```

## 10. LD_PRELOAD, app_process y Shizuku

Termux suele tener:

```text
LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec-ld-preload.so
```

Eso puede ser incompatible con binarios del sistema si hay mismatch 32/64.

Error típico:

```text
CANNOT LINK EXECUTABLE "/system/bin/sh":
"/data/data/com.termux/files/usr/lib/libtermux-exec-ld-preload.so" is 32-bit instead of 64-bit
```

Conclusión: si un script va a ejecutar `/system/bin/app_process`, `/system/bin/getprop`, u otros binarios del sistema, debe:

1. Arrancar con intérprete de Termux.
2. Una vez adentro, limpiar `LD_PRELOAD`.
3. Recién entonces ejecutar el binario del sistema.

Patrón correcto:

```bash
#!/data/data/com.termux/files/usr/bin/bash
: "${PREFIX:=/data/data/com.termux/files/usr}"

# Clean environment before launching system binaries.
unset LD_PRELOAD 2>/dev/null || true

SDK=$(/system/bin/getprop ro.build.version.sdk 2>/dev/null)
[[ "$SDK" =~ ^[0-9]+$ ]] || SDK=0

exec /system/bin/app_process \
    -Djava.class.path="$LOADER" /system/bin \
    --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "$@"
```

Para wrappers de Shizuku/rish:

- `RISH_APPLICATION_ID` por defecto:

```text
com.termux
```

- Loader DEX en:

```text
$PREFIX/lib/rish/rish_shizuku.dex
```

- En Android 14+, el loader no debe tener permiso de escritura.
- Si el loader es DEX, mantener extensión `.dex`.
- Si se quiere compatibilidad con scripts que buscan `.so`, usar symlink `.so -> .dex`.
- Verificar magic si hay dudas:

```sh
head -c 8 archivo | od -An -tx1 -c
```

DEX empieza con:

```text
d e x
```

ELF empieza con:

```text
177 E L F
```

## 11. Patrón /opt + postinst para HOME/boot

dpkg instala bien bajo `$PREFIX`, pero algunas integraciones de usuario necesitan `$HOME`, por ejemplo Termux:Boot:

```text
$HOME/.termux/boot/
```

En esos casos:

1. El paquete instala recursos bajo:

```text
$PREFIX/opt/<paquete>/
```

2. `postinst` copia a `$HOME` lo necesario.
3. `prerm` limpia las copias package-managed.
4. No pisar configuraciones del usuario sin aviso.

Ejemplo de destino boot:

```text
/data/data/com.termux/files/home/.termux/boot/<script>
```

Los scripts de boot deben tener shebang absoluto de Termux y ser ejecutables.

Advertencia general para add-ons de Termux:

- Termux, Termux:API, Termux:Boot, Termux:Float, Termux:Tasker, etc., deben venir de la misma fuente: F-Droid o GitHub.
- Mezclar fuentes puede romper firma y permisos.
- Play Store no es una fuente válida para Termux actualizado.

## 12. README y mensajes

### Idiomas

- README principal: inglés y español.
- README de paquete: inglés y español.
- Mensajes de `postinst`: inglés y español.
- Español: neutro.
- Comentarios de código: inglés.
- Commits: inglés.

No incluir referencias al estilo de conversación ni preferencias de chat dentro del proyecto.

### README principal del repo

Cuando se agrega un paquete, actualizar las dos secciones:

- sección inglesa `Packages`
- sección española `Paquetes`

Formato:

```md
nombre-paquete — short English description.
```

```md
nombre-paquete — descripción corta en español.
```

Mantener estilo con em dash `—` y frases cortas.

### README del paquete

Ubicación:

```text
packages/<paquete>/README.md
```

Estructura recomendada:

```md
# nombre-paquete

[English](#english) · [Español](#español)

## English

Short description.

Installed files:

- `$PREFIX/bin/...`
- `$PREFIX/lib/...`

Usage:

    command
    command --help

Notes:

- Relevant note.

## Español

Descripción corta.

Archivos instalados:

- `$PREFIX/bin/...`
- `$PREFIX/lib/...`

Uso:

    comando
    comando --help

Notas:

- Nota relevante.
```

No incluir contexto personal, nombres de dispositivos propios ni soluciones temporales privadas.

### Mensajes de postinst

Estructura recomendada:

```text
== paquete installed / instalado ==
EN - ...
ES - ...
```

No decir cosas como:

- “como tenías en el Huawei”
- “la función vieja de tu bashrc”
- “tu copia de .local”

Sí se puede decir genéricamente:

```text
If `command -v paquete` does not point to $PREFIX/bin/paquete,
another copy earlier in PATH is taking precedence.
```

## 13. Publicación y pruebas

Versionar, construir y publicar:

```sh
./build.sh
git add packages/<name> docs README.md
git commit -m "Add <name>"
git push
```

Si se modificó un paquete existente:

```sh
./build.sh
git add packages/<name> docs README.md
git commit -m "Fix <name> ..."
git push
```

Verificación remota después de push:

```sh
curl -fsSL https://estebanalpha.github.io/estebanalpha-personal-repo/Packages.gz \
  | gunzip \
  | awk '/^Package: <name>$/,/^$/'
```

Los 404 de `InRelease`/`Release` son normales en repo plano sin firmar.

Que APT muestre intentos fallidos contra `Packages` y luego baje `Packages.gz` puede ser ruido normal. Lo importante es que el índice y el `.deb` se descarguen.

## 14. Flujo recomendado para crear un paquete nuevo

Cuando se pida un paquete nuevo, definir primero:

1. Nombre del paquete.
2. Descripción corta EN/ES.
3. Qué archivos instala.
4. Si son scripts, loaders, binarios nativos o datos.
5. Dependencias reales.
6. Si necesita `$HOME` o boot.
7. Si necesita Shizuku, adb, Termux:API, Termux:Boot, etc.
8. Si necesita limpiar `LD_PRELOAD`.
9. Si necesita Android 14+ read-only.
10. Si hay archivos externos cuyo origen hay que documentar.
11. Si existe versión upstream clara.
12. Si corresponde instalar documentación bajo `$PREFIX/share/doc/<paquete>`.

Luego crear esqueleto:

```sh
cd ~/estebanalpha-personal-repo

name="example-tool"
pkg="packages/$name"
root="$pkg/data/data/com.termux/files/usr"

mkdir -p "$pkg/DEBIAN" "$root/bin"
```

Crear `control`, scripts, README, build, verificación y commit.

## 15. Checklist obligatorio antes de commit

Como mínimo:

```sh
# Maintainer script syntax
bash -n packages/<name>/DEBIAN/postinst
bash -n packages/<name>/DEBIAN/prerm 2>/dev/null || true

# Installed command syntax
bash -n packages/<name>/data/data/com.termux/files/usr/bin/<command>

# Correct shebangs
head -n 1 packages/<name>/data/data/com.termux/files/usr/bin/<command>
head -n 1 packages/<name>/DEBIAN/postinst

# Build
./build.sh

# Deb content
dpkg-deb -c docs/<name>_*_all.deb

# No unwanted root payload
dpkg-deb -c docs/<name>_*_all.deb | grep -E ' \./README\.md$| \./build\.sh$| \./DEBIAN' || echo OK

# Metadata
dpkg-deb -I docs/<name>_*_all.deb
```

El `dpkg-deb -c` debe mostrar solamente rutas bajo:

```text
./data/data/com.termux/files/usr/...
```

No debe mostrar:

```text
./README.md
./build.sh
./DEBIAN
```

### Prueba local

```sh
pkg install --reinstall ./docs/<name>_<version>_all.deb
hash -r
command -v <command>
<command>
```

Si hay sombras en PATH:

```sh
type -a <command>
```

Si aparece `~/.local/bin/<command>` antes que `$PREFIX/bin/<command>`, el paquete no se está usando.

### Prueba con LD_PRELOAD si el paquete lanza binarios del sistema

```sh
LD_PRELOAD="$PREFIX/lib/libtermux-exec-ld-preload.so" <command>
```

Si falla con mismatch 32/64, el shebang o el saneamiento de entorno están mal.

## 16. Errores históricos y cómo evitarlos

### Error: `unable to create '/README.md.dpkg-new': Read-only file system`

Causa:

```text
dpkg-deb --build packages/<name>
```

empaquetó un archivo que estaba al mismo nivel que `DEBIAN/`, por ejemplo:

```text
packages/<name>/README.md
```

Ese archivo se interpretó como payload a instalar en `/README.md`.

Solución:

- build con staging.
- copiar solo `DEBIAN/` y `data/` al directorio de build.
- verificar con `dpkg-deb -c`.

### Error: `CANNOT LINK EXECUTABLE "/system/bin/sh": ... is 32-bit instead of 64-bit`

Causa:

Un script con shebang:

```sh
#!/system/bin/sh
```

fue lanzado desde Termux con `LD_PRELOAD` activo, y el intérprete del sistema no podía cargar la librería de Termux por mismatch de bitness.

Solución:

- usar shebang de Termux:

```sh
#!/data/data/com.termux/files/usr/bin/bash
```

- limpiar `LD_PRELOAD` dentro del script.
- recién entonces ejecutar binarios del sistema.

### Error: `CANNOT LINK EXECUTABLE "printf": can't read file ".../usr/lib": Is a directory`

Causa:

El wrapper dependía de un comando externo frágil en un entorno donde el linker estaba contaminado o el comando externo no era confiable.

Solución:

- usar builtins de bash.
- no devolver rutas mediante comandos externos frágiles.
- usar variables y búsqueda directa.

### Error: el comando instalado no se usa

Causa:

`PATH` tiene antes:

```text
$HOME/.local/bin
```

y existe ahí una copia vieja del comando.

Diagnóstico:

```sh
type -a <command>
command -v <command>
```

Solución:

- mover o borrar la copia vieja de `~/.local/bin`.
- `hash -r`.
- verificar de nuevo.

### Error: primera ejecución de Shizuku falla con timeout

Causa:

Primera vez que Shizuku muestra diálogo de permiso.

Solución:

- aceptar el permiso.
- verificar que Shizuku esté activo.
- reintentar.

## 17. Plantilla mínima de paquete

Ejemplo genérico `example-tool`.

Estructura:

```text
packages/example-tool/
├── DEBIAN/
│   ├── control
│   └── postinst
├── README.md
└── data/data/com.termux/files/usr/bin/example-tool
```

Comandos:

```sh
cd ~/estebanalpha-personal-repo

name="example-tool"
pkg="packages/$name"
root="$pkg/data/data/com.termux/files/usr"

mkdir -p "$pkg/DEBIAN" "$root/bin"
```

`DEBIAN/control`:

```text
Package: example-tool
Version: 0.1.0
Architecture: all
Maintainer: estebanalpha
Depends: bash
Section: utils
Priority: optional
Description: Example tool for Termux
 Example long description line one.
 Example long description line two.
```

`DEBIAN/postinst`:

```sh
#!/data/data/com.termux/files/usr/bin/bash
set -e

# Termux prefix, with fallback for environments where PREFIX is unset.
P="${PREFIX:-/data/data/com.termux/files/usr}"

chmod 755 "$P/bin/example-tool" 2>/dev/null || true

cat <<'MSG'
== example-tool installed / instalado ==
EN - Example tool installed.
     Run it with: example-tool

ES - Herramienta example instalada.
     Ejecuta con: example-tool
MSG
```

`data/data/com.termux/files/usr/bin/example-tool`:

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -e

# Use Termux prefix as fallback when PREFIX is not exported.
: "${PREFIX:=/data/data/com.termux/files/usr}"

echo "example-tool ok"
```

Permisos:

```sh
chmod 755 "$pkg/DEBIAN/postinst"
chmod 755 "$root/bin/example-tool"
```

Build y verificación:

```sh
./build.sh
dpkg-deb -c docs/example-tool_0.1.0_all.deb
dpkg-deb -I docs/example-tool_0.1.0_all.deb
```

Instalación local:

```sh
pkg install --reinstall ./docs/example-tool_0.1.0_all.deb
hash -r
command -v example-tool
example-tool
```

Publicación:

```sh
git add packages/example-tool docs README.md
git commit -m "Add example-tool"
git push
```

## 18. Generador de paquetes

El repo debería tener un generador, por ejemplo:

```text
scripts/new-package.sh
```

Ese generador debe crear paquetes conformes a esta guía.

Requisitos del generador:

- Pedir o aceptar como argumentos:
  - nombre del paquete
  - descripción corta EN
  - descripción corta ES
  - versión inicial
  - dependencias
  - tipo de payload: `bin`, `lib`, `opt-boot`, `shizuku-wrapper`, etc.
- Crear estructura:

```text
packages/<name>/DEBIAN/control
packages/<name>/DEBIAN/postinst
packages/<name>/README.md
packages/<name>/data/data/com.termux/files/usr/...
```

- Usar shebang correcto.
- Usar español neutro en textos EN/ES.
- Usar comentarios en inglés.
- Declarar dependencias reales.
- No crear archivos que terminen en `/README.md` del sistema.
- No instalar nada en `$HOME` como mecanismo principal.
- Crear `postinst` idempotente.
- Crear `prerm` solo si el paquete copia cosas a `$HOME` o instala boot scripts.
- Recordar actualización del README principal.
- Recordar build y verificación.

Flujo esperado:

```sh
./scripts/new-package.sh
./build.sh
pkg install --reinstall ./docs/<name>_<version>_all.deb
```

## 19. Diagnóstico rápido en dispositivos

Estado general:

```sh
echo "PREFIX=$PREFIX"
echo "HOME=$HOME"
echo "PATH=$PATH"
echo "LD_PRELOAD=[$LD_PRELOAD]"
command -v pkg apt dpkg bash sh
```

Paquete instalado:

```sh
dpkg -L <paquete>
dpkg -s <paquete>
```

Sombra en PATH:

```sh
type -a <comando>
hash -r
```

Estado dpkg:

```sh
dpkg --audit
```

Si quedó a medio instalar:

```sh
dpkg --remove --force-remove-reinstreq <paquete> || true
apt clean
pkg update
```

Contenido de un deb:

```sh
dpkg-deb -c docs/<paquete>_<version>_all.deb
dpkg-deb -I docs/<paquete>_<version>_all.deb
```

Verificar loader DEX:

```sh
head -c 8 "$PREFIX/lib/rish/rish_shizuku.dex" | od -An -tx1 -c
```

Verificar symlink:

```sh
ls -l "$PREFIX/lib/rish"
readlink "$PREFIX/lib/rish/rish_shizuku.so"
```

Prueba de binario del sistema con entorno limpio:

```sh
LD_PRELOAD= /system/bin/sh -c 'echo shell-ok'
```

Si eso falla pero dentro de un wrapper de Termux funciona, el problema es exactamente heredar `LD_PRELOAD` hacia un intérprete del sistema.

## 20. Criterio general para IA

Si una solución huele a Linux desktop, frenar.

Preguntarse:

- ¿Existe esta ruta en Termux?
- ¿Este comando es de Termux o de Android?
- ¿Este shebang existe en Android?
- ¿Este binario puede ser de otra bitness que Termux?
- ¿Esto requiere root?
- ¿Esto requiere systemd?
- ¿Esto escribe en `/`?
- ¿Esto depende de un comando externo frágil?
- ¿Esto va a `$HOME` sin necesidad real?
- ¿Esto se va a entender en otro dispositivo sin contexto privado?
- ¿Esto declara dependencias reales?
- ¿Esto usa español neutro y comentarios en inglés?

Si alguna respuesta es problemática, no implementar directo: ajustar el diseño o preguntar.