import AppKit
import SwiftUI

/// Developer aid: `PokeRun --snapshot <dir>` renders the menu panel, settings tabs and
/// menu bar frames (both Black/White and FireRed) to PNG files, then exits.
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

        // Menu bar strips: Black & White row on top, FireRed row below (both frames shown for FireRed!).
        let bwItems = settings.roster.filter { $0.style == .blackWhite }
        let frItems = settings.roster.filter { $0.style == .fireRed }

        let strip = VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(bwItems) { item in
                    if let img = store.runnerFrames(for: item)?.images.first {
                        Image(nsImage: img).interpolation(.none)
                    }
                }
            }
            .frame(height: 24)

            HStack(spacing: 12) {
                ForEach(frItems) { item in
                    if let rf = store.runnerFrames(for: item), rf.images.count >= 2 {
                        VStack(spacing: 2) {
                            Image(nsImage: rf.images[0]).interpolation(.none)
                            Image(nsImage: rf.images[1]).interpolation(.none)
                        }
                    }
                }
            }
        }
        .padding(8)
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
