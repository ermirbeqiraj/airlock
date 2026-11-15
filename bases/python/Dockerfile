# airlock base: python (uv)
# Pinned by digest, not by tag. 3.12 matches what the local projects target.
# To update: pick new digests (older than 7 days), change them here; airlock rebuilds on next use.
FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b

COPY --from=ghcr.io/astral-sh/uv:0.12.3@sha256:2d890623d310b57771ce840f0da5eed5fc6d657da05ffaa45d82797b53fa3abc /uv /uvx /usr/local/lib/airlock/
# Node, for Python tools that run on it (pyright). Same pinned image as the node base.
COPY --from=node:24.22.2-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 /usr/local/bin/node /usr/local/bin/
COPY --from=node:24.22.2-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9 /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm

RUN apt-get update && apt-get install -y --no-install-recommends socat tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -u 1000 -M -d /home/dev dev \
 && ln -s /usr/local/lib/airlock/uvx /usr/local/bin/uvx \
 && ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

COPY common/ /usr/local/bin/
COPY python/uv.toml python/uv-self.toml /etc/airlock/
# uv wrapper: lets a uv_build project build itself, nothing else (see the file).
COPY python/uv /usr/local/bin/uv

# Safety settings as environment variables / a named config file, so a project's
# pyproject or uv.toml can't relax them (tested).
# no-build: wheels only, never run a source package's build code (Python's install scripts).
# pip has no relative age option: prefer uv.
ENV UV_EXCLUDE_NEWER="7 days" \
    UV_NO_BUILD=1 \
    UV_CONFIG_FILE=/etc/airlock/uv.toml \
    UV_PYTHON_DOWNLOADS=never \
    UV_CACHE_DIR=/cache/uv \
    UV_LINK_MODE=copy \
    PYRIGHT_PYTHON_CACHE_DIR=/cache/pyright-python \
    npm_config_ignore_scripts=true \
    npm_config_min_release_age=7 \
    npm_config_cache=/cache/npm \
    PIP_ONLY_BINARY=:all: \
    PIP_CACHE_DIR=/cache/pip \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HOME=/home/dev

USER dev
ENTRYPOINT ["airlock-entry"]
