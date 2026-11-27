import Foundation
import Combine
import ServiceManagement

/// Official Pokémon pixel & animated series supported by PokéRun.
enum SpriteStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case blackWhite = "bw"
    case fireRed = "fr"
    case alola = "alola"
    case modernPixel = "modern"
    case hgss = "hgss"
    case emerald = "em"
    case crystal = "cry"

    var id: String { rawValue }

    var badge: String {
        switch self {
        case .blackWhite: return "B/W"
        case .fireRed: return "FireRed"
        case .alola: return "Gen 7 · SM"
        case .modernPixel: return "Gen 6–9 Px"
        case .hgss: return "Walking"
        case .emerald: return "Emerald"
        case .crystal: return "Crystal"
        }
    }

    var title: String {
        switch self {
        case .blackWhite: return "Black & White (#001–#649)"
        case .fireRed: return "FireRed Pixel (#001–#386)"
        case .alola: return "Sun & Moon · Gen 7 Alola"
        case .modernPixel: return "Alola & Gen 6–9 Pixel"
        case .hgss: return "Walking Followers (Gen 1–9)"
        case .emerald: return "Emerald (#001–#386)"
        case .crystal: return "Crystal (#001–#251)"
        }
    }

    var shortFilterLabel: String {
        switch self {
        case .blackWhite: return "B/W"
        case .fireRed: return "FireRed"
        case .alola: return "Gen 7"
        case .modernPixel: return "6–9 Px"
        case .hgss: return "Walk"
        case .emerald: return "Emerald"
        case .crystal: return "Crystal"
        }
    }

    var subdirectory: String {
        switch self {
        case .blackWhite: return "sprites"
        case .fireRed: return "sprites_firered"
        case .alola: return "sprites_alola"
        case .modernPixel: return "sprites_modern"
        case .hgss: return "sprites_hgss"
        case .emerald: return "sprites_emerald"
        case .crystal: return "sprites_crystal"
        }
    }

    var fileExtension: String {
        switch self {
        case .blackWhite, .alola, .crystal: return "gif"
        case .fireRed, .modernPixel, .hgss, .emerald: return "png"
        }
    }

    /// Valid runner IDs for each series (1..1025 National Dex + 1026..1043 Alolan Regional Forms).
    var validIDs: [Int] {
        switch self {
        case .blackWhite:
            return Array(1...649)
        case .fireRed, .emerald:
            return Array(1...386)
        case .alola:
            return Array(722...809) + Array(1026...1043)
        case .modernPixel:
            // Lead with Gen 7 Alola + Alolan forms, followed by Gen 6, Gen 8, and Gen 9.
            return Array(722...809) + Array(1026...1043) + Array(650...721) + Array(810...1025)
        case .hgss:
            return Array(1...1043)
        case .crystal:
            return Array(1...251)
        }
    }

    func contains(_ id: Int) -> Bool {
        switch self {
        case .blackWhite: return (1...649).contains(id)
        case .fireRed, .emerald: return (1...386).contains(id)
        case .alola: return (722...809).contains(id) || (1026...1043).contains(id)
        case .modernPixel: return (650...1043).contains(id)
        case .hgss: return (1...1043).contains(id)
        case .crystal: return (1...251).contains(id)
        }
    }
}

/// Base Kanto National Dex numbers for the 18 Alolan Regional Forms (runner IDs 1026..1043).
enum AlolaForms {
    static let baseDexByRunnerID: [Int: Int] = [
        1026: 19,  1027: 20,  1028: 26,  1029: 27,  1030: 28,  1031: 37,
        1032: 38,  1033: 50,  1034: 51,  1035: 52,  1036: 53,  1037: 74,
        1038: 75,  1039: 76,  1040: 88,  1041: 89,  1042: 103, 1043: 105,
    ]
}

/// Identifies a single selectable Pokémon runner (series + runner ID).
struct RunnerItem: Hashable, Codable, Identifiable {
    let style: SpriteStyle
    let dexID: Int

    var id: String { key }
    var key: String { "\(style.rawValue):\(dexID)" }

