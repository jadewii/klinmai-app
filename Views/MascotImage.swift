import SwiftUI

// Helper view that provides fallback when mascot image is not available
struct MascotImage: View {
    let size: CGFloat
    @AppStorage("useCustomMascot") private var useCustomMascot = true
    
    var body: some View {
        if useCustomMascot {
            // Try to load from file system first
            MascotImageLoader(size: size)
        } else if let _ = NSImage(named: "KlinmaiMascot") {
            // Then try from assets
            Image("KlinmaiMascot")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Fallback to emoji when image not found
            Text("🦕")
                .font(.system(size: size * 0.8))
        }
    }
}

// Extension to check if image exists
extension NSImage {
    convenience init?(namedIfExists name: String) {
        if NSImage(named: name) != nil {
            self.init(named: name)
        } else {
            return nil
        }
    }
}