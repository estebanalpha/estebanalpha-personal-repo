# CONTRIBUTING

*[English](#english) · [Español](#español)*

This document exists so that any AI assistant (or human) picking up work
on this repository — in a fresh session, with no memory of prior
conversations — can add or modify a package without breaking established
conventions, reintroducing already-fixed bugs, or producing output that
looks inconsistent with the rest of the repo. Read this fully before
creating or editing a package.

---

## English

### 1. What this repo is

A personal, unofficial APT repository for Termux, hosted at:
```
https://github.com/estebanalpha/estebanalpha-personal-repo
```
GitHub Pages serves `docs/` as a flat, unsigned repo (`[trusted=yes]`).
Not the official Termux repos, not TUR. Packages are built with raw
`dpkg-deb` — **not** the official termux-packages build system (no
`TERMUX_PKG_*` variables, no cross-compiling container). Don't reach for
that system here.

A device adds this repo with:
```sh
curl -sL https://estebanalpha.github.io/estebanalpha-personal-repo/add-repo.sh | bash
```

### 2. The Termux/Android environment — what does and doesn't exist

- Prefix: `/data/data/com.termux/files/usr`. Home:
  `/data/data/com.termux/files/home`.
- No root, no `sudo`, no `systemd`, no system cron, no `/bin/bash`, no
  `/usr/bin/env` outside the Termux sandbox. `/` and `/system` are not
  writable by dpkg.
- Termux binaries live under `$PREFIX/bin`; Android system binaries live
  under `/system/bin`, and may be a **different bitness** than Termux's
  own binaries on the same device.
- Termux commonly exports
  `LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so`. This can break
  a `/system/bin/*` binary launched with that variable still set if
  there's a bitness mismatch — see §12 if your package launches system
  binaries.

If a solution smells like desktop Linux, stop and reconsider: does this
path/command/shebang actually exist in Termux, or are you assuming a
normal distro?

### 3. Where files go: `$PREFIX` vs `$HOME`

Default: **a package installs under `$PREFIX`**, like any normal Debian
package. dpkg tracks these files natively — `pkg upgrade`/`uninstall`
just work, no postinst needed for placement.
```
$PREFIX/bin/<command>                    755, the command itself
$PREFIX/lib/<package>/                   private libs/loaders/resources
$PREFIX/share/doc/<package>/             on-device docs (see §9)
$PREFIX/share/man/man1/<command>.1.gz    man page, if any
$PREFIX/share/examples/<package>/        example files, if any
$PREFIX/share/bash-completion/completions/<command>
$PREFIX/etc/                             global config (mark as Conffiles
                                          if the user may edit it)
```

`$HOME` is **not** the default target for package-managed binaries.
`~/.local/bin` and `~/.local/lib` are the user's own manual-script
space — never install a packaged command there. Reasonable `$HOME`
exceptions, when a package genuinely needs them:
```
~/.config/<package>/       user config, XDG-style
~/.cache/<package>/        cache
~/.local/state/<package>/  state
~/.termux/boot/            Termux:Boot launchers (see §3.1)
```

#### 3.1 The `$PREFIX/opt` + postinst pattern (only when `$HOME` is required)

Use this **only** when there's a hard structural reason a file must live
under `$HOME` — e.g. Termux:Boot requires scripts literally at
`~/.termux/boot/`, and dpkg has no concept of "the invoking user's home
directory" to install there directly.
- Stage the real files under
  `packages/<name>/data/data/com.termux/files/usr/opt/<name>/...`
  (a normal, dpkg-tracked location — the source of truth).
- `DEBIAN/postinst` copies from `/opt/<name>` into the correct `$HOME`
  location, `chmod +x`, `mkdir -p` as needed.
- `DEBIAN/prerm` removes what postinst created — dpkg won't clean up
  anything outside its own payload.
- Don't overwrite user configuration without care (idempotent, marked
  blocks — see the `local-setup` package's `.bashrc` block for the
  pattern).

Don't use this pattern by default. A general-purpose CLI tool goes
straight into `.../usr/bin/<name>` — no postinst at all.

### 4. Shebang

Always the absolute Termux path, no exceptions, for anything directly
executed (maintainer scripts, Termux:Boot launchers, any installed
command):
```sh
#!/data/data/com.termux/files/usr/bin/bash
```
Never `#!/bin/bash` or `#!/usr/bin/env bash` — neither path exists
outside the Termux app sandbox; a relative shebang fails at the kernel
level, before bash ever runs. For an installed Python command, same
idea: `#!/data/data/com.termux/files/usr/bin/python`.

