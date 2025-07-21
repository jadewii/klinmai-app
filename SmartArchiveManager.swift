import Foundation

struct ArchiveCandidate: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let lastModified: Date
    let type: FileType
    let iCloudStatus: iCloudStatus
    
    enum iCloudStatus: Equatable {
        case notIniCloud
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        
        var icon: String {
            switch self {
            case .notIniCloud: return ""
            case .notDownloaded: return "☁️"
            case .downloading: return "⬇️"
            case .downloaded: return "✅"
            }
        }
        
        var description: String {
            switch self {
            case .notIniCloud: return "Local"
            case .notDownloaded: return "In iCloud"
            case .downloading(let progress): return "Downloading \(Int(progress * 100))%"
            case .downloaded: return "Downloaded"
            }
        }
    }
    
    enum FileType: String, CaseIterable {
        case video = "Videos"
        case audio = "Audio"
        case image = "Images"
        case gif = "GIFs"
        case document = "Documents"
        case archive = "Archives"
        case project = "Projects"
        case other = "Other"
    }
}

struct ArchiveResults {
    let filesArchived: Int
    let spaceSaved: Int64
    let largestFile: (name: String, size: Int64)?
}

@MainActor
class SmartArchiveManager: ObservableObject {
    @Published var candidates: [ArchiveCandidate] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var partialResultsCount = 0
    
    private let fileManager = FileManager.default
    private let archiveBaseURL: URL
    private var scanTask: Task<Void, Never>?
    private var lastScanDate: Date?
    private var cachedCandidates: [ArchiveCandidate] = []
    
