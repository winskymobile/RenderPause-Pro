import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: UIAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("RenderPause Pro")
                    .font(.title2.weight(.semibold))

                Text("在名单应用离开前台一段时间后，自动隐藏或最小化窗口，减轻 WindowServer 负担，降低发热与耗电。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer().frame(height: 28)

            VStack(alignment: .leading, spacing: 14) {
                bullet("默认不会优化任何应用，请先加入名单。")
                bullet("默认策略为「隐藏」；「最小化」需要辅助功能权限。")
                bullet("切到其他应用并等待后台秒数后触发，切回立即恢复。")
            }

            Spacer().frame(height: 32)

            VStack(spacing: 10) {
                Button {
                    model.finishOnboarding()
                } label: {
                    Text("开始使用")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                HStack(spacing: 16) {
                    Button("添加应用…") {
                        model.addRunningApps()
                    }
                    .buttonStyle(.bordered)

                    Button("辅助功能设置…") {
                        model.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(32)
        .frame(width: 440, height: 380)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .imageScale(.medium)
                .padding(.top, 1)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
