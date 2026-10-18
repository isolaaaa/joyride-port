#!/bin/bash
# muOS audio workaround based on Mikhail/Crescent adaptation.
audio_active=0; pw_running=0; wp_running=0; original_volume=""; volume_pid=""

hardware_mixer() {
  (unset ALSA_CONFIG_PATH ALSA_CARD; amixer "$@")
}

start_muos_audio() {
  [ "${IS_MUOS:-0}" = 1 ] || return 0
  audio_active=1
  command -v pgrep >/dev/null 2>&1 || { printf 'muOS: pgrep missing; skipping audio service management\n'; return 0; }
  pgrep -x pipewire >/dev/null 2>&1 && pw_running=1
  pgrep -x wireplumber >/dev/null 2>&1 && wp_running=1
  original_volume=$(hardware_mixer -c 0 get 'digital volume' 2>/dev/null | awk '/Mono:/ {print $2;exit}') || true

  [ "$wp_running" = 0 ] || pkill -TERM -x wireplumber 2>/dev/null || true
  [ "$pw_running" = 0 ] || pkill -TERM -x pipewire 2>/dev/null || true

  for ((n=0; n<30; n++)); do
    if ! pgrep -x pipewire >/dev/null 2>&1 && ! pgrep -x wireplumber >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  export SDL_AUDIODRIVER=alsa
  export SDL_AUDIODEV=joyride
  export ALSA_CONFIG_PATH="$GAMEDIR/alsa-joyride.conf"
  export ALSA_CARD=0

  if command -v python3 >/dev/null 2>&1 && command -v amixer >/dev/null 2>&1 && [ -f "$GAMEDIR/tools/volume-hook.py" ]; then
    python3 "$GAMEDIR/tools/volume-hook.py" &
    volume_pid=$!
  fi
  printf 'muOS direct ALSA: card=0 device=0 PipeWire=%s WirePlumber=%s volume=%s\n' "$pw_running" "$wp_running" "$original_volume"
}

restore_muos_audio() {
  [ "$audio_active" = 1 ] || return 0
  audio_active=0
  if [ -n "$volume_pid" ]; then
    kill -TERM "$volume_pid" 2>/dev/null || true
    wait "$volume_pid" 2>/dev/null || true
  fi

  # Keep game-specific ALSA overrides out of restarted desktop services
  if [ "$pw_running" = 1 ] && ! pgrep -x pipewire >/dev/null 2>&1; then
    (unset ALSA_CONFIG_PATH ALSA_CARD SDL_AUDIODEV SDL_AUDIODRIVER PIPEWIRE_MODULE_DIR SPA_PLUGIN_DIR ALSA_PLUGIN_DIR LD_LIBRARY_PATH; exec pipewire -c /opt/muos/share/conf/pipewire.conf) &
    sleep 1
  fi
  if [ "$wp_running" = 1 ] && ! pgrep -x wireplumber >/dev/null 2>&1; then
    (unset ALSA_CONFIG_PATH ALSA_CARD SDL_AUDIODEV SDL_AUDIODRIVER PIPEWIRE_MODULE_DIR SPA_PLUGIN_DIR ALSA_PLUGIN_DIR LD_LIBRARY_PATH; exec wireplumber) &
    sleep 1
  fi
  [ -z "$original_volume" ] || hardware_mixer -c 0 set 'digital volume' "$original_volume" 2>/dev/null || true
  printf 'muOS audio restored\n'
}
