# C2: package code can't run at install time, and a project's own config can't turn it back on.
# Each attack has a control: the same install with the rule switched off inside the container
# must leave the marker. Without that, a broken fixture would "pass" by doing nothing.
source "$(dirname "$0")/../lib.sh"

# --- npm: dependency postinstall + root postinstall, project .npmrc tries to allow scripts
npm_project() {
  project scripts-npm
  fixture npm-postinstall evil "$(marker npm-dep)"
  npm pack ./evil >/dev/null 2>&1
  cat > package.json <<EOF
{ "name": "t", "version": "1.0.0",
  "scripts": { "postinstall": "node -e \"require('fs').writeFileSync('$(marker npm-root)', 'x')\"" },
  "dependencies": { "evil-postinstall": "file:./evil-postinstall-1.0.0.tgz" } }
EOF
  printf 'ignore-scripts=false\n' > .npmrc
}
t_npm() {
  npm_project
  npm install --no-audit >/dev/null 2>&1
  local hit=""; for m in npm-dep npm-root; do [ -e "$(marker $m)" ] && hit+="$m "; done
  [ -z "$hit" ] || { echo "ran: $hit"; return 1; }
}
t_npm_control() {
  npm_project
  npm install --no-audit --ignore-scripts=false >/dev/null 2>&1
  [ -e "$(marker npm-dep)" ] || { echo "fixture never ran, even with scripts on"; return 2; }
}

# --- pnpm: same, project pnpm-workspace.yaml tries to allow scripts and builds
pnpm_project() {
  project scripts-pnpm
  fixture npm-postinstall evil "$(marker pnpm-dep)"
  npm pack ./evil >/dev/null 2>&1
  cat > package.json <<EOF
{ "name": "t", "version": "1.0.0",
  "scripts": { "postinstall": "node -e \"require('fs').writeFileSync('$(marker pnpm-root)', 'x')\"" },
  "dependencies": { "evil-postinstall": "file:./evil-postinstall-1.0.0.tgz" } }
EOF
  printf 'ignoreScripts: false\ndangerouslyAllowAllBuilds: true\n' > pnpm-workspace.yaml
}
t_pnpm() {
  pnpm_project
  pnpm install >/dev/null 2>&1
  local hit=""; for m in pnpm-dep pnpm-root; do [ -e "$(marker $m)" ] && hit+="$m "; done
  [ -z "$hit" ] || { echo "ran: $hit"; return 1; }
}
t_pnpm_control() {
  pnpm_project
  airlock_env=(env pnpm_config_ignore_scripts=false)
  "$AIRLOCK" run node "${airlock_env[@]}" pnpm install >/dev/null 2>&1
  [ -e "$(marker pnpm-root)" ] || { echo "fixture never ran, even with scripts on"; return 2; }
}

# --- uv: source build of a local package, project tries to allow builds
uv_project() {
  project scripts-uv
  fixture py-setup evil "$(marker uv-build)"
  cat > pyproject.toml <<'EOF'
[project]
name = "t"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["evil-setup"]

[tool.uv]
package = false
no-build = false

[tool.uv.pip]
no-build = false

[tool.uv.sources]
evil-setup = { path = "evil" }
EOF
  uv venv --allow-existing -q >/dev/null 2>&1
}
t_uv_sync() { uv_project; uv sync >/dev/null 2>&1; [ ! -e "$(marker uv-build)" ]; }
t_uv_pip()  { uv_project; uv pip install ./evil >/dev/null 2>&1; [ ! -e "$(marker uv-build)" ]; }
t_uv_control() {
  uv_project
  "$AIRLOCK" run python env -u UV_CONFIG_FILE -u UV_NO_BUILD uv pip install ./evil >/dev/null 2>&1
  [ -e "$(marker uv-build)" ] || { echo "fixture never ran, even with builds on"; return 2; }
}

t_pip() {
  project scripts-pip
  local out; out=$(pip install six 2>&1) && { echo "pip ran"; return 1; }
  [[ $out == *disabled* ]] || { echo "$out"; return 1; }
}

# Attack first, control second: once the control installs the package, a later attack run
# would find it already installed and "pass" without its script ever having a chance.
check C2 "npm: dependency + root postinstall blocked despite .npmrc" t_npm
check C2 "control: npm fixture runs when scripts are on"          t_npm_control
check C2 "pnpm: postinstall blocked despite pnpm-workspace.yaml"  t_pnpm
check C2 "control: pnpm fixture runs when scripts are on"         t_pnpm_control
check C2 "uv sync: source build blocked despite [tool.uv]"        t_uv_sync
check C2 "uv pip install: source build blocked despite [tool.uv.pip]" t_uv_pip
check C2 "control: uv fixture builds when builds are on"          t_uv_control
check C2 "pip refuses to run"                                     t_pip
