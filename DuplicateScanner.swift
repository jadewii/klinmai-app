import Foundation
import CryptoKit

struct DuplicateScanResults {
    let duplicatesRemoved: Int
    let spaceSaved: Int64
    let largestDuplicate: Int64?
}

class DuplicateScanner {
    private let fileManager = FileManager.default
    
    func findAndRemoveDuplicates() async -> DuplicateScanResults {
        var hashToFiles: [String: [URL]] = [:]
        var totalSpaceSaved: Int64 = 0
        var duplicatesRemoved = 0
        
        // Directories to scan
        let directoriesToScan = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
        ]
        
        // First pass: build hash map
        for directory in directoriesToScan {
            let directoryHashes = await scanDirectory(directory)
            for (hash, urls) in directoryHashes {
                hashToFiles[hash, default: []].append(contentsOf: urls)
            }
        }
        
        // Second pass: remove duplicates
        for (_, files) in hashToFiles where files.count > 1 {
            // Sort by modification date, keep the oldest
            let sortedFiles = files.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // Remove all but the first (oldest) file
            for fileURL in sortedFiles.dropFirst() {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    try fileManager.trashItem(at: fileURL, resultingItemURL: nil)
                    totalSpaceSaved += fileSize
                    duplicatesRemoved += 1
                } catch {
                    // Continue with next file if this one fails
                    continue
                }
            }
        }
        
        return DuplicateScanResults(
            duplicatesRemoved: duplicatesRemoved,
            spaceSaved: totalSpaceSaved,
            largestDuplicate: nil // We'll update this in the removal loop
        )
    }
    
    private func scanDirectory(_ directory: URL) async -> [String: [URL]] {
        // First, gather all files synchronously
        let filesToHash = await Task.detached {
            var files: [URL] = []
            
            guard let enumerator = self.fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return files
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    
                    guard attributes.isRegularFile == true,
                          let fileSize = attributes.fileSize,
                          fileSize > 1024 // Skip files smaller than 1KB
                    else { continue }
                    
                    // Skip certain file types that shouldn't be deduplicated
                    let ext = fileURL.pathExtension.lowercased()
                    let skipExtensions = ["db", "sqlite", "plist", "lock", "tmp"]
                    if skipExtensions.contains(ext) { continue }
                    
                    files.append(fileURL)
                } catch {
                    continue
                }
            }
            
            return files
        }.value
        
        // Then hash files asynchronously
        var localHashMap: [String: [URL]] = [:]
        for fileURL in filesToHash {
            if let hash = await hashFile(at: fileURL) {
                localHashMap[hash, default: []].append(fileURL)
            }
        }
        
        return localHashMap
    }
    
    private func hashFile(at url: URL) async -> String? {
        do {
            let data = try Data(contentsOf: url)
            
            // For large files, only hash first and last chunks
            if data.count > 10_000_000 { // 10MB
                let chunkSize = 1_000_000 // 1MB
                let firstChunk = data.prefix(chunkSize)
                let lastChunk = data.suffix(chunkSize)
                let combined = firstChunk + lastChunk
                
                let hash = SHA256.hash(data: combined)
                return hash.compactMap { String(format: "%02x", $0) }.joined()
            } else {
                let hash = SHA256.hash(data: data)
                return hash.compactMap { String(format: "%02x", $0) }.joined()
            }
        } catch {
            return nil
        }
    }
}