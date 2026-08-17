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
        # Decode base64 content and write to file.
        # base64_encode preserves newlines and special characters safely.
        #
        #   Atomic. The document is sorted and serialised to a string first, written to a temp
        #   file beside the target and moved into place with os.replace. Redirecting into the
        #   target truncates it before python starts, so a malformed payload or a missing key
        #   leaves an empty file - and these files are weeks of room-by-room calibration.
        #
        #   Loud about a file it cannot read. A missing or empty file is a legitimate first run.
        #   A file that exists and does not parse aborts the write: the writers rebuild the whole
        #   document from a sensor that reads this file, so overwriting it after a failed read
        #   replaces real data with an empty document.
        echo "$CONTENT" | base64 -d | python3 -c '
import json, os, sys, tempfile

path, kind = sys.argv[1:3]

if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        with open(path) as f:
            json.load(f)
    except Exception as e:
        print(f"Error: {path} exists but does not parse ({e}); refusing to overwrite it",
              file=sys.stderr)
        sys.exit(1)

data = json.load(sys.stdin)

if kind == "fingerprints":
    data["fingerprints"].sort(key=lambda fp: fp["loc"])
    for fp in data["fingerprints"]:
        fp["beacons"] = dict(sorted(fp["beacons"].items()))
elif kind == "ignored":
    data["ignored"].sort()
elif kind == "statistics":
    data["statistics"].sort(key=lambda s: s["loc"])
    for s in data["statistics"]:
        s["beacons"] = dict(sorted(s["beacons"].items()))

payload = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".bt_", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        f.write(payload)
    os.replace(tmp, path)
except Exception:
    os.unlink(tmp)
    raise
' "$FILE_PATH" "$DATA_TYPE"
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
