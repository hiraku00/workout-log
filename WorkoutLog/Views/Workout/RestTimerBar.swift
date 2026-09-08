import SwiftUI

/// 休憩タイマーバー（添付アプリ風）
struct RestTimerBar: View {
    let timerDuration: Int
    let timerSeconds: Int
    let timerRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onEditDuration: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label("休憩", systemImage: "timer")
                .font(AppFont.subheadline).fontWeight(.semibold)

            Spacer()

            Button(action: onEditDuration) {
                Text(TimeInterval(timerRunning ? timerSeconds : timerDuration).timerString)
                    .font(AppFont.title3)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(timerRunning ? AppDesign.accent : Color.primary)
                    .frame(minWidth: 64)
            }
            .buttonStyle(.plain)
            .disabled(timerRunning)

            Button {
                if timerRunning {
                    onStop()
                } else {
                    onStart()
                }
            } label: {
                Image(systemName: timerRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(AppIconButtonStyle())
            .accessibilityLabel(timerRunning ? "タイマーを停止" : "タイマーを開始")
        }
        .appCard(cornerRadius: AppDesign.cornerLarge, padding: 12)
        .sensoryFeedback(.impact(weight: .light), trigger: timerRunning)
    }
}
