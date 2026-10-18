#!/bin/bash
# PORTMASTER: joyride, Joyride.sh
# Jetpack Joyride - Universal PortMaster launcher (dArkOS / ArkOS / muOS / Knulli / AmberELEC / ROCKNIX)

# 1. Glibc memory constraints for handheld devices (1GB RAM)
export MALLOC_ARENA_MAX=1
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_MMAP_THRESHOLD_=131072

# 2. Firmware dynamic loader environment isolation
ORIG_LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}
ORIG_LD_PRELOAD=${LD_PRELOAD:-}
unset LD_LIBRARY_PATH LD_PRELOAD

# 3. PortMaster Discovery
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
controlfolder=""

PM_CANDIDATES=(
  "${PM_DIR:-}"
  /opt/system/Tools/PortMaster
  /opt/tools/PortMaster
  "$XDG_DATA_HOME/PortMaster"
  /storage/.config/PortMaster
  /var/data/PortMaster
  /PortMaster
  /roms/tools/PortMaster
  /roms2/tools/PortMaster
  /storage/roms/ports/PortMaster
  /storage/roms/Ports/PortMaster
  /roms/ports/PortMaster
  /roms2/ports/PortMaster
  /roms/Ports/PortMaster
  /userdata/system/.local/share/PortMaster
  /mnt/mmc/MUOS/PortMaster
  /mnt/mmc/ports/PortMaster
  /mnt/mmc/Ports/PortMaster
  /mnt/sdcard/ports/PortMaster
  /mnt/sdcard/Ports/PortMaster
  /mnt/SDCARD/Apps/PortMaster/PortMaster
  /mnt/sdcard/Roms/.portmaster/PortMaster
)

for pm in "${PM_CANDIDATES[@]}"; do
  [ -n "$pm" ] && [ -r "$pm/control.txt" ] || continue
  controlfolder="$pm"
  . "$pm/control.txt"
  ORIG_LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-$ORIG_LD_LIBRARY_PATH}
  ORIG_LD_PRELOAD=${LD_PRELOAD:-$ORIG_LD_PRELOAD}
  unset LD_LIBRARY_PATH LD_PRELOAD

  case "${CFW_NAME:-}" in
    ''|*[!A-Za-z0-9._-]*) ;;
    *) [ ! -r "$pm/mod_${CFW_NAME}.txt" ] || . "$pm/mod_${CFW_NAME}.txt" ;;
  esac
  ORIG_LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-$ORIG_LD_LIBRARY_PATH}
  ORIG_LD_PRELOAD=${LD_PRELOAD:-$ORIG_LD_PRELOAD}
  unset LD_LIBRARY_PATH LD_PRELOAD

  command -v get_controls >/dev/null 2>&1 && get_controls
  ORIG_LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-$ORIG_LD_LIBRARY_PATH}
  ORIG_LD_PRELOAD=${LD_PRELOAD:-$ORIG_LD_PRELOAD}
  unset LD_LIBRARY_PATH LD_PRELOAD
  break
done
unset PM_CANDIDATES

# 4. muOS Identification & Display/Wayland Discovery
IS_MUOS=0
case "${CFW_NAME:-} $(uname -n)" in *muos*|*muOS*|*MuOS*) IS_MUOS=1 ;; esac
[ ! -d /opt/muos ] || IS_MUOS=1

if [ "$IS_MUOS" = 1 ]; then
  # muOS swaps button labels by default in SDL; disable label swapping
  export SDL_GAMECONTROLLER_USE_BUTTON_LABELS=0
fi

# Discover Wayland runtime socket (essential for muOS video initialization)
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  for runtime in /run/0-runtime-dir /var/run/0-runtime-dir "/run/user/$(id -u)"; do
    [ -d "$runtime" ] || continue
    export XDG_RUNTIME_DIR="$runtime"
    break
  done
fi

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  for socket in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
    [ -S "$socket" ] || continue
    export WAYLAND_DISPLAY="${socket##*/}"
    break
  done
fi

