# C5: only a project gets mounted: the git repo, or the nearest folder marked with .airlock.
source "$(dirname "$0")/../lib.sh"

# refuses <regex>: airlock must fail here, and for the stated reason.
refuses() {
  local out; out=$("$AIRLOCK" run node true 2>&1) && { echo "it ran"; return 1; }
  [[ $out =~ $1 ]] || { echo "failed, but not for the expected reason: $out"; return 1; }
}
t_home()    { cd "$HOME" && refuses "contains your home folder|not in a project"; }
# A git repo, so the refusal comes from the outside-home guard, not the project rule.
# It lives outside $WORK, so it cleans up after itself.
t_outside() {
  local d=/tmp/airlock-test-outside rc=0
  mkdir -p "$d" && cd "$d" && git init -q && refuses "outside" || rc=$?
  cd / && rm -rf "$d"
  return $rc
}
t_plain() {
  mkdir -p "$WORK/plain/child" && echo s > "$WORK/plain/secret.txt" && cd "$WORK/plain/child"
  refuses "not in a project"
}
t_marked() {
  mkdir -p "$WORK/marked/sub" && touch "$WORK/marked/.airlock" && echo s > "$WORK/outside-marked.txt"
  cd "$WORK/marked/sub" || return 1
  "$AIRLOCK" run node node -e '
    const fs = require("fs"), [root, outside] = process.argv.slice(1);
    if (!fs.existsSync(root + "/.airlock")) { console.log("project root not mounted"); process.exit(1); }
    if (fs.existsSync(outside)) { console.log("saw a file outside the marked folder"); process.exit(1); }' \
    "$WORK/marked" "$WORK/outside-marked.txt"
}
t_git_subdir() {
  project scope-git; mkdir -p deep/er && echo s > "$WORK/outside-git.txt"; cd deep/er
  "$AIRLOCK" run node node -e '
    const fs = require("fs"), [root, outside] = process.argv.slice(1);
    if (!fs.existsSync(root + "/.git")) { console.log("repo root not mounted"); process.exit(1); }
    if (fs.existsSync(outside)) { console.log("saw a file outside the repo"); process.exit(1); }' \
    "$P" "$WORK/outside-git.txt"
}

# A project folder on PATH: the host runs what's in it, so package code must not get to write it.
t_on_path() {
  project scope-path; mkdir -p bin
  local out; out=$(PATH="$P/bin:$PATH" "$AIRLOCK" run node true 2>&1) && { echo "it ran"; return 1; }
  [[ $out == *"which the host runs"* ]] || { echo "failed, but not for the expected reason: $out"; return 1; }
}

check C5 "refuses the home folder"                         t_home
check C5 "refuses folders outside home"                    t_outside
check C5 "refuses a plain folder (no git, no .airlock)"    t_plain
check C5 "a .airlock folder works, and only it is mounted" t_marked
check C5 "from a repo subfolder, the repo is mounted, nothing above" t_git_subdir
check C5 "refuses a project holding a folder on PATH"        t_on_path
