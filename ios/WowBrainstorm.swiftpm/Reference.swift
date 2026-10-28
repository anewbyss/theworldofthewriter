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
    let mapStyles: [MapStyle]
    let mapStamps: [String: MapStamp]
    let mapSizes: [String: [Double]]
    let religions: [ReligionRef]
    let languageFamilies: [LanguageFamily]
    let langFeatures: [LangFeature]
    let writingSystems: [WritingSystem]
    let contactZones: [ContactZone]
    let powerArchetypes: [PowerArchetype]
    let traitTemplates: [[String: JSONValue]]
    let kinshipTraditions: [KinshipTradition]
    let speciesTemplates: [[String: JSONValue]]
    let animals: [LoreGroup]
    let creatures: [LoreGroup]
    let wars: [LoreGroup]
    let rivalryLore: [LoreGroup]
    let mythHistory: [LoreGroup]

    func lore(_ source: String) -> [LoreGroup] {
        switch source {
        case "animals": return animals
        case "creatures": return creatures
        case "wars": return wars
        case "rivalryLore": return rivalryLore
        case "mythHistory": return mythHistory
        default: return []
        }
    }

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
    func mapStyle(_ id: String?) -> MapStyle { mapStyles.first { $0.id == id } ?? mapStyles[0] }
    func mapSize(_ scale: String?) -> (Double, Double) {
        let s = mapSizes[scale ?? ""] ?? mapSizes["region"] ?? [1600, 1100]
        return (s.count > 0 ? s[0] : 1600, s.count > 1 ? s[1] : 1100)
    }
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
    let source: String?
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
    let peopleList: [PeopleEntry]?
}

struct PeopleEntry: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct ReligionRef: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let family: String
    let origin: String
    let regions: [String]
    let living: Bool
    let concepts: [String]
    let branches: [ReligionBranch]
    let care: String
    let sources: [String]
}

struct ReligionBranch: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let note: String
}

struct LanguageFamily: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let regions: [String]
    let note: String
    let languages: [LanguageRef]
}

struct LanguageRef: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let regions: [String]
    let features: [String]
    let scripts: [String]
    let status: String
}

struct LangFeature: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let examples: String
}

struct WritingSystem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let used: String
}

struct ContactZone: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let connects: [String]
    let era: String
    let flows: String
    let hook: String
}

struct KinshipTradition: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let roots: String
    let region: String
    let bond: String
    let description: String
}

struct PowerArchetype: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let roots: String
    let summary: String
    let structure: String
    let prompts: String
    let care: String
}

/// A group in one of the lore lists (animals, mythic beings, wars…).
struct LoreGroup: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let pool: String
    let items: [LoreItem]
}

struct LoreItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let meta: String
    let note: String
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
    let points: [[Double]]?
}

struct MapStyle: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let inspiration: String
    let colors: [String: String]
    let pattern: String
    let pathStyle: String
    let font: String
    let orientation: String
    let frame: String
    let care: String?
}

struct MapStamp: Decodable, Hashable {
    let label: String
    let color: String
    let shapes: [PortraitShape]
}
