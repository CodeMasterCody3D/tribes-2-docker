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
    echo "Examples:"
    echo "  /home/cody/tribes2/asgard/lib"
    echo "  /media/cdrom/Tribes2/Linux/lib"
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
        if [[ -d "$guess" ]] && [[ -n "$(ls "$guess"/libstdc++* "$guess"/libSDL* "$guess"/libsmpeg* 2>/dev/null)" ]]; then
            CANDIDATES+=("$guess")
        fi
    done

    if [[ ${#CANDIDATES[@]} -gt 0 ]]; then
        echo "Found possible game lib directories:"
        for i in "${!CANDIDATES[@]}"; do
            echo "  $((i+1)). ${CANDIDATES[$i]}"
        done
        echo "  0. Enter a custom path"
        echo ""
        read -rp "Select [0-${#CANDIDATES[@]}] (default: 1): " CHOICE
        CHOICE="${CHOICE:-1}"

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [[ "$CHOICE" -ge 1 ]] && [[ "$CHOICE" -le ${#CANDIDATES[@]} ]]; then
            SRC_DIR="${CANDIDATES[$((CHOICE-1))]}"
        elif [[ "$CHOICE" == "0" ]]; then
            read -rp "Enter path: " SRC_DIR
        else
            echo "Invalid choice."
            exit 1
        fi
    else
        echo "(No common locations found automatically.)"
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
if [[ -z "$(ls "$SRC_DIR"/libstdc++* "$SRC_DIR"/libSDL* "$SRC_DIR"/libsmpeg* 2>/dev/null)" ]]; then
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
