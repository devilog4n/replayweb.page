/**
 * ReplayWeb.page Mobile - Performance Manager
 * 
 * This module provides performance optimizations for the ReplayWeb.page
 * mobile application, focusing on efficient handling of large archives,
 * memory management, and caching strategies.
 */

// Get error handler references
const ErrorTypes = window.ReplayMobile?.ErrorTypes || {};
const LoadingStates = window.ReplayMobile?.LoadingStates || {};

// Cache configuration
const CONFIG = {
  // Maximum number of archives to keep in memory cache
  MAX_CACHE_ITEMS: 5,
  
  // Maximum size of an archive to fully load in memory (in bytes)
  // Archives larger than this will use streaming mode
  MAX_FULL_LOAD_SIZE: 50 * 1024 * 1024, // 50MB
  
  // Size threshold for using chunks when loading archives (in bytes)
  CHUNK_THRESHOLD: 10 * 1024 * 1024, // 10MB
  
  // Size of chunks when loading large archives (in bytes)
  CHUNK_SIZE: 2 * 1024 * 1024, // 2MB
  
  // Enable memory usage monitoring
  MONITOR_MEMORY: true,
  
  // Memory threshold for cleanup (in MB)
  MEMORY_CLEANUP_THRESHOLD: 300, // 300MB
};

// Internal state
let archiveCache = new Map();
let metadataCache = new Map();
let memoryMonitorInterval = null;
let isInitialized = false;

/**
 * Initialize the performance manager
 */
function initPerformanceManager() {
  if (isInitialized) {
    return;
  }
  
  console.log('🚀 Initializing performance manager...');
  
  // Setup memory monitoring if enabled
  if (CONFIG.MONITOR_MEMORY) {
    setupMemoryMonitoring();
  }
  
  // Add event listeners for application states
  addEventListeners();
  
  isInitialized = true;
}

/**
 * Setup memory monitoring to prevent memory leaks and excessive usage
 */
function setupMemoryMonitoring() {
  // Clear any existing interval
  if (memoryMonitorInterval) {
    clearInterval(memoryMonitorInterval);
  }
  
  // Set up periodic memory check
  memoryMonitorInterval = setInterval(() => {
    checkMemoryUsage();
  }, 30000); // Check every 30 seconds
}

/**
 * Check current memory usage and clean up if necessary
 */
function checkMemoryUsage() {
  // Use performance API if available
  if (window.performance && window.performance.memory) {
    const memoryInfo = window.performance.memory;
    const usedHeapSize = Math.round(memoryInfo.usedJSHeapSize / (1024 * 1024));
    const totalHeapSize = Math.round(memoryInfo.totalJSHeapSize / (1024 * 1024));
    
    console.log(`📊 Memory usage: ${usedHeapSize}MB / ${totalHeapSize}MB`);
    
    // If memory usage exceeds threshold, perform cleanup
    if (usedHeapSize > CONFIG.MEMORY_CLEANUP_THRESHOLD) {
      console.warn(`⚠️ Memory usage high (${usedHeapSize}MB), performing cleanup...`);
      performMemoryCleanup();
    }
  }
}

/**
 * Perform memory cleanup operations to reduce memory footprint
 */
function performMemoryCleanup() {
  // Clear caches except for the currently viewed archive
  const currentArchive = window.ArchiveViewer?.getCurrentArchive?.();
  const currentArchiveName = currentArchive?.name || '';
  
  // Clear archive cache except for current archive
  if (archiveCache.size > 1) {
    for (const [name, _] of archiveCache) {
      if (name !== currentArchiveName) {
        archiveCache.delete(name);
      }
    }
    console.log(`🧹 Cleared ${archiveCache.size > 0 ? 'all except current' : 'all'} archives from cache`);
  }
  
  // Trim metadata cache to only keep essential items
  if (metadataCache.size > CONFIG.MAX_CACHE_ITEMS) {
    // Keep current and a few recent items
    const keysToKeep = [currentArchiveName];
    const otherKeys = [...metadataCache.keys()].filter(k => k !== currentArchiveName);
    
    // Sort by last accessed time and keep most recent
    otherKeys.sort((a, b) => {
      const itemA = metadataCache.get(a);
      const itemB = metadataCache.get(b);
      return (itemB.lastAccessed || 0) - (itemA.lastAccessed || 0);
    });
    
    // Add most recent keys to keep
    keysToKeep.push(...otherKeys.slice(0, CONFIG.MAX_CACHE_ITEMS - 1));
    
    // Create new cache with only the keys to keep
    const newCache = new Map();
    for (const key of keysToKeep) {
      if (metadataCache.has(key)) {
        newCache.set(key, metadataCache.get(key));
      }
    }
    
    const cleared = metadataCache.size - newCache.size;
    metadataCache = newCache;
    console.log(`🧹 Cleared ${cleared} items from metadata cache`);
  }
  
  // Force garbage collection if possible
  if (window.gc) {
    window.gc();
  }
}

/**
 * Add event listeners for application state changes
 */
