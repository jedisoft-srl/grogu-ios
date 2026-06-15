import Foundation
@testable import AppleAttribution

/// HTTPClient sincrono per i test: registra le richieste e restituisce un esito stubbed.
final class MockHTTPClient: HTTPClient {
    var stubbed: Result<Int, Error> = .success(202)
    private(set) var requests: [URLRequest] = []

    func post(_ request: URLRequest, completion: @escaping (Result<Int, Error>) -> Void) {
        requests.append(request)
        completion(stubbed)
    }

    var lastBodyJSON: [String: Any]? {
        guard let body = requests.last?.httpBody,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return nil }
        return obj
    }
}
