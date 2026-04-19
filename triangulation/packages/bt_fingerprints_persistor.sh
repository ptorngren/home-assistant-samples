#!/bin/bash
# ----------------------------------------------------------------
# bt_fingerprints_persistor.sh
# Helper script to Read/Write BT fingerprints and scan data
# ----------------------------------------------------------------

ACTION="$1"
DATA_TYPE="$2"
CONTENT="$3"

# Path configuration
BASE_DIR="/config/packages/triangulation/data"

# Ensure directory exists
mkdir -p "$BASE_DIR"

case "$ACTION" in
    write)
        # Determine file path based on data type
        case "$DATA_TYPE" in
            fingerprints)
                FILE_PATH="${BASE_DIR}/bt_fingerprints.json"
                ;;
            ignored)
                FILE_PATH="${BASE_DIR}/bt_ignored.json"
                ;;
            statistics)
                FILE_PATH="${BASE_DIR}/bt_statistics.json"
                ;;
            *)
                echo "Usage: $0 write {fingerprints|ignored|statistics} <content>"
                exit 1
                ;;
        esac
        # Decode base64 content and write to file
        # base64_encode preserves newlines and special characters safely
        case "$DATA_TYPE" in
            fingerprints)
                echo "$CONTENT" | base64 -d | python3 -c "
import json, sys
data = json.load(sys.stdin)
data['fingerprints'].sort(key=lambda fp: fp['loc'])
for fp in data['fingerprints']:
    fp['beacons'] = dict(sorted(fp['beacons'].items()))
print(json.dumps(data, indent=2, ensure_ascii=False))
" > "$FILE_PATH"
                ;;
            ignored)
                echo "$CONTENT" | base64 -d | python3 -c "
import json, sys
data = json.load(sys.stdin)
data['ignored'].sort()
print(json.dumps(data, indent=2, ensure_ascii=False))
" > "$FILE_PATH"
                ;;
            statistics)
                echo "$CONTENT" | base64 -d | python3 -c "
import json, sys
data = json.load(sys.stdin)
data['statistics'].sort(key=lambda s: s['loc'])
for s in data['statistics']:
    s['beacons'] = dict(sorted(s['beacons'].items()))
print(json.dumps(data, indent=2, ensure_ascii=False))
" > "$FILE_PATH"
                ;;
        esac
        ;;

    read)
        # Determine file path based on data type
        case "$DATA_TYPE" in
            fingerprints)
                FILE_PATH="${BASE_DIR}/bt_fingerprints.json"
                ;;
            ignored)
                FILE_PATH="${BASE_DIR}/bt_ignored.json"
                ;;
            statistics)
                FILE_PATH="${BASE_DIR}/bt_statistics.json"
                ;;
            *)
                echo "Usage: $0 read {fingerprints|ignored|statistics}"
                exit 1
                ;;
        esac

        if [ -f "$FILE_PATH" ]; then
            cat "$FILE_PATH"
        else
            case "$DATA_TYPE" in
                fingerprints) echo '{"fingerprints":[]}' ;;
                ignored)      echo '{"ignored":[]}' ;;
                statistics)   echo '{"statistics":[]}' ;;
            esac
        fi
        ;;

    *)
        echo "Usage: $0 {read|write} {fingerprints|ignored|statistics} [content]"
        exit 1
        ;;
esac
