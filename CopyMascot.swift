import Foundation
import SwiftUI

// Helper to copy mascot to app's Application Support directory
struct MascotHelper {
    static func setupMascot() {
        let fileManager = FileManager.default
        
        // Get Application Support directory for the app
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, 
                                               in: .userDomainMask).first else { return }
        
        // Create Klinmai directory if needed
        let klinmaiDir = appSupport.appendingPathComponent("Klinmai")
        try? fileManager.createDirectory(at: klinmaiDir, withIntermediateDirectories: true)
        
        // Destination for mascot
        let destPath = klinmaiDir.appendingPathComponent("mascot.png")
        
        // Source path
        let sourcePath = NSHomeDirectory() + "/Documents/Desktop_Cleaned/Images/klinmai.png"
        let sourceURL = URL(fileURLWithPath: sourcePath)
        
        // Copy if doesn't exist
        if !fileManager.fileExists(atPath: destPath.path) {
            try? fileManager.copyItem(at: sourceURL, to: destPath)
            print("✅ Mascot copied to app directory")
        }
    }
    
    static func getMascotPath() -> String {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, 
                                               in: .userDomainMask).first else { 
            return NSHomeDirectory() + "/Documents/Desktop_Cleaned/Images/klinmai.png"
        }
        return appSupport.appendingPathComponent("Klinmai/mascot.png").path
    }
}