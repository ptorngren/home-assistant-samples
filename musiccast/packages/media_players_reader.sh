#!/bin/bash

# ================================================================
# MusicCast Entity Mappings Reader
# ================================================================
# Reads CSV file with entity-to-IP mappings and outputs JSON
# CSV format: IP=entity_id (e.g., 192.168.1.11=media_player.kok)
# Unmatched: 0.0.0.0=entity_id
#
# Output: JSON with matched and unmatched arrays
# Used by: sensor.musiccast_entity_mappings (command_line sensor)

CSV_FILE="/config/packages/musiccast/data/media_players.csv"

MATCHED="[]"
UNMATCHED="[]"

# Read CSV file if it exists
if [ -f "$CSV_FILE" ]; then
  MATCHED_ARRAY=()
  UNMATCHED_ARRAY=()

  while IFS='=' read -r ip entity_id; do
    if [ -z "$ip" ] || [ -z "$entity_id" ]; then
      continue
    fi

    if [ "$ip" = "0.0.0.0" ]; then
      # Unmatched entity
      UNMATCHED_ARRAY+=("{\"entity\":\"$entity_id\"}")
    else
      # Matched entity
      MATCHED_ARRAY+=("{\"ip\":\"$ip\",\"entity\":\"$entity_id\"}")
    fi
  done < "$CSV_FILE"

  # Build JSON arrays
  if [ ${#MATCHED_ARRAY[@]} -gt 0 ]; then
    MATCHED="[$(IFS=,; echo "${MATCHED_ARRAY[*]}")]"
  fi

  if [ ${#UNMATCHED_ARRAY[@]} -gt 0 ]; then
    UNMATCHED="[$(IFS=,; echo "${UNMATCHED_ARRAY[*]}")]"
  fi
fi

# Output JSON with matched and unmatched arrays
echo "{\"matched\":$MATCHED,\"unmatched\":$UNMATCHED}"