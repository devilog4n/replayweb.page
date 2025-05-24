import Foundation
import UIKit
import GCDWebServer

class WebServerManager {
    // MARK: - Singleton
    static let shared = WebServerManager()
    
    // MARK: - Properties
    private var webServer: GCDWebServer?
    private(set) var isRunning = false
    private(set) var serverURL: URL?
    
    // Default port for the server
    private let serverPort: UInt = 8090
    
    // MARK: - Initialization
    private init() {
        // Private initializer to enforce singleton pattern
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopServer()
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the web server if it's not already running
    func startServer() -> Bool {
        guard !isRunning else {
            print("WebServerManager: Server is already running")
            return true
        }
        
        // Create a new GCDWebServer instance
        webServer = GCDWebServer()
        
        guard let webServer = webServer else {
            print("WebServerManager: Failed to create GCDWebServer instance")
            return false
        }
        
        // Configure and start the server
        if !configureServer(webServer) {
            print("WebServerManager: Failed to configure server")
            return false
        }
        
        if !startServer(webServer) {
            print("WebServerManager: Failed to start server")
            return false
        }
        
        isRunning = true
        print("WebServerManager: Server started successfully at \(serverURL?.absoluteString ?? "unknown URL")")
        return true
    }
    
    /// Stop the web server if it's running
    func stopServer() {
        guard isRunning, let webServer = webServer else { return }
        
        webServer.stop()
        isRunning = false
        serverURL = nil
        print("WebServerManager: Server stopped")
    }
    
    /// Restart the server
    func restartServer() -> Bool {
        stopServer()
        return startServer()
    }
    
    // MARK: - Private Methods
    
    /// Configure the server with handlers for static files and archives
    private func configureServer(_ server: GCDWebServer) -> Bool {
        // Get the path to the project's www directory
        // First try to find it in the app bundle (for production builds)
        var wwwPath = Bundle.main.path(forResource: "www", ofType: nil)
        
        // If not found in bundle, look for it in the project directory (for development)
        if wwwPath == nil {
            // Try to find the www directory by navigating up from the app bundle
            let fileManager = FileManager.default
            if let bundlePath = Bundle.main.bundlePath, 
               let projectPath = findProjectDirectory(startingFrom: bundlePath) {
                let potentialWWWPath = projectPath.appendingPathComponent("www").path
                if fileManager.fileExists(atPath: potentialWWWPath) {
                    // Verify this is actually a www directory with expected files
                    if validateWWWDirectory(potentialWWWPath) {
                        wwwPath = potentialWWWPath
                        print("WebServerManager: Using www directory from project path: \(potentialWWWPath)")
                    } else {
                        print("WebServerManager: Invalid www directory at: \(potentialWWWPath)")
                    }
                }
            }
        } else {
            // Validate the www directory from the bundle as well
            if !validateWWWDirectory(wwwPath!) {
                print("WebServerManager: Warning - Bundle www directory might be incomplete")
                // We won't fail here because it's the bundle path, but we'll log a warning
            }
        }
        
        // Ensure we found a valid www path
        guard let finalWWWPath = wwwPath else {
            print("WebServerManager: Error - Could not find valid www directory")
            return false
        }
        
        // Get the path to the Documents/warc-data directory for user archives
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            print("WebServerManager: Error - Could not find Documents directory")
            return false
        }
        
        // Validate Documents directory is writable
        let documentsURL = URL(fileURLWithPath: documentsPath)
        guard validateDirectoryIsWritable(documentsURL) else {
            print("WebServerManager: Error - Documents directory is not writable")
            return false
        }
        
        let warcsPath = (documentsPath as NSString).appendingPathComponent("warc-data")
        let warcsURL = URL(fileURLWithPath: warcsPath)
        
        // Create the warc-data directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: warcsPath) {
            do {
                try fileManager.createDirectory(atPath: warcsPath, withIntermediateDirectories: true, attributes: nil)
                print("WebServerManager: Created warc-data directory at \(warcsPath)")
                
                // Verify the directory was created successfully and is writable
                guard validateDirectoryIsWritable(warcsURL) else {
                    print("WebServerManager: Error - Created warc-data directory is not writable")
                    return false
                }
            } catch {
                print("WebServerManager: Error creating warc-data directory: \(error.localizedDescription)")
                return false
            }
        } else {
            // Verify existing directory is writable
            guard validateDirectoryIsWritable(warcsURL) else {
                print("WebServerManager: Error - Existing warc-data directory is not writable")
                return false
            }
            
            // Check disk space in the directory
            checkAvailableDiskSpace(warcsURL)
        }
        
        // Add handler for static files from www directory
        // Serve index.html and other assets from the root
        server.addGETHandler(
            forBasePath: "/",
            directoryPath: finalWWWPath,
            indexFilename: "index.html", // Ensure index.html is served at the root
            cacheAge: 0,
            allowRangeRequests: true
        )

