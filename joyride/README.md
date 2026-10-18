# Jetpack Joyride for R36s / PortMaster / NextOS

A native AArch64 port adapter for **Jetpack Joyride v1.16.2** running on the **R36s handheld console** (Rockchip RK3326 SoC, Mali-G31 MP2 GPU, ARM 64-bit CPU, 1GB RAM).

# Installation

1. Extract the contents of this archive into the `ports/` directory of your SD card (used by PortMaster).
   The resulting layout must contain:
   - `ports/Joyride.sh`
   - `ports/joyride/`

2. Copy your legally owned **Jetpack Joyride v1.16.2 arm64-v8a APK** into:
   - `ports/joyride/gamedata/` (or directly into `ports/joyride/`)
   Standard filename: `com.halfbrick.jetpackjoyride.apk`.

3. Launch **Jetpack Joyride** from the Ports menu on your handheld (R36s / ArkOS / AmberELEC / Rocknix).
   On the first launch, the automated extractor will validate and prepare the game data.

## License
The adapter source code and build scripts are licensed under the GNU General Public License v3.0 (GPL-3.0-only).
See `LICENSE` for details.
Jetpack Joyride is a trademark and copyright of Halfbrick Studios. No proprietary assets or game data are included with this software.
