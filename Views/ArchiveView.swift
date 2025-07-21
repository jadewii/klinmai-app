import SwiftUI

struct ArchiveView: View {
    @StateObject private var archiveManager = SmartArchiveManager()
    @State private var selectedCandidates = Set<UUID>()
    @State private var isScanning = false
    @State private var monthsThreshold = 6
    @State private var sizeThresholdMB = 500
    @State private var hasScannedOnAppear = false
    @State private var sortOption: SortOption = .size
    @State private var filterType: ArchiveCandidate.FileType? = nil
    @State private var selectedPreviewCandidate: ArchiveCandidate? = nil
    
    enum SortOption: String, CaseIterable {
        case size = "Size"
        case age = "Age"
        case name = "Name"
        case type = "Type"
    }
    
    var filteredAndSortedCandidates: [ArchiveCandidate] {
        var candidates = archiveManager.candidates
        
        // Apply filter
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
            // Top section with controls and preview
            HStack(alignment: .top, spacing: 16) {
                // Left side: Controls
                VStack(alignment: .leading, spacing: 12) {
                    // Sort and Filter Bar
                    HStack(spacing: 12) {
                        // Sort Picker
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 12))
                            Picker("Sort by", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.1))
                        )
                    
                    // Filter Buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // All Types button
                            Button(action: {
                                filterType = nil
                            }) {
                                Text("All Types")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(filterType == nil ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(filterType == nil ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            // Individual type buttons
                            ForEach(ArchiveCandidate.FileType.allCases, id: \.self) { type in
                                Button(action: {
                                    filterType = type
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: iconForType(type))
                                            .font(.system(size: 12))
                                        Text(type.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(filterType == type ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(filterType == type ? colorForType(type).opacity(0.3) : Color.white.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Results count
                    if !archiveManager.candidates.isEmpty {
                        HStack(spacing: 4) {
                            Text("\(filteredAndSortedCandidates.count)")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                            Text("of \(archiveManager.candidates.count) files")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                            if filterType != nil {
                                Text("• Filtered")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                
                HStack(spacing: 30) {
                    // Age slider
                    VStack(alignment: .leading) {
                        Text("Files older than")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        HStack {
                            Slider(value: Binding(
                                get: { Double(monthsThreshold) },
                                set: { monthsThreshold = Int($0) }
                            ), in: 1...24, step: 1)
                            .frame(width: 150)
                            
                            Text("\(monthsThreshold) months")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 80)
                        }
                    }
                    
                    // Size slider
                    VStack(alignment: .leading) {
                        Text("Files larger than")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        HStack {
                            Slider(value: Binding(
                                get: { Double(sizeThresholdMB) },
                                set: { sizeThresholdMB = Int($0) }
                            ), in: 50...5000, step: 50)
                            .frame(width: 150)
                            
                            Text("\(sizeThresholdMB) MB")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 80)
                        }
                    }
                    
                    Spacer()
                    
                    // Scan button
                    Button(action: {
                        Task {
                            await scanForCandidates()
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Scan")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.ultraThinMaterial)
                )
                
                if isScanning {
                    VStack(spacing: 8) {
                        ProgressView("Scanning for archive candidates...", value: archiveManager.scanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .opacity(archiveManager.isiCloudDriveAvailable() ? 1 : 0.3)
                            
                            Text(archiveManager.isiCloudDriveAvailable() ? "Including iCloud Drive" : "iCloud Drive not available")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            
            // Results list
            if !archiveManager.candidates.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(filteredAndSortedCandidates.count) files")
                            .font(.headline)
                            .foregroundColor(.white)
                        
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
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredAndSortedCandidates) { candidate in
                                ArchiveCandidateRow(
                                    candidate: candidate,
                                    isSelected: selectedCandidates.contains(candidate.id),
                                    isPreviewSelected: selectedPreviewCandidate?.id == candidate.id,
                                    onToggle: {
                                        if selectedCandidates.contains(candidate.id) {
                                            selectedCandidates.remove(candidate.id)
                                        } else {
                                            selectedCandidates.insert(candidate.id)
                                        }
                                    },
                                    onTap: {
                                        selectedPreviewCandidate = candidate
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
                
                // Archive button
                if !selectedCandidates.isEmpty {
                    Button(action: {
                        Task {
                            await archiveSelected()
                        }
                    }) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Archive \(selectedCandidates.count) files")
                            Text("(\(formatBytes(selectedSize)))")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            } else if !isScanning {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No archive candidates found")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Adjust the filters and scan to find old or large files")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxHeight: .infinity)
            }
            }
            .onAppear {
                // Auto-scan when view appears (only once)
                if !hasScannedOnAppear {
                    hasScannedOnAppear = true
                    Task {
                        await scanForCandidates()
                    }
                }
            }
            
            // Preview panel on the right
            FilePreviewView(candidate: selectedPreviewCandidate)
                .padding(.trailing, 16)
        }
        .padding(.top, 16)
    }
    
    private var totalSize: Int64 {
        archiveManager.candidates.reduce(0) { $0 + $1.size }
    }
    
    private var filteredTotalSize: Int64 {
        filteredAndSortedCandidates.reduce(0) { $0 + $1.size }
    }
    
    private var selectedSize: Int64 {
        archiveManager.candidates
            .filter { selectedCandidates.contains($0.id) }
            .reduce(0) { $0 + $1.size }
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
    
    private func scanForCandidates() async {
        isScanning = true
        selectedCandidates.removeAll()
        selectedPreviewCandidate = nil
        await archiveManager.scanForArchiveCandidates(
            olderThanMonths: monthsThreshold,
            largerThanMB: sizeThresholdMB
        )
        isScanning = false
    }
    
    private func archiveSelected() async {
        let toArchive = archiveManager.candidates.filter { selectedCandidates.contains($0.id) }
        let _ = await archiveManager.archiveSelected(toArchive)
        
        // Remove archived files from list
        archiveManager.candidates.removeAll { candidate in
            selectedCandidates.contains(candidate.id)
        }
        selectedCandidates.removeAll()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    static func formatPath(_ url: URL) -> String {
        let path = url.deletingLastPathComponent().path
        
        // Simplify iCloud paths
        if path.contains("Mobile Documents/com~apple~CloudDocs") {
            let simplified = path.replacingOccurrences(
                of: NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs",
                with: "iCloud Drive"
            )
            return simplified
        }
        
        // Simplify home directory paths
        if path.starts(with: NSHomeDirectory()) {
            return path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
        
        return path
    }
}

struct ArchiveCandidateRow: View {
    let candidate: ArchiveCandidate
    let isSelected: Bool
    let isPreviewSelected: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    
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
        HStack {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(CheckboxToggleStyle())
            
            Image(systemName: iconForType(candidate.type))
                .foregroundColor(colorForType(candidate.type))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.url.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if candidate.url.path.contains("Mobile Documents/com~apple~CloudDocs") {
                        Image(systemName: "icloud")
                            .font(.caption)
                            .foregroundColor(.blue)
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
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isPreviewSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onTap()
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
}