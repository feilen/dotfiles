#!/usr/bin/env node

import { readFileSync } from 'fs';

const input = JSON.parse(readFileSync(0, 'utf8'));

if (input.tool_name !== 'Bash') {
  process.exit(0);
}

const cmd = input.tool_input?.command || '';

const hasFindExec = /find\s+.*-exec\s+(grep|rg|cat|head|tail|wc|xargs)/i.test(cmd);
const hasFindPipeGrep = /find\s+.*\|\s*(xargs\s+)?(grep|rg)/i.test(cmd);
const hasFindNameGrep = /find\s+[^\|]+(-name|-iname)\s+['"][^'"]*['"]\s*.*-exec\s+grep/i.test(cmd);

if (!hasFindExec && !hasFindPipeGrep) {
  process.exit(0);
}

const RG_TYPES = {
  py: 'py', python: 'py',
  js: 'js', mjs: 'js', cjs: 'js',
  ts: 'ts', mts: 'ts', cts: 'ts', tsx: 'ts',
  rs: 'rust',
  go: 'go',
  c: 'c', h: 'c',
  cpp: 'cpp', cc: 'cpp', cxx: 'cpp', hpp: 'cpp', hxx: 'cpp',
  java: 'java',
  rb: 'ruby',
  sh: 'sh', bash: 'sh', zsh: 'sh',
  md: 'md', markdown: 'md',
  json: 'json',
  yaml: 'yaml', yml: 'yaml',
  html: 'html', htm: 'html',
  css: 'css', scss: 'css', sass: 'css',
  xml: 'xml',
  lua: 'lua',
  php: 'php',
  swift: 'swift',
  kt: 'kotlin', kts: 'kotlin',
  scala: 'scala',
  clj: 'clojure', cljs: 'clojure', cljc: 'clojure',
  ex: 'elixir', exs: 'elixir',
  hs: 'haskell',
  vim: 'vim',
  sql: 'sql',
  toml: 'toml',
  tf: 'tf',
  proto: 'protobuf',
};

function suggestRgAlternative(cmd) {
  const pathMatch = cmd.match(/find\s+(\S+)/);
  const searchPath = pathMatch?.[1] || '.';

  // Extract -name or -iname pattern (full pattern, not just extension)
  // Handle quoted patterns (single or double) and unquoted patterns separately
  const nameQuotedMatch = cmd.match(/-name\s+["']([^"']+)["']/);
  const nameUnquotedMatch = cmd.match(/-name\s+([^\s"']+)/);
  const inameQuotedMatch = cmd.match(/-iname\s+["']([^"']+)["']/);
  const inameUnquotedMatch = cmd.match(/-iname\s+([^\s"']+)/);

  const namePattern = nameQuotedMatch?.[1] || nameUnquotedMatch?.[1] ||
                      inameQuotedMatch?.[1] || inameUnquotedMatch?.[1];
  const caseInsensitive = !!(inameQuotedMatch || inameUnquotedMatch);

  // Check if pattern is just an extension (*.ext) vs a filename glob (foo*.txt)
  const extOnlyMatch = namePattern?.match(/^\*\.([a-zA-Z0-9]+)$/);
  const isComplexGlob = namePattern && !extOnlyMatch;

  // Extract grep pattern
  const grepQuotedMatch = cmd.match(/grep\s+(?:-[a-zA-Z]+\s+)*["']([^"']+)["']/);
  const grepUnquotedMatch = cmd.match(/grep\s+(?:-[a-zA-Z]+\s+)*(\S+)/);
  let grepPattern = grepQuotedMatch?.[1] || grepUnquotedMatch?.[1] || '';
  grepPattern = grepPattern.replace(/[{}\\;+]+$/, '').trim();
  if (!grepPattern || grepPattern === '-l' || grepPattern === '-r' || grepPattern.startsWith('-')) {
    grepPattern = '';
  }

  const hasContentSearch = /grep|rg/.test(cmd) && grepPattern;

  // Build file filtering part
  let fileFilter = '';
  if (extOnlyMatch) {
    const ext = extOnlyMatch[1].toLowerCase();
    const rgType = RG_TYPES[ext];
    if (rgType && !caseInsensitive) {
      fileFilter = `-t ${rgType}`;
    } else {
      fileFilter = caseInsensitive ? `--iglob '*.${ext}'` : `-g '*.${ext}'`;
    }
  } else if (isComplexGlob) {
    const globFlag = caseInsensitive ? '--iglob' : '--glob';
    fileFilter = `${globFlag} '${namePattern}'`;
  }

  if (hasContentSearch) {
    // Content search
    if (fileFilter) {
      return `rg ${fileFilter} '${grepPattern}' ${searchPath}`;
    }
    return `rg '${grepPattern}' ${searchPath}`;
  } else {
    // File listing only
    if (fileFilter) {
      return `rg --files ${fileFilter} ${searchPath}`;
    }
    return `rg --files ${searchPath} | rg '<filename-pattern>'`;
  }
}

const suggestion = suggestRgAlternative(cmd);

console.log(JSON.stringify({
  decision: "block",
  reason: `find+exec/xargs requires approval. Use rg instead:\n\n  ${suggestion}\n\nrg is faster and auto-allowed.`
}));
