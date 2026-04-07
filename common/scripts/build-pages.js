#!/usr/bin/env node

/**
 * Script to build the GitHub Pages site with 11ty and collect tool documentation
 */

const path = require('path');
const { execSync } = require('child_process');
const fs = require('fs');

const repoRoot = path.resolve(__dirname, '../../');
const contentDir = path.join(repoRoot, 'content');
const toolsDir = path.join(repoRoot, 'tools');

console.log('[build:pages] Starting GitHub Pages build...\n');

// Step 1: Collect tool documentation
console.log('[build:pages] Collecting tool documentation...');
const publicToolsDir = path.join(contentDir, 'src', 'tools');

// Clear stale tool docs before re-populating so removed or renamed tools
// don't persist across builds (matches the clean-build approach in collect-schemas.js).
if (fs.existsSync(publicToolsDir)) {
  fs.rmSync(publicToolsDir, { recursive: true, force: true });
}
fs.mkdirSync(publicToolsDir, { recursive: true });

// Iterate through all tools
if (fs.existsSync(toolsDir)) {
  const tools = fs.readdirSync(toolsDir);
  
  tools.forEach(toolName => {
    const toolDocsDir = path.join(toolsDir, toolName, 'docs');
    const targetToolDir = path.join(publicToolsDir, toolName);
    
    if (fs.existsSync(toolDocsDir)) {
      console.log(`  - Copying ${toolName} documentation...`);
      
      // Ensure target directory exists
      if (!fs.existsSync(targetToolDir)) {
        fs.mkdirSync(targetToolDir, { recursive: true });
      }
      
      // Copy all files from tool docs to site
      const files = fs.readdirSync(toolDocsDir);
      files.forEach(file => {
        const src = path.join(toolDocsDir, file);
        const dest = path.join(targetToolDir, file);
        
        if (fs.statSync(src).isDirectory()) {
          // Copy directories recursively
          copyDirSync(src, dest);
        } else {
          // Copy files
          fs.copyFileSync(src, dest);
        }
      });
    }
  });
}

// Step 2: Build 11ty site
console.log('\n[build:pages] Building 11ty site...');
try {
  const cwd = process.cwd();
  process.chdir(contentDir);
  execSync('npm ci --prefer-offline', { stdio: 'inherit' });
  execSync('npm run build', { stdio: 'inherit' });
  process.chdir(cwd);
  console.log('\n[build:pages] Site build completed successfully!');
} catch (error) {
  console.error('\n[build:pages] Error building site:', error.message);
  process.exit(1);
}

/**
 * Recursively copy a directory
 */
function copyDirSync(src, dest) {
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }
  
  const files = fs.readdirSync(src);
  files.forEach(file => {
    const srcFile = path.join(src, file);
    const destFile = path.join(dest, file);
    
    if (fs.statSync(srcFile).isDirectory()) {
      copyDirSync(srcFile, destFile);
    } else {
      fs.copyFileSync(srcFile, destFile);
    }
  });
}

console.log('[build:pages] All done! Generated site is at: content/_site/');
