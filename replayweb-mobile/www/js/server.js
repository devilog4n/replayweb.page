// Server state tracking
let isServerRunning = false;
let serverPort = 3333;
let serverBaseUrl = `http://localhost:${serverPort}`;

// Get error handler references
const ErrorTypes = window.ReplayMobile?.ErrorTypes || {};
const LoadingStates = window.ReplayMobile?.LoadingStates || {};

// Enhanced server initialization function
function startServer() {
  // Update loading state
  if (window.ErrorHandler) {
    window.ErrorHandler.setLoadingState(LoadingStates.SERVER_STARTING);
  }
  
  // Check if Capacitor is available
  if (!window.Capacitor) {
    const error = new Error('Capacitor framework not available');
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.SERVER);
    } else {
      console.error('❌ Capacitor not available');
      showErrorMessage('Capacitor framework not available');
    }
    return Promise.reject(error);
  }
  
  // Check if HTTP plugin is available
  if (!window.Capacitor.Plugins.Http) {
    const error = new Error('HTTP server plugin not available');
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.SERVER);
    } else {
      console.error('❌ Capacitor Http plugin not available');
      showErrorMessage('HTTP server plugin not available');
    }
    return Promise.reject(error);
  }
  
  // If server is already running, return immediately
  if (isServerRunning) {
    console.log('ℹ️ Server already running at ' + serverBaseUrl);
    
    // Update loading state to idle since server is already running
    if (window.ErrorHandler) {
      window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
    }
    
    return Promise.resolve(serverBaseUrl);
  }
  
  console.log('🔄 Starting HTTP server...');
  
  // Set a timeout to check if the server takes too long to start
  const serverTimeout = setTimeout(() => {
    if (!isServerRunning && window.ErrorHandler) {
      window.ErrorHandler.handleError(
        'Server startup timed out after 15 seconds', 
        ErrorTypes.SERVER
      );
    }
  }, 15000);
  
  // Start the server
  return window.Capacitor.Plugins.Http.serve({
    hostname: 'localhost',
    port: serverPort,
    directory: 'DOCUMENTS',  // Directory constant for app documents
    path: 'warc-data'
  })
  .then(() => {
    // Clear the timeout since server started successfully
    clearTimeout(serverTimeout);
    
    console.log(`✅ Local HTTP server running at ${serverBaseUrl}`);
    isServerRunning = true;
    
    // Show success message to user
    showToast('HTTP server started successfully');
    
    // Update loading state
    if (window.ErrorHandler) {
      window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
    }
    
    // Return server URL for chaining
    return serverBaseUrl;
  })
  .catch(error => {
    // Clear the timeout since we already got an error
    clearTimeout(serverTimeout);
    
    // Handle the error
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.SERVER);
    } else {
      console.error('❌ Error starting HTTP server:', error);
      showErrorMessage(`Failed to start server: ${error.message || 'Unknown error'}`);
    }
    
    return Promise.reject(error);
  });
}

// Stop server function
function stopServer() {
  if (!isServerRunning || !window.Capacitor?.Plugins?.Http) {
    return Promise.resolve();
  }
  
  return window.Capacitor.Plugins.Http.stopServer()
    .then(() => {
      console.log('✅ HTTP server stopped');
      isServerRunning = false;
      showToast('Server stopped');
    })
    .catch(error => {
      console.error('❌ Error stopping server:', error);
    });
}

// Check if the warc-data directory has archive files
function checkForArchives() {
  if (!window.Capacitor?.Plugins?.Filesystem) {
    console.warn('⚠️ Filesystem plugin not available, can\'t check for archives');
    return Promise.resolve([]);
  }
  
  return window.Capacitor.Plugins.Filesystem.readdir({
    path: 'warc-data',
    directory: 'DOCUMENTS'
  })
  .then(result => {
    const files = result.files || [];
    const archiveFiles = files.filter(file => {
      const name = file.name.toLowerCase();
      return name.endsWith('.warc') || 
             name.endsWith('.warc.gz') || 
             name.endsWith('.wacz');
    });
    
    console.log(`ℹ️ Found ${archiveFiles.length} archive files`);
    return archiveFiles;
  })
  .catch(error => {
    console.error('❌ Error checking for archive files:', error);
    return [];
  });
}

// Helper function to show toast messages
function showToast(message, duration = 'short') {
  if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: message,
      duration: duration
    }).catch(err => console.error('Toast error:', err));
  } else {
    console.log(`Toast message: ${message}`);
  }
}

// Helper function to show error messages
function showErrorMessage(message) {
  console.error(message);
  showToast(`Error: ${message}`, 'long');
}
