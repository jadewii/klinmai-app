import SwiftUI
import QuickLookThumbnailing

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
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 7), spacing: 16) {
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