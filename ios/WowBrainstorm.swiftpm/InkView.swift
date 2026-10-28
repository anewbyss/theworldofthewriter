import SwiftUI
import PencilKit
import Vision

/// Full-screen Apple Pencil page. Handwriting is stored as PencilKit data (for
/// re-editing) plus a PNG (so the web app can show it). "Convert to text" uses
/// Apple's on-device Vision text recognition — OCR, not generative AI.
struct InkPageView: View {
    @EnvironmentObject var store: Store
    let col: String
    let id: String
    let key: String

    @State private var drawing = PKDrawing()
    @State private var clearToken = 0
    @State private var pencilOnly = false
    @State private var recognizing = false
    @State private var language = "en-US"
    @State private var languages: [String] = ["en-US"]
    @State private var message: String?
    @State private var underlay: UIImage?
    @State private var underlayDataURL: String?
    @State private var underlayScale: Double = 1
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle(isOn: $pencilOnly) { Label("Pencil only", systemImage: "applepencil") }
                    .toggleStyle(.button)
                Picker("Language", selection: $language) {
                    ForEach(languages, id: \.self) { Text(Locale.current.localizedString(forIdentifier: $0) ?? $0).tag($0) }
                }
                .pickerStyle(.menu)
                Spacer()
                if recognizing { ProgressView() }
                Button { recognize() } label: { Label("Convert to text", systemImage: "text.viewfinder") }
                    .buttonStyle(.borderedProminent)
                    .tint(.wowGold)
                    .foregroundColor(.wowVioletDeep)
                    .disabled(recognizing)
                Button(role: .destructive) {
                    drawing = PKDrawing()
                    underlay = nil
                    underlayDataURL = nil
                    clearToken += 1
                    save(drawing)
                } label: { Label("Clear", systemImage: "trash") }
            }
            .padding(10)
            .background(.bar)

            if let message = message {
                Text(message).font(.callout).padding(8).frame(maxWidth: .infinity).background(Color.wowGold.opacity(0.2))
            }

            ZStack(alignment: .topLeading) {
                Color.wowPaper
                if let underlay = underlay {
                    Image(uiImage: underlay).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).opacity(0.9)
                }
                PencilCanvas(drawing: $drawing, pencilOnly: pencilOnly, clearToken: clearToken) { save($0) }
            }
        }
        .navigationTitle(store.title(col, store.get(col, id)))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let ink = store.value(col, id, key).object ?? [:]
        if let b64 = ink["pkdrawing"]?.string, let raw = Data(base64Encoded: b64), let d = try? PKDrawing(data: raw) {
            drawing = d
            if let u = ink["underlay"]?.string, let img = imageFromDataURL(u, scale: ink["underlayScale"]?.number ?? 1) {
                underlay = img
                underlayDataURL = u
                underlayScale = ink["underlayScale"]?.number ?? 1
            }
        } else if let png = ink["png"]?.string, let img = imageFromDataURL(png, scale: ink["scale"]?.number ?? 1) {
            // Handwriting from the web app: show it underneath; new strokes go on top.
            underlay = img
            underlayDataURL = png
            underlayScale = ink["scale"]?.number ?? 1
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        if let supported = try? request.supportedRecognitionLanguages(), !supported.isEmpty {
            languages = supported
            if !supported.contains(language) { language = supported[0] }
        }
    }

    private func save(_ d: PKDrawing) {
        var ink: [String: JSONValue] = [:]
        ink["pkdrawing"] = .string(d.dataRepresentation().base64EncodedString())
        if let u = underlayDataURL {
            ink["underlay"] = .string(u)
            ink["underlayScale"] = .number(underlayScale)
        }
        if let image = flatten(d, includeUnderlay: true), let png = image.pngData() {
            ink["png"] = .string("data:image/png;base64," + png.base64EncodedString())
            ink["scale"] = .number(Double(image.scale))
        }
        store.update(col, id, key, .object(ink))
    }

    /// Renders ink in light mode (so black stays black) at canvas coordinates.
    private func flatten(_ d: PKDrawing, includeUnderlay: Bool, whiteBackground: Bool = false) -> UIImage? {
        var bounds = d.bounds
        if includeUnderlay, let u = underlay {
            bounds = bounds.union(CGRect(origin: .zero, size: u.size))
        }
        if bounds.isNull || bounds.isEmpty { return nil }
        let canvasRect = CGRect(x: 0, y: 0, width: bounds.maxX + 20, height: bounds.maxY + 20)
        var inkImage = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            inkImage = d.image(from: canvasRect, scale: 1)
        }
        let renderer = UIGraphicsImageRenderer(size: canvasRect.size)
        return renderer.image { ctx in
            if whiteBackground {
                UIColor.white.setFill()
                ctx.fill(canvasRect)
            }
            if includeUnderlay, let u = underlay { u.draw(in: CGRect(origin: .zero, size: u.size)) }
            inkImage.draw(at: .zero)
        }
    }

    private func recognize() {
        guard let image = flatten(drawing, includeUnderlay: true, whiteBackground: true), let cg = image.cgImage else {
            message = "Write something on the page first."
            return
        }
        recognizing = true
        message = nil
        let lang = language
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = [lang]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            var text = ""
            do {
                try handler.perform([request])
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            } catch {
                text = ""
            }
            DispatchQueue.main.async {
                recognizing = false
                if text.isEmpty {
                    message = "Couldn't read that — try writing a little larger or more slowly."
                } else {
                    let current = store.value(col, id, "text").string ?? ""
                    store.update(col, id, "text", .string(current.isEmpty ? text : current + "\n" + text))
                    message = "Converted and added to this page's Text: “\(text.prefix(80))”"
                }
            }
        }
    }
}

func imageFromDataURL(_ s: String, scale: Double = 1) -> UIImage? {
    guard let comma = s.firstIndex(of: ",") else { return nil }
    guard let raw = Data(base64Encoded: String(s[s.index(after: comma)...])) else { return nil }
    return UIImage(data: raw, scale: CGFloat(max(scale, 1)))
}

/// PencilKit canvas with the system tool picker.
struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var pencilOnly: Bool
    var clearToken: Int
    var onChange: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.alwaysBounceVertical = true
        canvas.contentSize = CGSize(width: 2000, height: 3000)
        let picker = context.coordinator.toolPicker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        context.coordinator.lastToken = clearToken
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        if context.coordinator.lastToken != clearToken {
            context.coordinator.lastToken = clearToken
            canvas.drawing = PKDrawing()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        let toolPicker = PKToolPicker()
        var lastToken = 0
        private var pending: DispatchWorkItem?

        init(_ parent: PencilCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let d = canvasView.drawing
            parent.drawing = d
            // Debounce saving so long writing sessions stay smooth.
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.parent.onChange(d) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
    }
}

/// Compact preview + link to the full ink page, used inside entry forms.
struct InkFieldPreview: View {
    @EnvironmentObject var store: Store
    let col: String
    let id: String
    let key: String

    var body: some View {
        NavigationLink(value: Route.ink(col, id, key)) {
            HStack(spacing: 14) {
                if let png = store.value(col, id, key).object?["png"]?.string, let img = imageFromDataURL(png) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(width: 120, height: 90)
                        .background(Color.wowPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "scribble.variable").font(.largeTitle).foregroundColor(.wowViolet)
                        .frame(width: 120, height: 90)
                        .background(Color.wowPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading) {
                    Text("Open handwriting page").font(.headline)
                    Text("Write with Apple Pencil, then convert to text.").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}
