import XCTest
@testable import SimpleNetwork

final class URLSessionServiceHTTPErrorTests: XCTestCase {

    private var session: URLSession!
    private var service: URLSessionService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        URLProtocol.registerClass(MockURLProtocol.self)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = URLSessionService(
            session: session,
            encoder: JSONBodyEncoder(),
            decoder: JSONResponseDecoder(),
            logger: NetworkLogger(isEnabled: false)
        )
    }

    override func tearDownWithError() throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        session = nil
        service = nil
        try super.tearDownWithError()
    }

    // MARK: - HTTP 오류 전달

    func test_비_2xx_응답이면_httpError에_상태코드와_바디와_헤더가_보존된다() async {
        let expectedStatusCode = 422
        let expectedBody = Data(#"{"code":"validation_failed"}"#.utf8)
        let responseHeaders = [
            "Content-Type": "application/json",
            "X-Request-ID": "request-123"
        ]
        let expectedHeaders = [
            "content-type": "application/json",
            "x-request-id": "request-123"
        ]
        MockURLProtocol.stub(
            status: expectedStatusCode,
            headers: responseHeaders,
            chunks: [expectedBody]
        )

        do {
            _ = try await service.request(MockHTTPErrorAPI())
            XCTFail("에러가 발생하지 않았습니다")
        } catch {
            guard case .httpError(let statusCode, let data) = error as? NetworkError else {
                return XCTFail("기대: NetworkError.httpError, 실제: \(error)")
            }

            XCTAssertEqual(statusCode, expectedStatusCode)
            XCTAssertEqual(data.body, expectedBody)
            XCTAssertEqual(data.headers, expectedHeaders)
        }
    }

    func test_비_2xx_응답의_바디와_헤더가_비어있으면_httpError에_nil로_전달된다() async {
        let expectedStatusCode = 500
        MockURLProtocol.stub(status: expectedStatusCode)

        do {
            _ = try await service.request(MockHTTPErrorAPI())
            XCTFail("에러가 발생하지 않았습니다")
        } catch {
            guard case .httpError(let statusCode, let data) = error as? NetworkError else {
                return XCTFail("기대: NetworkError.httpError, 실제: \(error)")
            }

            XCTAssertEqual(statusCode, expectedStatusCode)
            XCTAssertNil(data.body)
            XCTAssertNil(data.headers)
        }
    }
}

// MARK: - Test Helpers

private struct MockHTTPErrorAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockHTTPErrorResponse

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.test" }
    var path: String { "/v1/error" }
}

private struct MockHTTPErrorResponse: Decodable {}
