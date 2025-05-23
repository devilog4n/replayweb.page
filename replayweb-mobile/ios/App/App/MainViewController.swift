import Foundation
import UIKit
import WebKit
import Combine
import Network

// MARK: - Service Worker Status Enum
enum ServiceWorkerStatus {
    case unknown
    case supported
    case unsupported
    case registered
    case failed
    
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .supported: return "Supported"
        case .unsupported: return "Unsupported"
        case .registered: return "Registered"
        case .failed: return "Failed"
        }
    }
}

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    // Service Worker properties
    private var serviceWorkerStatus: ServiceWorkerStatus = .unknown
    private var cancellables = Set<AnyCancellable>()
    
    // Network connectivity properties
    private var isOnline: Bool = true
    private var networkMonitor: NWPathMonitor?
    private var offlineIndicator: UIView?
    
    var webView: WKWebView!
    private let filePicker = FilePicker()
    private var errorLabel: UILabel?
    private var activityIndicator: UIActivityIndicatorView?
    
    // Diagnostic tools
    private var diagnosticsToolbar: DiagnosticsToolbar?
    private let diagButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupWebView()
        setupNetworkMonitoring()
        loadInitialContent()
        setupMessageHandlers()
        setupNotificationObservers()
        setupDiagnosticsButton()
        setupImportButton()
        
        // Check Service Worker registration after page loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkServiceWorkerRegistration(silent: true)
        }
    }
    
    private func setupImportButton() {
        // Create an import button for quick WACZ archive imports
        let importButton = UIButton(type: .system)
        importButton.setTitle("📥", for: .normal)
        importButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        importButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        importButton.layer.cornerRadius = 25
        importButton.frame = CGRect(x: view.bounds.width - 60, y: view.bounds.height - 200, width: 50, height: 50)
        importButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        importButton.addTarget(self, action: #selector(importWACZArchiveTapped), for: .touchUpInside)
        view.addSubview(importButton)
        view.bringSubviewToFront(importButton)
    }
    
    @objc private func importWACZArchiveTapped() {
        // Show a user-friendly import flow
        let alert = UIAlertController(
            title: "Import Archive",
            message: "Select a WACZ archive file to explore offline",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Select File", style: .default) { _ in
            self.importWACZArchive()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func importWACZArchive() {
        // Use the FilePicker to select a WACZ file
        filePicker.presentPicker(from: self) { [weak self] selectedURL in
            guard let self = self, let selectedURL = selectedURL else { return }
            
            // Show loading indicator
            self.showLoadingIndicator(true)
            
            // Import the archive
            ArchiveManager.shared.importArchive(from: selectedURL) { result in
                // Hide loading indicator
                self.showLoadingIndicator(false)
                
                switch result {
                case .success(let archiveURL):
                    // Load the imported archive
                    self.loadArchive(archiveURL)
                case .failure(let error):
                    // Show error message
                    self.showErrorMessage("Failed to import archive: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadArchive(_ archiveURL: URL) {
        guard let serverURL = WebServerManager.shared.serverURL else {
            showErrorMessage("Server not available")
            return
        }
        
        // Format the relative path as specified in the PRD section 3.3
        let relativePath = "/archives/\(archiveURL.lastPathComponent)"
        
        // Implementation approach #1: Use JavaScript injection (as specified in PRD section 3.3)
        // This is the preferred method as per the PRD
        if webView.url != nil {
            // If the WebView is already loaded, use JavaScript to navigate
            let jsCode = "window.setArchiveURL('\(relativePath)');"
            
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("MainViewController: Error setting archive URL via JavaScript: \(error.localizedDescription)")
                    self.loadViaDirectNavigation(serverURL: serverURL, relativePath: relativePath, archiveURL: archiveURL)
                } else {
                    // Show success message
                    let successMessage = "Archive loaded via JavaScript: \(archiveURL.lastPathComponent)"
                    print("MainViewController: \(successMessage)")
                    self.showSuccessMessage(successMessage)
                }
            }
        } else {
            // If WebView isn't loaded yet, use direct navigation
            loadViaDirectNavigation(serverURL: serverURL, relativePath: relativePath, archiveURL: archiveURL)
        }
    }
    
    // Fallback method using direct navigation if JavaScript method fails
    private func loadViaDirectNavigation(serverURL: URL, relativePath: String, archiveURL: URL) {
        // Format the URL directly as specified in the PRD
        let archiveIndexURL = "\(serverURL.absoluteString)index.html?archive=\(relativePath)"
        
        if let url = URL(string: archiveIndexURL) {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10.0
            
            // Load the archive in the WebView
            webView.load(request)
            
            // Show success message
            let successMessage = "Archive loaded via direct navigation: \(archiveURL.lastPathComponent)"
            print("MainViewController: \(successMessage)")
            showSuccessMessage(successMessage)
        } else {
            showErrorMessage("Invalid archive URL")
        }
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
    
    private func setupNotificationObservers() {
        // Register for app entering background notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppEnteringBackground),
            name: NSNotification.Name("AppEnteringBackground"),
            object: nil
        )
        
        // Register for app returning to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppEnteringForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppEnteringBackground() {
        // Store current state for offline use
        if let url = webView.url?.absoluteString {
            let script = "localStorage.setItem('lastViewedURL', '" + url + "');"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        // Ensure Service Worker is registered before going to background
        if serviceWorkerStatus != .registered && isOnline {
            checkServiceWorkerRegistration()
        }
    }
    
    @objc private func handleAppEnteringForeground() {
        // Check network connectivity
        checkNetworkConnectivity()
        
        // If we're online, check Service Worker registration
        if isOnline {
            checkServiceWorkerRegistration()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop network monitoring when view disappears
        if let networkMonitor = networkMonitor {
            networkMonitor.cancel()
            self.networkMonitor = nil
        }
    }
    
    // MARK: - Network Connectivity
    
    /// Set up network connectivity monitoring
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                self.handleConnectivityChange(isConnected: isConnected)
            }
        }
        
        networkMonitor?.start(queue: queue)
    }
    
    /// Handle changes in network connectivity
    func handleConnectivityChange(isConnected: Bool) {
        // Update connectivity status for tracking
        let wasOffline = !self.isOnline
        self.isOnline = isConnected
        
        // Update UI based on connectivity
        if isConnected {
            hideOfflineIndicator()
            print("Network: Device is now online")
            
            // If we were offline and now online, check service worker and reload content if needed
            if wasOffline {
                checkServiceWorkerRegistration()
                
                // Only reload if we're showing the offline page
                if let url = webView.url, url.absoluteString.contains("offline") {
                    reloadWebViewWithActiveArchive()
                }
            }
        } else {
            // Show offline indicator
            showOfflineIndicator()
            print("Network: Device is now offline")
            
            // If we're in the middle of loading content, show offline page
            if webView.isLoading {
                webView.stopLoading()
                showOfflinePage()
            }
        }
        
        // Notify web content about connectivity change
        notifyWebContentAboutConnectivity(isOnline: isConnected)
    }
    
    /// Check current network connectivity status
    func checkNetworkConnectivity() {
        // If we don't have a network monitor, set up one
        if networkMonitor == nil {
            setupNetworkMonitoring()
        }
        
        // Get current system connectivity status
        let connectedToNetwork = ProcessInfo.processInfo.isNetworkActivityIndicatorVisible
        
        // Update UI based on current status
        handleConnectivityChange(isConnected: connectedToNetwork)
    }
    
    /// Show offline indicator in the UI
    private func showOfflineIndicator() {
        // Remove any existing indicator first
        hideOfflineIndicator()
        
        // Create a semi-transparent banner at the top of the screen
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 36))
        indicator.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.9)
        indicator.autoresizingMask = [.flexibleWidth]
        
        // Add offline text
        let label = UILabel(frame: indicator.bounds)
        label.text = "Offline Mode"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        indicator.addSubview(label)
        
        // Add to view hierarchy
        view.addSubview(indicator)
        self.offlineIndicator = indicator
        
        // Animate in from top
        indicator.transform = CGAffineTransform(translationX: 0, y: -indicator.bounds.height)
        UIView.animate(withDuration: 0.3) {
            indicator.transform = .identity
        }
    }
    
    /// Hide the offline indicator
    private func hideOfflineIndicator() {
        guard let indicator = offlineIndicator else { return }
        
        // Animate out
        UIView.animate(withDuration: 0.3, animations: {
            indicator.transform = CGAffineTransform(translationX: 0, y: -indicator.bounds.height)
        }) { _ in
            indicator.removeFromSuperview()
            self.offlineIndicator = nil
        }
    }
    
    /// Notify web content about connectivity changes
    private func notifyWebContentAboutConnectivity(isOnline: Bool) {
        // Create a simple script to notify the web app
        let onlineStatus = isOnline ? "true" : "false"
        let script = "window.nativeAppIsOnline = " + onlineStatus + ";" +
                    "console.log('Connectivity changed: ' + (" + onlineStatus + " ? 'online' : 'offline'));"
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error notifying web content about connectivity: \(error)")
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupWebView() {
        // Check if Service Workers are supported in this iOS version
        checkServiceWorkerSupport()
        // Configure WKWebView with required settings
        let contentController = WKUserContentController()
        
        // Add console log handler for debugging
        contentController.add(self, name: "consoleLog")
        contentController.add(self, name: "nativeApp")
        
        // Add script for Service Worker debugging
        let swDebugScript = WKUserScript(
            source: """
            window.swDebugMode = true;
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(swDebugScript)
        
        // Configure WKWebView
        let webConfiguration = WKWebViewConfiguration()
        
        // Use default (non-ephemeral) data store for Service Worker persistence
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Enable app-bound domains for Service Worker support (iOS 14+)
        if #available(iOS 14.0, *) {
            webConfiguration.limitsNavigationsToAppBoundDomains = true
        }
        
        // Set content controller
        webConfiguration.userContentController = contentController
        
        // Set preferences
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.preferences = preferences
        
        // Enable developer tools in debug builds
        #if DEBUG
        if #available(iOS 16.4, *) {
            webConfiguration.preferences.isInspectable = true
        }
        #endif
        
        // Create WKWebView
        webView = WKWebView(frame: view.bounds, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Allow back-forward navigation gestures
        webView.allowsBackForwardNavigationGestures = true
        
        view.addSubview(webView)
    }
    
    private func loadInitialContent() {
        // Load local content from the web server
        if let serverURL = WebServerManager.shared.serverURL {
            print("MainViewController: Loading content from server URL: \(serverURL)")
            let indexURL = serverURL.appendingPathComponent("index.html")
            var request = URLRequest(url: indexURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            // Add a timeout for better error handling
            request.timeoutInterval = 10.0
            
            webView.load(request)
            
            // Set a timer to check if the page loaded successfully
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                
                // If the page is still loading after 5 seconds, show a loading indicator
                if self.webView.isLoading {
                    self.showLoadingIndicator(true)
                }
            }
        } else {
            showErrorMessage("Failed to start web server. Please restart the app.")
        }
    }
    
    /// Clear web cache while preserving Service Worker registrations
    func clearWebCachePreservingServiceWorkers() {
        // Create a data store reference
        let websiteDataStore = webView.configuration.websiteDataStore
        
        // Get all data types except those related to Service Workers
        let dataTypes = Set(WKWebsiteDataStore.allWebsiteDataTypes().filter { dataType in
            return !dataType.contains("ServiceWorker") && !dataType.contains("IndexedDB")
        })
        
        // Fetch records of this type from date 0 to now
        websiteDataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            // Remove the records
            websiteDataStore.removeData(ofTypes: dataTypes, for: records) {
                print("Cleared web cache while preserving Service Worker registrations")
                
                // Notify web content about cache clearing
                self.webView.evaluateJavaScript(
                    "if (window.webkit && window.webkit.messageHandlers.cacheStatus) { " +
                    "window.webkit.messageHandlers.cacheStatus.postMessage({action: 'cacheClearedByNative'}); }",
                    completionHandler: nil
                )
            }
        }
    }
    
    private func setupMessageHandlers() {
        // Add JavaScript message handlers for communication between web and native
        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "serviceWorker")
        contentController.add(self, name: "offlineStatus")
        contentController.add(self, name: "cacheStatus")
        
        // Inject JavaScript to monitor Service Worker lifecycle
        let swMonitorScript = """
        // Monitor service worker registration and lifecycle
        if ('serviceWorker' in navigator) {
            // Listen for Service Worker state changes
            navigator.serviceWorker.addEventListener('controllerchange', () => {
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "lifecycleEvent",
                    type: "controllerchange"
                });
            });
            
            // Listen for Service Worker updates
            navigator.serviceWorker.ready.then(registration => {
                console.log('Service Worker ready with scope:', registration.scope);
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "lifecycleEvent",
                    type: "ready",
                    scope: registration.scope
                });
                
                // Setup update monitoring
                registration.addEventListener('updatefound', () => {
                    const newWorker = registration.installing;
                    
                    newWorker.addEventListener('statechange', () => {
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "lifecycleEvent",
                            type: "statechange",
                            state: newWorker.state
                        });
                    });
                });
            });
            
            // Listen for messages from Service Worker
            navigator.serviceWorker.addEventListener('message', event => {
                console.log('Message from Service Worker:', event.data);
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "workerMessage",
                    data: JSON.stringify(event.data)
                });
            });
        }
        """
        
        webView.evaluateJavaScript(swMonitorScript) { _, error in
            if let error = error {
                print("Error injecting Service Worker monitor script: \(error.localizedDescription)")
            }
        }
    }
    
    private func showLoadingIndicator(_ show: Bool) {
        // Create a loading indicator if it doesn't exist
        if show {
            let loadingView = UIView(frame: view.bounds)
            loadingView.backgroundColor = UIColor(white: 0, alpha: 0.5)
            loadingView.tag = 100
            
            let indicator = UIActivityIndicatorView(style: .large)
            indicator.center = loadingView.center
            indicator.color = .white
            indicator.startAnimating()
            loadingView.addSubview(indicator)
            
            view.addSubview(loadingView)
        } else {
            // Remove loading indicator if it exists
            if let loadingView = view.viewWithTag(100) {
                loadingView.removeFromSuperview()
            }
        }
    }
    
    private func showErrorMessage(_ message: String) {
        print("Error: \(message)")
        
        // Display an error message to the user
        errorLabel = UILabel(frame: view.bounds)
        errorLabel?.text = message
        errorLabel?.textAlignment = .center
        errorLabel?.numberOfLines = 0
        
        if let errorLabel = errorLabel {
            view.addSubview(errorLabel)
        }
    }
    
    private func hideErrorMessage() {
        errorLabel?.removeFromSuperview()
        errorLabel = nil
    }
    
    // MARK: - Actions
    
    @objc func openArchive() {
        filePicker.presentPicker(from: self) { [weak self] archiveURL in
            guard let self = self, let archiveURL = archiveURL else { return }
            
            // Archive was imported and set as active, now reload the web view
            self.reloadWebViewWithActiveArchive()
        }
    }
    
    private func reloadWebViewWithActiveArchive() {
        guard let serverURL = WebServerManager.shared.serverURL else {
            showErrorMessage("Server URL is not available")
            return
        }
        
        // Show loading indicator during reload
        showLoadingIndicator(true)
        
        // Get active archive filename from ArchiveManager
        guard let activeArchiveURL = ArchiveManager.shared.getActiveArchiveURL() else {
            showLoadingIndicator(false)
            showErrorMessage("No active archive selected")
            return
        }
        
        let archiveFileName = activeArchiveURL.lastPathComponent
        print("Loading archive: \(archiveFileName)")
        
        // Clear website data with progress feedback
        let clearDataMessage = UIAlertController(
            title: "Preparing Archive",
            message: "Clearing previous data...",
            preferredStyle: .alert
        )
        
        let indicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        indicator.hidesWhenStopped = true
        indicator.style = .medium
        indicator.startAnimating()
        clearDataMessage.view.addSubview(indicator)
        
        present(clearDataMessage, animated: true) {
            // Clear unrelated website data (cookies, localStorage) but keep Service Worker registrations
            // This prevents stale data from previous archives
        
        // Notify that the web view load is complete
        NotificationCenter.default.post(name: NSNotification.Name("WebViewLoadComplete"), object: nil)
        
        // Check if this was a navigation with an archive parameter
        if let url = webView.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let archiveParam = components.queryItems?.first(where: { $0.name == "archive" })?.value {
            
            print("Archive loaded: \(archiveParam)")
            
            // Inject JavaScript to check if the archive loaded successfully
            let checkArchiveScript = """
            (function() {
                if (window.ReplayWeb && window.ReplayWeb.isArchiveLoaded) {
                    return { loaded: true };
                } else {
                    return { loaded: false };
                }
            })();
            """
            
            webView.evaluateJavaScript(checkArchiveScript) { result, error in
                if let error = error {
                    print("Error checking archive loading status: \(error)")
                    return
                }
                
                if let resultDict = result as? [String: Bool],
                   let loaded = resultDict["loaded"], loaded {
                    print("Archive successfully loaded in ReplayWeb.page")
                } else {
                    print("Archive may not have loaded correctly in ReplayWeb.page")
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView failed to load: \(error.localizedDescription)")
        showLoadingIndicator(false)
        showErrorMessage("Failed to load content: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView failed provisional navigation: \(error.localizedDescription)")
        showLoadingIndicator(false)
        showErrorMessage("Failed to load content: \(error.localizedDescription)")
        
        // Implement fallback for navigation errors
        implementNavigationFallback(error: error)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Handle navigation policy decisions
        if let url = navigationAction.request.url {
            // Allow navigation to localhost and app-bound domains
            if url.host == "localhost" || url.scheme == "capacitor" {
                decisionHandler(.allow)
                return
            }
            
            // Handle external links
            if url.scheme == "http" || url.scheme == "https" {
                // Open external links in Safari
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        
        // Default allow navigation within the app
        decisionHandler(.allow)
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completionHandler()
        }))
        present(alertController, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            completionHandler(false)
        }))
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            completionHandler(true)
        }))
        present(alertController, animated: true)
    }
}

// MARK: - Service Worker Support Methods

// MARK: - Service Worker Management Extension
}

// MARK: - Service Worker Support Extension
extension MainViewController {
    /// Check if Service Workers are supported in the current iOS version and WKWebView configuration
    private func checkServiceWorkerSupport() {
        // Service Workers are supported on iOS 14+ with App-Bound Domains
        if #available(iOS 14.0, *) {
            // Check if App-Bound Domains are configured in Info.plist
            if Bundle.main.object(forInfoDictionaryKey: "WKAppBoundDomains") != nil {
                serviceWorkerStatus = .supported
                print("Service Workers are supported")
            } else {
                serviceWorkerStatus = .unsupported
                print("Service Workers are unsupported: WKAppBoundDomains not configured in Info.plist")
            }
        } else {
            serviceWorkerStatus = .unsupported
            print("Service Workers are unsupported: iOS version < 14.0")
        }
    }
    
    /// Inject JavaScript to check Service Worker registration status
    private func checkServiceWorkerRegistration() {
        let script = """
        (function() {
            if ("serviceWorker" in navigator) {
                navigator.serviceWorker.getRegistration()
                .then(registration => {
                    if (registration) {
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "registrationStatus",
                            status: "registered",
                            scope: registration.scope
                        });
                    } else {
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "registrationStatus",
                            status: "unregistered"
                        });
                    }
                })
                .catch(error => {
                    window.webkit.messageHandlers.serviceWorker.postMessage({
                        action: "registrationStatus",
                        status: "error",
                        error: error.toString()
                    });
                });
            } else {
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "registrationStatus",
                    status: "unsupported"
                });
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error checking Service Worker registration: \(error)")
            }
        }
    }
    
    /// Force Service Worker registration if needed
    private func ensureServiceWorkerRegistration() {
        guard serviceWorkerStatus == .supported else {
            setupFallbackMechanisms()
            return
        }
        
        // First check if we already have a registration
        let checkScript = """
        if ("serviceWorker" in navigator) {
            navigator.serviceWorker.getRegistration().then(registration => {
                if (registration) {
                    // We already have a registration, check if it's active
                    if (registration.active) {
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "registrationStatus",
                            status: "registered",
                            scope: registration.scope,
                            state: "active"
                        });
                    } else if (registration.installing || registration.waiting) {
                        // Registration is in progress
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "registrationStatus",
                            status: "registered",
                            scope: registration.scope,
                            state: registration.installing ? "installing" : "waiting"
                        });
                    } else {
                        // Registration exists but no worker, try to register again
                        performServiceWorkerRegistration();
                    }
                } else {
                    // No registration, register now
                    performServiceWorkerRegistration();
                }
            }).catch(error => {
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "registrationStatus",
                    status: "error",
                    error: error.toString()
                });
                performServiceWorkerRegistration();
            });
        } else {
            window.webkit.messageHandlers.serviceWorker.postMessage({
                action: "registrationStatus",
                status: "unsupported"
            });
        }
        
        function performServiceWorkerRegistration() {
            navigator.serviceWorker.register("/sw.js", { 
                scope: "/",
                updateViaCache: "all" // Cache all assets for offline use
            })
            .then(registration => {
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "registrationStatus",
                    status: "registered",
                    scope: registration.scope,
                    state: "registering"
                });
                
                // Set up update checking
                setInterval(() => {
                    registration.update();
                }, 60 * 60 * 1000); // Check for updates every hour
            })
            .catch(error => {
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "registrationStatus",
                    status: "error",
                    error: error.toString()
                });
            });
        }
        """
        
        webView.evaluateJavaScript(checkScript) { _, error in
            if let error = error {
                print("Error checking/registering Service Worker: \(error)")
                self.serviceWorkerStatus = .failed
                self.setupFallbackMechanisms()
            }
        }
    }
    
    /// Setup fallback mechanisms when Service Workers aren't available
    private func setupFallbackMechanisms() {
        // Inject JavaScript to set up localStorage-based fallback caching
        let script = """
        (function() {
            // Create a fallback cache using localStorage and IndexedDB when available
            window.fallbackCache = {
                store: function(url, content) {
                    try {
                        // Store in localStorage with timestamp
                        localStorage.setItem("cache_" + url, content);
                        localStorage.setItem("cache_time_" + url, Date.now());
                        
                        // Try to store in IndexedDB as well for larger content
                        if (window.indexedDB) {
                            try {
                                const request = indexedDB.open("offlineCache", 1);
                                request.onupgradeneeded = function(event) {
                                    const db = event.target.result;
                                    if (!db.objectStoreNames.contains('cacheStore')) {
                                        db.createObjectStore('cacheStore', { keyPath: 'url' });
                                    }
                                };
                                
                                request.onsuccess = function(event) {
                                    const db = event.target.result;
                                    const transaction = db.transaction(["cacheStore"], "readwrite");
                                    const store = transaction.objectStore("cacheStore");
                                    
                                    store.put({
                                        url: url,
                                        content: content,
                                        timestamp: Date.now()
                                    });
                                };
                            } catch (idbError) {
                                console.log("IndexedDB cache failed, using localStorage only", idbError);
                            }
                        }
                        return true;
                    } catch (e) {
                        console.error("Fallback cache storage error:", e);
                        return false;
                    }
                },
                retrieve: function(url) {
                    // First try localStorage which is faster
                    const content = localStorage.getItem("cache_" + url);
                    if (content) return content;
                    
                    // If not in localStorage, try IndexedDB
                    if (window.indexedDB) {
                        return new Promise((resolve, reject) => {
                            const request = indexedDB.open("offlineCache", 1);
                            
                            request.onsuccess = function(event) {
                                const db = event.target.result;
                                try {
                                    const transaction = db.transaction(["cacheStore"], "readonly");
                                    const store = transaction.objectStore("cacheStore");
                                    const getRequest = store.get(url);
                                    
                                    getRequest.onsuccess = function() {
                                        if (getRequest.result) {
                                            resolve(getRequest.result.content);
                                        } else {
                                            resolve(null);
                                        }
                                    };
                                    
                                    getRequest.onerror = function(error) {
                                        console.error("Error retrieving from IndexedDB:", error);
                                        resolve(null);
                                    };
                                } catch (e) {
                                    console.error("Error accessing IndexedDB:", e);
                                    resolve(null);
                                }
                            };
                            
                            request.onerror = function(event) {
                                console.error("Error opening IndexedDB:", event);
                                resolve(null);
                            };
                        });
                    }
                    
                    return null;
                },
                getTimestamp: function(url) {
                    return localStorage.getItem("cache_time_" + url);
                },
                clear: function() {
                    // Clear localStorage cache
                    Object.keys(localStorage).forEach(key => {
                        if (key.startsWith("cache_")) {
                            localStorage.removeItem(key);
                        }
                    });
                    
                    // Clear IndexedDB cache
                    if (window.indexedDB) {
                        try {
                            const request = indexedDB.deleteDatabase("offlineCache");
                            request.onsuccess = function() {
                                console.log("IndexedDB cache cleared");
                            };
                        } catch (e) {
                            console.error("Error clearing IndexedDB cache:", e);
                        }
                    }
                }
            };
            
            // Set up automatic caching for critical assets
            window.addEventListener('load', function() {
                // Cache critical CSS and JS files
                const criticalAssets = Array.from(document.querySelectorAll('script, link[rel="stylesheet"]'))
                    .map(el => el.src || el.href)
                    .filter(url => url && url.startsWith(window.location.origin));
                
                // Cache images that are visible in the viewport
                const visibleImages = Array.from(document.querySelectorAll('img'))
                    .filter(img => {
                        const rect = img.getBoundingClientRect();
                        return rect.top < window.innerHeight && rect.bottom > 0 && 
                               rect.left < window.innerWidth && rect.right > 0;
                    })
                    .map(img => img.src)
                    .filter(url => url);
                
                // Combine all assets to cache
                const assetsToCache = [...criticalAssets, ...visibleImages];
                
                // Cache each asset
                assetsToCache.forEach(url => {
                    fetch(url)
                        .then(response => response.text())
                        .then(content => {
                            window.fallbackCache.store(url, content);
                        })
                        .catch(error => {
                            console.error("Error caching asset:", url, error);
                        });
                });
            });
            
            // Notify native app that fallback cache is ready
            window.webkit.messageHandlers.cacheStatus.postMessage({
                action: "fallbackCacheReady"
            });
            
            // Set up offline detection
            window.addEventListener("online", function() {
                window.webkit.messageHandlers.offlineStatus.postMessage({
                    action: "connectivityChanged",
                    status: "online"
                });
            });
            
            window.addEventListener("offline", function() {
                window.webkit.messageHandlers.offlineStatus.postMessage({
                    action: "connectivityChanged",
                    status: "offline"
                });
            });
            
            // Initial status
            window.webkit.messageHandlers.offlineStatus.postMessage({
                action: "connectivityChanged",
                status: navigator.onLine ? "online" : "offline"
            });
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error setting up fallback mechanisms: \(error)")
            }
        }
    }
    
    /// Clear website data while preserving Service Worker registrations
    func clearWebsiteData(completion: @escaping (Bool) -> Void) {
        // Define data types to remove (excluding Service Worker registrations)
        let dataTypes = [
            WKWebsiteDataType.memoryCache,
            WKWebsiteDataType.diskCache,
            WKWebsiteDataType.offlineWebApplicationCache,
            WKWebsiteDataType.localStorage,
            WKWebsiteDataType.sessionStorage,
            WKWebsiteDataType.indexedDBDatabases,
            WKWebsiteDataType.cookies
        ]
        
        // Get the data store from the webView's configuration
        let dataStore = webView.configuration.websiteDataStore
        
        // Fetch records of all data types
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            // Filter out Service Worker registrations if we want to keep them
            let recordsToRemove = records.filter { record in
                // Keep service worker registrations for localhost
                if record.dataTypes.contains(WKWebsiteDataType.serviceWorkerRegistrations) && 
                   record.displayName.contains("localhost") {
                    print("Preserving Service Worker registration for \(record.displayName)")
                    return false
                }
                // Remove everything else
                return true
            }
            
            // Remove the filtered records
            dataStore.removeData(ofTypes: Set(dataTypes), 
                                for: recordsToRemove) {
                print("Website data cleared while preserving Service Worker registrations")
                completion(true)
            }
        }
    }
    
    /// Reload the WebView with proper cache settings
    func reloadWebView(ignoreCache: Bool = false) {
        if ignoreCache {
            webView.reloadFromOrigin()
        } else {
            webView.reload()
        }
    }
    
    /// Force update of Service Worker if one is registered
    func updateServiceWorker(completion: @escaping (Bool) -> Void) {
        guard serviceWorkerStatus == .registered else {
            print("No Service Worker registered to update")
            completion(false)
            return
        }
        
        let script = """
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.getRegistration().then(registration => {
                if (registration) {
                    registration.update().then(() => {
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "lifecycleEvent",
                            type: "update",
                            result: "success"
                        });
                    }).catch(error => {
                        window.webkit.messageHandlers.serviceWorker.postMessage({
                            action: "lifecycleEvent",
                            type: "update",
                            result: "error",
                            error: error.toString()
                        });
                    });
                } else {
                    window.webkit.messageHandlers.serviceWorker.postMessage({
                        action: "registrationStatus",
                        status: "unregistered"
                    });
                }
            });
        }
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error updating Service Worker: \(error)")
                completion(false)
            } else {
                // Success will be reported via message handler
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion(true)
                }
            }
        }
    }
    
    /// Skip the waiting state and activate a new Service Worker immediately
    func activateNewServiceWorker(completion: @escaping (Bool) -> Void) {
        let script = """
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.getRegistration().then(registration => {
                if (registration && registration.waiting) {
                    // Send message to the waiting Service Worker to activate it
                    registration.waiting.postMessage({type: 'SKIP_WAITING'});
                    window.webkit.messageHandlers.serviceWorker.postMessage({
                        action: "lifecycleEvent",
                        type: "skipWaiting",
                        result: "success"
                    });
                    return true;
                } else {
                    window.webkit.messageHandlers.serviceWorker.postMessage({
                        action: "lifecycleEvent",
                        type: "skipWaiting",
                        result: "noWaitingWorker"
                    });
                    return false;
                }
            }).catch(error => {
                window.webkit.messageHandlers.serviceWorker.postMessage({
                    action: "lifecycleEvent",
                    type: "skipWaiting",
                    result: "error",
                    error: error.toString()
                });
            });
        }
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Error activating new Service Worker: \(error)")
                completion(false)
            } else {
                // Success will be reported via message handler
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion(true)
                }
            }
        }
    }
    
    /// Display offline page when network is unavailable
    func showOfflinePage() {
        print("MainViewController: Showing offline page")
        
        // Try to load the offline.html page from the local server first
        if let serverURL = WebServerManager.shared.serverURL {
            let offlineURL = serverURL.appendingPathComponent("offline.html")
            let request = URLRequest(url: offlineURL)
            webView.load(request)
            return
        }
        
        // Fallback to inline HTML if server URL is not available
        let offlineHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Offline - ReplayWeb.page Mobile</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    margin: 0;
                    padding: 20px;
                    text-align: center;
                    background-color: #f5f5f7;
                    color: #333;
                }
                .offline-icon {
                    font-size: 48px;
                    margin-bottom: 20px;
                }
                h1 {
                    font-size: 24px;
                    margin-bottom: 10px;
                }
                p {
                    font-size: 16px;
                    margin-bottom: 20px;
                    color: #666;
                    max-width: 400px;
                }
                .buttons {
                    display: flex;
                    flex-direction: column;
                    gap: 12px;
                    width: 100%;
                    max-width: 250px;
                }
                button {
                    background-color: #007aff;
                    color: white;
                    border: none;
                    padding: 12px 24px;
                    border-radius: 8px;
                    font-size: 16px;
                    cursor: pointer;
                    transition: background-color 0.2s;
                }
                button.secondary {
                    background-color: #e0e0e0;
                    color: #333;
                }
                button:hover {
                    background-color: #0069d9;
                }
                button.secondary:hover {
                    background-color: #d0d0d0;
                }
                .cached-content {
                    margin-top: 20px;
                    font-size: 14px;
                    color: #666;
                }
                .spinner {
                    border: 3px solid rgba(0, 0, 0, 0.1);
                    border-radius: 50%;
                    border-top: 3px solid #007aff;
                    width: 24px;
                    height: 24px;
                    animation: spin 1s linear infinite;
                    display: inline-block;
                    vertical-align: middle;
                    margin-right: 8px;
                }
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
                .hidden {
                    display: none;
                }
            </style>
        </head>
        <body>
            <div class="offline-icon">📶</div>
            <h1>You're Offline</h1>
            <p>Unable to connect to the internet. You can try again or access your cached content.</p>
            
            <div class="buttons">
                <button id="reload-btn" onclick="tryReload()">Try Again</button>
                <button id="cached-btn" class="secondary" onclick="showCachedContent()">View Cached Content</button>
                <div id="loading" class="hidden">
                    <div class="spinner"></div> Checking connection...
                </div>
            </div>
            
            <div id="cached-status" class="cached-content hidden"></div>
            
            <script>
                // Check if we're still offline
                window.addEventListener("online", function() {
                    document.getElementById('reload-btn').click();
                });
                
                // Try to reload the page
                function tryReload() {
                    document.getElementById('loading').classList.remove('hidden');
                    document.getElementById('reload-btn').disabled = true;
                    
                    // Try to fetch a small resource to check connectivity
                    fetch('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P+/HgAFdwI2QOQjeQAAAABJRU5ErkJggg==', { 
                        mode: 'no-cors',
                        cache: 'no-store'
                    })
                    .then(() => {
                        // We're back online, reload the page
                        location.reload();
                    })
                    .catch(() => {
                        // Still offline
                        document.getElementById('loading').classList.add('hidden');
                        document.getElementById('reload-btn').disabled = false;
                        
                        // Show error message
                        const cachedStatus = document.getElementById('cached-status');
                        cachedStatus.textContent = 'Still offline. Please check your connection.';
                        cachedStatus.classList.remove('hidden');
                        
                        // Hide message after 3 seconds
                        setTimeout(() => {
                            cachedStatus.classList.add('hidden');
                        }, 3000);
                    });
                }
                
                // Show cached content if available
                function showCachedContent() {
                    const cachedStatus = document.getElementById('cached-status');
                    
                    // Check if we have cached content
                    if (window.fallbackCache) {
                        try {
                            // Try to get the last URL we were viewing
                            let lastURL = localStorage.getItem('lastViewedURL');
                            if (!lastURL) {
                                // Default to index if no last URL
                                lastURL = window.location.origin + '/index.html';
                            }
                            
                            window.fallbackCache.retrieve(lastURL)
                                .then(content => {
                                    if (content) {
                                        // We have cached content, show it
                                        document.body.innerHTML = content;
                                        // Inject our offline detection script again
                                        const script = document.createElement('script');
                                        script.textContent = `
                                            window.addEventListener("online", function() {
                                                location.reload();
                                            });
                                        `;
                                        document.body.appendChild(script);
                                    } else {
                                        cachedStatus.textContent = 'No cached content available.';
                                        cachedStatus.classList.remove('hidden');
                                    }
                                })
                                .catch(error => {
                                    cachedStatus.textContent = 'Error loading cached content.';
                                    cachedStatus.classList.remove('hidden');
                                    console.error('Error loading cached content:', error);
                                });
                        } catch (e) {
                            cachedStatus.textContent = 'No cached content available.';
                            cachedStatus.classList.remove('hidden');
                            console.error('Error accessing cache:', e);
                        }
                    } else {
                        cachedStatus.textContent = 'No cached content available.';
                        cachedStatus.classList.remove('hidden');
                    }
                }
                
                // Store current URL before going offline
                if (navigator.onLine) {
                    localStorage.setItem('lastViewedURL', window.location.href);
                }
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(offlineHTML, baseURL: URL(string: "http://localhost:8080"))
    }
}

// MARK: - WKScriptMessageHandler

// MARK: - WKScriptMessageHandler Implementation
extension MainViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: Any] else {
            print("Invalid message format received from JavaScript")
            return
        }
        
        // Handle messages based on handler name
        switch message.name {
        case "nativeApp":
            handleNativeAppMessage(messageBody)
            
        case "serviceWorker":
            handleServiceWorkerMessage(messageBody)
            
        case "offlineStatus":
            handleOfflineStatusMessage(messageBody)
            
        case "cacheStatus":
            handleCacheStatusMessage(messageBody)
            
        default:
            print("Unknown message handler: \(message.name)")
        }
    }
    
    private func handleNativeAppMessage(_ messageBody: [String: Any]) {
        guard let action = messageBody["action"] as? String else { return }
        
        switch action {
        case "openArchive":
            openArchive()
        default:
            print("Unknown nativeApp action: \(action)")
        }
    }
    
    private func handleServiceWorkerMessage(_ messageBody: [String: Any]) {
        guard let action = messageBody["action"] as? String else { return }
        
        switch action {
        case "registrationStatus":
            if let status = messageBody["status"] as? String {
                switch status {
                case "registered":
                    serviceWorkerStatus = .registered
                    print("Service Worker registered successfully")
                    if let scope = messageBody["scope"] as? String {
                        print("Service Worker scope: \(scope)")
                    }
                    NotificationCenter.default.post(name: NSNotification.Name("ServiceWorkerRegistered"), object: nil)
                    
                case "unregistered":
                    print("Service Worker not registered, attempting registration")
                    ensureServiceWorkerRegistration()
                    
                case "error":
                    serviceWorkerStatus = .failed
                    if let error = messageBody["error"] as? String {
                        print("Service Worker registration error: \(error)")
                    }
                    setupFallbackMechanisms()
                    NotificationCenter.default.post(name: NSNotification.Name("ServiceWorkerFailed"), object: nil)
                    
                case "unsupported":
                    serviceWorkerStatus = .unsupported
                    print("Service Workers not supported in this browser")
                    setupFallbackMechanisms()
                    NotificationCenter.default.post(name: NSNotification.Name("ServiceWorkerUnsupported"), object: nil)
                    
                default:
                    print("Unknown Service Worker status: \(status)")
                }
            }
            
        case "lifecycleEvent":
            if let eventType = messageBody["type"] as? String {
                print("Service Worker lifecycle event: \(eventType)")
                
                switch eventType {
                case "ready":
                    if let scope = messageBody["scope"] as? String {
                        print("Service Worker ready with scope: \(scope)")
                    }
                    
                case "controllerchange":
                    print("Service Worker controller changed - new version activated")
                    
                case "statechange":
                    if let state = messageBody["state"] as? String {
                        print("Service Worker state changed to: \(state)")
                        
                        // Handle different service worker states
                        switch state {
                        case "installed":
                            print("New Service Worker installed")
                            NotificationCenter.default.post(name: NSNotification.Name("ServiceWorkerUpdated"), object: nil)
                            
                        case "activated":
                            print("New Service Worker activated")
                            
                        case "redundant":
                            print("Service Worker became redundant")
                            // Check if we need to fall back to non-service worker mode
                            checkServiceWorkerRegistration()
                            
                        default:
                            break
                        }
                    }
                    
                default:
                    print("Unknown Service Worker lifecycle event: \(eventType)")
                }
            }
            
        case "workerMessage":
            if let dataString = messageBody["data"] as? String {
                print("Message from Service Worker: \(dataString)")
                
                // Parse the message if it's in JSON format
                if let data = dataString.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Handle specific messages from service worker
                    if let messageType = jsonObject["type"] as? String {
                        switch messageType {
                        case "cacheComplete":
                            print("Service Worker cache complete")
                            NotificationCenter.default.post(name: NSNotification.Name("ServiceWorkerCacheComplete"), object: nil)
                            
                        case "cacheError":
                            print("Service Worker cache error")
                            NotificationCenter.default.post(name: NSNotification.Name("ServiceWorkerCacheError"), object: nil)
                            
                        default:
                            break
                        }
                    }
                }
            }
            
        default:
            print("Unknown serviceWorker action: \(action)")
        }
    }
    
    private func handleOfflineStatusMessage(_ messageBody: [String: Any]) {
        guard let action = messageBody["action"] as? String else { return }
        
        switch action {
        case "connectivityChanged":
            if let status = messageBody["status"] as? String {
                print("Connectivity status changed: \(status)")
                if status == "offline" {
                    // If we're offline and Service Workers aren't supported, show offline page
                    if serviceWorkerStatus != .registered {
                        showOfflinePage()
                    }
                }
            }
            
        default:
            print("Unknown offlineStatus action: \(action)")
        }
    }
    
    private func handleCacheStatusMessage(_ messageBody: [String: Any]) {
        guard let action = messageBody["action"] as? String else { return }
        
        switch action {
        case "fallbackCacheReady":
            print("Fallback cache mechanism is ready")
            
        default:
            print("Unknown cacheStatus action: \(action)")
        }
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Show loading indicator
        showLoadingIndicator(true)
        
        // If we're offline and trying to load a non-local URL, show offline page
        if !isOnline, let url = webView.url, !url.isFileURL && !url.host?.contains("localhost") ?? true {
            webView.stopLoading()
            showOfflinePage()
            showLoadingIndicator(false)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide loading indicator
        showLoadingIndicator(false)
        hideErrorMessage()
        
        // Check Service Worker registration after navigation completes
        checkServiceWorkerRegistration()
        
        // Notify that the web view load is complete
        NotificationCenter.default.post(name: NSNotification.Name("WebViewLoadComplete"), object: nil)
        
        // Store the current URL for offline fallback
        if isOnline, let url = webView.url?.absoluteString {
            let script = "localStorage.setItem('lastViewedURL', '" + url + "');"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadingIndicator(false)
        
        // If the error is related to network connectivity and we're offline, show offline page
        let nsError = error as NSError
        if !isOnline || nsError.domain == NSURLErrorDomain && 
           (nsError.code == NSURLErrorNotConnectedToInternet || 
            nsError.code == NSURLErrorNetworkConnectionLost) {
            showOfflinePage()
        } else {
            showErrorMessage("Navigation failed: \(error.localizedDescription)")
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadingIndicator(false)
        
        // If the error is related to network connectivity and we're offline, show offline page
        let nsError = error as NSError
        if !isOnline || nsError.domain == NSURLErrorDomain && 
           (nsError.code == NSURLErrorNotConnectedToInternet || 
            nsError.code == NSURLErrorNetworkConnectionLost) {
            showOfflinePage()
        } else {
            showErrorMessage("Failed to load page: \(error.localizedDescription)")
        }
    }
    
    /// Display an offline fallback page when connectivity is lost
    private func showOfflinePage() {
        // Clear any current loading operations
        showLoadingIndicator(false)
        
        // Check if we have an active archive loaded
        if let activeArchiveURL = ArchiveManager.shared.getActiveArchiveURL() {
            // If we have an active archive, try to load its offline version through the Service Worker
            if serviceWorkerStatus == .registered {
                // Service Worker is registered - it should handle the offline navigation automatically
                // Just reload the current page and let the Service Worker intercept
                webView.reload()
                return
            }
            
            // Try to load from fallback cache
            let script = """
            (function() {
                // Try to load the last viewed URL from localStorage
                const lastURL = localStorage.getItem('lastViewedURL');
                if (lastURL) {
                    // Check if we have this page in our fallback cache
                    const content = window.fallbackCache.get(lastURL);
                    if (content) {
                        // We have cached content, display it
                        document.open();
                        document.write(content);
                        document.close();
                        return { success: true, url: lastURL };
                    }
                }
                return { success: false };
            })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let result = result as? [String: Any], 
                   let success = result["success"] as? Bool, 
                   success {
                    // Successfully loaded from cache
                    return
                }
                
                // If we couldn't load from cache, load a generic offline page
                self.loadGenericOfflinePage(archiveURL: activeArchiveURL)
            }
        } else {
            // No active archive, show a generic offline page
            loadGenericOfflinePage()
        }
    }
    
    /// Load a generic offline page with basic functionality
    private func loadGenericOfflinePage(archiveURL: URL? = nil) {
        // Create a basic HTML offline page
        let archiveInfo = archiveURL != nil ? "You were viewing archive: \(archiveURL!.lastPathComponent)" : "No archive was loaded"
        
        let offlineHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Offline - ReplayWeb</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; color: #333; }
                .container { max-width: 600px; margin: 0 auto; text-align: center; }
                .icon { font-size: 64px; margin-bottom: 20px; }
                h1 { color: #555; font-size: 24px; }
                p { line-height: 1.5; margin-bottom: 20px; }
                .btn { background: #007AFF; color: white; border: none; padding: 12px 20px; border-radius: 8px; 
                      font-size: 16px; cursor: pointer; margin-top: 10px; }
                .info { font-size: 14px; color: #777; margin-top: 40px; font-style: italic; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">📡</div>
                <h1>You're Offline</h1>
                <p>Cannot connect to the internet. Please check your connection.</p>
                <p>\(archiveInfo)</p>
                <button class="btn" onclick="window.location.reload()">Try Again</button>
                <p class="info">Archives that have been fully cached will still work while offline.</p>
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(offlineHTML, baseURL: WebServerManager.shared.serverURL)
    }
}
