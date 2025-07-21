import Foundation

struct SystemCleanResults {
    let filesRemoved: Int
    let spaceSaved: Int64
}

class SystemCleaner {
    private let fileManager = FileManager.default
    
    func cleanSystemJunk() async -> SystemCleanResults {
        var totalFilesRemoved = 0
        var totalSpaceSaved: Int64 = 0
        
        // Clean various cache directories
        let cacheURLs = getCacheDirectories()
        for cacheURL in cacheURLs {
            let results = await cleanDirectory(cacheURL, keepDirectory: true)
            totalFilesRemoved += results.filesRemoved
            totalSpaceSaved += results.spaceSaved
        }
        
        // Clean logs
        let logResults = await cleanLogs()
        totalFilesRemoved += logResults.filesRemoved
        totalSpaceSaved += logResults.spaceSaved
        
        // Clean temporary files
        let tempResults = await cleanTemporaryFiles()
        totalFilesRemoved += tempResults.filesRemoved
        totalSpaceSaved += tempResults.spaceSaved
        
        return SystemCleanResults(
            filesRemoved: totalFilesRemoved,
            spaceSaved: totalSpaceSaved
        )
    }
    
    private func getCacheDirectories() -> [URL] {
        var cacheURLs: [URL] = []
        
        // User Library Caches
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let cachesURL = libraryURL.appendingPathComponent("Caches")
            
            // Safe cache directories to clean
            let safeCaches = [
                "com.apple.Safari/Webpage Previews",
                "com.apple.Safari/Favicon Cache",
                "com.apple.dt.Xcode/DerivedData",
                "pip",
                "Homebrew",
                "Google/Chrome/Default/Cache",
                "Firefox/Profiles"
            ]
            
            for cache in safeCaches {
                let url = cachesURL.appendingPathComponent(cache)
                if fileManager.fileExists(atPath: url.path) {
                    cacheURLs.append(url)
                }
            }
        }
        
        return cacheURLs
    }
    
    private func cleanDirectory(_ directory: URL, keepDirectory: Bool) async -> (filesRemoved: Int, spaceSaved: Int64) {
        var filesRemoved = 0
        var spaceSaved: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
            )
            
            for item in contents {
                do {
                    let attributes = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    let size = Int64(attributes.fileSize ?? 0)
                    
                    if attributes.isDirectory == true {
                        let subResults = await cleanDirectory(item, keepDirectory: false)
                        filesRemoved += subResults.filesRemoved
                        spaceSaved += subResults.spaceSaved
                        
                        if !keepDirectory {
                            try fileManager.removeItem(at: item)
                        }
                    } else {
                        try fileManager.removeItem(at: item)
                        filesRemoved += 1
                        spaceSaved += size
                    }
                } catch {
                    // Skip files we can't remove
                    continue
                }
            }
        } catch {
            // Skip directories we can't access
        }
        
        return (filesRemoved, spaceSaved)
    }
    
    private func cleanLogs() async -> (filesRemoved: Int, spaceSaved: Int64) {
        var filesRemoved = 0
        var spaceSaved: Int64 = 0
        
        // Clean user logs
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let logsURL = libraryURL.appendingPathComponent("Logs")
            
            do {
                let logs = try fileManager.contentsOfDirectory(
                    at: logsURL,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
                )
                
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                
                for logFile in logs {
                    do {
                        let attributes = try logFile.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                        
                        if let modDate = attributes.contentModificationDate,
                           modDate < cutoffDate {
                            let size = Int64(attributes.fileSize ?? 0)
                            try fileManager.removeItem(at: logFile)
                            filesRemoved += 1
                            spaceSaved += size
                        }
                    } catch {
                        continue
                    }
                }
            } catch {
                // Skip if we can't access logs
            }
        }
        
        return (filesRemoved, spaceSaved)
    }
    
    private func cleanTemporaryFiles() async -> (filesRemoved: Int, spaceSaved: Int64) {
        var filesRemoved = 0
        var spaceSaved: Int64 = 0
        
        let tempDirectories = [
            fileManager.temporaryDirectory,
            URL(fileURLWithPath: "/var/folders", isDirectory: true),
            URL(fileURLWithPath: "/tmp", isDirectory: true)
        ]
        
        for tempDir in tempDirectories {
            guard fileManager.fileExists(atPath: tempDir.path) else { continue }
            
            do {
                let items = try fileManager.contentsOfDirectory(
                    at: tempDir,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
                )
                
                let cutoffDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
                
                for item in items {
                    do {
                        let attributes = try item.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                        
                        if let modDate = attributes.contentModificationDate,
                           modDate < cutoffDate {
                            let size = Int64(attributes.fileSize ?? 0)
                            try fileManager.removeItem(at: item)
                            filesRemoved += 1
                            spaceSaved += size
                        }
                    } catch {
                        continue
                    }
                }
            } catch {
                continue
            }
        }
        
        return (filesRemoved, spaceSaved)
    }
}