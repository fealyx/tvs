#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Collect schema files from each Rush project's local schemas/ directory.
// Each schema must declare a canonical $id under the configured Pages root,
// and the published output path is derived from that $id rather than source layout.

const repoRoot = path.resolve(__dirname, '..', '..');
const outputRoot = path.resolve(repoRoot, '.pages');
const canonicalBaseUrl = 'https://fealyx.github.io/tvs';
const canonicalSchemasRoot = `${canonicalBaseUrl}/schemas/`;

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

function stripJsonComments(input) {
  let output = '';
  let inString = false;
  let stringDelimiter = '';
  let isEscaped = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (let index = 0; index < input.length; index += 1) {
    const current = input[index];
    const next = input[index + 1];

    if (inLineComment) {
      if (current === '\n') {
        inLineComment = false;
        output += current;
      }
      continue;
    }

    if (inBlockComment) {
      if (current === '*' && next === '/') {
        inBlockComment = false;
        index += 1;
      }
      continue;
    }

    if (inString) {
      output += current;
      if (isEscaped) {
        isEscaped = false;
      } else if (current === '\\') {
        isEscaped = true;
      } else if (current === stringDelimiter) {
        inString = false;
        stringDelimiter = '';
      }
      continue;
    }

    if (current === '"' || current === "'") {
      inString = true;
      stringDelimiter = current;
      output += current;
      continue;
    }

    if (current === '/' && next === '/') {
      inLineComment = true;
      index += 1;
      continue;
    }

    if (current === '/' && next === '*') {
      inBlockComment = true;
      index += 1;
      continue;
    }

    output += current;
  }

  return output;
}

function readRushConfig() {
  const rushJsonPath = path.join(repoRoot, 'rush.json');
  const raw = fs.readFileSync(rushJsonPath, 'utf8');

  try {
    return JSON.parse(stripJsonComments(raw));
  } catch (error) {
    throw new Error(`Failed to parse rush.json: ${error.message}`);
  }
}

function getRushProjectSchemaFiles() {
  const rushConfig = readRushConfig();
  const projects = Array.isArray(rushConfig.projects) ? rushConfig.projects : [];
  const schemaFiles = [];

  for (const project of projects) {
    if (!project || typeof project.projectFolder !== 'string') {
      continue;
    }

    const projectRoot = path.join(repoRoot, project.projectFolder);
    const schemasDir = path.join(projectRoot, 'schemas');
    const projectFiles = walk(schemasDir);

    for (const file of projectFiles) {
      if (file.endsWith('.schema.json')) {
        schemaFiles.push(file);
      }
    }
  }

  return schemaFiles;
}

function assertCanonicalSchemaId(schemaId, rel) {
  if (typeof schemaId !== 'string' || schemaId.length === 0) {
    throw new Error(`Schema $id is missing in ${rel}`);
  }

  if (!schemaId.startsWith(canonicalSchemasRoot)) {
    throw new Error(`Schema $id in ${rel} must be under ${canonicalSchemasRoot}. Found: ${schemaId}`);
  }

  const publishedRelativePath = schemaId.slice(canonicalSchemasRoot.length);
  if (!publishedRelativePath || publishedRelativePath.endsWith('/')) {
    throw new Error(`Schema $id in ${rel} does not resolve to a file path: ${schemaId}`);
  }

  if (!publishedRelativePath.endsWith('.schema.json')) {
    throw new Error(`Schema $id in ${rel} must end with .schema.json. Found: ${schemaId}`);
  }

  const normalizedRelativePath = publishedRelativePath.split('/').join(path.sep);
  const normalizedOutputPath = path.normalize(normalizedRelativePath);
  if (path.isAbsolute(normalizedOutputPath) || normalizedOutputPath.startsWith('..')) {
    throw new Error(`Schema $id in ${rel} resolves outside the schemas root: ${schemaId}`);
  }

  return normalizedOutputPath;
}

function main() {
  const schemaFiles = getRushProjectSchemaFiles();

  if (schemaFiles.length === 0) {
    throw new Error('No schema files found under Rush project schemas directories.');
  }

  if (fs.existsSync(outputRoot)) {
    fs.rmSync(outputRoot, { recursive: true, force: true });
  }
  ensureDir(path.join(outputRoot, 'schemas'));

  const published = [];
  const seenIds = new Set();
  const seenDestinations = new Set();

  for (const file of schemaFiles) {
    const rel = path.relative(repoRoot, file).split(path.sep).join('/');

    const raw = fs.readFileSync(file, 'utf8');
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      throw new Error(`Failed to parse JSON in ${rel}: ${error.message}`);
    }

    const schemaId = parsed.$id;
    const publishedRelativePath = assertCanonicalSchemaId(schemaId, rel);
    const publishedRelativePathPosix = publishedRelativePath.split(path.sep).join('/');

    if (seenIds.has(schemaId)) {
      throw new Error(`Duplicate schema $id detected: ${schemaId}`);
    }
    seenIds.add(schemaId);

    if (seenDestinations.has(publishedRelativePathPosix)) {
      throw new Error(`Multiple schema files map to the same published path: ${publishedRelativePathPosix}`);
    }
    seenDestinations.add(publishedRelativePathPosix);

    const destPath = path.join(outputRoot, 'schemas', publishedRelativePath);
    const destDir = path.dirname(destPath);
    ensureDir(destDir);
    fs.copyFileSync(file, destPath);

    published.push({
      rel,
      schemaId,
      destPath: path.relative(repoRoot, destPath).split(path.sep).join('/'),
    });
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
