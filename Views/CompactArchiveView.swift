import SwiftUI

// Import the necessary files
// Note: These would normally be imported via the app's module

struct CompactArchiveView: View {
    @StateObject private var archiveManager = SmartArchiveManager()
    @StateObject private var smartCleanManager = SmartCleanManager()
    @State private var selectedCandidates = Set<UUID>()
    @State private var isScanning = false
    @State private var monthsThreshold = 1
    @State private var sizeThresholdMB = 10
    @State private var hasScannedOnAppear = false
    @State private var sortOption: SortOption = .size
    @State private var filterType: ArchiveCandidate.FileType? = nil
    @State private var isGridView = false
    @State private var showSmartSuggestions = false
    @State private var suggestionsJustGenerated = false
    @State private var iCloudFilter: iCloudFilterOption = .all
    @State private var showiCloudArchiveModal = false
    @State private var pendingArchiveFiles: [ArchiveCandidate] = []
    
    enum iCloudFilterOption: String, CaseIterable {
        case all = "All"
        case iCloudOnly = "iCloud"
        case localOnly = "Local"
        case notDownloaded = "Not Downloaded"
    }
    
    enum SortOption: String, CaseIterable {
        case size = "Size"
        case age = "Age"
        case name = "Name"
        case type = "Type"
    }
    