function addEventListeners() {
  // Clear cache when app goes to background (if supported)
  if (window.Capacitor?.Plugins?.App) {
    window.Capacitor.Plugins.App.addListener('appStateChange', ({ isActive }) => {
      if (!isActive) {
        // When app goes to background, clear cache except current
        performMemoryCleanup();
      }
    });
  }
  
  // Listen for viewer navigation events to optimize memory
  document.addEventListener('replay-navigated', () => {
    // When user navigates in the viewer, check memory
    checkMemoryUsage();
  });
}

/**
 * Optimize archive loading based on size and type
 * @param {Object} archive Archive object with size and type information
 * @returns {Object} Loading strategy object with optimized parameters
 */
function getLoadingStrategy(archive) {
  if (!archive) {
    return { streaming: false, useChunks: false, chunkSize: CONFIG.CHUNK_SIZE };
  }
  
  const size = archive.size || 0;
  const isLarge = size > CONFIG.MAX_FULL_LOAD_SIZE;
  const useChunks = size > CONFIG.CHUNK_THRESHOLD;
  
  // Calculate optimal chunk size based on archive size
  let chunkSize = CONFIG.CHUNK_SIZE;
  if (useChunks && size > 0) {
    // For very large archives, use larger chunks
    if (size > 100 * 1024 * 1024) { // > 100MB
      chunkSize = 5 * 1024 * 1024; // 5MB
    }
  }
  
  return {
    streaming: isLarge,
    useChunks: useChunks,
    chunkSize: chunkSize
  };
}

/**
 * Optimize the URL parameters for loading an archive in the viewer
 * @param {string} url The original URL
 * @param {Object} archive The archive object
 * @returns {string} Optimized URL
 */
function optimizeViewerUrl(url, archive) {
  if (!url) return url;
  
  try {
    const parsedUrl = new URL(url);
    const strategy = getLoadingStrategy(archive);
    
    // Add performance optimizing parameters
    if (strategy.streaming) {
      parsedUrl.searchParams.set('stream', 'true');
    }
    
    if (strategy.useChunks) {
      parsedUrl.searchParams.set('useChunks', 'true');
      parsedUrl.searchParams.set('chunkSize', strategy.chunkSize.toString());
    }
    
    // Set cache hint
    parsedUrl.searchParams.set('cache', 'true');
    
    return parsedUrl.toString();
  } catch (error) {
    console.error('Error optimizing URL:', error);
    return url;
  }
}

/**
 * Update archive metadata when it's accessed
 * @param {Object} archive The archive object
 */
function updateArchiveMetadata(archive) {
  if (!archive || !archive.name) return;
  
  const name = archive.name;
  const now = Date.now();
  
  // Update or create metadata
  if (metadataCache.has(name)) {
    const metadata = metadataCache.get(name);
    metadata.accessCount = (metadata.accessCount || 0) + 1;
    metadata.lastAccessed = now;
    metadataCache.set(name, metadata);
  } else {
    metadataCache.set(name, {
      name: name,
      size: archive.size || 0,
      type: archive.type || '',
      accessCount: 1,
      lastAccessed: now,
      created: now
    });
  }
}

/**
 * Optimize web archive viewer loading
 * @param {Object} archive The archive to load
 * @returns {Object} Enhanced archive object with optimization params
 */
function optimizeArchiveLoading(archive) {
  if (!archive) return archive;
  
  // Update access metadata
  updateArchiveMetadata(archive);
  
  // Get loading strategy
  const strategy = getLoadingStrategy(archive);
  
  // Add optimization parameters to archive object
  const enhancedArchive = { ...archive };
  enhancedArchive.optimized = true;
  enhancedArchive.streaming = strategy.streaming;
  enhancedArchive.useChunks = strategy.useChunks;
  enhancedArchive.chunkSize = strategy.chunkSize;
  
  // If we have the optimized URL, use it
  if (archive.url) {
    enhancedArchive.optimizedUrl = optimizeViewerUrl(archive.url, archive);
  }
  
  return enhancedArchive;
}

/**
 * Preload archive metadata for faster loading
 * @param {Array} archives List of archives to preload metadata for
 */
function preloadArchiveMetadata(archives) {
  if (!archives || !archives.length) return;
  
  console.log(`🔄 Preloading metadata for ${archives.length} archives...`);
  
  // Process in background with small delay to not block UI
  setTimeout(() => {
    archives.forEach((archive, index) => {
      // Stagger preloading to avoid UI freezes
      setTimeout(() => {
        if (archive && archive.name && !metadataCache.has(archive.name)) {
          updateArchiveMetadata(archive);
        }
      }, index * 50); // 50ms delay between each preload
    });
  }, 100);
}

/**
 * Get optimization statistics
 * @returns {Object} Performance statistics
 */
function getPerformanceStats() {
  return {
    archiveCacheSize: archiveCache.size,
    metadataCacheSize: metadataCache.size,
    memoryMonitoringActive: !!memoryMonitorInterval,
    config: CONFIG
  };
}

// Initialize on load
document.addEventListener('DOMContentLoaded', initPerformanceManager);

// Export public API to window
window.PerformanceManager = {
  optimizeArchiveLoading,
  optimizeViewerUrl,
  preloadArchiveMetadata,
  getPerformanceStats,
  forceMemoryCleanup: performMemoryCleanup
};