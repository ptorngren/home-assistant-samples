# ================================================================
# MusicCast Randomization Locks Reader
# ================================================================
# Reads every presets_*.csv ("preset_num,state" lines) and finds the locked preset per scenario
#
# Output: JSON {"locks": {scenario: preset_num}} — scenarios without a lock are left out
# Used by: sensor.musiccast_randomization_locks (command_line sensor)

import glob
import json
import os

# code_locked in mixer.yaml's RANDOMIZATION STATE CONSTANTS — keep in sync
CODE_LOCKED = 'L'

result = {}
for f in sorted(glob.glob('/config/packages/musiccast/data/presets_*.csv')):
    scenario = os.path.basename(f).replace('presets_', '').replace('.csv', '')
    lock_num = 0
    try:
        for line in open(f):
            parts = line.strip().split(',')
            if len(parts) == 2 and parts[1].strip() == CODE_LOCKED:
                lock_num = int(parts[0].strip())
                break
    except Exception:
        pass
    if lock_num:
        result[scenario] = lock_num
print(json.dumps({'locks': result}))
