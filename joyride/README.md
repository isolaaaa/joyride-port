# Jetpack Joyride for R36s / PortMaster

A native AArch64 port adapter for **Jetpack Joyride v1.16.2** running on the **R36s handheld console** (Rockchip RK3326 SoC, Mali-G31 MP2 GPU, ARM 64-bit CPU, 1GB RAM).

Built using the `nextos-framework` Track 8 (native Android SO loader adapter).

## Features
- Full AArch64 binary targeting Linux with GLIBC 2.17 compatibility (compatible with ArkOS, AmberELEC, JELOS, Rocknix, muOS, etc.).
- Direct OpenGL ES 2.0 rendering via SDL2.
- Low-latency PCM stereo audio queue at 44.1 kHz via SDL2.
- Full PortMaster controller mapping:
  - Gamepad buttons (A, B, R1/R2) for jetpack thrust.
  - Left stick / D-Pad for cursor navigation in menus.
  - Start / Select for back, pause and quit.
- Integrated offline content-driven NXExtract verification recipe (`extractor.json`).

## Requirements
- Target: R36s or any AArch64 RK3326 device running a PortMaster-compatible Linux distribution.
- Commercial data: A legally acquired copy of Jetpack Joyride v1.16.2 APK (`com.halfbrick.jetpackjoyride.apk`).

## License
The adapter source code and build scripts are licensed under the GNU General Public License v3.0 (GPL-3.0-only).
See `LICENSE` for details.
Jetpack Joyride is a trademark and copyright of Halfbrick Studios. No proprietary assets or game data are included with this software.
