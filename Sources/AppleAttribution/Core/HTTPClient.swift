import Foundation

/// Seam di trasporto: restituisce lo status code HTTP o un errore di rete.
protocol HTTPClient {
    func post(_ request: URLRequest, completion: @escaping (Result<Int, Error>) -> Void)
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func post(_ request: URLRequest, completion: @escaping (Result<Int, Error>) -> Void) {
        session.dataTask(with: request) { _, response, error in
            if let error = error { completion(.failure(error)); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(.success(status))
        }.resume()
    }
}
