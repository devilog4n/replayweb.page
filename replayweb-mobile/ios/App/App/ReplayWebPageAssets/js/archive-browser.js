/**
 * ReplayWeb.page Mobile - Archive Browser UI
 * 
 * This module provides a simple UI for browsing and managing WARC archives.
 */

// Initialize the browser when DOM is loaded and we're in the right context
document.addEventListener('DOMContentLoaded', function() {
  // Check if we're on the main page and not already viewing an archive
  const urlParams = new URLSearchParams(window.location.search);
  const isViewingArchive = urlParams.has('source') || urlParams.has('url') || urlParams.has('warc');
  
  if (isViewingArchive) {
    // If already viewing an archive, do nothing
    return;
  }
  
  // If DOM has the archive-browser element, initialize the UI
  const archiveBrowser = document.getElementById('archive-browser');
  if (archiveBrowser) {
    initArchiveBrowser(archiveBrowser);
  }
});

/**
 * Initialize the archive browser UI
 * @param {HTMLElement} container The container element
 */
function initArchiveBrowser(container) {
  // Make sure the container is visible
  container.style.display = 'flex';
  
  // Get UI elements
  const archiveList = container.querySelector('.archive-list');
  const importButton = container.querySelector('.import-button');
  const refreshButton = container.querySelector('.refresh-button');
  const noArchivesMessage = container.querySelector('.no-archives-message');
  
  // Initialize event listeners
  if (importButton) {
    importButton.addEventListener('click', function() {
      if (window.AppManager?.importArchive) {
        window.AppManager.importArchive();
      } else {
        showMessage('Import functionality not available', 'error');
      }
    });
  }
  
  // Handle refresh button click
  if (refreshButton) {
    refreshButton.addEventListener('click', () => {
      console.log('🔄 Refresh button clicked');
      
      // Display loading state immediately for better UX
      if (archiveList) {
        archiveList.innerHTML = '<div class="archive-item loading">Refreshing archives...</div>';
      }
      
      // Force reload of archives with a slight delay to ensure UI update
      setTimeout(() => {
        // Special handling for browser preview environments
        if (!window.Capacitor && window.location.hostname === 'localhost') {
          console.log('🔍 Special handling for browser preview refresh');
          // If FileManager exists but might be a partial mock implementation
          if (!window.FileManager || !window.FileManager._mockInitialized) {
            console.log('⚠️ Reloading page to ensure proper initialization');
            window.location.reload();
            return;
          }
        }
        
        refreshArchiveList(archiveList, noArchivesMessage);
      }, 100);
    });
  }
  
  // Initial load of archives
  refreshArchiveList(archiveList, noArchivesMessage);
}

/**
 * Refresh the archive list UI
 * @param {HTMLElement} listElement The list element to populate
 * @param {HTMLElement} noArchivesMessage Element to show when no archives exist
 */
function refreshArchiveList(listElement, noArchivesMessage) {
  if (!listElement) return;
  
  // Clear the current list
  listElement.innerHTML = '<div class="archive-item loading">Loading archives...</div>';
  
  // Check if we have the app and file manager available
  if (!window.AppManager) {
    listElement.innerHTML = '<div class="archive-item error">Archive management not available</div>';
    return;
  }
  
  // Special handling for browser preview environments
  if (!window.Capacitor && window.location.hostname === 'localhost') {
    console.log('🔍 Running in browser preview mode, ensuring mock initialization');
    // Ensure our mock initialization happened
    if (!window.FileManager) {
      console.warn('⚠️ FileManager not found, may not be completely initialized');
      listElement.innerHTML = '<div class="archive-item">⚙️ Setting up mock archive browser...</div>';
      // Force reload after a brief delay to ensure initialization completes
      setTimeout(() => window.location.reload(), 1000);
      return;
    }
  }
  
  // Get archives using the file manager
  window.AppManager.refreshArchives()
    .then(archives => {
      // Clear the loading indicator
      listElement.innerHTML = '';
      
      if (archives.length === 0) {
        // Show the no archives message if available
        if (noArchivesMessage) {
          noArchivesMessage.style.display = 'block';
        } else {
          // Otherwise use the list element
          listElement.innerHTML = '<div class="archive-item empty">No archives found</div>';
        }
        return;
      }
      
      // Hide the no archives message if we have archives
      if (noArchivesMessage) {
        noArchivesMessage.style.display = 'none';
      }
      
      // Create an element for each archive
      archives.forEach(archive => {
        const archiveElement = createArchiveElement(archive);
        listElement.appendChild(archiveElement);
      });
    })
    .catch(error => {
      console.error('Error refreshing archive list:', error);
      listElement.innerHTML = `<div class="archive-item error">Error: ${error.message || 'Unknown error'}</div>`;
    });
}

