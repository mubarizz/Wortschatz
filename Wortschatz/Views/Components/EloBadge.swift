import SwiftUI

public struct EloBadge: View {
    let elo: Double
    var showLabel: Bool = true
    var compact: Bool = false
    
    public init(elo: Double, showLabel: Bool = true, compact: Bool = false) {
        self.elo = elo
        self.showLabel = showLabel
        self.compact = compact
    }
    
    private var badgeColor: Color {
        switch elo {
        case ..<1500: return .blue
        case 1500..<2300: return .teal
        case 2300..<3200: return .indigo
        case 3200..<5000: return .purple
        default: return .orange
        }
    }
    
    public var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundColor(badgeColor)
            
            if showLabel {
                Text("Elo")
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(round(elo)))")
                .font(.system(size: compact ? 11 : 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(badgeColor.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Learn Score Badge (0% – 100% Mastery Indicator)
public struct LearnScoreBadge: View {
    let score: Int
    let reviewsCount: Int
    var showLabel: Bool = false
    var compact: Bool = false
    
    public init(word: VocabularyWord, showLabel: Bool = false, compact: Bool = false) {
        self.score = word.learnScore
        self.reviewsCount = word.reviewsCount
        self.showLabel = showLabel
        self.compact = compact
    }
    
    public init(score: Int, reviewsCount: Int = 1, showLabel: Bool = false, compact: Bool = false) {
        self.score = min(100, max(0, score))
        self.reviewsCount = reviewsCount
        self.showLabel = showLabel
        self.compact = compact
    }
    
    private var badgeColor: Color {
        if reviewsCount == 0 && score == 0 { return .gray }
        if score >= 75 { return .green }
        if score >= 40 { return .blue }
        return .orange
    }
    
    private var statusLabel: String {
        if reviewsCount == 0 && score == 0 { return "Neu" }
        if score >= 75 { return "Gelernt" }
        if score >= 40 { return "Training" }
        return "Unsicher"
    }
    
    public var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if score >= 75 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: compact ? 11 : 13, weight: .bold))
                    .foregroundColor(.green)
            } else {
                // Mini circular progress ring
                ZStack {
                    Circle()
                        .stroke(badgeColor.opacity(0.25), lineWidth: compact ? 2.0 : 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(reviewsCount > 0 ? 8 : 0, score)) / 100.0)
                        .stroke(badgeColor, style: StrokeStyle(lineWidth: compact ? 2.0 : 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: compact ? 11 : 13, height: compact ? 11 : 13)
            }
            
            Text("\(score)%")
                .font(.system(size: compact ? 11 : 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(score >= 75 ? .green : .primary)
            
            if showLabel {
                Text("• \(statusLabel)")
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundColor(badgeColor)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .frame(minWidth: compact ? 54 : nil)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(badgeColor.opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - Responsive Press Button Style (Apple Fluid Design)
public struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97
    
    public init(scaleAmount: CGFloat = 0.97) {
        self.scaleAmount = scaleAmount
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
