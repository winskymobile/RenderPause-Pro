import AppKit
import SwiftUI

// MARK: - Design tokens (strict map from preferences-split-lr-v1.html)

private enum PrefsChrome {
    // --bg-*
    static func windowBg(_ s: ColorScheme) -> Color { s == .dark ? rgb(0x1C1C1E) : rgb(0xE8E8ED) }
    static func leftBg(_ s: ColorScheme) -> Color { s == .dark ? rgb(0x242426) : rgb(0xF2F2F7) }
    static func rightBg(_ s: ColorScheme) -> Color { s == .dark ? rgb(0x1E1E20) : rgb(0xFFFFFF) }
    static func cardBg(_ s: ColorScheme) -> Color { s == .dark ? rgb(0x2C2C2E) : rgb(0xFFFFFF) }

    // --line / --label / --sec / --ter / --accent
    static func line(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.08) : rgba(0, 0, 0, 0.08)
    }
    static func label(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.92) : rgba(0, 0, 0, 0.88)
    }
    static func sec(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.55) : rgba(0, 0, 0, 0.52)
    }
    static func ter(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.34) : rgba(0, 0, 0, 0.34)
    }
    static func accent(_ s: ColorScheme) -> Color {
        s == .dark ? rgb(0x0A84FF) : rgb(0x007AFF)
    }
    static func rowHover(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.05) : rgba(0, 0, 0, 0.035)
    }

    // Quiet activity tokens
    static func activityBg(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.03) : rgba(0, 0, 0, 0.028)
    }
    static func activityLine(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.05) : rgba(0, 0, 0, 0.05)
    }
    static func activityTitle(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.38) : rgba(0, 0, 0, 0.40)
    }
    static func activityBody(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.42) : rgba(0, 0, 0, 0.42)
    }
    static func activityMeta(_ s: ColorScheme) -> Color {
        s == .dark ? rgba(1, 1, 1, 0.28) : rgba(0, 0, 0, 0.30)
    }

    // Metrics
    static let hairline: CGFloat = 0.5
    static let titleBarHeight: CGFloat = 48
    static let leftWidth: CGFloat = 280
    static let radius: CGFloat = 10
    static let activityRadius: CGFloat = 8
    static let activityRowHeight: CGFloat = 26
    /// Default open size (= min resizable). User can still enlarge the window.
    static let winW: CGFloat = 740
    static let winH: CGFloat = 500

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }
}

// MARK: - Root

