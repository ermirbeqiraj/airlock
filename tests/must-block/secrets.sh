# C1: package code can't read host secrets. Only the project folder is visible.
source "$(dirname "$0")/../lib.sh"
project secrets

SECRETS=(.ssh .claude .config .gnupg Dropbox .npmrc .bashrc)

t_env() {
  AIRLOCK_TEST_SECRET=leak node -e 'process.exit(process.env.AIRLOCK_TEST_SECRET ? 1 : 0)'
}

t_home() {
  local p found=""
  for p in "${SECRETS[@]}"; do [ -e "$HOME/$p" ] && found+="$p "; done
  [ -n "$found" ] || { echo "none of ${SECRETS[*]} exist on the host: nothing to look for"; return 2; }
  node -e '
    const fs = require("fs"), [home, ...names] = process.argv.slice(1);
    const seen = names.filter(n => fs.existsSync(home + "/" + n));
    if (seen.length) { console.log("visible:", seen.join(" ")); process.exit(1); }' "$HOME" $found
}

t_symlink() {
  [ -d "$HOME/.ssh" ] || { echo "no ~/.ssh on the host"; return 2; }
  ln -sfn "$HOME/.ssh" leak
  node -e 'try { require("fs").readdirSync("leak"); process.exit(1) } catch { process.exit(0) }'
}

t_sibling() {
  mkdir -p "$WORK/secrets-sibling" && echo s > "$WORK/secrets-sibling/secret.txt"
  node -e 'process.exit(require("fs").existsSync(process.argv[1]) ? 1 : 0)' "$WORK/secrets-sibling/secret.txt"
}

t_docker_socket() {
  node -e '
    const fs = require("fs");
    const socks = ["/var/run/docker.sock", "/run/docker.sock", process.argv[1] + "/.docker/desktop/docker.sock"];
    const seen = socks.filter(s => fs.existsSync(s));
    if (seen.length) { console.log("visible:", seen.join(" ")); process.exit(1); }' "$HOME"
}

check C1 "host env vars aren't passed in"                t_env
check C1 "home secrets (~/.ssh, ~/.claude, …) not visible" t_home
check C1 "a repo symlink to ~/.ssh leads nowhere"         t_symlink
check C1 "a sibling folder outside the project isn't visible" t_sibling
check C1 "the Docker socket isn't reachable"              t_docker_socket
