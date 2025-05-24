// sw-wacz.js - Service Worker for WACZ Processing
// This service worker handles loading and serving content from WACZ archives

// Cache name for WACZ archives
const WACZ_CACHE_NAME = 'wacz-cache-v1';

// In-memory store for archive information
const archiveRegistry = new Map();

// Install event - cache core app files
self.addEventListener('install', event => {
  // Skip waiting for new service worker activation
  self.skipWaiting();
  console.log('💼 WACZ Service Worker installed');
});

// Activate event - clean up old caches and take control
self.addEventListener('activate', event => {
  event.waitUntil(
    Promise.all([
      // Take control of all clients
      clients.claim(),
      
      // Clean up any old caches
      caches.keys().then(cacheNames => {
        return Promise.all(
          cacheNames.filter(cacheName => {
            return cacheName !== WACZ_CACHE_NAME;
          }).map(cacheName => {
            return caches.delete(cacheName);
          })
        );
      })
    ])
  );
  console.log('🚀 WACZ Service Worker activated and controlling the page');
});

// Message event - handle communication from the app
self.addEventListener('message', event => {
  const message = event.data;
  
  console.log('📨 Service Worker received message:', message.type);
  
  switch (message.type) {
    case 'REGISTER_ARCHIVE':
      registerArchive(message.archiveId, message.url, message.size, event.ports[0]);
      break;
      
    case 'UNREGISTER_ARCHIVE':
      unregisterArchive(message.archiveId, event.ports[0]);
      break;
      
    case 'PING':
      event.ports[0].postMessage({
        type: 'PONG',
        message: 'Service worker is active'
      });
      break;
      
    default:
      console.warn('⚠️ Unknown message type:', message.type);
  }
});

// Fetch event - intercept requests to serve archived content
self.addEventListener('fetch', event => {
  let url;
  
  try {
    url = new URL(event.request.url);
  } catch (error) {
    console.error('❌ Error parsing URL:', event.request.url);
    return; // Let the browser handle this request
  }
  
  // Special handling for Capacitor custom URL scheme
  const isCapacitorScheme = url.protocol === 'capacitor:' || 
                            event.request.url.startsWith('capacitor://localhost');
  
  // Check if this is a request for archived content
  if (url.searchParams.has('waczArchive')) {
    const archiveId = url.searchParams.get('waczArchive');
    const path = url.searchParams.get('path') || '';
    
    console.log(`🔍 Service Worker intercepting request for archive: ${archiveId}, path: ${path}`);
    
    event.respondWith(
      serveFromArchive(archiveId, path, event.request)
    );
    return;
  }
  
  // For non-archive requests, proceed with normal fetch
  event.respondWith(fetch(event.request));
});

// Register an archive with the service worker
async function registerArchive(archiveId, url, size, port) {
  try {
    console.log(`📂 Registering archive ${archiveId} from ${url}`);
    
    // Store archive information in registry
    archiveRegistry.set(archiveId, {
      url,
      size,
      dateAdded: new Date().toISOString()
    });
    
    // Respond with success message
    port.postMessage({
      type: 'ARCHIVE_REGISTERED',
      archiveId,
      success: true
    });
  } catch (error) {
    console.error('❌ Error registering archive:', error);
    port.postMessage({
      type: 'ARCHIVE_REGISTERED',
      archiveId,
      success: false,
      error: error.message
    });
  }
}

// Unregister an archive from the service worker
function unregisterArchive(archiveId, port) {
  try {
    console.log(`🗑️ Unregistering archive ${archiveId}`);
    
    // Remove archive from registry
    archiveRegistry.delete(archiveId);
    
    // Respond with success message
    port.postMessage({
      type: 'ARCHIVE_UNREGISTERED',
      archiveId,
      success: true
    });
  } catch (error) {
    console.error('❌ Error unregistering archive:', error);
    port.postMessage({
      type: 'ARCHIVE_UNREGISTERED',
      archiveId,
      success: false,
      error: error.message
    });
  }
}

// Resolve base URL based on environment
function getBaseUrl() {
  const location = self.location;
  
  // In browser preview environments
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    return `${location.protocol}//${location.host}`;
  }
  
  // In Capacitor environment
  if (location.protocol === 'capacitor:') {
    return 'capacitor://localhost';
  }
  
  // Handle iOS WKWebView case (file protocol with special path format)
  if (location.protocol === 'file:') {
    // iOS WKWebView uses file:// URLs
    console.log('📱 Service worker running in iOS WKWebView environment');
    return 'file://'; // Use minimal base for iOS
  }
  
  // Default
  return self.location.origin;
}

// Serve content from an archive
async function serveFromArchive(archiveId, path, request) {
  try {
    // Check if we have this archive registered
    if (!archiveRegistry.has(archiveId)) {
      console.error(`❌ Archive ${archiveId} not registered`);
      return new Response(`Archive ${archiveId} not registered`, { 
        status: 404,
        headers: { 'Content-Type': 'text/plain' }
      });
    }
    
    const archive = archiveRegistry.get(archiveId);
    
    // Check cache first
    const cacheName = `archive-${archiveId}`;
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      console.log(`💾 Serving from cache: ${request.url}`);
      return cachedResponse;
    }
    
    // If not in cache, get from server
    // Build the actual URL to fetch from the server
    let serverUrl;
    if (path) {
      // For specific paths within the archive
      serverUrl = `http://localhost:3333/${archiveId}/${path}`;
    } else {
      // For the main archive file
      serverUrl = archive.url || `http://localhost:3333/${archiveId}`;
    }
    
    console.log(`🔄 Fetching from server: ${serverUrl}`);
    
    // Create a new request with appropriate credentials and mode
    const serverRequest = new Request(serverUrl, {
      method: request.method,
      headers: request.headers,
      mode: 'cors',  // Allow cross-origin requests
      credentials: 'include',  // Include credentials
      redirect: 'follow'
    });
    
    try {
      const serverResponse = await fetch(serverRequest);
      
      // Clone the response so we can cache it and return it
      const responseToCache = serverResponse.clone();
      
      // Cache the response for future requests
      await cache.put(request, responseToCache);
      
      return serverResponse;
    } catch (fetchError) {
      console.error(`❌ Error fetching from server: ${fetchError.message}`);
      
      // If we're running in Capacitor, try a different approach for local files
      if (typeof window !== 'undefined' && window.Capacitor) {
        console.log('ℹ️ Attempting alternative fetch method for Capacitor');
        // Implementation details would depend on how your local server is set up
      }
      
      return new Response(`Error fetching content: ${fetchError.message}`, { 
        status: 502,
        headers: { 'Content-Type': 'text/plain' }
      });
    }
  } catch (error) {
    console.error(`❌ Error serving content from archive ${archiveId}:`, error);
    return new Response(`Error serving content: ${error.message}`, { 
      status: 500,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}
