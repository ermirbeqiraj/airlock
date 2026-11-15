# Normal Python (uv) work keeps working.
source "$(dirname "$0")/../lib.sh"
project work-python
printf '[project]\nname = "t"\nversion = "0.1.0"\nrequires-python = ">=3.12"\ndependencies = ["six"]\n\n[tool.uv]\npackage = false\n' > pyproject.toml

t_tools() { uv --version && uvx --version; }
t_sync()  { uv sync -q >/dev/null 2>&1 && uv run -q python -c 'import six'; }
t_not_on_host() { [ -z "$(ls -A .venv 2>/dev/null)" ] || { echo ".venv has files on the host"; return 1; }; }
t_python3_host() { [ "$(command -v python3)" != "$REPO/shims/python3" ]; }

# A project that is a package (entry points), built with uv's own backend.
t_package() {
  project work-python-pkg
  mkdir -p src/t && printf 'def main():\n    print("hello from t")\n' > src/t/__init__.py
  cat > pyproject.toml <<'EOF'
[project]
name = "t"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["six"]

[project.scripts]
t = "t:main"

[build-system]
requires = ["uv_build>=0.12.3,<0.13.0"]
build-backend = "uv_build"
EOF
  uv sync -q && [ "$(uv run -q t)" = "hello from t" ] && uv run -q python -c 'import six' &&
    uv add -q six && uv run -q t >/dev/null && uv sync -q --locked && uv run -q --frozen t >/dev/null
}

# A Python tool that runs on node (pyright): uses the image's pinned node, nothing to download.
t_pyright() {
  project work-python-pyright
  printf 'x: int = 1\n' > t.py
  printf '[project]\nname = "t"\nversion = "0.1.0"\nrequires-python = ">=3.12"\n\n[dependency-groups]\ndev = ["pyright"]\n\n[tool.uv]\npackage = false\n' > pyproject.toml
  local out; out=$(uv run pyright t.py 2>&1)
  [[ $out == *"0 errors"* ]] || { echo "$out"; return 1; }
}

check W2 "uv and uvx run"                      t_tools
check W2 "uv sync + uv run import works"       t_sync
check W3 ".venv stays off the host disk"       t_not_on_host
check W2 "a uv_build package: uv sync, uv run <entry point>, uv add, --locked/--frozen" t_package
check W2 "uv run pyright (a Python tool on node) works"  t_pyright
check W2 "python3 stays the host's (not shimmed)" t_python3_host
