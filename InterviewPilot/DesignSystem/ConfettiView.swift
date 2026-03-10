import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: isAnimating ? particle.finalY : particle.y)
                    .rotationEffect(.degrees(isAnimating ? particle.rotation : 0))
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .onAppear {
            generateParticles()
            withAnimation(.easeOut(duration: 2.0)) {
                isAnimating = true
            }
        }
    }

    private func generateParticles() {
        particles = (0..<30).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...8),
                x: CGFloat.random(in: -150...150),
                y: CGFloat.random(in: -20...20),
                finalY: CGFloat.random(in: 200...500),
                rotation: Double.random(in: 180...720)
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let finalY: CGFloat
    let rotation: Double
}
