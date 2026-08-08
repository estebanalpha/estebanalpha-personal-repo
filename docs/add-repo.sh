#!/data/data/com.termux/files/usr/bin/bash
REPO_URL="https://estebanalpha.github.io/estebanalpha-personal-repo"

set -e
mkdir -p "$PREFIX/etc/apt/sources.list.d"
echo "deb [trusted=yes] $REPO_URL/ ./" > "$PREFIX/etc/apt/sources.list.d/estebanalpha-repo.list"
pkg update

echo ""
echo "EN: Repository added. Install with: pkg install shizuku-semi-auto"
echo "ES: Repositorio agregado. Instala con: pkg install shizuku-semi-auto"
