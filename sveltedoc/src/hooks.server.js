import { docWatcher } from '$lib/doc-files-watcher.js';
import { dev } from '$app/environment';

// Start the file watcher in development mode
if (dev) {
  docWatcher.start().catch(console.error);
  
  // Graceful shutdown
  if (typeof process !== 'undefined') {
    process.on('SIGTERM', () => {
      docWatcher.stop();
    });
    
    process.on('SIGINT', () => {
      docWatcher.stop();
      process.exit(0);
    });
  }
}