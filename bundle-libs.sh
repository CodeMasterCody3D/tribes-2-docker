#!/usr/bin/env bash
# bundle-libs.sh — Copy required compatibility libraries from a Loki game
# installation into the Docker build context.
#
# Usage: ./bundle-libs.sh [path/to/game/lib]
#   If no path is given, you'll be prompted to enter one interactively.
#
# This populates the lib/ directory with the old-era shared libraries
# (libSDL, libsmpeg, libstdc++, etc.) that the Docker image needs at
# build time to run GCC 2.95 / egcs-compiled game binaries.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
SRC_DIR="${1:-}"

# If no argument provided, ask the user
if [[ -z "$SRC_DIR" ]]; then
    echo "=== Tribes 2 Docker — Bundle Compatibility Libraries ==="
    echo ""
    echo "Enter the path to your Tribes 2 game's lib/ directory."
    echo "This is the folder containing files like libSDL-1.2.so.0,"
    echo "libstdc++-libc6.2-2.so.3, libsmpeg-0.4.so.0, etc."
    echo ""

    # Try to auto-detect common locations
    CANDIDATES=()
    for guess in \
        "$HOME/tribes2/asgard/lib" \
        "$HOME/Tribes2/Linux/lib" \
        "$HOME/tribes2/lib" \
        "$HOME/Games/Tribes2/lib" \
        "/media/cdrom/Tribes2/Linux/lib" \
        "/mnt/cdrom/Tribes2/Linux/lib" \
        "/opt/tribes2/lib" \
        "/usr/local/games/tribes2/lib"; do
        if [[ -d "$guess" ]] && ls "$guess"/libstdc++* "$guess"/libSDL* "$guess"/libsmpeg* &>/dev/null; then
            CANDIDATES+=("$guess")
        fi
    done

    if [[ ${#CANDIDATES[@]} -gt 0 ]]; then
        echo "Found possible game lib directories:"
        for i in "${!CANDIDATES[@]}"; do
            echo "  $((i+1)). ${CANDIDATES[$i]}"
        done
        echo ""
        read -rp "Enter a path directly, or pick a number [1-${#CANDIDATES[@]}] (default: 1): " INPUT
        INPUT="${INPUT:-1}"

        if [[ "$INPUT" =~ ^[0-9]+$ ]] && [[ "$INPUT" -ge 1 ]] && [[ "$INPUT" -le ${#CANDIDATES[@]} ]]; then
            SRC_DIR="${CANDIDATES[$((INPUT-1))]}"
        else
            SRC_DIR="$INPUT"
        fi
    else
        read -rp "Enter path: " SRC_DIR
    fi

    # Expand ~ and validate
    SRC_DIR="${SRC_DIR/#\~/$HOME}"
    echo ""
fi

if [[ ! -d "$SRC_DIR" ]]; then
    echo "ERROR: '$SRC_DIR' is not a directory."
    exit 2
fi

# Verify it looks like a game lib directory
if ! ls "$SRC_DIR"/libstdc++* "$SRC_DIR"/libSDL* "$SRC_DIR"/libsmpeg* &>/dev/null; then
    echo "WARNING: '$SRC_DIR' doesn't seem to contain expected library files."
    echo "Expected files like: libstdc++-libc6.2-2.so.3, libSDL-1.2.so.0, libsmpeg-0.4.so.0"
    read -rp "Continue anyway? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Clean out old binaries (keep .gitkeep and .gitignore)
find "$LIB_DIR" -maxdepth 1 -type f ! -name '.gitkeep' ! -name '.gitignore' -delete 2>/dev/null || true

COPIED=0
for pattern in libstdc++* libSDL* libsmpeg* libsmjpeg* libttf*; do
    for f in "$SRC_DIR"/$pattern; do
        if [[ -f "$f" ]]; then
            cp -L "$f" "$LIB_DIR/"
            echo "  copied: $(basename "$f")"
            COPIED=$((COPIED + 1))
        fi
    done
done

echo ""
if [[ $COPIED -eq 0 ]]; then
    echo "ERROR: No matching library files found in '$SRC_DIR'."
    exit 2
fi

echo "Done. $COPIED files prepared in $LIB_DIR/"
echo "Run './asgard-build <game>' to build the Docker image with these libraries."
