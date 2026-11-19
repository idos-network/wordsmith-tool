import AppKit
import Carbon.HIToolbox

/// Floating panel near the cursor. Non-activating, so the app you type in stays active and ⌘V lands there.
final class ChoicePanel: NSPanel {
    /// Choices: 0–2 = variant, 3 = keep original. Summary: 0 = copy. nil = cancel. Called at most once per `showLoading`.
    var onPick: (Int?) -> Void = { _ in }

    static let width: CGFloat = 460
    static let inset: CGFloat = 6  // between the panel edge and the rows
    private static let titles = ["Professional", "Shorter", "Casual", "Keep original"]
    // physical keys, so it works on the Czech layout where the top row types ěšč…
    private static let numberKeys = [
        [kVK_ANSI_1, kVK_ANSI_Keypad1], [kVK_ANSI_2, kVK_ANSI_Keypad2],
        [kVK_ANSI_3, kVK_ANSI_Keypad3], [kVK_ANSI_4, kVK_ANSI_Keypad4],
    ]
    private let stack = NSStackView()
    private var rows: [ChoiceRow] = []
    private var selected = 0
    private var topLeft = NSPoint.zero

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 60),
                   styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        hasShadow = true
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        contentView = background

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.width),
        ])
    }

    override var canBecomeKey: Bool { true }

    func showLoading(_ title: String) {
        topLeft = Self.pointNearMouse()
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        rows = []
        setContent([Self.header(title, hint: "esc  cancel", icon: spinner)])
        makeKeyAndOrderFront(nil)
    }

    func showError(_ message: String) {
        let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")!)
        icon.contentTintColor = .systemOrange
        rows = []
        setContent([Self.header("Couldn't rewrite", hint: "esc  close", icon: icon),
                    Self.padded(Self.wrappingLabel(message, size: 13, color: .labelColor))])
    }

    /// `original` is shown under "Keep original", so you can see what gets replaced.
    func showChoices(_ variants: [String], original: String) {
        rows = Self.titles.enumerated().map { index, title in
            let isOriginal = index >= variants.count
            let row = ChoiceRow(number: index + 1, title: title, text: isOriginal ? original : variants[index],
                                dimmed: isOriginal, maxLines: isOriginal ? 2 : 6)
            row.onClick = { [weak self] in self?.finish(index) }
            row.onHover = { [weak self] in self?.select(index) }
            return row
        }
        let separator = NSBox()
        separator.boxType = .separator
        setContent([Self.header("Pick a version", hint: "↑↓  select    ⏎  replace    esc  cancel", icon: nil)]
                   + rows.dropLast() + [separator] + [rows.last!])
        select(0)
    }

    /// One row per language; picking one (⏎, its number or a click) copies it.
    func showSummary(_ versions: [(title: String, text: String)]) {
        rows = versions.enumerated().map { index, version in
            let row = ChoiceRow(number: index + 1, title: version.title, text: version.text, dimmed: false, maxLines: 30)
            row.onClick = { [weak self] in self?.finish(index) }
            row.onHover = { [weak self] in self?.select(index) }
            return row
        }
        let hint = rows.count > 1 ? "↑↓  select    ⏎  copy    esc  close" : "⏎  copy    esc  close"
        setContent([Self.header("Summary", hint: hint, icon: nil)] + rows)
        select(0)
    }

    override func keyDown(with event: NSEvent) {
        let key = Int(event.keyCode)
        switch key {
        case kVK_Escape: finish(nil)
        case kVK_Return, kVK_ANSI_KeypadEnter: if !rows.isEmpty { finish(selected) }
        case kVK_UpArrow: select(selected - 1)
        case kVK_DownArrow: select(selected + 1)
        default:
            if let index = Self.numberKeys.firstIndex(where: { $0.contains(key) }), index < rows.count { finish(index) }
        }
    }

    // clicking into another window cancels
    override func resignKey() {
        super.resignKey()
        finish(nil)
    }

    private func finish(_ choice: Int?) {
        let callback = onPick
        onPick = { _ in }
        orderOut(nil)
        callback(choice)
    }

    private func select(_ index: Int) {
        guard !rows.isEmpty else { return }
        selected = (index + rows.count) % rows.count
        for (i, row) in rows.enumerated() { row.isSelected = i == selected }
    }

    private func setContent(_ views: [NSView]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for view in views {
            stack.addArrangedSubview(view)
            // full width; without this short rows hug their text and end up at odd positions
            view.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -Self.inset).isActive = true
        }
        contentView?.layoutSubtreeIfNeeded()
        setContentSize(contentView?.fittingSize ?? frame.size)
        setFrameTopLeftPoint(clamped(topLeft))
    }

    private func clamped(_ point: NSPoint) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main else { return point }
        let visible = screen.visibleFrame
        return NSPoint(x: min(max(point.x, visible.minX), visible.maxX - frame.width),
                       y: max(min(point.y, visible.maxY), visible.minY + frame.height))
    }

    private static func pointNearMouse() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        return NSPoint(x: mouse.x + 8, y: mouse.y - 8)
    }

    /// Title on the left, keyboard hint on the right.
    private static func header(_ title: String, hint: String, icon: NSView?) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let hintLabel = NSTextField(labelWithString: hint)
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        icon?.setContentHuggingPriority(.required, for: .horizontal)
        let line = NSStackView(views: (icon.map { [$0] } ?? []) + [titleLabel, hintLabel])
        line.distribution = .fill  // the title stretches, so the hint sits on the right
        line.spacing = 8
        line.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 4, right: 10)
        return line
    }

    private static func padded(_ view: NSView) -> NSView {
        let box = NSStackView(views: [view])
        box.edgeInsets = NSEdgeInsets(top: 2, left: 10, bottom: 8, right: 10)
        return box
    }

    static func wrappingLabel(_ text: String, size: CGFloat, color: NSColor, maxLines: Int = 0, width: CGFloat? = nil) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size)
        field.textColor = color
        field.isSelectable = false
        field.maximumNumberOfLines = maxLines
        field.cell?.truncatesLastVisibleLine = true
        field.preferredMaxLayoutWidth = width ?? (Self.width - 2 * Self.inset - 20)
        return field
    }
}

