import Foundation

struct FileOrganizerResults {
    let filesOrganized: Int
    let filesArchived: Int
    let filesScanned: Int
    let oldestFileDate: Date?
    let errors: [String]
}

class FileOrganizer {
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    func cleanDesktop() async -> FileOrganizerResults {
        let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let cleanedPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Desktop_Cleaned")
        
        return await organizeDirectory(
            sourceURL: desktopURL,
            destinationURL: cleanedPath,
            groupByType: true
        )
    }
    
    func cleanDownloads() async -> FileOrganizerResults {
        let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        return await organizeDirectory(
            sourceURL: downloadsURL,
            destinationURL: downloadsURL,
            groupByType: true,
            inPlace: true
        )
    }
    
    func archiveOldFiles(olderThanMonths months: Int) async -> FileOrganizerResults {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let archiveURL = documentsURL.appendingPathComponent("Archive")
        
        var filesArchived = 0
        var errors: [String] = []
        
        // Create archive directory if needed
        try? fileManager.createDirectory(at: archiveURL, withIntermediateDirectories: true)
        
        // Calculate cutoff date
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -months, to: Date())!
        
        // Scan common directories
        let directoriesToScan = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
            documentsURL
        ]
        
        for directory in directoriesToScan {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
                )
                
                for fileURL in contents {
                    // Skip directories and already archived files
                    if fileURL.lastPathComponent.hasPrefix(".") ||
                       fileURL.path.contains("/Archive/") {
                        continue
                    }
                    
                    let attributes = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
                    
                    if let modDate = attributes.contentModificationDate,
                       attributes.isDirectory != true,
                       modDate < cutoffDate {
                        
                        let yearMonth = dateFormatter.string(from: modDate).prefix(7)
                        let destDir = archiveURL.appendingPathComponent(String(yearMonth))
                        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
                        
                        let destURL = destDir.appendingPathComponent(fileURL.lastPathComponent)
                        try fileManager.moveItem(at: fileURL, to: destURL)
                        filesArchived += 1
                    }
                }
            } catch {
                errors.append("Error archiving in \(directory.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        return FileOrganizerResults(
            filesOrganized: 0,
            filesArchived: filesArchived,
            filesScanned: 0,
            oldestFileDate: nil,
            errors: errors
        )
    }
    
    private func organizeDirectory(
        sourceURL: URL,
        destinationURL: URL,
        groupByType: Bool,
        inPlace: Bool = false
    ) async -> FileOrganizerResults {
        var filesOrganized = 0
        var filesScanned = 0
        var oldestFileDate: Date?
        var errors: [String] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: sourceURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]
            )
            
            for fileURL in contents {
                // Skip hidden files and directories
                if fileURL.lastPathComponent.hasPrefix(".") {
                    continue
                }
                
                let attributes = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                if attributes.isDirectory == true {
                    continue
                }
                
                filesScanned += 1
                
                // Track oldest file
                if let modDate = attributes.contentModificationDate {
                    if oldestFileDate == nil || modDate < oldestFileDate! {
                        oldestFileDate = modDate
                    }
                }
                
                let category = categorizeFile(fileURL)
                let categoryDir = inPlace ? 
                    sourceURL.appendingPathComponent(category) :
                    destinationURL.appendingPathComponent(category)
                
                // Skip if already in the right category folder
                if fileURL.deletingLastPathComponent() == categoryDir {
                    continue
                }
                
                do {
                    try fileManager.createDirectory(
                        at: categoryDir,
                        withIntermediateDirectories: true
                    )
                    
                    let destURL = categoryDir.appendingPathComponent(fileURL.lastPathComponent)
                    
                    // Handle duplicates by appending number
                    let finalURL = uniqueURL(for: destURL)
                    
                    try fileManager.moveItem(at: fileURL, to: finalURL)
                    filesOrganized += 1
                    
                } catch {
                    errors.append("Failed to organize \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            errors.append("Failed to read directory: \(error.localizedDescription)")
        }
        
        return FileOrganizerResults(
            filesOrganized: filesOrganized,
            filesArchived: 0,
            filesScanned: filesScanned,
            oldestFileDate: oldestFileDate,
            errors: errors
        )
    }
    
    private func categorizeFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "svg", "webp":
            return "Images"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm":
            return "Videos"
        case "mp3", "wav", "aac", "flac", "m4a", "ogg":
            return "Audio"
        case "pdf", "doc", "docx", "txt", "rtf", "odt", "pages":
            return "Documents"
        case "zip", "rar", "7z", "tar", "gz", "dmg", "pkg":
            return "Archives"
        case "app":
            return "Applications"
        case "xls", "xlsx", "csv", "numbers":
            return "Spreadsheets"
        case "ppt", "pptx", "key":
            return "Presentations"
        case "swift", "py", "js", "ts", "java", "cpp", "c", "h", "m":
            return "Code"
        default:
            return "Other"
        }
    }
    
    private func uniqueURL(for url: URL) -> URL {
        var finalURL = url
        var counter = 1
        
        while fileManager.fileExists(atPath: finalURL.path) {
            let nameWithoutExt = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newName = "\(nameWithoutExt)_\(counter)" + (ext.isEmpty ? "" : ".\(ext)")
            finalURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }
        
        return finalURL
    }
}