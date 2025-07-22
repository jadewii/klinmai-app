import Foundation
import StoreKit
import SwiftUI

// MARK: - Subscription Tiers
enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Klinmai Pro"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "Clean up to 100 files per day",
                "Basic desktop organization",
                "Archive view (limited to 50 files)",
                "Basic duplicate detection"
            ]
        case .pro:
            return [
                "Unlimited file cleaning",
                "Advanced smart organization",
                "Unlimited archive access",
                "Project folder detection",
                "GitHub integration",
                "Priority support",
                "All future features"
            ]
        }
    }
}

// MARK: - Subscription Product IDs
struct SubscriptionProducts {
    static let proMonthly = "com.jadewii.klinmai.pro.monthly"
    static let proYearly = "com.jadewii.klinmai.pro.yearly"
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var isSubscribed: Bool = false
    @Published var expirationDate: Date?
    @Published var isLoading: Bool = false
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    private var updateListenerTask: Task<Void, Error>?
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults keys
    private let kSubscriptionTier = "klinmai.subscription.tier"
    private let kSubscriptionExpiration = "klinmai.subscription.expiration"
    private let kDailyFileCount = "klinmai.daily.file.count"
    private let kDailyFileCountDate = "klinmai.daily.file.count.date"
    
    // Feature limits
    let freeFileLimitPerDay = 100
    let freeArchiveLimit = 50
    
    private init() {
        loadSubscriptionStatus()
        
        // Start listening for transactions
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                SubscriptionProducts.proMonthly,
                SubscriptionProducts.proYearly
            ])
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase Subscription
    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            
        case .userCancelled:
            throw SubscriptionError.userCancelled
            
        case .pending:
            throw SubscriptionError.pending
            
        @unknown default:
            throw SubscriptionError.unknown
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    // MARK: - Update Subscription Status
    private func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var latestExpirationDate: Date?
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    
                    if let expirationDate = transaction.expirationDate,
                       latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                        latestExpirationDate = expirationDate
                    }
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        
        isSubscribed = hasActiveSubscription
        currentTier = hasActiveSubscription ? .pro : .free
        expirationDate = latestExpirationDate
        
        saveSubscriptionStatus()
    }
    
    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Feature Access
    func canAccessFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .unlimitedCleaning:
            return currentTier == .pro
        case .advancedOrganization:
            return currentTier == .pro
        case .unlimitedArchive:
            return currentTier == .pro
        case .projectDetection:
            return currentTier == .pro
        case .githubIntegration:
            return currentTier == .pro
        }
    }
    
    func remainingFilesForToday() -> Int? {
        guard currentTier == .free else { return nil }
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastCountDate = userDefaults.object(forKey: kDailyFileCountDate) as? Date ?? Date.distantPast
        
        // Reset count if it's a new day
        if !Calendar.current.isDate(lastCountDate, inSameDayAs: today) {
            userDefaults.set(0, forKey: kDailyFileCount)
            userDefaults.set(today, forKey: kDailyFileCountDate)
        }
        
        let usedToday = userDefaults.integer(forKey: kDailyFileCount)
        return max(0, freeFileLimitPerDay - usedToday)
    }
    
    func incrementFileCount(_ count: Int = 1) {
        guard currentTier == .free else { return }
        
        let current = userDefaults.integer(forKey: kDailyFileCount)
        userDefaults.set(current + count, forKey: kDailyFileCount)
    }
    
    // MARK: - Persistence
    private func saveSubscriptionStatus() {
        userDefaults.set(currentTier.rawValue, forKey: kSubscriptionTier)
        userDefaults.set(expirationDate, forKey: kSubscriptionExpiration)
    }
    
    private func loadSubscriptionStatus() {
        if let tierString = userDefaults.string(forKey: kSubscriptionTier),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
            isSubscribed = (tier == .pro)
        }
        
        expirationDate = userDefaults.object(forKey: kSubscriptionExpiration) as? Date
        
        // Check if subscription expired
        if let expiration = expirationDate, expiration < Date() {
            currentTier = .free
            isSubscribed = false
        }
    }
}

// MARK: - Features
enum Feature {
    case unlimitedCleaning
    case advancedOrganization
    case unlimitedArchive
    case projectDetection
    case githubIntegration
}

// MARK: - Errors
enum SubscriptionError: LocalizedError {
    case userCancelled
    case pending
    case verificationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending"
        case .verificationFailed:
            return "Purchase verification failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}