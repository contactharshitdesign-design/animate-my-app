#!/usr/bin/env node
// npx animate-my-app            → installs the skill for you (~/.claude/skills/animate-my-app)
// npx animate-my-app --project  → installs it into this project (./.claude/skills/animate-my-app)
// add --force to replace an existing copy (the old one is kept as a timestamped backup)
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  console.log('Usage: npx animate-my-app [--project] [--force]');
  process.exit(0);
}
const project = args.includes('--project');
const force = args.includes('--force');
const src = path.join(__dirname, '..', 'skills', 'animate-my-app');
const root = project ? path.join(process.cwd(), '.claude', 'skills') : path.join(os.homedir(), '.claude', 'skills');
const dest = path.join(root, 'animate-my-app');

if (!fs.existsSync(path.join(src, 'SKILL.md'))) { console.error('animate-my-app: the packaged skill is missing.'); process.exit(1); }
fs.mkdirSync(root, { recursive: true });
if (fs.existsSync(dest)) {
  if (!force) {
    console.log(`animate-my-app is already installed at ${dest}\nRun again with --force to replace it (your current copy is backed up).`);
    process.exit(0);
  }
  // backups live outside the skills folder, or Claude would load them as a second copy of the skill
  const backups = path.join(os.homedir(), '.claude', 'skill-backups');
  fs.mkdirSync(backups, { recursive: true });
  const backup = path.join(backups, `animate-my-app-${new Date().toISOString().replace(/[:.]/g, '-')}`);
  fs.renameSync(dest, backup);
  console.log(`Backed up the old copy to ${backup}`);
}
fs.cpSync(src, dest, { recursive: true });
for (const f of ['new_app.sh']) {               // keep scripts executable
  const p = path.join(dest, 'scripts', f);
  if (fs.existsSync(p)) fs.chmodSync(p, 0o755);
}
console.log(`Installed animate-my-app → ${dest}`);
console.log('Restart Claude Code (or run /reload-skills), then ask it to animate your app design.');
