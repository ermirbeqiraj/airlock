# A planted `.git` must not expose the host (C1) or survive the run (C4).
# Found by an independent red-team run: airlock bind-mounted $root/.git whenever it existed,
# Docker followed a `.git -> $HOME` link, and the whole home folder became readable inside.
# The after-run check skipped .git, so the link survived for the next run.
# Affects .airlock-marked folders that aren't git repos (in a repo, .git is a read-only mount).
source "$(dirname "$0")/../lib.sh"

# A stand-in host secret outside the project.
SECRET_REL=.cache/airlock-pov-secret.txt
SECRET=$HOME/$SECRET_REL
echo "host secret" > "$SECRET"

marked_project() {
  P="$WORK/$1"
  docker volume ls -q --filter "label=airlock.path=$P" | xargs -r docker volume rm >/dev/null
  rm -rf "$P" && mkdir -p "$P" && cd "$P" && touch .airlock
}

# C4: package code plants .git -> $HOME during a run. It must not be left in the folder.
t_planted_removed() {
  marked_project dotgit-plant
  local out; out=$(node -e 'require("fs").symlinkSync(process.argv[1], ".git")' "$HOME" 2>&1) &&
    { echo "run succeeded: planting wasn't reported"; return 1; }
  [[ $out == *quarantine* ]] || { echo "no quarantine warning: $out"; return 1; }
  if [ -L "$P/.git" ] || [ -e "$P/.git" ]; then echo ".git still in the folder after the run"; return 1; fi
}

# C1: say a .git link is there anyway (it survived, or something else made it). The next run
# must not mount what it points to.
t_link_not_mounted() {
  marked_project dotgit-link
  ln -s "$HOME" .git
  local out; out=$(node -e '
    const fs = require("fs"), rel = process.argv[1];
    if (fs.existsSync(".git/" + rel)) { console.log("host file readable via .git: .git/" + rel); process.exit(1); }
    if (fs.existsSync(".git/.ssh"))    { console.log("host ~/.ssh visible via .git"); process.exit(1); }
  ' "$SECRET_REL" 2>&1)
  local rc=$?
  [[ $out == *"host file readable"* || $out == *"visible via .git"* ]] && { echo "$out"; return 1; }
  [ $rc -ne 0 ] && [[ $out == *"is a link"* ]] || { echo "expected a refusal, got (rc=$rc): $out"; return 1; }
}

check C4 "a .git planted during a run is quarantined"          t_planted_removed
check C1 "a .git link is refused, never mounted"               t_link_not_mounted

rm -f "$SECRET"
