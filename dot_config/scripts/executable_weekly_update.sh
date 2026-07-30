
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="weekly-update"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/${APP_NAME}"
STAMP_FILE="${STATE_DIR}/last_success_epoch"
LOCK_FILE="${STATE_DIR}/lock"

mkdir -p "$STATE_DIR"

now_epoch() { date +%s; }

# Print whole days since last successful run (or huge number if never ran)
days_since_last() {
  if [[ ! -f "$STAMP_FILE" ]]; then
    echo 999999
    return 0
  fi
  local last
  last="$(<"$STAMP_FILE")"
  local now
  now="$(now_epoch)"
  # integer division: seconds -> days
  echo $(( (now - last) / 86400 ))
}

usage() {
  cat <<'EOF'
Usage:
  weekly-update run [--force] [--noconfirm]
  weekly-update status [--waybar]

Commands:
  run        Runs: mirrors -> keyrings -> shelly upgrade -> clean cache -> stamp time
  status     Shows days since last successful run (and optionally Waybar JSON)

Options:
  --force       Run even if < 7 days since last success
  --noconfirm   Non-interactive (passes --noconfirm to pacman and --no-confirm to shelly)
  --waybar      Output JSON for Waybar custom module
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 127
  }
}

cmd="${1:-}"
shift || true

FORCE=0
NOCONFIRM=0
WAYBAR=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    --noconfirm) NOCONFIRM=1 ;;
    --waybar) WAYBAR=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

case "$cmd" in
  run)
    need_cmd sudo
    need_cmd pacman
    need_cmd shelly
    need_cmd cachyos-rate-mirrors
    need_cmd flock

    # Only run weekly unless forced
    DAYS="$(days_since_last)"
    if [[ "$FORCE" -ne 1 && "$DAYS" -lt 7 ]]; then
      echo "Not due yet: ${DAYS} day(s) since last successful update."
      exit 0
    fi

    # Lock to avoid double-runs (Waybar clicks, hotkeys, etc.)
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      echo "Another ${APP_NAME} run is already in progress." >&2
      exit 1
    fi

    PACMAN_FLAGS=()
    SHELLY_FLAGS=()
    if [[ "$NOCONFIRM" -eq 1 ]]; then
      PACMAN_FLAGS+=(--noconfirm)
      SHELLY_FLAGS+=(--no-confirm)
    fi

    echo "==> [1/4] Updating CachyOS mirror ranking…"
    sudo cachyos-rate-mirrors

    echo "==> [2/4] Updating keyrings first…"
    # Keyrings first helps avoid signature/PGP drama
    sudo pacman -Sy --needed "${PACMAN_FLAGS[@]}" archlinux-keyring cachyos-keyring

    echo "==> [3/4] Full system upgrade via shelly…"
    shelly news "${SHELLY_FLAGS[@]}"
    shelly "${SHELLY_FLAGS[@]}"

    echo "==> [4/4] Cleaning caches…"
    shelly cache-clean "${SHELLY_FLAGS[@]}" || true

    echo "==> Writing success stamp…"
    now_epoch > "$STAMP_FILE"

    echo "Done. Last success: $(date -d "@$(<"$STAMP_FILE")")"
    ;;

  status)
    DAYS="$(days_since_last)"

    if [[ "$WAYBAR" -eq 1 ]]; then
      if [[ "$DAYS" -ge 7 ]]; then
        printf '{"text":"⬆ %sd","class":"updates","tooltip":"%s days since last successful update"}\n' \
          "$DAYS" "$DAYS"
      else
        printf '{"text":"","class":"noupdates","tooltip":"%s days since last successful update"}\n' \
          "$DAYS"
      fi
    else
      echo "$DAYS"
    fi
    ;;

  *)
    usage
    exit 2
    ;;
esac
