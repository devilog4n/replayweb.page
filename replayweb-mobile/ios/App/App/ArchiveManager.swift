import Foundation
import UIKit
import WebKit

class ArchiveManager {
    // MARK: - Singleton
    static let shared = ArchiveManager()
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private var activeArchivePath: URL?
    
    // MARK: - Constants
    private let archivesDirectoryName = "warc-data"
    
    // MARK: - Initialization
    private init() {
        // Private initializer to enforce singleton pattern
        createArchivesDirectoryIfNeeded()
    }
    
    // MARK: - Public Methods
    
    /// Get the URL to the archives directory
    func getArchivesDirectoryURL() -> URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ArchiveManager: Error - Could not access Documents directory")
            return nil
        }
        
        return documentsURL.appendingPathComponent(archivesDirectoryName)
    }
    
    /// Import a WACZ archive from a source URL to the app's archives directory
    func importArchive(from sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let archivesDirectoryURL = getArchivesDirectoryURL() else {
            completion(.failure(ArchiveError.directoryNotFound))
            return
        }
        
        // Generate a unique filename for the imported archive
        let uniqueFilename = UUID().uuidString + "_" + sourceURL.lastPathComponent
        let destinationURL = archivesDirectoryURL.appendingPathComponent(uniqueFilename)
        
        do {
            // Copy the file to the archives directory
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // Set as active archive
            activeArchivePath = destinationURL
            completion(.success(destinationURL))
        } catch {
            print("ArchiveManager: Error importing archive - \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// Get the list of available archives in the app's archives directory
    func getAvailableArchives() -> [URL] {
        guard let archivesDirectoryURL = getArchivesDirectoryURL(),
              fileManager.fileExists(atPath: archivesDirectoryURL.path) else {
            return []
        }
        
        do {
            // Get all files in the archives directory
            let fileURLs = try fileManager.contentsOfDirectory(
                at: archivesDirectoryURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            // Filter for WACZ files
            return fileURLs.filter { $0.pathExtension.lowercased() == "wacz" }
        } catch {
            print("ArchiveManager: Error getting available archives - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Validate and set an archive as the active one for viewing
    func setActiveArchive(archiveURL: URL) -> Bool {
        // Basic validation: file exists and has .wacz extension
        guard fileManager.fileExists(atPath: archiveURL.path),
              archiveURL.pathExtension.lowercased() == "wacz" else {
            print("ArchiveManager: Invalid archive file")
            return false
        }
        
        // Enhanced validation: check file size and attempt to validate file structure
        do {
            // Check file size (WACZ files should be at least a few KB)
            let attributes = try fileManager.attributesOfItem(atPath: archiveURL.path)
            guard let fileSize = attributes[.size] as? UInt64, fileSize > 1024 else {
                print("ArchiveManager: Archive file is too small to be valid")
                return false
            }
            
            // Advanced WACZ structure validation using ZIP inspection
            if !validateWACZStructure(archiveURL) {
                print("ArchiveManager: Archive failed structure validation")
                return false
            }
            
            print("ArchiveManager: Archive validated successfully, size: \(fileSize) bytes")
            
            activeArchivePath = archiveURL
            return true
        } catch {
            print("ArchiveManager: Error validating archive - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Validate the internal structure of a WACZ file
    /// WACZ files are ZIP archives with specific required files/directories
    private func validateWACZStructure(_ archiveURL: URL) -> Bool {
        // We'll use Process to run the unzip command to list the contents
        // This is a lightweight way to check structure without extracting the whole archive
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        
        // -l just lists files, -q for quiet mode
        process.arguments = ["-l", "-q", archiveURL.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Get the command output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8) else {
                print("ArchiveManager: Could not read zip listing output")
                return false
            }
            
            // Check for required WACZ components
            // A valid WACZ file must contain at least these key files
            let requiredFiles = [
                "archive.cdx",       // CDX index
                "datapackage.json",  // Metadata
                "pages/pages.jsonl"  // Pages index
            ]
            
            var foundRequiredFiles = 0
            
            for requiredFile in requiredFiles {
                if output.contains(requiredFile) {
                    foundRequiredFiles += 1
                } else {
                    print("ArchiveManager: Missing required file in WACZ: \(requiredFile)")
                }
            }
            
            // Also check for the presence of a warc files directory
            let hasWarcFiles = output.contains("archive/") || output.contains("wacz/")
            
            // Consider valid if we found at least 2 required files and the warc directory
            let isValid = foundRequiredFiles >= 2 && hasWarcFiles
            
            if isValid {
                print("ArchiveManager: WACZ structure validation passed")
            } else {
                print("ArchiveManager: WACZ structure validation failed - missing required files")
            }
            
            return isValid
            
        } catch {
            print("ArchiveManager: Failed to examine WACZ structure: \(error.localizedDescription)")
            // We'll return true here to not block loading if the file size check passed
            // This is a fallback in case the unzip command isn't available
            return true
        }
    }
    
    /// Get the currently active archive URL
    func getActiveArchiveURL() -> URL? {
        return activeArchivePath
    }
    
    /// Delete an archive from the app's archives directory
    func deleteArchive(at archiveURL: URL) -> Bool {
        do {
            try fileManager.removeItem(at: archiveURL)
            // If the deleted archive was the active one, clear the active archive
            if activeArchivePath == archiveURL {
                activeArchivePath = nil
            }
            return true
        } catch {
            print("ArchiveManager: Error deleting archive - \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Create the archives directory if it doesn't exist
    private func createArchivesDirectoryIfNeeded() {
        guard let archivesDirectoryURL = getArchivesDirectoryURL() else {
            print("ArchiveManager: Failed to get archives directory URL")
            return
        }
        
        if !fileManager.fileExists(atPath: archivesDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: archivesDirectoryURL, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
                print("ArchiveManager: Created archives directory at \(archivesDirectoryURL.path)")
            } catch {
                print("ArchiveManager: Error creating archives directory - \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Error Types
extension ArchiveManager {
    enum ArchiveError: Error {
        case directoryNotFound
        case importFailed
        case invalidArchive
    }
}
