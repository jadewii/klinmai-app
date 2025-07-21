import SwiftUI

struct ProjectsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Project Detection")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.8))
            
            Text("🦕 Coming soon: AI-powered project folder detection")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Text("I'll intelligently detect and organize your creative projects")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClutterView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Clutter Scanner")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.8))
            
            Text("🦕 Coming soon: Deep clutter analysis")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Find and eliminate the biggest space wasters on your Mac")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PerformanceView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "speedometer")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Performance Tools")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.8))
            
            Text("🦕 Coming soon: System optimization tools")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Flush DNS, reindex Spotlight, and manage startup items")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}