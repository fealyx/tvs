#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const outputRoot = path.resolve(repoRoot, '.pages');
const canonicalBaseUrl = 'https://fealyx.github.io/tvs';

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) {
    return out;
  }

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else {
      out.push(full);
    }
  }

  return out;
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function main() {
  const toolsDir = path.join(repoRoot, 'tools');
  const allFiles = walk(toolsDir);
  const schemaFiles = allFiles.filter((file) => {
    if (!file.endsWith('.schema.json')) {
      return false;
    }

    const normalized = file.split(path.sep).join('/');
    return /\/tools\/[^/]+\/schemas\/.+\.schema\.json$/.test(normalized);
  });

  if (schemaFiles.length === 0) {
    throw new Error('No schema files found under tools/*/schemas/*.schema.json');
  }

  if (fs.existsSync(outputRoot)) {
    fs.rmSync(outputRoot, { recursive: true, force: true });
  }
  ensureDir(path.join(outputRoot, 'schemas'));

  const published = [];

  for (const file of schemaFiles) {
    const rel = path.relative(repoRoot, file).split(path.sep).join('/');
    const match = rel.match(/^tools\/([^/]+)\/schemas\/(.+\.schema\.json)$/);
    if (!match) {
      continue;
    }

    const namespace = match[1];
    const filename = match[2];
    const expectedId = `${canonicalBaseUrl}/schemas/${namespace}/${filename}`;

    const raw = fs.readFileSync(file, 'utf8');
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      throw new Error(`Failed to parse JSON in ${rel}: ${error.message}`);
    }

    if (parsed.$id !== expectedId) {
      throw new Error(`Schema $id mismatch in ${rel}. Expected: ${expectedId}, Found: ${parsed.$id || '(missing)'}`);
    }

    const destDir = path.join(outputRoot, 'schemas', namespace);
    ensureDir(destDir);
    const destPath = path.join(destDir, filename);
    fs.copyFileSync(file, destPath);

    published.push({ rel, expectedId, destPath: path.relative(repoRoot, destPath).split(path.sep).join('/') });
  }

  const index = {
    generatedAtUtc: new Date().toISOString(),
    canonicalBaseUrl,
    schemas: published,
  };

  fs.writeFileSync(path.join(outputRoot, 'schemas', 'index.json'), JSON.stringify(index, null, 2));

  process.stdout.write(`Collected ${published.length} schema files into ${path.relative(repoRoot, outputRoot)}\n`);
}

main();
