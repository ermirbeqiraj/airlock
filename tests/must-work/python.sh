# Normal Python (uv) work keeps working.
source "$(dirname "$0")/../lib.sh"
project work-python
printf '[project]\nname = "t"\nversion = "0.1.0"\nrequires-python = ">=3.12"\ndependencies = ["six"]\n\n[tool.uv]\npackage = false\n' > pyproject.toml

t_tools() { uv --version && uvx --version; }
t_sync()  { uv sync -q >/dev/null 2>&1 && uv run -q python -c 'import six'; }
t_not_on_host() { [ -z "$(ls -A .venv 2>/dev/null)" ] || { echo ".venv has files on the host"; return 1; }; }
t_python3_host() { [ "$(command -v python3)" != "$REPO/shims/python3" ]; }

check ok "uv and uvx run"                      t_tools
check ok "uv sync + uv run import works"       t_sync
check ok ".venv stays off the host disk"       t_not_on_host
check ok "python3 stays the host's (not shimmed)" t_python3_host