struct PreferencesView: View {
    @ObservedObject var model: UIAppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            contentBody
        }
        .frame(minWidth: PrefsChrome.winW, idealWidth: PrefsChrome.winW, minHeight: PrefsChrome.winH, idealHeight: PrefsChrome.winH)
        .background(PrefsChrome.windowBg(scheme))
        .ignoresSafeArea(.container, edges: .top)
        .onAppear { model.refresh() }
    }

    // HTML .tb — 48px full-width chrome; title + version after software name
    private var titleBar: some View {
        ZStack {
            PrefsChrome.windowBg(scheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                Color.clear.frame(width: 72) // traffic-light column
                HStack(spacing: 6) {
                    Text("RenderPause Pro")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PrefsChrome.label(scheme))
                        .tracking(-0.13) // -0.01em @ 13
                        .lineLimit(1)
                    Text(appVersionLabel)
                        .font(.system(size: 12, weight: .regular).monospacedDigit())
                        .foregroundStyle(PrefsChrome.sec(scheme))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: 72)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: PrefsChrome.titleBarHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            PrefsChrome.line(scheme)
                .frame(height: PrefsChrome.hairline)
                .frame(maxWidth: .infinity)
        }
    }

    // HTML .body — grid 280px | 1fr
    private var contentBody: some View {
        HStack(spacing: 0) {
            leftPane
                .frame(width: PrefsChrome.leftWidth)
            PrefsChrome.line(scheme)
                .frame(width: PrefsChrome.hairline)
                .frame(maxHeight: .infinity)
            rightPane
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left (HTML .left: pad 18 16 16, gap 14, bg-left)

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            generalBlock
            activityBlock
        }
        .padding(.top, 18)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PrefsChrome.leftBg(scheme))
    }

    /// Marketing version label, e.g. `v1.1.0`.
    private var appVersionLabel: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let version = (short?.isEmpty == false) ? short! : "1.1.0"
        return version.hasPrefix("v") ? version : "v\(version)"
    }

    // HTML .col-title 11/650 + .card of rows
    private var generalBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("通用")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PrefsChrome.sec(scheme))
                .tracking(0.11) // ~0.01em
                .padding(.leading, 2)

            VStack(spacing: 0) {
                settingsRow {
                    Text("启用监控")
                        .font(.system(size: 13))
                        .foregroundStyle(PrefsChrome.label(scheme))
                    Spacer(minLength: 8)
                    Toggle("", isOn: monitoringBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                rowLine
                settingsRow {
                    Text("登录时启动")
                        .font(.system(size: 13))
                        .foregroundStyle(PrefsChrome.label(scheme))
                    Spacer(minLength: 8)
                    Toggle("", isOn: launchBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                rowLine
                settingsRow {
                    Text("触发时间（秒）")
                        .font(.system(size: 13))
                        .foregroundStyle(PrefsChrome.label(scheme))
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        stepButton("−") {
                            model.setBackgroundSeconds(model.settings.backgroundSeconds - 5)
                        }
                        TextField("", value: backgroundSecondsBinding, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.center)
                            .frame(width: 42, height: 24)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(PrefsChrome.label(scheme))
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(PrefsChrome.line(scheme), lineWidth: PrefsChrome.hairline)
                            )
                        stepButton("+") {
                            model.setBackgroundSeconds(model.settings.backgroundSeconds + 5)
                        }
                    }
                }
                // 隐藏模式 UI kept but gated — product defaults to hide-only.
                if FeatureFlags.allowMinimizeMode {
                    rowLine
                    settingsRow {
                        Text("隐藏模式")
                            .font(.system(size: 13))
                            .foregroundStyle(PrefsChrome.label(scheme))
                        Spacer(minLength: 8)
                        HStack(spacing: 14) {
                            radio("隐藏", on: model.settings.optimizeAction == .hide) {
                                model.setOptimizeAction(.hide)
                            }
                            radio("最小化", on: model.settings.optimizeAction == .minimize) {
                                model.setOptimizeAction(.minimize)
                            }
                        }
                    }
                    if model.settings.optimizeAction == .minimize {
                        rowLine
                        settingsRow {
                            Text("最小化辅助功能")
                                .font(.system(size: 13))
                                .foregroundStyle(PrefsChrome.label(scheme))
                            Spacer(minLength: 8)
                            if model.accessibilityTrusted {
                                Text("已授权")
                                    .font(.system(size: 13))
                                    .foregroundStyle(PrefsChrome.sec(scheme))
                            } else {
                                Button("去授权") {
                                    model.requestAccessibilityAuthorization()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(PrefsChrome.accent(scheme))
                            }
                        }
                    }
                }
                rowLine
                settingsRow {
                    Text("检测更新")
                        .font(.system(size: 13))
                        .foregroundStyle(PrefsChrome.label(scheme))
                    Spacer(minLength: 8)
                    if !model.updateStatusText.isEmpty {
                        Text(model.updateStatusText)
                            .font(.system(size: 12))
                            .foregroundStyle(PrefsChrome.sec(scheme))
                            .lineLimit(1)
                    }
                    Button(model.updateButtonTitle) {
                        model.performUpdatePrimaryAction()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(
                        model.updateButtonEnabled
                            ? PrefsChrome.accent(scheme)
                            : PrefsChrome.ter(scheme)
                    )
                    .disabled(!model.updateButtonEnabled)
                }
            }
            .background(PrefsChrome.cardBg(scheme))
            .clipShape(RoundedRectangle(cornerRadius: PrefsChrome.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PrefsChrome.radius, style: .continuous)
                    .strokeBorder(PrefsChrome.line(scheme), lineWidth: PrefsChrome.hairline)
            )
        }
    }

    // Quiet secondary activity region
    private var activityBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("最近活动")
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(0.21)
                    .foregroundStyle(PrefsChrome.activityTitle(scheme))
                Spacer()
                Text("今日 \(model.todayOptimizeCount) 次")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(PrefsChrome.activityMeta(scheme))
            }
            .padding(.horizontal, 4)

            GeometryReader { geo in
                let maxRows = max(1, Int(geo.size.height / PrefsChrome.activityRowHeight))
                let entries = Array(model.logEntries.prefix(maxRows))
                VStack(spacing: 0) {
                    if entries.isEmpty {
                        Text("暂无活动")
                            .font(.system(size: 11))
                            .foregroundStyle(PrefsChrome.activityMeta(scheme))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(10)
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            CompactLogRowView(entry: entry)
                            if index < entries.count - 1 {
                                PrefsChrome.activityLine(scheme)
                                    .frame(height: PrefsChrome.hairline)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PrefsChrome.activityBg(scheme))
            .clipShape(RoundedRectangle(cornerRadius: PrefsChrome.activityRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PrefsChrome.activityRadius, style: .continuous)
                    .strokeBorder(PrefsChrome.activityLine(scheme), lineWidth: PrefsChrome.hairline)
            )
            // No scrollbar — height-driven row count only.
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Right (HTML .right)

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // .r-head pad 16 18 12
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("应用名单")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.36)
                        .foregroundStyle(PrefsChrome.label(scheme))
                    Text("启用或移除名单中的应用")
                        .font(.system(size: 12))
                        .foregroundStyle(PrefsChrome.sec(scheme))
                }
                Spacer(minLength: 0)
                // .btn.primary
                Button("添加") { model.addRunningApps() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(PrefsChrome.accent(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            // .list margin 0 14 16
            Group {
                if model.rules.isEmpty {
                    VStack(spacing: 10) {
                        Spacer(minLength: 24)
                        Text("还没有应用")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PrefsChrome.label(scheme))
                        Text("添加需要在后台自动隐藏的应用。")
                            .font(.system(size: 12.5))
                            .foregroundStyle(PrefsChrome.sec(scheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 220)
                        Button("添加") { model.addRunningApps() }
                            .buttonStyle(.plain)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(PrefsChrome.accent(scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.rules.enumerated()), id: \.element.id) { index, rule in
                                RuleRowView(model: model, rule: rule)
                                if index < model.rules.count - 1 {
                                    PrefsChrome.line(scheme).frame(height: PrefsChrome.hairline)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PrefsChrome.cardBg(scheme))
            .clipShape(RoundedRectangle(cornerRadius: PrefsChrome.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PrefsChrome.radius, style: .continuous)
                    .strokeBorder(PrefsChrome.line(scheme), lineWidth: PrefsChrome.hairline)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PrefsChrome.rightBg(scheme))
    }

    // MARK: - Shared

    private var rowLine: some View {
        PrefsChrome.line(scheme).frame(height: PrefsChrome.hairline)
    }

    /// HTML .row: min-height 40, padding 8 12, font 13
    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
    }

    /// HTML .step-btn 22×22 inset 0.5 line
    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(PrefsChrome.label(scheme))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(PrefsChrome.line(scheme), lineWidth: PrefsChrome.hairline)
        )
    }

    /// HTML radio label 13, gap 5
    private func radio(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(on ? PrefsChrome.accent(scheme) : PrefsChrome.sec(scheme))
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(PrefsChrome.label(scheme))
            }
        }
        .buttonStyle(.plain)
    }

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { model.settings.monitoringEnabled },
            set: { model.setMonitoring($0) }
        )
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private var backgroundSecondsBinding: Binding<Double> {
        Binding(
            get: { model.settings.backgroundSeconds },
            set: { model.setBackgroundSeconds($0) }
        )
    }
}

// MARK: - App row (HTML .app: pad 10 12, gap 10, icon 28)

private struct RuleRowView: View {
    @ObservedObject var model: UIAppModel
    let rule: AppRule
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.setRuleEnabled(bundleID: rule.bundleID, enabled: !rule.enabled)
            } label: {
                Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        rule.enabled
                            ? PrefsChrome.accent(scheme)
                            : Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.55)
                    )
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Image(nsImage: model.icon(for: rule.bundleID))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .cornerRadius(7)

            Text(rule.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PrefsChrome.label(scheme))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Same status labels as menu bar (已隐藏 / 监控中 / 已关闭)
            Text(model.statusText(for: rule))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(PrefsChrome.sec(scheme))
                .lineLimit(1)

            Button {
                model.removeRule(bundleID: rule.bundleID)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(hovering ? PrefsChrome.label(scheme) : PrefsChrome.sec(scheme))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("移除")
            .accessibilityLabel("移除")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(hovering ? PrefsChrome.rowHover(scheme) : Color.clear)
        .onHover { hovering = $0 }
    }
}

// MARK: - Log row (HTML .log-item: 36 | 1fr | auto, h 26)

private struct CompactLogRowView: View {
    let entry: LogEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            Text(timeString)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(PrefsChrome.activityMeta(scheme))
                .frame(width: 36, alignment: .leading)
            Text("\(entry.displayName) · \(eventLabel)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(PrefsChrome.activityBody(scheme))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortReason)
                .font(.system(size: 10.5))
                .foregroundStyle(PrefsChrome.activityMeta(scheme))
                .lineLimit(1)
                .frame(maxWidth: 56, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: PrefsChrome.activityRowHeight, alignment: .center)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.date)
    }

    private var eventLabel: String {
        switch entry.event {
        case "optimized": return "已优化"
        case "restored": return "已恢复"
        case "error": return "错误"
        default: return entry.event
        }
    }

    private var shortReason: String {
        let r = entry.reason
        if r.hasPrefix("background+") { return String(r.dropFirst("background".count)) }
        if r == "activated" { return "激活" }
        if r == "already_hidden" { return "已隐藏" }
        if r.contains("accessibility") || r.contains("ax_not") || r.contains("not_trusted") {
            return "需授权"
        }
        return r
    }
}
