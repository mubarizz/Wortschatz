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
        case ..<1100: return .gray
        case 1100..<1250: return .blue
        case 1250..<1400: return .teal
        case 1400..<1550: return .indigo
        case 1550..<1700: return .purple
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
