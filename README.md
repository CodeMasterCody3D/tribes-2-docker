# Tribes 2 Docker Compatibility Layer

A Docker-based compatibility wrapper to run the native 2001 Loki Software Linux port of **Tribes 2** on modern 64-bit (x86_64) Linux hosts (such as Ubuntu 24.04, KDE neon, Debian, and Arch).

It solves modern system issues (NPTL threading conflicts, OSS/ALSA audio locks, OpenGL driver issues, and display socket routing) by containerizing the game in a 32-bit Ubuntu 16.04 container.

---

## Technical Features & Workarounds Included

1. **Threading Model Compatibility (NPTL vs LinuxThreads):**
   The native game binary freezes or deadlocks under modern host kernels due to NPTL. Running the engine inside a 32-bit Ubuntu 16.04 container isolates it under a compatible threading context.
2. **TrueType Font Fallbacks (Bypasses Exit Code 1):**
   The GUI profile manager requires `Arial.ttf` and `Verdana Bold.ttf` to start up the main menu shell. If these are missing, the client exits cleanly with status `1`. This repository bundles open-source Liberation Sans fonts renamed as drop-in replacements for Arial/Verdana.
3. **Intro Movie Handling (situational):**
   Passing the `-nologin` flag bypasses defunct WON/Sierra login servers but makes the game load the intro movie. On most complete game copies the intro plays (or is skipped by the engine) without issue. However, if `base/textures/T2IntroC15.mpg` is missing on your copy, the smpeg engine can null-dereference and segfault (`BUG! Going down hard...`). If that happens, set `$pref::SkipIntro = 1;` in `ClientPrefs.cs` — see Troubleshooting below.
4. **Audio Routing via PulseAudio OSS wrapper:**
   PulseAudio OSS emulation (`padsp`) is wrapped around the execution launcher to route OSS `/dev/dsp` calls through modern audio endpoints.
5. **Software OpenGL Rendering:**
   Forced software Mesa OpenGL rendering (`LIBGL_ALWAYS_SOFTWARE=1`) is enabled by default to prevent hardware driver symbol mismatches inside the legacy 32-bit container.

---

## Installation & Setup

### 1. Clone the repository
Clone this project to your local machine.

### 2. Copy the Game Files (or use a bind mount)
Copy the contents of your original *Tribes 2* Linux game directory (specifically containing files like `tribes2`, `tribes2.dynamic`, `console_start.cs`, and the `base/` folder) into the folder:
`games/tribes2/`

*(Note: The required GUI fonts are already bundled under `games/tribes2/base/fonts/` for convenience).*

**Alternatively (recommended)**, skip the copy entirely and point `asgard-run` at your existing game folder anywhere on the host. The container reads the files live via a bind mount — no duplication needed — and the bundled launcher (`run_t2.sh`) and replacement fonts (`base/fonts/`) from this repo are automatically layered on top of your folder, so you don't have to add them yourself. See the "Run the game" section below.

### 3a. Bundle Compatibility Libraries
The Docker image needs old-era shared libraries (libSDL, libsmpeg, libstdc++ from GCC 2.95) to run game binaries compiled with egcs/GCC 2.95. Run the helper script with no arguments to get an **interactive arrow-key menu** that finds and copies them from your game installation:

```bash
./bundle-libs.sh
```

It auto-detects folders that already contain the libraries, and offers a **"Browse for a folder..."** picker (↑/↓ + **Open** to enter a folder, **Tab → "Choose THIS folder"** to select) — the same navigation as the game-folder menu, flagging any folder where the compat libraries are found. You can still pass the path directly to skip the menu:

```bash
./bundle-libs.sh /home/cody/tribes2/asgard/lib
```

This populates the `lib/` directory with the required `.so` files. The `lib/.gitignore` keeps these binaries out of git — they're rebuilt per-user from their own game files.

### 3b. (Optional) Add Loki Compatibility Libraries
If you have additional Loki compatibility shared libraries (e.g. for Civ:CTP), place them in the `lib/` folder at the repo root. The build will copy them into the container's `/usr/lib/`.

---

## How to Build & Play

1. **Build the container:**
   ```bash
   sudo ./asgard-build tribes2
   ```

2. **Run the game — interactive folder menu (recommended):**
   ```bash
   ./asgard-run tribes2
   ```
   With no folder argument, an arrow-key menu pops up so you can tell it where
   your Tribes 2 game folder lives — no need to know or type the path:

   - It first lists any **auto-detected** installs (e.g. `~/t2-linux`,
     `~/Downloads/t2-linux`). Use **↑/↓** and **Enter** to pick one.
   - Or choose **"Browse for a folder..."** to open a file browser. Inside it:
     - **↑/↓** highlight a sub-folder, **Open** (Enter) goes inside it,
       **".. (go up a level)"** goes back up.
     - **Tab** over to **"Choose THIS folder"** to select the folder you're
       currently in. It flags the spot where Tribes 2 is detected.
   - Or pick **"Use the copy baked into the image"** to run the files bundled at
     build time.

   The chosen folder is bind-mounted read-write into the container (so the engine
   can write `console.log`, prefs, and screenshots), and the repo's `run_t2.sh`
   launcher and `base/fonts/` are layered on top automatically — so your game
   folder can live anywhere and needs no modification.

   **Skip the menu** by passing the path directly as a second argument:
   ```bash
   ./asgard-run tribes2 /home/cody/t2-linux
   ```

   *(The menu needs `whiptail`, which ships with most distros. Without it, or in a
   non-interactive shell, the script falls back to a simple text prompt.)*

The wrapper script `run_t2.sh` automatically forces the game to launch in offline mode (`-nologin`) and route output correctly.

---

## Troubleshooting

**Game segfaults on startup with `BUG! Going down hard...` (missing intro movie):**
If your game copy is missing `base/textures/T2IntroC15.mpg`, the intro player can crash. Skip the intro by adding the preference to your local config:
```bash
mkdir -p ~/.loki/tribes2/base/prefs/
echo '$pref::SkipIntro = 1;' >> ~/.loki/tribes2/base/prefs/ClientPrefs.cs
```
(Most complete game copies don't need this — the intro plays fine.)
