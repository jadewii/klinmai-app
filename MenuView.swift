import SwiftUI

struct MenuView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var organizer = NativeFileOrganizer()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.pink)
                    .font(.title2)
                
                Text("DesktopCleaner")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    showSettings()
                }) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Main action button
            Button(action: {
                Task {
                    await organizer.organizeDesktop()
                }
            }) {
                HStack {
                    if organizer.isOrganizing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundColor(.white)
                    }
                    
                    Text(organizer.isOrganizing ? "Organizing..." : "Clean Desktop Now")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.pink)
                )
            }
            .buttonStyle(.plain)
            .disabled(organizer.isOrganizing)
            
            // Status
            if organizer.lastOrganizedCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Organized \(organizer.lastOrganizedCount) files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Current method
            HStack {
                Text("Method:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(appState.organizationMethod.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Auto-clean status
            if appState.autoCleanSchedule != .never {
                HStack {
                    Text("Auto-clean:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(appState.autoCleanSchedule.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            // Quit button
            Button("Quit DesktopCleaner") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding(12)
        .frame(width: 250)
    }
    
    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Create new settings window if it doesn't exist
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "DesktopCleaner Settings"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView().environmentObject(appState))
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }
}

#Preview {
    MenuView()
        .environmentObject(AppState())
}