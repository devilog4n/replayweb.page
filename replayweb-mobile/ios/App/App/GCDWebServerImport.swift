// GCDWebServerImport.swift - Helper to ensure GCDWebServer is properly imported
// This file centralizes GCDWebServer imports to avoid bridging header issues

import Foundation

// This class wraps GCDWebServer functionality to avoid direct imports in other files
class GCDWebServerWrapper {
    static let shared = GCDWebServerWrapper()
    private init() {}
    
    // Reference to the actual web server instance
    private var webServer: Any?
    
    // Create and configure a new web server
    func createWebServer() -> Any? {
        // Use Obj-C runtime to create GCDWebServer instance
        let gcdWebServerClass = NSClassFromString("GCDWebServer") as? NSObject.Type
        webServer = gcdWebServerClass?.init()
        return webServer
    }
}
