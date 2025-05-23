/**
 * ReplayWeb.page Mobile - Archive Viewer Integration
 * 
 * This module handles the integration between the native app and
 * the ReplayWeb.page archive viewer, managing the transitions
 * and communication between components.
 */

// State tracking
let currentArchive = null;
let viewerReady = false;
let lastViewedUrl = null;

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', initArchiveViewer);

/**
 * Initialize the archive viewer integration
 */
function initArchiveViewer() {
  // Check if we're viewing an archive by checking URL parameters
  const urlParams = new URLSearchParams(window.location.search);
  const sourceParam = urlParams.get('source');
  const urlParam = urlParams.get('url');
  const warcParam = urlParams.get('warc');
  const waczArchiveParam = urlParams.get('waczArchive');
  
  if (sourceParam || urlParam || warcParam || waczArchiveParam) {
    console.log('🔍 Archive viewer mode detected');
    setupViewerMode();
  } else {
    console.log('🏠 Archive browser mode detected');
    setupBrowserMode();
  }
  
  // Listen for the ReplayWeb.page ready event
  document.addEventListener('replay-app-ready', handleReplayAppReady);
  
  // Setup navigation event listeners
  setupNavigationListeners();
}

/**
 * Setup the app in viewer mode (showing ReplayWeb.page)
 */
function setupViewerMode() {
  // Hide the archive browser if it exists
  const archiveBrowser = document.getElementById('archive-browser');
  if (archiveBrowser) {
    archiveBrowser.style.display = 'none';
  }
  
  // Show the ReplayWeb.page viewer
  const replayApp = document.querySelector('replay-app-main');
  if (replayApp) {
    replayApp.style.display = 'block';
  }
  
  // Parse URL to detect which archive is being viewed
  parseCurrentArchive();
  
  // Add back button
  addBackButton();
}

/**
 * Setup the app in browser mode (showing archive list)
 */
function setupBrowserMode() {
  // Hide the ReplayWeb.page viewer
  const replayApp = document.querySelector('replay-app-main');
  if (replayApp) {
    replayApp.style.display = 'none';
  }
  
  // Show the archive browser
  const archiveBrowser = document.getElementById('archive-browser');
  if (archiveBrowser) {
    archiveBrowser.style.display = 'flex';
  }
}

/**
 * Parse the current URL to determine which archive is being viewed
 */
function parseCurrentArchive() {
  const urlParams = new URLSearchParams(window.location.search);
  const sourceParam = urlParams.get('source');
  const urlParam = urlParams.get('url');
  const warcParam = urlParams.get('warc');
  const waczArchiveParam = urlParams.get('waczArchive');
  
  // Handle service worker archive loading
  if (waczArchiveParam) {
    console.log(`💾 Viewing archive through Service Worker: ${waczArchiveParam}`);
    
    // Create archive object for service worker loaded archive
    currentArchive = {
      id: waczArchiveParam,
      name: decodeURIComponent(waczArchiveParam),
      usingServiceWorker: true
    };
    return;
  }
  
  // Handle traditional archive loading
  const archiveUrl = sourceParam || urlParam || warcParam;
  
  if (!archiveUrl) {
    console.warn('⚠️ No archive URL found in parameters');
    return;
  }
  
  lastViewedUrl = archiveUrl;
  
  // Try to extract the archive name from the URL
  let archiveName = '';
  
  try {
    if (archiveUrl.includes('/')) {
      archiveName = archiveUrl.split('/').pop();
    } else {
      archiveName = archiveUrl;
    }
    
    // Clean up URL parameters if they exist
    if (archiveName.includes('?')) {
      archiveName = archiveName.split('?')[0];
    }
    
    console.log(`📂 Viewing archive: ${archiveName}`);
    
    // Update window title
    document.title = `${archiveName} - ReplayWeb.page Mobile`;
    
    // Store current archive info
    currentArchive = {
      name: archiveName,
      url: archiveUrl
    };
  } catch (error) {
    console.error('❌ Error parsing archive URL:', error);
  }
}

/**
 * Add a back button to return to the archive browser
 */
function addBackButton() {
  // Check if we already have a back button
  if (document.getElementById('back-to-browser')) {
    return;
  }
  
  // Create back button
  const backButton = document.createElement('button');
  backButton.id = 'back-to-browser';
  backButton.className = 'back-button';
  backButton.innerHTML = '◀ Archives';
  backButton.title = 'Back to Archive List';
  
  // Style the button
  backButton.style.position = 'fixed';
  backButton.style.top = '10px';
  backButton.style.left = '10px';
  backButton.style.zIndex = '9999';
  backButton.style.padding = '8px 12px';
  backButton.style.backgroundColor = 'rgba(41, 98, 255, 0.9)';
  backButton.style.color = 'white';
  backButton.style.border = 'none';
  backButton.style.borderRadius = '4px';
  backButton.style.fontWeight = 'bold';
  backButton.style.fontSize = '14px';
  backButton.style.cursor = 'pointer';
  backButton.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
  
  // Add click event to return to archive browser
  backButton.addEventListener('click', function() {
    navigateToArchiveBrowser();
  });
  
  // Add button to the body
  document.body.appendChild(backButton);
}

/**
 * Handle ReplayWeb.page ready event
 */
