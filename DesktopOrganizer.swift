import Foundation
import AppKit

class DesktopOrganizer: ObservableObject {
    @Published var desktopFiles: [URL] = []
    @Published var isScanning = false
    @Published var organizationProgress: Double = 0.0
    
    private let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    
    // Predefined folder suggestions
    let folderSuggestions = [
        "Desktop Cleanup \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))",
        "Desktop Archive",
        "Organized Files",
        "Quick Access",
        "To Sort"
    ]
    
    // File type categories for smart organization
    enum FileCategory: String, CaseIterable {
        case images = "Images"
        case documents = "Documents"
        case videos = "Videos"
        case audio = "Audio"
        case archives = "Archives"
        case code = "Code"
        case other = "Other"
        
        var extensions: Set<String> {
            switch self {
            case .images:
                return ["jpg", "jpeg", "png", "gif", "bmp", "svg", "webp", "ico", "heic", "heif", "tiff", "psd", "ai"]
            case .documents:
                return ["pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key"]
            case .videos:
                return ["mp4", "avi", "mov", "wmv", "flv", "mkv", "webm", "m4v", "mpg", "mpeg"]
            case .audio:
                return ["mp3", "wav", "flac", "aac", "ogg", "wma", "m4a", "aiff", "ape", "opus"]
            case .archives:
                return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg", "deb", "rpm"]
            case .code:
                return ["js", "ts", "jsx", "tsx", "py", "java", "cpp", "c", "h", "cs", "php", "rb", "go", "rs", "swift", "kt", "scala", "r", "m", "sh", "ps1", "bat"]
            case .other:
                return []
            }
        }
    }
    
    func scanDesktop() async {
        await MainActor.run {
            isScanning = true
            desktopFiles = []
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: desktopURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            let files = contents.filter { url in
                // Skip directories and hidden files
                let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                return resourceValues?.isRegularFile == true
            }
            
            await MainActor.run {
                desktopFiles = files
                isScanning = false
            }
        } catch {
            print("Error scanning desktop: \(error)")
            await MainActor.run {
                isScanning = false
            }
        }
    }
    
    func organizeIntoFolder(folderName: String, organizeByType: Bool) async -> Bool {
        let folderURL = desktopURL.appendingPathComponent(folderName)
        
        do {
            // Create main folder if it doesn't exist
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            let filesToMove = desktopFiles
            let totalFiles = Double(filesToMove.count)
            var movedCount = 0.0
            
            for file in filesToMove {
                let targetFolder: URL
                
                if organizeByType {
                    // Determine category and create subfolder
                    let category = categorizeFile(file)
                    let categoryFolder = folderURL.appendingPathComponent(category.rawValue)
                    
                    if !FileManager.default.fileExists(atPath: categoryFolder.path) {
                        try FileManager.default.createDirectory(at: categoryFolder, withIntermediateDirectories: true)
                    }
                    
                    targetFolder = categoryFolder
                } else {
                    targetFolder = folderURL
                }
                
                let destinationURL = targetFolder.appendingPathComponent(file.lastPathComponent)
                
                // Handle duplicate filenames
                let finalDestination = uniqueFileURL(destinationURL)
                
                try FileManager.default.moveItem(at: file, to: finalDestination)
                
                movedCount += 1
                await MainActor.run {
                    organizationProgress = movedCount / totalFiles
                }
            }
            
            // Refresh the file list
            await scanDesktop()
            
            return true
        } catch {
            print("Error organizing desktop: \(error)")
            return false
        }
    }
    
    private func categorizeFile(_ url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()
        
        for category in FileCategory.allCases {
            if category.extensions.contains(ext) {
                return category
            }
        }
        
        return .other
    }
    
    private func uniqueFileURL(_ url: URL) -> URL {
        var finalURL = url
        var counter = 1
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newName = "\(nameWithoutExtension) \(counter)"
            finalURL = url.deletingLastPathComponent().appendingPathComponent(newName).appendingPathExtension(ext)
            counter += 1
        }
        
        return finalURL
    }
    
    func getExistingDesktopFolders() -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: desktopURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            return contents.compactMap { url in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return resourceValues?.isDirectory == true ? url.lastPathComponent : nil
            }
        } catch {
            print("Error getting desktop folders: \(error)")
            return []
        }
    }
}