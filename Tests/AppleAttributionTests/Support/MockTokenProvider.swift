import Foundation
@testable import AppleAttribution

final class MockTokenProvider: AttributionTokenProviding {
    enum ProviderError: Error { case boom }
    var result: Result<String, Error>
    init(result: Result<String, Error>) { self.result = result }
    func attributionToken() throws -> String {
        switch result {
        case .success(let t): return t
        case .failure(let e): throw e
        }
    }
}
