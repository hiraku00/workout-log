import SwiftUI

/// Mac側の定期自動リビルド・バックアップの状態を確認する専用画面。
/// 証明書の有効期限はこの端末のprofileから直接読み取り、バックアップ・
/// リビルドの成否はMac側スクリプトが送り込むworkoutlog_status.jsonから読む。
struct SyncStatusView: View {
    private let calendar = Calendar.current
    private static let trustSteps = "Settings → General → VPN & Device Management → Trust"

    private var profileExpiration: Date? {
        ProvisioningProfileReader.expirationDate()
    }

    private var status: DeviceSyncStatus? {
        DeviceSyncStatusReader.read()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let profileExpiration {
                        let remainingDays = daysUntil(profileExpiration)
                        let isNear = remainingDays <= 2
                        statusRow(
                            title: "証明書の有効期限",
                            value: profileExpirationDescription(profileExpiration, remainingDays: remainingDays),
                            subtitle: "アプリを実行するための許可証（無料のApple IDでは7日で失効）",
                            action: isNear ? "起動できない時は \(Self.trustSteps) をタップ" : nil,
                            isWarning: isNear
                        )
                    } else {
                        statusRow(
                            title: "証明書の有効期限",
                            value: "不明",
                            subtitle: "アプリを実行するための許可証（無料のApple IDでは7日で失効）",
                            action: nil,
                            isWarning: false
                        )
                    }
                } header: {
                    Text("証明書とは")
                } footer: {
                    Text("""
                    Appleの無料アカウントは、アプリを動かす許可証（provisioning profile）が7日ごとに切れる仕様です。

                    期限切れになると、アプリのアイコンをタップしても起動できなくなります。切れる前にMacが自動で新しい許可証を発行し直すので、通常は何もしなくて大丈夫です。

                    もし既に起動できなくなっていたら:
                    1. iPhoneのロックを解除し、Macに接続する
                    2. 自動的に再ビルドされるのを待つ（下の「Mac側の自動処理」参照）
                    3. \(Self.trustSteps) をタップする
                    """)
                }

                Section {
                    let backupFailed = status?.lastBackupResult == "failed"
                    statusRow(
                        title: "最終バックアップ",
                        value: backupStatusDescription(status),
                        subtitle: "その日の記録をMacへ複製した日時。データが消えても復元できる保険",
                        action: backupFailed ? "取得に失敗中。iPhoneのロックを解除してMacに接続してください" : nil,
                        isWarning: backupFailed
                    )

                    let rebuildFailed = status?.lastRebuildResult != nil && status?.lastRebuildResult != "success"
                    statusRow(
                        title: "最終リビルド",
                        value: rebuildStatusDescription(status),
                        subtitle: "許可証を新しく発行し直した日時。上の「証明書の有効期限」を延長する処理",
                        action: rebuildFailed ? "更新に失敗中。このままだと証明書が失効します" : nil,
                        isWarning: rebuildFailed
                    )

                    let next = nextRebuildInfo(status)
                    statusRow(
                        title: "次回の実行予定",
                        value: next.value,
                        subtitle: "上の「証明書の有効期限」が切れる前に、次の更新を試みる予定日",
                        action: next.isOverdue ? "予定日を過ぎています。iPhoneをMacに接続してください" : nil,
                        isWarning: next.isOverdue
                    )
                } header: {
                    Text("Mac側の自動処理")
                } footer: {
                    Text("""
                    バックアップとリビルドは、Mac上で30分おきに終日チェックされます。

                    起動できない時は \(Self.trustSteps) をタップしてください。
                    """)
                }
            }
            .navigationTitle("自動リビルド")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statusRow(title: String, value: String, subtitle: String, action: String?, isWarning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isWarning ? .orange : .secondary.opacity(0.5))
                    .font(.system(size: 13))
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(isWarning ? .orange : .secondary)
                    .fontWeight(isWarning ? .semibold : .regular)
            }
            Text(subtitle)
                .font(AppFont.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 19)
            if let action {
                Text("→ \(action)")
                    .font(AppFont.caption2)
                    .foregroundStyle(.orange)
                    .padding(.leading, 19)
            }
        }
        .padding(.vertical, 3)
    }

    private func daysUntil(_ date: Date) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    private func profileExpirationDescription(_ date: Date, remainingDays days: Int) -> String {
        if days < 0 { return "\(date.shortDisplayString)（期限切れ）" }
        if days == 0 { return "\(date.shortDisplayString)（本日まで）" }
        return "\(date.shortDisplayString)（あと\(days)日）"
    }

    private func backupStatusDescription(_ status: DeviceSyncStatus?) -> String {
        guard let status else { return "未取得" }
        if status.lastBackupResult == "failed" {
            guard let attemptDate = status.lastBackupAttemptAt else { return "取得失敗" }
            return "取得失敗（\(dateTimeString(attemptDate))時点）"
        }
        guard let date = status.lastBackupPulledAt else { return "未取得" }
        return dateTimeString(date)
    }

    private func rebuildStatusDescription(_ status: DeviceSyncStatus?) -> String {
        guard let status, let result = status.lastRebuildResult else { return "未実行" }
        switch result {
        case "success":
            guard let date = status.lastRebuildSuccessAt else { return "成功" }
            return dateTimeString(date)
        default:
            return "失敗"
        }
    }

    /// 次回リビルド予定日の表示文字列と、その予定日を過ぎてしまっているか（＝催促が必要か）を返す。
    private func nextRebuildInfo(_ status: DeviceSyncStatus?) -> (value: String, isOverdue: Bool) {
        guard let nextDate = status?.nextRebuildDate else {
            return ("未定（まだ記録がありません）", false)
        }
        let days = daysUntil(nextDate)
        if days < 0 {
            return ("\(nextDate.shortDisplayString)（予定日超過）", true)
        }
        if days == 0 {
            return ("\(nextDate.shortDisplayString)以降", false)
        }
        return ("\(nextDate.shortDisplayString)以降（あと\(days)日）", false)
    }

    private func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
