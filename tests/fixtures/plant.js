// Test fixture: package code trying to plant things the host runs or reads later (claim C4).
// Run inside airlock from the project root. Every attempt is caught; it prints what worked
// from the container's point of view. The test checks the host afterwards.
const fs = require("fs");
const path = require("path");

const tryIt = (name, fn) => {
  try { fn(); console.log("worked:", name); } catch (e) { console.log("blocked:", name, e.code); }
};
const write = (p, s) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, s); };
const PAYLOAD = "PLANTED by test fixture\n";

// Existing files: modify, replace, delete.
for (const p of ["CLAUDE.md", "AGENTS.md", ".claude/settings.json", ".mcp.json",
                 ".vscode/tasks.json", ".github/workflows/ci.yml", ".envrc", ".airlock"]) {
  tryIt(`modify ${p}`, () => fs.appendFileSync(p, PAYLOAD));
}
tryIt("delete AGENTS.md", () => fs.unlinkSync("AGENTS.md"));
tryIt("add a file inside existing .claude/", () => write(".claude/commands/x.md", PAYLOAD));

// New files that didn't exist before.
for (const p of ["CLAUDE.local.md", "sub/AGENTS.md", ".pi/agent/AGENTS.md",
                 ".idea/workspace.xml", ".devcontainer/devcontainer.json"]) {
  tryIt(`create ${p}`, () => write(p, PAYLOAD));
}

// Rename trick: move the folder holding a read-only file, plant a fresh one in its place.
tryIt("rename docs/ away and plant docs/CLAUDE.md", () => {
  fs.renameSync("docs", "docs-moved");
  write("docs/CLAUDE.md", PAYLOAD);
});

// Git: hooks and config run on the host.
tryIt("write .git/hooks/pre-commit", () => write(".git/hooks/pre-commit", "#!/bin/sh\n" + PAYLOAD));
tryIt("modify .git/config", () => fs.appendFileSync(".git/config", "[core]\n\thooksPath = /tmp\n"));