# 5. Robust Game Directory Resolution (handles muOS / ArkOS / SD1 / SD2 layouts)
PORTS_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
TASK_DIR=""

for candidate in \
  "$PORTS_DIR/joyride" \
  "${directory:+/${directory#/}/ports/joyride}" \
  "${directory:+/${directory#/}/Ports/joyride}" \
  /mnt/sdcard/ports/joyride \
  /mnt/mmc/ports/joyride \
  /mnt/sdcard/ROMS/ports/joyride \
  /mnt/sdcard/ROMS/Ports/joyride \
  /mnt/mmc/ROMS/ports/joyride \
  /mnt/mmc/ROMS/Ports/joyride \
  /mnt/SDCARD/Ports/joyride \
  /mnt/SDCARD/ports/joyride \
  /storage/roms/ports/joyride \
  /storage/roms/Ports/joyride \
  /roms/ports/joyride \
  /roms/Ports/joyride \
  /roms2/ports/joyride \
  /roms2/Ports/joyride \
  "$PORTS_DIR"; do
  [ -n "$candidate" ] && [ -f "$candidate/joyride-nextos" ] || continue
  TASK_DIR="$(cd -- "$candidate" && pwd -P)"
  break
done

if [ -z "$TASK_DIR" ]; then
  echo "ERROR: joyride directory with joyride-nextos binary not found!"
  command -v pm_finish >/dev/null 2>&1 && pm_finish || true
  exit 2
fi

GAMEDIR="$TASK_DIR"
cd "$GAMEDIR" || exit 1

# 6. Logging Setup
mkdir -p "$GAMEDIR/gamedata" "$GAMEDIR/lib" "$GAMEDIR/logs"
LOG="$GAMEDIR/log.txt"
[ -s "$LOG" ] && mv -f "$LOG" "$GAMEDIR/log.prev.txt" 2>/dev/null || true
exec > "$LOG" 2>&1

printf '== Jetpack Joyride | CFW=%s | muOS=%s ==\n' "${CFW_NAME:-auto}" "$IS_MUOS"
printf 'GAMEDIR: %s\n' "$GAMEDIR"
uname -a

# 7. Cleanup & Termination Trap
game_pid=""
finished=0

