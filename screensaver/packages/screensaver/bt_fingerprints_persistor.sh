#!/bin/bash
# ----------------------------------------------------------------
# bt_fingerprints_persistor.sh
# Helper script to Read/Write BT fingerprints and scan data
# ----------------------------------------------------------------

# Source shared library for JSON escaping
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bt_persistor_lib.sh"

ACTION="$1"
DATA_TYPE="$2"
CONTENT="$3"

# Path configuration
BASE_DIR="/config/.cache"

# Ensure directory exists
mkdir -p "$BASE_DIR"

case "$ACTION" in
    write)
        # Determine file path based on data type
        case "$DATA_TYPE" in
            fingerprints)
                FILE_PATH="${BASE_DIR}/bt_fingerprints.csv"
                ;;
            ignored)
                FILE_PATH="${BASE_DIR}/bt_ignored.csv"
                ;;
            *)
                echo "Usage: $0 write {fingerprints|ignored} <content>"
                exit 1
                ;;
        esac
        # Decode base64 content and write to file
        # base64_encode preserves newlines and special characters safely
        echo "$CONTENT" | base64 -d > "$FILE_PATH"
        ;;

    read)
        # Determine file path based on data type
        case "$DATA_TYPE" in
            fingerprints)
                FILE_PATH="${BASE_DIR}/bt_fingerprints.csv"
                DEFAULT=""
                WRAP=true
                ;;
            ignored)
                FILE_PATH="${BASE_DIR}/bt_ignored.csv"
                DEFAULT="[]"
                WRAP=true
                ;;
            *)
                echo "Usage: $0 read {fingerprints|ignored}"
                exit 1
                ;;
        esac

        if [ -f "$FILE_PATH" ]; then
            if [ "$WRAP" = true ]; then
                if [ "$DATA_TYPE" = "fingerprints" ]; then
                    # Wrap fingerprint CSV in JSON array for json_attributes compatibility
                    # CSV format: location_index|MAC=RSSI,MAC=RSSI,... (newline-separated)
                    # JSON format: {"fingerprints":["entry1","entry2","entry3"]}
                    # Uses escape_json_string() to safely handle special chars
                    printf '{"fingerprints":['
                    first=true
                    while IFS= read -r line || [ -n "$line" ]; do
                        if [ -n "$line" ]; then
                            if [ "$first" = false ]; then
                                printf ','
                            fi
                            escaped_line=$(escape_json_string "$line")
                            printf '%s' "$escaped_line"
                            first=false
                        fi
                    done < "$FILE_PATH"
                    printf ']}'
                elif [ "$DATA_TYPE" = "ignored" ]; then
                    # Convert newline-separated MAC list to JSON array for json_attributes compatibility
                    # CSV format: MAC\nMAC\nMAC\n... (newline-separated)
                    # JSON format: {"ignored":["MAC1","MAC2","MAC3"]}
                    # Uses escape_json_string() to safely handle special chars
                    printf '{"ignored":['
                    first=true
                    while IFS= read -r line || [ -n "$line" ]; do
                        if [ -n "$line" ]; then
                            if [ "$first" = false ]; then
                                printf ','
                            fi
                            escaped_line=$(escape_json_string "$line")
                            printf '%s' "$escaped_line"
                            first=false
                        fi
                    done < "$FILE_PATH"
                    printf ']}'
                fi
            else
                cat "$FILE_PATH"
            fi
        else
            if [ "$WRAP" = true ]; then
                if [ "$DATA_TYPE" = "fingerprints" ]; then
                    echo "{\"fingerprints\":\"\"}"
                elif [ "$DATA_TYPE" = "ignored" ]; then
                    echo "{\"ignored\":$DEFAULT}"
                fi
            else
                echo "$DEFAULT"
            fi
        fi
        ;;

    *)
        echo "Usage: $0 {read|write} {fingerprints|scan} [content]"
        exit 1
        ;;
esac
