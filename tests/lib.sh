# tests/lib.sh — helpers shared by every test file. Plain bash, no installs.
#
# A test file defines small functions and calls:
#   check <claim> <description> <function>   PASS when the function returns 0
# A function returns 0 = as claimed, 1 = claim broken, 2 = SKIP (the test can't prove anything
# right now, e.g. no fresh version exists to try).
#
# Attacks are harmless: "success" only leaves a marker file. Fixtures are generated locally,
# never published, and run inside airlock like any package would.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AIRLOCK=$REPO/bin/airlock
export PATH="$REPO/shims:$PATH"
WORK=${AIRLOCK_TEST_WORK:-$HOME/.cache/airlock-tests}
RESULTS=${AIRLOCK_TEST_RESULTS:-/dev/null}
DAY=86400

# project <name>: fresh git repo under $WORK, cd into it, path in $P.
# Also drops the project's deps volumes: they're keyed by path and would survive the folder,
# so a "fresh" project would still have last run's node_modules.
project() {
  P="$WORK/$1"
  docker volume ls -q --filter "label=airlock.path=$P" | xargs -r docker volume rm >/dev/null
  rm -rf "$P" && mkdir -p "$P" && cd "$P" && git init -q
}

# marker <name>: absolute path of a marker file inside the current project.
marker() { echo "$P/PWNED-$1"; }

# fixture <name> <dest> <marker>: copy tests/fixtures/<name> to <dest>, filling in the marker.
fixture() {
  cp -r "$REPO/tests/fixtures/$1" "$2"
  grep -rl '@MARKER@' "$2" | xargs -r sed -i "s|@MARKER@|$3|g"
}

check() {
  local claim=$1 desc=$2 fn=$3 out rc
  out=$("$fn" 2>&1); rc=$?
  case $rc in
    0) printf '  \e[32mPASS\e[0m %-3s %s\n' "$claim" "$desc"; echo "PASS $claim $desc" >> "$RESULTS" ;;
    2) printf '  \e[33mSKIP\e[0m %-3s %s\n' "$claim" "$desc"; echo "SKIP $claim $desc" >> "$RESULTS"
       [ -n "$out" ] && printf '%s\n' "$out" | tail -2 | sed 's/^/           /' ;;
    *) printf '  \e[31mFAIL\e[0m %-3s %s\n' "$claim" "$desc"; echo "FAIL $claim $desc" >> "$RESULTS"
       [ -n "$out" ] && printf '%s\n' "$out" | tail -6 | sed 's/^/           /' ;;
  esac
  return 0
}

# Age in seconds of an ISO timestamp.
age_of() { echo $(( $(date +%s) - $(date -d "$1" +%s) )); }

# npm registry publish time of <pkg> <version>, PyPI upload time of <pkg> <version>.
npm_time()  { curl -fs "https://registry.npmjs.org/$1" | jq -r --arg v "$2" '.time[$v]'; }
pypi_time() { curl -fs "https://pypi.org/pypi/$1/$2/json" | jq -r '.urls[0].upload_time_iso_8601'; }
