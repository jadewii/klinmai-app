import SwiftUI

// Preview of how the app icon will look
struct AppIconPreview: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("App Icon Preview")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            HStack(spacing: 40) {
                // Small icon (32x32)
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .frame(width: 32, height: 32)
                        
                        MascotImage(size: 28)
                    }
                    Text("32x32")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Medium icon (128x128)
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .frame(width: 128, height: 128)
                        
                        MascotImage(size: 110)
                    }
                    Text("128x128")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Large icon (256x256)
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.black)
                            .frame(width: 256, height: 256)
                        
                        MascotImage(size: 220)
                    }
                    Text("256x256")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Text("Perfect for macOS dock!")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
    }
}

// Alternative button style with pure black circle
struct CleanButtonAlternative: View {
    @State private var isHovering = false
    @State private var isScanning = false
    
    var body: some View {
        Button(action: {
            withAnimation {
                isScanning.toggle()
            }
        }) {
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(0.8),
                                Color.red.opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 20)
                
                // Main button
                VStack(spacing: 0) {
                    // Top half - black circle with mascot
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 200, height: 200)
                        
                        MascotImage(size: 180)
                            .rotationEffect(.degrees(isScanning ? 360 : 0))
                            .animation(
                                isScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                                value: isScanning
                            )
                    }
                    .offset(y: 40)
                    
                    // Text below
                    Text("CLEAN MY\nCOMPUTER")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: -30)
                }
                .frame(width: 200, height: 200)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.2, blue: 0.3),
                                    Color(red: 0.8, green: 0.1, blue: 0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            }
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovering = hovering
            }
        }
    }
}