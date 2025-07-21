import SwiftUI

struct iCloudArchiveModal: View {
    let filesToArchive: [ArchiveCandidate]
    let onConfirm: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    
    private var iCloudFiles: [ArchiveCandidate] {
        filesToArchive.filter { $0.iCloudStatus != .notIniCloud }
    }
    
    private var notDownloadedFiles: [ArchiveCandidate] {
        filesToArchive.filter {
            if case .notDownloaded = $0.iCloudStatus { return true }
            if case .downloading = $0.iCloudStatus { return true }
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("iCloud Files Detected")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(iCloudFiles.count) of \(filesToArchive.count) files are in iCloud")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Warning message
            VStack(alignment: .leading, spacing: 12) {
                Label("Archiving will move these files out of iCloud sync", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                if !notDownloadedFiles.isEmpty {
                    Label("\(notDownloadedFiles.count) files need to be downloaded first", systemImage: "arrow.down.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // File list preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Files to archive:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(iCloudFiles.prefix(5)), id: \.id) { file in
                            HStack {
                                Text(file.iCloudStatus.icon)
                                    .font(.system(size: 12))
                                Text(file.url.lastPathComponent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                        
                        if iCloudFiles.count > 5 {
                            Text("... and \(iCloudFiles.count - 5) more")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .italic()
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: {
                    Task {
                        isProcessing = true
                        await onConfirm()
                        isProcessing = false
                        dismiss()
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text("Download & Archive")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isProcessing)
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "2a2a2a"))
        )
    }
}