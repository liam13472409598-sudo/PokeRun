import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let settings = AppSettings.shared
    private let store = SpriteStore.shared
    private let monitor = SystemMonitor()
    private let animator = RunnerAnimator()

    private let menu = NSMenu()
    private let runnerMenu = NSMenu()
    private var headerItem: NSMenuItem!
    private var headerHost: NSHostingView<MenuHeaderView>!
    private var pauseItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private let navigator = SettingsNavigator()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleNone
        animator.button = statusItem.button

        buildMenu()
        statusItem.menu = menu

        animator.maxFPS = settings.fpsLimit.rawValue
        animator.flipped = settings.flipHorizontally
        animator.paused = settings.paused
        loadRunner(settings.selectedRunner)

        monitor.onCPUUpdate = { [weak self] cpu in self?.updateSpeed(cpu: cpu) }
        monitor.start()

        bindSettings()
    }

    // MARK: Runner

    private func loadRunner(_ runner: RunnerItem) {
        let frames = store.runnerFrames(for: runner) ?? store.runnerFrames(for: AppSettings.defaultRunner)
        animator.setFrames(frames)
        updateTooltip()
    }

    /// Maps CPU usage to playback rate, like RunCat: slow stroll when idle, sprint at full load.
    private func updateSpeed(cpu: Double) {
        let load = min(max(cpu / 100, 0), 1)
        let effective = settings.invertSpeed ? 1 - load : load
        let rate = 0.5 + 4.5 * effective
        animator.rate = min(rate, settings.speedLimit.maxRate)
        updateTooltip()
    }

    private func updateTooltip() {
        let runner = settings.selectedRunner
        statusItem.button?.toolTip = "\(store.displayName(runner)) — CPU \(Fmt.percent(monitor.cpu.usage))"
    }

    private func bindSettings() {
        settings.$selectedRunner.dropFirst().removeDuplicates()
            .sink { [weak self] runner in self?.loadRunner(runner) }
            .store(in: &cancellables)
        settings.$flipHorizontally.dropFirst()
            .sink { [weak self] v in self?.animator.flipped = v }
            .store(in: &cancellables)
        settings.$paused.dropFirst()
            .sink { [weak self] v in
                self?.animator.paused = v
                self?.pauseItem.state = v ? .on : .off
            }
            .store(in: &cancellables)
        settings.$fpsLimit.dropFirst()
            .sink { [weak self] v in self?.animator.maxFPS = v.rawValue }
            .store(in: &cancellables)
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        headerHost = NSHostingView(rootView: MenuHeaderView(monitor: monitor, settings: settings, store: store))
        headerHost.frame.size = headerHost.fittingSize
        headerItem = NSMenuItem()
        headerItem.view = headerHost
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let runnerItem = NSMenuItem(title: "Runner", action: nil, keyEquivalent: "")
        runnerItem.image = NSImage(systemSymbolName: "hare", accessibilityDescription: nil)
        runnerMenu.delegate = self
        runnerMenu.autoenablesItems = false
        runnerItem.submenu = runnerMenu
        menu.addItem(runnerItem)

        pauseItem = NSMenuItem(title: "Pause Runner", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        pauseItem.state = settings.paused ? .on : .off
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let activity = NSMenuItem(title: "Open Activity Monitor", action: #selector(openActivityMonitor), keyEquivalent: "")
        activity.target = self
        menu.addItem(activity)

        let prefs = NSMenuItem(title: "Settings…", action: #selector(openGeneralSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let about = NSMenuItem(title: "About PokéRun", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit PokéRun", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        monitor.refreshAll()
        headerHost.frame.size = headerHost.fittingSize
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === runnerMenu else { return }
        menu.removeAllItems()

        // Group roster into ordered per-series submenus so all 5 series stay quick to browse.
        var orderedStyles: [SpriteStyle] = []
        var grouped: [SpriteStyle: [RunnerItem]] = [:]
        for runner in settings.roster {
            if grouped[runner.style] == nil {
                orderedStyles.append(runner.style)
                grouped[runner.style] = []
            }
            grouped[runner.style]?.append(runner)
        }

        if orderedStyles.count <= 1 {
            for runner in settings.roster {
                menu.addItem(makeRunnerMenuItem(runner, includeSeriesSuffix: false))
            }
        } else {
            for style in orderedStyles {
                guard let items = grouped[style], !items.isEmpty else { continue }
                let sub = NSMenu(title: style.title)
                sub.autoenablesItems = false
                for runner in items {
                    sub.addItem(makeRunnerMenuItem(runner, includeSeriesSuffix: false))
                }
                let parent = NSMenuItem(title: style.title, action: nil, keyEquivalent: "")
                if let sample = items.first(where: { $0 == settings.selectedRunner }) ?? items.first {
                    parent.image = store.thumbnail(for: sample, height: 18)
                }
                parent.state = settings.selectedRunner.style == style ? .on : .off
                parent.submenu = sub
                menu.addItem(parent)
            }
        }

        menu.addItem(.separator())
        let random = NSMenuItem(title: "Random Runner", action: #selector(selectRandomRunner), keyEquivalent: "r")
        random.target = self
        menu.addItem(random)
        let manage = NSMenuItem(title: "Manage Runners…", action: #selector(openRunnersSettings), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
    }

    private func makeRunnerMenuItem(_ runner: RunnerItem, includeSeriesSuffix: Bool) -> NSMenuItem {
        let title = includeSeriesSuffix ? store.displayName(runner) : store.speciesName(runner.dexID)
        let item = NSMenuItem(title: title, action: #selector(selectRunner(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = runner.key
        item.image = store.thumbnail(for: runner, height: 18)
        item.state = runner == settings.selectedRunner ? .on : .off
        return item
    }

    @objc private func selectRunner(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let runner = RunnerItem(key: key) else { return }
        settings.selectedRunner = runner
    }

    @objc private func selectRandomRunner() {
        let candidates = settings.roster.filter { $0 != settings.selectedRunner }
        if let pick = (candidates.isEmpty ? settings.roster : candidates).randomElement() {
            settings.selectedRunner = pick
        }
    }

    @objc private func togglePause() {
        settings.paused.toggle()
    }

    @objc private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func openRunnersSettings() { openSettings(tab: .runners) }

    @objc private func openAbout() { openSettings(tab: .about) }

    @objc private func openGeneralSettings() { openSettings(tab: .general) }

    func openSettings(tab: SettingsTab) {
        navigator.tab = tab
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings, navigator: navigator, store: store))
            let window = NSWindow(contentViewController: host)
            window.title = "PokéRun Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Accessory apps have no menu bar, so add a hidden Edit menu to make ⌘C/⌘V/⌘A work in text fields.
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit PokéRun", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
