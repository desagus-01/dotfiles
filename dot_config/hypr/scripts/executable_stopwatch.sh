#!/usr/bin/env bash

set -euo pipefail

WINDOW_CLASS="com.gus.termdown_stopwatch"
DEFAULT_CORNER="top-right"
WINDOW_COLUMNS="${TERMDOWN_STOPWATCH_COLUMNS:-30}"
WINDOW_ROWS="${TERMDOWN_STOPWATCH_ROWS:-7}"
WINDOW_WIDTH="${TERMDOWN_STOPWATCH_WIDTH:-300}"
WINDOW_HEIGHT="${TERMDOWN_STOPWATCH_HEIGHT:-140}"
WINDOW_FONT_SIZE="${TERMDOWN_STOPWATCH_FONT_SIZE:-15}"
WINDOW_MARGIN="${TERMDOWN_STOPWATCH_MARGIN:-16}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
CORNER_FILE="$STATE_DIR/termdown-stopwatch-corner"

usage() {
	cat <<EOF
Usage: $(basename "$0") [corner|position|move|close|TIMESPEC...]

No arguments opens a rofi prompt:
  - blank/stopwatch starts stopwatch mode
  - 10m, 1h 5m, 12:00, etc. starts timer mode
  - then choose the title text shown above the time

Commands:
  corner, position  Choose the corner and move the existing timer if open
  move              Re-apply the saved corner to the existing timer
  close             Close the existing timer window

Environment:
  TERMDOWN_STOPWATCH_COLUMNS    Ghostty terminal columns, default: $WINDOW_COLUMNS
  TERMDOWN_STOPWATCH_ROWS       Ghostty terminal rows, default: $WINDOW_ROWS
  TERMDOWN_STOPWATCH_WIDTH      Output window width, default: $WINDOW_WIDTH
  TERMDOWN_STOPWATCH_HEIGHT     Output window height, default: $WINDOW_HEIGHT
  TERMDOWN_STOPWATCH_FONT_SIZE  Ghostty font size, default: $WINDOW_FONT_SIZE
EOF
}

valid_corner() {
	case "${1:-}" in
		top-left | top-right | bottom-left | bottom-right) return 0 ;;
		*) return 1 ;;
	esac
}

read_corner() {
	local corner
	corner="$(cat "$CORNER_FILE" 2>/dev/null || true)"

	if valid_corner "$corner"; then
		printf '%s\n' "$corner"
	else
		printf '%s\n' "$DEFAULT_CORNER"
	fi
}

write_corner() {
	local corner="$1"

	valid_corner "$corner" || return 1
	mkdir -p "$STATE_DIR"
	printf '%s\n' "$corner" >"$CORNER_FILE"
}

notify_error() {
	local message="$1"

	if command -v notify-send >/dev/null 2>&1; then
		notify-send "Termdown" "$message"
	else
		printf 'Termdown: %s\n' "$message" >&2
	fi
}

require_command() {
	local command_name="$1"

	if ! command -v "$command_name" >/dev/null 2>&1; then
		notify_error "Missing dependency: $command_name"
		exit 1
	fi
}

rofi_dmenu() {
	local prompt="$1"
	shift

	rofi -dmenu -replace -i -no-show-icons -width 35 -p "$prompt" "$@"
}

prompt_timespec() {
	local choice

	if ! command -v rofi >/dev/null 2>&1; then
		printf '\n'
		return 0
	fi

	choice="$({
		printf 'stopwatch\n'
		printf '5m\n'
		printf '10m\n'
		printf '25m\n'
		printf '50m\n'
		printf '1h\n'
	} | rofi_dmenu "Timer" -l 6 -mesg "Blank or 'stopwatch' = stopwatch. Type e.g. 90, 10m, 1h 5m, 12:00")" || exit 0

	case "$choice" in
		"" | stopwatch | Stopwatch) printf '\n' ;;
		*) printf '%s\n' "$choice" ;;
	esac
}

