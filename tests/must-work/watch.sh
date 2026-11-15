# Edits on the host reach file watchers inside (hot reload).
source "$(dirname "$0")/../lib.sh"
project work-watch
mkdir -p src && echo a > src/file.txt

t_watch() {
  node -e '
    require("fs").watch("src", { recursive: true }, () => { console.log("event"); process.exit(0) });
    console.log("watching");
    setTimeout(() => process.exit(1), 10000);' > watch.log 2>&1 &
  local pid=$!
  timeout 15 bash -c 'until grep -q watching watch.log; do sleep 0.2; done'
  echo b >> src/file.txt
  wait $pid && grep -q event watch.log
}

check W5 "a host edit reaches a watcher inside" t_watch
