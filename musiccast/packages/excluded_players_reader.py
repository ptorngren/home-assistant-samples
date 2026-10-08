# ================================================================
# MusicCast Excluded Players Reader
# ================================================================
# Reads media_players.exclude (one entity_id per line, "#" lines are comments)
#
# Output: JSON {"excluded": [entity_id, ...]} — empty list when the file is missing
# Used by: sensor.musiccast_excluded_players (command_line sensor)

import json

EXCLUDE_FILE = '/config/packages/musiccast/data/media_players.exclude'

try:
    lines = [l.strip() for l in open(EXCLUDE_FILE) if l.strip() and not l.startswith('#')]
except FileNotFoundError:
    lines = []
print(json.dumps({'excluded': lines}))
