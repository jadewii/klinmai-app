import Foundation
import AppKit

class NativeFileOrganizer: ObservableObject {
    @Published var isOrganizing = false
    @Published var lastOrganizedCount = 0
    
    // SMART FILE ORGANIZATION - Uses native macOS workflow
    // No artificial monthly folders - just smart native locations
    private let fileTypeMapping: [String: URL] = {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        return [
            // Images -> Pictures (as intended by macOS)
            "jpg": homeURL.appendingPathComponent("Pictures"),
            "jpeg": homeURL.appendingPathComponent("Pictures"),
            "png": homeURL.appendingPathComponent("Pictures"),
            "gif": homeURL.appendingPathComponent("Pictures"),
            "bmp": homeURL.appendingPathComponent("Pictures"),
            "tiff": homeURL.appendingPathComponent("Pictures"),
            "svg": homeURL.appendingPathComponent("Pictures"),
            "webp": homeURL.appendingPathComponent("Pictures"),
            "heic": homeURL.appendingPathComponent("Pictures"),
            
            // Documents -> Documents (native macOS workflow)
            "pdf": homeURL.appendingPathComponent("Documents"),
            "doc": homeURL.appendingPathComponent("Documents"),
            "docx": homeURL.appendingPathComponent("Documents"),
            "txt": homeURL.appendingPathComponent("Documents"),
            "rtf": homeURL.appendingPathComponent("Documents"),
            "pages": homeURL.appendingPathComponent("Documents"),
            "md": homeURL.appendingPathComponent("Documents"),
            "key": homeURL.appendingPathComponent("Documents"),
            "numbers": homeURL.appendingPathComponent("Documents"),
            
            // Audio -> Music (where it belongs!)
            "mp3": homeURL.appendingPathComponent("Music"),
            "m4a": homeURL.appendingPathComponent("Music"),
            "wav": homeURL.appendingPathComponent("Music"),
            "aiff": homeURL.appendingPathComponent("Music"),
            "flac": homeURL.appendingPathComponent("Music"),
            "aac": homeURL.appendingPathComponent("Music"),
            
            // Video -> Movies (native location)
            "mp4": homeURL.appendingPathComponent("Movies"),
            "mov": homeURL.appendingPathComponent("Movies"),
            "avi": homeURL.appendingPathComponent("Movies"),
            "mkv": homeURL.appendingPathComponent("Movies"),
            "m4v": homeURL.appendingPathComponent("Movies"),
            
            // Code files -> Developer (if exists, otherwise Documents)
            "swift": homeURL.appendingPathComponent("Developer"),
            "py": homeURL.appendingPathComponent("Developer"),
            "js": homeURL.appendingPathComponent("Developer"),
            "html": homeURL.appendingPathComponent("Developer"),
            "css": homeURL.appendingPathComponent("Developer"),
            "json": homeURL.appendingPathComponent("Developer"),
            "xml": homeURL.appendingPathComponent("Developer"),
            
            // Archives -> Downloads/Archive (keep downloads organized)
            "zip": homeURL.appendingPathComponent("Downloads/Archive"),
            "dmg": homeURL.appendingPathComponent("Downloads/Archive"),
            "pkg": homeURL.appendingPathComponent("Downloads/Archive"),
            "tar": homeURL.appendingPathComponent("Downloads/Archive"),
            "gz": homeURL.appendingPathComponent("Downloads/Archive")
        ]
    }()
    
    func organizeDesktop() async {
        await MainActor.run {
            isOrganizing = true
            lastOrganizedCount = 0
        }
        
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: desktopURL, includingPropertiesForKeys: nil)
            var organizedCount = 0
            
            for fileURL in contents {
                // Skip directories, system files, and hidden files
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue,
                      !fileURL.lastPathComponent.hasPrefix("."),
                      !fileURL.lastPathComponent.hasPrefix("~") else {
                    continue
                }
                
                let fileExtension = fileURL.pathExtension.lowercased()
                
                if let destinationFolder = fileTypeMapping[fileExtension] {
                    // Ensure destination folder exists
                    try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                    
                    let destinationURL = destinationFolder.appendingPathComponent(fileURL.lastPathComponent)
                    
                    // Handle naming conflicts
                    let finalDestination = getNonConflictingURL(destinationURL)
                    
                    try fileManager.moveItem(at: fileURL, to: finalDestination)
                    
                    // Add native macOS tags based on file type
                    addNativeTag(to: finalDestination, for: fileExtension)
                    
                    organizedCount += 1
                }
            }
            
            await MainActor.run {
                self.lastOrganizedCount = organizedCount
                self.isOrganizing = false
            }
            
            // Show native macOS notification
            showNativeNotification(count: organizedCount)
            
        } catch {
            await MainActor.run {
                self.isOrganizing = false
            }
            print("Error organizing desktop: \(error)")
        }
    }
    
    private func getNonConflictingURL(_ url: URL) -> URL {
        let fileManager = FileManager.default
        var counter = 1
        var newURL = url
        
        while fileManager.fileExists(atPath: newURL.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newName = "\(nameWithoutExtension) \(counter).\(ext)"
            newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }
        
        return newURL
    }
    
    private func addNativeTag(to url: URL, for fileExtension: String) {
        do {
            var resourceValues = URLResourceValues()
            
            // Add color-coded tags based on file type
            switch fileExtension {
            case "swift", "py", "js", "html", "css", "json", "xml":
                resourceValues.tagNames = ["Code"]
            case "mp3", "m4a", "wav", "aiff", "flac", "aac":
                resourceValues.tagNames = ["Music"]
            case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp":
                resourceValues.tagNames = ["Images"]
            case "pdf", "doc", "docx", "txt", "rtf", "pages", "md":
                resourceValues.tagNames = ["Documents"]
            default:
                resourceValues.tagNames = ["Organized"]
            }
            
            try url.setResourceValues(resourceValues)
        } catch {
            print("Could not add tag to \(url.lastPathComponent): \(error)")
        }
    }
    
    private func showNativeNotification(count: Int) {
        let notification = NSUserNotification()
        notification.title = "Desktop Cleaned! 🧹✨"
        notification.informativeText = "Organized \(count) files using native macOS workflow"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}