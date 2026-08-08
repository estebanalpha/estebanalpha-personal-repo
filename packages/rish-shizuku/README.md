# rish-shizuku

[English](#english) · [Español](#español)

## English

Termux wrapper for Shizuku's `rish` shell.

Installed files:

- `$PREFIX/bin/rish`
- `$PREFIX/lib/rish/rish_shizuku.dex`
- `$PREFIX/lib/rish/rish_shizuku.so` — compatibility symlink

Usage:

```sh
rish
rish id
rish -c 'command'
```

Notes:

- The wrapper clears `LD_PRELOAD` before starting `app_process`.
- On Android 14+, the loader must be read-only; the wrapper enforces this when possible.
- The loader file is provided by the Shizuku app and may need updating if Shizuku changes.

## Español

Wrapper de Termux para la shell `rish` de Shizuku.

Archivos instalados:

- `$PREFIX/bin/rish`
- `$PREFIX/lib/rish/rish_shizuku.dex`
- `$PREFIX/lib/rish/rish_shizuku.so` — symlink de compatibilidad

Uso:

```sh
rish
rish id
rish -c 'comando'
```

Notas:

- El wrapper limpia `LD_PRELOAD` antes de iniciar `app_process`.
- En Android 14+, el loader debe ser de solo lectura; el wrapper lo aplica cuando es posible.
- El archivo loader proviene de la app Shizuku y puede necesitar actualización si Shizuku cambia.