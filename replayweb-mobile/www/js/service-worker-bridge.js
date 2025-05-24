/**
 * service-worker-bridge.js
 * 
 * This module provides a communication bridge between the main application
 * and the service worker for handling WACZ archives.
 */

window.ServiceWorkerBridge = (function() {
  // Private variables
  let _ready = false;
  let _pendingRequests = new Map();
  let _requestId = 0;
  let _registration = null;
  
  // Initialize the bridge
  async function initialize() {
    if (_ready) return true;
    
    try {
      console.log('🔄 Initializing Service Worker Bridge');
      
      // Check if service workers are supported
      if (!('serviceWorker' in navigator)) {
        console.warn('⚠️ Service Workers bypassed or not supported');
        window.useServiceWorker = false;
        return false;
      }
      
      // Enhanced iOS WKWebView handling
      if (typeof window.Capacitor !== 'undefined' && window.Capacitor.getPlatform() === 'ios') {
        console.log('📱 iOS platform detected, applying special WebKit handling');
        
        // For iOS, set a relatively fast timeout to avoid hanging the app
        const iosTimeout = 3000;  // 3 seconds maximum for iOS tests
        
        try {
          // Test if service worker registration is available and working
          await Promise.race([
            navigator.serviceWorker.getRegistration('./'),
            new Promise((_, reject) => setTimeout(() => reject(new Error('iOS SW test timeout')), iosTimeout))
          ]);
          
          // Additional iOS WebKit checks
          if (!navigator.serviceWorker.controller) {
            // If there's no active controller, we may need to reload or fall back
            console.log('📱 iOS service worker environment ready but no active controller');
            
            // Check for WebKit networking availability
            if (window.webkit?.messageHandlers) {
              console.log('✅ WebKit message handlers available');
            } else {
              console.warn('⚠️ WebKit message handlers not detected, may affect networking');  
            }
          }
        } catch (iosTestError) {
          console.warn('⚠️ iOS service worker test failed:', iosTestError);
          console.log('🛡️ Falling back to direct file access mode for iOS');
          window.useServiceWorker = false;
          return false;
        }
      }
      
      // Add a timeout to prevent endless waiting
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error('Service worker registration timed out')), 10000);
      });
      
      // When running in Capacitor/WKWebView on iOS, check for limitations
      const isCapacitorEnvironment = typeof window.Capacitor !== 'undefined';
      const isIOS = isCapacitorEnvironment && window.Capacitor.getPlatform() === 'ios';
      
      // If running on iOS, apply special handling for WKWebView
      if (isIOS) {
        console.log('📱 Running on iOS - applying special service worker configuration');
        
        // Get iOS version
        let iOSVersion = 16.0; // Default assumption for modern devices
        try {
          // Try to detect iOS version from user agent
          const userAgent = navigator.userAgent;
          const match = userAgent.match(/OS\s+(\d+)_(\d+)/i);
          if (match && match.length > 2) {
            iOSVersion = parseFloat(`${match[1]}.${match[2]}`);
            console.log(`📱 Detected iOS version: ${iOSVersion}`);
          }
        } catch (versionError) {
          console.warn('⚠️ Could not detect iOS version:', versionError);
        }
        
        // Service workers are only fully supported in iOS 16.4+
        if (iOSVersion < 16.4) {
          console.warn(`⚠️ Running on iOS ${iOSVersion}, which may have limited service worker support`);
          
          // Test if we can access the serviceWorker controller
          try {
            const testController = navigator.serviceWorker.controller;
            if (testController) {
              console.log('✅ iOS service worker controller detected');
            } else {
              console.log('⚠️ No active service worker controller found on iOS');
              // Add special handling for iOS without an active controller
              _forceCapacitorMode = true;
            }
          } catch (e) {
            console.error('❌ Service workers test failed on iOS:', e);
            console.log('🛡️ Falling back to direct file access mode');
            window.useServiceWorker = false;
            return false;
          }
        }
      }
      
      // Register the service worker
      // Use multiple possible paths to ensure it works in all environments
      // Root /sw.js path is critical for controlling /archives/ requests
      const possiblePaths = [
        '/sw.js',             // Absolute root path (PREFERRED for full scope)
        './sw.js',            // Relative path from current directory
        '../sw.js',           // One directory up
        './js/sw-wacz.js',    // Fallback to original paths
        'js/sw-wacz.js',      // Alternate relative path
        '/js/sw-wacz.js',     // Absolute path from domain root
      ];
      
      let registered = false;
      let lastError = null;
      
      // Try each path in sequence
      for (const path of possiblePaths) {
        if (registered) break;
        
        try {
          console.log(`ℹ️ Attempting to register service worker with path: ${path}`);
          
          // For iOS, use special registration settings to prevent network process crashes
          const registrationOptions = {
            scope: '/',          // ROOT SCOPE is critical for controlling /archives/ requests
            updateViaCache: 'none' // Important for WKWebView compatibility
          };
          
          // Add additional iOS-specific properties if needed
          if (isIOS) {
            // Setting a smaller script size limit for iOS to prevent crashes
            registrationOptions.maximumFileSize = 2 * 1024 * 1024; // 2MB limit for iOS
          }
          
          _registration = await Promise.race([
            navigator.serviceWorker.register(path, registrationOptions),
            timeoutPromise
          ]);
          
          console.log(`✅ Service worker registered successfully with path: ${path}`);
          registered = true;
          
          // Add special handling for iOS to prevent network process crashes
          if (isIOS && _registration) {
            // Add a small delay to ensure the service worker activates properly
            await new Promise(resolve => setTimeout(resolve, 500));
            
            // Force an update check to ensure the service worker is properly installed
            try {
              await _registration.update();
              console.log('📱 iOS service worker update check completed');
            } catch (updateError) {
              console.warn('⚠️ iOS service worker update check failed:', updateError);
              // Continue anyway - this is just a precaution
            }
          }
          
          break;
        } catch (error) {
          console.warn(`⚠️ Failed to register service worker with path: ${path}`, error);
          lastError = error;
          
          // Special handling for iOS network crashes
          if (isIOS && error.toString().includes('network')) {
            console.warn('🛡️ Possible iOS network process issue detected');
            // Add a longer delay before trying the next path on iOS network issues
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
        }
      }
      
      if (!registered) {
        console.error('❌ Service worker registration failed with all paths');
        throw lastError || new Error('Service worker registration failed');
      }
      
      console.log('✅ Service worker registered with scope:', _registration.scope);
      
      // Wait for the service worker to be active
      if (_registration.active) {
        console.log('✅ Service worker is already active');
        _ready = true;
      } else {
        // Wait for the service worker to activate
        console.log('⏳ Waiting for service worker to activate');
        
        if (_registration.installing) {
          _registration.installing.addEventListener('statechange', event => {
            console.log('🔄 Service worker state changed to:', event.target.state);
            
            if (event.target.state === 'activated') {
              console.log('✅ Service worker is now active');
              _ready = true;
            }
          });
        }
      }
      
      // Add message event listener
      navigator.serviceWorker.addEventListener('message', event => {
        handleMessage(event.data);
      });
      
      return _ready;
    } catch (error) {
      console.error('❌ Error initializing service worker bridge:', error);
      return false;
    }
  }
  
  // Send a message to the service worker
  async function sendMessage(message) {
    return new Promise((resolve, reject) => {
      if (!navigator.serviceWorker.controller) {
        reject(new Error('No active service worker found'));
        return;
      }
      
      // Create a unique ID for this request
      const id = `req_${_requestId++}`;
      message.id = id;
      
      // Create a message channel for the response
      const messageChannel = new MessageChannel();
      messageChannel.port1.onmessage = event => {
        const response = event.data;
        console.log('📨 Received response from service worker:', response);
        resolve(response);
      };
      
      // Store pending request
      _pendingRequests.set(id, {
        resolve,
        reject,
        timestamp: Date.now()
      });
      
      // Send the message to the service worker
      navigator.serviceWorker.controller.postMessage(message, [messageChannel.port2]);
      console.log('📤 Sent message to service worker:', message);
    });
  }
  
  // Handle incoming messages from the service worker
  function handleMessage(data) {
    console.log('📨 Received message from service worker:', data);
    
    if (data.id && _pendingRequests.has(data.id)) {
      const { resolve, reject } = _pendingRequests.get(data.id);
      _pendingRequests.delete(data.id);
      
      if (data.error) {
        reject(new Error(data.error));
      } else {
        resolve(data);
      }
    }
  }
  
  // Register an archive with the service worker
  async function registerArchive(archiveId, url, size) {
    try {
      if (!_ready) {
        await initialize();
      }
      
      if (!navigator.serviceWorker.controller) {
        throw new Error('Service worker not active');
      }
      
      return await sendMessage({
        type: 'REGISTER_ARCHIVE',
        archiveId,
        url,
        size
      });
    } catch (error) {
      console.error('❌ Error registering archive with service worker:', error);
      throw error;
    }
  }
  
  // Unregister an archive from the service worker
  async function unregisterArchive(archiveId) {
    try {
      if (!_ready) {
        await initialize();
      }
      
      return await sendMessage({
        type: 'UNREGISTER_ARCHIVE',
        archiveId
      });
    } catch (error) {
      console.error('❌ Error unregistering archive from service worker:', error);
      throw error;
    }
  }
  
  // Check if the service worker is active
  async function isActive() {
    try {
      if (!_ready) {
        await initialize();
      }
      
      // Ping the service worker to check if it's responsive
      const response = await sendMessage({ type: 'PING' });
      return response.type === 'PONG';
    } catch (error) {
      console.error('❌ Error checking service worker status:', error);
      return false;
    }
  }
  
  // Create a URL for accessing archive content through service worker
  function createArchiveUrl(archiveId, path = '') {
    const url = new URL(window.location.origin);
    url.searchParams.set('waczArchive', archiveId);
    
    if (path) {
      url.searchParams.set('path', path);
    }
    
    return url.toString();
  }
  
  // Public API
  return {
    initialize,
    registerArchive,
    unregisterArchive,
    isActive,
    createArchiveUrl
  };
})();
