#!/usr/bin/env bash
# Rebuilds every package under packages/ and regenerates the repo index.
#
# Default (local test build): output goes to .build/out/ and nothing in
# docs/ is touched. With --publish the output goes to docs/, the folder
# GitHub Pages serves; that mode is meant for the CI workflow, which
# commits the result. Do not commit docs/ by hand.
#
# Needs: dpkg-deb, md5sum/sha1sum/sha256sum, gzip (all part of the base
# 'dpkg'/coreutils in Termux). dpkg-scanpackages/dpkg-dev is deliberately
# not used: it does not exist in Termux.
#
# Usage: ./build.sh [--publish]
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_SRC_DIR="$REPO_DIR/packages"
BUILD_DIR="$REPO_DIR/.build"
STAGE_DIR="$BUILD_DIR/stage"

case "${1:-}" in
    --publish) OUT_DIR="$REPO_DIR/docs"; PUBLISH=1 ;;
    "")        OUT_DIR="$BUILD_DIR/out";  PUBLISH=0 ;;
    *) echo "Usage: ./build.sh [--publish]" >&2; exit 2 ;;
esac

mkdir -p "$OUT_DIR" "$STAGE_DIR"

# Repo-wide fallback, used only for a package with no git history yet.
REPO_EPOCH="$(git -C "$REPO_DIR" log -1 --format=%ct 2>/dev/null || date +%s)"

for pkgdir in "$PKG_SRC_DIR"/*/; do
    name="$(basename "$pkgdir")"

    if [ ! -f "$pkgdir/DEBIAN/control" ]; then
        echo "Skipping $name (no DEBIAN/control)"
        continue
    fi

    echo "Packaging $name..."

    stage="$STAGE_DIR/$name"
    rm -rf "$stage"
    mkdir -p "$stage"

    # Only DEBIAN and data form the package; README.md and other
    # maintenance files stay out of the payload.
    cp -a "$pkgdir/DEBIAN" "$stage/"
    if [ -d "$pkgdir/data" ]; then
        cp -a "$pkgdir/data" "$stage/"
    fi

    # Normalize modes so the .deb bytes do not depend on the umask of the
    # machine that builds it (Termux and CI must produce identical files):
    # directories 755, files 644, anything already executable 755.
    find "$stage" -type d -exec chmod 755 {} +
    find "$stage" -type f ! -perm -u+x -exec chmod 644 {} +
    find "$stage" -type f -perm -u+x -exec chmod 755 {} +
    # Commands and maintainer scripts are always executable, even if the
    # executable bit was lost on the way into git.
    find "$stage" -type f -path '*/usr/bin/*' -exec chmod 755 {} +
    for script in preinst postinst prerm postrm; do
        if [ -f "$stage/DEBIAN/$script" ]; then chmod 755 "$stage/DEBIAN/$script"; fi
    done

    # Per-package epoch: last commit that touched packages/<name>, so a
    # commit that only touches another package does not change this .deb.
    PKG_EPOCH="$(git -C "$REPO_DIR" log -1 --format=%ct -- "packages/$name" 2>/dev/null)"
    [ -n "$PKG_EPOCH" ] || PKG_EPOCH="$REPO_EPOCH"

    rm -f "$OUT_DIR/${name}_"*_*.deb
    SOURCE_DATE_EPOCH="$PKG_EPOCH" dpkg-deb --build --root-owner-group "$stage" "$OUT_DIR/"
done

rm -rf "$STAGE_DIR"

echo "Generating the repo index (Packages)..."

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

# -n: do not store the file name and timestamp in the gzip header, so an
# unchanged index compresses to identical bytes.
gzip -nkf "$INDEX"

if [ "$PUBLISH" -eq 1 ]; then
    # GitHub Pages serves extensionless files properly with Jekyll off.
    touch "$OUT_DIR/.nojekyll"
fi

echo ""
echo "Done. Output in: $OUT_DIR"
ls -la "$OUT_DIR"/*.deb "$OUT_DIR/Packages"* 2>/dev/null

echo ""
if [ "$PUBLISH" -eq 1 ]; then
    echo "docs/ updated. In CI the workflow commits it; locally, do not commit docs/."
else
    echo "Local test build only; docs/ was not touched. Pushing changes under"
    echo "packages/ makes the CI workflow publish them."
fi
