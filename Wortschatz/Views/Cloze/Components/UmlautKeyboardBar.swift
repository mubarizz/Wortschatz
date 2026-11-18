import SwiftUI
import UIKit

public struct UmlautKeyboardBar: View {
    @Binding var text: String
    let onQuickSubmit: () -> Void
    
    private let umlauts = ["ä", "ö", "ü", "ß", "Ä", "Ö", "Ü"]
    
    public init(text: Binding<String>, onQuickSubmit: @escaping () -> Void) {
        self._text = text
        self.onQuickSubmit = onQuickSubmit
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            ForEach(umlauts, id: \.self) { char in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    text.append(char)
                }) {
                    Text(char)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(7)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
                }
                .buttonStyle(.plain)
            }
            
            // Clear last character button
            Button(action: {
                if !text.isEmpty {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    text.removeLast()
                }
            }) {
                Image(systemName: "delete.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.95))
    }
}
