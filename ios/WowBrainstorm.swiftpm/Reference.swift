import Foundation

/// The built-in reference library (schemas, narrative styles, culture pools,
/// tropes, dice tables, portrait shapes). Generated from /shared by
/// tools/build-data.mjs into ReferenceData.swift.
struct Reference: Decodable {
    let formatName: String
    let formatVersion: Int
    let collections: [CollectionDef]
    let narrativeStyles: [NarrativeStyle]
    let culturePools: [CulturePool]
    let tropes: [Trope]
    let rasas: [Rasa]
    let sparkTables: [String: [String]]
    let twists: [String]
    let stopwords: [String]
    let portrait: PortraitSpec

    static func load() -> Reference {
        do {
            return try JSONDecoder().decode(Reference.self, from: Data(referenceJSON.utf8))
        } catch {
            fatalError("Reference library failed to load: \(error)")
        }
    }

    func collection(_ id: String) -> CollectionDef? { collections.first { $0.id == id } }
    func style(_ id: String?) -> NarrativeStyle? { narrativeStyles.first { $0.id == id } }
    func culture(_ id: String?) -> CulturePool? { culturePools.first { $0.id == id } }
    func rasa(_ id: String?) -> Rasa? { rasas.first { $0.id == id } }
}

struct CollectionDef: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let singular: String
    let titleField: String
    let icon: String
    let fields: [FieldDef]
}

struct FieldDef: Decodable, Identifiable, Hashable {
    let key: String
    let label: String
    let type: String
    let required: Bool?
    let options: [String]?
    let collection: String?
    var id: String { key }
}

struct NarrativeStyle: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let origin: String
    let region: String
    let summary: String
    let whenToUse: String
    let stages: [StyleStage]
    let sources: [String]
    let care: String?
}

struct StyleStage: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let prompt: String
}

struct CulturePool: Decodable, Identifiable, Hashable {
    let id: String
    let region: String
    let peoples: String
    let storytelling: [String]
    let cosmology: [String]
    let powerConcepts: [String]
    let figures: [String]
    let crafts: [String]
    let research: [String]
    let care: String
}

struct Trope: Decodable, Identifiable, Hashable {
    let id: String
    let kind: String
    let name: String
    let keywords: [String]
    let note: String?
}

struct Rasa: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let meaning: String
    let color: String
}

struct PortraitSpec: Decodable {
    let width: Double
    let height: Double
    let skinTones: [String]
    let hairColors: [String]
    let garmentColors: [String]
    let accentColors: [String]
    let backgrounds: [String]
    let options: [String: [String]]
    let parts: PortraitParts
    let defaults: [String: JSONValue]
}

struct PortraitParts: Decodable {
    let build: [String: [PortraitShape]]
    let hairBack: [String: [PortraitShape]]
    let hairFront: [String: [PortraitShape]]
    let eyes: [String: [PortraitShape]]
    let aura: [String: [PortraitShape]]
    let symbol: [String: [PortraitShape]]
    let head: [PortraitShape]
    let face: [PortraitShape]
}

struct PortraitShape: Decodable, Hashable {
    let t: String
    let cx: Double?
    let cy: Double?
    let rx: Double?
    let ry: Double?
    let x: Double?
    let y: Double?
    let w: Double?
    let h: Double?
    let r: Double?
    let rot: Double?
    let opacity: Double?
    let sw: Double?
    let fill: String?
    let stroke: String?
}
