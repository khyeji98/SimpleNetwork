import XCTest
@testable import SimpleNetwork

final class BodyEncoderTests: XCTestCase {

    private var session: URLSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        URLProtocol.registerClass(MockURLProtocol.self)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDownWithError() throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        session = nil
        try super.tearDownWithError()
    }

    // MARK: - JSONBodyEncoder 단위

    func test_기본_인코더는_키를_변환하지_않는다() throws {
        let data = try JSONBodyEncoder().encode(MockBody(userName: "hyeji"))

        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"userName":"hyeji"}"#)
    }

    func test_키_변환_전략이_적용된다() throws {
        let encoder = JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase)
        let data = try encoder.encode(MockBody(userName: "hyeji"))

        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"user_name":"hyeji"}"#)
    }

    func test_maxByteCount_이내면_인코딩에_성공한다() throws {
        let encoder = JSONBodyEncoder(maxByteCount: 100)
        let data = try encoder.encode(MockBody(userName: "hyeji"))

        XCTAssertEqual(data.count, 20)
    }

    func test_maxByteCount를_초과하면_bodyTooLarge를_던진다() {
        let encoder = JSONBodyEncoder(maxByteCount: 10)

        XCTAssertThrowsError(try encoder.encode(MockBody(userName: "hyeji"))) { error in
            guard case .bodyTooLarge(let byteCount, let limit) = error as? NetworkError else {
                return XCTFail("bodyTooLarge가 아닙니다: \(error)")
            }
            XCTAssertEqual(byteCount, 20)
            XCTAssertEqual(limit, 10)
        }
    }

    // MARK: - JSONResponseDecoder 단위

    func test_키_디코딩_전략이_적용된다() throws {
        let decoder = JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)
        let data = #"{"user_name":"hyeji"}"#.data(using: .utf8)!

        let decoded = try decoder.decode(MockBody.self, from: data)

        XCTAssertEqual(decoded.userName, "hyeji")
    }

    // MARK: - 인코더 해석 (서비스 기본값 vs API 재정의)

    func test_API가_재정의하지_않으면_서비스_기본_인코더를_사용한다() async throws {
        MockURLProtocol.stub(chunks: [mockBodyResponseData])
        let service = URLSessionService(
            session: session,
            encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase),
            logger: NetworkLogger(isEnabled: false)
        )

        _ = try await service.request(MockPostAPI())

        XCTAssertEqual(sentBodyString(), #"{"user_name":"hyeji"}"#)
    }

    func test_API의_인코더_재정의가_서비스_기본값보다_우선한다() async throws {
        MockURLProtocol.stub(chunks: [mockBodyResponseData])
        let service = URLSessionService(
            session: session,
            encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase),
            logger: NetworkLogger(isEnabled: false)
        )

        _ = try await service.request(MockCustomEncoderAPI())

        XCTAssertEqual(sentBodyString(), #"{"userName":"hyeji"}"#)
    }

    func test_API의_디코더_재정의가_서비스_기본값보다_우선한다() async throws {
        MockURLProtocol.stub(chunks: [#"{"user_name":"hyeji"}"#.data(using: .utf8)!])
        let service = URLSessionService(
            session: session,
            decoder: JSONResponseDecoder(),
            logger: NetworkLogger(isEnabled: false)
        )

        let response = try await service.request(MockCustomDecoderAPI())

        XCTAssertEqual(response.userName, "hyeji")
    }

    // MARK: - 에러 전파

    func test_크기_제한을_초과하면_요청이_전송되지_않는다() async {
        MockURLProtocol.stub(chunks: [mockBodyResponseData])
        let service = URLSessionService(session: session, logger: NetworkLogger(isEnabled: false))

        do {
            _ = try await service.request(MockSizeLimitedAPI())
            XCTFail("에러가 발생하지 않았습니다")
        } catch {
            guard case .bodyTooLarge = error as? NetworkError else {
                return XCTFail("bodyTooLarge가 아닙니다: \(error)")
            }
        }

        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func test_커스텀_인코더가_던진_에러가_encodingFailed로_보존된다() async {
        MockURLProtocol.stub(chunks: [mockBodyResponseData])
        let service = URLSessionService(session: session, logger: NetworkLogger(isEnabled: false))

        do {
            _ = try await service.request(MockFailingEncoderAPI())
            XCTFail("에러가 발생하지 않았습니다")
        } catch {
            guard case .encodingFailed(let underlying) = error as? NetworkError else {
                return XCTFail("encodingFailed가 아닙니다: \(error)")
            }
            XCTAssertEqual(underlying as? MockEncoderError, .rejected)
        }
    }

    // MARK: - Helpers

    private var mockBodyResponseData: Data {
        #"{"userName":"hyeji"}"#.data(using: .utf8)!
    }

    private func sentBodyString() -> String? {
        guard let request = MockURLProtocol.requests.first,
              let body = MockURLProtocol.bodyData(of: request)
        else { return nil }

        return String(data: body, encoding: .utf8)
    }
}

// MARK: - Test Helpers

private struct MockBody: Codable, Sendable {
    let userName: String
}

private enum MockEncoderError: Error, Equatable {
    case rejected
}

private struct FailingEncoder: BodyEncoder {
    func encode(_ body: any Encodable & Sendable) throws -> Data {
        throw MockEncoderError.rejected
    }
}

private struct MockPostAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockBody

    var httpMethod: HTTPMethod { .post }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var body: (any Encodable & Sendable)? { MockBody(userName: "hyeji") }
}

private struct MockCustomEncoderAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockBody

    var httpMethod: HTTPMethod { .post }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var body: (any Encodable & Sendable)? { MockBody(userName: "hyeji") }
    var encoder: (any BodyEncoder)? { JSONBodyEncoder() }
}

private struct MockCustomDecoderAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockBody

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var decoder: (any ResponseDecoder)? {
        JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)
    }
}

private struct MockSizeLimitedAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockBody

    var httpMethod: HTTPMethod { .post }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var body: (any Encodable & Sendable)? { MockBody(userName: "hyeji") }
    var encoder: (any BodyEncoder)? { JSONBodyEncoder(maxByteCount: 5) }
}

private struct MockFailingEncoderAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockBody

    var httpMethod: HTTPMethod { .post }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var body: (any Encodable & Sendable)? { MockBody(userName: "hyeji") }
    var encoder: (any BodyEncoder)? { FailingEncoder() }
}
