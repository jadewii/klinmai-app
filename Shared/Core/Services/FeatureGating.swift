import SwiftUI

// MARK: - Feature Gating View Modifier
struct FeatureGated: ViewModifier {
    let feature: Feature
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    func body(content: Content) -> some View {
        if subscriptionManager.canAccessFeature(feature) {
            content
        } else {
            content
                .disabled(true)
                .overlay {
                    Color.black.opacity(0.6)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.largeTitle)
                                Text("Pro Feature")
                                    .fontWeight(.semibold)
                                Button("Upgrade") {
                                    showPaywall = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .foregroundColor(.white)
                        }
                        .onTapGesture {
                            showPaywall = true
                        }
                }
                .sheet(isPresented: $showPaywall) {
                    SubscriptionPaywallView()
                }
        }
    }
}

extension View {
    func requiresPro(_ feature: Feature) -> some View {
        modifier(FeatureGated(feature: feature))
    }
}

// MARK: - Usage Limit Alert
struct UsageLimitAlert: ViewModifier {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    let onUpgrade: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Daily Limit Reached", isPresented: $isPresented) {
                Button("Upgrade to Pro", action: onUpgrade)
                Button("OK", role: .cancel) { }
            } message: {
                if let remaining = subscriptionManager.remainingFilesForToday() {
                    Text("You've reached your daily limit of \(subscriptionManager.freeFileLimitPerDay) files. Upgrade to Pro for unlimited cleaning!")
                }
            }
    }
}

// MARK: - Subscription Status Banner
struct SubscriptionStatusBanner: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    let onUpgrade: () -> Void
    
    var body: some View {
        if subscriptionManager.currentTier == .free {
            HStack {
                Image(systemName: "exclamationmark.circle")
                
                if let remaining = subscriptionManager.remainingFilesForToday() {
                    Text("\(remaining) files remaining today")
                } else {
                    Text("Free plan: \(subscriptionManager.freeFileLimitPerDay) files/day")
                }
                
                Spacer()
                
                Button("Upgrade") {
                    onUpgrade()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
        }
    }
}

// MARK: - Integration with existing views
extension SmartCareEngine {
    func runFullScanWithLimits() async {
        let subscriptionManager = SubscriptionManager.shared
        
        // Check limits for free tier
        if subscriptionManager.currentTier == .free {
            if let remaining = subscriptionManager.remainingFilesForToday(), remaining <= 0 {
                log("⚠️ Daily limit reached. Upgrade to Pro for unlimited cleaning!", type: .warning)
                return
            }
        }
        
        // Run normal scan
        await runFullScan()
        
        // Increment usage count
        if subscriptionManager.currentTier == .free {
            subscriptionManager.incrementFileCount(totalActionsPerformed)
        }
    }
}

// MARK: - Archive View Limit
extension CompactArchiveView {
    var limitedCandidates: [ArchiveCandidate] {
        let subscriptionManager = SubscriptionManager.shared
        
        if subscriptionManager.currentTier == .free {
            return Array(filteredAndSortedCandidates.prefix(subscriptionManager.freeArchiveLimit))
        }
        
        return filteredAndSortedCandidates
    }
    
    var showUpgradePrompt: Bool {
        let subscriptionManager = SubscriptionManager.shared
        return subscriptionManager.currentTier == .free && 
               filteredAndSortedCandidates.count > subscriptionManager.freeArchiveLimit
    }
}