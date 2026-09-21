import Foundation

enum Config {
    static let claudeAPIKey: String = {
        guard
            let url = Bundle.main.url(forResource: "secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let key = dict["CLAUDE_API_KEY"] as? String,
            !key.isEmpty
        else {
            fatalError(
                "Missing CLAUDE_API_KEY in secrets.plist. " +
                "Add secrets.plist to the app target (not just the folder) " +
                "with a CLAUDE_API_KEY string entry."
            )
        }
        return key
    }()
}
