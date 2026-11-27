import AppKit
import SwiftUI

/// Developer aid: `PokeRun --snapshot <dir>` renders the menu panel, settings tabs and
/// menu bar sample strips across all 5 series to PNG files, then exits.
enum Snapshot {
    @MainActor
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let monitor = SystemMonitor()
        monitor.start()
        RunLoop.main.run(until: Date().addingTimeInterval(2.2))
        monitor.refreshAll()

        let settings = AppSettings.shared
        let store = SpriteStore.shared

        write(MenuHeaderView(monitor: monitor, settings: settings, store: store)
                .background(Color(nsColor: .windowBackgroundColor)), to: dir.appendingPathComponent("menu.png"))
        let nav = SettingsNavigator()
        for tab in [SettingsTab.general, .runners, .about] {
            nav.tab = tab
            write(SettingsView(settings: settings, navigator: nav, store: store)
                    .background(Color(nsColor: .windowBackgroundColor)),
                  to: dir.appendingPathComponent("settings-\(tab).png"))
        }

        let strip = VStack(alignment: .leading, spacing: 10) {
            ForEach(SpriteStyle.allCases) { style in
                let items = Array(settings.roster.filter { $0.style == style }.prefix(14))
                HStack(spacing: 12) {
                    Text(style.badge)
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .frame(width: 60, alignment: .leading)
                    ForEach(items) { item in
                        if let rf = store.runnerFrames(for: item), let img = rf.images.first {
                            Image(nsImage: img).interpolation(.none)
                        }
                    }
                }
                .frame(height: 24)
            }
        }
        .padding(10)
        .background(Color(white: 0.92))
        write(strip, to: dir.appendingPathComponent("menubar.png"))
        print("snapshots written to \(dir.path)")
        exit(0)
    }

    @MainActor
    private static func write<V: View>(_ view: V, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }
}
