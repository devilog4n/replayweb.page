// UIKitImport.swift - Central import point for all system frameworks

// Simple direct import strategy - bypassing module issues
import Foundation

// Use direct C-style imports for UIKit
#if os(iOS)
@_exported import UIKit

// Ensure symbols are used to force linking
final class UIKitLinker {
    static let shared = UIKitLinker()
    private init() {}
    
    func ensureLinked() {
        #if os(iOS)
        _ = UIView(frame: .zero)
        #endif
    }
}
#endif

