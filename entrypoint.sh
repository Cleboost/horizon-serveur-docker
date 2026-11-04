#!/bin/sh
# Init (HORIZON_EULA, HORIZON_WORLD, …) puis config server.toml via env (horizon-server config set).
# Panel : HORIZON_PANEL=true + port publié (voir docs Horizon hosting § Web panel).
set -eu

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
      echo "horizon-server: panel actif sur ${panel_bind} (allow_public=${panel_public})"
      echo "horizon-server: lien login → horizon-server panel (dans le conteneur)"
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
    echo "horizon-server: définir HORIZON_EULA=true pour accepter https://aka.ms/MinecraftEULA" >&2
    exit 1
  fi
  horizon-server init --yes || exit 1
fi

apply_config

exec horizon-server run
