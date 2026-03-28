#!/bin/bash
# ================================================================
# musiccast_presets_fetcher.sh
# Pre-fetch presets for all known MusicCast players
# ================================================================
# Reads media_players.csv, curls getPresetInfo for each player in
# parallel, outputs JSON keyed by entity_id.
#
# Output: {"presets": {"media_player.bastu": [...], ...}}
# Used by: command_line sensor.musiccast_media_player_presets

export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

CSV_FILE="/config/packages/musiccast/data/media_players.csv"

if [ ! -f "$CSV_FILE" ]; then
  echo '{"presets":{}}'
  exit 0
fi

# ================================================================
# FETCH FUNCTION (exported for xargs subshells)
# ================================================================

# Argument: $1=ip|entity (pipe-separated)
# Uses exported TEMP_DIR for result files
fetch_presets() {
  local ip="${1%%|*}"
  local entity="${1#*|}"

  response=$(curl -s -m 3 --connect-timeout 2 \
    -H "X-AppName: MusicCast/1.0" \
    "http://$ip/YamahaExtendedControl/v1/netusb/getPresetInfo" 2>/dev/null | tr -d '\0')

  preset_info=$(echo "$response" | jq -c 'select(.response_code == 0) | .preset_info | map(select(.text != "")) | map({text: .text, input: .input})' 2>/dev/null)

  if [ -n "$preset_info" ] && [ "$preset_info" != "null" ]; then
    # Entity IDs (media_player.foo) are safe as filenames after replacing dots
    filename=$(echo "$entity" | tr '.' '_')
    echo "$entity|$preset_info" > "$TEMP_DIR/$filename"
  fi
}

export -f fetch_presets

# ================================================================
# PARALLEL FETCH
# ================================================================

TEMP_DIR=$(mktemp -d)
export TEMP_DIR

# Read CSV, skip comments / blank lines / unmatched (0.0.0.0) entries
# Pass ip|entity pairs to xargs for parallel curl (-P 20)
while IFS='=' read -r ip entity; do
  case "$ip" in
    \#*|'') continue ;;   # comment or blank line
    0.0.0.0) continue ;;  # unmatched entity from network scan
  esac
  [ -z "$entity" ] && continue
  echo "$ip|$entity"
done < "$CSV_FILE" | xargs -P 20 -I {} bash -c 'fetch_presets "{}"'

# ================================================================
# ASSEMBLE RESULTS
# ================================================================

RESULT='{}'

for result_file in "$TEMP_DIR"/*; do
  [ -f "$result_file" ] || continue
  line=$(cat "$result_file")
  entity="${line%%|*}"
  preset_json="${line#*|}"
  RESULT=$(printf '%s' "$RESULT" | jq --arg e "$entity" --argjson p "$preset_json" '. + {($e): $p}')
done

printf '{"presets":%s}\n' "$RESULT"

rm -rf "$TEMP_DIR"