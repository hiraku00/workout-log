import Foundation

/// 削除したワークアウトのIDを端末内に記録しておく「墓標」。
///
/// Mac側の自動リビルドは、直近のバックアップ（最大30世代を保持）をアプリの
/// 復元用ファイルとして端末へ定期的に送り込む（`rebuild_and_install.sh`）。
/// そのタイミングがユーザーの削除操作より後になると、`DataBackupImporter`は
/// 「IDが存在しないなら復元する」だけを見て、削除したはずの記録をそのまま
/// 復活させてしまう。ここに削除済みIDを記録しておき、復元処理側で除外することで、
/// 意図的に削除した記録がバックグラウンド同期で生き返るのを防ぐ。
///
/// アンインストール等でデータコンテナごと失われた場合はこの記録も一緒に消えるため、
/// 「本当にデータを失った」正規の復元シナリオは従来通り機能する。
enum DeletedWorkoutTombstones {
    private static let key = "deletedWorkoutIDs"
    /// 際限なく増え続けないよう、直近に削除した分だけを保持する。
    private static let maxEntries = 200

    static func record(_ id: UUID) {
        var ids = storedIDStrings()
        ids.removeAll { $0 == id.uuidString }
        ids.append(id.uuidString)
        if ids.count > maxEntries {
            ids.removeFirst(ids.count - maxEntries)
        }
        UserDefaults.standard.set(ids, forKey: key)
    }

    static func record<S: Sequence>(_ ids: S) where S.Element == UUID {
        for id in ids { record(id) }
    }

    static func contains(_ id: UUID) -> Bool {
        storedIDStrings().contains(id.uuidString)
    }

    private static func storedIDStrings() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}
