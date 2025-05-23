import UIKit
import WebKit

class ServiceWorkerTester {
    static let shared = ServiceWorkerTester()
    
    private var debugView: ServiceWorkerDebugView?
    weak var parentViewController: UIViewController?
    weak var webView: WKWebView?
    
    // MARK: - Testing Methods
    
    func testServiceWorkerRegistration(silent: Bool = false, completion: ((ServiceWorkerStatus) -> Void)? = nil) {
        guard let webView = webView else {
            completion?(.unknown)
            return
        }
        
        // Only show debug overlay if not in silent mode
        if !silent {
            showDebugOverlay()
        }
        
        // JavaScript to check service worker registration
        let script = """
        (function() {
            if (!navigator.serviceWorker) {
                return { registered: false, message: "ServiceWorker API not available" };
            }
            
            return navigator.serviceWorker.getRegistrations()
            .then(registrations => {
                if (registrations.length === 0) {
                    return { registered: false, message: "No service workers registered" };
                }
                
                const regInfo = registrations.map(reg => {
                    return `Scope: ${reg.scope}, State: ${reg.active ? 'active' : 'inactive'}`;
                }).join('\\n');
                
                return { 
                    registered: true, 
                    message: `Found ${registrations.length} registrations:\\n${regInfo}` 
                };
            })
            .catch(error => {
                return { registered: false, message: `Error: ${error.message}` };
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            var status: ServiceWorkerStatus = .unknown
            
            if let error = error {
                let errorMessage = "Error: \(error.localizedDescription)"
                if !silent {
                    self?.debugView?.updateStatus(registered: false, message: errorMessage)
                }
                status = .failed
            } else if let resultDict = result as? [String: Any],
                      let registered = resultDict["registered"] as? Bool,
                      let message = resultDict["message"] as? String {
                
                if registered {
                    status = .registered
                } else if message.contains("not available") {
                    status = .unsupported
                } else {
                    status = .supported
                }
                
                if !silent {
                    self?.debugView?.updateStatus(registered: registered, message: message)
                }
            } else {
                if !silent {
                    self?.debugView?.updateStatus(registered: false, message: "Invalid response format")
                }
                status = .failed
            }
            
            // Call completion handler with status
            completion?(status)
        }
    }
    
    func testWACZImport() {
        guard let parentVC = parentViewController else { return }
        
        let filePicker = FilePicker()
        filePicker.presentPicker(from: parentVC) { [weak self] url in
            guard let url = url else {
                self?.showAlert(title: "Import Cancelled", message: "No file was selected.")
                return
            }
            
            self?.showAlert(title: "File Selected", message: "Selected WACZ file: \(url.lastPathComponent)\nURL: \(url.path)")
            
            // Import the archive
            ArchiveManager.shared.importArchive(from: url) { result in
                switch result {
                case .success(let archiveURL):
                    DispatchQueue.main.async {
                        self?.showAlert(title: "Import Successful", 
                                       message: "WACZ file imported successfully to:\n\(archiveURL.path)\n\nTesting archive loading...")
                        
                        // Set as active archive
                        let success = ArchiveManager.shared.setActiveArchive(archiveURL)
                        if success, let webView = self?.webView {
                            // Inject the archive URL into the page
                            let relativePath = "/archives/\(archiveURL.lastPathComponent)"
                            // Use format exactly as specified in the PRD
                            webView.evaluateJavaScript("window.location.href = 'http://localhost:8080/index.html?archive=\(relativePath)';")
                        }
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.showAlert(title: "Import Failed", 
                                       message: "Failed to import WACZ file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func testOfflineMode() {
        guard let webView = webView else { return }
        
        // Check if an archive is loaded
        webView.evaluateJavaScript("(function() { return window.location.href.includes('archive=') ? true : false; })()") { [weak self] result, error in
            let hasArchive = (result as? Bool) ?? false
            
            if !hasArchive {
                self?.showAlert(title: "No Archive Loaded", 
                               message: "Please load a WACZ archive first using the 'Test WACZ Import' feature.")
                return
            }
            
            // Show message about simulating offline mode
            self?.showAlert(title: "Testing Offline Mode", 
                           message: "Simulating offline mode...\n\nThe app will now try to load content from cache/Service Worker.\n\nThis test is most effective when:\n1. You've already browsed some pages in the archive\n2. You check if those pages load without network")
        }
    }
    
    // MARK: - Helper Methods
    
    private func showDebugOverlay() {
        guard let parentVC = parentViewController else { return }
        
        // Remove existing debug view if any
        debugView?.removeFromSuperview()
        
        // Create new debug view
        let debugView = ServiceWorkerDebugView(frame: CGRect(x: 0, y: 0, width: 280, height: 180))
        debugView.center = parentVC.view.center
        debugView.onClose = { [weak debugView] in
            debugView?.removeFromSuperview()
        }
        
        parentVC.view.addSubview(debugView)
        self.debugView = debugView
    }
    
    private func showAlert(title: String, message: String) {
        guard let parentVC = parentViewController else { return }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        parentVC.present(alert, animated: true)
    }
}
