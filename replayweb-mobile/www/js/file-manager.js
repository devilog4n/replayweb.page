/**
 * ReplayWeb.page Mobile - File Manager
 * 
 * This module provides file system access for WARC archives.
 * It handles reading, writing, and managing archive files.
 */

// Get error handler references
const ErrorTypes = window.ReplayMobile?.ErrorTypes || {};
const LoadingStates = window.ReplayMobile?.LoadingStates || {};

// Constants
const ARCHIVES_DIRECTORY = 'warc-data';
const DOCUMENTS_DIRECTORY = 'DOCUMENTS'; // Capacitor directory constant
const SUPPORTED_EXTENSIONS = ['.warc', '.warc.gz', '.wacz'];

// State management
let archiveList = [];
let isInitialized = false;

/**
 * Initialize the file system access
 * @returns {Promise<void>}
 */
async function initFileSystem() {
  // Update loading state if error handler is available
  if (window.ErrorHandler) {
    window.ErrorHandler.setLoadingState(LoadingStates.INITIALIZING, 'Initializing file system...');
  }
  
  // Skip if already initialized
  if (isInitialized) {
    if (window.ErrorHandler) {
      window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
    }
    return Promise.resolve();
  }
  
  // Check for required plugins
  if (!window.Capacitor?.Plugins?.Filesystem) {
    const error = new Error('Filesystem plugin not available');
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.FILESYSTEM);
    } else {
      console.error('❌ Filesystem plugin not available');
    }
    return Promise.reject(error);
  }
  
  try {
    // Ensure the archives directory exists
    await ensureArchivesDirectory();
    
    // Load the list of available archives
    await refreshArchiveList();
    
    isInitialized = true;
    console.log('✅ File system initialized');
    
    // Set loading state to idle
    if (window.ErrorHandler) {
      window.ErrorHandler.setLoadingState(LoadingStates.IDLE);
    }
    
    return Promise.resolve();
  } catch (error) {
    // Handle error
    if (window.ErrorHandler) {
      window.ErrorHandler.handleError(error, ErrorTypes.FILESYSTEM);
    } else {
      console.error('❌ Error initializing file system:', error);
    }
    return Promise.reject(error);
  }
}

/**
 * Ensure the archives directory exists
 * @returns {Promise<void>}
 */
async function ensureArchivesDirectory() {
  const fs = window.Capacitor.Plugins.Filesystem;
  
  try {
    // Check if directory exists
    await fs.readdir({
      path: ARCHIVES_DIRECTORY,
      directory: DOCUMENTS_DIRECTORY
    });
    
    console.log(`ℹ️ Archive directory exists: ${ARCHIVES_DIRECTORY}`);
  } catch (error) {
    // Directory doesn't exist, create it
    console.log(`ℹ️ Creating archive directory: ${ARCHIVES_DIRECTORY}`);
    
    try {
      await fs.mkdir({
        path: ARCHIVES_DIRECTORY,
        directory: DOCUMENTS_DIRECTORY,
        recursive: true
      });
      
      console.log(`✅ Created archive directory: ${ARCHIVES_DIRECTORY}`);
    } catch (mkdirError) {
      console.error(`❌ Failed to create archive directory: ${mkdirError.message}`);
      throw mkdirError;
    }
  }
}

/**
 * Refresh the list of available archives
 * @returns {Promise<Array>} List of archive files
 */