    init(style: SpriteStyle, dexID: Int) {
        self.style = style
        self.dexID = dexID
    }

    init?(key: String) {
        let parts = key.split(separator: ":")
        if parts.count == 2,
           let style = SpriteStyle(rawValue: String(parts[0])),
           let id = Int(parts[1]),
           style.contains(id) {
            self.style = style
            self.dexID = id
        } else if let id = Int(key), SpriteStyle.blackWhite.contains(id) {
            self.style = .blackWhite
            self.dexID = id
        } else {
            return nil
        }
    }
}

/// Caps how fast the runner may animate.
enum SpeedLimit: Int, CaseIterable, Identifiable {
    case none = 0, fast, moderate, slow

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .fast: return "Fast (3×)"
        case .moderate: return "Moderate (2×)"
        case .slow: return "Slow (1×)"
        }
    }

    var maxRate: Double {
        switch self {
        case .none: return 5.0
        case .fast: return 3.0
        case .moderate: return 2.0
        case .slow: return 1.0
        }
    }
}

/// Caps how often the menu bar image is redrawn.
enum FPSLimit: Int, CaseIterable, Identifiable {
    case fps60 = 60, fps40 = 40, fps30 = 30, fps20 = 20, fps10 = 10

    var id: Int { rawValue }
    var label: String { "\(rawValue) fps" }
}