prompt_title() {
	local default_title="$1"
	local choice

	if ! command -v rofi >/dev/null 2>&1; then
		printf '%s\n' "$default_title"
		return 0
	fi

	choice="$({
		printf '%s\n' "$default_title"
		printf 'Focus\n'
		printf 'Break\n'
		printf 'Study\n'
		printf 'Workout\n'
	} | rofi_dmenu "Timer text" -l 5 -mesg "Blank = $default_title. Type custom text.")" || exit 0

	if [[ -n "$choice" ]]; then
		printf '%s\n' "$choice"
	else
		printf '%s\n' "$default_title"
	fi
}

choose_corner() {
	local current choice

	if ! command -v rofi >/dev/null 2>&1; then
		write_corner "$DEFAULT_CORNER"
		return 0
	fi

	current="$(read_corner)"
	choice="$(printf 'top-left\ntop-right\nbottom-left\nbottom-right\n' | rofi_dmenu "Timer corner" -l 4 -select "$current")" || exit 0

	if ! valid_corner "$choice"; then
		notify_error "Invalid corner: $choice"
		exit 1
	fi

	write_corner "$choice"
	position_existing || true
}

get_addresses() {
	hyprctl clients -j | jq -r --arg class "$WINDOW_CLASS" '.[] | select(.class == $class) | .address'
}

get_first_address() {
	get_addresses | head -n 1
}

get_window_field() {
	local address="$1"
	local field="$2"

	hyprctl clients -j | jq -r --arg address "$address" --arg field "$field" \
		'.[] | select(.address == $address) | .[$field] // empty' | head -n 1
}

get_window_size() {
	local address="$1"

	hyprctl clients -j | jq -r --arg address "$address" \
		'.[] | select(.address == $address) | [.size[0], .size[1]] | @tsv' | head -n 1
}

