import UIKit
import WebKit

// Extension for the diagnostic testing functionality
extension MainViewController {
    
    // MARK: - Diagnostics Setup
    
    func setupDiagnosticsButton() {
        // Setup diagnostics button
        diagButton.setTitle("🔍", for: .normal)
        diagButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        diagButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.7)
        diagButton.layer.cornerRadius = 25
        diagButton.frame = CGRect(x: view.bounds.width - 60, y: view.bounds.height - 140, width: 50, height: 50)
        diagButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        diagButton.addTarget(self, action: #selector(showDiagnosticsToolbar), for: .touchUpInside)
        view.addSubview(diagButton)
        view.bringSubviewToFront(diagButton)
    }
    
    @objc func showDiagnosticsToolbar() {
        // Create diagnostics toolbar if it doesn't exist
        if diagnosticsToolbar == nil {
            let toolbar = DiagnosticsToolbar(frame: CGRect(x: 20, y: view.bounds.height - 80, width: view.bounds.width - 40, height: 50))
            toolbar.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
            
            // Set up callbacks
            toolbar.onTestServiceWorker = { [weak self] in
                self?.testServiceWorkerRegistration()
            }
            
            toolbar.onTestWACZImport = { [weak self] in
                self?.testWACZImport()
            }
            
            toolbar.onTestOfflineMode = { [weak self] in
                self?.testOfflineMode()
            }
            
            toolbar.onHide = { [weak self] in
                self?.diagnosticsToolbar?.removeFromSuperview()
                self?.diagnosticsToolbar = nil
            }
            
            view.addSubview(toolbar)
            view.bringSubviewToFront(toolbar)
            diagnosticsToolbar = toolbar
        }
    }
    
    // MARK: - Test Methods
    
    func checkServiceWorkerRegistration(silent: Bool = false) {
        // Setup ServiceWorkerTester
        let tester = ServiceWorkerTester.shared
        tester.parentViewController = self
        tester.webView = webView
        
        // Run test (with silent mode option)
        tester.testServiceWorkerRegistration(silent: silent, completion: { status in
            if !silent && status == .registered {
                // Show a brief success toast when explicitly testing
                self.showSuccessMessage("Service Worker registered successfully")
            } else if !silent && status != .registered {
                // Show diagnostic view for manual testing to help troubleshoot
                // The detailed message will be shown in the debug overlay
            }
            
            // Update app state based on service worker status
            self.serviceWorkerStatus = status
            
            // Notify observers about service worker status
            NotificationCenter.default.post(
                name: NSNotification.Name("ServiceWorkerStatusChanged"),
                object: nil,
                userInfo: ["status": status]
            )
        })
    }
    
    /// Legacy method for manual testing through the UI
    func testServiceWorkerRegistration() {
        checkServiceWorkerRegistration(silent: false)
    }
    
    private func showSuccessMessage(_ message: String) {
        let toast = UILabel()
        toast.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = UIFont.systemFont(ofSize: 14)
        toast.text = message
        toast.numberOfLines = 0
        toast.alpha = 0.0
        toast.layer.cornerRadius = 10
        toast.clipsToBounds = true
        toast.frame = CGRect(x: 20, y: 40, width: view.frame.width - 40, height: 40)
        view.addSubview(toast)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn, animations: {
            toast.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 2.0, options: .curveEaseOut, animations: {
                toast.alpha = 0.0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        })
    }
    
    func testWACZImport() {
        // Setup ServiceWorkerTester
        let tester = ServiceWorkerTester.shared
        tester.parentViewController = self
        tester.webView = webView
        
        // Run test
        tester.testWACZImport()
    }
    
    func testOfflineMode() {
        // Setup ServiceWorkerTester
        let tester = ServiceWorkerTester.shared
        tester.parentViewController = self
        tester.webView = webView
        
        // Run test
        tester.testOfflineMode()
    }
    
    // MARK: - Background Handling
    
    @objc func handleAppEnteringBackground() {
        print("MainViewController: App entering background")
        
        // Save any necessary state 
        if let url = webView.url?.absoluteString {
            UserDefaults.standard.set(url, forKey: "lastViewedURL")
        }
        
        // If diagnostics are shown, hide them
        diagnosticsToolbar?.removeFromSuperview()
        diagnosticsToolbar = nil
    }
}