        // Add specific handler for sw.js at the root
        // This ensures the Service Worker has the correct scope
        let swJsPath = (finalWWWPath as NSString).appendingPathComponent("sw.js")
        server.addHandler(forMethod: "GET", path: "/sw.js", request: GCDWebServerRequest.self) { _ in
            // Check if sw.js exists at the path
            if FileManager.default.fileExists(atPath: swJsPath) {
                return GCDWebServerFileResponse(file: swJsPath, byteRange: nil)
            } else {
                print("WebServerManager: Error - sw.js not found at \(swJsPath)")
                return GCDWebServerResponse(statusCode: 404)
            }
        }
        
        // Add handler for user archives
        server.addGETHandler(
            forBasePath: "/archives",
            directoryPath: warcsPath,
            indexFilename: nil,
            cacheAge: 0,
            allowRangeRequests: true
        )
        
        return true
    }
    
    /// Start the server with security options
    private func startServer(_ server: GCDWebServer) -> Bool {
        do {
            // Configure server options for security
            let options: [String: Any] = [
                GCDWebServerOption_Port: serverPort,
                GCDWebServerOption_BindToLocalhost: true,
                GCDWebServerOption_ServerName: "ReplayWeb Mobile Server"
            ]
            
            try server.start(options: options)
            serverURL = server.serverURL
            return true
        } catch {
            print("WebServerManager: Error starting server: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - App Lifecycle Notifications
    
    private func setupNotifications() {
        // Handle app entering background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Handle app becoming active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // Add ensureServerRunning method to match AppDelegate usage
    func ensureServerRunning() {
        if !isRunning {
            print("WebServerManager: Server was not running, attempting to start.")
            _ = startServer()
        } else {
            print("WebServerManager: Server is already running.")
        }
    }
    
    @objc private func applicationDidEnterBackground() {
        print("WebServerManager: App entered background, stopping server")
        // As per PRD, server should continue running in background if possible
        // stopServer() // Original behavior was to stop. Let's keep it running.
        // Instead, we'll rely on the AppDelegate's background task management
        ensureServerRunning() 
    }
    
    @objc private func applicationWillEnterForeground() {
        print("WebServerManager: App will enter foreground, ensuring server is running")
        // Ensure server is running when app comes to foreground
        // If it was stopped for some reason (e.g. by OS), restart it.
        if !isRunning {
            startServer()
        }
    }
    
    /// Helper method to find the project directory by navigating up from a given path
    private func findProjectDirectory(startingFrom path: String) -> URL? {
        let fileManager = FileManager.default
        var currentPath = URL(fileURLWithPath: path)
        
        // Try navigating up several levels to find the project root
        // We're looking for a directory that contains the www folder
        for _ in 0..<5 { // Limit to 5 levels up to avoid infinite loops
            // Go up one directory level
            currentPath = currentPath.deletingLastPathComponent()
            
            // Check if this directory contains a www folder
            let wwwPath = currentPath.appendingPathComponent("www")
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: wwwPath.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // Found a directory containing www - this is likely our project directory
                return currentPath
            }
        }
        
        return nil
    }
    
    /// Validate that a directory contains the expected files for a www directory
    private func validateWWWDirectory(_ path: String) -> Bool {
        let fileManager = FileManager.default
        let indexPath = (path as NSString).appendingPathComponent("index.html")
        let swPath = (path as NSString).appendingPathComponent("sw.js")
        let mainJsPath = (path as NSString).appendingPathComponent("main.js")
        
        // At minimum, we need index.html and sw.js to be present for a valid www directory
        guard fileManager.fileExists(atPath: indexPath) else {
            print("WebServerManager: index.html not found in www directory")
            return false
        }
        
        guard fileManager.fileExists(atPath: swPath) else {
            print("WebServerManager: sw.js not found in www directory")
            return false
        }
        
        // Main.js is also important but not strictly required
        if !fileManager.fileExists(atPath: mainJsPath) {
            print("WebServerManager: Warning - main.js not found in www directory")
        }
        
        // Check that index.html contains the Service Worker registration
        do {
            let indexContent = try String(contentsOfFile: indexPath, encoding: .utf8)
            if !indexContent.contains("navigator.serviceWorker.register") {
                print("WebServerManager: Warning - index.html might not register Service Worker")
            }
        } catch {
            print("WebServerManager: Could not read index.html: \(error.localizedDescription)")
        }
        
        return true
    }
    
    /// Verify a directory is writable by creating and removing a test file
    private func validateDirectoryIsWritable(_ directoryURL: URL) -> Bool {
        let fileManager = FileManager.default
        let testFileName = "write_test_\(UUID().uuidString).tmp"
        let testFileURL = directoryURL.appendingPathComponent(testFileName)
        
        do {
            // Try to create a test file
            try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
            
            // Clean up by removing the test file
            try fileManager.removeItem(at: testFileURL)
            
            return true
        } catch {
            print("WebServerManager: Directory not writable: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Check available disk space in a directory
    private func checkAvailableDiskSpace(_ directoryURL: URL) {
        do {
            let resourceValues = try directoryURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage {
                let availableMB = availableCapacity / (1024 * 1024)
                
                if availableMB < 100 {
                    print("WebServerManager: Warning - Low disk space: only \(availableMB) MB available")
                } else {
                    print("WebServerManager: Available disk space: \(availableMB) MB")
                }
            }
        } catch {
            print("WebServerManager: Unable to check disk space: \(error.localizedDescription)")
        }
    }
}
