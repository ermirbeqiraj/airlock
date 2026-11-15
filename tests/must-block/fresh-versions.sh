# C3: versions published in the last 7 days aren't installed.
# Uses packages that publish often (typescript@next nightly, boto3 near-daily). If the newest
# release is already older than 7 days, there's nothing to refuse: SKIP, not PASS.
source "$(dirname "$0")/../lib.sh"

TS_TIMES="$WORK/typescript-times.json"
curl -fs --compressed https://registry.npmjs.org/typescript | jq '.time' > "$TS_TIMES"
ts_time() { jq -r --arg v "$1" '.[$v]' "$TS_TIMES"; }
ts_newest_next() { jq -r 'to_entries | map(select(.key | test("-dev\\."))) | max_by(.value) | .key' "$TS_TIMES"; }

ts_fresh_exists() {
  local v; v=$(ts_newest_next)
  [ "$(age_of "$(ts_time "$v")")" -lt $((7 * DAY)) ] || { echo "newest typescript@next ($v) is already 7+ days old"; return 2; }
}

ts_installed_age_ok() {
  local v; v=$(node -p 'require("typescript/package.json").version') || return 1
  local age; age=$(age_of "$(ts_time "$v")")
  [ "$age" -ge $((7 * DAY)) ] || { echo "installed typescript $v is $((age / 3600))h old"; return 1; }
}

t_npm()  { ts_fresh_exists || return; project fresh-npm;  echo '{"name":"t","version":"1.0.0"}' > package.json; npm install typescript@next --no-audit >/dev/null 2>&1; ts_installed_age_ok; }
t_pnpm() { ts_fresh_exists || return; project fresh-pnpm; echo '{"name":"t","version":"1.0.0"}' > package.json; pnpm add typescript@next >/dev/null 2>&1; ts_installed_age_ok; }

t_uv() {
  local newest; newest=$(curl -fs https://pypi.org/pypi/boto3/json | jq -r '.info.version')
  [ "$(age_of "$(pypi_time boto3 "$newest")")" -lt $((7 * DAY)) ] || { echo "newest boto3 ($newest) is already 7+ days old"; return 2; }
  project fresh-uv
  printf '[project]\nname = "t"\nversion = "0.1.0"\nrequires-python = ">=3.12"\ndependencies = ["boto3"]\n\n[tool.uv]\npackage = false\nexclude-newer = "2099-01-01"\n' > pyproject.toml
  uv sync -q >/dev/null 2>&1 || { echo "uv sync failed"; return 1; }
  local v; v=$(uv run -q python -c 'import boto3; print(boto3.__version__)') || return 1
  local age; age=$(age_of "$(pypi_time boto3 "$v")")
  [ "$age" -ge $((7 * DAY)) ] || { echo "installed boto3 $v is $((age / 3600))h old"; return 1; }
}

check C3 "npm: typescript@next resolves to a 7+ day old build"  t_npm
check C3 "pnpm: typescript@next resolves to a 7+ day old build" t_pnpm
check C3 "uv: boto3 7+ days old, despite project exclude-newer" t_uv
