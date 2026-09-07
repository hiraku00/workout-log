import SwiftUI

/// Mac側の定期自動リビルド・バックアップの状態を確認する専用画面。
/// 証明書の有効期限はこの端末のprofileから直接読み取り、バックアップ・
/// リビルドの成否はMac側スクリプトが送り込むworkoutlog_status.jsonから読む。
struct SyncStatusView: View {
    private let calendar = Calendar.current

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
                            subtitle: isNear
                                ? "期限が近づいています。この後アプリが開けなくなったら、設定→一般→VPNとデバイス管理で「信頼」をタップしてください"
                                : "期限切れになるとアプリが起動できなくなります。次のリビルドで自動更新されます",
                            isWarning: isNear
                        )
                    } else {
                        statusRow(
                            title: "証明書の有効期限",
                            value: "不明",
                            subtitle: "この端末のprofileから期限を読み取れませんでした",
                            isWarning: false
                        )
                    }
                } header: {
                    Text("証明書")
                }

                Section {
                    let backupFailed = status?.lastBackupResult == "failed"
                    statusRow(
                        title: "最終バックアップ",
                        value: backupStatusDescription(status),
                        subtitle: backupFailed
                            ? "取得に失敗しています。iPhoneのロックを解除し、Macに接続しておいてください"
                            : "この日時までの記録がMacに退避されています",
                        isWarning: backupFailed
                    )

                    let rebuildFailed = status?.lastRebuildResult != nil && status?.lastRebuildResult != "success"
                    statusRow(
                        title: "最終リビルド",
                        value: rebuildStatusDescription(status),
                        subtitle: rebuildFailed
                            ? "更新に失敗しています。この状態が続くと証明書が失効し、アプリが起動できなくなります"
                            : "証明書を新しく発行し直し、期限切れを防ぐ処理です",
                        isWarning: rebuildFailed
                    )

                    statusRow(
                        title: "次回の実行予定",
                        value: nextRebuildDescription(status),
                        subtitle: "前回成功から\(status?.rebuildIntervalDays.map(String.init) ?? "5")日後の朝9:00に、初めて実際のビルドが試みられます（それまでは毎朝チェックだけして何もしません）",
                        isWarning: false
                    )
                } header: {
                    Text("Mac側の自動処理")
                } footer: {
                    Text("毎朝9:00に再ビルドの判定、9:10にバックアップ取得がMac上で自動実行されます。リビルドは毎日ではなく、前回成功から一定日数経った時だけ実際に走ります。アプリが開けなくなった時は、iPhoneの設定→一般→VPNとデバイス管理で「信頼」をタップしてください。")
                }
            }
            .navigationTitle("自動リビルド")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statusRow(title: String, value: String, subtitle: String, isWarning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(isWarning ? .orange : .secondary)
            }
            Text(subtitle)
                .font(AppFont.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
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
            return "取得失敗"
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

    private func nextRebuildDescription(_ status: DeviceSyncStatus?) -> String {
        guard let nextDate = status?.nextRebuildDate else { return "未定（まだ記録がありません）" }
        let days = daysUntil(nextDate)
        if days <= 0 { return "\(nextDate.shortDisplayString)以降" }
        return "\(nextDate.shortDisplayString)以降（あと\(days)日）"
    }

    private func dateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
