// ReplayWeb.page Mobile - Main JavaScript
(function() {
  // Global archive URL setter for native app integration (as specified in PRD)
  window.setArchiveURL = function(archiveUrl) {
    console.log('Archive URL set by native app:', archiveUrl);
    loadArchive(archiveUrl);
    return true;
  };
  // Configuration
  const config = {
    defaultTitle: 'ReplayWeb.page Mobile',
    defaultCollection: null,
    allowUpload: true,
    clearOnLoad: true
  };

  // DOM Elements
  let archiveUrl = null;
  let iframeElem = null;
  let statusElem = null;
  let loadingElem = null;
  let errorElem = null;

  // Initialize the application
  function init() {
    // Create UI elements
    createUI();
    
    // Register service worker
    registerServiceWorker();
    
    // Check for source parameter in URL
    checkForSourceParam();
    
    // Add event listeners
    addEventListeners();
  }

  // Create the UI elements
  function createUI() {
    const container = document.getElementById('replay-container');
    if (!container) return;
    
    // Create status element
    statusElem = document.createElement('div');
    statusElem.className = 'replay-status';
    statusElem.textContent = 'Ready to load archive';
    container.appendChild(statusElem);
    
    // Create loading element
    loadingElem = document.createElement('div');
    loadingElem.className = 'replay-loading';
    loadingElem.innerHTML = '<div class="spinner"></div><div class="message">Loading archive...</div>';
    loadingElem.style.display = 'none';
    container.appendChild(loadingElem);
    
    // Create error element
    errorElem = document.createElement('div');
    errorElem.className = 'replay-error';
    errorElem.style.display = 'none';
    container.appendChild(errorElem);
    
    // Create iframe for replay
    iframeElem = document.createElement('iframe');
    iframeElem.className = 'replay-iframe';
    iframeElem.style.display = 'none';
    iframeElem.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms');
    container.appendChild(iframeElem);
  }

  // Register service worker
  function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js')
        .then(registration => {
          console.log('Service Worker registered with scope:', registration.scope);
          updateStatus('Service Worker registered');
        })
        .catch(error => {
          console.error('Service Worker registration failed:', error);
          updateStatus('Service Worker registration failed');
        });
    } else {
      console.warn('Service Workers not supported');
      updateStatus('Service Workers not supported');
    }
  }

  // Check for source parameter in URL
  function checkForSourceParam() {
    const urlParams = new URLSearchParams(window.location.search);
    const source = urlParams.get('source');
    
    if (source) {
      loadArchive(source);
    }
  }

  // Add event listeners
  function addEventListeners() {
    // Listen for messages from native app
    window.addEventListener('message', event => {
      if (event.data && event.data.action === 'loadArchive') {
        if (event.data.url) {
          loadArchive(event.data.url);
        }
      }
    });
    
    // Open archive button
    const openButton = document.getElementById('open-archive-btn');
    if (openButton) {
      openButton.addEventListener('click', () => {
        // This will be handled by the native app through the script message handler
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeApp) {
          window.webkit.messageHandlers.nativeApp.postMessage({action: 'openArchive'});
        } else {
          console.warn('Native app message handler not available');
          updateStatus('Native app integration not available');
        }
      });
    }
  }

  // Load an archive
  function loadArchive(url) {
    archiveUrl = url;
    
    updateStatus('Loading archive: ' + url);
    showLoading(true);
    showError(false);
    
    // Simple check if URL is valid
    if (!url || (!url.startsWith('/') && !url.startsWith('http'))) {
      showError('Invalid archive URL: ' + url);
      showLoading(false);
      return;
    }
    
    // Create a replay URL
    const replayUrl = createReplayUrl(url);
    
    // Load the iframe
    iframeElem.src = replayUrl;
    iframeElem.style.display = 'block';
    
    // Handle iframe load events
    iframeElem.onload = () => {
      showLoading(false);
      updateStatus('Archive loaded successfully');
    };
    
    iframeElem.onerror = () => {
      showLoading(false);
      showError('Failed to load archive');
    };
  }

  // Create a replay URL for the archive
  function createReplayUrl(archiveUrl) {
    // In a real implementation, this would create a URL that loads the archive
    // through the ReplayWeb.page replay engine. For our simplified version,
    // we'll just return a basic viewer page.
    return `/viewer.html?source=${encodeURIComponent(archiveUrl)}`;
  }

  // Update status message
  function updateStatus(message) {
    if (statusElem) {
      statusElem.textContent = message;
    }
    console.log('Status:', message);
  }

  // Show/hide loading indicator
  function showLoading(show) {
    if (loadingElem) {
      loadingElem.style.display = show ? 'flex' : 'none';
    }
  }

  // Show/hide error message
  function showError(message) {
    if (errorElem) {
      if (message) {
        errorElem.textContent = message;
        errorElem.style.display = 'block';
      } else {
        errorElem.style.display = 'none';
      }
    }
  }

  // Initialize when DOM is ready
  document.addEventListener('DOMContentLoaded', init);
})();
