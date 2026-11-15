# Threat model

**The threat:** code from npm or PyPI packages. It may be malicious from the start, or turn
malicious in a hijacked release. **Trusted:** you, your agents (Claude Code, pi) and your editor.
They run on the host. airlock is the wall between the two.

Every claim below has tests in `tests/` (tagged with its id). A claim without a passing test
is a hope, not a claim.

## Claims

| Id | Claim | Why it matters |
|----|-------|----------------|
| C1 | Package code can't read host secrets: no home folder, keys, tokens or host env vars. Only the project folder is visible. | This is what attackers come for. |
| C2 | Package code can't run at install time: npm/pnpm install scripts and Python source builds are blocked, and a project's own config can't turn them back on. | Install is the most common attack moment. It runs before you've even used the package. |
| C3 | Versions published in the last 7 days aren't installed. | Hijacked releases are usually caught and pulled within days. |
| C4 | Package code can't plant things the host runs or reads later: git hooks/config, agent config (`.claude/`, `CLAUDE.md`, `AGENTS.md`, `.mcp.json`, `.pi/`), editor and CI config (`.vscode/`, `.idea/`, `.github/`), `.envrc`, `.airlock`. Existing ones are read-only. New ones are moved to quarantine when the command ends, with a warning. | The host's agents and editor have full access. Planting instructions or hooks for them is a way out of the box. |
| C5 | Only a project gets mounted: the git repo you're in, or the nearest folder marked with `.airlock`. Never your home folder, a folder above it, or a plain folder. | Running `node` in `~/src` or `~/Dropbox` must not expose everything below it. |
| C6 | Package code can't take over the container or reach the machine: non-root, no capabilities, no privilege escalation, read-only system files, no Docker socket, memory and process limits. | Keeps the wall a wall. |
| C7 | Dev servers are reachable from this machine only (127.0.0.1), not from the LAN. | A dev server is unauthenticated code. |
| C8 | What's pinned stays pinned: base images by digest, tool versions exact. | You know what runs, and it changes only when you change it. |

## Findings (fixed, with tests)

- **C4 — renaming a parent folder bypasses read-only mounts** (probed 2026-11-15). Writing to
  a read-only-mounted `docs/CLAUDE.md` fails (EROFS) and renaming it fails (EBUSY), but
  renaming `docs/` to `docs-moved/` works: the original moves away and a fresh
  `docs/CLAUDE.md` can be planted. **Fix:** the after-run check compares contents. The moved
  original always shows up as a new protected path, and that's the evidence: then every
  changed protected path is restored from a backup taken before the run. Without evidence, a
  change is your own edit on the host during the run, and stays (tested both ways).
- **C1 — a planted `.git` link mounted the home folder** (found by an independent red-team
  session, 2026-11-15). In an `.airlock`-marked folder that isn't a git repo, package code
  could create `.git -> $HOME`. The after-run check skipped `.git`, so the link survived, and
  the next run's read-only `.git` mount followed it: the whole home folder became readable
  inside. Docker Desktop's "sharing your home directory" warning was the visible symptom.
  **Fix:** `.git` is never mounted through a link (airlock refuses to run), and a `.git` that
  appears during a run is quarantined. General rule: airlock never mounts a link.
- **C4 — a nested `.git` ran planted hooks on the host** (red-team, 2026-11-15). Only the top
  `.git` was protected; package code planted `sub/.git` pointing at a gitdir it wrote, and
  host `git -C sub commit` ran its hook. **Fix:** `.git` is protected at any depth.
- **C5 — a plain folder got mounted.** Outside a git repo, airlock mounted the current folder,
  e.g. all of `~/src`. **Fix:** a git repo or a folder marked with `.airlock` is required.

## Not claimed (accepted, for now)

| Id | Gap | Why accepted / mitigation |
|----|-----|---------------------------|
| N1 | The network is open, internet and LAN. Package code can call out or probe the LAN. | It needs the registry. Blocking only the LAN is more work than it's worth for now. |
| N2 | Package code can edit your source files (the repo is writable). | Builds need to write. You review diffs before committing. |
| N3 | Once the app runs, its dependencies' code runs (inside the container). | C2 only stops install-time code. The container (C1, C4–C6) is the real wall. C2 and C3 are extra layers. |
| N4 | Secrets inside the project (`.env`) are visible to package code. | The app needs them. Use dev-only keys. |
| N5 | A newly planted file (C4) exists until the command ends: minutes during a long dev-server run. | Detection runs at exit. Existing files are read-only throughout. |
| N6 | Escapes from Docker Desktop's VM or the kernel. | Out of scope. The VM is a second wall. |
| N7 | Production and deploys. | A different problem. |
| N8 | A trusted caller can relax the rules, e.g. `npm install --ignore-scripts=false` (command-line flags win). | Agents are told not to, and to ask first. |
| N9 | Package code can write a folder shaped like a bare git repo. Running git *inside* it may use its config. | Not reproduced with `git status` (2.53). Host fix: `git config --global safe.bareRepository explicit`. |
