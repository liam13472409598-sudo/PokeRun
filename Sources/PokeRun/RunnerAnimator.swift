import AppKit
import QuartzCore

/// Plays a runner's frames in the status bar button. Playback rate follows CPU load.
/// Uses one-shot timers scheduled at the next frame boundary, so it costs almost nothing when idle.
final class RunnerAnimator {
    weak var button: NSStatusBarButton?

    private(set) var frames: RunnerFrames?
    private var timer: Timer?
    private var clock: Double = 0
    private var lastTick: CFTimeInterval = CACurrentMediaTime()
    private var currentIndex = -1

    var rate: Double = 1.0
    var maxFPS: Int = 40 { didSet { reschedule() } }
    var flipped = false { didSet { currentIndex = -1; drawCurrent() } }
    var paused = false {
        didSet {
            guard paused != oldValue else { return }
            if paused {
                timer?.invalidate()
                timer = nil
            } else {
                lastTick = CACurrentMediaTime()
                step()
            }
        }
    }

    func setFrames(_ newFrames: RunnerFrames?) {
        frames = newFrames
        clock = 0
        currentIndex = -1
        lastTick = CACurrentMediaTime()
        drawCurrent()
        reschedule()
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard !paused, frames != nil else { return }
        step()
    }

    /// Index of the frame at `clock` and the time until the next frame starts.
    private func locate(_ f: RunnerFrames) -> (index: Int, remaining: Double) {
        var acc = 0.0
        for (i, d) in f.delays.enumerated() {
            acc += d
            if clock < acc { return (i, acc - clock) }
        }
        return (f.count - 1, f.delays.last ?? 0.1)
    }

    private func drawCurrent() {
        guard let f = frames, f.count > 0 else { return }
        let idx = locate(f).index
        guard idx != currentIndex else { return }
        currentIndex = idx
        button?.image = flipped ? f.flipped[idx] : f.images[idx]
    }

    private func step() {
        guard let f = frames, f.total > 0, !paused else { return }
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1.0)
        lastTick = now
        let r = max(rate, 0.05)
        clock = (clock + dt * r).truncatingRemainder(dividingBy: f.total)
        drawCurrent()

        let remaining = locate(f).remaining / r
        let interval = max(remaining, 1.0 / Double(max(maxFPS, 1)))
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in self?.step() }
        t.tolerance = interval * 0.1
        RunLoop.main.add(t, forMode: .common) // keep animating while menus are open
        timer = t
    }
}
