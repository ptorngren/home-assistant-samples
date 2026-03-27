#!/bin/bash

# ================================================================
# MusicCast Network Discovery Script
# ================================================================
# Scans IP range for Yamaha MusicCast devices
# Queries each device via HTTP for network_name and ip_address
# Returns JSON: {devices: [{network_name, ip}, ...], errors: [...]}
#
# Usage: ./media_players_writer.sh <start_ip> <end_ip>
# Example: ./media_players_writer.sh 192.168.1.11 192.168.1.13
#          (scans .11, .12, .13)

START_IP="${1}"
END_IP="${2}"
ENTITIES_JSON_B64="${3}"
OUTPUT_CSV="${4}"
OUTPUT_INCLUDE="${5}"

# Set explicit PATH for HA's limited shell environment
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# Decode base64-encoded entities JSON
if [ -n "$ENTITIES_JSON_B64" ]; then
  ENTITIES_JSON=$(echo "$ENTITIES_JSON_B64" | base64 -d 2>/dev/null || echo "[]")
else
  ENTITIES_JSON="[]"
fi

# ================================================================
# INPUT VALIDATION
# ================================================================

if [ -z "$START_IP" ] || [ -z "$END_IP" ]; then
  echo '{"devices":[],"errors":["Usage: media_players_writer.sh <start_ip> <end_ip>"]}'
  exit 1
fi

# Extract subnet and start/end octets
SUBNET=$(echo "$START_IP" | cut -d. -f1-3)
START_OCTET=$(echo "$START_IP" | cut -d. -f4)
END_OCTET=$(echo "$END_IP" | cut -d. -f4)

# ================================================================
# HELPER FUNCTIONS
# ================================================================

# Query device for network info
# Arguments: $1=ip, $2=temp_dir
# Writes to temp_dir/ip if successful, returns exit code
query_device() {
  local ip="$1"
  local temp_dir="$2"

  # Optimized curl: strict timeouts for local LAN
  response=$(curl -s -m 2 --connect-timeout 1 \
    -H "X-AppName: MusicCast/1.0" \
    "http://$ip/YamahaExtendedControl/v1/system/getNetworkStatus" 2>/dev/null | tr -d '\0')

  # Single jq call: validate response_code == 0 and extract data simultaneously
  parsed=$(echo "$response" | jq -r 'select(.response_code == 0) | "\(.network_name)|\(.ip_address)"' 2>/dev/null)

  if [ -n "$parsed" ]; then
    echo "$parsed" > "$temp_dir/$ip"
    return 0
  fi
  return 1
}

# Export function for xargs to access
export -f query_device

# ================================================================
# MAIN DISCOVERY LOGIC (CONTROLLED BATCHING)
# ================================================================

DEVICES_JSON="[]"

echo "Scanning $SUBNET.$START_OCTET to $SUBNET.$END_OCTET for MusicCast devices..."

# Create temp directory for results (in RAM on RPi)
TEMP_DIR=$(mktemp -d)

# Controlled batching: xargs -P 30 ensures exactly 30 parallel jobs at a time
seq "$START_OCTET" "$END_OCTET" | sed "s/^/$SUBNET./" | xargs -P 30 -I {} bash -c "query_device {} $TEMP_DIR"

