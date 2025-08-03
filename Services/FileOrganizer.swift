import Foundation
import UniformTypeIdentifiers

class FileOrganizer {
    private let fileManager = FileManager.default
    private let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    
    func organizeDesktop(using sortMode: SortMode, customFolder: URL? = nil) async throws -> CleanInfo {
        var movedFiles: [MovedFile] = []
        
        let contents = try fileManager.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: [.creationDateKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        )
        
        for fileURL in contents {
            // Skip directories and system files
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  !isSystemFile(fileURL) else { continue }
            
            // Skip if it's the Organized folder itself
            if fileURL.lastPathComponent == "Organized" { continue }
            
            let destinationURL = try getDestinationURL(for: fileURL, sortMode: sortMode, customFolder: customFolder)
            
            // Create destination directory if needed
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            // Move file
            let newFileURL = destinationURL.appendingPathComponent(fileURL.lastPathComponent)
            try fileManager.moveItem(at: fileURL, to: newFileURL)
            
            movedFiles.append(MovedFile(originalPath: fileURL, newPath: newFileURL))
        }
        
        // Clean up old screenshots if enabled
        let preferences = loadPreferences()
        if preferences.deleteOldScreenshots {
            cleanupOldScreenshots()
        }
        
        return CleanInfo(date: Date(), movedFiles: movedFiles)
    }
    
    func undoClean(_ cleanInfo: CleanInfo) async throws {
        for movedFile in cleanInfo.movedFiles {
            if fileManager.fileExists(atPath: movedFile.newPath.path) {
                try fileManager.moveItem(at: movedFile.newPath, to: movedFile.originalPath)
            }
        }
        
        // Clean up empty directories
        cleanupEmptyDirectories()
    }
    
    private func getDestinationURL(for fileURL: URL, sortMode: SortMode, customFolder: URL?) throws -> URL {
        // Always use smart native organization - no monthly folders!
        let home = FileManager.default.homeDirectoryForCurrentUser
        let ext = fileURL.pathExtension.lowercased()
        let fileName = fileURL.lastPathComponent.lowercased()
        
        // Check if it's a screenshot
        let isScreenshot = fileName.contains("screenshot") || fileName.hasPrefix("screen shot") || 
                          fileName.hasPrefix("capture") || fileName.hasPrefix("snip")
        
        // Handle screenshots specially if folder is enabled
        let preferences = loadPreferences()
        if isScreenshot && preferences.createScreenshotsFolder {
            let documentsURL = home.appendingPathComponent("Documents")
            let screenshotsURL = documentsURL.appendingPathComponent("Screenshots")
            
            // Get month folder (e.g., "2024-01 January")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM MMMM"
            let monthFolder = formatter.string(from: Date())
            let monthURL = screenshotsURL.appendingPathComponent(monthFolder)
            
            try? FileManager.default.createDirectory(at: monthURL, withIntermediateDirectories: true)
            return monthURL
        }
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp", "heic":
            return home.appendingPathComponent("Pictures")
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "md", "key", "numbers":
            return home.appendingPathComponent("Documents")
        case "mp3", "m4a", "wav", "aiff", "flac", "aac":
            return home.appendingPathComponent("Music")
        case "mp4", "mov", "avi", "mkv", "m4v":
            return home.appendingPathComponent("Movies")
        case "swift", "py", "js", "html", "css", "json", "xml":
            let devFolder = home.appendingPathComponent("Developer")
            try? FileManager.default.createDirectory(at: devFolder, withIntermediateDirectories: true)
            return devFolder
        case "zip", "dmg", "pkg", "tar", "gz":
            let archiveFolder = home.appendingPathComponent("Downloads/Archive")
            try? FileManager.default.createDirectory(at: archiveFolder, withIntermediateDirectories: true)
            return archiveFolder
        default:
            return home.appendingPathComponent("Documents")
        }
    }
    
    private func getDateBasedDestination(for fileURL: URL) throws -> URL {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let creationDate = attributes[.creationDate] as? Date ?? Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM"
        let datePath = formatter.string(from: creationDate)
        
        let fileType = getFileType(for: fileURL)
        return desktopURL
            .appendingPathComponent("Organized")
            .appendingPathComponent(datePath)
            .appendingPathComponent(fileType.folderName)
    }
    
    private func getTypeBasedDestination(for fileURL: URL) -> URL {
        let fileType = getFileType(for: fileURL)
        return desktopURL
            .appendingPathComponent("Organized")
            .appendingPathComponent(fileType.folderName)
    }
    
    private func getSmartBundleDestination(for fileURL: URL) -> URL {
        // Group by project name patterns or timestamp similarity
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        
        // Extract project name (e.g., "ProjectName_v1_final" -> "ProjectName")
        let projectName = extractProjectName(from: fileName)
        
        return desktopURL
            .appendingPathComponent("Organized")
            .appendingPathComponent("Projects")
            .appendingPathComponent(projectName)
    }
    
    private func extractProjectName(from fileName: String) -> String {
        // Remove common suffixes and version numbers
        let patterns = ["_v\\d+", "_final", "_draft", "_copy", "\\s\\(\\d+\\)"]
        var cleanName = fileName
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleanName = regex.stringByReplacingMatches(
                    in: cleanName,
                    options: [],
                    range: NSRange(location: 0, length: cleanName.count),
                    withTemplate: ""
                )
            }
        }
        
        return cleanName.isEmpty ? "Misc" : cleanName
    }
    
    private func getFileType(for fileURL: URL) -> FileType {
        guard let type = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return .other
        }
        
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .videos }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .pdf) || type.conforms(to: .text) { return .documents }
        if type.conforms(to: .archive) || type.conforms(to: .diskImage) { return .archives }
        if type.conforms(to: .sourceCode) { return .code }
        
        return .other
    }
    
    private func isSystemFile(_ url: URL) -> Bool {
        let systemFiles = [".DS_Store", ".localized", "desktop.ini"]
        return systemFiles.contains(url.lastPathComponent)
    }
    
    private func cleanupEmptyDirectories() {
        let organizedURL = desktopURL.appendingPathComponent("Organized")
        if let enumerator = fileManager.enumerator(at: organizedURL, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue,
                   (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil))?.isEmpty == true {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }
    
    private func loadPreferences() -> Preferences {
        if let data = UserDefaults.standard.data(forKey: "preferences"),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            return decoded
        }
        return Preferences()
    }
    
    private func cleanupOldScreenshots() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let screenshotsURL = home.appendingPathComponent("Documents/Screenshots")
        
        guard fileManager.fileExists(atPath: screenshotsURL.path) else { return }
        
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        if let enumerator = fileManager.enumerator(at: screenshotsURL, includingPropertiesForKeys: [.creationDateKey]) {
            for case let fileURL as URL in enumerator {
                guard !fileURL.hasDirectoryPath else { continue }
                
                if let attributes = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < thirtyDaysAgo {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
}

enum FileType {
    case images, videos, documents, audio, archives, code, other
    
    var folderName: String {
        switch self {
        case .images: return "Images"
        case .videos: return "Videos"
        case .documents: return "Documents"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .code: return "Code"
        case .other: return "Other"
        }
    }
}

enum OrganizerError: LocalizedError {
    case noCustomFolderSelected
    
    var errorDescription: String? {
        switch self {
        case .noCustomFolderSelected:
            return "No custom folder selected. Please choose a folder in preferences."
        }
    }
}