### 5. Language and tone

**Always English + Spanish** (English block, then a `---` separator,
then Spanish — see this file, or any package's `README.md`, for the
exact pattern):
- Every `README.md` — top-level and per-package.
- `postinst`/`prerm` messages printed during install.
- Any message an **installed command itself** prints to the user at
  runtime (usage errors, "not found" messages, etc.) — this is content
  the end user sees, same as a postinst message. It doesn't become
  "code" just because it lives inside the installed script rather than
  a maintainer script.

**English only:**
- Source code comments, including maintainer-script comments.
- Commit messages.
- `build.sh` / `scripts/` — maintainer-only tooling, not user-facing.

**Spanish, when used, is neutral** — no regional slang, no phrasing
tied to one country's usage.

**Never**, in any comment or message:
- Reference a specific device, a debugging session, or "what was
  confirmed" in some conversation.
- Frame something as a changelog relative to a prior version ("v1 did
  X, this does Y instead").
- Leave in reasoning that only makes sense with conversational context.

Bad, actually seen in earlier drafts of this repo — don't reintroduce
this style:
```
# fixed after testing on the Huawei
# previous attempt used a different approach here
# como tenías en tu bashrc anterior
```
Good — describes current behavior and the durable reason for it,
nothing else:
```
# Use the Termux shebang because system sh may fail to start when
# LD_PRELOAD points at a Termux library of a different bitness.
```
If you're fixing something, the **commit message** is where "what
changed and why" belongs — never a comment block in the file itself.
Generic, timeless troubleshooting notes are fine in a message, e.g.:
```
If `command -v <name>` doesn't point to $PREFIX/bin/<name>, another
copy earlier in PATH is taking precedence.
```

### 6. Versioning

- **Original code** (yours or a prior AI session's) — `adb-connect`,
  `shizuku-watchdog`, `local-setup`. Simple `X.Y` (or `X.Y.Z`). Bump on
  any content change, however small — `docs/` is rebuilt from source,
  and an unbumped version won't show as an available upgrade. Never
  reuse a version number for different content.
- **A package that repackages an existing upstream artifact** —
  `rish-shizuku` and similar. Debian's
  `<upstream-version>-<packaging-revision>`, e.g. `13.5.4-1`. Bump the
  revision when only your own postinst/wrapper logic changes; bump the
  upstream part when you re-export from a newer upstream release. If
  the upstream version genuinely can't be determined, fall back to
  `X.Y.Z` and document the artifact's origin in the package's
  `README.md`.

### 7. `DEBIAN/control` template

```
Package: <name>
Version: <see §6>
Architecture: all
Maintainer: estebanalpha
Depends: <real dependencies — see §8>
Section: utils
Priority: optional
Description: <one-line English summary>
 <one paragraph, one leading space per continuation line, no markdown>
```
`Architecture: all` only if there are no native (ELF) binaries specific
to a CPU architecture in the payload.

### 8. Dependencies

Declare real dependencies even when Termux usually already has the
tool — a minimal or customized install may not. Examples:
`Depends: bash` for anything with that shebang; add `coreutils`,
`grep`, `sed`, `findutils`, `curl`, etc. for whatever the scripts
actually call. Follow the same logic for any command you invoke.
`android-tools` for `adb`, `termux-api` for `termux-notification`/etc.

System binaries under `/system/bin/*` (getprop, app_process, pm, am)
are never a Debian dependency — they're part of Android, always
present, but call them by absolute path and treat §12 as relevant.

External Android apps (Termux:API, Termux:Boot, Shizuku) are never a
`Depends` field either — document the requirement in `postinst` output
and the package's `README.md` instead.

### 9. On-device documentation (`$PREFIX/share/doc`)

If a package's documentation is worth having on-device (not just on
GitHub), place it at
`packages/<name>/data/data/com.termux/files/usr/share/doc/<name>/README.md`
— same bilingual content as `packages/<name>/README.md`. It's under
`$PREFIX`, so dpkg tracks and removes it natively; no postinst needed
for this specifically. Optional — skip it if the package is trivial
enough that it adds no value.

### 10. Maintainer scripts (`postinst`/`prerm`/etc.)

- Shebang per §4; start with `set -e`.
- Non-interactive. Idempotent — must be safe to run twice.
- Print a bilingual final message (see §5's format).
- `prerm` removes only what the package itself created — never user
  data.
- Don't download required files during install unless that's a
  deliberate, documented design choice.

### 11. `build.sh` — required behavior, don't regress these

**Payload staging is mandatory.** `dpkg-deb --build` treats everything
directly under the directory it's given as payload, *except* the
`DEBIAN/` subdirectory. If `packages/<name>/README.md` (or anything
else) sits as a sibling of `DEBIAN/` and `data/`, it gets packaged as
if it should install to `/README.md` — the real filesystem root, not
writable without root. This produces exactly this failure at install
time on a device:
```
unable to create '/README.md.dpkg-new': Read-only file system
```
`build.sh` must copy only `DEBIAN/` and `data/` into a temporary
staging directory (e.g. `.build/<name>/`) before calling `dpkg-deb`,
never build `packages/<name>/` directly.

Other requirements already in place — verify they're still there if
you touch `build.sh`, don't reintroduce these:
- **No `dpkg-scanpackages`.** It's part of `dpkg-dev`, which doesn't
  exist in Termux. The `Packages` index is generated by hand with
  `dpkg-deb -f <deb>` plus `md5sum`/`sha1sum`/`sha256sum`/`wc -c`. If
  you ever rewrite this generation logic, don't reach for
  `dpkg-scanpackages` — it works on a full Linux box and then fails
  silently-into-corruption the first time it runs on Termux (the `>`
  redirect truncates the output file before the missing-command error
  surfaces).
- **Force `chmod 755` on each package's `DEBIAN/` directory** before
  building. Permissions can drift to `700` after a `tar`/`cp`
  round-trip (observed after extracting a tarball on Termux); `dpkg-deb`
  refuses to build otherwise.
- **`SOURCE_DATE_EPOCH` is derived per package**, from the latest
  commit that touched `packages/<name>/` specifically — not from the
  repo's overall HEAD. `dpkg-deb` embeds a build timestamp via gzip; if
  the epoch came from the repo-wide HEAD instead, every unrelated
  commit would change *every* package's `.deb` bytes even when its
  source didn't change, since HEAD moves with every commit regardless
  of which package it touched. Falls back to the repo-wide HEAD
  timestamp only for a package with no commit history yet (just
  added, not committed).
- Old `.deb` files for a package are deleted before rebuilding it, so a
  version bump doesn't leave a stale file in `docs/` next to the new
  one.

Always run `./build.sh` after any change under `packages/`, then read
`git status` before committing — confirm only the files you expect
changed. If something you didn't touch shows as modified, find out why
before proceeding.

### 12. Appendix: wrapping a Shizuku/rish-style tool, or anything that launches `/system/bin/*`

Only relevant if your package execs a system binary (`app_process`,
`getprop`, `pm`, `am`, ...). Most packages never need this section.

Clean the environment before launching the system binary, from inside
a Termux-shebang script:
```bash
#!/data/data/com.termux/files/usr/bin/bash
: "${PREFIX:=/data/data/com.termux/files/usr}"
unset LD_PRELOAD 2>/dev/null || true
exec /system/bin/app_process ...
```
Starting directly with a system shebang (`#!/system/bin/sh`) instead of
a Termux one, while `LD_PRELOAD` still points at a Termux library, is
what produces:
```
CANNOT LINK EXECUTABLE "/system/bin/sh": ... is 32-bit instead of 64-bit
```
For Shizuku/rish wrappers specifically: default `RISH_APPLICATION_ID`
to `com.termux`; the loader typically lives at
`$PREFIX/lib/rish/rish_shizuku.dex`. DEX files start with `dex` (check
with `head -c 8 <file> | od -An -tx1 -c`); if something expects a
`.so`, a compatibility symlink (`.so -> .dex`) is fine — don't rename
the real file. On Android 14+, the loader should not be
group/world-writable (`chmod 400` or similar).

Prefer bash builtins over shelling out to external commands
(`printf`, `dirname`, `basename`) for logic that decides which file to
load — a fragile external-command dependency in that specific path has
caused confusing failures here before (`can't read file ".../usr/lib":
Is a directory`-style errors). A plain loop over candidate paths with
`[[ -f ... ]]` is more robust than piping through an external command.

### 13. Before starting a new package — answer these first

Name; short EN+ES description; what files it installs and where
(§3/§9); real dependencies (§8); does it need `$HOME`/boot (§3.1); does
it need Shizuku/adb/Termux:API/Termux:Boot (document, don't add to
`Depends`); does it launch system binaries (§12); is there a clear
upstream version (§6).

### 14. Before committing — run this

```sh
bash -n packages/<name>/DEBIAN/postinst
bash -n packages/<name>/DEBIAN/prerm 2>/dev/null || true
bash -n packages/<name>/data/data/com.termux/files/usr/bin/<command>
head -n1 packages/<name>/DEBIAN/postinst
head -n1 packages/<name>/data/data/com.termux/files/usr/bin/<command>

./build.sh

dpkg-deb -c docs/<name>_*_all.deb
# every line must start with ./data/data/com.termux/files/usr/... —
# if you see ./README.md, ./build.sh, or ./DEBIAN, the staging step in
# build.sh regressed (see §11).
dpkg-deb -c docs/<name>_*_all.deb | grep -E ' \./README\.md$| \./build\.sh$| \./DEBIAN' && echo "LEAK" || echo OK

dpkg-deb -I docs/<name>_*_all.deb
```
If you have a real device to test on:
```sh
pkg install --reinstall ./docs/<name>_<version>_all.deb
hash -r
command -v <command>
type -a <command>   # if something else shadows it earlier in PATH
```

### 15. After pushing — verify the live repo

```sh
curl -fsSL https://estebanalpha.github.io/estebanalpha-personal-repo/Packages.gz \
  | gunzip | awk '/^Package: <name>$/,/^$/'
```
404s on `InRelease`/`Release` from apt are normal for an unsigned flat
repo — what matters is that `Packages(.gz)` and the `.deb` itself
download correctly.

### 16. `scripts/new-package.sh`

Scaffolds a new package (`control`, `postinst`, `README.md`, and the
installed command file, with `@name@`/`@cmd@`/`@version@` placeholders
filled in). Use it as the starting point for anything that fits the
plain `$PREFIX/bin` pattern (§3); for the `$HOME`/boot pattern (§3.1)
you'll still need to add `data/.../opt/<name>/`, `postinst`, and
`prerm` by hand — the generator doesn't cover that case yet.

### 17. Git hygiene

One logical change per commit — don't bundle an unrelated `build.sh`
fix into a package-content commit, or vice versa. Commit messages in
English, short and descriptive.

---

## Español

### 1. Qué es este repo

Un repositorio APT personal y no oficial para Termux, alojado en:
```
https://github.com/estebanalpha/estebanalpha-personal-repo
```
GitHub Pages sirve `docs/` como repo plano y sin firmar
(`[trusted=yes]`). No son los repos oficiales de Termux, ni el TUR. Los
paquetes se construyen con `dpkg-deb` directo — **no** con el sistema
de build oficial de termux-packages (sin variables `TERMUX_PKG_*`, sin
contenedor de cross-compilación). No recurras a ese sistema acá.

Un dispositivo agrega este repo con:
```sh
curl -sL https://estebanalpha.github.io/estebanalpha-personal-repo/add-repo.sh | bash
```

### 2. El entorno de Termux/Android — qué existe y qué no

- Prefix: `/data/data/com.termux/files/usr`. Home:
  `/data/data/com.termux/files/home`.
- Sin root, sin `sudo`, sin `systemd`, sin cron de sistema, sin
  `/bin/bash`, sin `/usr/bin/env` fuera del sandbox de Termux. `/` y
  `/system` no son escribibles por dpkg.
- Los binarios de Termux viven bajo `$PREFIX/bin`; los binarios del
  sistema Android viven bajo `/system/bin`, y pueden ser de **distinta
  bitness** que los de Termux en el mismo dispositivo.
- Termux suele exportar
  `LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so`. Esto puede
  romper un binario de `/system/bin/*` lanzado con esa variable
  todavía activa si hay mismatch de bitness — ver §12 si tu paquete
  lanza binarios del sistema.

Si una solución huele a Linux de escritorio, parate a reconsiderar:
¿esa ruta/comando/shebang existe de verdad en Termux, o estás
asumiendo una distro normal?

### 3. Dónde van los archivos: `$PREFIX` vs `$HOME`

Por defecto: **un paquete se instala bajo `$PREFIX`**, como cualquier
paquete Debian normal. dpkg rastrea estos archivos de forma nativa —
`pkg upgrade`/`uninstall` funcionan solos, sin postinst para la
ubicación.
```
$PREFIX/bin/<comando>                    755, el comando en sí
$PREFIX/lib/<paquete>/                   libs/loaders/recursos privados
$PREFIX/share/doc/<paquete>/             documentación en el equipo (§9)
$PREFIX/share/man/man1/<comando>.1.gz    man page, si aplica
$PREFIX/share/examples/<paquete>/        archivos de ejemplo, si aplica
$PREFIX/share/bash-completion/completions/<comando>
$PREFIX/etc/                             config global (marcar como
                                          Conffiles si el usuario la edita)
```

`$HOME` **no** es el destino por defecto para binarios administrados
por el paquete. `~/.local/bin` y `~/.local/lib` son el espacio de
scripts manuales del usuario — nunca instales ahí un comando
empaquetado. Excepciones razonables en `$HOME`, cuando un paquete
genuinamente las necesita:
```
~/.config/<paquete>/       config del usuario, estilo XDG
~/.cache/<paquete>/        cache
~/.local/state/<paquete>/  estado
~/.termux/boot/            launchers de Termux:Boot (ver §3.1)
```

#### 3.1 El patrón `$PREFIX/opt` + postinst (solo cuando `$HOME` es obligatorio)

Usá esto **solo** cuando hay una razón estructural real por la que un
archivo tiene que vivir bajo `$HOME` — ej. Termux:Boot exige que los
scripts estén literalmente en `~/.termux/boot/`, y dpkg no tiene
noción de "el home del usuario que invoca" para instalar ahí directo.
- Poné los archivos reales bajo
  `packages/<nombre>/data/data/com.termux/files/usr/opt/<nombre>/...`
  (una ubicación normal, rastreada por dpkg — la fuente de verdad).
- `DEBIAN/postinst` copia desde `/opt/<nombre>` hacia la ubicación
  correcta en `$HOME`, con `chmod +x`, `mkdir -p` según haga falta.
- `DEBIAN/prerm` borra lo que el postinst creó — dpkg no limpia nada
  fuera de su propio payload.
- No sobreescribas configuración del usuario sin cuidado (bloques
  idempotentes y marcados — ver el patrón del `.bashrc` en el paquete
  `local-setup`).

No uses este patrón por defecto. Una herramienta de propósito general
va directo a `.../usr/bin/<nombre>` — sin postinst para nada.

### 4. Shebang

Siempre la ruta absoluta de Termux, sin excepciones, para todo lo que
se ejecute directo (maintainer scripts, launchers de Termux:Boot,
cualquier comando instalado):
```sh
#!/data/data/com.termux/files/usr/bin/bash
```
Nunca `#!/bin/bash` ni `#!/usr/bin/env bash` — ninguna de esas rutas
existe fuera del sandbox de la app de Termux; un shebang relativo
falla a nivel del kernel, antes de que bash llegue a correr. Para un
comando Python instalado, misma idea:
`#!/data/data/com.termux/files/usr/bin/python`.

### 5. Idioma y tono

**Siempre inglés + español** (bloque en inglés, después un separador
`---`, después español — ver este mismo archivo, o el `README.md` de
cualquier paquete, para el patrón exacto):
- Todo `README.md` — el principal y el de cada paquete.
- Mensajes de `postinst`/`prerm` impresos durante la instalación.
- Cualquier mensaje que el **comando instalado mismo** le imprima al
  usuario en tiempo de ejecución (errores de uso, "no encontrado",
  etc.) — es contenido que ve el usuario final, igual que un mensaje
  de postinst. No se convierte en "código" solo por vivir dentro del
  script instalado en vez de un maintainer script.

**Solo inglés:**
- Comentarios de código, incluidos los de maintainer scripts.
- Mensajes de commit.
- `build.sh` / `scripts/` — herramientas solo para el mantenedor, no
  las ve un usuario.

**El español, cuando se usa, es neutro** — sin modismos regionales, sin
frases atadas al uso de un solo país.

**Nunca**, en ningún comentario o mensaje:
- Referenciar un dispositivo específico, una sesión de depuración, o
  "lo que se confirmó" en alguna conversación.
- Enmarcar algo como un changelog relativo a una versión anterior ("la
  v1 hacía X, esto hace Y en cambio").
- Dejar razonamiento que solo tiene sentido con contexto conversacional.

Mal — llegó a aparecer en borradores anteriores de este repo, no lo
reintroduzcas:
```
# arreglado tras probar en el Huawei
# el intento anterior usaba otro enfoque acá
# como tenías en tu bashrc anterior
```
Bien — describe el comportamiento actual y la razón técnica duradera,
nada más:
```
# Usa el shebang de Termux porque el sh del sistema puede fallar al
# arrancar cuando LD_PRELOAD apunta a una librería de Termux de otra
# bitness.
```
Si estás arreglando algo, el **mensaje de commit** es el lugar para el
"qué cambió y por qué" — nunca un bloque de comentario en el archivo
mismo. Una nota de troubleshooting genérica y atemporal sí está bien
en un mensaje, ej.:
```
Si `command -v <nombre>` no apunta a $PREFIX/bin/<nombre>, otra copia
antes en el PATH tiene prioridad.
```

#### 5.1 Selección de idioma para mensajes de runtime de comandos instalados

A diferencia de `postinst` (corre una sola vez al instalar — mostrar
los dos idiomas apilados ahí está bien), los mensajes propios de un
comando instalado corren cada vez que se invoca. Imprimir los dos
idiomas en cada corrida es ruidoso para algo que se usa repetidamente.
Elegí un solo idioma en cambio:

1. Si existe `$PREFIX/etc/estebanalpha-repo/lang.conf`, usalo — una
   sola línea, `es` o `en`, deja que el usuario fuerce una elección sin
   importar el locale.
2. Si no, detectá desde `LC_ALL`, después `LC_MESSAGES`, después
   `LANG` (orden de precedencia POSIX), buscando que empiece con
   `es`; por defecto inglés en cualquier otro caso (incluido cuando
   ninguna de estas variables está seteada, algo común en Termux).

```bash
LANG_CONF="$PREFIX/etc/estebanalpha-repo/lang.conf"
if [ -f "$LANG_CONF" ]; then
    _LANG="$(cat "$LANG_CONF")"
else
    case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
        es*) _LANG=es ;;
        *)   _LANG=en ;;
    esac
fi
```
Reusá este mismo bloque, sin modificar, en cualquier comando instalado
que imprima mensajes de runtime — no inventes un orden de detección
distinto por paquete. El archivo de config es a propósito para todo el
repo (una sola preferencia cubre los comandos de todos los paquetes),
no por paquete. Ningún paquete necesita crear
`$PREFIX/etc/estebanalpha-repo/` de forma proactiva — un usuario que
quiera forzar un idioma lo crea él mismo:
```sh
mkdir -p $PREFIX/etc/estebanalpha-repo
echo es > $PREFIX/etc/estebanalpha-repo/lang.conf   # o "en"
```

### 6. Versionado

- **Código propio** (tuyo o de una sesión de IA anterior) —
  `adb-connect`, `shizuku-watchdog`, `local-setup`. `X.Y` simple (o
  `X.Y.Z`). Subilo con cualquier cambio de contenido, por chico que
  sea — `docs/` se reconstruye desde la fuente, y una versión no
  subida no va a aparecer como actualización disponible. Nunca
  reutilices un número de versión para contenido distinto.
- **Un paquete que reempaqueta un artefacto de otro proyecto** —
  `rish-shizuku` y similares. Formato de Debian
  `<version-upstream>-<revisión-de-empaquetado>`, ej. `13.5.4-1`. Subí
  la revisión cuando cambia solo tu propia lógica de postinst/wrapper;
  subí la parte de upstream cuando volvés a exportar desde una versión
  más nueva. Si de verdad no se puede determinar la versión upstream,
  caé a `X.Y.Z` y documentá el origen del artefacto en el `README.md`
  del paquete.

### 7. Plantilla de `DEBIAN/control`

```
Package: <nombre>
Version: <ver §6>
Architecture: all
Maintainer: estebanalpha
Depends: <dependencias reales — ver §8>
Section: utils
Priority: optional
Description: <resumen de una línea, en inglés>
 <un párrafo, una sola indentación de espacio por línea de
 continuación, sin markdown>
```
`Architecture: all` solo si no hay binarios nativos (ELF) específicos
de una arquitectura de CPU en el payload.

### 8. Dependencias

Declará dependencias reales aunque Termux normalmente ya tenga la
herramienta — una instalación mínima o personalizada puede no
tenerla. Ejemplos: `Depends: bash` para cualquier cosa con ese
shebang; sumá `coreutils`, `grep`, `sed`, `findutils`, `curl`, etc.
según lo que los scripts realmente llamen. Misma lógica para cualquier
comando que invoques. `android-tools` para `adb`, `termux-api` para
`termux-notification`/etc.

Los binarios del sistema bajo `/system/bin/*` (getprop, app_process,
pm, am) nunca son una dependencia de Debian — son parte de Android,
siempre presentes, pero llamalos por ruta absoluta y considerá
relevante el §12.

Las apps externas de Android (Termux:API, Termux:Boot, Shizuku)
tampoco van en `Depends` — documentá el requisito en el mensaje del
`postinst` y en el `README.md` del paquete.

### 9. Documentación en el dispositivo (`$PREFIX/share/doc`)

Si la documentación de un paquete vale la pena tenerla en el
dispositivo (no solo en GitHub), ponela en
`packages/<nombre>/data/data/com.termux/files/usr/share/doc/<nombre>/README.md`
— mismo contenido bilingüe que `packages/<nombre>/README.md`. Está
bajo `$PREFIX`, así que dpkg la rastrea y la remueve nativamente; no
hace falta postinst para esto específicamente. Opcional — salteala si
el paquete es lo bastante trivial como para que no aporte nada.

### 10. Maintainer scripts (`postinst`/`prerm`/etc.)

- Shebang según §4; empezar con `set -e`.
- No interactivos. Idempotentes — deben poder correr dos veces sin
  romper.
- Imprimir un mensaje final bilingüe (formato de §5).
- `prerm` remueve solo lo que el propio paquete creó — nunca datos del
  usuario.
- No descargar archivos obligatorios durante la instalación salvo que
  sea una decisión de diseño deliberada y documentada.

### 11. `build.sh` — comportamiento obligatorio, no lo regresiones

**El staging del payload es obligatorio.** `dpkg-deb --build` trata
todo lo que esté directamente bajo el directorio que se le pasa como
payload, *excepto* la subcarpeta `DEBIAN/`. Si
`packages/<nombre>/README.md` (o cualquier otra cosa) queda como
hermano de `DEBIAN/` y `data/`, se empaqueta como si debiera
instalarse en `/README.md` — la raíz real del sistema de archivos, no
escribible sin root. Esto produce exactamente esta falla al instalar
en un dispositivo:
```
unable to create '/README.md.dpkg-new': Read-only file system
```
`build.sh` tiene que copiar solamente `DEBIAN/` y `data/` a un
directorio de staging temporal (ej. `.build/<nombre>/`) antes de
llamar a `dpkg-deb` — nunca construir `packages/<nombre>/` directo.

Otros requisitos ya vigentes — verificá que sigan ahí si tocás
`build.sh`, no los reintroduzcas:
- **Sin `dpkg-scanpackages`.** Es parte de `dpkg-dev`, que no existe
  en Termux. El índice `Packages` se genera a mano con
  `dpkg-deb -f <deb>` más `md5sum`/`sha1sum`/`sha256sum`/`wc -c`. Si en
  algún momento reescribís esta parte, no recurras a
  `dpkg-scanpackages` — funciona en una PC con Linux completo y
  después falla de forma silenciosa-hasta-corromper la primera vez que
  corre en Termux (el redirect `>` trunca el archivo de salida antes
  de que aparezca el error de comando faltante).
- **Forzar `chmod 755` en la carpeta `DEBIAN/` de cada paquete** antes
  de construir. Los permisos pueden terminar en `700` tras un viaje de
  ida y vuelta por `tar`/`cp` (se observó al extraer un tarball en
  Termux); `dpkg-deb` se niega a construir si no.
- **`SOURCE_DATE_EPOCH` se deriva por paquete**, del último commit que
  tocó `packages/<nombre>/` puntualmente — no del HEAD general del
  repo. `dpkg-deb` incrusta un timestamp de build vía gzip; si el
  epoch saliera del HEAD de todo el repo, cualquier commit no
  relacionado cambiaría los bytes del `.deb` de *todos* los paquetes
  aunque su fuente no haya cambiado, porque el HEAD se mueve con cada
  commit sin importar qué paquete tocó. Cae al timestamp del HEAD
  general del repo solo para un paquete sin historial de git todavía
  (recién agregado, sin commitear).
- Los `.deb` viejos de un paquete se borran antes de reconstruirlo,
  para que un bump de versión no deje un archivo viejo en `docs/`
  junto al nuevo.

Corré siempre `./build.sh` después de cualquier cambio bajo
`packages/`, y leé el `git status` antes de commitear — confirmá que
solo cambió lo que esperabas. Si algo que no tocaste aparece
modificado, averiguá por qué antes de seguir.

### 12. Apéndice: envolver una herramienta estilo Shizuku/rish, o cualquier cosa que lance `/system/bin/*`

Solo relevante si tu paquete ejecuta un binario del sistema
(`app_process`, `getprop`, `pm`, `am`, ...). La mayoría de los
paquetes nunca necesitan esta sección.

Limpiá el entorno antes de lanzar el binario del sistema, desde
adentro de un script con shebang de Termux:
```bash
#!/data/data/com.termux/files/usr/bin/bash
: "${PREFIX:=/data/data/com.termux/files/usr}"
unset LD_PRELOAD 2>/dev/null || true
exec /system/bin/app_process ...
```
Arrancar directo con un shebang del sistema (`#!/system/bin/sh`) en
vez de uno de Termux, mientras `LD_PRELOAD` todavía apunta a una
librería de Termux, es lo que produce:
```
CANNOT LINK EXECUTABLE "/system/bin/sh": ... is 32-bit instead of 64-bit
```
Para wrappers de Shizuku/rish en particular: `RISH_APPLICATION_ID` por
defecto es `com.termux`; el loader típicamente vive en
`$PREFIX/lib/rish/rish_shizuku.dex`. Los archivos DEX empiezan con
`dex` (verificar con `head -c 8 <archivo> | od -An -tx1 -c`); si algo
espera un `.so`, un symlink de compatibilidad (`.so -> .dex`) está
bien — no renombres el archivo real. En Android 14+, el loader no
debería tener permiso de escritura de grupo/otros (`chmod 400` o
similar).

Preferí builtins de bash antes que invocar comandos externos
(`printf`, `dirname`, `basename`) para la lógica que decide qué
archivo cargar — una dependencia frágil de un comando externo en ese
punto puntual ya causó fallas confusas acá (errores del estilo
`can't read file ".../usr/lib": Is a directory`). Un loop simple sobre
rutas candidatas con `[[ -f ... ]]` es más robusto que pasar por un
comando externo.

### 13. Antes de empezar un paquete nuevo — contestá esto primero

Nombre; descripción corta EN+ES; qué archivos instala y dónde (§3/§9);
dependencias reales (§8); necesita `$HOME`/boot (§3.1); necesita
Shizuku/adb/Termux:API/Termux:Boot (documentar, no va en `Depends`);
lanza binarios del sistema (§12); hay una versión upstream clara (§6).

### 14. Antes de commitear — corré esto

```sh
bash -n packages/<nombre>/DEBIAN/postinst
bash -n packages/<nombre>/DEBIAN/prerm 2>/dev/null || true
bash -n packages/<nombre>/data/data/com.termux/files/usr/bin/<comando>
head -n1 packages/<nombre>/DEBIAN/postinst
head -n1 packages/<nombre>/data/data/com.termux/files/usr/bin/<comando>

./build.sh

dpkg-deb -c docs/<nombre>_*_all.deb
# cada línea tiene que empezar con ./data/data/com.termux/files/usr/... —
# si ves ./README.md, ./build.sh, o ./DEBIAN, el staging de build.sh
# regresionó (ver §11).
dpkg-deb -c docs/<nombre>_*_all.deb | grep -E ' \./README\.md$| \./build\.sh$| \./DEBIAN' && echo "LEAK" || echo OK

dpkg-deb -I docs/<nombre>_*_all.deb
```
Si tenés un dispositivo real para probar:
```sh
pkg install --reinstall ./docs/<nombre>_<version>_all.deb
hash -r
command -v <comando>
type -a <comando>   # si algo más lo tapa antes en el PATH
```

### 15. Después de pushear — verificá el repo en vivo

```sh
curl -fsSL https://estebanalpha.github.io/estebanalpha-personal-repo/Packages.gz \
  | gunzip | awk '/^Package: <nombre>$/,/^$/'
```
Los 404 de `InRelease`/`Release` de apt son normales en un repo plano
sin firmar — lo que importa es que `Packages(.gz)` y el `.deb` mismo
se descarguen bien.

### 16. `scripts/new-package.sh`

Genera el esqueleto de un paquete nuevo (`control`, `postinst`,
`README.md`, y el archivo del comando instalado, con los placeholders
`@name@`/`@cmd@`/`@version@` ya reemplazados). Usalo como punto de
partida para cualquier cosa que encaje en el patrón simple de
`$PREFIX/bin` (§3); para el patrón de `$HOME`/boot (§3.1) todavía vas
a tener que agregar `data/.../opt/<nombre>/`, `postinst` y `prerm` a
mano — el generador todavía no cubre ese caso.

### 17. Higiene de git

Un cambio lógico por commit — no mezcles un fix de `build.sh` no
relacionado con un commit de contenido de paquete, ni al revés.
Mensajes de commit en inglés, cortos y descriptivos.
