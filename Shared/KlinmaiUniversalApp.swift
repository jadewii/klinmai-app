import SwiftUI

@main
struct KlinmaiUniversalApp: App {
    @StateObject private var smartCare = SmartCareEngine()
    @StateObject private var llmHandler = LLMHandler()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            MacContentView()
                .environmentObject(smartCare)
                .environmentObject(llmHandler)
                .environmentObject(subscriptionManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            MacSettingsView()
                .environmentObject(smartCare)
                .environmentObject(subscriptionManager)
        }
        
        #elseif os(iOS)
        WindowGroup {
            iOSContentView()
                .environmentObject(smartCare)
                .environmentObject(llmHandler)
                .environmentObject(subscriptionManager)
        }
        
        #elseif os(watchOS)
        WindowGroup {
            WatchContentView()
                .environmentObject(smartCare)
                .environmentObject(subscriptionManager)
        }
        #endif
    }
}

// MARK: - Platform-Specific Content Views

#if os(macOS)
struct MacContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false
    
    var body: some View {
        ContentView() // Your existing macOS view
            .overlay(alignment: .topTrailing) {
                if subscriptionManager.currentTier == .free {
                    SubscriptionBadge()
                        .padding()
                        .onTapGesture {
                            showPaywall = true
                        }
                }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
                    .frame(width: 600, height: 700)
            }
    }
}

struct MacSettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title)
            
            GroupBox("Subscription") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Plan:")
                        Text(subscriptionManager.currentTier.displayName)
                            .fontWeight(.semibold)
                    }
                    
                    if let expiration = subscriptionManager.expirationDate {
                        HStack {
                            Text("Expires:")
                            Text(expiration, style: .date)
                        }
                    }
                    
                    if subscriptionManager.currentTier == .free {
                        Button("Upgrade to Pro") {
                            // Open paywall
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}
#endif

#if os(iOS)
struct iOSContentView: View {
    @EnvironmentObject var smartCare: SmartCareEngine
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab = 0
    @State private var showPaywall = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SmartCareViewiOS()
                .tabItem {
                    Label("Clean", systemImage: "sparkles")
                }
                .tag(0)
            
            ArchiveViewiOS()
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }
                .tag(1)
            
            DesktopOrganizerViewiOS()
                .tabItem {
                    Label("Desktop", systemImage: "desktopcomputer")
                }
                .tag(2)
            
            ProjectsViewiOS()
                .tabItem {
                    Label("Projects", systemImage: "folder.badge.gearshape")
                }
                .tag(3)
                .overlay {
                    if subscriptionManager.currentTier == .free {
                        LockedFeatureOverlay {
                            showPaywall = true
                        }
                    }
                }
            
            SettingsViewiOS()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
    }
}

struct SmartCareViewiOS: View {
    @EnvironmentObject var smartCare: SmartCareEngine
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isScanning = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Remaining files indicator for free tier
                    if let remaining = subscriptionManager.remainingFilesForToday() {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                            Text("\(remaining) files remaining today")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                    }
                    
                    // Big clean button
                    Button(action: {
                        Task {
                            if subscriptionManager.canAccessFeature(.unlimitedCleaning) ||
                               (subscriptionManager.remainingFilesForToday() ?? 0) > 0 {
                                await smartCare.runFullScan()
                            }
                        }
                    }) {
                        VStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                            Text("Clean My Device")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(width: 200, height: 200)
                        .background(Color(hex: "f29dd3"))
                        .clipShape(Circle())
                    }
                    .disabled(isScanning || (subscriptionManager.remainingFilesForToday() ?? 1) == 0)
                    
                    // Quick actions
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        QuickActionCard(title: "Desktop", icon: "desktopcomputer", action: {})
                        QuickActionCard(title: "Downloads", icon: "arrow.down.circle", action: {})
                        QuickActionCard(title: "Duplicates", icon: "doc.on.doc", action: {})
                        QuickActionCard(title: "System", icon: "gearshape.2", action: {})
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Klinmai")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
#endif

#if os(watchOS)
struct WatchContentView: View {
    @EnvironmentObject var smartCare: SmartCareEngine
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Subscription status
                    HStack {
                        Image(systemName: subscriptionManager.currentTier == .pro ? "crown.fill" : "crown")
                            .foregroundColor(.yellow)
                        Text(subscriptionManager.currentTier.displayName)
                            .font(.caption)
                    }
                    
                    // Quick stats
                    VStack(alignment: .leading, spacing: 8) {
                        StatRow(label: "Files Cleaned", value: "\(smartCare.totalActionsPerformed)")
                        StatRow(label: "Space Saved", value: formatBytes(smartCare.spaceSaved))
                        
                        if let remaining = subscriptionManager.remainingFilesForToday() {
                            StatRow(label: "Remaining Today", value: "\(remaining)")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Simple action button
                    Button(action: {
                        // Trigger cleaning on paired device
                    }) {
                        Label("Clean Now", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "f29dd3"))
                }
                .padding()
            }
            .navigationTitle("Klinmai")
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
#endif

// MARK: - Shared Components

struct SubscriptionBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown")
            Text("Upgrade")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "f29dd3"))
        .foregroundColor(.white)
        .cornerRadius(20)
    }
}

struct LockedFeatureOverlay: View {
    let action: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                Text("Pro Feature")
                    .font(.title2)
                    .fontWeight(.semibold)
                Button("Unlock with Pro", action: action)
                    .buttonStyle(.borderedProminent)
            }
            .foregroundColor(.white)
        }
        .ignoresSafeArea()
    }
}

// Platform-specific adaptive views would go here...
struct ArchiveViewiOS: View {
    var body: some View {
        Text("Archive View - iOS")
    }
}

struct DesktopOrganizerViewiOS: View {
    var body: some View {
        Text("Desktop Organizer - iOS")
    }
}

struct ProjectsViewiOS: View {
    var body: some View {
        Text("Projects - iOS")
    }
}

struct SettingsViewiOS: View {
    var body: some View {
        Text("Settings - iOS")
    }
}