/// One option: a key badge, its title, and the text it would paste.
private final class ChoiceRow: NSView {
    var onClick: () -> Void = {}
    var onHover: () -> Void = {}
    var isSelected = false { didSet { updateColors() } }

    private let badge: NSTextField
    private let titleLabel: NSTextField
    private let textLabel: NSTextField
    private let dimmed: Bool

    init(number: Int, title: String, text: String, dimmed: Bool, maxLines: Int) {
        self.dimmed = dimmed
        badge = NSTextField(labelWithString: "\(number)")
        titleLabel = NSTextField(labelWithString: title)
        let textWidth = ChoicePanel.width - 2 * ChoicePanel.inset - 50  // badge column + paddings
        textLabel = ChoicePanel.wrappingLabel(text, size: 13, color: .labelColor, maxLines: maxLines, width: textWidth)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(title): \(text)")

        badge.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 5
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)

        for view in [badge, titleLabel, textLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            badge.widthAnchor.constraint(equalToConstant: 20),
            badge.heightAnchor.constraint(equalToConstant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            titleLabel.firstBaselineAnchor.constraint(equalTo: badge.firstBaselineAnchor),
            textLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            textLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
        ])
        updateColors()
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // activeAlways: our app is never active, the app you type in is
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover() }
    override func mouseDown(with event: NSEvent) { onClick() }
    override func accessibilityPerformPress() -> Bool { onClick(); return true }
    override func viewDidChangeEffectiveAppearance() { updateColors() }

    private func updateColors() {
        // layer colors do not follow light/dark by themselves, so resolve them for this view's appearance
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = isSelected ? NSColor.selectedContentBackgroundColor.cgColor : nil
            titleLabel.textColor = isSelected ? .white.withAlphaComponent(0.85) : .secondaryLabelColor
            textLabel.textColor = isSelected ? .white : (dimmed ? .secondaryLabelColor : .labelColor)
            badge.textColor = isSelected ? .white : .secondaryLabelColor
            badge.layer?.backgroundColor = (isSelected ? NSColor.white.withAlphaComponent(0.25) : NSColor.quaternaryLabelColor).cgColor
        }
    }
}
