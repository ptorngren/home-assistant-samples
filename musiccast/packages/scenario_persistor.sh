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
META_FILE="${BASE_DIR}/scenarios.json"

# Default volume for newly added players (HA scale 0.0–1.0)
DEFAULT_VOLUME=0.25

# Ensure directory exists
mkdir -p "$BASE_DIR"

# ----------------------------------------------------------------
# scenarios.json — the one place that reads and writes the metadata file
# ----------------------------------------------------------------
# Every mutation goes through here so the two properties below hold for all of
# them rather than for whichever branch was written most carefully.
#
#   Atomic. The JSON is serialised to a string, written to a temp file beside
#   the target and moved into place with os.replace. Writing straight into
#   open(path,'w') truncates the file before serialising, so anything that
#   raises mid-dump — an unencodable value, a full disk — leaves the file cut
#   off at that point. The reader then sees invalid JSON and every scenario
#   disappears from the dashboard.
#
#   Loud about a file it cannot read. A missing file is a legitimate first run
#   and starts an empty document; a file that exists but does not parse aborts
#   and changes nothing. Treating the second case as "start over" turns one
#   unreadable file into an erased one.
#
# Usage: meta_write <op> <scenario_id> [args…]
#   create <id> <name> <icon>   add or replace an entry
#   delete <id>                 remove an entry
#   set    <id> <field=value>   update one field of an existing entry
#
# Values are passed as separate arguments rather than assembled into JSON by the
# shell, so a quote or a brace in a scenario name cannot corrupt the document.
meta_write() {
    python3 -c '
import json, os, sys, tempfile

path, op, sid = sys.argv[1:4]
value = sys.argv[4] if len(sys.argv) > 4 else None
value2 = sys.argv[5] if len(sys.argv) > 5 else None

if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error: {path} exists but does not parse ({e}); refusing to overwrite it",
              file=sys.stderr)
        sys.exit(1)
else:
    data = {"scenarios": {}}

scenarios = data.setdefault("scenarios", {})

if op == "create":
    scenarios[sid] = {"name": value, "icon": value2}
elif op == "delete":
    scenarios.pop(sid, None)
elif op == "set":
    field, _, new = value.partition("=")
    if sid in scenarios:
        scenarios[sid][field] = new
else:
    print(f"Error: unknown op {op}", file=sys.stderr)
    sys.exit(1)

# Serialise first: a failure here must not have touched the file yet.
payload = json.dumps(data, ensure_ascii=False, indent=2)

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".scenarios.", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        f.write(payload)
    os.replace(tmp, path)
except Exception:
    os.unlink(tmp)
    raise
' "$META_FILE" "$@"
}

