/**
 * ReplayWeb.page Mobile - Error Handling and Loading States
 * 
 * This module provides centralized error handling and loading state management
 * for the ReplayWeb.page mobile application.
 */

// Global namespace initialization to prevent duplicate declarations on iOS
// This must be executed before any other code to ensure globals are properly set up
(function initializeGlobals() {
  // Initialize global namespace for the app
  window.ReplayMobile = window.ReplayMobile || {};
  
  // Error types for categorizing different errors
  window.ReplayMobile.ErrorTypes = window.ReplayMobile.ErrorTypes || {
    SERVER: 'server_error',
    FILESYSTEM: 'filesystem_error',
    NETWORK: 'network_error',
    ARCHIVE: 'archive_error',
    VIEWER: 'viewer_error',
    UNKNOWN: 'unknown_error'
  };
  
  // Loading state types
  window.ReplayMobile.LoadingStates = window.ReplayMobile.LoadingStates || {
    INITIALIZING: 'initializing',
    SERVER_STARTING: 'server_starting',
    LOADING_ARCHIVES: 'loading_archives',
    IMPORTING_ARCHIVE: 'importing_archive',
    LOADING_ARCHIVE: 'loading_archive',
    DELETING_ARCHIVE: 'deleting_archive',
    VIEWER_LOADING: 'viewer_loading',
    IDLE: 'idle'
  };
})();

// Local references for convenience - these don't create new global variables
const ErrorTypes = window.ReplayMobile.ErrorTypes;

// Use the LoadingStates from our global namespace
const LoadingStates = window.ReplayMobile.LoadingStates;

// State management
let currentLoadingState = LoadingStates.IDLE;
let loadingStartTime = null;
let errorLog = [];
const MAX_ERROR_LOG = 50;

// DOM elements cache
let loadingIndicator = null;
let loadingStatusText = null;
let errorContainer = null;

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', function() {
  // Initialize elements cache
  loadingIndicator = document.getElementById('app-loading');
  loadingStatusText = document.getElementById('loading-status');
  errorContainer = document.getElementById('error-container');
  
  // Create error container if it doesn't exist
  if (!errorContainer) {
    createErrorContainer();
  }
});

/**
 * Create an error container for displaying errors to the user
 */
function createErrorContainer() {
  errorContainer = document.createElement('div');
  errorContainer.id = 'error-container';
  errorContainer.style.display = 'none';
  errorContainer.style.position = 'fixed';
  errorContainer.style.bottom = '20px';
  errorContainer.style.left = '50%';
  errorContainer.style.transform = 'translateX(-50%)';
  errorContainer.style.backgroundColor = 'rgba(229, 57, 53, 0.95)';
  errorContainer.style.color = 'white';
  errorContainer.style.padding = '12px 20px';
  errorContainer.style.borderRadius = '8px';
  errorContainer.style.boxShadow = '0 4px 8px rgba(0, 0, 0, 0.2)';
  errorContainer.style.zIndex = '10000';
  errorContainer.style.maxWidth = '90%';
  errorContainer.style.textAlign = 'center';
  errorContainer.style.transition = 'opacity 0.3s ease-in-out';
  errorContainer.style.fontSize = '14px';
  
  // Add close button
  const closeButton = document.createElement('button');
  closeButton.innerHTML = '×';
  closeButton.style.position = 'absolute';
  closeButton.style.top = '5px';
  closeButton.style.right = '5px';
  closeButton.style.background = 'none';
  closeButton.style.border = 'none';
  closeButton.style.color = 'white';
  closeButton.style.fontSize = '20px';
  closeButton.style.padding = '0 5px';
  closeButton.style.cursor = 'pointer';
  closeButton.addEventListener('click', function() {
    hideError();
  });
  
  errorContainer.appendChild(closeButton);
  
  // Add error message element
  const errorMessage = document.createElement('div');
  errorMessage.id = 'error-message';
  errorContainer.appendChild(errorMessage);
  
  // Add to body
  document.body.appendChild(errorContainer);
}

/**
 * Set the current loading state
 * @param {string} state The new loading state from LoadingStates enum
 * @param {string} message Optional custom message to display
 */
function setLoadingState(state, message = null) {
  // Update state
  currentLoadingState = state;
  
  // If we're moving to a loading state, record the start time
  if (state !== LoadingStates.IDLE) {
    loadingStartTime = new Date().getTime();
  } else {
    loadingStartTime = null;
  }
  
  // Update UI based on state
  updateLoadingUI(state, message);
  
  // Log state change for debugging
  console.log(`🔄 Loading state: ${state}${message ? ` - ${message}` : ''}`);
  
  // For idle state, hide the loading UI
  if (state === LoadingStates.IDLE && loadingIndicator) {
    hideLoadingScreen();
  }
}

/**
 * Update the loading UI based on the current state
 * @param {string} state The current loading state
 * @param {string} customMessage Optional custom message to display
 */
