# ================================================================
# MusicCast Scenarios Reader
# ================================================================
# Reads every scenario_*.csv (one "entity_id:..." line per player, master first)
#
# Output: JSON {"scenarios": {name: {"master": entity_id, "players": [entity_id, ...]}}}
# Used by: sensor.musiccast_scenarios (command_line sensor)

import glob
import json
import os

result = {}
for f in sorted(glob.glob('/config/packages/musiccast/data/scenario_*.csv')):
    name = os.path.basename(f).replace('scenario_', '').replace('.csv', '')
    lines = [l.strip() for l in open(f) if l.strip() and ':' in l]
    if lines:
        players = [l.split(':')[0] for l in lines]
        result[name] = {'master': players[0], 'players': players}
print(json.dumps({'scenarios': result}))
