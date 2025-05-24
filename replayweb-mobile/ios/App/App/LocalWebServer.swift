import Foundation
import GCDWebServer

class LocalWebServer {
    // MARK: - Singleton
    static let shared = LocalWebServer()
    
    // MARK: - Properties
    private var webServer: GCDWebServer?
    private(set) var isRunning = false
    private(set) var serverURL: URL?
    private(set) var replayURL: URL?
    
    // Default port for the server
    private let serverPort: UInt = 8090
    
    // MARK: - Initialization
    private init() {
        // Private initializer to enforce singleton pattern
    }
    
    deinit {
        stopServer()
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the web server if it's not already running
    func startServer() -> Bool {
        guard !isRunning else {
            print("LocalWebServer: Server is already running")
            return true
        }
        
        // Create a new GCDWebServer instance
        webServer = GCDWebServer()
        
        guard let webServer = webServer else {
            print("LocalWebServer: Failed to create GCDWebServer instance")
            return false
        }
        
        // Configure and start the server
        if !configureServer(webServer) {
            print("LocalWebServer: Failed to configure server")
            return false
        }
        
        if !startServer(webServer) {
            print("LocalWebServer: Failed to start server")
            return false
        }
        
        isRunning = true
        
        // Set the replay URL by appending the /replay/ path
        if let url = serverURL {
            replayURL = url.appendingPathComponent("replay/")
            print("LocalWebServer: Server started successfully")
            print("  - Base URL: \(url.absoluteString)")
            print("  - Replay URL: \(replayURL?.absoluteString ?? "unknown")")
        } else {
            print("LocalWebServer: Server started but URL is unknown")
        }
        
        return true
    }
    
    /// Stop the web server if it's running
    func stopServer() {
        guard isRunning, let webServer = webServer else { return }
        
        webServer.stop()
        isRunning = false
        serverURL = nil
        print("LocalWebServer: Server stopped")
    }
    
    /// Restart the server
    func restartServer() -> Bool {
        stopServer()
        return startServer()
    }
    
    // MARK: - Private Methods
    
    /// Configure the server with handlers for ReplayWebPage assets
    private func configureServer(_ server: GCDWebServer) -> Bool {
        // Get the path to the ReplayWebPageAssets directory
        guard let assetsPath = Bundle.main.path(forResource: "ReplayWebPageAssets", ofType: nil) else {
            print("LocalWebServer: Error - Could not find ReplayWebPageAssets directory in bundle")
            return false
        }
        
        // Validate the assets directory
        if !validateAssetsDirectory(assetsPath) {
            print("LocalWebServer: Warning - ReplayWebPageAssets directory might be incomplete")
            // We won't fail here since it's the bundle path, but we'll log a warning
        }
        
        // Get the path to the Documents/warc-data directory for user archives
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            print("LocalWebServer: Error - Could not find Documents directory")
            return false
        }
        
        let warcsPath = (documentsPath as NSString).appendingPathComponent("warc-data")
        
        // Create the warc-data directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: warcsPath) {
            do {
                try fileManager.createDirectory(atPath: warcsPath, withIntermediateDirectories: true, attributes: nil)
                print("LocalWebServer: Created warc-data directory at \(warcsPath)")
            } catch {
                print("LocalWebServer: Error creating warc-data directory: \(error.localizedDescription)")
                return false
            }
        }
        
        // Add handler for ReplayWeb.page UI at /replay/ endpoint
        server.addGETHandler(
            forBasePath: "/replay/",
            directoryPath: assetsPath,
            indexFilename: "index.html",
            cacheAge: 0,
            allowRangeRequests: true
        )
        
        // Add special handler for sw.js at the root to enable proper service worker scope
        server.addHandler(forMethod: "GET", path: "/sw.js", request: GCDWebServerRequest.self) { _ in
            let swJsPath = (assetsPath as NSString).appendingPathComponent("sw.js")
            return GCDWebServerFileResponse(file: swJsPath, byteRange: nil)
        }
        
        // Add handler for the root path to redirect to /replay/
        server.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self) { request in
            return GCDWebServerResponse(redirect: URL(string: "/replay/")!, permanent: false)
        }
        
        // Add handler for archives under /archives/
        server.addGETHandler(
            forBasePath: "/archives/",
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
                GCDWebServerOption_ServerName: "ReplayWeb Local Server"
            ]
            
            try server.start(options: options)
            serverURL = server.serverURL
            return true
        } catch {
            print("LocalWebServer: Error starting server: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Validate that the assets directory contains the expected files
    private func validateAssetsDirectory(_ path: String) -> Bool {
        let fileManager = FileManager.default
        let indexPath = (path as NSString).appendingPathComponent("index.html")
        let uiJsPath = (path as NSString).appendingPathComponent("ui.js")
        let swJsPath = (path as NSString).appendingPathComponent("sw.js")
        let manifestPath = (path as NSString).appendingPathComponent("webmanifest.json")
        let faviconsPath = (path as NSString).appendingPathComponent("favicons")
        
        // At minimum, we need index.html and ui.js to be present
        guard fileManager.fileExists(atPath: indexPath) else {
            print("LocalWebServer: index.html not found in assets directory")
            return false
        }
        
        guard fileManager.fileExists(atPath: uiJsPath) else {
            print("LocalWebServer: ui.js not found in assets directory")
            return false
        }
        
        // Check for other important files
        if !fileManager.fileExists(atPath: swJsPath) {
            print("LocalWebServer: Warning - sw.js not found in assets directory")
        }
        
        if !fileManager.fileExists(atPath: manifestPath) {
            print("LocalWebServer: Warning - webmanifest.json not found in assets directory")
        }
        
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: faviconsPath, isDirectory: &isDirectory) || !isDirectory.boolValue {
            print("LocalWebServer: Warning - favicons directory not found or is not a directory")
        }
        
        // Check that index.html contains references to ui.js and/or sw.js
        do {
            let indexContent = try String(contentsOfFile: indexPath, encoding: .utf8)
            if !indexContent.contains("ui.js") {
                print("LocalWebServer: Warning - index.html might not reference ui.js")
            }
            
            if !indexContent.contains("sw.js") && !indexContent.contains("serviceWorker.register") {
                print("LocalWebServer: Warning - index.html might not register Service Worker")
            }
        } catch {
            print("LocalWebServer: Could not read index.html: \(error.localizedDescription)")
        }
        
        return true
    }
}
