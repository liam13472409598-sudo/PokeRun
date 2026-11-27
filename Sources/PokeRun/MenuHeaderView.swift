import SwiftUI

/// The live system-info panel shown at the top of the menu bar dropdown.
struct MenuHeaderView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    let store: SpriteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            runnerHeader
            Divider()
            cpuSection
            memorySection
            storageSection
            if monitor.battery.present { batterySection }
            networkSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 300, alignment: .leading)
    }

    // MARK: Sections

    private var runnerHeader: some View {
        let runner = settings.selectedRunner
        return HStack(spacing: 10) {
            AnimatedSprite(item: runner, height: 36, paused: settings.paused, flipped: settings.flipHorizontally)
                .frame(width: 56, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.displayName(runner)).font(.headline)
                Text(runnerStatus).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(store.subtitle(runner))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private var runnerStatus: String {
        if settings.paused { return "Resting (paused)" }
        let cpu = monitor.cpu.usage
        switch cpu {
        case ..<10: return "Strolling"
        case ..<35: return "Jogging"
        case ..<70: return "Running"
        default: return "Sprinting!"
        }
    }

    private var cpuSection: some View {
        MetricSection(icon: "cpu", title: "CPU", value: Fmt.percent(monitor.cpu.usage),
                      fraction: monitor.cpu.usage / 100) {
            DetailRow("System", Fmt.percent(monitor.cpu.system))
            DetailRow("User", Fmt.percent(monitor.cpu.user))
            DetailRow("Idle", Fmt.percent(monitor.cpu.idle))
        }
    }

    private var memorySection: some View {
        let m = monitor.memory
        let pressureColor: Color = m.pressure < 60 ? .green : (m.pressure < 80 ? .yellow : .red)
        return MetricSection(icon: "memorychip", title: "Memory",
                             value: "\(Fmt.bytes(m.used)) / \(Fmt.bytes(m.total))",
                             fraction: m.usedFraction, barColor: pressureColor) {
            DetailRow("Pressure", Fmt.percent(m.pressure))
            DetailRow("App Memory", Fmt.bytes(m.app))
            DetailRow("Wired", Fmt.bytes(m.wired))
            DetailRow("Compressed", Fmt.bytes(m.compressed))
            DetailRow("Cached Files", Fmt.bytes(m.cached))
        }
    }

    private var storageSection: some View {
        let s = monitor.storage
        return MetricSection(icon: "internaldrive", title: "Storage",
                             value: "\(Fmt.disk(s.used)) / \(Fmt.disk(s.total))",
                             fraction: s.usedFraction) {
            DetailRow(s.volumeName, "\(Fmt.disk(s.available)) available")
        }
    }

    private var batterySection: some View {
        let b = monitor.battery
        return MetricSection(icon: batteryIcon(b), title: "Battery", value: "\(b.percent)%",
                             fraction: Double(b.percent) / 100, barColor: batteryColor(b)) {
            DetailRow("Power Source", b.onACPower ? "Power Adapter" : "Battery")
            DetailRow("State", b.isCharging ? "Charging" : (b.isCharged || (b.onACPower && b.percent >= 99) ? "Charged" : (b.onACPower ? "Not Charging" : "Discharging")))
            if let m = b.minutesRemaining {
                DetailRow(b.isCharging ? "Time to Full" : "Time Remaining", Fmt.minutes(m))
            }
            if let h = b.healthPercent { DetailRow("Maximum Capacity", "\(h)%") }
            if let c = b.cycleCount { DetailRow("Cycle Count", "\(c)") }
            if b.lowPowerMode { DetailRow("Low Power Mode", "On") }
        }
    }

    private func batteryColor(_ b: BatteryInfo) -> Color {
        if b.isCharging { return .green }
        if b.lowPowerMode { return .yellow }
        switch b.percent {
        case ..<16: return .red
        case ..<31: return .yellow
        default: return .green
        }
    }

    private func batteryIcon(_ b: BatteryInfo) -> String {
        if b.isCharging { return "battery.100.bolt" }
        switch b.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private var networkSection: some View {
        let n = monitor.network
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Network", systemImage: n.connected ? "network" : "network.slash")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(n.statusLabel)
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label(Fmt.speed(n.uploadBytesPerSec), systemImage: "arrow.up")
                Label(Fmt.speed(n.downloadBytesPerSec), systemImage: "arrow.down")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            if let ip = n.localIP {
                DetailRow("Local IP", ip)
            }
        }
    }
}

// MARK: Building blocks

private struct MetricSection<Details: View>: View {
    let icon: String
    let title: String
    let value: String
    let fraction: Double
    var barColor: Color? = nil
    @ViewBuilder let details: Details

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
                Spacer()
                Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            UsageBar(fraction: fraction, overrideColor: barColor)
            details
        }
    }
}

private struct UsageBar: View {
    let fraction: Double
    var overrideColor: Color? = nil

    private var color: Color {
        if let overrideColor { return overrideColor }
        switch fraction {
        case ..<0.70: return .green
        case ..<0.88: return .yellow
        default: return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(color.gradient)
                    .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// A looping sprite preview (used in the menu header and settings).
struct AnimatedSprite: View {
    let item: RunnerItem
    let height: CGFloat
    var paused: Bool = false
    var flipped: Bool = false

    var body: some View {
        let frames = SpriteStore.shared.frames(for: item, height: height, maxWidth: height * 1.6)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { context in
            if let f = frames, f.count > 0 {
                let image = frame(f, at: context.date)
                Image(nsImage: image)
                    .interpolation(.none)
            } else {
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
            }
        }
    }

    private func frame(_ f: RunnerFrames, at date: Date) -> NSImage {
        let t = paused ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: f.total)
        var acc = 0.0
        for (i, d) in f.delays.enumerated() {
            acc += d
            if t < acc { return flipped ? f.flipped[i] : f.images[i] }
        }
        return flipped ? f.flipped[0] : f.images[0]
    }
}