    init() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.archiveBaseURL = documentsURL.appendingPathComponent("Archive")
    }
    
    func scanForArchiveCandidates(olderThanMonths: Int = 6, largerThanMB: Int = 500) async {
        // Cancel any existing scan
        scanTask?.cancel()
        
        // Use cached results if available and recent (within 30 seconds)
        if let lastScan = lastScanDate, 
           Date().timeIntervalSince(lastScan) < 30,
           !cachedCandidates.isEmpty {
            await MainActor.run {
                candidates = cachedCandidates
                partialResultsCount = candidates.count
            }
        }
        
        await MainActor.run {
            isScanning = true
            if candidates.isEmpty {
                candidates.removeAll()
            }
            scanProgress = 0
            partialResultsCount = candidates.count
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -olderThanMonths, to: Date())!
        let sizeThreshold = Int64(largerThanMB) * 1_048_576 // Convert MB to bytes
        
        // Order directories by likelihood of having relevant files
        var directoriesToScan = [
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first!
        ]
        
        // Add iCloud Drive if available
        if let iCloudURL = getiCloudDriveURL() {
            directoriesToScan.append(iCloudURL)
        }
        
        scanTask = Task {
            // Process directories in order of likely importance
            for (index, directory) in directoriesToScan.enumerated() {
                if Task.isCancelled { break }
                
                let results = await self.scanDirectory(
                    directory,
                    cutoffDate: cutoffDate,
                    sizeThreshold: sizeThreshold
                )
                
                if !results.isEmpty {
                    await MainActor.run {
                        // Add results immediately and sort
                        self.candidates.append(contentsOf: results)
                        self.candidates.sort { $0.size > $1.size }
                        self.partialResultsCount = self.candidates.count
                        self.scanProgress = Double(index + 1) / Double(directoriesToScan.count)
                    }
                }
            }
            
            await MainActor.run {
                self.isScanning = false
                self.lastScanDate = Date()
                self.cachedCandidates = self.candidates
            }
        }
    }
    
    // Check if iCloud Drive is available
    @MainActor
    func isiCloudDriveAvailable() -> Bool {
        if let iCloudURL = getiCloudDriveURL() {
            return FileManager.default.fileExists(atPath: iCloudURL.path)
        }
        return false
    }
    
    // Get iCloud Drive URL
    private func getiCloudDriveURL() -> URL? {
        // Method 1: Direct path (most reliable for iCloud Drive)
        let iCloudPath = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs"
        let iCloudURL = URL(fileURLWithPath: iCloudPath)
        
        if fileManager.fileExists(atPath: iCloudURL.path) {
            return iCloudURL
        }
        
        // Method 2: Using FileManager (for custom containers)
        if let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            return ubiquityURL
        }
        
        return nil
    }
    
    private func scanDirectory(_ directory: URL, cutoffDate: Date, sizeThreshold: Int64) async -> [ArchiveCandidate] {
        let localCandidates = await Task.detached { [weak self] in
            guard let self = self else { return [ArchiveCandidate]() }
            
            var candidates: [ArchiveCandidate] = []
            let fm = FileManager.default
            
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey, 
                    .fileSizeKey, 
                    .contentModificationDateKey,
                    .ubiquitousItemDownloadingStatusKey,
                    .ubiquitousItemIsDownloadingKey
                ],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return candidates
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                // Skip if already in archive
                if fileURL.path.contains("/Archive/") { continue }
                
                do {
                    let attributes = try fileURL.resourceValues(forKeys: [
                        .isRegularFileKey, 
                        .fileSizeKey, 
                        .contentModificationDateKey, 
                        .ubiquitousItemDownloadingStatusKey,
                        .ubiquitousItemIsDownloadingKey
                    ])
                    
                    guard attributes.isRegularFile == true,
                          let fileSize = attributes.fileSize,
                          let modDate = attributes.contentModificationDate else { continue }
                    
                    // Don't skip iCloud files anymore - we'll show them all with status
                    
                    // Check if file meets criteria
                    if fileSize > sizeThreshold || modDate < cutoffDate {
                        // Get file type without calling main-actor method
                        let ext = fileURL.pathExtension.lowercased()
                        let type = self.getFileType(for: ext)
                        
                        // Check iCloud status
                        let iCloudStatus = await self.checkiCloudStatus(for: fileURL, attributes: attributes)
                        
                        let candidate = ArchiveCandidate(
                            url: fileURL,
                            size: Int64(fileSize),
                            lastModified: modDate,
                            type: type,
                            iCloudStatus: iCloudStatus
                        )
                        candidates.append(candidate)
                    }
                } catch {
                    continue
                }
            }
            
            return candidates
        }.value
        
        return localCandidates
    }
    
    // Non-MainActor version of categorizeFile
    nonisolated private func getFileType(for ext: String) -> ArchiveCandidate.FileType {
        switch ext {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return .video
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff":
            return .audio
        case "gif":
            return .gif
        case "jpg", "jpeg", "png", "heic", "tiff", "bmp", "svg", "webp", "raw":
            return .image
        case "pdf", "doc", "docx", "txt", "rtf", "odt", "pages", "md":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "dmg", "pkg", "iso":
            return .archive
        default:
            return .other
        }
    }
    
    func archiveSelected(_ candidates: [ArchiveCandidate]) async -> ArchiveResults {
        var filesArchived = 0
        var totalSpace: Int64 = 0
        var largestFile: (String, Int64)?
        
        for candidate in candidates {
            do {
                // Create archive subdirectory based on type and date
                let yearMonth = formatYearMonth(candidate.lastModified)
                let archiveDir = archiveBaseURL
                    .appendingPathComponent(candidate.type.rawValue)
                    .appendingPathComponent(yearMonth)
                
                try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
                
                let destURL = archiveDir.appendingPathComponent(candidate.url.lastPathComponent)
                let finalURL = uniqueURL(for: destURL)
                
                try fileManager.moveItem(at: candidate.url, to: finalURL)
                
                filesArchived += 1
                totalSpace += candidate.size
                
                if largestFile == nil || candidate.size > largestFile!.1 {
                    largestFile = (candidate.url.lastPathComponent, candidate.size)
                }
                
            } catch {
                // Skip files that can't be archived
                continue
            }
        }
        
        return ArchiveResults(
            filesArchived: filesArchived,
            spaceSaved: totalSpace,
            largestFile: largestFile
        )
    }
    
    private func categorizeFile(_ url: URL) -> ArchiveCandidate.FileType {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v":
            return .video
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff":
            return .audio
        case "gif":
            return .gif
        case "jpg", "jpeg", "png", "heic", "tiff", "bmp", "svg", "webp", "raw":
            return .image
        case "pdf", "doc", "docx", "txt", "rtf", "odt", "pages", "md":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "dmg", "pkg", "iso":
            return .archive
        default:
            return .other
        }
    }
    
    private func formatYearMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
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
    
    // Check iCloud status for a file
    @MainActor
    private func checkiCloudStatus(for url: URL, attributes: URLResourceValues) -> ArchiveCandidate.iCloudStatus {
        // Check if file is in iCloud path
        if !url.path.contains("Mobile Documents/com~apple~CloudDocs") {
            return .notIniCloud
        }
        
        // Check download status
        if let downloadStatus = attributes.ubiquitousItemDownloadingStatus {
            switch downloadStatus {
            case .current:
                return .downloaded
            case .downloaded:
                return .downloaded
            case .notDownloaded:
                return .notDownloaded
            default:
                // Check if downloading
                if let isDownloading = attributes.ubiquitousItemIsDownloading, isDownloading {
                    return .downloading(progress: 0.5) // Default to 50% when downloading
                }
                return .notDownloaded
            }
        }
        
        return .notDownloaded
    }
}