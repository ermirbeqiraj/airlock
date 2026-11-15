# C2: in a uv_build project, only the project may build, whatever package code wrote into
# pyproject.toml or uv.lock during an earlier run (N2). Found by red-team: the wrapper read
# uv.lock line by line, so a single-quoted `name = 'evil-static'` (valid TOML) dropped out of
# the no-build list and built under `uv sync --frozen`.
source "$(dirname "$0")/../lib.sh"

uvb_project() {
  project uvl-frozen
  fixture py-static evil "$(marker uvl-build)"
  mkdir -p src/t && touch src/t/__init__.py
  cat > pyproject.toml <<EOF
[project]
name = "t"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["evil-static"]
[build-system]
requires = ["uv_build>=0.12.3,<0.13.0"]
build-backend = "uv_build"
[tool.uv.sources]
evil-static = { path = "evil" }
EOF
  uv lock -q >/dev/null 2>&1
}

t_plain_sync_blocked() {
  uvb_project
  uv sync >/dev/null 2>&1
  [ ! -e "$(marker uvl-build)" ]
}
t_frozen_canonical_lock_blocked() {
  uvb_project
  uv sync --frozen >/dev/null 2>&1
  [ ! -e "$(marker uvl-build)" ]
}
t_frozen_edited_lock_builds() {
  uvb_project
  # what package code does to uv.lock during a previous run (N2): valid TOML, but the
  # wrapper's parser only matches double-quoted name lines
  sed -i 's/name = "evil-static"/name = '"'"'evil-static'"'"'/' uv.lock
  uv sync --frozen >/dev/null 2>&1
  [ ! -e "$(marker uvl-build)" ] || { echo "dependency built from source despite --frozen"; return 1; }
}

t_frozen_self_moved() {
  uvb_project
  # the project's own lock entry points at another folder, which would then get built
  sed -i 's|source = { editable = "." }|source = { directory = "evil" }|' uv.lock
  uv sync --frozen >/dev/null 2>&1
  [ ! -e "$(marker uvl-build)" ] || { echo "a folder named by the lock was built as the project"; return 1; }
}
t_fake_backend() {
  project uvl-fake-backend
  fixture py-static fx "$(marker uvl-fake)" && mv fx/* . && rmdir fx
  # The real backend is setuptools (runs setup.py); the uv_build lines sit inside a string.
  cat >> pyproject.toml <<'EOF'

[tool.fake]
x = """
build-backend = "uv_build"
requires = ["uv_build>=0.12.3,<0.13.0"]
"""
EOF
  uv sync >/dev/null 2>&1
  [ ! -e "$(marker uvl-fake)" ] || { echo "a non-uv_build project was allowed to build"; return 1; }
}

check C2 "uv sync: dependency source build blocked"                          t_plain_sync_blocked
check C2 "uv sync --frozen: dependency blocked with a canonical lock"        t_frozen_canonical_lock_blocked
check C2 "uv sync --frozen: dependency blocked even if uv.lock was edited"   t_frozen_edited_lock_builds
check C2 "uv sync --frozen: a lock can't point the project at another folder" t_frozen_self_moved
check C2 "a uv_build look-alike (real backend setuptools) can't build"       t_fake_backend
