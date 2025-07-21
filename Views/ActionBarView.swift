import SwiftUI

struct ActionBarView: View {
    let selectedCount: Int
    let selectedSize: Int64
    let onMove: () -> Void
    let onRename: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void
    let onCollab: () -> Void
    let onArchive: () -> Void
    
    @State private var showCollabModal = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 16) {
                // Selection info
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(selectedCount) files selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("(\(formatBytes(selectedSize)))")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    ActionButton(
                        icon: "folder.fill",
                        label: "Move",
                        color: Color(hex: "C3E4FF"),
                        textColor: .black
                    ) {
                        print("Move clicked")
                        onMove()
                    }
                    
                    ActionButton(
                        icon: "pencil",
                        label: "Rename",
                        color: Color(hex: "D8C6FF"),
                        textColor: .black
                    ) {
                        print("Rename clicked")
                        onRename()
                    }
                    
                    ActionButton(
                        icon: "square.and.arrow.up",
                        label: "Share",
                        color: Color(hex: "C4F1D4"),
                        textColor: .black
                    ) {
                        print("Share clicked")
                        onShare()
                    }
                    
                    ActionButton(
                        icon: "star.fill",
                        label: "Favorite",
                        color: Color(hex: "FFE6A7"),
                        textColor: .black
                    ) {
                        print("Favorite clicked")
                        onFavorite()
                    }
                    
                    ActionButton(
                        icon: "person.2.fill",
                        label: "Collab",
                        color: Color(hex: "FAD0DE"),
                        textColor: .black
                    ) {
                        print("Collab clicked")
                        showCollabModal = true
                    }
                    
                    ActionButton(
                        icon: "archivebox.fill",
                        label: "Archive",
                        color: Color.black,
                        textColor: .white
                    ) {
                        print("Archive clicked")
                        onArchive()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: selectedCount > 0)
        .sheet(isPresented: $showCollabModal) {
            CollabModalView()
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let textColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: isHovered ? color.opacity(0.3) : Color.clear, radius: 4, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct CollabModalView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Cute icon
            ZStack {
                Circle()
                    .fill(Color(hex: "FAD0DE"))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                Text("Want to share this with your team?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("TeamSai makes collaboration magical! ✨")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Invite via TeamSai") {
                    print("Invite via TeamSai")
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "2a2a2a"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hex: "FAD0DE"))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}