#!/bin/bash
# ----------------------------------------------------------------
# randomization_persistor.sh
# Helper script to Read/Write MusicCast randomization state
# ----------------------------------------------------------------

ACTION="$1"
SCENARIO="$2"
CONTENT="$3"

# Path configuration
BASE_DIR="/config/packages/musiccast/data"
FILE_PATH="${BASE_DIR}/presets_${SCENARIO}.csv"

# Ensure directory exists
mkdir -p "$BASE_DIR"

case "$ACTION" in
    write)
        # Write content to file.
        # We use printf to preserve newlines from HA templates.
        # TODO: Security hardening - pass data via stdin instead of command-line argument
        #       to safely handle special characters (quotes, etc.) in data
        #       Current printf '%s' is safer than echo, but stdin is ideal
        #       See: packages/screensaver/bt_fingerprints_persistor.sh for safer pattern
        printf '%s\n' "$CONTENT" > "$FILE_PATH"
        ;;

    read)
        if [ -f "$FILE_PATH" ]; then
            awk -F, '
                BEGIN { printf "{" }
                {
                    # Only process lines that strictly have 2 fields (preset_num,state)
                    if (NF == 2) {
                        # If we have already printed a field, add a comma separator
                        if (found_first) printf ","

                        # Print "key":"value"
                        printf "\"%s\":\"%s\"", $1, $2
                        found_first = 1
                    }
                }
                END { printf "}" }
            ' "$FILE_PATH"
        else
            echo "{}"
        fi
        ;;

    *)
        echo "Usage: $0 {read|write} <scenario> [content]"
        exit 1
        ;;
esac
