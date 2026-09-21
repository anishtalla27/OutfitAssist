import Foundation

enum ClaudeService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // stored so it doesn't get deallocated mid-request
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // this is where the whole app lives - claude does everything
    static func analyze(transcript: String, image: String, completion: @escaping (String) -> Void) {
        let request = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let userRequest = request.isEmpty
            ? "No spoken request was captured. Identify the clothing pieces and colors, then suggest the best outfit combination from those pieces."
            : request
        performRequest(transcript: userRequest, image: image, attempt: 1, completion: completion)
    }

    private static func performRequest(transcript: String, image: String, attempt: Int, completion: @escaping (String) -> Void) {
        let fallback = "Sorry, I had trouble analyzing that. Please try again."

        let system = """
        You are OutfitAssist, an AI clothing assistant for blind \
        users. The image is supposed to show a small set of clothing \
        options, usually 2-10 separate pieces, not necessarily what \
        someone is wearing. First identify the visible clothing pieces \
        and their main colors. Then answer the user's request by choosing \
        or comparing pieces from the image. Treat anything the user said \
        about preferences, occasion, style, comfort, weather, or matching \
        as important. If there is no specific request, recommend the best \
        outfit combination from the visible pieces. Do not invent clothing \
        that is not visible unless you clearly frame it as an optional add-on. \
        Do not say "you are wearing" unless the user asks about something \
        they are currently wearing. Keep the response short and spoken-friendly, \
        usually 3-5 sentences. Be specific about colors and item types, but \
        say when something is uncertain instead of guessing. Never say you \
        cannot see the image.
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-5",
            "max_tokens": 300,
            "system": system,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": """
                            Spoken request or preference:
                            \(transcript)

                            Return only the answer the app should speak to the user.
                            Start by naming the visible items briefly, then give the outfit advice.
                            """
                        ],
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(fallback)
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Config.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyData

        session.dataTask(with: request) { data, _, error in
            // retry once after 1 second if the connection dropped
            if error != nil && attempt < 2 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    performRequest(transcript: transcript, image: image, attempt: attempt + 1, completion: completion)
                }
                return
            }

            guard error == nil,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let first = content.first,
                  let text = first["text"] as? String else {
                DispatchQueue.main.async { completion(fallback) }
                return
            }
            DispatchQueue.main.async { completion(text) }
        }.resume()
    }
}
