#!/usr/bin/env bash
# Run the test suite: tests/run.sh [filter]   (filter matches file names, e.g. `plant`)
# Needs Docker and network (registry tests). Work files go to ~/.cache/airlock-tests.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export AIRLOCK_TEST_WORK=$HOME/.cache/airlock-tests
export AIRLOCK_TEST_RESULTS=$(mktemp)
export XDG_CACHE_HOME=$AIRLOCK_TEST_WORK/cache   # test quarantines stay in the work folder
mkdir -p "$AIRLOCK_TEST_WORK"

for f in "$here"/must-block/*.sh "$here"/must-work/*.sh; do
  [[ $(basename "$f") == *"${1:-}"* ]] || continue
  echo "== $(basename "$(dirname "$f")")/$(basename "$f")"
  bash "$f"
done

# Clean up: work folders, then the volumes that belonged to them.
rm -rf "$AIRLOCK_TEST_WORK"
"$here/../bin/airlock" prune >/dev/null

pass=$(grep -c '^PASS' "$AIRLOCK_TEST_RESULTS"); fail=$(grep -c '^FAIL' "$AIRLOCK_TEST_RESULTS")
skip=$(grep -c '^SKIP' "$AIRLOCK_TEST_RESULTS")
echo; echo "$pass passed, $fail failed, $skip skipped"
[ "$fail" -gt 0 ] && { echo "Broken claims:"; grep '^FAIL' "$AIRLOCK_TEST_RESULTS" | cut -d' ' -f2- | sed 's/^/  /'; }
rm -f "$AIRLOCK_TEST_RESULTS"
[ "$fail" -eq 0 ]
