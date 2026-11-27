import Foundation
import Combine
import ServiceManagement

/// Official Pokémon pixel-art series supported by PokéRun.
enum SpriteStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case blackWhite = "bw"
    case fireRed = "fr"
    case hgss = "hgss"
    case emerald = "em"
    case crystal = "cry"

    var id: String { rawValue }

    var badge: String {
        switch self {
        case .blackWhite: return "B/W"
        case .fireRed: return "FireRed"
        case .hgss: return "HGSS"
        case .emerald: return "Emerald"
        case .crystal: return "Crystal"
        }
    }

    var title: String {
        switch self {
        case .blackWhite: return "Black & White"
        case .fireRed: return "FireRed Pixel"
        case .hgss: return "HeartGold & SoulSilver"
        case .emerald: return "Emerald"
        case .crystal: return "Crystal"
        }
    }

    var shortFilterLabel: String {
        switch self {
        case .blackWhite: return "B/W"
        case .fireRed: return "FireRed"
        case .hgss: return "HGSS"
        case .emerald: return "Emerald"
        case .crystal: return "Crystal"
        }
    }

    var subdirectory: String {
        switch self {
        case .blackWhite: return "sprites"
        case .fireRed: return "sprites_firered"
        case .hgss: return "sprites_hgss"
        case .emerald: return "sprites_emerald"
        case .crystal: return "sprites_crystal"
        }
    }

    var fileExtension: String {
        switch self {
        case .blackWhite, .crystal: return "gif"
        case .fireRed, .hgss, .emerald: return "png"
        }
    }

    var maxID: Int {
        switch self {
        case .blackWhite: return 649
        case .fireRed: return 386
        case .hgss: return 493
        case .emerald: return 386
        case .crystal: return 251
        }
    }
}

/// Identifies a single selectable Pokémon runner (series + National Pokédex number).
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
           (1...style.maxID).contains(id) {
            self.style = style
            self.dexID = id
        } else if let id = Int(key), (1...SpriteStyle.blackWhite.maxID).contains(id) {
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
    static let defaultHGSSIDs = [25, 1, 4, 6, 7, 94, 133, 143, 151, 249, 250, 387, 390, 393, 445, 448, 493]
    static let defaultEmeraldIDs = [252, 255, 257, 258, 282, 306, 330, 359, 373, 376, 380, 381, 382, 383, 384]
    static let defaultCrystalIDs = [25, 6, 94, 131, 143, 151, 152, 155, 157, 158, 175, 197, 212, 245, 248, 249, 250, 251]

    static let defaultNewSeriesRoster: [RunnerItem] =
        defaultHGSSIDs.map { RunnerItem(style: .hgss, dexID: $0) } +
        defaultEmeraldIDs.map { RunnerItem(style: .emerald, dexID: $0) } +
        defaultCrystalIDs.map { RunnerItem(style: .crystal, dexID: $0) }

    static let defaultRoster: [RunnerItem] =
        defaultBWIDs.map { RunnerItem(style: .blackWhite, dexID: $0) } +
        defaultFireRedIDs.map { RunnerItem(style: .fireRed, dexID: $0) } +
        defaultNewSeriesRoster

    static let defaultRunner = RunnerItem(style: .blackWhite, dexID: 25)

    private let defaults = UserDefaults.standard

    @Published var roster: [RunnerItem] {
        didSet { defaults.set(roster.map(\.key), forKey: Keys.rosterV3) }
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
        if let v3Keys = d.stringArray(forKey: Keys.rosterV3) {
            let parsed = v3Keys.compactMap(RunnerItem.init(key:))
            initialRoster = parsed.isEmpty ? Self.defaultRoster : parsed
        } else if let v2Keys = d.stringArray(forKey: Keys.rosterV2) {
            // Preserve existing B/W + FireRed roster and append HGSS, Emerald, and Crystal favourites.
            var migrated = v2Keys.compactMap(RunnerItem.init(key:))
            for item in Self.defaultNewSeriesRoster where !migrated.contains(item) {
                migrated.append(item)
            }
            initialRoster = migrated.isEmpty ? Self.defaultRoster : migrated
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV3)
        } else if let legacyIDs = d.array(forKey: Keys.rosterLegacy) as? [Int], !legacyIDs.isEmpty {
            let bw = legacyIDs.compactMap { (1...SpriteStyle.blackWhite.maxID).contains($0) ? RunnerItem(style: .blackWhite, dexID: $0) : nil }
            let fr = Self.defaultFireRedIDs.map { RunnerItem(style: .fireRed, dexID: $0) }
            let migrated = bw + fr + Self.defaultNewSeriesRoster
            initialRoster = migrated.isEmpty ? Self.defaultRoster : migrated
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV3)
        } else {
            initialRoster = Self.defaultRoster
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV3)
        }

        let initialSelected: RunnerItem
        if let selKey = d.string(forKey: Keys.selectedV2), let item = RunnerItem(key: selKey) {
            initialSelected = item
        } else if let legacySel = d.object(forKey: Keys.selectedLegacy) as? Int,
                  (1...SpriteStyle.blackWhite.maxID).contains(legacySel) {
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
