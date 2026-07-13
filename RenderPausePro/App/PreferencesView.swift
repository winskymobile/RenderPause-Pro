import AppKit
import SwiftUI

struct PreferencesView: View {
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
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("后台满")
                    Spacer()
                    TextField(
                        "",
                        value: backgroundSecondsBinding,
                        format: .number
                    )
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
                    .foregroundStyle(.secondary)
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

            Section {
                if model.rules.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("还没有应用")
                            .font(.body.weight(.medium))
                        Text("添加需要在后台自动隐藏或最小化的应用。默认不会优化任何应用。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("添加应用…") {
                            model.addRunningApps()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    List(selection: $model.selectedRuleIDs) {
                        ForEach(model.rules) { rule in
                            RuleRowView(model: model, rule: rule)
                                .tag(rule.bundleID)
                        }
                    }
                    .frame(minHeight: 180, maxHeight: 240)
                    .listStyle(.inset(alternatesRowBackgrounds: true))

                    HStack(spacing: 10) {
                        Button("添加…") { model.addRunningApps() }
                        Button("移除") { model.removeSelectedRules() }
                            .disabled(model.selectedRuleIDs.isEmpty)
                        Spacer()
                    }
                    .controlSize(.regular)
                }
            } header: {
                Text("应用名单")
            } footer: {
                Text("名单内的应用才会被优化。策略为「隐藏」或「最小化」。")
                    .foregroundStyle(.secondary)
            }

            Section {
                if model.logEntries.isEmpty {
                    Text("暂无活动记录")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    List {
                        ForEach(model.logEntries.prefix(12)) { entry in
                            LogRowView(entry: entry)
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 160)
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            } header: {
                Text("最近活动")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .frame(minWidth: 500, idealWidth: 520, minHeight: 600, idealHeight: 640)
        .onAppear { model.refresh() }
    }

    private var statusSummary: String {
        let n = model.todayOptimizeCount
        let s = Int(model.settings.backgroundSeconds)
        return "今日 \(n) 次 · 后台 \(s) 秒"
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
                .frame(width: 54, alignment: .leading)
            Text(entry.displayName)
                .font(.callout)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
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
        .padding(.vertical, 2)
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