case "$ACTION" in
    write)
        # Write content to file.
        # We use quotes around "$CONTENT" to preserve the newlines sent from HA.
        # TODO: Security hardening - pass data via stdin instead of command-line argument
        #       to safely handle special characters (quotes, etc.) in data
        #       See: packages/triangulation/bt_fingerprints_persistor.sh for safer pattern
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
        # create <name-b64> <icon-b64> <master_entity>
        # Derives scenario_id from display name, creates CSV + updates scenarios.json
        NAME=$(echo "$2" | base64 -d)
        ICON=$(echo "$3" | base64 -d)
        MASTER="$4"

        # Generate scenario_id: strip diacritics, lowercase, spaces and hyphens to
        # underscores, keep only a-z0-9_, trim leading/trailing underscores
        SCENARIO_ID=$(python3 -c "
import unicodedata, re, sys
name = sys.argv[1]
normalized = unicodedata.normalize('NFD', name)
ascii_name = ''.join(c for c in normalized if unicodedata.category(c) != 'Mn')
with_underscores = re.sub(r'[\s\-]+', '_', ascii_name.lower())
print(re.sub(r'[^a-z0-9_]', '', with_underscores).strip('_'))
" "$NAME")

        # Refuse what cannot make a usable scenario, before anything is written. A blank
        # name derives a blank id, which writes a "" key and a file literally called
        # scenario_.csv; a blank master writes a CSV whose first line is ":0.25", giving a
        # scenario nothing can play. Both are reachable from the editor, which passes its
        # fields through untouched, and both leave junk that has to be cleared by hand.
        # The name is checked through the derived id, so a name of only punctuation — which
        # survives the field but derives to nothing — is caught with the empty one.
        if [ -z "$SCENARIO_ID" ]; then
            echo "Error: scenario name '${NAME}' gives no usable id; not created" >&2
            exit 1
        fi
        if [ -z "$MASTER" ]; then
            echo "Error: scenario '${NAME}' needs a master player; not created" >&2
            exit 1
        fi

        # Metadata first, because meta_write is the step that can refuse: it aborts on a
        # metadata file it cannot read. Ordered this way, that refusal leaves nothing at
        # all; the other way round it would leave an orphan CSV, which sensor.
        # musiccast_scenarios picks up by globbing scenario_*.csv and reports as a
        # scenario the dashboard cannot show — the tiles are built from scenarios.json.
        meta_write create "$SCENARIO_ID" "$NAME" "$ICON" || exit 1

        # Create CSV with the master at DEFAULT_VOLUME if it does not already exist
        CSV_PATH="${BASE_DIR}/scenario_${SCENARIO_ID}.csv"
        if [ ! -f "$CSV_PATH" ]; then
            echo "${MASTER}:${DEFAULT_VOLUME}" > "$CSV_PATH"
        fi

        echo "$SCENARIO_ID"
        ;;

    set_master)
        # set_master <scenario_id> <new_master_entity>
        # Reorders CSV: new master first, old members follow in original order.
        # If new master was already a member, it is removed from that position.
        # If new master is not in the CSV at all, it is added with DEFAULT_VOLUME.
        SCENARIO_ID="$2"
        NEW_MASTER="$3"

        # The same refusal as create and rename, and the one that matters most: this is the
        # only write path that damages an *existing* scenario. An empty master writes a first
        # line of ":0.25" and demotes the real master to a member, leaving a scenario that
        # cannot play. The editor validates before calling, but these guards exist for the
        # callers this script does not own.
        if [ -z "$NEW_MASTER" ]; then
            echo "Error: scenario '${SCENARIO_ID}' cannot be given an empty master" >&2
            exit 1
        fi

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

        # Metadata first, as in create, and for the same reason: meta_write is the step
        # that can refuse. Removing the CSV first would destroy the group and volumes and
        # then abort on an unreadable metadata file, losing the scenario's contents while
        # leaving its entry behind.
        meta_write delete "$SCENARIO_ID" || exit 1

        rm -f "${BASE_DIR}/scenario_${SCENARIO_ID}.csv"
        ;;

    rename)
        # rename <scenario_id> <new_name-b64>
        # Updates display name in scenarios.json; ID and CSV file are unchanged
        SCENARIO_ID="$2"
        NEW_NAME=$(echo "$3" | base64 -d)

        # Same refusal as create: a blank name leaves a tile with nothing written on it.
        # set_icon has no equivalent guard on purpose — a blank icon falls back to the
        # dashboard's default and the scenario still works, so it is a cosmetic choice
        # rather than an unusable state.
        if [ -z "$NEW_NAME" ]; then
            echo "Error: scenario '${SCENARIO_ID}' cannot be renamed to an empty name" >&2
            exit 1
        fi

        meta_write set "$SCENARIO_ID" "name=${NEW_NAME}"
        ;;

    set_icon)
        # set_icon <scenario_id> <new_icon-b64>
        # Updates icon field in scenarios.json; ID and CSV file are unchanged
        SCENARIO_ID="$2"
        NEW_ICON=$(echo "$3" | base64 -d)

        meta_write set "$SCENARIO_ID" "icon=${NEW_ICON}"
        ;;

    *)
        echo "Usage: $0 {read|write|players|create|delete|rename|set_icon|set_master} <args>"
        exit 1
        ;;
esac