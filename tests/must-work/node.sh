# Normal node work keeps working.
source "$(dirname "$0")/../lib.sh"
project work-node
cat > package.json <<'EOF'
{ "name": "t", "version": "1.0.0", "scripts": { "hello": "node -e \"console.log('run works')\"" } }
EOF

t_tools()   { node -v && npm -v && pnpm -v && npx --version; }
t_install() { npm install is-number --no-audit >/dev/null 2>&1 && node -e 'process.exit(require("is-number")(5) ? 0 : 1)'; }
t_not_on_host() { [ -z "$(ls -A node_modules 2>/dev/null)" ] || { echo "node_modules has files on the host"; return 1; }; }
t_script()  { [ "$(npm run -s hello)" = "run works" ]; }
t_pnpm() {
  project work-pnpm; echo '{"name":"t","version":"1.0.0"}' > package.json
  pnpm add is-number >/dev/null 2>&1 && node -e 'process.exit(require("is-number")(5) ? 0 : 1)'
}
t_owner() { node -e 'require("fs").writeFileSync("made-inside.txt", "x")' && [ "$(stat -c %u made-inside.txt)" = "$(id -u)" ]; }
t_tz() {
  local host inside; host=$(date +%z)
  inside=$(node -e 'const o = -new Date().getTimezoneOffset(), s = o < 0 ? "-" : "+", a = Math.abs(o);
                    console.log(s + String(Math.floor(a / 60)).padStart(2, "0") + String(a % 60).padStart(2, "0"))')
  [ "$host" = "$inside" ] || { echo "host $host, container $inside"; return 1; }
}

check ok "node, npm, pnpm, npx run"                     t_tools
check ok "npm install + require works"                  t_install
check ok "node_modules stays off the host disk"         t_not_on_host
check ok "npm run <script> works"                       t_script
check ok "pnpm add + require works"                     t_pnpm
check ok "files made inside are owned by you"           t_owner
check ok "container uses the host timezone"             t_tz
