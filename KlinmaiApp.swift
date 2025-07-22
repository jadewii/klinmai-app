import SwiftUI

extension Color {
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
            (a, r, g, b) = (1, 1, 1, 0)
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

@main
struct KlinmaiApp: App {
    @StateObject private var smartCare = SmartCareEngine()
    @StateObject private var llmHandler = LLMHandler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(smartCare)
                .environmentObject(llmHandler)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            SettingsView()
                .environmentObject(smartCare)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var smartCare: SmartCareEngine
    @EnvironmentObject var llmHandler: LLMHandler
    @State private var userInput = ""
    @State private var isScanning = false
    @State private var selectedTab = 1  // Default to Archive view
    @State private var buttonScale: CGFloat = 1.0
    @State private var dinoRotation: Double = 0
    @State private var isConsoleVisible = false
    @State private var consoleHeight: CGFloat = 200
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "f29dd3"),
                    Color(hex: "f29dd3").opacity(0.8),
                    Color(hex: "f29dd3").opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with animated mascot
                HeaderView(isScanning: $isScanning, dinoRotation: $dinoRotation, isConsoleVisible: $isConsoleVisible)
                    .padding()
                
                // Tab selection
                Picker("", selection: $selectedTab) {
                    Label("Smart Care", systemImage: "sparkles").tag(0)
                    Label("Archive", systemImage: "archivebox").tag(1)
                    Label("Desktop", systemImage: "desktopcomputer").tag(2)
                    Label("Projects", systemImage: "folder.badge.gearshape").tag(3)
                    Label("Clutter", systemImage: "trash.slash").tag(4)
                    Label("Performance", systemImage: "speedometer").tag(5)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // Main content area
                Group {
                    switch selectedTab {
                    case 0:
                        SmartCareView(
                            isScanning: $isScanning,
                            buttonScale: $buttonScale,
                            userInput: $userInput
                        )
                    case 1:
                        CompactArchiveView()
                    case 2:
                        DesktopOrganizerView()
                    case 3:
                        ProjectsView()
                    case 4:
                        ClutterView()
                    case 5:
                        PerformanceView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Collapsible console section
                if isConsoleVisible {
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Console with adjustable height
                    ConsoleView()
                        .environmentObject(smartCare)
                        .frame(height: consoleHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                        .padding()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(width: 1200, height: 800)
        .preferredColorScheme(.dark)
        .onChange(of: smartCare.consoleOutput.count) { newCount in
            // Auto-show console when new logs appear (if it was hidden)
            if !isConsoleVisible && newCount > 0 && smartCare.isRunning {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isConsoleVisible = true
                }
            }
        }
    }
    
    @MainActor
    private func runSmartCare() async {
        isScanning = true
        await smartCare.runFullScan()
        isScanning = false
    }
    
    @MainActor
    private func processAICommand() async {
        guard !userInput.isEmpty else { return }
        isScanning = true
        
        // Process command through local LLM
        if let action = await llmHandler.processCommand(userInput) {
            await smartCare.executeAction(action)
        }
        
        userInput = ""
        isScanning = false
    }
}

struct HeaderView: View {
    @Binding var isScanning: Bool
    @Binding var dinoRotation: Double
    @Binding var isConsoleVisible: Bool
    @State private var dinoScale: CGFloat = 1.0
    @State private var showingHeart = false
    
    var body: some View {
        HStack {
            // Animated Klinmai mascot
            ZStack {
                // Gradient circle background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.3, green: 0.8, blue: 0.6),
                                Color(red: 0.2, green: 0.6, blue: 0.8),
                                Color(red: 0.1, green: 0.4, blue: 0.6)
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 30
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .teal.opacity(0.5), radius: 10)
                
                MascotImage(size: 55)
                    .rotationEffect(.degrees(dinoRotation))
                    .scaleEffect(dinoScale)
                    .onChange(of: isScanning) { scanning in
                        if scanning {
                            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                dinoRotation = 360
                            }
                            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                dinoScale = 1.1
                            }
                        } else {
                            withAnimation {
                                dinoRotation = 0
                                dinoScale = 1.0
                            }
                            
                            // Show heart after cleaning
                            withAnimation(.spring()) {
                                showingHeart = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingHeart = false
                                }
                            }
                        }
                    }
                
                if showingHeart {
                    Text("❤️")
                        .font(.title)
                        .offset(x: 30, y: -20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Klinmai™")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Your offline AI cleaning companion")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Part of the 4 Dino Plan 🦖")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Status indicators
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("100% Offline")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if isScanning {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                        Text("Cleaning...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical, 4)
                
                // Console toggle button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isConsoleVisible.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isConsoleVisible ? "terminal.fill" : "terminal")
                            .font(.caption)
                        Text(isConsoleVisible ? "Hide Console" : "Show Console")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(isConsoleVisible ? 0.2 : 0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
            // Settings content here
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}