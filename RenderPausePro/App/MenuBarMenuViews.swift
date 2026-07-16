import AppKit

// MARK: - Tokens (strict map from menubar-menu-v1.html)

enum MenuBarChrome {
    /// HTML `--menu-w`
    static let menuWidth: CGFloat = 288
    /// HTML `--row-h`
    static let rowHeight: CGFloat = 28
    /// HTML `--pad-x`
    static let padX: CGFloat = 10
    /// HTML item outer margin 0 5
    static let itemInsetX: CGFloat = 5
    /// HTML .item gap 8
    static let itemGap: CGFloat = 8
    /// HTML .app-row gap 7
    static let appGap: CGFloat = 7
    /// HTML lead column 22
    static let leadWidth: CGFloat = 22
    /// HTML .app-row check 16
    static let checkWidth: CGFloat = 16
    /// HTML .app-row icon column 18 / icon 16
    static let appIconColumn: CGFloat = 18
    static let appIconSize: CGFloat = 16
    /// HTML header vertical padding 7 / 8
    static let headerPadTop: CGFloat = 7
    static let headerPadBottom: CGFloat = 8
    /// HTML .section-label pad 6 14 4
    static let sectionPadTop: CGFloat = 6
    static let sectionPadBottom: CGFloat = 4
    static let sectionPadX: CGFloat = 14
    /// HTML font sizes
    static let titleSize: CGFloat = 13
    static let headerTitleSize: CGFloat = 13
    static let headerSubSize: CGFloat = 12
    static let stateSize: CGFloat = 12
    static let sectionSize: CGFloat = 11
    static let kbdSize: CGFloat = 12
    /// Space between app list and “添加应用” (no separator line).
    static let listToAddGap: CGFloat = 12
}

// MARK: - Shared row chrome

