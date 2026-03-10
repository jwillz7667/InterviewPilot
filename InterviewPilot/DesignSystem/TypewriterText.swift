import SwiftUI

struct TypewriterText: View {
    let fullText: String
    let speed: Double

    @State private var displayedText = ""
    @State private var currentIndex = 0

    init(_ text: String, speed: Double = 0.02) {
        self.fullText = text
        self.speed = speed
    }

    var body: some View {
        Text(displayedText)
            .onChange(of: fullText) {
                displayedText = fullText
            }
            .onAppear {
                displayedText = fullText
            }
    }
}
