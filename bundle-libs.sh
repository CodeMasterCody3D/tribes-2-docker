#!/usr/bin/env bash
# bundle-libs.sh — Copy required compatibility libraries from a Loki game
# installation into the Docker build context.
#
# Usage: ./bundle-libs.sh /path/to/game/lib
#   e.g. ./bundle-libs.sh /home/cody/tribes2/asgard/lib
#
# This populates the lib/ directory with the old-era shared libraries
# (libSDL, libsmpeg, libstdc++, etc.) that the Docker image needs at
# build time to run GCC 2.95 / egcs-compiled game binaries.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
SRC_DIR="${1:-}"

if [[ -z "$SRC_DIR" ]]; then
    echo "Usage: $0 /path/to/game/lib"
    echo ""
    echo "Copies compatibility .so files from a Loki game's lib/ directory"
    echo "into this repo's lib/ directory for inclusion in the Docker image."
    exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: '$SRC_DIR' is not a directory."
    exit 2
fi

# Clean out old binaries (keep .gitkeep and .gitignore)
find "$LIB_DIR" -maxdepth 1 -type f ! -name '.gitkeep' ! -name '.gitignore' -delete 2>/dev/null || true

COPIED=0
for pattern in libstdc++* libSDL* libsmpeg* libsmjpeg* libttf*; do
    for f in "$SRC_DIR"/$pattern; do
        if [[ -f "$f" ]]; then
            cp "$f" "$LIB_DIR/"
            echo "  copied: $(basename "$f")"
            ((COPIED++))
        fi
    done
done

# Also copy the ti9exception shim source and compile it
SHIM_SRC="$LIB_DIR/ti9exception-shim.c"
cat > "$SHIM_SRC" << 'EOF'
/* Shim to provide __ti9exception for GCC 2.95 / egcs binaries.
   Modern libstdc++ dropped this old typeinfo symbol. */
typedef struct { const void *vptr; const char *name; } __attribute__((aligned(8))) ti9exception;
static const void *__ti9exception_vtable[2];
__attribute__((visibility("default"), weak))
ti9exception __ti9exception = { __ti9exception_vtable, "9exception" };
EOF

if command -v gcc &>/dev/null; then
    gcc -shared -fPIC -o "$LIB_DIR/libti9exception.so" "$SHIM_SRC"
    echo "  compiled: libti9exception.so"
    ((COPIED++))
else
    echo "  WARNING: gcc not found, skipping libti9exception.so compilation"
    echo "  Install gcc and run: gcc -shared -fPIC -o lib/libti9exception.so lib/ti9exception-shim.c"
fi

echo ""
echo "Done. $COPIED files prepared in $LIB_DIR/"
echo "Run './asgard-build <game>' to build the Docker image with these libraries."
