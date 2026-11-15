# C4: package code can't plant things the host runs or reads later.
# Existing protected files must come out unchanged. New ones must not be left on the host
# (quarantined), and airlock must say so and fail the command.
source "$(dirname "$0")/../lib.sh"
project plant

EXISTING=(CLAUDE.md AGENTS.md .claude/settings.json .mcp.json .vscode/tasks.json
          .github/workflows/ci.yml .envrc .airlock docs/CLAUDE.md)
NEW=(CLAUDE.local.md sub/AGENTS.md .pi/agent/AGENTS.md .idea/workspace.xml
     .devcontainer/devcontainer.json .claude/commands/x.md docs-moved/CLAUDE.md)

for f in "${EXISTING[@]}"; do mkdir -p "$(dirname "$f")"; echo "original $f" > "$f"; done
echo '{"name":"t","version":"1.0.0"}' > package.json
git add -A && git -c user.email=t@t -c user.name=t commit -qm init
before=$(cd "$P" && sha256sum "${EXISTING[@]}" .git/config; find .git/hooks -type f | sort)

cp "$REPO/tests/fixtures/plant.js" .
OUT=$(node plant.js 2>&1); RC=$?

t_existing() {
  local now; now=$(cd "$P" && sha256sum "${EXISTING[@]}" .git/config 2>&1; find .git/hooks -type f | sort)
  [ "$now" = "$before" ] || { diff <(echo "$before") <(echo "$now") | grep '^[<>]' | head -8; return 1; }
}
t_new() {
  local f left=""; for f in "${NEW[@]}"; do [ -e "$P/$f" ] && left+="$f "; done
  [ -z "$left" ] || { echo "left on host: $left"; return 1; }
}
t_reported() {
  [ "$RC" -ne 0 ] || { echo "command exited 0"; return 1; }
  [[ $OUT == *quarantine* ]] || { echo "no quarantine warning in output"; return 1; }
}
t_clean_run() {
  # A run that plants nothing must stay silent and succeed.
  local out; out=$(node -e 'console.log("hello")' 2>&1) || { echo "$out"; return 1; }
  [ "$out" = hello ] || { echo "unexpected output: $out"; return 1; }
}

t_host_edit_kept() {
  # You (or an agent) editing CLAUDE.md on the host during a long run is not an attack.
  project plant-host-edit; echo original > CLAUDE.md; echo '{"name":"t","version":"1.0.0"}' > package.json
  node -e 'console.log("started"); setTimeout(() => {}, 4000)' > run.log 2>&1 &
  local pid=$!
  timeout 20 bash -c 'until grep -q started run.log; do sleep 0.2; done'
  echo "edited on host" > CLAUDE.md
  wait $pid || { echo "run failed: $(cat run.log)"; return 1; }
  [ "$(cat CLAUDE.md)" = "edited on host" ] || { echo "host edit lost"; return 1; }
  ! grep -q quarantine run.log || { echo "flagged a host edit as planting"; return 1; }
}

check C4 "existing agent/editor/CI/git files unchanged"  t_existing
check C4 "newly planted files not left on the host"      t_new
check C4 "planting is reported and fails the command"    t_reported
check C4 "a clean run says nothing extra"                t_clean_run
check C4 "a host edit during a run is kept, not flagged" t_host_edit_kept
