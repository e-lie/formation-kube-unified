#!/usr/bin/env node

import { DocFilesWatcher } from '../src/lib/doc-files-watcher.js';

console.log('🚀 Starting documentation sync...');

const watcher = new DocFilesWatcher();

try {
  await watcher.syncAllFiles();
  console.log('✅ Documentation sync completed successfully');
  process.exit(0);
} catch (error) {
  console.error('❌ Error during sync:', error);
  process.exit(1);
}