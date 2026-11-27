import Foundation
import Combine
import ServiceManagement

/// Which official Pokémon pixel-art set a runner comes from.
enum SpriteStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case blackWhite = "bw"
    case fireRed = "fr"

    var id: String { rawValue }

    var badge: String {
        switch self {
        case .blackWhite: return "B/W"
        case .fireRed: return "FireRed"
        }
    }

    var title: String {
        switch self {
        case .blackWhite: return "Black & White"
        case .fireRed: return "FireRed"
        }
    }

    var maxID: Int {
        switch self {
        case .blackWhite: return 649
        case .fireRed: return 386
        }
    }
}

/// Identifies a single selectable Pokémon runner (style + National Pokédex number).
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

    /// Maximum playback-rate multiplier.
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

    /// Curated Black & White favourites (#001–#649).
    static let defaultBWIDs = [1, 4, 6, 7, 25, 39, 52, 54, 94, 133, 143, 149, 150, 151, 175, 258, 393, 448]
    /// Curated FireRed pixel favourites (#001–#386), placed after the original Black & White runners.
    static let defaultFireRedIDs = [1, 4, 6, 7, 25, 39, 52, 54, 59, 94, 131, 133, 143, 149, 150, 151, 258, 384]

    static let defaultRoster: [RunnerItem] =
        defaultBWIDs.map { RunnerItem(style: .blackWhite, dexID: $0) } +
        defaultFireRedIDs.map { RunnerItem(style: .fireRed, dexID: $0) }

    static let defaultRunner = RunnerItem(style: .blackWhite, dexID: 25)

    private let defaults = UserDefaults.standard

    @Published var roster: [RunnerItem] {
        didSet { defaults.set(roster.map(\.key), forKey: Keys.rosterV2) }
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
        if let storedKeys = d.stringArray(forKey: Keys.rosterV2) {
            let parsed = storedKeys.compactMap(RunnerItem.init(key:))
            initialRoster = parsed.isEmpty ? Self.defaultRoster : parsed
        } else if let legacyIDs = d.array(forKey: Keys.rosterLegacy) as? [Int], !legacyIDs.isEmpty {
            // Migrate v1 Black & White roster and append the FireRed favourites right after them.
            let bw = legacyIDs.compactMap { (1...SpriteStyle.blackWhite.maxID).contains($0) ? RunnerItem(style: .blackWhite, dexID: $0) : nil }
            let fr = Self.defaultFireRedIDs.map { RunnerItem(style: .fireRed, dexID: $0) }
            let migrated = bw + fr
            initialRoster = migrated.isEmpty ? Self.defaultRoster : migrated
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV2)
        } else {
            initialRoster = Self.defaultRoster
            d.set(initialRoster.map(\.key), forKey: Keys.rosterV2)
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
        guard roster.count > 1 else { return } // always keep at least one runner
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
