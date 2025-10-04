#!/usr/bin/env sh
#!/usr/bin/env sh
set +e

usage="Usage: $0 [+] or [-]"

if [ "$#" -ne 1 ]; then
  echo "No direction parameter provided"
  echo "$usage"
  exit 1
fi

arg="$1"
if [ "$arg" = "help" ] || [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
  echo "$usage"
  exit 0
fi
if [ "$arg" != "+" ] && [ "$arg" != "-" ]; then
  echo "Direction parameter must be '+' or '-'"
  echo "$usage"
  exit 1
fi
direction=$arg

monitor_data=$(hyprctl monitors -j)
focused_id=$(printf '%s' "$monitor_data" | jq -r '.[] | select(.focused == true) | .id')

if [ "$focused_id" -eq 0 ]; then
  focused_id=$((focused_id + 2))
fi

echo "focused_id: $focused_id"
ddcutil --sleep-multiplier=.2 --display="$focused_id" setvcp 10 "$direction" 15
