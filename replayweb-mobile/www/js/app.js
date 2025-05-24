// ReplayWeb.page Mobile App - Main Application Logic
// This file handles the application lifecycle and WARC archive loading

// Get error handler references
const ErrorTypes = window.ReplayMobile?.ErrorTypes || {};
const LoadingStates = window.ReplayMobile?.LoadingStates || {};

// App state variables
let selectedArchive = null;
let archiveList = [];
let appInitialized = false;

// IMPORTANT: Early initialization for browser environments
(function setupEnvironment() {
  // When in browser preview mode (not in Capacitor), set up mock systems immediately
  if (typeof window !== 'undefined' && !window.Capacitor && 
      (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
    console.log('🔧 Running in browser preview mode, setting up early mock initialization');
    // Force enable service workers for testing
    window.useServiceWorker = true;
    
    // Initialize mock file system
    setupMockFileSystem();
  }
})();

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', initializeApp);

/**
 * Set up mock FileSystem for browser testing environment
 * This is used for development and testing without native device capabilities
 */
function setupMockFileSystem() {
  // Create the FileManager if it doesn't exist yet
  if (!window.FileManager) {
    console.log('💾 Creating mock FileManager for browser testing');
    
    window.FileManager = {
      _mockInitialized: true,
      initFileSystem: function() {
        console.log('💾 Mock file system initialized');
        return Promise.resolve();
      },
      getArchives: function() {
        // Return some mock archives for testing
        const mockArchives = [
          {
            name: 'example1.wacz',
            url: './warc-data/example.wacz',
            size: 1024 * 1024 * 2,
            date: new Date().toISOString(),
            id: 'example1_' + Date.now()
          },
          {
            name: 'example2.wacz',
            url: './warc-data/example.wacz',
            size: 1024 * 1024 * 3,
            date: new Date(Date.now() - 86400000).toISOString(),
            id: 'example2_' + Date.now()
          }
        ];
        console.log('🔍 Getting mock archives');
        return Promise.resolve(mockArchives);
      },
      deleteArchive: function(name) {
        console.log('🗑 Mock deleting archive:', name);
        return Promise.resolve();
      },
      importArchiveFromDevice: function() {
        console.log('💾 Simulating archive import');
        const newArchive = {
          name: `imported_${Date.now()}.wacz`,
          url: './warc-data/example.wacz',
          size: 1024 * 1024 * Math.floor(Math.random() * 5 + 1),
          date: new Date().toISOString(),
          id: 'imported_' + Date.now()
        };
        return Promise.resolve(newArchive);
      }
    };
  }
}

// Main initialization function
function initializeApp() {
  // Prevent duplicate initialization
  if (appInitialized) {
    return;
  }
  
  console.log('🚀 Initializing ReplayWeb.page Mobile...');
  
  // Set initial loading state
  if (window.ErrorHandler) {
    window.ErrorHandler.setLoadingState(LoadingStates.INITIALIZING);
  } else if (typeof updateLoadingStatus === 'function') {
    updateLoadingStatus('Initializing application...');
  }
  
  // Try to initialize service worker if available
  if (window.ServiceWorkerBridge && 'serviceWorker' in navigator) {
    // Enable service workers
    window.useServiceWorker = true;
    
    // Initialize the service worker bridge
    window.ServiceWorkerBridge.initialize()
      .then(success => {
        if (success) {
          console.log('✅ Service Worker Bridge initialized successfully');
        } else {
          console.warn('⚠️ Service Worker Bridge initialization failed, falling back to non-SW mode');
          window.useServiceWorker = false;
        }
      })
      .catch(error => {
        console.error('❌ Error initializing Service Worker Bridge:', error);
        window.useServiceWorker = false;
      });
  } else {
    console.log('ℹ️ Service Worker Bridge not available or service workers not supported');
    window.useServiceWorker = false;
  }
  
  // Check if we're running in Capacitor environment
  if (!window.Capacitor) {
    console.warn('⚠️ Not running in Capacitor environment. Some features may be limited.');
    // If not in Capacitor, we might be running in a browser for development
    simulateAppForDevelopment();
    return;
  }
  
  // Check for required modules
  if (typeof startServer !== 'function') {
    const error = new Error('Application initialization failed: Server module not loaded');
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.UNKNOWN);
    } else {
      showError('Application initialization failed: Server module not loaded');
    }
    return;
  }
  
  if (!window.FileManager) {
    const error = new Error('Application initialization failed: File Manager module not loaded');
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.UNKNOWN);
    } else {
      showError('Application initialization failed: File Manager module not loaded');
    }
    return;
  }
  
  // When running in a browser preview (not Capacitor), set up mock FileManager for testing
  if (!window.Capacitor && window.location.hostname === 'localhost') {
    console.log('🔧 Running in browser preview mode, setting up mock file system');
    setupMockFileSystem();
  }
  
  // Detect if we're already viewing an archive (via URL parameters)
  const urlParams = getURLParams();
  const isViewingArchive = urlParams.source || urlParams.url || urlParams.warc;
  
  if (isViewingArchive) {
    console.log('ℹ️ Already viewing an archive, skipping initialization');
    // Clear loading state if we're already viewing an archive
    if (window.ErrorHandler) {
      window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
    }
    return;
  }
  
  // Set a timeout for the entire initialization process
  const initTimeout = setTimeout(() => {
    if (!appInitialized && window.ErrorHandler) {
      window.ErrorHandler.handleError(
        'Application initialization timed out after 25 seconds',
        ErrorTypes.UNKNOWN
      );
    }
  }, 25000);
  
  // Initialize in sequence: file system -> server -> load archives
  window.FileManager.initFileSystem()
    .then(() => {
      // Update loading state for server startup
      if (window.ErrorHandler) {
        window.ErrorHandler.setLoadingState(LoadingStates.SERVER_STARTING);
      } else if (typeof updateLoadingStatus === 'function') {
        updateLoadingStatus('Starting HTTP server...');
      }
      return startServer();
    })
    .then(() => {
      // Update loading state for archive loading
      if (window.ErrorHandler) {
        window.ErrorHandler.setLoadingState(LoadingStates.LOADING_ARCHIVES);
      } else if (typeof updateLoadingStatus === 'function') {
        updateLoadingStatus('Loading available archives...');
      }
      return window.FileManager.getArchives(true); // true = refresh the list
    })
    .then(archives => {
      // Store archive list and mark as initialized
      archiveList = archives;
      appInitialized = true;
      
      // Clear the initialization timeout
      clearTimeout(initTimeout);
      
      console.log(`📂 Found ${archives.length} archives:`, 
                 archives.length > 0 ? archives.map(a => a.name).join(', ') : 'none');
      
      if (archives.length > 0) {
        // Automatically select the first archive
        selectedArchive = archives[0];
        
        // Update loading state for archive loading
        if (window.ErrorHandler) {
          window.ErrorHandler.setLoadingState(
            LoadingStates.LOADING_ARCHIVE, 
            `Loading archive: ${selectedArchive.name}`
          );
        } else if (typeof updateLoadingStatus === 'function') {
          updateLoadingStatus(`Loading archive: ${selectedArchive.name}`);
        }
        
        loadSelectedArchive();
      } else {
        // No archives found - show instructions
        if (window.ErrorHandler) {
          window.ErrorHandler.setLoadingState(LoadingStates.IDLE, 'No archives found');
        } else if (typeof updateLoadingStatus === 'function') {
          updateLoadingStatus('No archives found');
        }
        
        showNoArchivesMessage();
      }
    })
    .catch(error => {
      // Clear the initialization timeout since we got an error
      clearTimeout(initTimeout);
      
      // Handle the error
      if (window.ErrorHandler) {
        window.ErrorHandler.handleError(error, ErrorTypes.UNKNOWN);
      } else {
        console.error('❌ Error during app initialization:', error);
        showError(`Application initialization failed: ${error.message || 'Unknown error'}`);
      }
    });
}

