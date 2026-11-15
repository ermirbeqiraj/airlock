# C4: package code can't modify airlock's own code. The shims execute bin/airlock on the
# HOST on every call, so when the mounted project contains the airlock installation
# (e.g. running from the airlock repo itself), bin/airlock must be protected like any
# other file the host runs. Currently it is writable through the repo mount and the
# after-run check doesn't track it: the edit lands silently and the next shim call
# would run it on the host as you.
source "$(dirname "$0")/../lib.sh"

cd "$REPO"
backup=$(mktemp)
cp -a bin/airlock "$backup"
trap 'cp -a "$backup" "$REPO/bin/airlock" 2>/dev/null; rm -f "$backup"' EXIT

OUT=$(node -e 'require("fs").appendFileSync("bin/airlock", "\n# PWNED\n")' 2>&1); RC=$?

t_untouched() { cmp -s "$backup" "$REPO/bin/airlock" || { echo "bin/airlock was modified on the host"; return 1; }; }
t_failed()    { [ "$RC" -ne 0 ] || { echo "command exited 0: the edit succeeded silently"; return 1; }; }

check C4 "bin/airlock on the host is unchanged after the run" t_untouched
check C4 "editing airlock's own code fails the command"       t_failed
