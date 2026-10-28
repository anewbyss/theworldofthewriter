import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 3 {
            r = Double((v >> 8) & 0xF) / 15
            g = Double((v >> 4) & 0xF) / 15
            b = Double(v & 0xF) / 15
        } else {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        }
        self.init(red: r, green: g, blue: b)
    }

    static let wowVioletDeep = Color(hex: "#2A1640")
    static let wowViolet = Color(hex: "#4B1F7A")
    static let wowVioletBright = Color(hex: "#6C3DB0")
    static let wowVioletSoft = Color(hex: "#8E5BD0")
    static let wowGold = Color(hex: "#E1AD01")
    static let wowGoldDeep = Color(hex: "#C9A227")
    static let wowPaper = Color(hex: "#FFFEF9")
}

/// Rounded card used across the app.
struct Card<Content: View>: View {
    var accent: Bool = false
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(alignment: .top) {
                if accent {
                    Rectangle().fill(Color.wowGold).frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Small pill label.
struct Chip: View {
    let text: String
    var on: Bool = false
    var gold: Bool = false
    var body: some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(on ? Color.wowViolet : gold ? Color.wowGold.opacity(0.22) : Color.wowVioletSoft.opacity(0.14)))
            .foregroundColor(on ? .white : .primary)
            .overlay(Capsule().stroke(on ? Color.wowViolet : Color.wowVioletSoft.opacity(0.3)))
    }
}

/// Wrapping row layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).foregroundColor(.wowGoldDeep).tracking(1.2)
            Text(title).font(.system(.largeTitle, design: .serif).weight(.bold))
            if let s = subtitle { Text(s).foregroundColor(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
