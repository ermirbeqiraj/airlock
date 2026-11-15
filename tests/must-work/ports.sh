# Dev servers: reachable from this machine (C7: and only from it), whichever localhost they bind.
# Stopping the command stops its container.
source "$(dirname "$0")/../lib.sh"
project work-ports
V4=4391 V6=4392
for p in $V4 $V6; do (exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null && { echo "  port $p busy on host: skipping"; exit 0; }; done
printf 'ports=%s %s\n' $V4 $V6 > .airlock
cat > server.js <<EOF
const http = require("http");
const ok = (req, res) => res.end("ok");
http.createServer(ok).listen($V4, "127.0.0.1");
http.createServer(ok).listen($V6, "::1");
console.log("listening");
EOF

node server.js > server.log 2>&1 &
SHIM_PID=$!
timeout 30 bash -c 'until grep -q listening server.log; do sleep 0.3; done'

get() { curl -s -m 3 "http://$1:$2/"; }
lan_ip() { hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' | grep -v ':' | head -1; }

t_v4() { [ "$(get 127.0.0.1 $V4)" = ok ]; }
t_v6() { [ "$(get 127.0.0.1 $V6)" = ok ]; }
t_lan() {
  local ip; ip=$(lan_ip); [ -n "$ip" ] || { echo "no LAN address"; return 2; }
  local a b; a=$(get "$ip" $V4); b=$(get "$ip" $V6)
  [ -z "$a$b" ] || { echo "reachable on $ip"; return 1; }
}
t_busy() { [ "$(node -e 'console.log("second")')" = second ]; }
t_stop() {
  kill -TERM $SHIM_PID; timeout 15 bash -c "while kill -0 $SHIM_PID 2>/dev/null; do sleep 0.3; done" || { echo "airlock didn't exit"; return 1; }
  timeout 15 bash -c "while docker ps --format '{{.Command}}' | grep -q 'server.js'; do sleep 0.5; done" || { echo "container still running"; return 1; }
}

check ok "server on 127.0.0.1 inside reachable from host" t_v4
check ok "server on ::1 inside reachable from host"       t_v6
check C7 "not reachable from the LAN address"             t_lan
check ok "another command runs while the port is held"   t_busy
check ok "stopping the command stops its container"      t_stop
