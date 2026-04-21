#!/usr/bin/env bash
# git_sync_check.sh — notify when watched git repos are behind their remote.
# Add repos to the REPOS array below; ~ is supported in paths.
set -uo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION — add/remove repos here
# ---------------------------------------------------------------------------
REPOS=(
  "$HOME/.local/share/chezmoi"
)

# Minimum seconds between network checks (default: 3600 = 1 hour)
INTERVAL=${GIT_SYNC_CHECK_INTERVAL:-3600}

# ---------------------------------------------------------------------------
# State / lock
# ---------------------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/git-sync-check"
STAMP_FILE="${STATE_DIR}/last_run"
LOCK_FILE="${STATE_DIR}/lock"

mkdir -p "$STATE_DIR"

# ---- throttle: exit early if last run was recent enough ------------------
if [[ -f "$STAMP_FILE" ]]; then
  last=$(<"$STAMP_FILE")
  now=$(date +%s)
  if (( now - last < INTERVAL )); then
    exit 0
  fi
fi

# ---- lock: prevent concurrent runs (e.g. multiple terminals opening) -----
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Notification helper
# ---------------------------------------------------------------------------
notify() {
  local title="$1"
  local body="$2"
  if command -v notify-send &>/dev/null && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    notify-send --urgency=normal --icon=git "$title" "$body"
  else
    printf '\033[1;33m[git-sync-check]\033[0m %s: %s\n' "$title" "$body" >&2
  fi
}

# ---------------------------------------------------------------------------
# Per-repo check
# ---------------------------------------------------------------------------
check_repo() {
  local repo="$1"
  local name
  name=$(basename "$repo")

  # Must be a git repo
  if [[ ! -d "$repo/.git" ]]; then
    return 0
  fi

  # Fetch quietly; treat network failure as non-fatal
  if ! git -C "$repo" fetch --quiet --no-tags 2>/dev/null; then
    return 0
  fi

  # Skip if no upstream is configured
  if ! git -C "$repo" rev-parse '@{u}' &>/dev/null; then
    return 0
  fi

  local local_sha upstream_sha
  local_sha=$(git -C "$repo" rev-parse HEAD)
  upstream_sha=$(git -C "$repo" rev-parse '@{u}')

  if [[ "$local_sha" != "$upstream_sha" ]]; then
    local count
    count=$(git -C "$repo" rev-list --count HEAD.."@{u}")
    notify \
      "$name is out of sync" \
      "${repo/#$HOME/~} is $count commit(s) behind its remote."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
for repo in "${REPOS[@]}"; do
  check_repo "$repo"
done

# Stamp successful completion time
date +%s > "$STAMP_FILE"

