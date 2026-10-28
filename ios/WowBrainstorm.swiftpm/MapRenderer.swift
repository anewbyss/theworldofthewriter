import SwiftUI

/// What to draw on top of the base map.
struct MapRenderOptions {
    var zoom: Double = 1
    var time: Double?
    var journeyID: String?
    var selectedID: String?
    var editing = false
    var draft: [[Double]] = []
    var draftIsRegion = false
    var layers: Set<String> = ["regions", "paths", "stamps", "labels", "events", "conflicts", "decor"]
}

/// Draws a map entry with the shared style and stamp recipes (mirrors web/js/maps.js).
enum MapRenderer {
    static func draw(_ ctx: inout GraphicsContext, store: Store, map: Entity, canvas: MapCanvas, options o: MapRenderOptions) {
        let style = store.ref.mapStyle(map.string("mapStyle"))
        let pal = style.colors
        let z = o.zoom
        let W = canvas.width, H = canvas.height

        func col(_ key: String?, _ fallback: String? = nil) -> Color? {
            guard let k = key ?? fallback, k != "none" else { return nil }
            return Color(hex: pal[k] ?? k)
        }
        let paper = col("paper") ?? .white
        let ink = col("ink") ?? .black
        let accent = col("accent") ?? .wowGold
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * z, y: y * z) }
        func font(_ size: Double, bold: Bool = true) -> Font {
            .system(size: max(size * z, 4), weight: bold ? .semibold : .regular, design: style.font == "serif" ? .serif : .default)
        }

        // Paper & pattern
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W * z, height: H * z)), with: .color(paper))
        drawPattern(&ctx, style: style, W: W, H: H, z: z, ink: ink, accent: accent)

        // Features
        let order: [String: Int] = ["region": 0, "path": 1, "stamp": 2, "label": 3]
        let layerOf: [String: String] = ["region": "regions", "path": "paths", "stamp": "stamps", "label": "labels"]
        let sorted = canvas.features.enumerated().sorted { a, b in
            let oa = order[a.element.kind] ?? 2, ob = order[b.element.kind] ?? 2
            return oa != ob ? oa < ob : a.offset < b.offset
        }.map { $0.element }
        for f in sorted {
            guard o.layers.contains(layerOf[f.kind] ?? "stamps") else { continue }
            let visible = store.isVisible(f, at: o.time)
            if !visible && !o.editing { continue }
            var layer = ctx
            if !visible { layer.opacity = 0.15 }
            switch f.kind {
            case "region":
                if f.points.count >= 3 {
                    var path = Path()
                    path.addLines(f.points.map { pt($0[0], $0[1]) })
                    path.closeSubpath()
                    layer.fill(path, with: .color((col(f.color, "land") ?? .gray).opacity(f.opacity ?? 0.8)))
                    layer.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.5 * z, lineJoin: .round))
                }
                if let l = f.label, !l.isEmpty {
                    let a = f.anchor
                    drawText(&layer, l, a.x, a.y, 18, ink, paper, z, font)
                }
            case "path":
                drawRoute(&layer, f, style: style, pal: pal, z: z, paper: paper, ink: ink, col: col)
                if let l = f.label, !l.isEmpty {
                    let a = f.anchor
                    drawText(&layer, l, a.x, a.y - 10, 14, ink, paper, z, font)
                }
            case "label":
                layer.draw(Text(f.text ?? "Label").font(font(f.size ?? 22)).foregroundColor(ink), at: pt(f.x, f.y - (f.size ?? 22) * 0.35), anchor: .center)
            default:
                let def = store.ref.mapStamps[f.stamp ?? "pin"] ?? store.ref.mapStamps["pin"]
                let size = f.size ?? 40
                if let def = def {
                    let fill = col(f.color, def.color) ?? ink
                    let k = size / 40 * z
                    let t = CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: (f.x - size / 2) * z, ty: (f.y - size / 2) * z)
                    for s in def.shapes {
                        let path = shapePath(s).applying(t)
                        let paint: (String?) -> Color? = { key in key == "fill" ? fill : col(key) }
                        let opacity = s.opacity ?? 1
                        if let c = paint(s.fill), s.t != "line" { layer.fill(path, with: .color(c.opacity(opacity))) }
                        if let c = paint(s.stroke) {
                            layer.stroke(path, with: .color(c.opacity(opacity)), style: StrokeStyle(lineWidth: (s.sw ?? 1) * k, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                if let l = f.label, !l.isEmpty {
                    drawText(&layer, l, f.x, f.y + size / 2 + 15, 14, ink, paper, z, font)
                }
            }
        }

        // Journey
        if let jid = o.journeyID, !jid.isEmpty {
            let stops = store.journey(jid, canvas, time: o.time)
            if stops.count > 1 {
                var path = Path()
                path.addLines(stops.map { pt($0.anchor.x, $0.anchor.y) })
                ctx.stroke(path, with: .color(accent.opacity(0.9)), style: StrokeStyle(lineWidth: 5 * z, lineCap: .round, dash: [14 * z, 8 * z]))
            }
            for (i, s) in stops.enumerated() {
                let c = pt(s.anchor.x, s.anchor.y)
                let r = 13 * z
                let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.fill(circle, with: .color(accent))
                ctx.stroke(circle, with: .color(ink), lineWidth: 2 * z)
                ctx.draw(Text("\(i + 1)").font(.system(size: max(13 * z, 4), weight: .bold)).foregroundColor(ink), at: c, anchor: .center)
            }
        }

        // Conflicts at their places
        if o.layers.contains("conflicts") {
            let war = Color(hex: "#C0392B")
            for (fid, list) in store.conflictsByFeature(canvas, time: o.time) {
                guard let f = canvas.features.first(where: { $0.id == fid }), store.isVisible(f, at: o.time) else { continue }
                let a = f.anchor
                let c = pt(a.x, a.y)
                let r = 34 * z
                let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.fill(ring, with: .color(war.opacity(0.12)))
                ctx.stroke(ring, with: .color(war), style: StrokeStyle(lineWidth: 3 * z, dash: [8 * z, 5 * z]))
                let b = pt(a.x - 22, a.y - 22)
                let br = 12 * z
                let badge = Path(ellipseIn: CGRect(x: b.x - br, y: b.y - br, width: br * 2, height: br * 2))
                ctx.fill(badge, with: .color(war))
                ctx.stroke(badge, with: .color(paper), lineWidth: 2 * z)
                ctx.draw(Text("⚔").font(.system(size: max(13 * z, 4))).foregroundColor(.white), at: b, anchor: .center)
                let names = list.prefix(2).map { $0.string("name").isEmpty ? "Conflict" : $0.string("name") }.joined(separator: " · ") + (list.count > 2 ? " +\(list.count - 2)" : "")
                ctx.draw(Text(names).font(.system(size: max(13 * z, 4), weight: .bold)).foregroundColor(war), at: pt(a.x, a.y + 52), anchor: .center)
            }
        }

        // Event badges
        if o.layers.contains("events") {
            let evs = store.eventsByFeature(canvas, time: o.time)
            for f in canvas.features {
                guard let list = evs[f.id], store.isVisible(f, at: o.time) else { continue }
                let a = f.anchor
                let c = pt(a.x + 20, a.y - 22)
                let r = 11 * z
                let now = o.time != nil && list.contains { $0.number("sequence") == o.time }
                let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.fill(circle, with: .color(now ? accent : ink))
                ctx.stroke(circle, with: .color(paper), lineWidth: 2 * z)
                ctx.draw(Text("\(list.count)").font(.system(size: max(12 * z, 4), weight: .bold)).foregroundColor(now ? ink : paper), at: c, anchor: .center)
            }
        }

        // Draft
        if !o.draft.isEmpty {
            var path = Path()
            path.addLines(o.draft.map { pt($0[0], $0[1]) })
            if o.draftIsRegion { path.closeSubpath(); ctx.fill(path, with: .color(accent.opacity(0.2))) }
            ctx.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
            for p in o.draft {
                let c = pt(p[0], p[1])
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)), with: .color(accent))
            }
        }

        // Selection
        if let i = canvas.index(of: o.selectedID) {
            let f = canvas.features[i]
            let highlight = Color(hex: "#6C3DB0")
            if f.kind == "path" || f.kind == "region" {
                for p in f.points {
                    let c = pt(p[0], p[1])
                    let dot = Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
                    ctx.fill(dot, with: .color(.white))
                    ctx.stroke(dot, with: .color(highlight), lineWidth: 2)
                }
            } else {
                let r = (f.kind == "label" ? (f.size ?? 22) * 1.4 : (f.size ?? 40) * 0.75) * z
                let cy = f.kind == "label" ? f.y - (f.size ?? 22) / 3 : f.y
                let c = pt(f.x, cy)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(highlight), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
            }
        }

        if o.layers.contains("decor") {
            drawFrame(&ctx, style: style, W: W, H: H, z: z, ink: ink, accent: accent)
            drawCompass(&ctx, style: style, W: W, z: z, paper: paper, ink: ink, accent: accent, font: font)
            drawCartouche(&ctx, map: map, style: style, z: z, paper: paper, ink: ink, font: font)
        }
    }

    private static func drawText(_ ctx: inout GraphicsContext, _ s: String, _ x: Double, _ y: Double, _ size: Double, _ ink: Color, _ paper: Color, _ z: Double, _ font: (Double, Bool) -> Font) {
        let p = CGPoint(x: x * z, y: (y - size * 0.35) * z)
        for (dx, dy) in [(-1.5, 0.0), (1.5, 0.0), (0.0, -1.5), (0.0, 1.5)] {
            ctx.draw(Text(s).font(font(size, true)).foregroundColor(paper.opacity(0.85)), at: CGPoint(x: p.x + dx, y: p.y + dy), anchor: .center)
        }
        ctx.draw(Text(s).font(font(size, true)).foregroundColor(ink), at: p, anchor: .center)
    }

    static func shapePath(_ s: PortraitShape) -> Path {
        switch s.t {
        case "ellipse":
            let cx = s.cx ?? 0, cy = s.cy ?? 0, rx = s.rx ?? 0, ry = s.ry ?? 0
            return Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        case "rect":
            let rect = CGRect(x: s.x ?? 0, y: s.y ?? 0, width: s.w ?? 0, height: s.h ?? 0)
            var p = Path(roundedRect: rect, cornerRadius: s.r ?? 0)
            if let rot = s.rot {
                let c = CGPoint(x: rect.midX, y: rect.midY)
                p = p.applying(CGAffineTransform(translationX: c.x, y: c.y).rotated(by: rot * .pi / 180).translatedBy(x: -c.x, y: -c.y))
            }
            return p
        case "poly", "line":
            var p = Path()
            let pts = (s.points ?? []).filter { $0.count >= 2 }.map { CGPoint(x: $0[0], y: $0[1]) }
            p.addLines(pts)
            if s.t == "poly" { p.closeSubpath() }
            return p
        default:
            return Path()
        }
    }

    private static func drawRoute(_ ctx: inout GraphicsContext, _ f: MapFeature, style: MapStyle, pal: [String: String], z: Double, paper: Color, ink: Color, col: (String?, String?) -> Color?) {
        guard f.points.count >= 2 else { return }
        let color = col(f.color, "ink") ?? ink
        let w = f.width ?? 3
        let ps = f.pathStyle ?? style.pathStyle
        var path = Path()
        path.addLines(f.points.map { CGPoint(x: $0[0] * z, y: $0[1] * z) })
        switch ps {
        case "footprints":
            for fp in footprints(f.points, spacing: 22) {
                let rx = (w + 3) * z, ry = (w + 3) / 1.8 * z
                let e = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                    .applying(CGAffineTransform(rotationAngle: fp.angle).concatenating(CGAffineTransform(translationX: fp.x * z, y: fp.y * z)))
                ctx.fill(e, with: .color(color))
            }
        case "double":
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w * 2.4 * z, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: .color(paper), style: StrokeStyle(lineWidth: w * 0.9 * z, lineCap: .round, lineJoin: .round))
        case "dashed":
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w * z, lineCap: .round, lineJoin: .round, dash: [w * 4 * z, w * 2.5 * z]))
        case "dotted":
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w * z, lineCap: .round, lineJoin: .round, dash: [0.1, w * 3 * z]))
        default:
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w * z, lineCap: .round, lineJoin: .round))
        }
    }

    private static func drawPattern(_ ctx: inout GraphicsContext, style: MapStyle, W: Double, H: Double, z: Double, ink: Color, accent: Color) {
        switch style.pattern {
        case "grid":
            var p = Path()
            var x = 50.0
            while x < W { p.move(to: CGPoint(x: x * z, y: 0)); p.addLine(to: CGPoint(x: x * z, y: H * z)); x += 50 }
            var y = 50.0
            while y < H { p.move(to: CGPoint(x: 0, y: y * z)); p.addLine(to: CGPoint(x: W * z, y: y * z)); y += 50 }
            ctx.stroke(p, with: .color(ink.opacity(0.07)), lineWidth: 1)
        case "dots":
            var p = Path()
            var x = 20.0
            while x < W {
                var y = 20.0
                while y < H { p.addEllipse(in: CGRect(x: (x - 1.5) * z, y: (y - 1.5) * z, width: 3 * z, height: 3 * z)); y += 40 }
                x += 40
            }
            ctx.fill(p, with: .color(accent.opacity(0.25)))
        case "rings":
            var p = Path()
            var r = 70.0
            while r < max(W, H) {
                p.addEllipse(in: CGRect(x: (W / 2 - r) * z, y: (H / 2 - r) * z, width: 2 * r * z, height: 2 * r * z))
                r += 70
            }
            ctx.stroke(p, with: .color(accent.opacity(0.22)), lineWidth: 1)
        case "stars":
            var rng = ParkMiller(state: 12345)
            var p = Path()
            let n = Int((W * H / 9000).rounded())
            for _ in 0..<n {
                let x = rng.next() * W, y = rng.next() * H, r = 0.6 + rng.next() * 1.6
                p.addEllipse(in: CGRect(x: (x - r) * z, y: (y - r) * z, width: 2 * r * z, height: 2 * r * z))
            }
            ctx.fill(p, with: .color(ink.opacity(0.7)))
        case "hatch":
            var p = Path()
            var d = -H
            while d < W { p.move(to: CGPoint(x: d * z, y: H * z)); p.addLine(to: CGPoint(x: (d + H) * z, y: 0)); d += 24 }
            ctx.stroke(p, with: .color(ink.opacity(0.1)), lineWidth: 1)
        default:
            break
        }
    }

    private static func drawFrame(_ ctx: inout GraphicsContext, style: MapStyle, W: Double, H: Double, z: Double, ink: Color, accent: Color) {
        func rect(_ inset: Double) -> CGRect { CGRect(x: inset * z, y: inset * z, width: (W - inset * 2) * z, height: (H - inset * 2) * z) }
        switch style.frame {
        case "simple":
            ctx.stroke(Path(rect(10)), with: .color(ink), lineWidth: 2 * z)
        case "double":
            ctx.stroke(Path(rect(10)), with: .color(ink), lineWidth: 3 * z)
            ctx.stroke(Path(rect(18)), with: .color(accent), lineWidth: 1.5 * z)
        case "band":
            var p = Path(rect(0))
            p.addRect(rect(24))
            ctx.fill(p, with: .color(ink.opacity(0.85)), style: FillStyle(eoFill: true))
            var x = 40.0
            while x < W - 30 {
                ctx.fill(Path(CGRect(x: x * z, y: 8 * z, width: 20 * z, height: 8 * z)), with: .color(accent))
                ctx.fill(Path(CGRect(x: x * z, y: (H - 16) * z, width: 20 * z, height: 8 * z)), with: .color(accent))
                x += 60
            }
        case "circle":
            let r = min(W, H) / 2 - 20
            let circle = CGRect(x: (W / 2 - r) * z, y: (H / 2 - r) * z, width: 2 * r * z, height: 2 * r * z)
            var p = Path(rect(0))
            p.addEllipse(in: circle)
            ctx.fill(p, with: .color(Color.black.opacity(0.35)), style: FillStyle(eoFill: true))
            ctx.stroke(Path(ellipseIn: circle), with: .color(accent), lineWidth: 3 * z)
        default:
            break
        }
    }

    private static func drawCompass(_ ctx: inout GraphicsContext, style: MapStyle, W: Double, z: Double, paper: Color, ink: Color, accent: Color, font: (Double, Bool) -> Font) {
        let o = style.orientation
        guard !o.isEmpty else { return }
        let cw = ["N": "E", "E": "S", "S": "W", "W": "N"], opp = ["N": "S", "S": "N", "E": "W", "W": "E"]
        let cx = W - 90, cy = 95.0, r = 42.0
        let circle = Path(ellipseIn: CGRect(x: (cx - r) * z, y: (cy - r) * z, width: 2 * r * z, height: 2 * r * z))
        ctx.fill(circle, with: .color(paper.opacity(0.8)))
        ctx.stroke(circle, with: .color(ink), lineWidth: 1.5 * z)
        var needle = Path()
        needle.addLines([CGPoint(x: cx * z, y: (cy - r + 6) * z), CGPoint(x: (cx + 8) * z, y: cy * z), CGPoint(x: cx * z, y: (cy + r - 6) * z), CGPoint(x: (cx - 8) * z, y: cy * z)])
        needle.closeSubpath()
        ctx.fill(needle, with: .color(accent))
        ctx.stroke(needle, with: .color(ink), lineWidth: 1 * z)
        let right = cw[o] ?? "E"
        let letters: [(String, Double, Double, Double)] = [
            (o, cx, cy - r - 12, 18), (opp[o] ?? "S", cx, cy + r + 13, 13),
            (right, cx + r + 12, cy, 13), (opp[right] ?? "W", cx - r - 12, cy, 13),
        ]
        for (t, x, y, size) in letters {
            ctx.draw(Text(t).font(font(size, true)).foregroundColor(ink), at: CGPoint(x: x * z, y: y * z), anchor: .center)
        }
    }

    private static func drawCartouche(_ ctx: inout GraphicsContext, map: Entity, style: MapStyle, z: Double, paper: Color, ink: Color, font: (Double, Bool) -> Font) {
        let title = map.string("title").isEmpty ? "Untitled map" : map.string("title")
        let sub = [map.string("era"), map.string("scaleNote")].filter { !$0.isEmpty }.joined(separator: " · ")
        let inset = style.frame == "band" ? 40.0 : 32.0
        let w = max(240, max(Double(title.count) * 13, Double(sub.count) * 7) + 40)
        let h = sub.isEmpty ? 46.0 : 66.0
        let box = Path(roundedRect: CGRect(x: inset * z, y: inset * z, width: w * z, height: h * z), cornerRadius: 6 * z)
        ctx.fill(box, with: .color(paper.opacity(0.88)))
        ctx.stroke(box, with: .color(ink), lineWidth: 1.5 * z)
        ctx.draw(Text(title).font(font(24, true)).foregroundColor(ink), at: CGPoint(x: (inset + 18) * z, y: (inset + 22) * z), anchor: .leading)
        if !sub.isEmpty {
            ctx.draw(Text(sub).font(font(13, false)).foregroundColor(ink.opacity(0.8)), at: CGPoint(x: (inset + 18) * z, y: (inset + 49) * z), anchor: .leading)
        }
    }
}

/// A non-interactive map picture (thumbnails, export).
struct MapPicture: View {
    let store: Store
    let map: Entity
    var options = MapRenderOptions(layers: ["regions", "paths", "stamps", "labels", "decor"])

    var body: some View {
        let canvas = store.mapCanvas(map)
        Canvas { ctx, size in
            var o = options
            o.zoom = min(size.width / canvas.width, size.height / canvas.height)
            MapRenderer.draw(&ctx, store: store, map: map, canvas: canvas, options: o)
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
    }
}
