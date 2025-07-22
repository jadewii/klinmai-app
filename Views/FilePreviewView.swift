import SwiftUI
import AVKit
import AVFoundation
import PDFKit
import QuickLookThumbnailing

struct FilePreviewView: View {
    let candidate: ArchiveCandidate?
    @State private var thumbnail: NSImage?
    @State private var isLoadingPreview = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with status
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("100% Offline")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // Preview area
            if let candidate = candidate {
                VStack(spacing: 8) {
                    // File preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        if isLoadingPreview {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            previewContent(for: candidate)
                        }
                    }
                    .frame(height: 200)
                    
                    // File info
                    VStack(alignment: .leading, spacing: 6) {
                        // File name
                        Text(candidate.url.lastPathComponent)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Metadata
                        HStack(spacing: 12) {
                            // Type
                            Label(candidate.type.rawValue, systemImage: iconForType(candidate.type))
                                .font(.caption)
                                .foregroundColor(colorForType(candidate.type))
                            
                            // Size
                            Text(formatBytes(candidate.size))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            // Age
                            Text(ageText(for: candidate.lastModified))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        // Path
                        Text(ArchiveView.formatPath(candidate.url))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .onAppear {
                    loadPreview(for: candidate)
                }
                .onChange(of: candidate.id) { _ in
                    loadPreview(for: candidate)
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.2))
                    
                    Text("Select a file to preview")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxHeight: .infinity)
            }
            
            Spacer()
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private func previewContent(for candidate: ArchiveCandidate) -> some View {
        switch candidate.type {
        case .image, .gif:
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
            } else {
                imagePreviewPlaceholder
            }
            
        case .video:
            if let thumb = thumbnail {
                ZStack {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                    
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            } else {
                videoPreviewPlaceholder
            }
            
        case .audio:
            audioPreviewPlaceholder
            
        case .document:
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
            } else {
                documentPreviewPlaceholder
            }
            
        case .archive, .project, .other:
            genericPreviewPlaceholder(for: candidate.type)
        }
    }
    
    private var imagePreviewPlaceholder: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxHeight: 180)
    }
    
    private var videoPreviewPlaceholder: some View {
        VStack {
            Image(systemName: "video")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxHeight: 180)
    }
    
    private var audioPreviewPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "f29dd3").opacity(0.5))
            
            Text("Audio File")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxHeight: 180)
    }
    
    private var documentPreviewPlaceholder: some View {
        VStack {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxHeight: 180)
    }
    
    private func genericPreviewPlaceholder(for type: ArchiveCandidate.FileType) -> some View {
        VStack(spacing: 12) {
            Image(systemName: iconForType(type))
                .font(.system(size: 48))
                .foregroundColor(colorForType(type).opacity(0.5))
            
            Text(type.rawValue)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxHeight: 180)
    }
    
    private func loadPreview(for candidate: ArchiveCandidate) {
        isLoadingPreview = true
        thumbnail = nil
        
        Task {
            switch candidate.type {
            case .image, .gif:
                await loadImagePreview(from: candidate.url)
            case .video:
                await loadVideoThumbnail(from: candidate.url)
            case .document:
                if candidate.url.pathExtension.lowercased() == "pdf" {
                    await loadPDFPreview(from: candidate.url)
                } else {
                    await loadQuickLookThumbnail(from: candidate.url)
                }
            case .audio:
                // Audio files show placeholder with metadata
                isLoadingPreview = false
            default:
                await loadQuickLookThumbnail(from: candidate.url)
            }
        }
    }
    
    @MainActor
    private func loadImagePreview(from url: URL) async {
        guard let loadedImage = NSImage(contentsOf: url) else {
            isLoadingPreview = false
            return
        }
        
        // Resize if too large
        let maxSize: CGFloat = 400
        if loadedImage.size.width > maxSize || loadedImage.size.height > maxSize {
            thumbnail = loadedImage.resized(to: NSSize(width: maxSize, height: maxSize))
        } else {
            thumbnail = loadedImage
        }
        
        isLoadingPreview = false
    }
    
    @MainActor
    private func loadVideoThumbnail(from url: URL) async {
        // For performance, just use QuickLook for video thumbnails
        // It's much faster and doesn't load the entire video
        await loadQuickLookThumbnail(from: url)
    }
    
    @MainActor
    private func loadPDFPreview(from url: URL) async {
        // Just use QuickLook for PDFs - it works reliably
        await loadQuickLookThumbnail(from: url)
    }
    
    @MainActor
    private func loadQuickLookThumbnail(from url: URL) async {
        let size = CGSize(width: 256, height: 256)  // Smaller size for speed
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 1.0,
            representationTypes: .thumbnail  // Use thumbnail representation type
        )
        
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            self.thumbnail = NSImage(cgImage: representation.cgImage, size: size)
        } catch {
            // Thumbnail generation failed - that's ok
        }
        isLoadingPreview = false
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
    
    private func ageText(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 30 {
            return "\(days)d old"
        } else if days < 365 {
            return "\(days / 30)mo old"
        } else {
            return "\(days / 365)y old"
        }
    }
}

// Extension to resize NSImage
extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
}
