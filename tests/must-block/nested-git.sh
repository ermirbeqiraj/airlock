# C4: package code can't plant git metadata the host runs later. Only the TOP-LEVEL
# .git is protected (mounted read-only, pruned from the planting check). A nested
# `.git` file (worktree/submodule style) is writable and untracked: package code can
# point it at a gitdir it planted in the repo, and the host's git then runs its hooks.
source "$(dirname "$0")/../lib.sh"
project nested-git
echo '{"name":"t","version":"1.0.0"}' > package.json
git add -A && git -c user.email=t@t -c user.name=t commit -qm init

# Run 1: package code plants sub/.git -> evilgit/ (with a pre-commit hook) inside the repo.
OUT=$(node -e '
  const fs = require("fs"), path = require("path"), root = process.cwd();
  fs.mkdirSync("sub", { recursive: true });
  for (const d of ["evilgit/hooks", "evilgit/objects", "evilgit/refs"]) fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync("sub/.git", "gitdir: " + path.join(root, "evilgit") + "\n");
  fs.writeFileSync("evilgit/HEAD", "ref: refs/heads/main\n");
  fs.writeFileSync("evilgit/config", "[core]\n\trepositoryformatversion = 0\n");
  fs.writeFileSync("evilgit/hooks/pre-commit", "#!/bin/sh\ntouch " + path.join(root, "sub", "PWNED-hook") + "\n");
  fs.chmodSync("evilgit/hooks/pre-commit", 0o755);
' 2>&1); RC=$?

t_silent() {
  [ "$RC" -ne 0 ] || { echo "command exited 0, no quarantine warning"; return 1; }
  [[ $OUT == *quarantine* ]] || { echo "failed but no quarantine warning: $OUT"; return 1; }
}
# The pointer must go: it's what makes host git use the planted gitdir. evilgit/ itself is a
# plain folder, writable repo content like any other (N2); without the pointer it's only
# reachable by running git inside it (N9 in docs/threat-model.md).
t_not_left() {
  [ ! -e sub/.git ] || { echo "left on host: sub/.git"; return 1; }
}
t_hook() {
  # What the host does later: run git inside sub/. If the plant survived, the planted
  # hook executes on the host.
  git -C sub -c user.email=t@t -c user.name=t commit --allow-empty -qm x >/dev/null 2>&1
  if [ -e sub/PWNED-hook ]; then echo "planted pre-commit executed on the host: sub/PWNED-hook"; return 1; fi
}

check C4 "planting a nested .git fails the command with a warning" t_silent
check C4 "a planted nested .git is not left on the host"           t_not_left
check C4 "a planted git hook never runs on the host"                t_hook
