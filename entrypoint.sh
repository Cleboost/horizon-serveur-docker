#!/bin/sh
# First start: horizon-server init via HORIZON_* ; then config set from env.
# Init flags match https://github.com/horizon-rust/horizon/blob/main/docs/hosting.md
set -eu

run_init() {
  set -- horizon-server init --yes --eula

  if [ -n "${HORIZON_WORLD:-}" ]; then
    set -- "$@" --world "$HORIZON_WORLD"
  fi
  if [ -n "${HORIZON_SEED:-}" ]; then
    set -- "$@" --seed "$HORIZON_SEED"
  fi
  if [ -n "${HORIZON_PORT:-}" ]; then
    set -- "$@" --port "$HORIZON_PORT"
  fi

  case "${HORIZON_WHITELIST:-true}" in
    false|0|no|off|FALSE|NO|OFF) set -- "$@" --no-whitelist ;;
    *) set -- "$@" --whitelist ;;
  esac

  case "${HORIZON_ONLINE:-true}" in
    false|0|no|off|FALSE|NO|OFF) set -- "$@" --offline ;;
  esac

  if [ -n "${HORIZON_PLAYERS:-}" ]; then
    old_ifs=${IFS-}
    IFS=','
    for p in $HORIZON_PLAYERS; do
      p=$(printf '%s' "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$p" ]; then
        set -- "$@" --player "$p"
      fi
    done
    IFS=$old_ifs
  fi

  if [ -n "${HORIZON_OP:-}" ]; then
    old_ifs=${IFS-}
    IFS=','
    for o in $HORIZON_OP; do
      o=$(printf '%s' "$o" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$o" ]; then
        set -- "$@" --op "$o"
      fi
    done
    IFS=$old_ifs
  fi

  "$@" || exit 1
}

apply_config() {
  set --

  if [ -n "${HORIZON_PORT:-}" ]; then
    set -- "$@" "server.port=${HORIZON_PORT}"
  fi
  if [ -n "${HORIZON_MOTD:-}" ]; then
    set -- "$@" "server.motd=${HORIZON_MOTD}"
  fi
  if [ -n "${HORIZON_MAX_PLAYERS:-}" ]; then
    set -- "$@" "server.max_players=${HORIZON_MAX_PLAYERS}"
  fi
  if [ -n "${HORIZON_BIND:-}" ]; then
    set -- "$@" "server.bind=${HORIZON_BIND}"
  fi
  if [ -n "${HORIZON_VIEW_DISTANCE:-}" ]; then
    set -- "$@" "server.view_distance=${HORIZON_VIEW_DISTANCE}"
  fi
  if [ -n "${HORIZON_SIMULATION_DISTANCE:-}" ]; then
    set -- "$@" "server.simulation_distance=${HORIZON_SIMULATION_DISTANCE}"
  fi

  case "${HORIZON_WHITELIST:-true}" in
    false|0|no|off|FALSE|NO|OFF) set -- "$@" "server.whitelist=false" ;;
    *) set -- "$@" "server.whitelist=true" ;;
  esac

  case "${HORIZON_ONLINE:-true}" in
    false|0|no|off|FALSE|NO|OFF) set -- "$@" "server.online_mode=false" ;;
    *) set -- "$@" "server.online_mode=true" ;;
  esac

  if [ -n "${HORIZON_ENFORCE_WHITELIST:-}" ]; then
    set -- "$@" "server.enforce_whitelist=${HORIZON_ENFORCE_WHITELIST}"
  fi
  if [ -n "${HORIZON_GAME_MODE:-}" ]; then
    set -- "$@" "world.game_mode=${HORIZON_GAME_MODE}"
  fi
  if [ -n "${HORIZON_DIFFICULTY:-}" ]; then
    set -- "$@" "world.difficulty=${HORIZON_DIFFICULTY}"
  fi
  if [ -n "${HORIZON_ENGINE_LOW_MEMORY:-}" ]; then
    set -- "$@" "engine.low_memory=${HORIZON_ENGINE_LOW_MEMORY}"
  fi
  if [ -n "${HORIZON_BACKUPS_EVERY:-}" ]; then
    set -- "$@" "backups.every=${HORIZON_BACKUPS_EVERY}"
  fi
  if [ -n "${HORIZON_BACKUPS_KEEP:-}" ]; then
    set -- "$@" "backups.keep=${HORIZON_BACKUPS_KEEP}"
  fi

  case "${HORIZON_PANEL:-false}" in
    true|1|yes|on|TRUE|YES|ON)
      panel_bind="${HORIZON_PANEL_BIND:-0.0.0.0:8130}"
      panel_public="${HORIZON_PANEL_ALLOW_PUBLIC:-true}"
      set -- "$@" "panel.bind=${panel_bind}" "panel.allow_public=${panel_public}"
      echo "horizon-server: panel on ${panel_bind} (allow_public=${panel_public})"
      echo "horizon-server: login link → docker exec … horizon-server panel"
      ;;
    *)
      set -- "$@" "panel.bind="
      ;;
  esac

  if [ -n "${HORIZON_CONFIG:-}" ]; then
    # shellcheck disable=SC2086
    set -- "$@" ${HORIZON_CONFIG}
  fi

  if [ "$#" -gt 0 ]; then
    horizon-server config set "$@" || exit 1
  fi
}

if [ ! -f server.toml ]; then
  if [ "${HORIZON_EULA:-}" != "true" ]; then
    echo "horizon-server: set HORIZON_EULA=true to accept https://aka.ms/MinecraftEULA" >&2
    exit 1
  fi
  run_init
fi

apply_config

exec horizon-server run