function updateLoadingUI(state, customMessage = null) {
  if (!loadingStatusText) {
    return;
  }
  
  // If we have a custom message, use it
  if (customMessage) {
    loadingStatusText.textContent = customMessage;
    return;
  }
  
  // Otherwise use a default message based on the state
  let message = '';
  
  switch (state) {
    case LoadingStates.INITIALIZING:
      message = 'Initializing application...';
      break;
    case LoadingStates.SERVER_STARTING:
      message = 'Starting server...';
      break;
    case LoadingStates.LOADING_ARCHIVES:
      message = 'Loading available archives...';
      break;
    case LoadingStates.IMPORTING_ARCHIVE:
      message = 'Importing archive...';
      break;
    case LoadingStates.LOADING_ARCHIVE:
      message = 'Loading archive...';
      break;
    case LoadingStates.DELETING_ARCHIVE:
      message = 'Deleting archive...';
      break;
    case LoadingStates.VIEWER_LOADING:
      message = 'Loading viewer...';
      break;
    case LoadingStates.IDLE:
    default:
      message = 'Ready';
      break;
  }
  
  loadingStatusText.textContent = message;
}

/**
 * Hide the loading screen
 */
function hideLoadingScreen() {
  if (!loadingIndicator) {
    return;
  }
  
  // Add hidden class to trigger transition
  loadingIndicator.classList.add('hidden');
  
  // Remove from DOM after transition
  setTimeout(function() {
    if (loadingIndicator.parentNode) {
      loadingIndicator.parentNode.removeChild(loadingIndicator);
    }
    
    // Clear reference
    loadingIndicator = null;
  }, 500);
}

/**
 * Handle and display an error
 * @param {Error|string} error The error object or message
 * @param {string} type The type of error from ErrorTypes enum
 * @param {boolean} showToUser Whether to show the error to the user
 * @returns {Object} The handled error object
 */
function handleError(error, type = ErrorTypes.UNKNOWN, showToUser = true) {
  // Normalize the error
  const errorObj = {
    message: typeof error === 'string' ? error : (error.message || 'Unknown error'),
    type: type,
    timestamp: new Date().toISOString(),
    stack: error.stack || null,
    original: error
  };
  
  // Log the error
  console.error(`❌ [${errorObj.type}] ${errorObj.message}`, error);
  
  // Add to error log, maintaining maximum size
  errorLog.unshift(errorObj);
  if (errorLog.length > MAX_ERROR_LOG) {
    errorLog.pop();
  }
  
  // Show error to user if requested
  if (showToUser) {
    showError(errorObj.message);
    
    // Also use native toast if available
    if (window.Capacitor?.Plugins?.Toast) {
      window.Capacitor.Plugins.Toast.show({
        text: `Error: ${errorObj.message}`,
        duration: 'long'
      });
    }
  }
  
  return errorObj;
}

/**
 * Show an error message to the user
 * @param {string} message The error message to display
 * @param {number} duration How long to show the error in ms (0 = until dismissed)
 */
function showError(message, duration = 5000) {
  if (!errorContainer) {
    createErrorContainer();
  }
  
  // Update error message
  const messageElement = document.getElementById('error-message');
  if (messageElement) {
    messageElement.textContent = message;
  }
  
  // Show the error container
  errorContainer.style.display = 'block';
  errorContainer.style.opacity = '1';
  
  // Automatically hide after duration (if specified)
  if (duration > 0) {
    setTimeout(function() {
      hideError();
    }, duration);
  }
}

/**
 * Hide the error message
 */
function hideError() {
  if (!errorContainer) {
    return;
  }
  
  // Fade out
  errorContainer.style.opacity = '0';
  
  // Hide after transition
  setTimeout(function() {
    errorContainer.style.display = 'none';
  }, 300);
}

/**
 * Get the loading state duration in milliseconds
 * @returns {number} Duration in ms or 0 if not loading
 */
function getLoadingDuration() {
  if (!loadingStartTime) {
    return 0;
  }
  
  return new Date().getTime() - loadingStartTime;
}

/**
 * Get the error log
 * @returns {Array} The error log
 */
function getErrorLog() {
  return errorLog;
}

/**
 * Clear the error log
 */
function clearErrorLog() {
  errorLog = [];
}

/**
 * Check if an operation timed out
 * @param {number} maxDuration Maximum acceptable duration in ms
 * @returns {boolean} Whether the operation timed out
 */
function checkTimeout(maxDuration = 10000) {
  const duration = getLoadingDuration();
  return duration > 0 && duration > maxDuration;
}

// Export functionality to window
window.ErrorHandler = {
  ErrorTypes,
  LoadingStates,
  setLoadingState,
  handleError,
  showError,
  hideError,
  getErrorLog,
  clearErrorLog,
  hideLoadingScreen,
  getLoadingDuration,
  checkTimeout
};