/**
 * Get URL parameters as an object
 * @returns {Object} URL parameters
 */
function getURLParams() {
  const params = {};
  const urlParams = new URLSearchParams(window.location.search);
  for (const [key, value] of urlParams.entries()) {
    params[key] = value;
  }
  return params;
}

/**
 * Load the selected archive
 */
function loadSelectedArchive() {
  if (!selectedArchive) {
    console.error('❌ No archive selected');
    return;
  }
  
  console.log(`📂 Loading archive: ${selectedArchive.name}`);
  
  // Update loading state if error handler is available
  if (window.ErrorHandler) {
    window.ErrorHandler.setLoadingState(
      LoadingStates.LOADING_ARCHIVE, 
      `Loading archive: ${selectedArchive.name}`
    );
  }
  
  // Get the base URL for loading the archive
  const archiveUrl = selectedArchive.url || `http://localhost:3333/${selectedArchive.name}`;
  
  // Check if service worker is available and enabled
  if (window.useServiceWorker && window.ServiceWorkerBridge) {
    console.log('🔄 Using Service Worker for archive loading');
    
    // Generate a unique ID for this archive if it doesn't have one
    const archiveId = selectedArchive.id || `archive_${Date.now()}`;
    
    // Register the archive with the service worker
    window.ServiceWorkerBridge.registerArchive(archiveId, archiveUrl, selectedArchive.size || 0)
      .then(response => {
        if (response.success) {
          console.log('✅ Archive registered with Service Worker');
          
          // Create URL for loading WACZ through service worker
          const viewerUrl = `capacitor://localhost/index.html?waczArchive=${encodeURIComponent(archiveId)}`;
          console.log(`🔄 Navigating to: ${viewerUrl}`);
          window.location.href = viewerUrl;
        } else {
          console.error('❌ Failed to register archive with Service Worker, falling back to direct loading');
          fallbackToDirectLoading(archiveUrl);
        }
      })
      .catch(error => {
        console.error('❌ Error registering archive with Service Worker:', error);
        fallbackToDirectLoading(archiveUrl);
      });
  } else {
    // No service worker, load directly
    fallbackToDirectLoading(archiveUrl);
  }
}

