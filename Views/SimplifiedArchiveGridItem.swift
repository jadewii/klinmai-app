import SwiftUI

struct SimplifiedArchiveGridItem: View {
    let candidate: ArchiveCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    @State private var showUpgradePrompt = false
    
    private var shouldShowUpgradePrompt: Bool {
        return candidate.type == .image || candidate.type == .gif || candidate.type == .video
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon and checkbox
            ZStack(alignment: .topLeading) {
                // File type icon centered
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 80)
                    
                    VStack(spacing: 4) {
                        Image(systemName: iconForType(candidate.type))
                            .font(.system(size: 32))
                            .foregroundColor(colorForType(candidate.type))
                        
                        Text(candidate.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
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
                    .font(.system(size: 11, weight: .medium))
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
            
            // Upgrade prompt for media files
            if shouldShowUpgradePrompt {
                Button(action: {
                    showUpgradePrompt = true
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 11))
                        Text("Open in \(candidate.type == .video ? "Audiomai" : "Imagimai")")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
        )
        .alert("Delete File?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteFile()
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(candidate.url.lastPathComponent)\"?")
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView(fileType: candidate.type)
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
    
    private func deleteFile() {
        do {
            try FileManager.default.removeItem(at: candidate.url)
            onDelete()
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}