function handleReplayAppReady() {
  console.log('✅ ReplayWeb.page viewer is ready');
  viewerReady = true;
  
  // Hide loading screen if shown
  const loadingScreen = document.getElementById('loading-screen');
  if (loadingScreen) {
    loadingScreen.style.display = 'none';
  }
  
  // Configure ReplayWeb.page for Service Worker compatibility if needed
  const urlParams = new URLSearchParams(window.location.search);
  const waczArchiveParam = urlParams.get('waczArchive');
  
  if (waczArchiveParam && window.useServiceWorker && 'serviceWorker' in navigator) {
    console.log('🔄 Configuring ReplayWeb.page to use Service Worker for archive access');
    
    // Get the ReplayWeb.page controller
    const replayApp = document.querySelector('replay-app-main');
    if (replayApp && replayApp.wrController) {
      // Tell ReplayWeb.page to use our service worker for loading archives
      replayApp.wrController.useServiceWorker = true;
      console.log('✅ ReplayWeb.page configured to use Service Worker');
    }
  }
  
  // Reset app loading state if error handler is available
  if (window.ErrorHandler) {
    window.ErrorHandler.setLoadingState(ErrorTypes.IDLE);
  }
  
  // Announce the loaded archive to the user
  announceLoadedArchive();
}

/**
 * Announce the loaded archive to the user
 */
function announceLoadedArchive() {
  if (!currentArchive) {
    return;
  }
  
  // Show toast if available
  if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: `Loaded archive: ${currentArchive.name}`,
      duration: 'short'
    });
  }
}

/**
 * Navigate back to the archive browser
 */
function navigateToArchiveBrowser() {
  window.location.href = 'index.html';
}

/**
 * Setup navigation event listeners
 */
function setupNavigationListeners() {
  // Handle hardware back button on Android using Capacitor if available
  if (window.Capacitor?.Plugins?.App) {
    window.Capacitor.Plugins.App.addListener('backButton', function() {
      // If we're in viewer mode, go back to archive browser
      const urlParams = new URLSearchParams(window.location.search);
      const isViewingArchive = urlParams.get('source') || urlParams.get('url') || urlParams.get('warc');
      
      if (isViewingArchive) {
        navigateToArchiveBrowser();
      } else {
        // In browser mode, we'd typically exit the app, but that's handled by the OS
      }
    });
  }
}

// Expose functions to window object
window.ArchiveViewer = {
  getCurrentArchive: function() {
    return currentArchive;
  },
  navigateToArchiveBrowser: navigateToArchiveBrowser,
  /**
   * Load the selected archive with performance optimizations
   */
  loadArchive: function(archive) {
    if (!archive) {
      console.error('❌ Invalid archive object');
      return;
    }
    
    let viewerUrl;
    
    // Check if we should use service workers
    if (window.useServiceWorker && window.ServiceWorkerBridge && 'serviceWorker' in navigator) {
      console.log('🔄 Using Service Worker for archive loading');
      
      // Generate a unique ID for this archive if it doesn't have one
      const archiveId = archive.id || `archive_${Date.now()}`;
      
      // Get the URL of the archive
      const archiveUrl = archive.url || `http://localhost:3333/${archive.name}`;
      
      // Register the archive with the service worker and navigate
      window.ServiceWorkerBridge.registerArchive(archiveId, archiveUrl, archive.size || 0)
        .then(response => {
          if (response.success) {
            console.log('✅ Archive registered with Service Worker');
            
            // Create URL for loading WACZ through service worker
            const swViewerUrl = `index.html?waczArchive=${encodeURIComponent(archiveId)}`;
            console.log(`🔄 Navigating to: ${swViewerUrl}`);
            window.location.href = swViewerUrl;
          } else {
            console.error('❌ Failed to register archive with Service Worker, falling back to direct loading');
            window.ArchiveViewer.loadArchiveWithoutServiceWorker(archive);
          }
        })
        .catch(error => {
          console.error('❌ Error registering archive with Service Worker:', error);
          window.ArchiveViewer.loadArchiveWithoutServiceWorker(archive);
        });
    } else {
      // Use standard loading without service worker
      window.ArchiveViewer.loadArchiveWithoutServiceWorker(archive);
    }
  },
  
  /**
   * Load archive without using service worker
   */
  loadArchiveWithoutServiceWorker: function(archive) {
    if (!archive || !archive.url) {
      console.error('❌ Invalid archive object or missing URL');
      return;
    }
    
    // Apply performance optimizations if available
    let optimizedArchive = archive;
    let viewerUrl;
    
    if (window.PerformanceManager?.optimizeArchiveLoading) {
      // Get optimized archive with performance enhancements
      optimizedArchive = window.PerformanceManager.optimizeArchiveLoading(archive);
      
      // Use optimized URL if available
      if (optimizedArchive.optimizedUrl) {
        viewerUrl = optimizedArchive.optimizedUrl;
      } else {
        // Construct URL with optimization parameters
        const baseUrl = `index.html?source=${encodeURIComponent(archive.url)}`;
        viewerUrl = window.PerformanceManager.optimizeViewerUrl(baseUrl, archive);
      }
      
      console.log('💡 Using optimized loading for archive:', 
        optimizedArchive.streaming ? 'streaming mode' : 'standard mode',
        optimizedArchive.useChunks ? `(${Math.round(optimizedArchive.chunkSize/1024/1024)}MB chunks)` : '');
    } else {
      // Fallback to standard loading without optimizations
      viewerUrl = `index.html?source=${encodeURIComponent(archive.url)}`;
    }
    
    // Navigate to the viewer
    window.location.href = viewerUrl;
  }
};