    var filteredAndSortedCandidates: [ArchiveCandidate] {
        var candidates = archiveManager.candidates
        
        // Apply iCloud filter
        switch iCloudFilter {
        case .all:
            break // Show all
        case .iCloudOnly:
            candidates = candidates.filter { $0.iCloudStatus != .notIniCloud }
        case .localOnly:
            candidates = candidates.filter { $0.iCloudStatus == .notIniCloud }
        case .notDownloaded:
            candidates = candidates.filter { 
                if case .notDownloaded = $0.iCloudStatus { return true }
                if case .downloading = $0.iCloudStatus { return true }
                return false
            }
        }
        
        // Apply type filter
        if let filterType = filterType {
            candidates = candidates.filter { $0.type == filterType }
        }
        
        // Apply sort
        switch sortOption {
        case .size:
            return candidates.sorted { $0.size > $1.size }
        case .age:
            return candidates.sorted { $0.lastModified < $1.lastModified }
        case .name:
            return candidates.sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
        case .type:
            return candidates.sorted { $0.type.rawValue < $1.type.rawValue }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact top bar with all controls
            VStack(alignment: .leading, spacing: 12) {
                // First row: Sort and filter types
                HStack(spacing: 12) {
                    // Sort buttons (non-expanding)
                    HStack(spacing: 6) {
                        FilterButton(title: "Size", icon: "arrow.up.arrow.down", isSelected: sortOption == .size) {
                            sortOption = .size
                        }
                        FilterButton(title: "Age", icon: "clock", isSelected: sortOption == .age) {
                            sortOption = .age
                        }
                        FilterButton(title: "Name", icon: "textformat", isSelected: sortOption == .name) {
                            sortOption = .name
                        }
                        FilterButton(title: "Type", icon: "square.grid.2x2", isSelected: sortOption == .type) {
                            sortOption = .type
                        }
                    }
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color.white.opacity(0.2))
                    
                    // Filter type buttons
                    HStack(spacing: 6) {
                        FilterButton(title: "All Types", isSelected: filterType == nil) {
                            filterType = nil
                        }
                        FilterButton(title: "Videos", icon: "video.fill", isSelected: filterType == .video) {
                            filterType = .video
                        }
                        FilterButton(title: "Audio", icon: "music.note", isSelected: filterType == .audio) {
                            filterType = .audio
                        }
                        FilterButton(title: "Images", icon: "photo", isSelected: filterType == .image) {
                            filterType = .image
                        }
                        FilterButton(title: "GIFs", icon: "photo.on.rectangle", isSelected: filterType == .gif) {
                            filterType = .gif
                        }
                        FilterButton(title: "Documents", icon: "doc.fill", isSelected: filterType == .document) {
                            filterType = .document
                        }
                    }
                    
                    Spacer()
                    
                    // iCloud filter menu
                    Menu {
                        ForEach(iCloudFilterOption.allCases, id: \.self) { option in
                            Button(action: {
                                iCloudFilter = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if iCloudFilter == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "icloud")
                                .font(.system(size: 11))
                            Text("\(iCloudFilter.rawValue) Files")
                                .font(.system(size: 11))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .fixedSize()
                    
                    // Results count
                    if !archiveManager.candidates.isEmpty {
                        Text("\(filteredAndSortedCandidates.count)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                        + Text(" of \(archiveManager.candidates.count) files")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Second row: Age/Size sliders and scan button
                HStack(spacing: 20) {
                    // Age slider
                    HStack {
                        Text("Files older than")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Slider(value: Binding(
                            get: { Double(monthsThreshold) },
                            set: { monthsThreshold = Int($0) }
                        ), in: 1...24, step: 1)
                        .frame(width: 120)
                        Text("\(monthsThreshold) months")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 60)
                    }
                    
                    // Size slider
                    HStack {
                        Text("Files larger than")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Slider(value: Binding(
                            get: { Double(sizeThresholdMB) },
                            set: { sizeThresholdMB = Int($0) }
                        ), in: 50...5000, step: 50)
                        .frame(width: 120)
                        Text("\(sizeThresholdMB) MB")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 60)
                    }
                    
                    // View toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isGridView.toggle()
                        }
                    }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.3x3")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isGridView ? "Switch to List View" : "Switch to Grid View")
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Smart suggestions lightbulb button
                        if !smartCleanManager.suggestions.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSmartSuggestions.toggle()
                            }
                        }) {
                            ZStack {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(suggestionsJustGenerated ? .yellow : .white)
                                    .scaleEffect(suggestionsJustGenerated ? 1.1 : 1.0)
                                
                                // Badge for suggestion count
                                if !showSmartSuggestions {
                                    Text("\(smartCleanManager.suggestions.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(2)
                                        .background(Circle().fill(Color.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(showSmartSuggestions ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Smart suggestions (\(smartCleanManager.suggestions.count))")
                        .onAppear {
                            if suggestionsJustGenerated {
                                // Briefly show suggestions then collapse
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSmartSuggestions = false
                                        suggestionsJustGenerated = false
                                    }
                                }
                            }
                        }
                    }
                    
                    // Scan button
                    Button(action: {
                        Task {
                            await scanForCandidates()
                        }
                    }) {
                        Label("Scan", systemImage: "magnifyingglass")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "f29dd3"), Color(hex: "f29dd3").opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            
            // Smart suggestions
            if showSmartSuggestions && !smartCleanManager.suggestions.isEmpty {
                SmartSuggestionsView(
                    smartCleanManager: smartCleanManager,
                    onApplySuggestion: { suggestion in
                        applySuggestion(suggestion)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // File list and stats
            HStack(alignment: .top, spacing: 0) {
                // Main file list
                VStack(alignment: .leading, spacing: 10) {
                    // List header
                    HStack {
                        if isScanning && archiveManager.candidates.isEmpty {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Scanning...")
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Text("\(filteredAndSortedCandidates.count) files")
                                .font(.headline)
                                .foregroundColor(.white)
                            if isScanning {
                                Text("(scanning...)")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text("(\(formatBytes(filteredTotalSize)) total)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Button("Select All") {
                            selectedCandidates = Set(filteredAndSortedCandidates.map { $0.id })
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                        
                        Button("Deselect All") {
                            selectedCandidates.removeAll()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    
                    // File list or grid
                    ScrollView {
                        if isGridView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                                ForEach(filteredAndSortedCandidates) { candidate in
                                    SimplifiedArchiveGridItem(
                                        candidate: candidate,
                                        isSelected: selectedCandidates.contains(candidate.id),
                                        onToggle: {
                                            if selectedCandidates.contains(candidate.id) {
                                                selectedCandidates.remove(candidate.id)
                                            } else {
                                                selectedCandidates.insert(candidate.id)
                                            }
                                        },
                                        onDelete: {
                                            archiveManager.candidates.removeAll { $0.id == candidate.id }
                                            selectedCandidates.remove(candidate.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredAndSortedCandidates) { candidate in
                                    SimplifiedArchiveRow(
                                        candidate: candidate,
                                        isSelected: selectedCandidates.contains(candidate.id),
                                        onToggle: {
                                            if selectedCandidates.contains(candidate.id) {
                                                selectedCandidates.remove(candidate.id)
                                            } else {
                                                selectedCandidates.insert(candidate.id)
                                            }
                                        },
                                        onDelete: {
                                            archiveManager.candidates.removeAll { $0.id == candidate.id }
                                            selectedCandidates.remove(candidate.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Action bar at the bottom
            if !selectedCandidates.isEmpty {
                ActionBarView(
                    selectedCount: selectedCandidates.count,
                    selectedSize: selectedSize,
                    onMove: {
                        // TODO: Implement move functionality
                    },
                    onRename: {
                        // TODO: Implement rename functionality
                    },
                    onShare: {
                        // TODO: Implement share functionality
                    },
                    onFavorite: {
                        // TODO: Implement favorite functionality
                    },
                    onCollab: {
                        // Handled by ActionBarView internally
                    },
                    onArchive: {
                        Task {
                            await archiveSelected()
                        }
                    }
                )
            }
        }
        .onAppear {
            if !hasScannedOnAppear {
                hasScannedOnAppear = true
                Task {
                    await scanForCandidates()
                }
            }
        }
        .sheet(isPresented: $showiCloudArchiveModal) {
            iCloudArchiveModal(
                filesToArchive: pendingArchiveFiles,
                onConfirm: {
                    await performArchive(pendingArchiveFiles)
                }
            )
        }
    }
    
    
    // Helper methods...
    private var filteredTotalSize: Int64 {
        filteredAndSortedCandidates.reduce(0) { $0 + $1.size }
    }
    
    private var selectedSize: Int64 {
        archiveManager.candidates
            .filter { selectedCandidates.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }
    
    private func scanForCandidates() async {
        isScanning = true
        selectedCandidates.removeAll()
        await archiveManager.scanForArchiveCandidates(
            olderThanMonths: monthsThreshold,
            largerThanMB: sizeThresholdMB
        )
        isScanning = false
        
        // Run smart analysis after scan
        if !archiveManager.candidates.isEmpty {
            await smartCleanManager.analyzeFiles(archiveManager.candidates)
            if !smartCleanManager.suggestions.isEmpty {
                showSmartSuggestions = true
                suggestionsJustGenerated = true
            }
        }
    }
    
    private func archiveSelected() async {
        let toArchive = archiveManager.candidates.filter { selectedCandidates.contains($0.id) }
        
        // Check if any files are in iCloud
        let iCloudFiles = toArchive.filter { $0.iCloudStatus != .notIniCloud }
        
        if !iCloudFiles.isEmpty {
            // Show confirmation modal
            pendingArchiveFiles = toArchive
            showiCloudArchiveModal = true
        } else {
            // No iCloud files, proceed normally
            await performArchive(toArchive)
        }
    }
    
    private func performArchive(_ files: [ArchiveCandidate]) async {
        let _ = await archiveManager.archiveSelected(files)
        
        archiveManager.candidates.removeAll { candidate in
            files.contains { $0.id == candidate.id }
        }
        selectedCandidates.removeAll()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func applySuggestion(_ suggestion: SmartSuggestion) {
        switch suggestion.action {
        case .archiveFiles:
            // Add files to selection and trigger archive
            let affectedIds = archiveManager.candidates
                .filter { candidate in suggestion.affectedFiles.contains(candidate.url) }
                .map { $0.id }
            selectedCandidates = Set(affectedIds)
            Task {
                await archiveSelected()
            }
            
        case .groupIntoFolder(let folderName):
            print("TODO: Group files into folder: \(folderName)")
            // Implementation would create folder and move files
            
        case .keepNewest:
            print("TODO: Keep only newest version of duplicates")
            // Implementation would delete older versions
            
        case .moveToProject(let projectName):
            print("TODO: Move to project: \(projectName)")
            print("💡 This would work great with Projemai!")
            
        case .deleteEmpty:
            print("TODO: Delete empty files")
            // Implementation would delete empty files
            
        case .createSequence(let sequenceName):
            print("TODO: Create sequence: \(sequenceName)")
            // Implementation would organize into sequence folder
        }
        
        // Remove applied suggestion
        smartCleanManager.suggestions.removeAll { $0.id == suggestion.id }
    }
}

// Compact filter button
struct FilterButton: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 60)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.black : Color(hex: "f29dd3").opacity(0.6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// New row component with inline thumbnails
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
    @State private var showDeleteConfirmation = false
    @State private var isHovering = false
    
    private var ageText: String {
        let days = Calendar.current.dateComponents([.day], from: candidate.lastModified, to: Date()).day ?? 0
        if days < 30 {
            return "\(days) days old"
        } else if days < 365 {
            return "\(days / 30) months old"
        } else {
            return "\(days / 365) years old"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(CheckboxToggleStyle())
            
            // Thumbnail view
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                if candidate.type == .video && isPlaying && videoPlayer != nil {
                    // Show video player in list
                    VideoPlayerView(player: videoPlayer!)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            Group {
                                if candidate.type == .audio {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 2)
                                }
                            }
                        )
                } else if isLoadingThumbnail {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.5)
                } else {
                    if candidate.type == .audio {
                        // Pink background with white music note
                        ZStack {
                            Circle()
                                .fill(Color(hex: "f29dd3"))
                                .frame(width: 30, height: 30)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 10, weight: .medium))
                                Image(systemName: "music.note")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: iconForType(candidate.type))
                            .foregroundColor(colorForType(candidate.type))
                            .font(.system(size: 20))
                    }
                }
            }
            .onTapGesture {
                if candidate.type == .audio {
                    toggleAudioPlayback()
                }
            }
            .onHover { hovering in
                isHovering = hovering
                if candidate.type == .video {
                    if hovering {
                        playVideo()
                    } else {
                        stopVideo()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.url.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // iCloud status icon
                    if !candidate.iCloudStatus.icon.isEmpty {
                        Text(candidate.iCloudStatus.icon)
                            .font(.caption)
                    }
                    
                    Text(ArchiveView.formatPath(candidate.url))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBytes(candidate.size))
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                
                Text(ageText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Trash button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Delete this file")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
        )
        .onAppear {
            loadThumbnail()
        }
        .alert("Delete File?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteFile()
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(candidate.url.lastPathComponent)\"? This action cannot be undone.")
        }
        .onDisappear {
            // Clean up audio playback
            audioPlayer?.pause()
            // Clean up video playback
            videoPlayer?.pause()
            videoPlayer = nil
        }
    }
    
    private func iconForType(_ type: ArchiveCandidate.FileType) -> String {
        switch type {
        case .video: return "video.fill"
        case .audio: return "music.note"
        case .image: return "photo"
        case .gif: return "photo.on.rectangle"
        case .document: return "doc.fill"
        case .archive: return "archivebox"
        case .project: return "folder.fill"
        case .other: return "doc"
        }
    }
    
    private func colorForType(_ type: ArchiveCandidate.FileType) -> Color {
        switch type {
        case .video: return .purple
        case .audio: return Color(hex: "f29dd3")
        case .image: return .green
        case .gif: return .teal
        case .document: return .blue
        case .archive: return .orange
        case .project: return .yellow
        case .other: return .gray
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        // Don't generate thumbnails for audio files - always use custom pink design
        if candidate.type == .audio {
            return
        }
        
        isLoadingThumbnail = true
        
        Task {
            await generateThumbnail()
        }
    }
    
    @MainActor
    private func generateThumbnail() async {
        let size = CGSize(width: 80, height: 80)  // Good quality for list view
        let request = QLThumbnailGenerator.Request(
            fileAt: candidate.url,
            size: size,
            scale: 2.0, // Higher scale for retina
            representationTypes: .thumbnail
        )
        
        Task.detached(priority: .background) {
            do {
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
    
    private func toggleAudioPlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            if audioPlayer == nil {
                audioPlayer = AVPlayer(url: candidate.url)
            }
            audioPlayer?.play()
            isPlaying = true
            
            // Monitor playback completion
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: audioPlayer?.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                audioPlayer?.seek(to: .zero)
            }
        }
    }
    
    private func playVideo() {
        if videoPlayer == nil {
            videoPlayer = AVPlayer(url: candidate.url)
            videoPlayer?.isMuted = true // Mute by default for better performance
        }
        videoPlayer?.seek(to: CMTime.zero)
        videoPlayer?.play()
        isPlaying = true
    }
    
    private func stopVideo() {
        videoPlayer?.pause()
        videoPlayer?.seek(to: CMTime.zero)
        isPlaying = false
    }
    
    private func deleteFile() {
        do {
            try FileManager.default.removeItem(at: candidate.url)
            // File deleted successfully - notify parent view
            onDelete()
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}


// Simple inline video player view without controls
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = CALayer()
        view.layer?.addSublayer(playerLayer)
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Grid item view for gallery mode
struct CompactArchiveCandidateGridItem: View {
    let candidate: ArchiveCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: NSImage?
    @State private var isLoadingThumbnail = false
    @State private var showDeleteConfirmation = false
    @State private var isPlaying = false
    @State private var audioPlayer: AVPlayer?
    @State private var videoPlayer: AVPlayer?
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with checkbox overlay
            ZStack(alignment: .topLeading) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 119)
                    
                    if candidate.type == .video && isPlaying && videoPlayer != nil {
                        // Show video player
                        VideoPlayerView(player: videoPlayer!)
                            .frame(width: .infinity, height: 119)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let thumb = thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: .infinity, height: 119)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Group {
                                    if candidate.type == .audio {
                                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 31)) // 36 * 0.85 = 30.6
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 4)
                                    }
                                }
                            )
                    } else if isLoadingThumbnail {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        if candidate.type == .audio {
                            ZStack {
                                // Solid pink background like in the reference
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "f29dd3"))
                                
                                // White music note with lines on pink background
                                HStack(spacing: 4) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 20, weight: .medium))
                                    Image(systemName: "music.note")
                                        .font(.system(size: 28, weight: .medium))
                                }
                                .foregroundColor(.white)
                            }
                        } else {
                            Image(systemName: iconForType(candidate.type))
                                .font(.system(size: 34)) // 40 * 0.85 = 34
                                .foregroundColor(colorForType(candidate.type))
                        }
                    }
                }
                .onTapGesture {
                    if candidate.type == .audio {
                        toggleAudioPlayback()
                    } else {
                        onToggle()
                    }
                }
                .onHover { hovering in
                    isHovering = hovering
                    if candidate.type == .video {
                        if hovering {
                            playVideo()
                        } else {
                            stopVideo()
                        }
                    }
                }
                
                // Checkbox
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(CheckboxToggleStyle())
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .padding(4)
                )
                
                // Delete button  
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.8))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(8)
                    }
                    Spacer()
                }
            }
            
            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium)) // 12 * 0.85 = 10.2
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text(formatBytes(candidate.size))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if !candidate.iCloudStatus.icon.isEmpty {
                        Text(candidate.iCloudStatus.icon)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
        )
        .onAppear {
            loadThumbnail()
        }
        .alert("Delete File?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteFile()
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(candidate.url.lastPathComponent)\"?")
        }
        .onDisappear {
            // Clean up audio playback
            audioPlayer?.pause()
            // Clean up video playback
            videoPlayer?.pause()
            videoPlayer = nil
        }
    }
    
