import Foundation
import UIKit

// MARK: - 種目の動作参考画像
enum ExerciseReference {
    /// 種目名からGoogle画像検索URLを生成する。
    static func imageSearchURL(for exerciseName: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "tbm", value: "isch"),
            URLQueryItem(name: "q", value: "\(exerciseName) 正しいフォーム")
        ]
        return components?.url
    }

    /// GoogleアプリのUniversal Linkを避け、Braveへ
    /// Google画像検索URLを渡す。Braveがない場合は通常のHTTPS URLへフォールバックする。
    static func openImageSearch(for exerciseName: String) {
        guard let searchURL = imageSearchURL(for: exerciseName) else { return }

        if let browserURL = braveOpenURL(for: searchURL),
           UIApplication.shared.canOpenURL(browserURL) {
            UIApplication.shared.open(browserURL)
        } else {
            UIApplication.shared.open(searchURL)
        }
    }

    static func braveOpenURL(for webURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "brave"
        components.host = "open-url"
        components.queryItems = [
            URLQueryItem(name: "url", value: webURL.absoluteString)
        ]
        return components.url
    }
}

