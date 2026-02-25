
# Bluetooth Triangulation: Beacon Curation & Location Matching

BT location detection uses beacon signal strength (RSSI) to identify which room you're in. When you capture a location's fingerprint, you record which beacons are present and their signal strengths. However, **not all beacons are reliable**:

**Three problems degrade location detection:**

1. **Volatile beacons** — Your own devices with unstable signal strength
   - A beacon captured at -94 dBm might later appear at -96 dBm (below threshold), disappearing from scans
   - A printer's signal bounces off obstacles: -65 dBm one day, -40 dBm another day
   - When these beacons vanish or change, the fingerprint matching fails (missing beacons, low signal similarity)

2. **Alien devices** — Beacons from neighbors
   - A Bluetooth Party Speaker or a smart TV you don't own
   - These devices turn on/off unpredictably, adding random noise
   - They're unreliable regardless of signal strength or location - you don't control them

3. **Overlapping beacons** — Your own devices appearing in multiple rooms with different expected signals
   - A beacon strong in the GARAGE might be detected similarly in the KITCHEN
   - The algorithm can't distinguish rooms when they share too many similar beacons

**The solution: Beacon curation**

You manually identify and ignore problematic beacons:
- **Volatile beacons** → Ignore globally (mark as unreliable)
- **Alien devices** → Ignore globally (they don't belong to you)
- **Overlapping beacons** → Ignore locally from specific rooms (keep them where they're distinctive)

Beacon curation is **fully manual and reversible** — you run fingerprint captures, observe what's detected, use your domain knowledge to decide what to ignore, and toggle beacons on/off anytime without recalibrating.

---

## How to Use

### Setting Up Locations

1. Open the **BT Location Calibration** dashboard
2. Enter your room names in **Location Names** (e.g., kitchen, garage, bedroom)
3. Adjust **BT Weak Signal Threshold** if needed (default -95 dBm filters out very weak signals)

### Capturing Fingerprints

1. Go to each location with your phone/device
2. Long-press the location heading in **Fingerprint Details** to capture beacon signals for that location
3. The system records which beacons are detected and their signal strengths
4. Repeat for all locations

### Managing Beacons

In the **Fingerprint Details** section, you can adjust which beacons are used for each location:

**Ignore a beacon locally (from specific location):**
1. Find the beacon in a location's fingerprint list
2. **Tap the beacon** to toggle it ignored/active for that location
3. The beacon is now ignored in this location but remains active in other locations

**Ignore a beacon globally (from all locations):**
1. Find the beacon in the latest scan or any location's fingerprint
2. **Hold the beacon** to toggle it globally ignored/active
3. The beacon is now ignored everywhere and won't affect any location detection

**Check Status**
1. Click **Beacon Status** to see ignored/active beacons

### Validating Your Setup

After configuring locations and managing beacons:

1. Go to **Algorithm Tuning** tab
2. Click **Test Algorithm Sanity** to validate location detection accuracy
3. Review the **Algorithm Results** table to see how locations score for the current scan
4. Adjust beacon ignores if any locations have similar scores

### Understanding the Scoring

**How the algorithm scores locations:**
```
Score = (0.45 × beacon_match_ratio) + (0.30 × fingerprint_coverage) + (0.25 × signal_similarity)

- beacon_match_ratio: How many beacons you matched vs the best match across all locations
- fingerprint_coverage: What percentage of this location's fingerprint you matched
- signal_similarity: How close your RSSI values match the fingerprint
```

Beacon curation improves these scores by removing beacons that hurt detection. Here's how each problem degrades scoring:

---

**Problem 1: Volatile Beacons (Signal Instability)**

A printer beacon was captured at -94 dBm (above threshold), but later appears at -96 dBm (below threshold):
```
Fingerprint: OFFICE has [Printer at -94 dBm, Desk lamp at -65 dBm, Router at -45 dBm]

Day 1 (Good): Scan finds [Printer at -94, Lamp at -65, Router at -45]
- beacon_match_ratio: 3/3 = 1.0 (all beacons found)
- fingerprint_coverage: 3/3 = 1.0 (matched 100%)
- signal_similarity: All within 2 dBm → 0.95
- Score: (0.45 × 1.0) + (0.30 × 1.0) + (0.25 × 0.95) = 0.98 ✅

Day 2 (Bad): Scan finds [Lamp at -65, Router at -45] (Printer at -96, below threshold)
- beacon_match_ratio: 2/3 = 0.67 (only 2 of 3 beacons found)
- fingerprint_coverage: 2/3 = 0.67 (matched only 67%)
- signal_similarity: Can't evaluate Printer, others OK → 0.90
- Score: (0.45 × 0.67) + (0.30 × 0.67) + (0.25 × 0.90) = 0.70 ❌

Solution: Ignore the volatile Printer beacon globally
- Fingerprint becomes [Desk lamp at -65, Router at -45]
- Both days: beacon_match_ratio 2/2, fingerprint_coverage 2/2, signal_similarity 0.95
- Score both days: (0.45 × 1.0) + (0.30 × 1.0) + (0.25 × 0.95) = 0.98 ✅
```

---

**Problem 2: Alien Devices (Unreliable Neighbor Equipment)**

A JBL Party Speaker (not yours) appears randomly in scans with unpredictable signal:
```
Fingerprint: BEDROOM includes [Lamp at -60, Party Speaker at -75, Desk Speaker at -70]
(You forgot the Party Speaker is a neighbor's device when capturing)

Day 1 (Party Speaker on): Scan finds [Lamp at -60, Party Speaker at -74, Desk Speaker at -70]
- Matches all 3, scores well

Day 2 (Party Speaker off): Scan finds only [Lamp at -60, Desk Speaker at -70]
- beacon_match_ratio: 2/3 = 0.67, fingerprint_coverage: 2/3 = 0.67
- Score drops significantly because a "beacon" is missing

Day 3 (Party Speaker elsewhere): Scan finds [Lamp at -60, Party Speaker at -45, Desk Speaker at -70]
- signal_similarity crashes (Party Speaker is 30 dBm different)
- Score affected by signal mismatch

Solution: Ignore the Party Speaker globally
- Fingerprint becomes [Lamp at -60, Desk Speaker at -70]
- All days: Consistent matching, consistent scores ✅
```

---

**Problem 3: Overlapping Beacons (Same Beacon in Multiple Locations)**

An ENTRANCE beacon is strong in KITCHEN (-70 dBm) but also appears in GARAGE (-68 dBm):
```
KITCHEN Fingerprint: 15 beacons (includes ENTRANCE at -70 dBm)
GARAGE Fingerprint: 12 beacons (includes ENTRANCE at -68 dBm)
(Both share 10 other beacons with similar signal profiles)

When you're in KITCHEN and scan:
- Scan shows 12 matching beacons
- KITCHEN score: (0.45 × 1.0) + (0.30 × 0.80) + (0.25 × 0.85) = 0.68
- GARAGE score: (0.45 × 0.83) + (0.30 × 1.0) + (0.25 × 0.82) = 0.63

Result: KITCHEN wins, but margin is small (0.68 vs 0.63) — fragile detection
- The ENTRANCE beacon is shared, so it doesn't help distinguish them
- When ENTRANCE signal varies even slightly, GARAGE could win

Solution: Ignore ENTRANCE from both KITCHEN and GARAGE
- KITCHEN: 14 beacons → fingerprint_coverage improves (12/14 = 0.86 vs 0.80)
- GARAGE: 11 beacons → fingerprint_coverage improves (10/11 = 0.91 vs 0.83)

New scores when in KITCHEN:
- KITCHEN: (0.45 × 1.0) + (0.30 × 0.86) + (0.25 × 0.90) = 0.71
- GARAGE: (0.45 × 0.83) + (0.30 × 0.91) + (0.25 × 0.85) = 0.65

Result: Larger margin (0.71 vs 0.65) = robust detection ✅
```

---

**When to Ignore Each Type:**

| Problem | Type | Ignore Scope | Why |
|---------|------|--------------|-----|
| Volatile signal | Your own device | Global | Can't stabilize signal variance |
| Alien device | Neighbor equipment | Global | Always unreliable |
| Overlapping beacon | Your own device | Local (per-location) | Keep if distinctive in other rooms |

---

## Visual Setup Guide

### Calibration Dashboard

This is the main interface for setting up and managing BT location detection. You configure locations, capture fingerprints, and monitor beacon signals here.

![BT Location Calibration Dashboard](Triangulation.jpg)

**What you see:**
- **Location Names** — Editable list of rooms where you want location detection (kitchen, garage, office, etc.)
- **BT Weak Signal Threshold** — Slider to ignore weak beacons that might cause false positives  (-95 dBm is a fair staring point)
- **Management Buttons** — Report beacon status, load or clear stored data
- **Latest BT Scan** — Bluetooth devices with signal strength (RSSI in dBm) and device names as reported by the most recent report
- **Fingerprint Details** — Captured beacon signatures for each location, showing which beacons are active vs ignored and how they match the latest scan

### Algorithm Validation

After capturing fingerprints, validate the matching algorithm with this sanity check. It shows how well each location can be distinguished based on beacon signals.

![Algorithm Tuning & Validation](algorithm_tuning.jpg)

**What you see:**
- **BT Missing Beacon Penalty** — Slider adjusting how much the algorithm penalizes missing beacons (higher = stricter matching)
- **Test Algorithm Sanity** — Validates algorithm scoring against your current fingerprints
- **Algorithm Results Table** — Shows how each location scores for the latest scan:
  - **Matched** — How many beacons from the fingerprint were detected in the scan
  - **Σ Match** — Aggregate match quality (percentage of beacons found)
  - **Σ Signal** — Aggregate signal quality (how close RSSI values match)
  - **Penalty** — Points deducted for missing beacons
  - **Σ Total** — Final composite score (higher = better match)

**Goal:** The expected location should have high scores with clear separation to others (PEER 0.98 vs Garage 0.699 shows good distinction).

---

## Common Tasks

### Task 1: Remove an Overlapping Beacon

1. Identify locations where beacon causes ambiguity (similar RSSI values)
2. Ignore from affected locations by tapping the beacon
3. Beacon remains active in other locations where RSSI differs significantly
4. Affected locations show the beacon as ignored
5. Beacon never matches the affected locations

### Task 2: Ignore an Irrelevant Device

1. Identify beacon that's generally unwanted (neighbor device noise)
2. Long press the beacon in latest scan or in any location 
3. All locations show that this MAC is ignored
4. Beacon never matches any location

### Task 3: Re-enable an Ignored Beacon

1. Toggle the state by repeating the action (tap or press)

### Task 4: Check Current Ignore Status

1. Check `sensor.bt_ignored_beacons` state (shows count)
2. Go to `/lovelace/screensaver-settings`
3. Check "Fingerprint Details" table for per-location `:X` suffixes (red highlight)
4. Check "Beacon Coverage Summary" for active/ignored counts per location
5. Run `script.report_ignored_beacons` for detailed report

### Task 5: Reset All Ignores

1. Clear global ignored file (delete or empty `.cache/bt_ignored.csv`)
2. Recapture a location fingerprints (removes `:X` suffixes):

---

# Technical Reference


## Key Features

✅ **Flexible Ignore**
- Per-location: Ignore beacon from specific locations where it causes ambiguity
- Global: Ignore beacon from all locations (neighbor device noise)
- Toggle on/off any time

✅ **Unlimited Capacity**
- Global ignored: File-based storage, supports 100+ beacons
- Per-location: Limited only by beacon count in fingerprint
- No entity size limits (uses sensor attributes)

✅ **Persistent Storage**
- Per-location: `:X` suffix in fingerprint CSV
- Global: File-backed sensor attributes
- Both survive HA restarts and YAML reloads

✅ **Algorithm Integration**
- Seamless filtering (no performance impact)
- Works with existing match_ratio algorithm
- Transparent to detection logic
- Prepared for alternative algorithms

✅ **User Interface**
- Visual indicators (colors, strikethrough)
- Coverage statistics
- Validation reports

✅ **Documentation**
- System overview in dashboard
- Curation guide with examples
- Detailed markdown documentation

## Algorithm Selection Background

Fingerprinting for indoor positioning (BT RSSI in a home) uses several main approaches:

### Distance-Based Methods (Simplest)

**k-Nearest Neighbors (k-NN)**
- Find k most similar fingerprints, select most common location via voting
- Advantages: Simple, no training needed, works well in small environments (homes, offices)
- Disadvantages: Can be slow with large databases, sensitive to noise
- Standard choice in most home solutions

**Weighted k-NN**
- Same as k-NN but closer points get higher weight
- Advantages: More stable results, better handles outliers
- **Recommendation: Standard choice for home BT fingerprinting**

**1-NN (Nearest Neighbor)**
- Select only closest point
- Fast but less stable than k-NN

### Probabilistic Methods

**Naive Bayes**
- Each beacon contributes probability, combined to select location
- Advantages: Better noise tolerance, needs less data
- Disadvantages: Assumes signal independence (not always true)

**Gaussian Models**
- Each location modeled as mean + standard deviation
- Selects location with best statistical fit
- More accurate than Naive Bayes with good training data

### Machine Learning Methods

**Random Forest**
- Multiple decision trees vote for location
- Advantages: Very robust, tolerates noise well
- Disadvantages: Requires training phase, more computationally expensive

**Support Vector Machines (SVM)**
- Creates decision boundaries between zones
- Good for multi-room classification

**Neural Networks**
- Advantages: Highest accuracy possible
- Disadvantages: Overkill for homes, needs large datasets

### Temporal Models

**Hidden Markov Models (HMM)**
- Considers previous location and movement constraints
- Example: Can't jump from kitchen to bedroom in 0.1 seconds
- Adds extra layer of stability

**Kalman Filter**
- Smooths positions over time, removes signal jitter
- Simple to implement, effective for temporal stability

### Algorithm Comparison Table

| Algorithm      | Type         | Complexity | Accuracy | Home Suitability |
|----------------|--------------|-----------|----------|-----------------|
| 1-NN           | Distance     | Very Easy | OK       | Yes             |
| k-NN           | Distance     | Easy      | Good     | Yes             |
| Weighted k-NN  | Distance     | Easy      | Good     | Yes (abandoned) |
| Naive Bayes    | Probability  | Medium    | Good     | Yes             |
| Gaussian       | Probability  | Medium    | Good     | Yes             |
| Random Forest  | ML           | Medium    | Very Good | Overkill        |
| SVM            | ML           | Medium    | Very Good | Rarely needed   |
| Neural Net     | ML           | Hard      | Highest  | No (too complex)|
| HMM            | Temporal     | Medium    | Stabilizes | Extra layer    |
| Kalman Filter  | Temporal     | Easy      | Stabilizes | Yes (optional) |
| **Match Ratio** | **Custom**   | **Easy**  | **Very Good** | **Yes (selected)** |

## Algorithm Choice: Match Ratio with Beacon Strength Weighting

**Chosen Algorithm:** Two-stage matching prioritizing beacon count, with RSSI quality as tiebreaker

**Why this approach:**
Previous distance-based methods (Manhattan distance, weighted k-NN, summation-based scoring) all failed because they penalized locations with more beacons in their fingerprints. This caused false positives when a location with few beacons happened to have lucky RSSI matches.

The Match Ratio algorithm **separates two concerns:**
- **Stage 1: Beacon matching** — How many beacons from the fingerprint appear in the current scan (percentage-based, location-neutral)
- **Stage 2: Signal quality** — How close RSSI values match (weighted by beacon strength, high beacons ~48× more influential than weak ones)

**Result:** Eliminated the bias against larger fingerprints. 5/5 test locations detected correctly. Robust to signal drift and fingerprint size differences.

**Key features:**
- Beacon strength weighting: `weight = max(0, 100 + rssi_dBm)` — strong beacons (-52 dBm) ~48× more influential than weak ones (-94 dBm)
- Works reliably with fingerprints of different sizes
- No performance penalty (O(n) filtering per scan)

## Algorithm Output Protocol

The code is prepared to handle pluggable algorithms via `script.bt_location_detect_algorithm_proxy`. The generic detection logic in `bt_beacon_triangulation.yaml` calls this proxy, which is implemented in `screensaver_local.yaml` (default: Match Ratio algorithm). To swap algorithms, override the proxy implementation in your local package.

All location detection algorithms must return the following metrics for integration with the detection orchestrator:

| Metric | Type | Description |
|--------|------|-------------|
| `matched` | int | Number of beacons found in both fingerprint and current scan |
| `missing` | int | Number of beacons in fingerprint but not in current scan |
| `beacon_score` | float | Score contribution from beacon matching quantity |
| `rssi_score` | float | Score contribution from RSSI signal accuracy |
| `penalty` | float | Additional penalty (missing beacons, confidence gaps, etc.) |
| `total_score` | float | Final composite score; higher = better match |

**Match Ratio Algorithm Output Example:**
```yaml
matched: 12
missing: 3
beacon_score: 80.0  # (12/15) × 100
rssi_score: 4.25    # weighted average RSSI difference
penalty: 0
total_score: 84.25  # beacon_score + rssi_score + penalty
```

**Rationale:** This uniform protocol allows algorithm implementations to be swapped without changing detection logic, enabling future algorithm improvements or alternative matching strategies without affecting the orchestrator code.

---

## Data Formats

### Global Ignore List
**File:** `.cache/bt_bt_ignored.csv`

**Stored (newline-separated):**
```
AA:BB:CC:DD:EE:FF
11:22:33:44:55:66
22:33:44:55:66:77
```

**When read (JSON array via sensor):**
```json
{
  "ignored": ["AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66", "22:33:44:55:66:77"]
}
```

**Capacity:** Unlimited (supports 100+ beacons without issues)

### Per-Location Ignores
**File:** `.cache/bt_fingerprints.csv` (same as fingerprints)

**Format:**
```
0|AA:BB:CC:DD:EE:FF=-65,11:22:33:44:55:66=-72:X,22:33:44:55:66:77=-80:X
```

- `:X` suffix = ignored for this location only
- `:X` goes AFTER RSSI value
- Case-insensitive (normalized to uppercase in algorithm)

---

## Data Flow

### Reading Global Ignores
```
sensor.bt_ignored_beacons
  ↓ (reads from file via bash command)
ignored array in sensor attributes
  ↓ (available in scripts via state_attr())
Algorithm filters beacons immediately
```

### Writing Global Ignores
```
script.bt_beacon_toggle_global_ignored
  ↓ (reads from sensor attribute)
  ↓ (adds/removes MAC)
  ↓ (writes to file via shell_command)
homeassistant.update_entity
  ↓ (refreshes sensor)
Algorithm automatically uses updated list
```

### Filtering During Detection
```
BT scan → script.detect_location_from_signals
  ↓ (loads fingerprints + global ignored)
  ↓ (filters out ignored beacons)
script.bt_location_match_ratio
  ↓ (uses only active beacons for scoring)
Returns best match location
```

---

## Technical Implementation

### Algorithm Filtering Logic
```jinja2
# Skip ignored beacons when counting
for beacon in fingerprint:
    if beacon.endswith(':X'):
        continue  # Skip local ignored
    if beacon_mac in global_ignored_list:
        continue  # Skip global ignored
    # Count as active beacon
    score += calculate_match(beacon, scan)
```

### Performance Impact
- **Storage:** +2 bytes per ignored beacon (minimal)
- **Algorithm:** O(n) filtering, happens once per scan
- **UI:** Generated from existing data, no extra queries

### Data Consistency
- Local ignored stored with fingerprint (always together)
- Global ignored in file with sensor attributes (independent)
- Filtering applied consistently in algorithm
- UI reads same data as algorithm

---

## Scripts & Services

| Script | Purpose | Input |
|--------|---------|-------|
| `script.bt_beacon_toggle_location_ignored` | Ignore beacon at specific locations | location, mac |
| `script.bt_beacon_toggle_global_ignored` | Ignore beacon everywhere | mac |
| `script.report_ignored_beacons` | Check ignore status | (none) |
| `script.test_algorithm_sanity_check` | Test with ignored beacons | (none) |

### Service Call Examples

**Ignore beacon from specific location:**
```yaml
service: script.bt_beacon_toggle_location_ignored
data:
  location: "garage"
  mac: "AA:BB:CC:DD:EE:FF"
```

**Ignore beacon globally:**
```yaml
service: script.bt_beacon_toggle_global_ignored
data:
  mac: "11:22:33:44:55:66"
```

**Report ignored beacons:**
```yaml
service: script.report_ignored_beacons
```

**Test algorithm validation:**
```yaml
service: script.test_algorithm_sanity_check
```

---

## Important Notes

### CSV Format is Critical
- `:X` must come AFTER RSSI value: `MAC=RSSI:X`
- No spaces around `=` or `,`
- Case-insensitive (normalized to uppercase)

### Storage Patterns
- **File + Sensor Attributes:** Same proven pattern as fingerprints and scans
- **No Entity Size Limits:** Uses sensor attributes, not state
- **Unlimited Capacity:** File system limited, not Home Assistant

### Algorithm Changes are Safe
- Only affects scoring/filtering logic
- All ignored beacons are skipped
- Both local and global ignored checked
- Performance remains constant

---
