import AppKit

// PokéRun — a RunCat-style menu bar runner starring pixel Pokémon.
// The runner animates faster as CPU usage rises.

let app = NSApplication.shared
MainActor.assumeIsolated { Snapshot.runIfRequested() }
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
