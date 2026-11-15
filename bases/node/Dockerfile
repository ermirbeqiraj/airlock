# airlock base: node
# Pinned by digest, not by tag: the tag `node:24-slim` moves, the digest doesn't.
# To update: pick a new digest (older than 7 days), change it here; airlock rebuilds on next use.
# node 24.22.2, image built 2026-11-05.
FROM node:24.22.2-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9

# Package managers, exact versions, baked in at build time (no runtime downloads via corepack).
RUN npm install -g npm@11.21.2 pnpm@11.0.9 --ignore-scripts --no-fund --no-audit \
 && npm cache clean --force \
 && apt-get update && apt-get install -y --no-install-recommends socat tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY common/ /usr/local/bin/

# Safety settings as environment variables: they override a project's own .npmrc /
# pnpm config, so a repo can't switch install scripts back on.
ENV npm_config_ignore_scripts=true \
    npm_config_min_release_age=7 \
    npm_config_cache=/cache/npm \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    pnpm_config_ignore_scripts=true \
    pnpm_config_minimum_release_age=10080 \
    pnpm_config_store_dir=/cache/pnpm-store \
    HOME=/home/dev

USER node
ENTRYPOINT ["airlock-entry"]
