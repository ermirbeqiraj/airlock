# The host's own services (e.g. compose Postgres) answer on localhost inside, for the ports
# listed as `host_ports=` in .airlock.
source "$(dirname "$0")/../lib.sh"
project work-host-ports
HP=4393
(exec 3<>/dev/tcp/127.0.0.1/$HP) 2>/dev/null && { echo "  port $HP busy on host: skipping"; exit 0; }
printf 'host_ports=%s\n' $HP > .airlock
mkdir -p srv && echo ok > srv/index.html
python3 -m http.server $HP --bind 127.0.0.1 --directory srv >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
timeout 10 bash -c "until (exec 3<>/dev/tcp/127.0.0.1/$HP) 2>/dev/null; do sleep 0.2; done"

fetch() { node -e 'fetch(process.argv[1]).then(r => r.text()).then(t => console.log(t.trim()))' "$1" 2>&1; }
t_v4()   { local o; o=$(fetch "http://127.0.0.1:$HP/"); [ "$o" = ok ] || { echo "$o"; return 1; }; }
t_name() { local o; o=$(fetch "http://localhost:$HP/"); [ "$o" = ok ] || { echo "$o"; return 1; }; }
t_py()   { local o; o=$(uv run --no-project python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:$HP/').read().decode().strip())" 2>&1); [ "${o##*$'\n'}" = ok ] || { echo "$o"; return 1; }; }

check W6 "a host service answers on 127.0.0.1 inside (node)" t_v4
check W6 "and on localhost"                                  t_name
check W6 "and from the python base"                          t_py
