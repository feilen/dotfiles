#!/usr/bin/env node
import { readFileSync, existsSync, unlinkSync } from 'fs';
import { spawnSync } from 'child_process';

function sleep(ms) {
  spawnSync('sleep', [(ms / 1000).toString()]);
}

function main() {
  const input = JSON.parse(readFileSync(0, 'utf8'));

  const cmd = input.tool_input?.command || '';
  if (!/\bgit\s+commit\b/.test(cmd)) {
    process.exit(0);
  }

  const cwd = input.cwd;
  const resultFile = `/tmp/commit-review-${process.pid}.json`;

  if (existsSync(resultFile)) {
    unlinkSync(resultFile);
  }

  const promptScript = '/home/feilen/.claude/hooks/git-commit-review-prompt.sh';

  const paneResult = spawnSync('tmux', [
    'split-window', '-h', '-P', '-F', '#{pane_id}',
    '-c', cwd,
    'bash', promptScript, cwd, resultFile
  ], { encoding: 'utf8' });

  const paneId = paneResult.stdout.trim();

  spawnSync('tmux', ['resize-pane', '-t', paneId, '-x', '163']);

  while (true) {
    const checkResult = spawnSync('tmux', ['list-panes', '-F', '#{pane_id}'], { encoding: 'utf8' });
    if (!checkResult.stdout.includes(paneId)) {
      break;
    }
    sleep(200);
  }

  if (!existsSync(resultFile)) {
    console.log(JSON.stringify({
      decision: 'block',
      reason: 'Commit review was cancelled (no response)'
    }));
    process.exit(0);
  }

  const result = JSON.parse(readFileSync(resultFile, 'utf8'));
  unlinkSync(resultFile);

  if (result.accept) {
    process.exit(0);
  }

  console.log(JSON.stringify({
    decision: 'block',
    reason: `User rejected commit: ${result.reason || 'no reason given'}`
  }));
}

main();