/// All user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultBWIDs = [1, 4, 6, 7, 25, 39, 52, 54, 94, 133, 143, 149, 150, 151, 175, 258, 393, 448]
    static let defaultFireRedIDs = [1, 4, 6, 7, 25, 39, 52, 54, 59, 94, 131, 133, 143, 149, 150, 151, 258, 384]
    /// Beloved Gen 7 Alola favourites + Alolan Regional Forms!
    static let defaultAlolaIDs = [722, 724, 725, 727, 728, 730, 744, 745, 778, 785, 789, 791, 792, 800, 802, 807, 809, 1028, 1031, 1032, 1042, 1043]
    /// GBA-style pixel battle sprites for Gen 7 Alola + Gen 6/8/9 fan favourites.
    static let defaultModernPixelIDs = [722, 724, 725, 728, 745, 778, 791, 792, 807, 1028, 1031, 658, 700, 810, 813, 887, 906, 909, 937, 959, 1007, 1008, 1017]
    static let defaultHGSSIDs = [25, 1, 4, 6, 7, 94, 133, 143, 151, 249, 250, 387, 390, 393, 445, 448, 493, 722, 724, 725, 728, 744, 778, 791, 792, 807, 1028, 1031, 658, 700, 906, 937]
    static let defaultEmeraldIDs = [252, 255, 257, 258, 282, 306, 330, 359, 373, 376, 380, 381, 382, 383, 384]
    static let defaultCrystalIDs = [25, 6, 94, 131, 143, 151, 152, 155, 157, 158, 175, 197, 212, 245, 248, 249, 250, 251]

    static let defaultGen7Additions: [RunnerItem] =
        defaultAlolaIDs.map { RunnerItem(style: .alola, dexID: $0) } +
        defaultModernPixelIDs.map { RunnerItem(style: .modernPixel, dexID: $0) } +
        [722, 724, 725, 728, 744, 778, 791, 792, 807, 1028, 1031, 658, 700, 906, 937].map { RunnerItem(style: .hgss, dexID: $0) }

    static let defaultRoster: [RunnerItem] =
        defaultBWIDs.map { RunnerItem(style: .blackWhite, dexID: $0) } +
        defaultFireRedIDs.map { RunnerItem(style: .fireRed, dexID: $0) } +
        defaultAlolaIDs.map { RunnerItem(style: .alola, dexID: $0) } +
        defaultModernPixelIDs.map { RunnerItem(style: .modernPixel, dexID: $0) } +
        defaultHGSSIDs.map { RunnerItem(style: .hgss, dexID: $0) } +
        defaultEmeraldIDs.map { RunnerItem(style: .emerald, dexID: $0) } +
        defaultCrystalIDs.map { RunnerItem(style: .crystal, dexID: $0) }

    static let defaultRunner = RunnerItem(style: .blackWhite, dexID: 25)

    private let defaults = UserDefaults.standard

    @Published var roster: [RunnerItem] {
        didSet { defaults.set(roster.map(\.key), forKey: Keys.rosterV4) }
    }
    @Published var selectedRunner: RunnerItem {
        didSet { defaults.set(selectedRunner.key, forKey: Keys.selectedV2) }
    }
    @Published var flipHorizontally: Bool { didSet { defaults.set(flipHorizontally, forKey: Keys.flip) } }
    @Published var invertSpeed: Bool { didSet { defaults.set(invertSpeed, forKey: Keys.invertSpeed) } }
    @Published var paused: Bool { didSet { defaults.set(paused, forKey: Keys.paused) } }
    @Published var speedLimit: SpeedLimit { didSet { defaults.set(speedLimit.rawValue, forKey: Keys.speedLimit) } }
    @Published var fpsLimit: FPSLimit { didSet { defaults.set(fpsLimit.rawValue, forKey: Keys.fpsLimit) } }

    private enum Keys {
        static let rosterLegacy = "roster"
        static let selectedLegacy = "selectedID"
        static let rosterV2 = "rosterV2"
        static let rosterV3 = "rosterV3"
        static let rosterV4 = "rosterV4"
        static let selectedV2 = "selectedRunnerV2"
        static let flip = "flipHorizontally"
        static let invertSpeed = "invertSpeed"
        static let paused = "paused"
        static let speedLimit = "speedLimit"
        static let fpsLimit = "fpsLimit"
    }

    private init() {
        let d = UserDefaults.standard

        let initialRoster: [RunnerItem]
        if let v4Keys = d.stringArray(forKey: Keys.rosterV4) {
            let parsed = v4Keys.compactMap(RunnerItem.init(key:))
            initialRoster = parsed.isEmpty ? Self.defaultRoster : parsed
        } else if let prevKeys = d.stringArray(forKey: Keys.rosterV3) ?? d.stringArray(forKey: Keys.rosterV2) {
            // Preserve user's existing runners and insert/append Gen 7 Alola + Gen 6–9 favourites!
            var migrated = prevKeys.compactMap(RunnerItem.init(key:))
            for item in Self.defaultGen7Additions where !migrated.contains(item) {
                migrated.append(item)
            }
            initialRoster = migrated.isEmpty ? Self.defaultRoster : migrated
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV4)
        } else {
            initialRoster = Self.defaultRoster
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV4)
        }

        let initialSelected: RunnerItem
        if let selKey = d.string(forKey: Keys.selectedV2), let item = RunnerItem(key: selKey) {
            initialSelected = item
        } else if let legacySel = d.object(forKey: Keys.selectedLegacy) as? Int,
                  SpriteStyle.blackWhite.contains(legacySel) {
            initialSelected = RunnerItem(style: .blackWhite, dexID: legacySel)
            d.set(initialSelected.key, forKey: Keys.selectedV2)
        } else {
            initialSelected = Self.defaultRunner
        }

        roster = initialRoster
        selectedRunner = initialSelected
        flipHorizontally = d.bool(forKey: Keys.flip)
        invertSpeed = d.bool(forKey: Keys.invertSpeed)
        paused = d.bool(forKey: Keys.paused)
        speedLimit = SpeedLimit(rawValue: d.integer(forKey: Keys.speedLimit)) ?? .none
        fpsLimit = FPSLimit(rawValue: d.object(forKey: Keys.fpsLimit) as? Int ?? 40) ?? .fps40
    }

    func addToRoster(_ item: RunnerItem) {
        guard !roster.contains(item) else { return }
        roster.append(item)
    }

    func removeFromRoster(_ item: RunnerItem) {
        guard roster.count > 1 else { return }
        roster.removeAll { $0 == item }
        if selectedRunner == item, let first = roster.first { selectedRunner = first }
    }

    func resetRoster() {
        roster = Self.defaultRoster
        if !roster.contains(selectedRunner) { selectedRunner = Self.defaultRunner }
    }
}

/// Launch-at-login via the modern ServiceManagement API.
enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static var isEnabled: Bool { status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