    private func iconForType(_ type: ArchiveCandidate.FileType) -> String {
        switch type {
        case .video: return "video.fill"
        case .audio: return "music.note"
        case .image: return "photo"
        case .gif: return "photo.on.rectangle"
        case .document: return "doc.fill"
        case .archive: return "archivebox"
        case .project: return "folder.fill"
        case .other: return "doc"
        }
    }
    
    private func colorForType(_ type: ArchiveCandidate.FileType) -> Color {
        switch type {
        case .video: return .purple
        case .audio: return Color(hex: "f29dd3")
        case .image: return .green
        case .gif: return .teal
        case .document: return .blue
        case .archive: return .orange
        case .project: return .yellow
        case .other: return .gray
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        // Don't generate thumbnails for audio files - always use custom pink design
        if candidate.type == .audio {
            return
        }
        
        isLoadingThumbnail = true
        
        Task {
            await generateThumbnail()
        }
    }
    
    @MainActor
    private func generateThumbnail() async {
        let size = CGSize(width: 240, height: 240) // Higher resolution for crisp thumbnails
        let request = QLThumbnailGenerator.Request(
            fileAt: candidate.url,
            size: size,
            scale: 2.0, // Higher scale for retina displays
            representationTypes: .thumbnail
        )
        
        Task.detached(priority: .background) {
            do {
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
    
    private func deleteFile() {
        do {
            try FileManager.default.removeItem(at: candidate.url)
            onDelete()
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    private func toggleAudioPlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            if audioPlayer == nil {
                audioPlayer = AVPlayer(url: candidate.url)
            }
            audioPlayer?.play()
            isPlaying = true
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: audioPlayer?.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                audioPlayer?.seek(to: .zero)
            }
        }
    }
    
    private func playVideo() {
        if videoPlayer == nil {
            videoPlayer = AVPlayer(url: candidate.url)
            videoPlayer?.isMuted = true // Mute by default for better performance
        }
        videoPlayer?.seek(to: CMTime.zero)
        videoPlayer?.play()
        isPlaying = true
    }
    
    private func stopVideo() {
        videoPlayer?.pause()
        videoPlayer?.seek(to: CMTime.zero)
        isPlaying = false
    }
}