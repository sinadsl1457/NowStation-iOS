import Foundation

/** 연결 실패와 서버 오류를 나눈다(지하에서 끊김 → 마지막 상태 유지, 서버가 모른다 → 탑승 끝). */
enum APIError: Error, Equatable {
    case network
    case notFound
    case badRequest
    case server(Int)
    case decoding
}

/** NowStation-Server API. 주소는 Info.plist의 APIBaseURL(빌드 설정 API_BASE_URL). */
final class APIClient {
    let baseURL: URL
    private let session: URLSession

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(baseURL: URL = APIClient.configuredBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static var configuredBaseURL: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
        return URL(string: raw ?? "") ?? URL(string: "http://localhost:8080/")!
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        return try await send(URLRequest(url: components.url!))
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
        return try await send(request)
    }

    func postNoContent<B: Encodable>(_ path: String, body: B) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
        _ = try await data(for: request)
    }

    func delete(_ path: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "DELETE"
        _ = try await data(for: request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await data(for: request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func data(for request: URLRequest) async throws -> Data {
        var request = request
        request.timeoutInterval = 10
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // 앱이 취소한 요청(한글 입력 중 앞 검색 등)은 연결 실패가 아니다
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw APIError.network
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 200..<300: return data
        case 404: throw APIError.notFound
        case 400..<500: throw APIError.badRequest
        default: throw APIError.server(code)
        }
    }
}
