#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

usage() {
    echo "Usage: new-package.sh <package-name> [command-name] [version]" >&2
    exit 1
}

[[ $# -ge 1 ]] || usage

name="$1"
cmd="${2:-$name}"
version="${3:-0.1.0}"

if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Invalid package name: $name" >&2
    exit 1
fi

if [[ ! "$cmd" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Invalid command name: $cmd" >&2
    exit 1
fi

if [[ ! "$version" =~ ^[0-9][0-9A-Za-z.+~-]*$ ]]; then
    echo "Invalid version: $version" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pkg="$REPO_ROOT/packages/$name"
root="$pkg/data/data/com.termux/files/usr"

if [[ -e "$pkg" ]]; then
    echo "Package already exists: $pkg" >&2
    exit 1
fi

mkdir -p "$pkg/DEBIAN" "$root/bin"

cat > "$pkg/DEBIAN/control" <<'TPL'
Package: @name@
Version: @version@
Architecture: all
Maintainer: estebanalpha
Depends: bash
Section: utils
Priority: optional
Description: TODO: short English description
 TODO: longer English description line one.
 TODO: longer English description line two.
TPL

cat > "$pkg/DEBIAN/postinst" <<'TPL'
#!/data/data/com.termux/files/usr/bin/bash
set -e

# Termux prefix, with fallback for environments where PREFIX is unset.
P="${PREFIX:-/data/data/com.termux/files/usr}"

chmod 755 "$P/bin/@cmd@" 2>/dev/null || true

cat <<'MSG'
== @name@ installed / instalado ==
EN - TODO: English post-install message.
ES - TODO: Spanish post-install message.
MSG
TPL

cat > "$pkg/README.md" <<'TPL'
# @name@

[English](#english) · [Español](#español)

## English

TODO: short English description.

Installed files:

- `$PREFIX/bin/@cmd@`

Usage:

    @cmd@

Notes:

- TODO.

## Español

TODO: short Spanish description.

Archivos instalados:

- `$PREFIX/bin/@cmd@`

Uso:

    @cmd@

Notas:

- TODO.
TPL

cat > "$root/bin/$cmd" <<'TPL'
#!/data/data/com.termux/files/usr/bin/bash
set -e

# Termux prefix, with fallback for environments where PREFIX is unset.
: "${PREFIX:=/data/data/com.termux/files/usr}"

echo "@cmd@ ok"
TPL

sed -i "s/@name@/$name/g; s/@version@/$version/g" "$pkg/DEBIAN/control"
sed -i "s/@name@/$name/g; s/@cmd@/$cmd/g" "$pkg/DEBIAN/postinst"
sed -i "s/@name@/$name/g; s/@cmd@/$cmd/g" "$pkg/README.md"
sed -i "s/@cmd@/$cmd/g" "$root/bin/$cmd"

chmod 755 "$pkg/DEBIAN/postinst"
chmod 755 "$root/bin/$cmd"

cat <<DONE
Created package skeleton:

  $pkg

Next steps:

1. Edit DEBIAN/control.
2. Edit DEBIAN/postinst.
3. Edit README.md.
4. Replace the placeholder command in data/.../usr/bin/$cmd.
5. Update the main README package list in EN and ES.
6. Run ./build.sh and test the .deb locally.
DONE
