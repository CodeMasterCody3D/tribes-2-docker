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

**Alternatively**, you can skip the copy entirely and point `asgard-run` at your existing game folder on the host. The container will read the files live via a bind mount — no duplication needed. See the "Run the game" section below.

### 3a. (Optional) Add Loki Compatibility Libraries
If you have a `lib/` directory with Loki compatibility shared libraries (e.g. for Civ:CTP), place them in the `lib/` folder at the repo root. The build will copy them into the container's `/usr/lib/`. This directory can be empty (it ships with a `.gitkeep`).

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
   sudo ./asgard-run tribes2 /home/cody/tribes2/asgard/games/tribes2
   ```
   The second argument is the path to your game directory on the host. It gets mounted read-only into the container at runtime.

   **Or, if you already copied files into `games/tribes2/`:**
   ```bash
   sudo ./asgard-run tribes2
   ```
   Without a second argument, uses the game files baked into the image at build time.

The wrapper script `run_t2.sh` automatically forces the game to launch in offline mode (`-nologin`) and route output correctly.
