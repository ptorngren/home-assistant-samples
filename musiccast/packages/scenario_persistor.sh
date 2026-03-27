#!/bin/bash
# ----------------------------------------------------------------
# scenario_persistor.sh
# Helper script to Read/Write MusicCast volume presets
# ----------------------------------------------------------------

ACTION="$1"
SCENARIO="$2"
CONTENT="$3"

# Path configuration
BASE_DIR="/config/packages/musiccast/data"
FILE_PATH="${BASE_DIR}/scenario_${SCENARIO}.csv"

# Default volume for newly added players (HA scale 0.0–1.0)
DEFAULT_VOLUME=0.25

# Ensure directory exists
mkdir -p "$BASE_DIR"

case "$ACTION" in
    write)
        # Write content to file.
        # We use quotes around "$CONTENT" to preserve the newlines sent from HA.
        # TODO: Security hardening - pass data via stdin instead of command-line argument
        #       to safely handle special characters (quotes, etc.) in data
        #       See: packages/screensaver/bt_fingerprints_persistor.sh for safer pattern
        echo "$CONTENT" > "$FILE_PATH"
        ;;
        
    read)
        if [ -f "$FILE_PATH" ]; then
            awk -F: '
                BEGIN { printf "{" }
                {
                    # Only process lines that strictly have 2 fields (player:volume)
                    if (NF == 2) {
                        # If we have already printed a field, add a comma separator
                        if (found_first) printf ","

                        # Print "key":value
                        printf "\"%s\":%s", $1, $2
                        found_first = 1
                    }
                }
                END { printf "}" }
            ' "$FILE_PATH"
        else
            echo "{}"
        fi
        ;;

    players)
        # Return ordered JSON array of player entity IDs (first line = master)
        if [ -f "$FILE_PATH" ]; then
            awk -F: '
                BEGIN { printf "[" }
                NF == 2 {
                    if (found_first) printf ","
                    printf "\"%s\"", $1
                    found_first = 1
                }
                END { printf "]" }
            ' "$FILE_PATH"
        else
            echo "[]"
        fi
        ;;
        
    create)
        # create <name> <icon> <master_entity>
        # Derives scenario_id from display name, creates CSV + updates scenarios.json
        NAME="$2"
        ICON="$3"
        MASTER="$4"
        META_FILE="${BASE_DIR}/scenarios.json"

        # Generate scenario_id: strip diacritics, lowercase, spaces→underscores, keep only a-z0-9_
        SCENARIO_ID=$(python3 -c "
import unicodedata, re, sys
name = sys.argv[1]
normalized = unicodedata.normalize('NFD', name)
ascii_name = ''.join(c for c in normalized if unicodedata.category(c) != 'Mn')
with_underscores = re.sub(r'[\s\-]+', '_', ascii_name.lower())
print(re.sub(r'[^a-z0-9_]', '', with_underscores).strip('_'))
" "$NAME")

        # Create CSV with master at volume 50 if it does not already exist
        CSV_PATH="${BASE_DIR}/scenario_${SCENARIO_ID}.csv"
        if [ ! -f "$CSV_PATH" ]; then
            echo "${MASTER}:${DEFAULT_VOLUME}" > "$CSV_PATH"
        fi

        # Add entry to scenarios.json
        python3 -c "
import json, sys
path, sid, name, icon = sys.argv[1:]
try:
    data = json.load(open(path))
except Exception:
    data = {'scenarios': {}}
data['scenarios'][sid] = {'name': name, 'icon': icon}
json.dump(data, open(path, 'w'), ensure_ascii=False, indent=2)
print(sid)
" "$META_FILE" "$SCENARIO_ID" "$NAME" "$ICON"
        ;;

    set_master)
        # set_master <scenario_id> <new_master_entity>
        # Reorders CSV: new master first, old members follow in original order.
        # If new master was already a member, it is removed from that position.
        # If new master is not in the CSV at all, it is added with DEFAULT_VOLUME.
        SCENARIO_ID="$2"
        NEW_MASTER="$3"

        python3 -c "
import sys
path, new_master, default_vol = sys.argv[1:]
try:
    lines = [l.strip() for l in open(path) if l.strip()]
    master_line = next((l for l in lines if l.split(':')[0] == new_master), new_master + ':' + default_vol)
    others = [l for l in lines if l.split(':')[0] != new_master]
    open(path, 'w').write('\n'.join([master_line] + others) + '\n')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" "${BASE_DIR}/scenario_${SCENARIO_ID}.csv" "$NEW_MASTER" "$DEFAULT_VOLUME"
        ;;

    delete)
        # delete <scenario_id>
        # Removes CSV file and entry from scenarios.json
        SCENARIO_ID="$2"
        META_FILE="${BASE_DIR}/scenarios.json"

        rm -f "${BASE_DIR}/scenario_${SCENARIO_ID}.csv"

        python3 -c "
import json, sys
path, sid = sys.argv[1:]
try:
    data = json.load(open(path))
    data['scenarios'].pop(sid, None)
    json.dump(data, open(path, 'w'), ensure_ascii=False, indent=2)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" "$META_FILE" "$SCENARIO_ID"
        ;;

    rename)
        # rename <scenario_id> <new_name>
        # Updates display name in scenarios.json; ID and CSV file are unchanged
        SCENARIO_ID="$2"
        NEW_NAME="$3"
        META_FILE="${BASE_DIR}/scenarios.json"

        python3 -c "
import json, sys
path, sid, new_name = sys.argv[1:]
try:
    data = json.load(open(path))
    if sid in data['scenarios']:
        data['scenarios'][sid]['name'] = new_name
    json.dump(data, open(path, 'w'), ensure_ascii=False, indent=2)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" "$META_FILE" "$SCENARIO_ID" "$NEW_NAME"
        ;;

    set_icon)
        # set_icon <scenario_id> <new_icon>
        # Updates icon field in scenarios.json; ID and CSV file are unchanged
        SCENARIO_ID="$2"
        NEW_ICON="$3"
        META_FILE="${BASE_DIR}/scenarios.json"

        python3 -c "
import json, sys
path, sid, new_icon = sys.argv[1:]
try:
    data = json.load(open(path))
    if sid in data['scenarios']:
        data['scenarios'][sid]['icon'] = new_icon
    json.dump(data, open(path, 'w'), ensure_ascii=False, indent=2)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" "$META_FILE" "$SCENARIO_ID" "$NEW_ICON"
        ;;

    *)
        echo "Usage: $0 {read|write|players|create|delete|rename|set_icon|set_master} <args>"
        exit 1
        ;;
esac