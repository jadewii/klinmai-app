import Foundation
import SwiftUI

struct TrashCleanResults {
    let spaceSaved: Int64
}

class MailAndTrashCleaner {
    private let fileManager = FileManager.default
    
    func emptyAllTrash() async -> TrashCleanResults {
        var totalSpaceSaved: Int64 = 0
        
        // Empty main system trash
        totalSpaceSaved += await emptySystemTrash()
        
        // Empty app-specific trash locations
        totalSpaceSaved += await emptyAppTrash()
        
        return TrashCleanResults(spaceSaved: totalSpaceSaved)
    }
    
    private func emptySystemTrash() async -> Int64 {
        var spaceSaved: Int64 = 0
        
        // Get trash size before emptying
        if let trashURL = try? fileManager.url(
            for: .trashDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            spaceSaved = await Task { calculateDirectorySize(trashURL) }.value
            
            // Empty trash using NSWorkspace
            await Task { @MainActor in
                NSWorkspace.shared.recycle([])
            }.value
        }
        
        return spaceSaved
    }
    
    private func emptyAppTrash() async -> Int64 {
        var spaceSaved: Int64 = 0
        
        // Common app trash locations
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let appTrashPaths = [
                "Caches/com.apple.Photos/Trash",
                "Caches/com.apple.iMovieApp/Trash",
                "Mail/V9/MailData/Deleted Messages.mbox"
            ]
            
            for path in appTrashPaths {
                let trashURL = libraryURL.appendingPathComponent(path)
                if fileManager.fileExists(atPath: trashURL.path) {
                    let size = calculateDirectorySize(trashURL)
                    do {
                        try fileManager.removeItem(at: trashURL)
                        spaceSaved += size
                    } catch {
                        // Skip if we can't remove
                    }
                }
            }
        }
        
        return spaceSaved
    }
    
    func cleanMailAttachments() async -> Int64 {
        var spaceSaved: Int64 = 0
        
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let mailDownloadsURL = libraryURL.appendingPathComponent("Mail/V9/MailData/Attachments")
            
            if fileManager.fileExists(atPath: mailDownloadsURL.path) {
                do {
                    let attachments = try fileManager.contentsOfDirectory(
                        at: mailDownloadsURL,
                        includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey]
                    )
                    
                    let cutoffDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
                    
                    for attachment in attachments {
                        do {
                            let attributes = try attachment.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
                            
                            if let accessDate = attributes.contentAccessDate,
                               accessDate < cutoffDate {
                                let size = Int64(attributes.fileSize ?? 0)
                                try fileManager.removeItem(at: attachment)
                                spaceSaved += size
                            }
                        } catch {
                            continue
                        }
                    }
                } catch {
                    // Skip if we can't access mail attachments
                }
            }
        }
        
        return spaceSaved
    }
    
    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            do {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(attributes.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return totalSize
    }
}