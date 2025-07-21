# Klinmai Source Code - Key Files for Performance Analysis

## 1. SmartArchiveManager.swift (File Scanning Logic)

```swift
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
}
```

## 2. CompactArchiveView.swift (Main UI with Performance Issues)

```swift
// Video player that recreates on every hover
struct CompactArchiveCandidateRow: View {
    let candidate: ArchiveCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isLoadingThumbnail = false
    @State private var isPlaying = false
    @State private var audioPlayer: AVPlayer?
    @State private var videoPlayer: AVPlayer?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // ... UI code ...
        }
        .onHover { hovering in
            isHovering = hovering
            if candidate.type == .video {
                if hovering {
                    playVideo() // PERFORMANCE ISSUE: Creates new player every hover
                } else {
                    stopVideo()
                }
            }
        }
    }
    
    private func playVideo() {
        if videoPlayer == nil {
            videoPlayer = AVPlayer(url: candidate.url) // EXPENSIVE OPERATION
            videoPlayer?.isMuted = true
        }
        videoPlayer?.seek(to: CMTime.zero)
        videoPlayer?.play()
        isPlaying = true
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        isLoadingThumbnail = true
        
        Task {
            await generateThumbnail()
        }
    }
    
    @MainActor
    private func generateThumbnail() async {
        let size = CGSize(width: 80, height: 80)
        let request = QLThumbnailGenerator.Request(
            fileAt: candidate.url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )
        
        Task.detached(priority: .background) {
            do {
                // PERFORMANCE ISSUE: No caching, regenerates every time
                let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                await MainActor.run {
                    self.thumbnail = thumbnail.nsImage
                    self.isLoadingThumbnail = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingThumbnail = false
                }
            }
        }
    }
}

// Grid view with similar issues
struct CompactArchiveCandidateGridItem: View {
    // Similar video and thumbnail loading issues
    // No virtualization for large lists
}
```

## 3. Main View Structure (CompactArchiveView.swift)

```swift
struct CompactArchiveView: View {
    @StateObject private var archiveManager = SmartArchiveManager()
    @StateObject private var smartCleanManager = SmartCleanManager()
    @State private var selectedCandidates = Set<UUID>()
    @State private var isScanning = false
    @State private var monthsThreshold = 1
    @State private var sizeThresholdMB = 10
    
    var filteredAndSortedCandidates: [ArchiveCandidate] {
        var candidates = archiveManager.candidates
        // Filtering and sorting logic
        return candidates
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top controls
            
            // File list - PERFORMANCE ISSUE: LazyVStack still loads all thumbnails
            ScrollView {
                if isGridView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                        ForEach(filteredAndSortedCandidates) { candidate in
                            CompactArchiveCandidateGridItem(
                                candidate: candidate,
                                // ... props
                            )
                        }
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredAndSortedCandidates) { candidate in
                            CompactArchiveCandidateRow(
                                candidate: candidate,
                                // ... props
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            if !hasScannedOnAppear {
                hasScannedOnAppear = true
                Task {
                    await scanForCandidates() // Initial scan is slow
                }
            }
        }
    }
}
```

## 4. Package.swift Configuration

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Klinmai",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Klinmai",
            targets: ["Klinmai"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Klinmai",
            path: ".",
            exclude: ["Info.plist", "Klinmai.entitlements"],
            sources: [
                "KlinmaiApp.swift",
                "SmartCareEngine.swift",
                "FileOrganizer.swift",
                "DuplicateScanner.swift",
                "SystemCleaner.swift",
                "MailAndTrashCleaner.swift",
                "LLMHandler.swift",
                "ConsoleView.swift",
                "SmartArchiveManager.swift",
                "ProjectDetector.swift",
                "CopyMascot.swift",
                "SmartCleanManager.swift",
                "Views/SmartCareView.swift",
                "Views/ArchiveView.swift",
                "Views/CompactArchiveView.swift",
                "Views/ProjectsView.swift",
                "Views/MascotImage.swift",
                "Views/MascotImageLoader.swift",
                "Views/FilePreviewView.swift",
                "Views/ActionBarView.swift",
                "Views/SmartSuggestionsView.swift",
                "Views/iCloudArchiveModal.swift"
            ]
        )
    ]
)
```

## Key Performance Bottlenecks

1. **No Caching System**
   - Thumbnails regenerated on every view
   - Video players recreated on every hover
   - File metadata scanned repeatedly

2. **Synchronous Operations**
   - iCloud status checks block scanning
   - Large file enumeration blocks UI
   - No pagination or virtualization

3. **Memory Leaks**
   - Video players never released
   - Thumbnails accumulate in memory
   - No resource cleanup

4. **Inefficient Data Flow**
   - Full re-renders on filter changes
   - No debouncing for rapid actions
   - Entire file list sorted on every update

## What We Need

1. **Persistent Caching**
   - SQLite or Core Data for file metadata
   - Disk cache for thumbnails
   - Video preview frame extraction

2. **Better Architecture**
   - Virtualized scrolling
   - Resource pooling for video players
   - Background processing queue

3. **Performance Optimizations**
   - Lazy loading with proper windowing
   - Debounced operations
   - Incremental updates

Please help us architect a solution that can handle 10,000+ files smoothly!