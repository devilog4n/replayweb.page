import Foundation
import UIKit
import UniformTypeIdentifiers

class FilePicker: NSObject {
    // MARK: - Properties
    private weak var presentingViewController: UIViewController?
    private var completionHandler: ((URL?) -> Void)?
    
    // MARK: - Public Methods
    
    /// Present a file picker for selecting WACZ archives
    /// - Parameters:
    ///   - viewController: The view controller to present the file picker from
    ///   - completion: Completion handler called with the selected file URL or nil if cancelled
    func presentPicker(from viewController: UIViewController, completion: @escaping (URL?) -> Void) {
        self.presentingViewController = viewController
        self.completionHandler = completion
        
        // Create a document picker for WACZ files
        let documentTypes: [UTType]
        
        if #available(iOS 14.0, *) {
            // Check for custom WACZ type first
            if let waczType = UTType("org.webrecorder.wacz") {
                documentTypes = [waczType]
            } else {
                // Fallback to generic archive types if custom type isn't registered
                documentTypes = [UTType.archive, UTType.zip, UTType.data]
                print("FilePicker: WACZ file type not registered, falling back to generic archive types")
            }
        } else {
            // Fallback for older iOS versions
            let picker = UIDocumentPickerViewController(documentTypes: ["public.archive", "public.zip-archive", "public.data"], in: .import)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            
            viewController.present(picker, animated: true)
            return
        }
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: documentTypes)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        
        // Add a loading indicator when presented for better UX
        viewController.present(picker, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension FilePicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completionHandler?(nil)
            return
        }
        
        // Create and show a loading indicator
        let loadingAlert = UIAlertController(
            title: "Importing Archive",
            message: "Please wait while the archive is being imported...",
            preferredStyle: .alert
        )
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        presentingViewController?.present(loadingAlert, animated: true)
        
        // Check if the file has a .wacz extension
        if url.pathExtension.lowercased() != "wacz" {
            // Dismiss loading indicator and show error
            loadingAlert.dismiss(animated: true) { [weak self] in
                // Show an alert that only WACZ files are supported
                let alert = UIAlertController(
                    title: "Unsupported File",
                    message: "Only .wacz archive files are supported. Please select a valid web archive.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.presentingViewController?.present(alert, animated: true)
            }
            
            completionHandler?(nil)
            return
        }
        
        // Get file size to check if it might be too large
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSizeBytes) / (1024 * 1024)
            
            // Log file size for debugging
            print("FilePicker: Selected WACZ file size: \(fileSizeMB) MB")
            
            // Warn if file is very large (over 100MB)
            if fileSizeMB > 100 {
                print("FilePicker: Warning - Selected file is large (\(fileSizeMB) MB)")
            }
        } catch {
            print("FilePicker: Could not determine file size: \(error.localizedDescription)")
        }
        
        // Start accessing the security-scoped resource
        let securityGranted = url.startAccessingSecurityScopedResource()
        
        // Import the file with timeout monitoring
        let importTimeout = DispatchWorkItem {
            loadingAlert.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                
                let timeoutAlert = UIAlertController(
                    title: "Import Timeout",
                    message: "The archive import is taking longer than expected. Would you like to continue waiting or cancel?",
                    preferredStyle: .alert
                )
                
                timeoutAlert.addAction(UIAlertAction(title: "Continue Waiting", style: .default))
                timeoutAlert.addAction(UIAlertAction(title: "Cancel", style: .destructive) { _ in
                    // If user chooses to cancel, stop the import
                    if securityGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                    self.completionHandler?(nil)
                })
                
                self.presentingViewController?.present(timeoutAlert, animated: true)
            }
        }
        
        // Schedule timeout if import takes too long (15 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: importTimeout)
        
        // Import the file
        ArchiveManager.shared.importArchive(from: url) { [weak self] result in
            // Cancel timeout
            importTimeout.cancel()
            
            guard let self = self else { return }
            
            // Stop accessing the security-scoped resource
            if securityGranted {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Dismiss loading indicator
            loadingAlert.dismiss(animated: true) {
                switch result {
                case .success(let importedURL):
                    // Set as active archive
                    _ = ArchiveManager.shared.setActiveArchive(importedURL)
                    
                    // Restart the web server to serve the new archive
                    _ = WebServerManager.shared.restartServer()
                    
                    // Show success feedback
                    let successAlert = UIAlertController(
                        title: "Archive Imported",
                        message: "The archive has been successfully imported and is ready to use.",
                        preferredStyle: .alert
                    )
                    successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.completionHandler?(importedURL)
                    })
                    self.presentingViewController?.present(successAlert, animated: true)
                    
                case .failure(let error):
                    print("FilePicker: Error importing archive - \(error.localizedDescription)")
                    
                    // Show an error alert with more detailed information
                    var errorMessage = "Failed to import the selected archive. "
                    
                    // Provide more specific error messages based on error type
                    if let archiveError = error as? ArchiveManager.ArchiveError {
                        switch archiveError {
                        case .directoryNotFound:
                            errorMessage += "Could not access archives directory."
                        case .importFailed:
                            errorMessage += "Could not copy the archive file."
                        case .invalidArchive:
                            errorMessage += "The archive appears to be invalid or corrupted."
                        }
                    } else if (error as NSError).domain == NSCocoaErrorDomain {
                        // Handle common file system errors
                        switch (error as NSError).code {
                        case NSFileWriteOutOfSpaceError:
                            errorMessage += "Your device is out of storage space."
                        case NSFileWriteNoPermissionError:
                            errorMessage += "Permission denied when copying the file."
                        default:
                            errorMessage += error.localizedDescription
                        }
                    } else {
                        errorMessage += error.localizedDescription
                    }
                    
                    let alert = UIAlertController(
                        title: "Import Failed",
                        message: errorMessage,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.presentingViewController?.present(alert, animated: true)
                    
                    self.completionHandler?(nil)
                }
            }
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completionHandler?(nil)
    }
}
