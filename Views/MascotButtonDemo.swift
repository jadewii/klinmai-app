import SwiftUI

// Demo view showing both mascot button options
struct MascotButtonDemo: View {
    @State private var isHoveringA = false
    @State private var isHoveringB = false
    @State private var isScanningA = false
    @State private var isScanningB = false
    
    var body: some View {
        VStack(spacing: 50) {
            Text("Mascot Button Options")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            HStack(spacing: 50) {
                // Option A: Mascot above text
                VStack {
                    Text("Option A: Mascot Above Text")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: {
                        withAnimation {
                            isScanningA.toggle()
                        }
                    }) {
                        ZStack {
                            // Glow effect
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
                            ZStack {
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
                                    .shadow(color: .red.opacity(0.5), radius: isHoveringA ? 20 : 10)
                                
                                VStack(spacing: 10) {
                                    Image("KlinmaiMascot")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .rotationEffect(.degrees(isScanningA ? 360 : 0))
                                        .scaleEffect(isHoveringA ? 1.1 : 1.0)
                                        .animation(
                                            isScanningA ? .linear(duration: 2).repeatForever(autoreverses: false) : .spring(response: 0.3),
                                            value: isScanningA
                                        )
                                        .animation(.spring(response: 0.3), value: isHoveringA)
                                    
                                    Text("CLEAN MY\nCOMPUTER")
                                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                                }
                                
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            }
                            .frame(width: 200, height: 200)
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3)) {
                            isHoveringA = hovering
                        }
                    }
                }
                
                // Option B: Mascot behind text
                VStack {
                    Text("Option B: Mascot Behind Text")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: {
                        withAnimation {
                            isScanningB.toggle()
                        }
                    }) {
                        ZStack {
                            // Glow effect
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
                            ZStack {
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
                                    .shadow(color: .red.opacity(0.5), radius: isHoveringB ? 20 : 10)
                                
                                // Mascot behind text
                                Image("KlinmaiMascot")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 140, height: 140)
                                    .opacity(0.3)
                                    .rotationEffect(.degrees(isScanningB ? 360 : 0))
                                    .animation(
                                        isScanningB ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                                        value: isScanningB
                                    )
                                
                                // Text on top
                                Text("CLEAN MY\nCOMPUTER")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                                
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            }
                            .frame(width: 200, height: 200)
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3)) {
                            isHoveringB = hovering
                        }
                    }
                }
            }
            
            Text("Click buttons to test animation")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.4, green: 0.2, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// Preview
struct MascotButtonDemo_Previews: PreviewProvider {
    static var previews: some View {
        MascotButtonDemo()
    }
}