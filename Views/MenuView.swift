import SwiftUI

struct MenuView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPreferences = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hare.fill")
                    .font(.title2)
                    .foregroundColor(Color.appPink)
                
                Text("Desktop Cleaner")
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            .background(Color.appPink.opacity(0.1))
            
            Divider()
            
            // Main Actions
            VStack(spacing: 8) {
                // Clean Desktop Button
                Button(action: {
                    Task {
                        await appState.cleanDesktop()
                    }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Clean Desktop Now")
                        Spacer()
                        if appState.isCleaning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle())
                .disabled(appState.isCleaning)
                
                // Undo Button (if available)
                if appState.lastCleanInfo != nil && appState.preferences.showUndoAfterClean {
                    Button(action: {
                        Task {
                            await appState.undoLastClean()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo Last Clean")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MenuButtonStyle())
                }
                
                // Status info - no toggles needed, it's all automatic!
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color.appPink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Organization Active")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Auto-cleans hourly & at 10 PM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Simple status text instead of complex preferences
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.appPink)
                    Text("Smart organization active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Quit Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuButtonStyle())
            }
            .padding(.vertical, 8)
            
            // Status Footer
            if let lastClean = appState.lastCleanInfo {
                Divider()
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.appPink)
                    Text("\(lastClean.movedFiles.count) files organized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.05))
            }
        }
        .frame(width: 320)
        .background(Color(red: 0.996, green: 0.957, blue: 0.976))
    }
}

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.appPink.opacity(0.1) : Color.clear)
            .foregroundColor(configuration.isPressed ? Color.appPink : .primary)
    }
}

struct PinkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color.appPink : Color.gray.opacity(0.3))
                .frame(width: 48, height: 28)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        configuration.isOn.toggle()
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

extension Color {
    static let appPink = Color(hex: "f29dd3")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}