/**
 * Create an element to represent an archive in the list
 * @param {Object} archive The archive object
 * @returns {HTMLElement} The archive element
 */
function createArchiveElement(archive) {
  const element = document.createElement('div');
  element.className = 'archive-item';
  
  // Format file size
  const fileSize = formatFileSize(archive.size || 0);
  
  // Create date string if we have a modification time
  const dateStr = archive.mtime ? 
    new Date(archive.mtime).toLocaleDateString() : 'Unknown date';
  
  // Determine icon based on archive type
  const typeIcon = getArchiveTypeIcon(archive.type || getArchiveType(archive.name));
  
  // Create the HTML structure
  element.innerHTML = `
    <div class="archive-icon">${typeIcon}</div>
    <div class="archive-details">
      <div class="archive-name">${archive.name}</div>
      <div class="archive-meta">${archive.type || ''} · ${fileSize} · ${dateStr}</div>
    </div>
    <div class="archive-actions">
      <button class="load-button" title="Load Archive">▶️</button>
      <button class="delete-button" title="Delete Archive">🗑️</button>
    </div>
  `;
  
  // Add event listeners to buttons
  const loadButton = element.querySelector('.load-button');
  if (loadButton) {
    loadButton.addEventListener('click', function(event) {
      event.stopPropagation();
      loadArchive(archive);
    });
  }
  
  const deleteButton = element.querySelector('.delete-button');
  if (deleteButton) {
    deleteButton.addEventListener('click', function(event) {
      event.stopPropagation();
      deleteArchive(archive);
    });
  }
  
  // Make the whole item clickable to load the archive
  element.addEventListener('click', function() {
    loadArchive(archive);
  });
  
  return element;
}

/**
 * Load an archive
 * @param {Object} archive The archive to load
 */
function loadArchive(archive) {
  if (!window.AppManager) {
    showMessage('Archive loading not available', 'error');
    return;
  }
  
  // Set the selected archive and load it
  window.AppManager.setSelectedArchive(archive);
  window.AppManager.loadSelectedArchive();
}

/**
 * Delete an archive
 * @param {Object} archive The archive to delete
 */
function deleteArchive(archive) {
  if (!window.AppManager) {
    showMessage('Archive management not available', 'error');
    return;
  }
  
  // Confirm deletion
  if (!confirm(`Are you sure you want to delete "${archive.name}"?`)) {
    return;
  }
  
  // Set as selected archive and delete it
  window.AppManager.setSelectedArchive(archive);
  window.AppManager.deleteSelectedArchive()
    .then(() => {
      // Archive list will be refreshed by the delete function
      showMessage(`Deleted ${archive.name}`, 'success');
    })
    .catch(error => {
      showMessage(`Error deleting archive: ${error.message}`, 'error');
    });
}

/**
 * Format a file size in bytes to a human-readable string
 * @param {number} bytes The size in bytes
 * @returns {string} Formatted size string
 */
function formatFileSize(bytes) {
  if (bytes === 0) return '0 B';
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  
  return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + units[i];
}

/**
 * Get the type of archive based on file extension
 * @param {string} filename 
 * @returns {string} Archive type
 */
function getArchiveType(filename) {
  const lowerName = filename.toLowerCase();
  
  if (lowerName.endsWith('.wacz')) {
    return 'WACZ';
  } else if (lowerName.endsWith('.warc.gz')) {
    return 'WARC.GZ';
  } else if (lowerName.endsWith('.warc')) {
    return 'WARC';
  } else {
    return 'Unknown';
  }
}

/**
 * Get an icon for the archive type
 * @param {string} type The archive type
 * @returns {string} Icon HTML
 */
function getArchiveTypeIcon(type) {
  switch (type.toUpperCase()) {
    case 'WACZ':
      return '📦'; // Package
    case 'WARC.GZ':
      return '🗜️'; // Compressed
    case 'WARC':
      return '📄'; // Document
    default:
      return '❓'; // Unknown
  }
}

/**
 * Show a message to the user
 * @param {string} message The message to show
 * @param {string} type The type of message (success, error, info)
 */
function showMessage(message, type = 'info') {
  console.log(`[${type}] ${message}`);
  
  // Use toast if available through AppManager or directly
  if (window.AppManager?.showToast) {
    window.AppManager.showToast(message);
  } else if (window.Capacitor?.Plugins?.Toast) {
    window.Capacitor.Plugins.Toast.show({
      text: message,
      duration: type === 'error' ? 'long' : 'short'
    });
  }
  
  // In the future, this could show a UI notification as well
}