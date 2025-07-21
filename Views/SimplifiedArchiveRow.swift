import SwiftUI

struct SimplifiedArchiveRow: View {
    let candidate: ArchiveCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    @State private var showUpgradePrompt = false
    
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
    
    private var shouldShowUpgradePrompt: Bool {
        return candidate.type == .image || candidate.type == .gif || candidate.type == .video
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(CheckboxToggleStyle())
            
            // File type icon
            Image(systemName: iconForType(candidate.type))
                .font(.system(size: 20))
                .foregroundColor(colorForType(candidate.type))
                .frame(width: 30)
            
            // File info
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
            
            // Upgrade prompt for media files
            if shouldShowUpgradePrompt {
                Button(action: {
                    showUpgradePrompt = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                        Text(candidate.type == .video ? "View in Audiomai" : "View in Imagimai")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // File metadata
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
        .alert("Delete File?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteFile()
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(candidate.url.lastPathComponent)\"? This action cannot be undone.")
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

struct UpgradePromptView: View {
    let fileType: ArchiveCandidate.FileType
    @Environment(\.dismiss) var dismiss
    
    var appName: String {
        switch fileType {
        case .image, .gif: return "Imagimai"
        case .video, .audio: return "Audiomai"
        default: return ""
        }
    }
    
    var appIcon: String {
        switch fileType {
        case .image, .gif: return "photo.on.rectangle.angled"
        case .video, .audio: return "music.note.tv"
        default: return ""
        }
    }
    
    var appColor: Color {
        switch fileType {
        case .image, .gif: return Color(hex: "3d7dad")
        case .video, .audio: return Color(hex: "9b59b6")
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon
            ZStack {
                Circle()
                    .fill(appColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: appIcon)
                    .font(.system(size: 36))
                    .foregroundColor(appColor)
            }
            
            VStack(spacing: 12) {
                Text("Preview in \(appName)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(appName) is the perfect app for viewing and organizing your \(fileType.rawValue.lowercased()). Get visual previews, create collections, and more!")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button("Download \(appName)") {
                    // TODO: Open App Store or website
                    print("Download \(appName)")
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Not Now") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "2a2a2a"))
        )
    }
}