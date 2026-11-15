# airlock

Agents and editors work on the host. Project code (installs, builds, tests, dev servers) runs
in throwaway containers, so npm/PyPI package code never runs with your rights.

## How

- `shims/` (`node npm npx pnpm uv uvx pip`) goes first on PATH: `pnpm test` runs as
  `airlock run node pnpm test`. `python3` stays the host's; project Python runs via `uv run`.
- `bases/`: one pinned image per runtime. Edit one and the next run rebuilds it.
- Each run: a fresh container with only the project mounted, deps in a volume, nothing of
  yours inside. Install scripts and source builds off, versions 7+ days old. `pip` refuses:
  use `uv pip`.

What's protected, what isn't, and why: [docs/threat-model.md](docs/threat-model.md).

## Use

- A project is a git repo, or a folder with an `.airlock` file. Anywhere else airlock refuses.
- Dev server ports: `ports=4321` in `.airlock`, published on 127.0.0.1 only.
- Host services (e.g. compose Postgres): `host_ports=5432` in `.airlock` makes them answer on
  localhost inside.
- Agent/editor/CI config planted during a run is moved to `~/.cache/airlock/quarantine/`.
- Limits: folders under `$HOME` only (Docker Desktop), ~0.2 s per command, editors don't see
  `node_modules`/`.venv`. Tools with their own runtime (e.g. pi) run on the host.

```
airlock run <base> <cmd...> | shell <base> | build <base> | status | prune
tests/run.sh [filter]   # harmless fake attacks for every claim + what must keep working
```
