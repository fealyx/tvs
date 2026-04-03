#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const workflowsDir = path.join(repoRoot, '.github', 'workflows');
const writeChanges = process.argv.includes('--write');

const lineRegex = /^([ \t-]*uses:\s*)([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)@([0-9a-f]{40})(\s*#\s*(v\d+(?:\.\d+)*))(\s*)$/m;

function getMajorPrefix(versionTag) {
  const m = /^v(\d+)/.exec(versionTag);
  if (!m) {
    throw new Error(`Unsupported version tag format: ${versionTag}`);
  }
  return `v${m[1]}`;
}

async function fetchJson(url, token) {
  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'tvs-action-pin-updater',
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(url, { headers });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`GitHub API ${res.status} for ${url}: ${body}`);
  }
  return res.json();
}

function pickLatestTag(tags, majorPrefix) {
  const candidates = tags
    .map((t) => t.name)
    .filter((name) => new RegExp(`^${majorPrefix.replace('.', '\\.')}(\\.\\d+)*$`).test(name))
    .sort((a, b) => {
      const pa = a.slice(1).split('.').map((n) => Number(n));
      const pb = b.slice(1).split('.').map((n) => Number(n));
      const len = Math.max(pa.length, pb.length);
      for (let i = 0; i < len; i++) {
        const av = pa[i] ?? 0;
        const bv = pb[i] ?? 0;
        if (av !== bv) {
          return av - bv;
        }
      }
      return 0;
    });

  return candidates[candidates.length - 1] || null;
}

async function resolveLatestSha(actionRepo, majorPrefix, token) {
  const tags = await fetchJson(`https://api.github.com/repos/${actionRepo}/tags?per_page=100`, token);
  const latestTag = pickLatestTag(tags, majorPrefix);
  if (!latestTag) {
    throw new Error(`No tags found for ${actionRepo} matching ${majorPrefix}`);
  }

  const commit = await fetchJson(`https://api.github.com/repos/${actionRepo}/commits/${latestTag}`, token);
  return { latestTag, latestSha: commit.sha };
}

async function main() {
  if (!fs.existsSync(workflowsDir)) {
    throw new Error(`Workflow directory not found: ${workflowsDir}`);
  }

  const workflowFiles = fs.readdirSync(workflowsDir)
    .filter((f) => f.endsWith('.yml') || f.endsWith('.yaml'))
    .map((f) => path.join(workflowsDir, f));

  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || '';

  const records = [];

  for (const file of workflowFiles) {
    const original = fs.readFileSync(file, 'utf8');
    const lines = original.split('\n');
    let changed = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const m = line.match(lineRegex);
      if (!m) {
        continue;
      }

      const prefix = m[1];
      const actionRepo = m[2];
      const currentSha = m[3];
      const versionComment = m[5];
      const suffix = m[6] || '';

      const majorPrefix = getMajorPrefix(versionComment);
      const { latestTag, latestSha } = await resolveLatestSha(actionRepo, majorPrefix, token);

      const upToDate = currentSha.toLowerCase() === latestSha.toLowerCase();
      records.push({
        file: path.relative(repoRoot, file),
        actionRepo,
        versionComment,
        latestTag,
        currentSha,
        latestSha,
        upToDate,
      });

      if (!upToDate) {
        lines[i] = `${prefix}${actionRepo}@${latestSha} # ${latestTag}${suffix}`;
        changed = true;
      }
    }

    if (changed && writeChanges) {
      fs.writeFileSync(file, lines.join('\n'));
    }
  }

  const total = records.length;
  const outdated = records.filter((r) => !r.upToDate);

  process.stdout.write(`Scanned ${total} pinned action references.\n`);
  if (outdated.length === 0) {
    process.stdout.write('All pinned action SHAs are up to date for their major line.\n');
  } else {
    process.stdout.write(`Found ${outdated.length} outdated pinned action references.\n`);
    for (const r of outdated) {
      process.stdout.write(`- ${r.file}: ${r.actionRepo} ${r.currentSha.slice(0, 12)} -> ${r.latestSha.slice(0, 12)} (${r.latestTag})\n`);
    }
    if (!writeChanges) {
      process.stdout.write('Run with --write to apply updates.\n');
    }
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