monitor_geometry() {
	local monitor_id="$1"

	hyprctl monitors -j | jq -r --arg id "$monitor_id" '
		(map(select((.id | tostring) == $id))[0] // map(select(.focused == true))[0] // .[0]) as $m
		| ($m.scale // 1) as $scale
		| [
			($m.x // 0 | floor),
			($m.y // 0 | floor),
			(($m.width / $scale) | floor),
			(($m.height / $scale) | floor),
			($m.reserved[0] // 0 | floor),
			($m.reserved[1] // 0 | floor),
			($m.reserved[2] // 0 | floor),
			($m.reserved[3] // 0 | floor)
		] | @tsv'
}

dispatch_window() {
	local lua="$1"

	hyprctl dispatch "$lua" >/dev/null
}

ensure_window_properties() {
	local address="$1"
	local pinned

	dispatch_window "hl.dsp.window.float({ window = \"address:$address\", action = \"on\" })"

	pinned="$(get_window_field "$address" pinned)"
	if [[ "$pinned" != "true" ]]; then
		dispatch_window "hl.dsp.window.pin({ window = \"address:$address\" })"
	fi

	dispatch_window "hl.dsp.window.resize({ window = \"address:$address\", x = $WINDOW_WIDTH, y = $WINDOW_HEIGHT, exact = true })"
}

position_address() {
	local address="$1"
	local monitor_id geometry corner
	local monitor_x monitor_y monitor_width monitor_height reserved_left reserved_top reserved_right reserved_bottom
	local actual_width actual_height
	local x y min_x min_y

	[[ -n "$address" ]] || return 1
	ensure_window_properties "$address"
	read -r actual_width actual_height <<<"$(get_window_size "$address")"

	actual_width="${actual_width:-$WINDOW_WIDTH}"
	actual_height="${actual_height:-$WINDOW_HEIGHT}"

	if ((actual_width < WINDOW_WIDTH)); then
		actual_width="$WINDOW_WIDTH"
	fi

	if ((actual_height < WINDOW_HEIGHT)); then
		actual_height="$WINDOW_HEIGHT"
	fi

	monitor_id="$(get_window_field "$address" monitor)"
	geometry="$(monitor_geometry "$monitor_id")"
	read -r monitor_x monitor_y monitor_width monitor_height reserved_left reserved_top reserved_right reserved_bottom <<<"$geometry"

	corner="$(read_corner)"
	case "$corner" in
		top-left)
			x=$((monitor_x + reserved_left + WINDOW_MARGIN))
			y=$((monitor_y + reserved_top + WINDOW_MARGIN))
			;;
		top-right)
			x=$((monitor_x + monitor_width - reserved_right - actual_width - WINDOW_MARGIN))
			y=$((monitor_y + reserved_top + WINDOW_MARGIN))
			;;
		bottom-left)
			x=$((monitor_x + reserved_left + WINDOW_MARGIN))
			y=$((monitor_y + monitor_height - reserved_bottom - actual_height - WINDOW_MARGIN))
			;;
		bottom-right)
			x=$((monitor_x + monitor_width - reserved_right - actual_width - WINDOW_MARGIN))
			y=$((monitor_y + monitor_height - reserved_bottom - actual_height - WINDOW_MARGIN))
			;;
	esac

	min_x=$((monitor_x + reserved_left + WINDOW_MARGIN))
	min_y=$((monitor_y + reserved_top + WINDOW_MARGIN))

	if ((x < min_x)); then
		x="$min_x"
	fi

	if ((y < min_y)); then
		y="$min_y"
	fi

	dispatch_window "hl.dsp.window.move({ window = \"address:$address\", x = $x, y = $y, exact = true })"
}

position_existing() {
	local address

	address="$(get_first_address)"
	[[ -n "$address" ]] || return 1
	position_address "$address"
}

close_existing() {
	local address

	while read -r address; do
		[[ -n "$address" ]] || continue
		dispatch_window "hl.dsp.window.close({ window = \"address:$address\" })"
	done < <(get_addresses)
}

wait_for_no_window() {
	local _

	for _ in {1..20}; do
		[[ -z "$(get_first_address)" ]] && return 0
		sleep 0.05
	done
}

wait_for_window() {
	local address _

	for _ in {1..50}; do
		address="$(get_first_address)"
		if [[ -n "$address" ]]; then
			printf '%s\n' "$address"
			return 0
		fi
		sleep 0.1
	done

	return 1
}

terminal_command() {
	cat "$HOME/.config/ml4w/settings/terminal.sh" 2>/dev/null || printf 'ghostty\n'
}

launch_timer() {
	local timespec="$1"
	local title="$2"
	local terminal address
	local -a termdown_args

	require_command hyprctl
	require_command jq
	require_command termdown

	terminal="$(terminal_command)"

	if [[ -z "$title" ]]; then
		title="Stopwatch"
		if [[ -n "$timespec" ]]; then
			title="Timer"
		fi
	fi

	termdown_args=(--no-art --title "$title")

	if [[ -n "$timespec" ]]; then
		termdown_args=(--no-art --title "$title" "$timespec")
	fi

	close_existing
	wait_for_no_window || true

	if [[ "$terminal" == *ghostty* ]]; then
		# Intentionally allow the terminal setting to contain arguments.
		# shellcheck disable=SC2086
		$terminal --gtk-single-instance=false --class="$WINDOW_CLASS" --font-size="$WINDOW_FONT_SIZE" --window-width="$WINDOW_COLUMNS" --window-height="$WINDOW_ROWS" -e termdown "${termdown_args[@]}" >/dev/null 2>&1 &
	else
		# Intentionally allow the terminal setting to contain arguments.
		# shellcheck disable=SC2086
		$terminal --class "$WINDOW_CLASS" -e termdown "${termdown_args[@]}" >/dev/null 2>&1 &
	fi

	address="$(wait_for_window)" || {
		notify_error "Could not find the termdown window after launching"
		exit 1
	}

	position_address "$address"
	sleep 0.15
	position_address "$address"
}

main() {
	local command="${1:-}"
	local default_title timespec title

	case "$command" in
		-h | --help)
			usage
			;;
		corner | position)
			require_command hyprctl
			require_command jq
			choose_corner
			;;
		move | reposition)
			require_command hyprctl
			require_command jq
			position_existing || true
			;;
		close)
			require_command hyprctl
			require_command jq
			close_existing
			;;
		*)
			if (($# > 0)); then
				timespec="$*"
				title="${TERMDOWN_STOPWATCH_TITLE:-}"
			else
				timespec="$(prompt_timespec)"
				default_title="Stopwatch"
				if [[ -n "$timespec" ]]; then
					default_title="Timer"
				fi
				title="$(prompt_title "$default_title")"
			fi

			launch_timer "$timespec" "$title"
			;;
	esac
}

main "$@"