/**
 * Fallback method for loading archives without service worker
 * @param {string} archiveUrl URL to the archive
 */
function fallbackToDirectLoading(archiveUrl) {
  console.log('ℹ️ Loading archive directly (no service worker)');
  
  // Apply performance optimizations if available
  let viewerUrl;
  if (window.PerformanceManager?.optimizeArchiveLoading) {
    // Get optimized archive with performance enhancements
    const optimizedArchive = window.PerformanceManager.optimizeArchiveLoading(selectedArchive);
    
    // Use optimized URL
    const baseUrl = `capacitor://localhost/index.html?source=${encodeURIComponent(archiveUrl)}`;
    viewerUrl = window.PerformanceManager.optimizeViewerUrl(baseUrl, optimizedArchive);
  } else {
    // Default URL
    viewerUrl = `capacitor://localhost/index.html?source=${encodeURIComponent(archiveUrl)}`;
  }
  
  if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: `Loading archive: ${selectedArchive.name}`,
      duration: 'short'
    });
  }
  
  // Navigate to the archive viewer
  console.log(`🔄 Navigating to: ${viewerUrl}`);
  window.location.href = viewerUrl;
}

/**
 * Show error message when no archives are found
 */
function showNoArchivesMessage() {
  console.warn('⚠️ No archives found');
  
  // In a more complete app, you would show a UI element here
  // For now, we'll just use a toast message
  if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: 'No archives found. The example archive will be loaded.',
      duration: 'long'
    });
  }
  
  // For demo purposes, load the example.wacz file if available
  loadExampleArchive();
}

/**
 * Load the example archive for demonstration
 */
function loadExampleArchive() {
  console.log('📂 Loading example archive...');
  const exampleUrl = 'capacitor://localhost/index.html?source=./warc-data/example.wacz';
  window.location.href = exampleUrl;
}

/**
 * Import an archive from the device
 */
function importArchive() {
  // First check if we need to initialize our mock file system for browser testing
  if (!window.Capacitor && window.location.hostname === 'localhost' && !window.FileManager) {
    console.log('🔄 Setting up mock FileManager for browser testing');
    setupMockFileSystem();
    showToast('Setting up mock environment, please try again in a moment');
    return Promise.resolve();
  }
  
  if (!window.FileManager) {
    showError('File Manager not available');
    return Promise.reject(new Error('File Manager not available'));
  }
  
  return window.FileManager.importArchiveFromDevice()
    .then(archive => {
      if (archive) {
        showToast(`Archive imported: ${archive.name}`);
        
        // Register the imported archive with Service Worker if available
        if (window.useServiceWorker && window.ServiceWorkerBridge) {
          console.log('🔄 Registering imported archive with Service Worker');
          
          // Generate unique ID for the archive if needed
          const archiveId = archive.id || `archive_${Date.now()}`;
          const archiveUrl = archive.url || `http://localhost:3333/${archive.name}`;
          
          // Pre-register with service worker before loading
          window.ServiceWorkerBridge.registerArchive(archiveId, archiveUrl, archive.size || 0)
            .then(response => {
              if (response.success) {
                console.log('✅ Imported archive registered with Service Worker');
                // Update archive with service worker info for loading
                archive.id = archiveId;
                archive.usingServiceWorker = true;
              }
              // Continue with loading regardless of registration result
              selectedArchive = archive;
              return loadSelectedArchive();
            })
            .catch(error => {
              console.error('❌ Error registering with Service Worker:', error);
              // Continue with regular loading on error
              selectedArchive = archive;
              return loadSelectedArchive();
            });
        } else {
          // No service worker, proceed normally
          selectedArchive = archive;
          return loadSelectedArchive();
        }
      }
    })
    .catch(error => {
      showError(`Error importing archive: ${error.message}`);
    });
}

