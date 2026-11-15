# C5/C1: the mount-scope checks compare the LOGICAL $PWD-derived root as a string, but
# the docker mount follows symlinks. cd through a symlink planted in the repo
# (proj/home -> $HOME) and the nearest .airlock is found through the link: root is the
# logical path (passes "contains home" / "outside home" / "contains airlock or PATH dir"),
# yet the mount resolves to $HOME — the whole home folder lands inside the container.
source "$(dirname "$0")/../lib.sh"

P="$WORK/scope-symlink"
docker volume ls -q --filter "label=airlock.path=$P" | xargs -r docker volume rm >/dev/null
rm -rf "$P" && mkdir -p "$P" && cd "$P"

# Test-only files in $HOME, removed on exit. (In the wild: ~/.airlock exists, and
# package code plants the symlink; a README step "cd home && npm install" suffices.)
CANARY="$HOME/.airlock-pov-canary"
touch "$HOME/.airlock" "$CANARY"
trap 'rm -f "$HOME/.airlock" "$CANARY"' EXIT

ln -s "$HOME" home   # planted symlink: plain name, not protected
cd "$P/home"         # logical PWD through the link

# A refusal is a pass too; only a container that sees the canary is a fail.
t_home_not_mounted() {
  local out; out=$(node -e 'if (require("fs").existsSync(process.argv[1])) console.log("MOUNTED")' \
    "$P/home/.airlock-pov-canary" 2>&1)
  [[ $out != *MOUNTED* ]] || { echo "host home folder mounted inside the container via the symlinked PWD"; return 1; }
}

check C5 "cd through a planted symlink never mounts the link's target (here: \$HOME)" t_home_not_mounted
