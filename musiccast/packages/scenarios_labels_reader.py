# ================================================================
# MusicCast Scenario Labels Reader
# ================================================================
# Reads scenarios.json (display names + icons keyed by scenario_id)
#
# Output: the file's JSON, or {"scenarios": {}} when the file is missing, plus "order":
# the scenario ids in file order, which is tile order. The list is what carries the order
# to the dashboard: HA compares attributes by value, and two dicts with the same entries
# in a different order are equal, so a reorder alone would never update the sensor.
# Used by: sensor.musiccast_scenarios_labels (command_line sensor)

import json
import os

path = '/config/packages/musiccast/data/scenarios.json'
data = json.load(open(path)) if os.path.exists(path) else {'scenarios': {}}
data['order'] = list(data.get('scenarios', {}))
print(json.dumps(data))