async function refreshArchiveList() {
  const fs = window.Capacitor.Plugins.Filesystem;
  
  try {
    const result = await fs.readdir({
      path: ARCHIVES_DIRECTORY,
      directory: DOCUMENTS_DIRECTORY
    });
    
    // Filter for supported archive files
    archiveList = (result.files || []).filter(file => {
      const name = file.name.toLowerCase();
      return SUPPORTED_EXTENSIONS.some(ext => name.endsWith(ext));
    });
    
    // Add additional metadata to each archive
    const archivesWithMetadata = [];
    
    for (const archive of archiveList) {
      try {
        const stat = await fs.stat({
          path: `${ARCHIVES_DIRECTORY}/${archive.name}`,
          directory: DOCUMENTS_DIRECTORY
        });
        
        archivesWithMetadata.push({
          ...archive,
          size: stat.size,
          mtime: stat.mtime,
          type: getArchiveType(archive.name),
          url: `http://localhost:3333/${archive.name}`
        });
      } catch (error) {
        // If stat fails, still include the file with basic info
        archivesWithMetadata.push({
          ...archive,
          size: 0,
          mtime: new Date().toISOString(),
          type: getArchiveType(archive.name),
          url: `http://localhost:3333/${archive.name}`
        });
      }
    }
    
    archiveList = archivesWithMetadata;
    console.log(`ℹ️ Found ${archiveList.length} archive files`);
    
    return archiveList;
  } catch (error) {
    console.error('❌ Error listing archive files:', error);
    return [];
  }
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
 * Get the list of available archives
 * @param {boolean} refresh Whether to refresh the list first
 * @returns {Promise<Array>} List of archive files
 */
async function getArchives(refresh = false) {
  if (refresh || archiveList.length === 0) {
    await refreshArchiveList();
  }
  
  return archiveList;
}

/**
 * Get an archive by filename
 * @param {string} filename The filename to find
 * @returns {Promise<Object|null>} The archive object or null if not found
 */
async function getArchiveByName(filename) {
  const archives = await getArchives();
  return archives.find(archive => archive.name === filename) || null;
}

/**
 * Import an archive file from a data URL
 * @param {string} dataUrl The data URL containing the file
 * @param {string} filename The target filename
 * @returns {Promise<Object>} The imported archive info
 */
async function importArchiveFromDataUrl(dataUrl, filename) {
  if (!window.Capacitor?.Plugins?.Filesystem) {
    return Promise.reject(new Error('Filesystem plugin not available'));
  }
  
  const fs = window.Capacitor.Plugins.Filesystem;
  
  try {
    // Validate filename has a supported extension
    if (!SUPPORTED_EXTENSIONS.some(ext => filename.toLowerCase().endsWith(ext))) {
      filename += '.warc'; // Default to .warc if no extension
    }
    
    // Write the file
    await fs.writeFile({
      path: `${ARCHIVES_DIRECTORY}/${filename}`,
      data: dataUrl,
      directory: DOCUMENTS_DIRECTORY,
      recursive: true
    });
    
    console.log(`✅ Imported archive: ${filename}`);
    
    // Refresh archive list
    await refreshArchiveList();
    
    // Return the imported archive info
    return getArchiveByName(filename);
  } catch (error) {
    console.error('❌ Error importing archive:', error);
    return Promise.reject(error);
  }
}

/**
 * Delete an archive file
 * @param {string} filename The filename to delete
 * @returns {Promise<boolean>} Success status
 */
async function deleteArchive(filename) {
  if (!window.Capacitor?.Plugins?.Filesystem) {
    return Promise.reject(new Error('Filesystem plugin not available'));
  }
  
  const fs = window.Capacitor.Plugins.Filesystem;
  
  try {
    await fs.deleteFile({
      path: `${ARCHIVES_DIRECTORY}/${filename}`,
      directory: DOCUMENTS_DIRECTORY
    });
    
    console.log(`✅ Deleted archive: ${filename}`);
    
    // Refresh archive list
    await refreshArchiveList();
    
    return true;
  } catch (error) {
    console.error(`❌ Error deleting archive ${filename}:`, error);
    return Promise.reject(error);
  }
}

/**
 * Rename an archive file
 * @param {string} oldFilename The current filename
 * @param {string} newFilename The new filename
 * @returns {Promise<Object>} The updated archive info
 */
async function renameArchive(oldFilename, newFilename) {
  if (!window.Capacitor?.Plugins?.Filesystem) {
    return Promise.reject(new Error('Filesystem plugin not available'));
  }
  
  // Validate new filename has a supported extension
  if (!SUPPORTED_EXTENSIONS.some(ext => newFilename.toLowerCase().endsWith(ext))) {
    // Preserve original extension
    const originalExt = SUPPORTED_EXTENSIONS.find(ext => oldFilename.toLowerCase().endsWith(ext)) || '.warc';
    newFilename += originalExt;
  }
  
  const fs = window.Capacitor.Plugins.Filesystem;
  
  try {
    // First read the file
    const result = await fs.readFile({
      path: `${ARCHIVES_DIRECTORY}/${oldFilename}`,
      directory: DOCUMENTS_DIRECTORY
    });
    
    // Then write it with the new name
    await fs.writeFile({
      path: `${ARCHIVES_DIRECTORY}/${newFilename}`,
      data: result.data,
      directory: DOCUMENTS_DIRECTORY
    });
    
    // Delete the original file
    await fs.deleteFile({
      path: `${ARCHIVES_DIRECTORY}/${oldFilename}`,
      directory: DOCUMENTS_DIRECTORY
    });
    
    console.log(`✅ Renamed archive: ${oldFilename} → ${newFilename}`);
    
    // Refresh archive list
    await refreshArchiveList();
    
    // Return the updated archive info
    return getArchiveByName(newFilename);
  } catch (error) {
    console.error(`❌ Error renaming archive ${oldFilename} → ${newFilename}:`, error);
    return Promise.reject(error);
  }
}

/**
 * Import an archive from the device's file system
 * Using Capacitor Camera plugin for file picking
 * @returns {Promise<Object>} The imported archive info
 */
async function importArchiveFromDevice() {
  if (!window.Capacitor?.Plugins?.Camera) {
    return Promise.reject(new Error('Camera plugin not available for file picking'));
  }
  
  try {
    // Use the camera plugin to pick a file
    const result = await window.Capacitor.Plugins.Camera.pickImages({
      limit: 1,
      quality: 100,
      presentationStyle: 'fullScreen'
    });
    
    if (!result.photos || result.photos.length === 0) {
      return Promise.reject(new Error('No file selected'));
    }
    
    const photo = result.photos[0];
    
    // Get file path
    const path = photo.path;
    let filename = path.split('/').pop();
    
    // If filename doesn't have a supported extension, show error
    if (!SUPPORTED_EXTENSIONS.some(ext => filename.toLowerCase().endsWith(ext))) {
      return Promise.reject(new Error('Selected file is not a supported archive type. Please select a .warc, .warc.gz, or .wacz file.'));
    }
    
    // Get the file data
    const fileData = await window.Capacitor.Plugins.Filesystem.readFile({
      path: path
    });
    
    // Import the file
    return importArchiveFromDataUrl(fileData.data, filename);
  } catch (error) {
    console.error('❌ Error importing archive from device:', error);
    return Promise.reject(error);
  }
}

// Export functions
window.FileManager = {
  initFileSystem,
  getArchives,
  getArchiveByName,
  importArchiveFromDataUrl,
  importArchiveFromDevice,
  deleteArchive,
  renameArchive,
  refreshArchiveList
};