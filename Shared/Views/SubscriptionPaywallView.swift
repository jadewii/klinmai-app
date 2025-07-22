import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        #if os(iOS) || os(visionOS)
        NavigationView {
            content
                .navigationTitle("Upgrade to Pro")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        #else
        content
        #endif
    }
    
    var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "f29dd3"))
                    
                    Text("Unlock Klinmai Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Clean smarter, organize better")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Features comparison
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "doc.fill",
                        title: "Unlimited Cleaning",
                        freeText: "100 files/day",
                        proText: "Unlimited"
                    )
                    
                    FeatureRow(
                        icon: "archivebox.fill",
                        title: "Archive Access",
                        freeText: "50 files",
                        proText: "Unlimited"
                    )
                    
                    FeatureRow(
                        icon: "folder.badge.gearshape",
                        title: "Project Detection",
                        freeText: "Basic",
                        proText: "Advanced + GitHub"
                    )
                    
                    FeatureRow(
                        icon: "brain",
                        title: "Smart Organization",
                        freeText: "Basic",
                        proText: "AI-Powered"
                    )
                }
                .padding(.horizontal)
                
                // Subscription options
                VStack(spacing: 12) {
                    ForEach(subscriptionManager.products.sorted(by: { $0.price < $1.price })) { product in
                        SubscriptionOptionView(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            onSelect: { selectedProduct = product }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Purchase button
                Button(action: purchase) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Subscribe Now")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "f29dd3"))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(selectedProduct == nil || isPurchasing)
                .padding(.horizontal)
                
                // Restore button
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .foregroundColor(.secondary)
                
                // Terms
                VStack(spacing: 8) {
                    Text("Subscriptions auto-renew. Cancel anytime.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: URL(string: "https://klinmai.app/terms")!)
                        Link("Privacy Policy", destination: URL(string: "https://klinmai.app/privacy")!)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func purchase() {
        guard let product = selectedProduct else { return }
        
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            
            do {
                try await subscriptionManager.purchase(product)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let freeText: String
    let proText: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: "f29dd3"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                HStack(spacing: 20) {
                    Label(freeText, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(proText, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var savings: String? {
        if product.id.contains("yearly") {
            return "Save 17%"
        }
        return nil
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .fontWeight(.medium)
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .fontWeight(.semibold)
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "f29dd3").opacity(0.1) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "f29dd3") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}