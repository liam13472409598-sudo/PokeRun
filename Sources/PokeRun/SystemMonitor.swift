import Foundation
import Darwin
import IOKit
import IOKit.ps
import SystemConfiguration

struct CPUInfo {
    var usage: Double = 0   // 0–100
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 100
    var cores: Int = ProcessInfo.processInfo.activeProcessorCount
}

struct MemoryInfo {
    var total: UInt64 = ProcessInfo.processInfo.physicalMemory
    var used: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var pressure: Double = 0 // 0–100

    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct StorageInfo {
    var volumeName: String = "Macintosh HD"
    var total: Int64 = 0
    var available: Int64 = 0

    var used: Int64 { max(total - available, 0) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct BatteryInfo {
    var present = false
    var percent: Int = 0
    var isCharging = false
    var onACPower = false
    var isCharged = false
    var minutesRemaining: Int? = nil
    var cycleCount: Int? = nil
    var healthPercent: Int? = nil
    var lowPowerMode = false
}

struct NetworkInfo {
    var uploadBytesPerSec: Double = 0
    var downloadBytesPerSec: Double = 0
    var interfaceName: String? = nil   // e.g. "Wi-Fi"
    var bsdName: String? = nil         // e.g. "en0"
    var localIP: String? = nil
    var vpnActive = false
    var connected: Bool { localIP != nil }

    var statusLabel: String {
        guard connected else { return "Offline" }
        let base = interfaceName ?? "Connected"
        return vpnActive ? "\(base) · VPN" : base
    }
}

/// Samples CPU, memory, storage, battery and network statistics.
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpu = CPUInfo()
    @Published private(set) var memory = MemoryInfo()
    @Published private(set) var storage = StorageInfo()
    @Published private(set) var battery = BatteryInfo()
    @Published private(set) var network = NetworkInfo()

    /// Smoothed CPU usage (0–100) used to drive the runner.
    private(set) var smoothedCPU: Double = 0
    var onCPUUpdate: ((Double) -> Void)?

    private var timer: Timer?
    private var tickCount = 0
    private var prevCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var prevNet: [String: (ibytes: UInt32, obytes: UInt32)] = [:]
    private var prevNetTime: CFAbsoluteTime = 0
    private var interfaceDisplayNames: [String: String] = [:]
    private let pageSize: UInt64 = {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return UInt64(size)
    }()

    func start() {
        refreshInterfaceNames()
        sampleCPU()
        sampleNetwork()
        refreshAll()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Refreshes the slower-moving stats (called when the menu opens).
    func refreshAll() {
        sampleMemory()
        sampleStorage()
        sampleBattery()
    }

    private func tick() {
        tickCount += 1
        sampleCPU()
        sampleMemory()
        sampleNetwork()
        if tickCount % 5 == 0 { sampleBattery() }
        if tickCount % 30 == 0 { sampleStorage(); refreshInterfaceNames() }
    }

    // MARK: CPU

    private func sampleCPU() {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let ticks = (user: UInt64(load.cpu_ticks.0), system: UInt64(load.cpu_ticks.1),
                     idle: UInt64(load.cpu_ticks.2), nice: UInt64(load.cpu_ticks.3))
        defer { prevCPUTicks = ticks }
        guard let prev = prevCPUTicks else { return }

        let user = Double(ticks.user &- prev.user) + Double(ticks.nice &- prev.nice)
        let system = Double(ticks.system &- prev.system)
        let idle = Double(ticks.idle &- prev.idle)
        let total = user + system + idle
        guard total > 0 else { return }

        var info = CPUInfo()
        info.user = user / total * 100
        info.system = system / total * 100
        info.idle = idle / total * 100
        info.usage = min(100, info.user + info.system)
        cpu = info

        // Light smoothing so the runner doesn't jitter.
        smoothedCPU = smoothedCPU * 0.4 + info.usage * 0.6
        onCPUUpdate?(smoothedCPU)
    }

    // MARK: Memory

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        var info = MemoryInfo()
        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        info.app = (internalPages > purgeable ? internalPages - purgeable : 0) * pageSize
        info.wired = UInt64(stats.wire_count) * pageSize
        info.compressed = UInt64(stats.compressor_page_count) * pageSize
        info.cached = (UInt64(stats.external_page_count) + purgeable) * pageSize
        info.used = min(info.app + info.wired + info.compressed, info.total)

        // kern.memorystatus_level = % of memory available; pressure is its complement.
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0) == 0 {
            info.pressure = Double(max(0, min(100, 100 - level)))
        }
        memory = info
    }

    // MARK: Storage

    private func sampleStorage() {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey, .volumeLocalizedNameKey,
        ]) else { return }
        var info = StorageInfo()
        info.volumeName = values.volumeLocalizedName ?? "Macintosh HD"
        info.total = Int64(values.volumeTotalCapacity ?? 0)
        info.available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        storage = info
    }

    // MARK: Battery

    private func sampleBattery() {
        var info = BatteryInfo()
        info.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for source in list {
                guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                      (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
                info.present = true
                let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
                let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                info.percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
                info.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                info.isCharged = desc[kIOPSIsChargedKey] as? Bool ?? false
                info.onACPower = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                let minutes = info.isCharging ? desc[kIOPSTimeToFullChargeKey] as? Int
                                              : desc[kIOPSTimeToEmptyKey] as? Int
                if let m = minutes, m > 0 { info.minutesRemaining = m }
            }
        }

        if info.present {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if service != 0 {
                defer { IOObjectRelease(service) }
                func prop(_ key: String) -> Int? {
                    IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? Int
                }
                info.cycleCount = prop("CycleCount")
                if let raw = prop("AppleRawMaxCapacity") ?? prop("NominalChargeCapacity"),
                   let design = prop("DesignCapacity"), design > 0 {
                    info.healthPercent = min(100, Int((Double(raw) / Double(design) * 100).rounded()))
                }
            }
        }
        battery = info
    }

    // MARK: Network

    private func refreshInterfaceNames() {
        var map: [String: String] = [:]
        if let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for iface in all {
                if let bsd = SCNetworkInterfaceGetBSDName(iface) as String?,
                   let name = SCNetworkInterfaceGetLocalizedDisplayName(iface) as String? {
                    map[bsd] = name
                }
            }
        }
        interfaceDisplayNames = map
    }

    private func primaryInterface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "PokeRun" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        else { return nil }
        return dict["PrimaryInterface"] as? String
    }

    private func sampleNetwork() {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return }
        defer { freeifaddrs(ifaddrPtr) }

        let primary = primaryInterface()
        var counters: [String: (ibytes: UInt32, obytes: UInt32)] = [:]
        var ipv4ByInterface: [String: String] = [:]

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr else { continue }
            let name = String(cString: ifa.ifa_name)
            let flags = Int32(ifa.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }

            switch Int32(addr.pointee.sa_family) {
            case AF_LINK:
                // Count physical interfaces (Wi-Fi / Ethernet) to avoid double-counting VPN tunnels.
                guard name.hasPrefix("en"), let data = ifa.ifa_data else { continue }
                let d = data.assumingMemoryBound(to: if_data.self).pointee
                counters[name] = (d.ifi_ibytes, d.ifi_obytes)
            case AF_INET:
                guard ipv4ByInterface[name] == nil else { break }
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    ipv4ByInterface[name] = String(cString: host)
                }
            default:
                break
            }
        }

        let isTunnel = primary.map {
            $0.hasPrefix("utun") || $0.hasPrefix("ipsec") || $0.hasPrefix("ppp") || $0.hasPrefix("tun")
        } ?? false
        let physicalInterface = ipv4ByInterface.keys
            .filter { $0.hasPrefix("en") }
            .sorted()
            .first

        let resolvedInterface: String?
        if isTunnel, let phys = physicalInterface {
            resolvedInterface = phys
        } else {
            resolvedInterface = primary ?? physicalInterface
        }

        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - prevNetTime
        var down: UInt64 = 0, up: UInt64 = 0
        for (name, c) in counters {
            guard let p = prevNet[name] else { continue }
            down += UInt64(c.ibytes &- p.ibytes) // 32-bit counters wrap; &- handles one wrap
            up += UInt64(c.obytes &- p.obytes)
        }

        var info = NetworkInfo()
        if prevNetTime > 0, elapsed > 0.2 {
            info.downloadBytesPerSec = Double(down) / elapsed
            info.uploadBytesPerSec = Double(up) / elapsed
        }
        info.bsdName = resolvedInterface
        info.interfaceName = resolvedInterface.flatMap { interfaceDisplayNames[$0] ?? $0 }
        info.localIP = resolvedInterface.flatMap { ipv4ByInterface[$0] }
        info.vpnActive = isTunnel
        network = info
        prevNet = counters
        prevNetTime = now
    }
}

// MARK: Formatting

enum Fmt {
    static func bytes(_ value: UInt64) -> String { bytes(Int64(clamping: value)) }

    static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        f.allowedUnits = [.useGB, .useMB]
        return f.string(fromByteCount: value)
    }

    static func disk(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: value)
    }

    static func speed(_ bytesPerSec: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var v = bytesPerSec
        var i = 0
        while v >= 1000, i < units.count - 1 { v /= 1000; i += 1 }
        return i == 0 ? String(format: "%.0f %@", v, units[i]) : String(format: "%.1f %@", v, units[i])
    }

    static func percent(_ v: Double) -> String { String(format: "%.1f%%", v) }

    static func minutes(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
