#!/usr/bin/env bash
# bundle-libs.sh — Copy required compatibility libraries from a Loki game
# installation into the Docker build context.
#
# Usage: ./bundle-libs.sh [path/to/game/lib]
#   If no path is given, you'll be prompted to enter one interactively.
#   You can point it at either:
#     - The game's lib/ subfolder (e.g. /path/to/game/lib)
#     - The game root folder (e.g. /path/to/game) — it'll search recursively
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
    echo "Enter the path to your Tribes 2 game installation."
    echo "You can point at the game root or its lib/ subfolder."
    echo "The script will search for files like libSDL-1.2.so.0,"
    echo "libstdc++-libc6.2-2.so.3, libsmpeg-0.4.so.0, etc."
    echo ""

    # Try to auto-detect common locations (game root or lib subdir)
    CANDIDATES=()
    for guess in \
        "$HOME/tribes2/asgard/lib" \
        "$HOME/tribes2/asgard" \
        "$HOME/Downloads/t2-linux" \
        "$HOME/Tribes2/Linux" \
        "$HOME/tribes2" \
        "$HOME/Games/Tribes2" \
        "/media/cdrom/Tribes2/Linux" \
        "/mnt/cdrom/Tribes2/Linux" \
        "/opt/tribes2" \
        "/usr/local/games/tribes2"; do
        if [[ -d "$guess" ]]; then
            # Check for compat libs in this dir or a lib/ subdir
            if ls "$guess"/libstdc++* "$guess"/libSDL* "$guess"/libsmpeg* &>/dev/null; then
                CANDIDATES+=("$guess")
            elif ls "$guess"/lib/libstdc++* "$guess"/lib/libSDL* "$guess"/lib/libsmpeg* &>/dev/null; then
                CANDIDATES+=("$guess/lib")
            fi
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

# If the user pointed at a game root (has tribes2.dynamic but no libstdc++),
# check if there's a lib/ subdir or search one level deeper
if ! ls "$SRC_DIR"/libstdc++* "$SRC_DIR"/libSDL* "$SRC_DIR"/libsmpeg* &>/dev/null; then
    if ls "$SRC_DIR"/lib/libstdc++* "$SRC_DIR"/lib/libSDL* "$SRC_DIR"/lib/libsmpeg* &>/dev/null; then
        SRC_DIR="$SRC_DIR/lib"
        echo "Using lib/ subdirectory: $SRC_DIR"
    else
        echo "WARNING: No compat library files found in '$SRC_DIR'."
        echo "Expected files like: libstdc++-libc6.2-2.so.3, libSDL-1.2.so.0, libsmpeg-0.4.so.0"
        echo "The Docker image includes fallback packages (libsmpeg0, libsdl1.2debian)"
        echo "so the game may still work without these."
        read -rp "Continue anyway? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
            echo "Aborted."
            exit 1
        fi
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
    echo "WARNING: No matching library files copied."
    echo "The Docker image's built-in packages may be sufficient."
else
    echo "Done. $COPIED files prepared in $LIB_DIR/"
fi
echo "Run './asgard-build <game>' to build the Docker image with these libraries."