/**
 * Delete the currently selected archive
 */
function deleteSelectedArchive() {
  if (!selectedArchive) {
    showError('No archive selected');
    return Promise.reject(new Error('No archive selected'));
  }
  
  if (!window.FileManager) {
    showError('File Manager not available');
    return Promise.reject(new Error('File Manager not available'));
  }
  
  const archiveName = selectedArchive.name;
  
  return window.FileManager.deleteArchive(archiveName)
    .then(() => {
      showToast(`Archive deleted: ${archiveName}`);
      return window.FileManager.getArchives(true);
    })
    .then(archives => {
      archiveList = archives;
      
      if (archives.length > 0) {
        // Select the first available archive
        selectedArchive = archives[0];
        loadSelectedArchive();
      } else {
        // No archives left, show example
        selectedArchive = null;
        showNoArchivesMessage();
      }
    })
    .catch(error => {
      showError(`Error deleting archive: ${error.message}`);
    });
}

/**
 * Show a toast message
 * @param {string} message The message to show
 * @param {string} duration 'short' or 'long'
 */
function showToast(message, duration = 'short') {
  console.log(`ℹ️ ${message}`);
  
  if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: message,
      duration: duration
    });
  }
}

/**
 * Show error message
 * @param {string} message The error message
 */
function showError(message) {
  console.error(`❌ ${message}`);
  
  if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: message,
      duration: 'long'
    });
  }
}

/**
 * For browser-based development without Capacitor
 */
function simulateAppForDevelopment() {
  console.log('🔧 Running in development mode');
  // In development mode, just load the example WACZ directly
  window.location.href = 'index.html?source=./warc-data/example.wacz';
}

/**
 * Set up a mock file system for browser testing
 */
function setupMockFileSystem() {
  console.log('🔧 Setting up mock file system for browser testing');
  
  // Create mock archive data
  const mockArchives = [
    {
      name: 'example1.wacz',
      url: './warc-data/example.wacz', // Use the demo file that should be in the www directory
      size: 1024 * 1024 * 2, // 2MB mock size
      date: new Date().toISOString(),
      id: 'example1_' + Date.now()
    },
    {
      name: 'example2.wacz',
      url: './warc-data/example.wacz', // Same demo file with different name
      size: 1024 * 1024 * 3, // 3MB mock size
      date: new Date(Date.now() - 86400000).toISOString(), // 1 day ago
      id: 'example2_' + Date.now()
    }
  ];
  
  // Store archive data
  let archives = [...mockArchives];
  
  // Override FileManager methods for browser testing
  if (window.FileManager) {
    // Mark as initialized
    window.FileManager._mockInitialized = true;
    
    // Override initFileSystem
    const originalInitFileSystem = window.FileManager.initFileSystem;
    window.FileManager.initFileSystem = function() {
      console.log('💾 Mock file system initialized');
      return Promise.resolve();
    };
    
    // Override getArchives
    window.FileManager.getArchives = function(refresh) {
      console.log('🔍 Getting mock archives', refresh ? '(refreshing)' : '');
      return Promise.resolve(archives);
    };
    
    // Override deleteArchive
    window.FileManager.deleteArchive = function(name) {
      console.log('🗑 Deleting mock archive:', name);
      archives = archives.filter(a => a.name !== name);
      return Promise.resolve();
    };
    
    // Override importArchiveFromDevice
    window.FileManager.importArchiveFromDevice = function() {
      console.log('💾 Simulating archive import');
      
      // Create a new mock archive
      const newArchive = {
        name: `imported_${Date.now()}.wacz`,
        url: './warc-data/example.wacz',
        size: 1024 * 1024 * Math.floor(Math.random() * 5 + 1), // Random size 1-5 MB
        date: new Date().toISOString(),
        id: 'imported_' + Date.now()
      };
      
      // Add to archive list
      archives.push(newArchive);
      
      // Return the new archive
      return Promise.resolve(newArchive);
    };
  }
}

