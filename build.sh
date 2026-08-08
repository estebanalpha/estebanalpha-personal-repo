#!/usr/bin/env bash
# Reconstruye todos los paquetes bajo packages/ y regenera el indice del
# repo en docs/ (la carpeta que sirve GitHub Pages).
#
# Requiere: dpkg-deb, md5sum/sha1sum/sha256sum, gzip (todo esto SI esta
# en el paquete 'dpkg' base de Termux). NO usa dpkg-scanpackages/dpkg-dev
# a proposito -- ese paquete no existe en Termux, solo en Debian/Ubuntu.
#
# Uso: ./build.sh
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_SRC_DIR="$REPO_DIR/packages"
OUT_DIR="$REPO_DIR/docs"
BUILD_DIR="$REPO_DIR/.build"

mkdir -p "$OUT_DIR" "$BUILD_DIR"

export SOURCE_DATE_EPOCH="$(git -C "$REPO_DIR" log -1 --format=%ct 2>/dev/null || date +%s)"

for pkgdir in "$PKG_SRC_DIR"/*/; do
    name="$(basename "$pkgdir")"

    if [ ! -f "$pkgdir/DEBIAN/control" ]; then
        echo "Saltando $name (no tiene DEBIAN/control)"
        continue
    fi

    echo "Empaquetando $name..."

    chmod 755 "$pkgdir/DEBIAN"
    chmod 755 "$pkgdir/DEBIAN/postinst" 2>/dev/null || true
    chmod 755 "$pkgdir/DEBIAN/prerm" 2>/dev/null || true
    chmod 755 "$pkgdir/DEBIAN/preinst" 2>/dev/null || true
    chmod 755 "$pkgdir/DEBIAN/postrm" 2>/dev/null || true

    stage="$BUILD_DIR/$name"
    rm -rf "$stage"
    mkdir -p "$stage"

    # Solo DEBIAN y data forman el paquete.
    # README.md y otros archivos de mantenimiento quedan fuera del payload.
    cp -a "$pkgdir/DEBIAN" "$stage/"

    if [ -d "$pkgdir/data" ]; then
        cp -a "$pkgdir/data" "$stage/"
    fi

    rm -f "$OUT_DIR/${name}_"*_*.deb
    dpkg-deb --build --root-owner-group "$stage" "$OUT_DIR/"
done

rm -rf "$BUILD_DIR"

echo "Generando indice del repo (Packages)..."

INDEX="$OUT_DIR/Packages"
: > "$INDEX"

for deb in "$OUT_DIR"/*.deb; do
    [ -e "$deb" ] || continue

    dpkg-deb -f "$deb" >> "$INDEX"

    {
        echo "Filename: ./$(basename "$deb")"
        echo "Size: $(wc -c < "$deb" | tr -d ' ')"
        echo "MD5sum: $(md5sum "$deb" | cut -d' ' -f1)"
        echo "SHA1: $(sha1sum "$deb" | cut -d' ' -f1)"
        echo "SHA256: $(sha256sum "$deb" | cut -d' ' -f1)"
    } >> "$INDEX"

    echo "" >> "$INDEX"
done

gzip -kf "$INDEX"

# GitHub Pages sirve mejor archivos sin extensión cuando Jekyll está desactivado.
touch "$OUT_DIR/.nojekyll"

echo ""
echo "Listo. docs/ actualizado:"
ls -la "$OUT_DIR"/*.deb "$OUT_DIR/Packages"* "$OUT_DIR/.nojekyll" 2>/dev/null

echo ""
echo "Commit + push para publicar (GitHub Pages sirviendo desde docs/)."
