# estebanalpha-personal-repo

*[English](#english) · [Español](#español)*

---

## English

Personal, unofficial APT repository for Termux. Not affiliated with the
official Termux project or the Termux User Repository (TUR). Packages
here are for personal use across multiple devices; use at your own risk
if you install any of them elsewhere.

### Adding this repository

```bash
curl -sL https://estebanalpha.github.io/estebanalpha-personal-repo/add-repo.sh | bash
```

This registers the source under `$PREFIX/etc/apt/sources.list.d/` and
runs `pkg update`. After that, on that device:

```bash
pkg install shizuku-semi-auto
pkg upgrade   # picks up updates to any package from this repo
```

### Packages

- **shizuku-semi-auto** — semi-automatic Shizuku activation via ADB
  loopback, for Android versions before 11 (no native wireless-debug
  toggle). See [packages/shizuku-semi-auto/README.md](packages/shizuku-semi-auto/README.md).

- rish-shizuku — Termux wrapper for the Shizuku `rish` shell. Installs
`rish` in `$PREFIX/bin` and the Shizuku loader in `$PREFIX/lib/rish`;
the wrapper clears `LD_PRELOAD` before launching `app_process`.

### Adding a new package (maintainer notes)

1. `mkdir -p packages/<name>/DEBIAN`
2. Write `packages/<name>/DEBIAN/control` (copy an existing one as a
   template: Package/Version/Architecture: all/Depends/Description).
3. Place payload files under
   `packages/<name>/data/data/com.termux/files/usr/...`
   (absolute Termux paths, exactly as they should land on install).
   Most commands go under `usr/bin`; support files can go under
   `usr/lib/<name>`, `usr/share/...`, or `usr/opt/<name>` when staging
   for a postinst copy.
4. Install normal commands directly under
   `packages/<name>/data/data/com.termux/files/usr/bin`. Use the
   `/opt/<name>` + `DEBIAN/postinst` pattern only when files must live
   in `$HOME`, such as Termux:Boot scripts or user-editable state.
5. Add `DEBIAN/prerm` to clean up on removal if needed.
6. Run `./build.sh` — rebuilds every package under `packages/` and
   regenerates `docs/Packages` + `docs/Packages.gz`.
7. Run `git add -A && git commit -m "..." && git push`.
8. On any device that already added this repo:
   `pkg update && pkg install <name>`.

### On repository signing

This repo is unsigned (`[trusted=yes]`) — simpler to maintain, at the
cost of apt not cryptographically verifying package integrity in
transit (GitHub Pages already serves over HTTPS, which protects against
interception; what's missing is a signature on the package itself, not
transport security). Reasonable tradeoff for personal use. `termux-apt-repo`
supports `--sign` with a GPG key if this is ever worth adding.

---

## Español

Repositorio APT personal y no oficial para Termux. No tiene afiliación
con el proyecto oficial de Termux ni con el Termux User Repository
(TUR). Los paquetes acá son para uso personal en varios dispositivos;
si los instalás en otro lado, es bajo tu propio riesgo.

### Agregar este repositorio

```bash
curl -sL https://estebanalpha.github.io/estebanalpha-personal-repo/add-repo.sh | bash
```

Esto registra la fuente en `$PREFIX/etc/apt/sources.list.d/` y corre
`pkg update`. De ahí en más, en ese dispositivo:

```bash
pkg install shizuku-semi-auto
pkg upgrade   # trae actualizaciones de cualquier paquete de este repo
```

### Paquetes

- **shizuku-semi-auto** — activación semi-automática de Shizuku vía ADB
  loopback, para versiones de Android anteriores a la 11 (sin toggle
  nativo de depuración inalámbrica). Ver [packages/shizuku-semi-auto/README.md](packages/shizuku-semi-auto/README.md).

- rish-shizuku — wrapper de Termux para la shell `rish` de Shizuku.
Instala `rish` en `$PREFIX/bin` y el loader de Shizuku en
`$PREFIX/lib/rish`; el wrapper limpia `LD_PRELOAD` antes de lanzar
`app_process`.

### Agregar un paquete nuevo (notas de mantenimiento)

1. `mkdir -p packages/<nombre>/DEBIAN`
2. Escribir `packages/<nombre>/DEBIAN/control` (copiar uno existente
   como plantilla: Package/Version/Architecture: all/Depends/Description).
3. Coloca los archivos del payload bajo
   `packages/<nombre>/data/data/com.termux/files/usr/...`
   (rutas absolutas de Termux, tal como deben quedar instalados).
   La mayoría de los comandos van en `usr/bin`; los archivos de soporte
   pueden ir en `usr/lib/<nombre>`, `usr/share/...` o `usr/opt/<nombre>`
   cuando se usan como preparación para una copia en postinst.
4. Instala los comandos normales directamente en
   `packages/<nombre>/data/data/com.termux/files/usr/bin`. Usa el patrón
   `/opt/<nombre>` + `DEBIAN/postinst` solo cuando los archivos deban
   vivir en `$HOME`, por ejemplo scripts de Termux:Boot o estado editable
   por el usuario.
5. Agrega `DEBIAN/prerm` para limpiar al desinstalar si hace falta.
6. Ejecuta `./build.sh` — reconstruye todos los paquetes bajo `packages/`
   y regenera `docs/Packages` + `docs/Packages.gz`.
7. Ejecuta `git add -A && git commit -m "..." && git push`.
8. En cualquier dispositivo que ya tenga el repo agregado:
   `pkg update && pkg install <nombre>`.

### Sobre la firma del repositorio

Este repo está sin firmar (`[trusted=yes]`) — más simple de mantener, a
costa de que apt no verifica criptográficamente la integridad del
paquete en tránsito (GitHub Pages ya sirve por HTTPS, lo cual protege
contra intercepción; lo que falta es la firma del paquete en sí, no
seguridad de transporte). Tradeoff razonable para uso personal.
`termux-apt-repo` soporta `--sign` con una clave GPG si en algún
momento vale la pena sumarlo.
