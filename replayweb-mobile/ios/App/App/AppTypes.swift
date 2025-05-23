import Foundation
import UIKit

// This file contains forward declarations and type definitions
// to help resolve circular dependencies between classes

// Forward declarations using protocols instead of class implementations
@objc protocol WebServerManagerProtocol {
    var isRunning: Bool { get }
    var serverURL: URL? { get }
    
    func startServer() -> Bool
    func stopServer()
}

@objc protocol MainViewControllerProtocol {
    func checkServiceWorkerRegistration()
    func checkNetworkConnectivity()
}