/// Base view for HTML `.item` rows: inset 5, radius 6, hover = system accent.
class MenuBarRowView: NSView {
    var onActivate: (() -> Void)?
    private(set) var isHighlighted = false
    private let content = NSView()
    private let background = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.masksToBounds = true
        addSubview(background)
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var contentView: NSView { content }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuBarChrome.menuWidth, height: MenuBarChrome.rowHeight)
    }

    override func layout() {
        super.layout()
        let inset = MenuBarChrome.itemInsetX
        background.frame = bounds.insetBy(dx: inset, dy: 0)
        content.frame = NSRect(
            x: inset + MenuBarChrome.padX,
            y: 0,
            width: max(0, bounds.width - inset * 2 - MenuBarChrome.padX * 2),
            height: bounds.height
        )
        applyHighlight()
    }

    func setHighlighted(_ highlighted: Bool) {
        guard isHighlighted != highlighted else { return }
        isHighlighted = highlighted
        applyHighlight()
        highlightDidChange()
    }

    func highlightDidChange() {}

    private func applyHighlight() {
        if isHighlighted {
            background.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        } else {
            background.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func mouseEntered(with event: NSEvent) {
        setHighlighted(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHighlighted(false)
    }

    override func mouseDown(with event: NSEvent) {
        setHighlighted(true)
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onActivate?()
            enclosingMenuItem?.menu?.cancelTracking()
        } else {
            setHighlighted(false)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    /// Label color for primary text depending on highlight.
    func primaryColor() -> NSColor {
        isHighlighted ? .white : .labelColor
    }

    func secondaryColor() -> NSColor {
        if isHighlighted {
            return NSColor.white.withAlphaComponent(0.88)
        }
        return .secondaryLabelColor
    }

    func tertiaryColor() -> NSColor {
        if isHighlighted {
            return NSColor.white.withAlphaComponent(0.75)
        }
        return .tertiaryLabelColor
    }
}

// MARK: - Header (desktop icon + title + sub)

/// HTML `.item.header` — not interactive, no hover fill.
final class MenuBarHeaderView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .secondaryLabelColor

        titleLabel.font = .systemFont(ofSize: MenuBarChrome.headerTitleSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        subLabel.font = .systemFont(ofSize: MenuBarChrome.headerSubSize, weight: .regular)
        subLabel.textColor = .secondaryLabelColor
        subLabel.lineBreakMode = .byTruncatingTail

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        // pad top 7 + title ~17 + 1 + sub ~16 + pad bottom 8 ≈ 49
        NSSize(width: MenuBarChrome.menuWidth, height: 49)
    }

    func configure(title: String, subtitle: String, icon: NSImage?) {
        titleLabel.stringValue = title
        subLabel.stringValue = subtitle
        iconView.image = icon
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let inset = MenuBarChrome.itemInsetX
        let x0 = inset + MenuBarChrome.padX
        let lead = MenuBarChrome.leadWidth
        let gap = MenuBarChrome.itemGap
        let textX = x0 + lead + gap
        let textW = max(0, bounds.width - textX - inset - MenuBarChrome.padX)

        iconView.frame = NSRect(
            x: x0 + (lead - 15) / 2,
            y: bounds.height - MenuBarChrome.headerPadTop - 16,
            width: 15,
            height: 15
        )
        titleLabel.frame = NSRect(
            x: textX,
            y: bounds.height - MenuBarChrome.headerPadTop - 17,
            width: textW,
            height: 17
        )
        subLabel.frame = NSRect(
            x: textX,
            y: MenuBarChrome.headerPadBottom,
            width: textW,
            height: 16
        )
    }
}

// MARK: - Action row (icon · title · kbd)

final class MenuBarActionRowView: MenuBarRowView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let kbdLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleLabel.font = .systemFont(ofSize: MenuBarChrome.titleSize)
        titleLabel.lineBreakMode = .byTruncatingTail
        kbdLabel.font = .systemFont(ofSize: MenuBarChrome.kbdSize)
        kbdLabel.alignment = .right
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(kbdLabel)
        highlightDidChange()
    }

    func configure(title: String, icon: NSImage?, keyEquivalent: String) {
        titleLabel.stringValue = title
        iconView.image = icon
        kbdLabel.stringValue = keyEquivalent
        needsLayout = true
    }

    override func highlightDidChange() {
        titleLabel.textColor = primaryColor()
        iconView.contentTintColor = secondaryColor()
        kbdLabel.textColor = tertiaryColor()
    }

    override func layout() {
        super.layout()
        let c = contentView.bounds
        let lead = MenuBarChrome.leadWidth
        let gap = MenuBarChrome.itemGap
        iconView.frame = NSRect(x: (lead - 15) / 2, y: (c.height - 15) / 2, width: 15, height: 15)
        let kbdW: CGFloat = kbdLabel.stringValue.isEmpty
            ? 0
            : max(36, ceil(kbdLabel.intrinsicContentSize.width) + 2)
        let titleX = lead + gap
        let titleW = max(0, c.width - titleX - kbdW - (kbdW > 0 ? 8 : 0))
        titleLabel.frame = NSRect(x: titleX, y: (c.height - 18) / 2, width: titleW, height: 18)
        if kbdW > 0 {
            kbdLabel.frame = NSRect(x: c.width - kbdW, y: (c.height - 16) / 2, width: kbdW, height: 16)
        } else {
            kbdLabel.frame = .zero
        }
    }
}

// MARK: - Section label

final class MenuBarSectionLabelView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: MenuBarChrome.sectionSize, weight: .medium)
        label.textColor = .tertiaryLabelColor
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuBarChrome.menuWidth, height: MenuBarChrome.sectionPadTop + 14 + MenuBarChrome.sectionPadBottom)
    }

    func configure(title: String) {
        label.stringValue = title
    }

    override func layout() {
        super.layout()
        label.frame = NSRect(
            x: MenuBarChrome.sectionPadX,
            y: MenuBarChrome.sectionPadBottom,
            width: max(0, bounds.width - MenuBarChrome.sectionPadX * 2),
            height: 14
        )
    }
}

// MARK: - App row: ✓ · icon · name · state

