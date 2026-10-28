import SwiftUI

/// Portrait settings, stored in the entry's "portrait" field as JSON.
struct PortraitParams: Equatable {
    var build = "slender"
    var hair = "coils"
    var eyes = "open"
    var aura = "none"
    var symbol = "none"
    var skin = 3
    var hairColor = 0
    var garment = 0
    var accent = 0
    var background = 0

    init(_ value: JSONValue, spec: PortraitSpec) {
        let d = spec.defaults
        let o = value.object ?? [:]
        func s(_ k: String) -> String { o[k]?.string ?? d[k]?.string ?? "" }
        func i(_ k: String) -> Int { Int(o[k]?.number ?? d[k]?.number ?? 0) }
        build = s("build"); hair = s("hair"); eyes = s("eyes"); aura = s("aura"); symbol = s("symbol")
        skin = i("skin"); hairColor = i("hairColor"); garment = i("garment"); accent = i("accent"); background = i("background")
    }

    static func random(spec: PortraitSpec) -> PortraitParams {
        var p = PortraitParams(.null, spec: spec)
        let o = spec.options
        p.build = o["build"]?.randomElement() ?? p.build
        p.hair = o["hair"]?.randomElement() ?? p.hair
        p.eyes = o["eyes"]?.randomElement() ?? p.eyes
        p.aura = o["aura"]?.randomElement() ?? p.aura
        p.symbol = o["symbol"]?.randomElement() ?? p.symbol
        p.skin = Int.random(in: 0..<spec.skinTones.count)
        p.hairColor = Int.random(in: 0..<spec.hairColors.count)
        p.garment = Int.random(in: 0..<spec.garmentColors.count)
        p.accent = Int.random(in: 0..<spec.accentColors.count)
        p.background = Int.random(in: 0..<spec.backgrounds.count)
        return p
    }

    var json: JSONValue {
        .object([
            "build": .string(build), "hair": .string(hair), "eyes": .string(eyes), "aura": .string(aura), "symbol": .string(symbol),
            "skin": .number(Double(skin)), "hairColor": .number(Double(hairColor)), "garment": .number(Double(garment)),
            "accent": .number(Double(accent)), "background": .number(Double(background)),
        ])
    }
}

/// Draws a portrait from the shared shape recipes (same as the web app's SVG).
struct PortraitView: View {
    let params: PortraitParams
    let spec: PortraitSpec

    private func pick(_ list: [String], _ i: Int) -> String {
        list.indices.contains(i) ? list[i] : (list.first ?? "#888888")
    }

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width / spec.width, size.height / spec.height)
            let palette: [String: Color] = [
                "skin": Color(hex: pick(spec.skinTones, params.skin)),
                "hair": Color(hex: pick(spec.hairColors, params.hairColor)),
                "garment": Color(hex: pick(spec.garmentColors, params.garment)),
                "accent": Color(hex: pick(spec.accentColors, params.accent)),
                "bg": Color(hex: pick(spec.backgrounds, params.background)),
                "dark": Color(hex: "#1B1030"),
            ]
            func color(_ key: String?) -> Color? {
                guard let key = key, key != "none" else { return nil }
                return palette[key] ?? Color(hex: key)
            }
            ctx.fill(Path(CGRect(x: 0, y: 0, width: spec.width * scale, height: spec.height * scale)), with: .color(palette["bg"]!))

            let p = spec.parts
            var shapes: [PortraitShape] = []
            shapes += p.aura[params.aura] ?? []
            shapes += p.hairBack[params.hair] ?? []
            shapes += p.head
            shapes += p.build[params.build] ?? []
            shapes += p.face
            shapes += p.eyes[params.eyes] ?? []
            shapes += p.hairFront[params.hair] ?? []
            shapes += p.symbol[params.symbol] ?? []

            for s in shapes {
                var path: Path
                if s.t == "ellipse" {
                    let cx = s.cx ?? 0, cy = s.cy ?? 0, rx = s.rx ?? 0, ry = s.ry ?? 0
                    path = Path(ellipseIn: CGRect(x: (cx - rx) * scale, y: (cy - ry) * scale, width: rx * 2 * scale, height: ry * 2 * scale))
                } else {
                    let x = s.x ?? 0, y = s.y ?? 0, w = s.w ?? 0, h = s.h ?? 0
                    let rect = CGRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale)
                    path = Path(roundedRect: rect, cornerRadius: (s.r ?? 0) * scale)
                    if let rot = s.rot {
                        let c = CGPoint(x: rect.midX, y: rect.midY)
                        let t = CGAffineTransform(translationX: c.x, y: c.y)
                            .rotated(by: rot * .pi / 180)
                            .translatedBy(x: -c.x, y: -c.y)
                        path = path.applying(t)
                    }
                }
                let opacity = s.opacity ?? 1
                if let fill = color(s.fill) {
                    ctx.fill(path, with: .color(fill.opacity(opacity)))
                }
                if let stroke = color(s.stroke) {
                    ctx.stroke(path, with: .color(stroke.opacity(opacity)), lineWidth: (s.sw ?? 1) * scale)
                }
            }
        }
        .aspectRatio(spec.width / spec.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wowGold, lineWidth: 2))
        .accessibilityLabel("Character portrait")
    }
}

/// Builder controls for the portrait field.
struct PortraitBuilder: View {
    let spec: PortraitSpec
    @Binding var value: JSONValue

    private var params: PortraitParams { PortraitParams(value, spec: spec) }

    private func apply(_ change: (inout PortraitParams) -> Void) {
        var p = params
        change(&p)
        value = p.json
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                PortraitView(params: params, spec: spec).frame(width: 200)
                controls
            }
            VStack(alignment: .leading, spacing: 16) {
                PortraitView(params: params, spec: spec).frame(width: 180)
                controls
            }
        }
        .padding(.vertical, 6)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            swatches("Skin tone", spec.skinTones, params.skin) { i in apply { $0.skin = i } }
            option("Build & clothing", "build", params.build) { v in apply { $0.build = v } }
            swatches("Garment", spec.garmentColors, params.garment) { i in apply { $0.garment = i } }
            option("Hair & head covering", "hair", params.hair) { v in apply { $0.hair = v } }
            swatches("Hair colour", spec.hairColors, params.hairColor) { i in apply { $0.hairColor = i } }
            option("Eyes", "eyes", params.eyes) { v in apply { $0.eyes = v } }
            option("Aura", "aura", params.aura) { v in apply { $0.aura = v } }
            option("Emblem", "symbol", params.symbol) { v in apply { $0.symbol = v } }
            swatches("Accent / power colour", spec.accentColors, params.accent) { i in apply { $0.accent = i } }
            swatches("Background", spec.backgrounds, params.background) { i in apply { $0.background = i } }
            HStack {
                Button { value = PortraitParams.random(spec: spec).json } label: { Label("Shuffle", systemImage: "dice") }
                    .buttonStyle(.bordered)
                Text("Shape-built placeholder — sketch your real design on an Ink page.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
    }

    private func option(_ label: String, _ key: String, _ current: String, _ onPick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
            FlowLayout {
                ForEach(spec.options[key] ?? [], id: \.self) { opt in
                    Button { onPick(opt) } label: { Chip(text: opt, on: opt == current) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func swatches(_ label: String, _ palette: [String], _ current: Int, _ onPick: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
            FlowLayout {
                ForEach(Array(palette.enumerated()), id: \.offset) { i, hex in
                    Button { onPick(i) } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(i == current ? Color.wowGold : Color.secondary.opacity(0.3), lineWidth: i == current ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) \(i + 1)")
                }
            }
        }
    }
}
