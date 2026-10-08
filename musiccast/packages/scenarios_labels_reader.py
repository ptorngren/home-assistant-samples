# ================================================================
# MusicCast Scenario Labels Reader
# ================================================================
# Reads scenarios.json (display names + icons keyed by scenario_id)
#
# Output: the file's JSON as is, or {"scenarios": {}} when the file is missing
# Used by: sensor.musiccast_scenarios_labels (command_line sensor)

import json
import os

path = '/config/packages/musiccast/data/scenarios.json'
data = json.load(open(path)) if os.path.exists(path) else {'scenarios': {}}
print(json.dumps(data))
