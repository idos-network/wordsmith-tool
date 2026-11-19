import Foundation

/// Detects two quick taps of one modifier key (⌥ or ⌃) on its own. Feed it every modifier change; call `reset()` on
/// every key press, so typing ⌥-characters (on the Czech layout ⌥V = @) or ⌃-shortcuts never counts as a tap.
struct DoubleTap {
    var maxHold: TimeInterval = 0.3  // a key held longer than this is not a tap
    var maxGap: TimeInterval = 0.35  // from the first release to the second press
    private var pressedAt: TimeInterval?
    private var releasedAt: TimeInterval?

    /// `only`: the watched key is the only modifier down; `none`: no modifier is down. Returns true on the second press.
    mutating func modifiersChanged(only: Bool, none: Bool, at time: TimeInterval) -> Bool {
        if only {
            if let releasedAt, time - releasedAt <= maxGap {
                reset()
                return true
            }
            pressedAt = time
            releasedAt = nil
        } else if none, let pressedAt, time - pressedAt <= maxHold {
            releasedAt = time
            self.pressedAt = nil
        } else {
            reset()
        }
        return false
    }

    mutating func reset() {
        pressedAt = nil
        releasedAt = nil
    }
}
