import SwiftUI
import AppKit
import QuickLookThumbnailing

struct SimplifiedArchiveGridItem: View {
    let candidate: ArchiveCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    @State private var thumbnail: NSImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail with checkbox overlay
            ZStack(alignment: .topLeading) {
                // Thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    if let thumb = thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if isLoadingThumbnail {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        // Show icon for non-previewable files
                        Image(systemName: iconForType(candidate.type))
                            .font(.system(size: 36))
                            .foregroundColor(colorForType(candidate.type))
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
                
                // Delete button (top-right)
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
                
                // Open button (bottom-left)
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            openFile()
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.25))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(8)
                        Spacer()
                    }
                }
                
                // iCloud status (bottom-right)
                if !candidate.iCloudStatus.icon.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(candidate.iCloudStatus.icon)
                                .font(.caption)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                )
                                .padding(4)
                        }
                    }
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
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 140)
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
        
        isLoadingThumbnail = true
        
        Task {
            await generateThumbnail()
        }
    }
    
    @MainActor
    private func generateThumbnail() async {
        let size = CGSize(width: 240, height: 240) // 2x for retina
        let request = QLThumbnailGenerator.Request(
            fileAt: candidate.url,
            size: size,
            scale: 2.0,
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
    
    private func openFile() {
        NSWorkspace.shared.open(candidate.url)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? Color(hex: "f29dd3") : .white.opacity(0.5))
                .font(.system(size: 20))
        }
        .buttonStyle(PlainButtonStyle())
    }
}