cleanup() {
  [ "$finished" = 0 ] || return 0
  finished=1
  local status=$?
  printf '== Cleaning up (exit status %s) ==\n' "$status"

  if [ -n "$game_pid" ]; then
    kill -TERM "$game_pid" 2>/dev/null || true
    for ((i=0; i<30; i++)); do
      kill -0 "$game_pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$game_pid" 2>/dev/null || true
    wait "$game_pid" 2>/dev/null || true
  fi

  # Terminate helper/setup UI if interrupted
  pkill -9 -f "nxextract-ui" 2>/dev/null || true

  # Stop gptokeyb if active
  if [ -n "${ESUDO:-}" ]; then
    $ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null || true
    $ESUDO kill -9 $(pidof gptokeyb2) 2>/dev/null || true
  else
    pkill -9 gptokeyb 2>/dev/null || true
    pkill -9 gptokeyb2 2>/dev/null || true
  fi

  # Restore muOS system audio services if modified
  command -v restore_muos_audio >/dev/null 2>&1 && restore_muos_audio || true

  # Restore console screen if terminal device exists
  [ -z "${CUR_TTY:-}" ] || { [ ! -c "$CUR_TTY" ] || printf '\033c' > "$CUR_TTY" 2>/dev/null; }

  # PortMaster finish signal
  command -v pm_finish >/dev/null 2>&1 && pm_finish || true
  return 0
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# 8. Permissions Setup
if [ -n "${ESUDO:-}" ]; then
  $ESUDO chmod +x "$GAMEDIR/joyride-nextos" "$GAMEDIR"/*.sh "$GAMEDIR"/nxextract/* "$GAMEDIR"/tools/* 2>/dev/null || true
  [ -n "${CUR_TTY:-}" ] && [ -c "$CUR_TTY" ] && $ESUDO chmod 666 "$CUR_TTY" /dev/uinput /dev/fb0 2>/dev/null || true
else
  chmod +x "$GAMEDIR/joyride-nextos" "$GAMEDIR"/*.sh "$GAMEDIR"/nxextract/* "$GAMEDIR"/tools/* 2>/dev/null || true
fi

# 9. Game Assets Extraction Check (NXExtract UI)
FOUND_CONTAINER=""
for candidate in \
  "$GAMEDIR/gamedata/com.halfbrick.jetpackjoyride.apk" \
  "$GAMEDIR/gamedata/com.halfbrick.jetpackjoyride.zip" \
  "$GAMEDIR/com.halfbrick.jetpackjoyride.apk" \
  "$GAMEDIR/com.halfbrick.jetpackjoyride.zip" \
  "$GAMEDIR/gamedata/"*.apk \
  "$GAMEDIR/gamedata/"*.zip \
  "$GAMEDIR/"*.apk \
  "$GAMEDIR/"*.zip; do
  if [ -f "$candidate" ] && [ ! -L "$candidate" ]; then
    FOUND_CONTAINER="$candidate"
    break
  fi
done

if [ -n "$FOUND_CONTAINER" ]; then
  printf 'Found game container: %s\n' "$FOUND_CONTAINER"
fi

if [ ! -f "$GAMEDIR/lib/libmortargame.so" ] || [ ! -f "$GAMEDIR/gamedata/com.halfbrick.jetpackjoyride.apk" ]; then
  printf 'Native library or APK container missing. Running extraction...\n'

  FIRMWARE_LIBS="/usr/local/lib/aarch64-linux-gnu:/usr/local/lib:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu:/usr/lib:/lib:${controlfolder:+$controlfolder/libs:}${controlfolder:+$controlfolder/libs.aarch64}"
  export NXEXTRACT_FIRMWARE_LIBRARY_PATH="$FIRMWARE_LIBS"

  NXEXTRACT_DIR="$GAMEDIR/nxextract"
  if [ -f "$NXEXTRACT_DIR/run-extractor.sh" ] && [ -f "$GAMEDIR/extractor.json" ] && command -v python3 >/dev/null 2>&1; then
    printf 'Invoking NXExtract UI launcher...\n'
    NXEXTRACT_GAME_DIR="$GAMEDIR" \
      bash "$NXEXTRACT_DIR/nxextract-runtime-env.sh" \
      bash "$NXEXTRACT_DIR/run-extractor.sh" || {
        printf 'NXExtract UI returned status %s; continuing with fallback extraction\n' "$?"
      }
  elif [ -f "$GAMEDIR/nxextract.py" ] && [ -f "$GAMEDIR/extractor.json" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$GAMEDIR/nxextract.py" install --recipe "$GAMEDIR/extractor.json" --game-dir "$GAMEDIR" || true
  fi

  # Fallback direct extraction of libmortargame.so
  if [ ! -f "$GAMEDIR/lib/libmortargame.so" ] && [ -n "$FOUND_CONTAINER" ]; then
    printf 'Extracting libmortargame.so directly from %s...\n' "$FOUND_CONTAINER"
    if command -v unzip >/dev/null 2>&1; then
      unzip -q -o "$FOUND_CONTAINER" "lib/arm64-v8a/libmortargame.so" -d "$GAMEDIR/.extract_tmp" 2>/dev/null || true
      if [ -f "$GAMEDIR/.extract_tmp/lib/arm64-v8a/libmortargame.so" ]; then
        mv -f "$GAMEDIR/.extract_tmp/lib/arm64-v8a/libmortargame.so" "$GAMEDIR/lib/libmortargame.so"
      fi
      rm -rf "$GAMEDIR/.extract_tmp"
    fi
  fi

  # Ensure APK is in gamedata/
  if [ ! -f "$GAMEDIR/gamedata/com.halfbrick.jetpackjoyride.apk" ] && [ -n "$FOUND_CONTAINER" ]; then
    cp -f "$FOUND_CONTAINER" "$GAMEDIR/gamedata/com.halfbrick.jetpackjoyride.apk" 2>/dev/null || true
  fi
fi

# Verify essential files
if [ ! -f "$GAMEDIR/joyride-nextos" ]; then
  echo "ERROR: joyride-nextos binary missing"
  exit 1
fi

if [ ! -f "$GAMEDIR/lib/libmortargame.so" ] && [ ! -f "$GAMEDIR/libmortargame.so" ]; then
  echo "ERROR: libmortargame.so is missing! Ensure game APK was supplied in gamedata/."
  exit 1
fi

# 10. Libraries and Dynamic Linker Configuration (AArch64)
LIBS=""
for libdir in \
  "$GAMEDIR/lib" \
  "$GAMEDIR" \
  "${controlfolder:+$controlfolder/libs.aarch64}" \
  "${controlfolder:+$controlfolder/libs}" \
  /usr/local/lib/aarch64-linux-gnu \
  /usr/local/lib64 \
  /usr/local/lib \
  /usr/lib/aarch64-linux-gnu \
  /lib/aarch64-linux-gnu \
  /usr/lib64 \
  /lib64 \
  /usr/lib \
  /lib; do
  [ -n "$libdir" ] && [ -d "$libdir" ] || continue
  LIBS="${LIBS:+$LIBS:}$libdir"
done

export LD_LIBRARY_PATH="${LIBS}${ORIG_LD_LIBRARY_PATH:+:$ORIG_LD_LIBRARY_PATH}"
[ -z "$ORIG_LD_PRELOAD" ] || export LD_PRELOAD="$ORIG_LD_PRELOAD"

# Audio plugin discovery for PipeWire / ALSA environments
for libdir in /usr/lib/aarch64-linux-gnu /usr/lib /usr/local/lib; do
  [ ! -d "$libdir/pipewire-0.3" ] || export PIPEWIRE_MODULE_DIR="$libdir/pipewire-0.3"
  [ ! -d "$libdir/spa-0.2" ] || export SPA_PLUGIN_DIR="$libdir/spa-0.2"
  [ ! -f "$libdir/alsa-lib/libasound_module_pcm_pipewire.so" ] || export ALSA_PLUGIN_DIR="$libdir/alsa-lib"
done

# 11. muOS Audio Initialization
if [ "$IS_MUOS" = 1 ] && [ -r "$GAMEDIR/tools/muos-audio.sh" ]; then
  . "$GAMEDIR/tools/muos-audio.sh"
  start_muos_audio
fi

# 12. Controls Configuration
[ -n "${sdl_controllerconfig:-}" ] && export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Start input service if supported by PortMaster
command -v pm_input_service >/dev/null 2>&1 && pm_input_service start || true

# Optional gptokeyb helper (for back -> esc mapping)
if [ -f "$GAMEDIR/joyride.gptk" ]; then
  if [ -n "${GPTOKEYB:-}" ]; then
    $GPTOKEYB "joyride-nextos" -c "$GAMEDIR/joyride.gptk" &
  elif command -v gptokeyb >/dev/null 2>&1; then
    gptokeyb "joyride-nextos" -c "$GAMEDIR/joyride.gptk" &
  fi
fi

# 13. CPU Performance Scaling (prevents stutter / frame drops)
if [ -d "/sys/devices/system/cpu/cpufreq" ]; then
  for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$gov" ] && echo "performance" | ${ESUDO:-} tee "$gov" >/dev/null 2>&1 || true
  done
fi

# 14. Launch Jetpack Joyride
ulimit -c 0
printf 'Launching joyride-nextos (GLES2, video=%s, audio=%s)...\n' "${SDL_VIDEODRIVER:-auto}" "${SDL_AUDIODRIVER:-auto}"
"$GAMEDIR/joyride-nextos" --gamedir "$GAMEDIR" --fullscreen & game_pid=$!
wait "$game_pid"
RESULT=$?
game_pid=""

printf '== Jetpack Joyride exited with code %s ==\n' "$RESULT"
exit "$RESULT"
