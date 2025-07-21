import SwiftUI

// View that loads mascot from a file path on your Mac
struct MascotImageLoader: View {
    let size: CGFloat
    @State private var mascotImage: NSImage?
    
    // Use the app's Application Support directory to avoid permission issues
    private var imagePaths: [String] {
        [
            // Primary path in app's directory (no permissions needed)
            MascotHelper.getMascotPath(),
            // Fallback to original location
            NSHomeDirectory() + "/Documents/Desktop_Cleaned/Images/klinmai.png",
            // Other fallback paths
            NSHomeDirectory() + "/Desktop/klinmai.png",
            NSHomeDirectory() + "/Downloads/klinmai.png"
        ]
    }
    
    var body: some View {
        Group {
            if let mascotImage = mascotImage {
                Image(nsImage: mascotImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                // Fallback to emoji
                Text("🦕")
                    .font(.system(size: size * 0.8))
            }
        }
        .onAppear {
            // First try to set up the mascot in app directory
            MascotHelper.setupMascot()
            // Then load it
            loadMascotImage()
        }
    }
    
    private func loadMascotImage() {
        // Try to load from multiple paths
        for path in imagePaths {
            if FileManager.default.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path) {
                mascotImage = image
                print("✅ Loaded mascot from: \(path)")
                return
            }
        }
        print("⚠️ Could not find mascot image in any of these locations:")
        imagePaths.forEach { print("  - \($0)") }
    }
}

// Alternative: Let user choose the image file
struct MascotImagePicker: View {
    let size: CGFloat
    @State private var mascotImage: NSImage?
    @AppStorage("klinmaiMascotPath") private var savedImagePath = ""
    
    var body: some View {
        Group {
            if let mascotImage = mascotImage {
                Image(nsImage: mascotImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .onTapGesture {
                        selectNewImage()
                    }
            } else {
                Button(action: selectNewImage) {
                    VStack {
                        Text("🦕")
                            .font(.system(size: size * 0.6))
                        Text("Click to choose mascot")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            loadSavedImage()
        }
    }
    
    private func loadSavedImage() {
        if !savedImagePath.isEmpty,
           FileManager.default.fileExists(atPath: savedImagePath),
           let image = NSImage(contentsOfFile: savedImagePath) {
            mascotImage = image
        }
    }
    
    private func selectNewImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose your Klinmai mascot image"
        panel.showsResizeIndicator = true
        panel.showsHiddenFiles = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif]
        
        if panel.runModal() == .OK,
           let url = panel.url,
           let image = NSImage(contentsOf: url) {
            mascotImage = image
            savedImagePath = url.path
        }
    }
}