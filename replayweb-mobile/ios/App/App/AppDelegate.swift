import UIKit
import WebKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    // Background task identifier for maintaining web server in background
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize and start GCDWebServer first
        let serverStarted = WebServerManager.shared.startServer()
        if !serverStarted {
            print("Warning: Failed to start web server")
        }
        
        // Create and set up the main view controller with WKWebView
        let mainVC = MainViewController()
        
        // Set up window with the main view controller
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = mainVC
        window?.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Start background task to keep web server running
        backgroundTask = application.beginBackgroundTask { [weak self] in
            // End the task if time expires
            if let task = self?.backgroundTask, task != .invalid {
                application.endBackgroundTask(task)
                self?.backgroundTask = .invalid
            }
        }
        
        // Notify the MainViewController that we're entering background
        NotificationCenter.default.post(name: NSNotification.Name("AppEnteringBackground"), object: nil)
        
        // Ensure the server keeps running in the background
        WebServerManager.shared.ensureServerRunning()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // End the background task if it's active
        if backgroundTask != .invalid {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("AppDelegate: Ended background task")
        }
        
        // Ensure the server is running
        if !WebServerManager.shared.isRunning {
            print("AppDelegate: Restarting web server after returning to foreground")
            WebServerManager.shared.startServer()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Find MainViewController and refresh Service Worker registrations
        if let rootVC = window?.rootViewController as? MainViewController {
            // Verify Service Worker registrations are intact
            rootVC.checkServiceWorkerRegistration()
            
            // Check network connectivity
            rootVC.checkNetworkConnectivity()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Stop the web server when the app terminates
        WebServerManager.shared.stopServer()
        
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
