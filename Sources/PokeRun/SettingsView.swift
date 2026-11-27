import SwiftUI
import ServiceManagement

enum SettingsTab: Hashable, CaseIterable {
    case general, runners, about

    var title: String {
        switch self {
        case .general: return "General"
        case .runners: return "Runners"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .runners: return "hare"
        case .about: return "info.circle"
        }
    }
}

/// Lets the menu open the settings window on a specific tab.
final class SettingsNavigator: ObservableObject {
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var navigator: SettingsNavigator
    let store: SpriteStore

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch navigator.tab {
                case .general:
                    GeneralSettingsView(settings: settings)
                case .runners:
                    RunnersSettingsView(settings: settings, store: store)
                case .about:
                    AboutView(settings: settings, store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 550)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                let active = navigator.tab == tab
                Button {
                    navigator.tab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .medium))
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(active ? Color.accentColor : Color.secondary)
                    .frame(width: 76, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(active ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: General

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginStatus = LaunchAtLogin.status
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LaunchAtLogin.set(newValue)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                        }
                        launchAtLogin = LaunchAtLogin.isEnabled
                        loginStatus = LaunchAtLogin.status
                    }
                if loginStatus == .requiresApproval {
                    HStack {
                        Text("Approve PokéRun in Login Items to finish enabling.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Runner") {
                Toggle("Pause runner", isOn: $settings.paused)
                Toggle("Invert horizontally (face the other way)", isOn: $settings.flipHorizontally)
                Toggle("Invert speed (faster when the CPU is idle)", isOn: $settings.invertSpeed)
            }

            Section("Performance") {
                Picker("Speed limit", selection: $settings.speedLimit) {
                    ForEach(SpeedLimit.allCases) { Text($0.label).tag($0) }
                }
                Picker("FPS limit", selection: $settings.fpsLimit) {
                    ForEach(FPSLimit.allCases) { Text($0.label).tag($0) }
                }
                Text("The runner speeds up as CPU usage rises: slow at idle, up to 5× at 100%. Lower limits use less energy.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            loginStatus = LaunchAtLogin.status
        }
    }
}

// MARK: Runners

struct RunnersSettingsView: View {
    @ObservedObject var settings: AppSettings
    let store: SpriteStore
    @State private var query = ""
    @State private var styleFilter: DexStyleFilter = .all
    @State private var selection: RunnerItem?

    var body: some View {
        HStack(spacing: 0) {
            // Current roster
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your Runners").font(.headline)
                    Spacer()
                    Text("\(settings.roster.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(settings.roster.enumerated()), id: \.element) { index, item in
                            rosterRow(item, index: index)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.14), lineWidth: 1))

                HStack(spacing: 6) {
                    Button("Use as Runner") {
                        if let s = selection { settings.selectedRunner = s }
                    }
                    .disabled(selection == nil)
                    Button("Remove") {
                        if let s = selection { settings.removeFromRoster(s); selection = nil }
                    }
                    .disabled(selection == nil || settings.roster.count <= 1)
                    Spacer()
                    Button("Reset") { settings.resetRoster() }
                        .help("Restore default favourites across all 7 series")
                }
                .controlSize(.small)
            }
            .padding(14)
            .frame(width: 280)

            Divider()

            // Pokédex search across all 7 series (3,215 sprites, Gen 1–9 + Alola)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Add from Pokédex").font(.headline)
                    Spacer()
                    Text(seriesRangeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                filterBar

                TextField("Search Rowlet, Mimikyu, Alola, #722, etc.", text: $query)
                    .textFieldStyle(.roundedBorder)

                let matches = store.search(query, filter: styleFilter)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element) { index, item in
                            pokedexRow(item, index: index)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.14), lineWidth: 1))
            }
            .padding(14)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(DexStyleFilter.allCases) { f in
                let active = styleFilter == f
                Button {
                    styleFilter = f
                } label: {
                    Text(f.label)
                        .font(.caption2.weight(active ? .semibold : .regular))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .foregroundStyle(active ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var seriesRangeLabel: String {
        switch styleFilter {
        case .all: return "3,215 sprites · Gen 1–9"
        case .series(let s): return "\(s.title) · \(s.validIDs.count)"
        }
    }

    private func rosterRow(_ item: RunnerItem, index: Int) -> some View {
        let isSelected = selection == item
        return HStack(spacing: 8) {
            SpriteThumb(item: item, store: store)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.speciesName(item.dexID)).lineLimit(1)
                Text(store.subtitle(item))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
            Spacer()
            if settings.selectedRunner == item {
                Image(systemName: "figure.run")
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .help("Current runner")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            isSelected
                ? Color.accentColor
                : (index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            selection = item
            settings.selectedRunner = item
        })
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            selection = item
        })
        .contextMenu {
            Button("Use as Runner") { settings.selectedRunner = item }
            if index > 0 {
                Button("Move Up") {
                    settings.roster.swapAt(index, index - 1)
                }
            }
            if index < settings.roster.count - 1 {
                Button("Move Down") {
                    settings.roster.swapAt(index, index + 1)
                }
            }
            Divider()
            Button("Remove") { settings.removeFromRoster(item) }
                .disabled(settings.roster.count <= 1)
        }
    }

    private func pokedexRow(_ item: RunnerItem, index: Int) -> some View {
        let inRoster = settings.roster.contains(item)
        return HStack(spacing: 8) {
            SpriteThumb(item: item, store: store)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.speciesName(item.dexID)).lineLimit(1)
                Text(store.subtitle(item))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if inRoster {
                if settings.selectedRunner == item {
                    Text("Active").font(.caption2).foregroundStyle(.tint)
                } else {
                    Button("Use") { settings.selectedRunner = item }
                        .controlSize(.small)
                }
                Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Add") { settings.addToRoster(item) }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            settings.addToRoster(item)
            settings.selectedRunner = item
        }
    }
}

private struct SpriteThumb: View {
    let item: RunnerItem
    let store: SpriteStore

    var body: some View {
        Group {
            if let img = store.thumbnail(for: item, height: 28) {
                Image(nsImage: img).interpolation(.none)
            } else {
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 30)
    }
}

// MARK: About

struct AboutView: View {
    @ObservedObject var settings: AppSettings
    let store: SpriteStore

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        let runner = settings.selectedRunner
        VStack(spacing: 12) {
            AnimatedSprite(item: runner, height: 64, flipped: settings.flipHorizontally)
                .frame(height: 76)
            Text("PokéRun").font(.largeTitle.bold())
            Text("Version \(version) · Personal build · \(store.speciesName(runner.dexID)) (\(store.subtitle(runner)))")
                .foregroundStyle(.secondary)
            Text("A RunCat-style menu bar runner starring 3,215 Pokémon across Generations 1–9 (including full Gen 7 Alola & Alolan forms).")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Divider().frame(width: 400)
            VStack(spacing: 4) {
                Text("Series: Black & White · FireRed · Sun & Moon (Gen 7 Alola) · Gen 6–9 Pixel")
                Text("Walking Followers (#001–#1025 + Alola) · Emerald · Crystal")
                Text("© Nintendo / Creatures Inc. / GAME FREAK inc. / The Pokémon Company")
                Text("Inspired by RunCat by Kyome. Built for personal use only.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
