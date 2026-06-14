# Tribes 2 Docker Compatibility Layer

A Docker-based compatibility wrapper to run the native 2001 Loki Software Linux port of **Tribes 2** on modern 64-bit (x86_64) Linux hosts (such as Ubuntu 24.04, KDE neon, Debian, and Arch).

It solves modern system issues (NPTL threading conflicts, OSS/ALSA audio locks, OpenGL driver issues, and display socket routing) by containerizing the game in a 32-bit Ubuntu 16.04 container.

---

## Technical Features & Workarounds Included

1. **Threading Model Compatibility (NPTL vs LinuxThreads):**
   The native game binary freezes or deadlocks under modern host kernels due to NPTL. Running the engine inside a 32-bit Ubuntu 16.04 container isolates it under a compatible threading context.
2. **TrueType Font Fallbacks (Bypasses Exit Code 1):**
   The GUI profile manager requires `Arial.ttf` and `Verdana Bold.ttf` to start up the main menu shell. If these are missing, the client exits cleanly with status `1`. This repository bundles open-source Liberation Sans fonts renamed as drop-in replacements for Arial/Verdana.
3. **Missing Intro Movie Bypass (Bypasses Segfault):**
   Passing the `-nologin` flag bypasses defunct WON/Sierra login servers but makes the game load the intro movie. If `base/textures/T2IntroC15.mpg` is missing, the smpeg engine suffers a null pointer dereference, causing a segmentation fault (`BUG! Going down hard...`). Setting `$pref::SkipIntro = 1;` in `ClientPrefs.cs` resolves this.
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
The Docker image needs old-era shared libraries (libSDL, libsmpeg, libstdc++ from GCC 2.95) to run game binaries compiled with egcs/GCC 2.95. Use the provided helper script to copy them from your game installation:

```bash
./bundle-libs.sh /home/cody/tribes2/asgard/lib
```

This populates the `lib/` directory with the required `.so` files and compiles the `__ti9exception` shim needed for the old C++ ABI. The `lib/.gitignore` keeps these binaries out of git — they're rebuilt per-user from their own game files.

### 3b. (Optional) Add Loki Compatibility Libraries
If you have additional Loki compatibility shared libraries (e.g. for Civ:CTP), place them in the `lib/` folder at the repo root. The build will copy them into the container's `/usr/lib/`.

### 3. Skip the Intro Movie in Preferences
To prevent the Smpeg movie player from segfaulting on the missing movie file, set the skip intro preference in your local preferences file.

Run the following command to append the preference to your game configuration:
```bash
mkdir -p ~/.loki/tribes2/base/prefs/
echo '$pref::SkipIntro = 1;' >> ~/.loki/tribes2/base/prefs/ClientPrefs.cs
```

---

## How to Build & Play

1. **Build the container:**
   ```bash
   sudo ./asgard-build tribes2
   ```

2. **Run the game (bind-mount your existing game folder — no copy needed):**
   ```bash
   ./asgard-run tribes2 /home/cody/t2-linux
   ```
   The second argument is the path to your game directory on the host — anywhere
   you keep it. It gets mounted read-write into the container at runtime (so the
   engine can write `console.log`, prefs, and screenshots), and the repo's
   `run_t2.sh` launcher and `base/fonts/` are overlaid on top automatically.

   **Or run it interactively** — with no path argument the script auto-detects
   common locations (including `~/t2-linux`) and prompts you to pick one or type
   a path:
   ```bash
   ./asgard-run
   ```

   **Or, if you already copied files into `games/tribes2/`:**
   ```bash
   ./asgard-run tribes2
   ```
   Without a second argument and nothing to prompt for, it uses the game files
   baked into the image at build time.

The wrapper script `run_t2.sh` automatically forces the game to launch in offline mode (`-nologin`) and route output correctly.