# Process results from temp files (now only contain valid data)
for result_file in "$TEMP_DIR"/*; do
  if [ -f "$result_file" ]; then
    device_info=$(cat "$result_file")
    network_name=$(echo "$device_info" | cut -d'|' -f1)
    ip_address=$(echo "$device_info" | cut -d'|' -f2)

    # Build JSON entry
    entry="{\"network_name\":\"$network_name\",\"ip\":\"$ip_address\"}"
    DEVICES_JSON=$(echo "$DEVICES_JSON" | jq --argjson entry "$entry" '. += [$entry]')
  fi
done

echo ""
echo "Scan complete: Found $(echo "$DEVICES_JSON" | jq 'length') devices"
echo ""

# ================================================================
# MATCH ENTITIES TO DEVICES & WRITE CSV
# ================================================================

if [ -n "$OUTPUT_CSV" ] && [ "$ENTITIES_JSON" != "[]" ]; then
  # Parse entities and devices
  MATCHED_COUNT=0
  UNMATCHED_COUNT=0
  CSV_CONTENT=""
  MATCHED_ENTITIES=""

  # Iterate through entities and try to match with discovered devices
  # Use Here-String (<<<) instead of pipe (|) to keep loop in main shell and preserve CSV_CONTENT
  while IFS='|' read -r entity_id friendly_name; do
    # Trim whitespace from friendly name (integration may add/remove spaces vs device network_name)
    fn_trimmed=$(echo "$friendly_name" | xargs)

    # Search for matching device (trim network_name to handle trailing spaces)
    matched_ip=$(echo "$DEVICES_JSON" | jq -r --arg fn "$fn_trimmed" '.[] | select((.network_name | gsub("^\\s+|\\s+$";"")) == $fn) | .ip' | head -1)

    if [ -n "$matched_ip" ] && [ "$matched_ip" != "null" ]; then
      CSV_CONTENT="${CSV_CONTENT}${matched_ip}=${entity_id}"$'\n'
      MATCHED_ENTITIES="${MATCHED_ENTITIES}${entity_id}"$'\n'
      ((MATCHED_COUNT++))
    else
      # Mark unmatched entity with dummy IP (0.0.0.0 = not resolved)
      CSV_CONTENT="${CSV_CONTENT}0.0.0.0=${entity_id}"$'\n'
      ((UNMATCHED_COUNT++))
    fi
  done <<< "$(echo "$ENTITIES_JSON" | jq -r '.[] | "\(.entity_id)|\(.friendly_name)"')"

  # Write CSV file (includes both matched and unmatched)
  if [ -n "$CSV_CONTENT" ]; then
    # Ensure directory exists
    mkdir -p "$(dirname "$OUTPUT_CSV")"
    # Sort by IP in ascending order (version sort handles IP addresses correctly), then by entity_id
    # Matched entries (with IPs) sort before unmatched (empty IPs)
    printf '%s' "$CSV_CONTENT" | sort -V -t'=' -k1,1 -k2,2 > "$OUTPUT_CSV"
    echo "Wrote $MATCHED_COUNT matched entities + $UNMATCHED_COUNT unmatched to $OUTPUT_CSV"
  fi
fi

# ================================================================
# WRITE PLAYER LIST INCLUDE FILE
# ================================================================

if [ -n "$OUTPUT_INCLUDE" ] && [ "$ENTITIES_JSON" != "[]" ]; then
  mkdir -p "$(dirname "$OUTPUT_INCLUDE")"

  # Read exclusion list (same directory as include, .exclude extension)
  EXCLUDE_FILE="${OUTPUT_INCLUDE%.include}.exclude"
  EXCLUDED=""
  if [ -f "$EXCLUDE_FILE" ]; then
    # Strip comments and blank lines
    EXCLUDED=$(grep -v '^\s*#' "$EXCLUDE_FILE" | grep -v '^\s*$' || true)
  fi

  # Filter out excluded entities before writing
  FILTERED_JSON="$ENTITIES_JSON"
  if [ -n "$EXCLUDED" ]; then
    while IFS= read -r excl_entity; do
      FILTERED_JSON=$(echo "$FILTERED_JSON" | jq --arg e "$excl_entity" '[.[] | select(.entity_id != $e)]')
    done <<< "$EXCLUDED"
  fi

  {
    echo "# MusicCast player list — single source of truth for group.musiccast_players and automation triggers"
    echo "# Edit this file and reload HA (Groups + Automations) when players are added or removed"
    echo "# NOTE: .include suffix (not .yaml) prevents HA package loader from treating this as a package definition"
    echo "# Auto-generated by musiccast_network_scan — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "$FILTERED_JSON" | jq -r '.[] | "- " + .entity_id'
  } > "$OUTPUT_INCLUDE"
  EXCLUDED_COUNT=$(echo "$ENTITIES_JSON" | jq 'length')
  FILTERED_COUNT=$(echo "$FILTERED_JSON" | jq 'length')
  echo "Wrote $FILTERED_COUNT players to $OUTPUT_INCLUDE ($(($EXCLUDED_COUNT - $FILTERED_COUNT)) excluded)"
fi

# ================================================================
# OUTPUT RESULTS
# ================================================================

echo "{\"devices\":$DEVICES_JSON,\"errors\":[]}"

# Force OS to flush all filesystem buffers
sync

# Clean up temp directory
rm -rf "$TEMP_DIR"