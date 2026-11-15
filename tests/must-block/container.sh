# C6: package code can't take over the container or reach the machine.
# C8: what's pinned stays pinned.
source "$(dirname "$0")/../lib.sh"
project container

inside() { node -e "$1"; }

t_user()  { inside 'process.exit(process.getuid() === 0 ? 1 : 0)'; }
t_caps()  { inside 'const s = require("fs").readFileSync("/proc/self/status", "utf8");
                    const cap = s.match(/^CapEff:\s*(\w+)/m)[1];
                    if (!/^0+$/.test(cap)) { console.log("CapEff", cap); process.exit(1); }'; }
t_nnp()   { inside 'const s = require("fs").readFileSync("/proc/self/status", "utf8");
                    process.exit(/^NoNewPrivs:\s*1/m.test(s) ? 0 : 1)'; }
t_sysro() { inside 'try { require("fs").writeFileSync("/usr/local/bin/evil", "x"); process.exit(1) } catch { process.exit(0) }'; }
t_limits() { inside 'const fs = require("fs"), r = f => fs.readFileSync("/sys/fs/cgroup/" + f, "utf8").trim();
                     const mem = r("memory.max"), pids = r("pids.max");
                     if (mem === "max" || pids === "max") { console.log("memory", mem, "pids", pids); process.exit(1); }'; }

t_pinned_images() {
  local bad; bad=$(grep -h '^FROM\|COPY --from' "$REPO"/bases/*/Dockerfile | grep -v '@sha256:[0-9a-f]\{64\}')
  [ -z "$bad" ] || { echo "not pinned by digest: $bad"; return 1; }
}
t_pinned_tools() {
  local bad; bad=$(grep -h 'install -g' "$REPO"/bases/*/Dockerfile | grep -oE '[a-z@/-]+@[^ ]+' | grep -vE '@[0-9]+\.[0-9]+\.[0-9]+$')
  [ -z "$bad" ] || { echo "not an exact version: $bad"; return 1; }
}

check C6 "runs as a non-root user"                   t_user
check C6 "no Linux capabilities"                     t_caps
check C6 "privilege escalation disabled"             t_nnp
check C6 "system files are read-only"                t_sysro
check C6 "memory and process limits set"             t_limits
check C8 "base images pinned by digest"              t_pinned_images
check C8 "globally installed tools pinned exactly"   t_pinned_tools