final class MenuBarAppRowView: MenuBarRowView {
    private let checkView = NSImageView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stateLabel = NSTextField(labelWithString: "")
    private var enabled = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        checkView.imageScaling = .scaleProportionallyUpOrDown
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleLabel.font = .systemFont(ofSize: MenuBarChrome.titleSize)
        titleLabel.lineBreakMode = .byTruncatingTail
        stateLabel.font = .monospacedDigitSystemFont(ofSize: MenuBarChrome.stateSize, weight: .regular)
        stateLabel.alignment = .right
        contentView.addSubview(checkView)
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(stateLabel)
        highlightDidChange()
    }

    func configure(
        title: String,
        appIcon: NSImage?,
        enabled: Bool,
        status: String,
        checkOn: NSImage,
        checkOff: NSImage
    ) {
        self.enabled = enabled
        titleLabel.stringValue = title
        iconView.image = appIcon
        stateLabel.stringValue = status
        checkView.image = enabled ? checkOn : checkOff
        checkView.alphaValue = enabled ? 1 : 0
        highlightDidChange()
        needsLayout = true
    }

    override func highlightDidChange() {
        if isHighlighted {
            titleLabel.textColor = enabled ? .white : NSColor.white.withAlphaComponent(0.82)
            stateLabel.textColor = NSColor.white.withAlphaComponent(0.88)
            checkView.contentTintColor = .white
        } else {
            titleLabel.textColor = enabled ? .labelColor : .tertiaryLabelColor
            stateLabel.textColor = .secondaryLabelColor
            checkView.contentTintColor = .labelColor
        }
    }

    override func layout() {
        super.layout()
        let c = contentView.bounds
        let checkW = MenuBarChrome.checkWidth
        let iconCol = MenuBarChrome.appIconColumn
        let iconSize = MenuBarChrome.appIconSize
        let gap = MenuBarChrome.appGap

        // grid: 16 | 18 | 1fr | auto
        checkView.frame = NSRect(
            x: (checkW - 12) / 2,
            y: (c.height - 12) / 2,
            width: 12,
            height: 12
        )
        let iconX = checkW + gap
        iconView.frame = NSRect(
            x: iconX + (iconCol - iconSize) / 2,
            y: (c.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        let stateW = ceil(stateLabel.intrinsicContentSize.width) + 2
        let titleX = iconX + iconCol + gap
        let titleW = max(0, c.width - titleX - stateW - 8)
        titleLabel.frame = NSRect(x: titleX, y: (c.height - 18) / 2, width: titleW, height: 18)
        stateLabel.frame = NSRect(x: c.width - stateW, y: (c.height - 16) / 2, width: stateW, height: 16)
    }
}

// MARK: - Empty / disabled plain row

final class MenuBarPlainDisabledView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: MenuBarChrome.titleSize)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuBarChrome.menuWidth, height: 34)
    }

    func configure(title: String) {
        label.stringValue = title
    }

    override func layout() {
        super.layout()
        let inset = MenuBarChrome.itemInsetX + MenuBarChrome.padX
        label.frame = NSRect(
            x: inset,
            y: (bounds.height - 18) / 2,
            width: max(0, bounds.width - inset * 2),
            height: 18
        )
    }
}

// MARK: - Vertical spacer (no separator line)

final class MenuBarSpacerView: NSView {
    private let height: CGFloat

    init(height: CGFloat) {
        self.height = height
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: MenuBarChrome.menuWidth, height: height)
    }
}

// MARK: - Factory helpers for NSMenuItem + custom view

enum MenuBarMenuItemFactory {
    static func wrap(_ view: NSView, height: CGFloat? = nil) -> NSMenuItem {
        let item = NSMenuItem()
        let h = height ?? view.intrinsicContentSize.height
        view.frame = NSRect(x: 0, y: 0, width: MenuBarChrome.menuWidth, height: h)
        view.setFrameSize(NSSize(width: MenuBarChrome.menuWidth, height: h))
        item.view = view
        return item
    }

    static func symbol(_ name: String, pointSize: CGFloat = 13) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let img = base.withSymbolConfiguration(config) ?? base
        img.isTemplate = true
        return img
    }

    /// HTML bare check path, 12×12, no ring.
    static func bareCheckImage() -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()
            // M3.2 8.2 L6.4 11.3 L12.8 4.5 scaled into 12pt box (16→12)
            let s = rect.width / 16
            path.move(to: NSPoint(x: 3.2 * s, y: rect.height - 8.2 * s))
            path.line(to: NSPoint(x: 6.4 * s, y: rect.height - 11.3 * s))
            path.line(to: NSPoint(x: 12.8 * s, y: rect.height - 4.5 * s))
            path.lineWidth = 2.0 * s
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    static func emptyCheckImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12))
        image.isTemplate = true
        return image
    }

    static func appIcon(bundleID: String) -> NSImage {
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        }
        let size = NSSize(width: MenuBarChrome.appIconSize, height: MenuBarChrome.appIconSize)
        let sized = NSImage(size: size)
        sized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        icon.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        sized.unlockFocus()
        sized.isTemplate = false
        return sized
    }

    static func statusText(enabled: Bool, session: WatchState) -> String {
        if !enabled { return "已关闭" }
        switch session {
        case .optimized: return "已隐藏"
        case .watched, .paused: return "监控中"
        }
    }

    static func keyGlyph(_ key: String) -> String {
        // HTML shows ⌘, / ⌘Q
        key
    }
}
