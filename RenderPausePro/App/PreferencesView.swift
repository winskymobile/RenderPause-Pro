import AppKit
import SwiftUI

private enum PreferencesTab: String, CaseIterable, Identifiable {
    case apps = "应用名单"
    case settings = "设置"
    case activity = "最近活动"

    var id: String { rawValue }
}

struct PreferencesView: View {
    @ObservedObject var model: UIAppModel
    @State private var tab: PreferencesTab = .apps

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(PreferencesTab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch tab {
                case .apps:
                    AppsTabView(model: model)
                case .settings:
                    SettingsTabView(model: model)
                case .activity:
                    ActivityTabView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 520, idealWidth: 540, minHeight: 520, idealHeight: 560)
        .onAppear { model.refresh() }
    }
}

// MARK: - Tab 1: Apps

private struct AppsTabView: View {
    @ObservedObject var model: UIAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("应用名单")
                        .font(.title3.weight(.semibold))
                    Text("仅名单内的应用会在离开前台后被自动优化。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("添加…") { model.addRunningApps() }
                    Button("移除") { model.removeSelectedRules() }
                        .disabled(model.selectedRuleIDs.isEmpty)
                }
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if model.rules.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 24)
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.tertiary)
                    Text("还没有应用")
                        .font(.body.weight(.medium))
                    Text("添加需要在后台自动隐藏或最小化的应用。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                    Button("添加应用…") { model.addRunningApps() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
            } else {
                List(selection: $model.selectedRuleIDs) {
                    ForEach(model.rules) { rule in
                        RuleRowView(model: model, rule: rule)
                            .tag(rule.bundleID)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Tab 2: Settings

private struct SettingsTabView: View {
    @ObservedObject var model: UIAppModel

    var body: some View {
        Form {
            Section {
                Toggle("启用监控", isOn: monitoringBinding)
                LabeledContent("状态") {
                    Text(statusSummary)
                        .foregroundStyle(.secondary)
                        .font(.body.monospacedDigit())
                }
            } header: {
                Text("状态")
            } footer: {
                Text("关闭监控后不会再自动隐藏或最小化名单中的应用。")
            }

            Section {
                HStack {
                    Text("后台满")
                    Spacer()
                    TextField("", value: backgroundSecondsBinding, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .textFieldStyle(.roundedBorder)
                    Stepper("", value: backgroundSecondsBinding, in: 5...600, step: 5)
                        .labelsHidden()
                    Text("秒后优化")
                        .foregroundStyle(.secondary)
                }
                Toggle("登录时启动", isOn: launchBinding)
            } header: {
                Text("通用")
            } footer: {
                Text("应用离开前台并达到该秒数后才会优化；输入法与分屏伙伴不会误触发。范围 5–600 秒。")
            }

            Section {
                LabeledContent("辅助功能") {
                    Text(model.accessibilityTrusted ? "已授权" : "未授权")
                        .foregroundStyle(model.accessibilityTrusted ? .secondary : .primary)
                }
                if !model.accessibilityTrusted {
                    Text("最小化策略需要辅助功能权限；隐藏策略不需要。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button("打开系统设置…") {
                    model.openAccessibilitySettings()
                }
            } header: {
                Text("权限")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    private var statusSummary: String {
        "今日 \(model.todayOptimizeCount) 次 · 后台 \(Int(model.settings.backgroundSeconds)) 秒"
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

// MARK: - Tab 3: Activity

private struct ActivityTabView: View {
    @ObservedObject var model: UIAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近活动")
                        .font(.title3.weight(.semibold))
                    Text("记录自动优化、恢复与错误。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if model.logEntries.isEmpty {
                VStack(spacing: 10) {
                    Spacer(minLength: 24)
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("暂无活动记录")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.logEntries) { entry in
                        LogRowView(entry: entry)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Rows

private struct RuleRowView: View {
    @ObservedObject var model: UIAppModel
    let rule: AppRule

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: model.icon(for: rule.bundleID))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(rule.bundleID)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Picker("", selection: actionBinding) {
                Text("隐藏").tag(OptimizeAction.hide)
                Text("最小化").tag(OptimizeAction.minimize)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 88)

            Toggle("", isOn: enabledBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var actionBinding: Binding<OptimizeAction> {
        Binding(
            get: { rule.action },
            set: { model.setRuleAction(bundleID: rule.bundleID, action: $0) }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule.enabled },
            set: { model.setRuleEnabled(bundleID: rule.bundleID, enabled: $0) }
        )
    }
}

private struct LogRowView: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timeString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(entry.displayName)
                .font(.callout)
                .lineLimit(1)
                .frame(minWidth: 88, idealWidth: 110, maxWidth: 140, alignment: .leading)
            Text(eventLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(entry.reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
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
}
