#!/bin/bash
# ----------------------------------------------------------------
# bt_fingerprints_persistor.sh
# Helper script to Read/Write BT fingerprints and scan data
# ----------------------------------------------------------------

ACTION="$1"
DATA_TYPE="$2"
CONTENT="$3"
# "allow-shrink" means the caller is removing entries on purpose. Two send it: clearing the
# fingerprint database, and restoring a beacon from the global ignore list. See the write branch.
ALLOW_SHRINK="$4"

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
                echo "Usage: $0 write {fingerprints|ignored|statistics} <content> [allow-shrink]"
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
        #
        #   Refuses any write holding fewer entries than the file already does, unless the caller
        #   passes allow-shrink. The read below answers a missing file with an empty document, so a
        #   sensor that refreshed while its file was briefly away reports an empty list while the file
        #   on disk is intact - and a command_line sensor only re-reads on demand, so it can stay that
        #   way for a day. Every writer rebuilds its whole document from that sensor, so a write from a
        #   stale one carries only what the sensor could see.
        #
        #   The comparison is the entry count, not emptiness: a capture, merge or reset rebuilt from an
        #   empty sensor produces a document holding the ONE location it touched, which is not empty and
        #   would otherwise be accepted over five real ones.
        #
        #   Removing entries is rare and always deliberate, so the caller says so. Two do: clearing the
        #   fingerprint database, and restoring a beacon from the global ignore list, which is the one
        #   routine shrink in the package. Nothing shrinks statistics through here - bt_clear_statistics
        #   bypasses this script by design.
        echo "$CONTENT" | base64 -d | python3 -c '
import json, os, sys, tempfile

path, kind, allow_shrink = sys.argv[1:4]

existing = None
if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        with open(path) as f:
            existing = json.load(f)
    except Exception as e:
        print(f"Error: {path} exists but does not parse ({e}); refusing to overwrite it",
              file=sys.stderr)
        sys.exit(1)

# Every message below is written for the person reading the failure notification, which quotes stderr
# verbatim. Anything reaching this script unvalidated would surface there as a python traceback.
if existing is not None and not (isinstance(existing, dict) and isinstance(existing.get(kind), list)):
    print(f"Error: {path} parses but document type is not {kind}; refusing to overwrite it",
          file=sys.stderr)
    sys.exit(1)

try:
    data = json.load(sys.stdin)
except Exception as e:
    print(f"Error: the {kind} payload is not valid JSON ({e}); nothing written",
          file=sys.stderr)
    sys.exit(1)

if not (isinstance(data, dict) and isinstance(data.get(kind), list)):
    print(f"Error: the {kind} payload must be an object holding a {kind} list; nothing written",
          file=sys.stderr)
    sys.exit(1)

if allow_shrink != "allow-shrink":
    # Counted first: nesting the same quote inside the f-string needs python 3.12, and this runs
    # wherever Home Assistant runs.
    held = len(existing[kind]) if existing else 0
    incoming = len(data[kind])
    if incoming < held:
        noun = {"fingerprints": "location", "ignored": "beacon", "statistics": "location"}[kind]
        print(f"Error: {path} holds {held} {noun}(s) and the write would leave {incoming}; "
              "refusing. A caller that means to remove entries says so with allow-shrink",
              file=sys.stderr)
        sys.exit(1)

# The shape check above proves the top-level list exists, not that its entries are well formed - and
# the writers carry untouched entries across verbatim, so a hand-edited file round-trips whatever it
# holds straight into this sort. A malformed entry must read as a sentence, not a traceback.
try:
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
except Exception as e:
    print(f"Error: the {kind} payload has a malformed entry ({e}); nothing written",
          file=sys.stderr)
    sys.exit(1)

payload = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".bt_", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        f.write(payload)
    os.replace(tmp, path)
except Exception:
    os.unlink(tmp)
    raise
' "$FILE_PATH" "$DATA_TYPE" "$ALLOW_SHRINK"
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
        echo "Usage: $0 {read|write} {fingerprints|ignored|statistics} [content] [allow-shrink]"
        exit 1
        ;;
esac
