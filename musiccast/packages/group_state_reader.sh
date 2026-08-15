#!/bin/bash

# ================================================================
# MusicCast Group State Probe
# ================================================================
# Reads dist/getDistributionInfo from each requested player and reports the
# role and group id the DEVICE holds. Neither is visible to Home Assistant:
# group_members describes what HA believes, while a player can hold a group id
# belonging to a group that no longer exists, and refuse every attempt to
# regroup it until it is restarted.
#
# Usage: ./group_state_reader.sh <csv_file> <entities_json_b64>
# Output: [{"entity":"media_player.x","role":"server|client|none","group_id":"0..0"}, ...]
#
# Players that do not answer are simply absent from the output: a probe that
# fails must not be able to block playback.

CSV_FILE="${1}"
ENTITIES_JSON_B64="${2}"

# Set explicit PATH for HA's limited shell environment
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

if [ -n "$ENTITIES_JSON_B64" ]; then
  ENTITIES_JSON=$(echo "$ENTITIES_JSON_B64" | base64 -d 2>/dev/null || echo "[]")
else
  ENTITIES_JSON="[]"
fi

if [ ! -f "$CSV_FILE" ]; then
  echo '[]'
  exit 0
fi

# ================================================================
# PROBE FUNCTION (exported for xargs subshells)
# ================================================================

# Argument: $1=ip|entity (pipe-separated). Uses exported TEMP_DIR for results.
probe_group_state() {
  local ip="${1%%|*}"
  local entity="${1#*|}"

  response=$(curl -s -m 2 --connect-timeout 1 \
    -H "X-AppName: MusicCast/1.0" \
    "http://$ip/YamahaExtendedControl/v1/dist/getDistributionInfo" 2>/dev/null | tr -d '\0')

  state=$(echo "$response" | jq -c --arg e "$entity" \
    'select(.response_code == 0) | {entity: $e, role: (.role // "unknown"), group_id: (.group_id // "")}' 2>/dev/null)

  if [ -n "$state" ] && [ "$state" != "null" ]; then
    filename=$(echo "$entity" | tr '.' '_')
    echo "$state" > "$TEMP_DIR/$filename"
  fi
}

export -f probe_group_state

# ================================================================
# PARALLEL PROBE
# ================================================================

TEMP_DIR=$(mktemp -d)
export TEMP_DIR

# Read CSV, keep only the entities asked for, hand ip|entity pairs to xargs.
while IFS='=' read -r ip entity; do
  case "$ip" in
    \#*|'') continue ;;   # comment or blank line
    0.0.0.0) continue ;;  # unmatched entity from network scan
  esac
  [ -z "$entity" ] && continue
  echo "$ENTITIES_JSON" | jq -e --arg e "$entity" 'index($e) != null' >/dev/null 2>&1 || continue
  echo "$ip|$entity"
done < "$CSV_FILE" | xargs -r -P 10 -I {} bash -c 'probe_group_state "{}"'

cat "$TEMP_DIR"/* 2>/dev/null | jq -s -c '.'
rm -rf "$TEMP_DIR"