// Function to set and load an archive URL, called from native code
window.setArchiveURL = function(archivePath) {
  console.log(`setArchiveURL called with: ${archivePath}`);

  const fullUrl = 'http://localhost:8090' + archivePath;
  const archiveId = archivePath; // Use the path as a unique ID

  if (window.useServiceWorker && window.ServiceWorkerBridge && navigator.serviceWorker) {
    console.log(`Attempting to register archive with Service Worker: ${archiveId}`);
    window.ServiceWorkerBridge.registerArchive(archiveId, fullUrl, 0) // Assuming size 0 is acceptable
      .then(response => {
        if (response && response.success) {
          console.log(`Archive registered with Service Worker: ${archiveId}`);
          window.location.href = 'index.html?waczArchive=' + encodeURIComponent(archiveId);
        } else {
          console.error(`Failed to register archive with Service Worker: ${archiveId}. Falling back to direct loading. Response:`, response);
          window.location.href = 'index.html?source=' + encodeURIComponent(fullUrl);
        }
      })
      .catch(error => {
        console.error(`Error registering archive ${archiveId} with Service Worker:`, error);
        console.log(`Falling back to direct loading for: ${fullUrl}`);
        window.location.href = 'index.html?source=' + encodeURIComponent(fullUrl);
      });
  } else {
    console.log(`Service Worker not used or not available. Loading directly: ${fullUrl}`);
    window.location.href = 'index.html?source=' + encodeURIComponent(fullUrl);
  }
};

// Initialize the AppManager if not already set up
if (!window.AppManager) {
  window.AppManager = {
    // Get current selected archive
    getSelectedArchive: function() {
      return selectedArchive;
    },
    
    // Set selected archive from archive browser
    setSelectedArchive: function(archive) {
      selectedArchive = archive;
      return selectedArchive;
    },
    
    // Refresh archive list
    refreshArchives: function() {
      // Check if file manager is available
      if (!window.FileManager) {
        console.log('⚠️ FileManager not initialized, attempting setup');
        
        // Try to set up mock system if in a browser environment
        if (!window.Capacitor && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
          console.log('🔄 Setting up mock FileManager for browser testing');
          setupMockFileSystem();
          
          // If we successfully created the mock FileManager, use it
          if (window.FileManager) {
            return window.FileManager.getArchives()
              .then(archives => {
                archiveList = archives || [];
                return archiveList;
              });
          }
        }
        
        return Promise.reject(new Error('File Manager not initialized'));
      }
      
      return window.FileManager.getArchives()
        .then(archives => {
          archiveList = archives || [];
          return archiveList;
        });
    },
    
    // Load the selected archive
    loadSelectedArchive: function() {
      // Update loading state if error handler is available
      if (window.ErrorHandler) {
        window.ErrorHandler.setLoadingState(LoadingStates.LOADING_ARCHIVE);
      }
      
      return loadSelectedArchive()
        .then(() => {
          // Reset loading state
          if (window.ErrorHandler) {
            window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
          }
        });
    },
    
    // Import an archive from the device
    importArchive: function() {
      // Update loading state if error handler is available
      if (window.ErrorHandler) {
        window.ErrorHandler.setLoadingState(LoadingStates.IMPORTING_ARCHIVE);
      }
      
      return importArchive()
        .then(() => {
          // Reset loading state
          if (window.ErrorHandler) {
            window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
          }
        });
    },
    
    // Delete the currently selected archive
    deleteSelectedArchive: function() {
      // Update loading state if error handler is available
      if (window.ErrorHandler) {
        window.ErrorHandler.setLoadingState(LoadingStates.DELETING_ARCHIVE);
      }
      
      return deleteSelectedArchive()
        .then(() => {
          // Reset loading state
          if (window.ErrorHandler) {
            window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
          }
        });
    }
  };
}

// Expose additional functions to window for access from UI
if (window.AppManager) {
  // Add getArchives function to return the archive list
  window.AppManager.getArchives = function() {
    return archiveList;
  };
  
  // Add refreshArchivesForce function to force reload archives
  window.AppManager.refreshArchivesForce = function() {
    // Special handling for iOS Safari
    const isIOS = typeof window.Capacitor !== 'undefined' && 
                  window.Capacitor.getPlatform() === 'ios';
    
    if (isIOS) {
      console.log('📱 iOS specific archive refresh handling');
    }
    
    // Update loading state
    if (window.ErrorHandler) {
      window.ErrorHandler.setLoadingState(LoadingStates.LOADING_ARCHIVES);
    }
    
    // Check if file manager is available
    if (!window.FileManager) {
      console.log('⚠️ FileManager not initialized, attempting setup');
      setupMockFileSystem();
      
      if (!window.FileManager) {
        if (window.ErrorHandler) {
          window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
        }
        return Promise.reject(new Error('File Manager not initialized'));
      }
    }
    
    return window.FileManager.getArchives()
      .then(archives => {
        archiveList = archives || [];
        
        // Reset loading state
        if (window.ErrorHandler) {
          window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
        }
        
        return archives;
      });
  };
}
