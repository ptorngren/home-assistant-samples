#!/bin/bash
# ================================================================
# bt_persistor_lib.sh
# Shared library for BT data persistence (fingerprints, scan, ignored, scores)
# Contains common functions used by bt_fingerprints_persistor.sh
# ================================================================

# Escape special characters in string for safe JSON output
# Handles: backslash, double quotes, newlines, carriage returns, tabs
# Usage: escape_json_string "string with \"quotes\" and newlines"
# Output: Properly escaped string ready for JSON (including surrounding quotes)
escape_json_string() {
  local s="$1"
  # Escape in order: backslash FIRST (else we double-escape), then others
  s="${s//\\/\\\\}"      # \ → \\
  s="${s//\"/\\\"}"      # " → \"
  s="${s//$'\n'/\\n}"    # newline → \n
  s="${s//$'\r'/\\r}"    # carriage return → \r
  s="${s//$'\t'/\\t}"    # tab → \t
  printf '"%s"' "$s"
}
