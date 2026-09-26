# brave-termux

Port of **Brave Browser** to **Termux** (Android userland / X11), structured as standard [`termux-packages`](https://github.com/termux/termux-packages) build recipes.

---

## Architecture & How It Works

Chromium and Brave cannot easily be natively compiled directly on Android devices due to massive CPU/RAM demands, lack of SysV IPC, missing glibc APIs in Bionic, and SELinux sandbox restrictions. 

This repository adapts Termux's two-stage cross-compilation pipeline:

1. **`packages/brave-host-tools`**:
   - Compiles host-native code generators and tools (V8 `mksnapshot`, `run_torque`, domain trie generators, Swiftshader ICD) on the build machine using host Clang/sysroot.
   - Installs these binaries into `$TERMUX_PREFIX/opt/brave-host-tools/`.

2. **`packages/brave-browser`**:
   - Fetches the base Chromium source (`149.0.7827.155`).
   - Downloads and integrates **Brave Core** (`v1.91.177`) into `src/brave`.
   - Injects the Termux compatibility layer (Bionic libc fixes, ashmem/memfd shared memory, Ozone X11 platform, Swiftshader/Vulkan graphics, and disabled setuid/seccomp sandbox).
   - Patches the GN build system to reuse the prebuilt generator tools from `brave-host-tools`.
   - Cross-compiles `brave` and installs it alongside launcher wrappers and `.desktop` integration files.

---

## Package Structure

```
packages/
├── brave-host-tools/
│   ├── build.sh
│   ├── cr-patches/         # Android / Bionic compatibility patches
│   ├── jumbo-patches/      # Jumbo/unity build speedups
│   ├── scripts/            # GN build rewrite scripts
│   └── toolchain-template/ # Host & V8 custom toolchain definitions
└── brave-browser/
    ├── build.sh
    ├── brave-launcher.sh.in
    ├── 9001-use-prebuilt-snapshot.patch
    ├── 9002-use-prebuilt-cross-tools.patch
    ├── 9003-v8-use-prebuilt-cross-tools.patch
    ├── 9004-use-prebuilt-pdfium.patch
    └── third_party_override/
```

---

## How to Build with `termux-packages`

1. Clone `termux-packages`:
   ```bash
   git clone https://github.com/termux/termux-packages.git
   cd termux-packages
   ```

2. Copy the packages into `x11-packages/`:
   ```bash
   cp -r /path/to/brave-termux/packages/brave-host-tools x11-packages/
   cp -r /path/to/brave-termux/packages/brave-browser x11-packages/
   ```

3. Build the host tools first (in docker container or host environment):
   ```bash
   ./build-package.sh -a aarch64 brave-host-tools
   ```

4. Build the browser package:
   ```bash
   ./build-package.sh -a aarch64 brave-browser
   ```

5. Install the resulting `.deb` package inside Termux:
   ```bash
   pkg install ./brave-browser_*.deb
   ```

6. Run Brave inside Termux X11:
   ```bash
   brave-browser
   # or
   brave
   ```
