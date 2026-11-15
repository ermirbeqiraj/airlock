# airlock

Agents and editors work on the host. Project code (installs, builds, tests, dev servers)
runs in throwaway containers built from base images we maintain.

**Why:** zero trust in npm/PyPI packages. Their code runs with full user rights on the host
(SSH keys, tokens, Dropbox). In the container there's nothing to steal.

## How it works

- `shims/` holds `node npm npx pnpm uv uvx pip pip3`, all symlinks to `airlock`, first on PATH
  (`~/.bashrc`, `~/.config/fish/config.fish`). `pnpm test` becomes `airlock run node pnpm test`.
  `python3` is NOT shimmed: the OS and plain scripts need it. Project deps live only in the
  container, so project code runs through `uv run`.
- `bases/<name>/Dockerfile`: one base per runtime (`node`, `python`), pinned by digest, built
  from images at least 7 days old. `bases/common/` is shared. The image tag is a hash of those
  files: edit them and the next run rebuilds (older tags are removed).
- Each run is a fresh container: the repo mounted at its host path, `.git` read-only, deps
  (`node_modules`, `.venv`) in a per-project volume (never on host disk), a shared download
  cache, no host env/keys/home, non-root, read-only system files, memory and process limits.
- Blocks, set as env vars or a named config file in the image so a project can't override them
  (tested against `.npmrc`, `pnpm-workspace.yaml`, `[tool.uv]`, `[tool.uv.pip]`):
  - node: install scripts off; new versions must be 7+ days old.
  - python: no source builds (wheels only); new versions 7+ days old.
- `pip` refuses and points to `uv pip` (same commands): pip has no age rule and builds local
  source packages.
- Only a project gets mounted: the git repo you're in, or the nearest folder holding an
  `.airlock` file (empty is fine). Anywhere else, airlock refuses.
- Agent, editor and CI config (`.claude/`, `CLAUDE.md`, `AGENTS.md`, `.mcp.json`, `.pi/`,
  `.vscode/`, `.idea/`, `.github/`, `.envrc`, `.airlock`, …) is read-only inside. Files of
  that kind planted during a run are moved to `~/.cache/airlock/quarantine/` when it ends,
  with a warning, and the command fails.
- Ports: `ports=4321 3000` in `<repo>/.airlock`, published on 127.0.0.1 only (not the LAN).
  Servers that bind localhost work as-is (forwarded inside the container, IPv4 or IPv6). A port
  already in use is skipped (the running dev server owns it).

## Outside airlock, on purpose

- **pi** runs on the host with its own node in `~/.local/share/pi-node` (official build,
  checksum-verified). Its updates use that npm, which reads `~/.npmrc` (scripts off, 7 days).

## Limits (known, accepted for now)

- The network is open, LAN included.
- Package code can edit repo files (the repo is mounted read-write). Review diffs.
- Only folders under `$HOME` work (Docker Desktop's file sharing): not `/tmp`.
- ~0.2 s startup per command.
- Host editors don't see `node_modules`/`.venv`: no package types in IntelliSense.

## Commands

    airlock run <base> <cmd...>   airlock shell <base>   airlock build <base>
    airlock status                airlock prune

## Tests

`tests/run.sh [filter]` checks every claim in `docs/threat-model.md` with harmless fake
attacks (`tests/must-block/`), plus the things that must keep working (`tests/must-work/`).
Needs Docker and network. About a minute.
