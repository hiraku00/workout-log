import Foundation

/// Mac側の自動リビルド・バックアップスクリプトが書き込む状態ファイル
/// （Documents/workoutlog_status.json）のCodable表現。
/// スクリプト側が`devicectl device copy to`で端末へ送り込む。
struct DeviceSyncStatus: Codable {
    var lastBackupPulledAt: Date?
    var lastBackupResult: String?
    var lastRebuildAttemptAt: Date?
    var lastRebuildSuccessAt: Date?
    var lastRebuildResult: String?
    /// rebuild_and_install.shのREBUILD_INTERVAL_DAYSの値。次回実行予定日の計算に使う。
    var rebuildIntervalDays: Int?

    /// 前回の成功日時 + rebuildIntervalDaysで、次にリビルドが試みられる日を返す。
    /// どちらかが無ければ計算できない（まだ一度もリビルドが記録されていない等）。
    var nextRebuildDate: Date? {
        guard let lastRebuildSuccessAt, let rebuildIntervalDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: rebuildIntervalDays, to: lastRebuildSuccessAt)
    }
}

enum DeviceSyncStatusReader {
    static let fileName = "workoutlog_status.json"

    static func read() -> DeviceSyncStatus? {
        let url = URL.documentsDirectory.appending(path: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DeviceSyncStatus.self, from: data)
    }
}

/// このビルドに埋め込まれたprovisioning profile（embedded.mobileprovision）から
/// 有効期限を読み取る。Macを介さず端末上のアプリだけで完結する。
enum ProvisioningProfileReader {
    static func expirationDate() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              // embedded.mobileprovisionはCMS署名されたバイナリだが、中身のplist部分は
              // そのままASCIIで埋め込まれているため、開始・終了タグで抜き出して読める。
              let text = String(data: data, encoding: .isoLatin1) else { return nil }
        guard let startRange = text.range(of: "<?xml"),
              let endRange = text.range(of: "</plist>") else { return nil }

        let plistString = String(text[startRange.lowerBound..<endRange.upperBound])
        guard let plistData = plistString.data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else { return nil }

        return plist["ExpirationDate"] as? Date
    }
}
