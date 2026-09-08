import Foundation
import AVFoundation
import AlarmKit
import UserNotifications
import UIKit

/// 休憩タイマーの状態・通知・アラーム連携を一元管理する。
///
/// 以前は`ExerciseDetailView`が`@State`でタイマーを保持していたため、種目詳細画面を
/// 離れる（NavigationLinkを戻る）とタイマー用の`Timer`がリークしたまま動き続け、
/// 誰も見ていない画面に向けて完了アラートを立てようとする不具合があった。
/// アプリ内で同時に有効な休憩タイマーは実質1つ（1種目の1セット休憩）という前提のもと、
/// `WorkoutViewModel`がこのコントローラを1つだけ保持し、どの画面が表示されているかに
/// 関わらずタイマーの進行・通知が正しく続くようにする。
@Observable
final class RestTimerController {
    /// タイマーの対象になっている種目のID。画面側が「自分の種目のタイマーか」を判定するために使う。
    private(set) var activeExerciseID: UUID?
    private(set) var isRunning = false
    private(set) var secondsRemaining = 0

    /// フォアグラウンドでタイマーが完了した瞬間に対象の種目IDがセットされる。
    /// 画面側はこれを見て完了アラートを表示し、確認したらnilに戻す。
    var justCompletedExerciseID: UUID?

    private var ticker: Timer?
    private var endDate: Date?
    private var usingSystemAlarm = false
    private let completionSound = TimerCompletionSoundPlayer()
    private var backgroundToken: NSObjectProtocol?
    private var foregroundToken: NSObjectProtocol?

    /// 端末上で唯一の休憩タイマーが使う固定ID。種目ごとに変える必要がなく、
    /// アプリ再起動をまたいでも確実に同じ通知・アラームをキャンセルできる。
    private static let notificationIdentifier = "rest-timer"
    private static let alarmID = UUID(uuidString: "6C1D6E7E-6F5A-4B3E-9B7A-1F2C3D4E5F60")!

    init() {
        backgroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopTicking()
        }
        foregroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleForeground()
        }
    }

    deinit {
        if let backgroundToken { NotificationCenter.default.removeObserver(backgroundToken) }
        if let foregroundToken { NotificationCenter.default.removeObserver(foregroundToken) }
    }

    // MARK: - 操作

    func start(for exerciseID: UUID, duration: Int) {
        stopTicking()
        cancelPendingAlerts()
        activeExerciseID = exerciseID
        isRunning = true
        secondsRemaining = duration
        let end = Date().addingTimeInterval(TimeInterval(duration))
        endDate = end
        scheduleCompletionAlert(at: end)
        startTicking()
    }

    func stop() {
        isRunning = false
        endDate = nil
        stopTicking()
        cancelPendingAlerts()
    }

    // MARK: - Ticker

    private func startTicking() {
        let nextTicker = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick(presentCompletionAlert: true)
        }
        ticker = nextTicker
        RunLoop.main.add(nextTicker, forMode: .common)
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick(presentCompletionAlert: Bool) {
        guard let endDate else { return }
        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else {
            secondsRemaining = 0
            isRunning = false
            self.endDate = nil
            stopTicking()
            if presentCompletionAlert, !usingSystemAlarm, let exerciseID = activeExerciseID {
                completionSound.play()
                justCompletedExerciseID = exerciseID
            }
            usingSystemAlarm = false
            return
        }
        secondsRemaining = Int(ceil(remaining))
    }

    private func handleForeground() {
        guard isRunning else { return }
        tick(presentCompletionAlert: false)
        if isRunning { startTicking() }
    }

    // MARK: - 通知・アラーム

    private func scheduleCompletionAlert(at endDate: Date) {
        usingSystemAlarm = false
        Task { @MainActor in
            await scheduleAlarmKitTimer(at: endDate)
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    private func scheduleAlarmKitTimer(at endDate: Date) async {
        do {
            let manager = AlarmManager.shared
            let authorization: AlarmManager.AuthorizationState
            if manager.authorizationState == .notDetermined {
                authorization = try await manager.requestAuthorization()
            } else {
                authorization = manager.authorizationState
            }

            guard authorization == .authorized, isRunning, self.endDate == endDate else {
                scheduleTimerNotification(at: endDate)
                return
            }

            let alert: AlarmPresentation.Alert
            if #available(iOS 26.1, *) {
                alert = AlarmPresentation.Alert(title: "休憩終了")
            } else {
                let stopButton = AlarmButton(
                    text: "停止",
                    textColor: .white,
                    systemImageName: "stop.circle.fill"
                )
                alert = AlarmPresentation.Alert(title: "休憩終了", stopButton: stopButton)
            }

            let attributes = AlarmAttributes<RestTimerAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                tintColor: AppDesign.accent
            )
            let configuration = AlarmManager.AlarmConfiguration<RestTimerAlarmMetadata>.alarm(
                schedule: .fixed(endDate),
                attributes: attributes,
                sound: .default
            )

            try? manager.cancel(id: Self.alarmID)
            _ = try await manager.schedule(id: Self.alarmID, configuration: configuration)
            usingSystemAlarm = true
        } catch {
            scheduleTimerNotification(at: endDate)
            print("AlarmKitでの休憩アラーム登録に失敗しました: \(error)")
        }
    }

    private func scheduleTimerNotification(at endDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { self.addTimerNotification(to: center, at: endDate) }
                }
            case .authorized, .provisional, .ephemeral:
                self.addTimerNotification(to: center, at: endDate)
            default:
                break
            }
        }
    }

    private func addTimerNotification(to center: UNUserNotificationCenter, at endDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "休憩終了"
        content.body = "次のセットを始めましょう。"
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, endDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.add(request)
    }

    private func cancelPendingAlerts() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        try? AlarmManager.shared.cancel(id: Self.alarmID)
        usingSystemAlarm = false
    }
}

@available(iOS 26.0, *)
private struct RestTimerAlarmMetadata: AlarmMetadata {}

/// 消音スイッチの状態に左右されず、前面表示中の休憩終了を伝える短いアラーム。
private final class TimerCompletionSoundPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(forResource: "rest_timer_alarm", withExtension: "wav") else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = 1
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            print("休憩終了アラームの再生に失敗しました: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        player = nil
        restoreOtherAudio()
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: Error?) {
        player = nil
        restoreOtherAudio()
    }

    private func restoreOtherAudio() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }
}
