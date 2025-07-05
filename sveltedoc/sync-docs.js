#!/usr/bin/env node

import { fileWatcher } from './src/lib/file-watcher.js';

console.log('🚀 Démarrage de la synchronisation manuelle...');

try {
  await fileWatcher.start();
  console.log('✅ Synchronisation terminée avec succès !');
} catch (error) {
  console.error('❌ Erreur lors de la synchronisation :', error);
} finally {
  fileWatcher.stop();
  process.exit(0);
}