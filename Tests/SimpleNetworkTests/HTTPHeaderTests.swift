import XCTest
@testable import SimpleNetwork

final class HTTPHeaderTests: XCTestCase {

    // MARK: - HTTPHeader

    func test_HTTPHeader_초기화() {
        let header = HTTPHeader(name: "X-Custom", value: "test")

        XCTAssertEqual(header.name, "X-Custom")
        XCTAssertEqual(header.value, "test")
    }

    func test_authorization_값_헤더_생성() {
        let header = HTTPHeader.authorization("Basic abc123")

        XCTAssertEqual(header.name, "Authorization")
        XCTAssertEqual(header.value, "Basic abc123")
    }

    func test_authorization_bearer_헤더_생성() {
        let header = HTTPHeader.authorization(bearer: "tok_abc")

        XCTAssertEqual(header.name, "Authorization")
        XCTAssertEqual(header.value, "Bearer tok_abc")
    }

    func test_contentType_헤더_생성() {
        let header = HTTPHeader.contentType(.json)

        XCTAssertEqual(header.name, "Content-Type")
        XCTAssertEqual(header.value, "application/json")
    }

    func test_accept_헤더_생성() {
        let header = HTTPHeader.accept(.xml)

        XCTAssertEqual(header.name, "Accept")
        XCTAssertEqual(header.value, "application/xml")
    }

    func test_userAgent_헤더_생성() {
        let header = HTTPHeader.userAgent("SimpleNetwork/1.0")

        XCTAssertEqual(header.name, "User-Agent")
        XCTAssertEqual(header.value, "SimpleNetwork/1.0")
    }

    func test_acceptLanguage_헤더_생성() {
        let header = HTTPHeader.acceptLanguage("ko-KR")

        XCTAssertEqual(header.name, "Accept-Language")
        XCTAssertEqual(header.value, "ko-KR")
    }

    func test_custom_헤더_생성() {
        let header = HTTPHeader.custom(name: "X-Request-ID", value: "uuid-123")

        XCTAssertEqual(header.name, "X-Request-ID")
        XCTAssertEqual(header.value, "uuid-123")
    }

    func test_HTTPHeader_Equatable() {
        let a = HTTPHeader.contentType(.json)
        let b = HTTPHeader.contentType(.json)
        let c = HTTPHeader.contentType(.xml)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - HTTPHeaders

    func test_HTTPHeaders_빈_초기화() {
        let headers = HTTPHeaders()

        XCTAssertEqual(headers.dictionary, [:])
    }

    func test_HTTPHeaders_배열_초기화() {
        let headers = HTTPHeaders([
            HTTPHeader.contentType(.json),
            HTTPHeader.accept(.json)
        ])

        XCTAssertEqual(headers.dictionary["Content-Type"], "application/json")
        XCTAssertEqual(headers.dictionary["Accept"], "application/json")
    }

    func test_HTTPHeaders_ExpressibleByArrayLiteral() {
        let headers: HTTPHeaders = [
            .authorization(bearer: "token"),
            .contentType(.json)
        ]

        XCTAssertEqual(headers.dictionary["Authorization"], "Bearer token")
        XCTAssertEqual(headers.dictionary["Content-Type"], "application/json")
    }

    func test_HTTPHeaders_같은_이름_헤더_교체() {
        var headers: HTTPHeaders = [.contentType(.json)]
        headers.add(.contentType(.xml))

        XCTAssertEqual(headers.dictionary["Content-Type"], "application/xml")
        XCTAssertEqual(headers.dictionary.count, 1)
    }

    func test_HTTPHeaders_같은_이름_대소문자_무시_교체() {
        var headers = HTTPHeaders([HTTPHeader(name: "content-type", value: "text/plain")])
        headers.add(.contentType(.json))

        XCTAssertEqual(headers.dictionary.count, 1)
        XCTAssertEqual(headers.dictionary["Content-Type"], "application/json")
    }

    func test_HTTPHeaders_add_새_헤더_추가() {
        var headers: HTTPHeaders = [.contentType(.json)]
        headers.add(.accept(.json))

        XCTAssertEqual(headers.dictionary.count, 2)
    }

    func test_HTTPHeaders_Equatable() {
        let a: HTTPHeaders = [.contentType(.json)]
        let b: HTTPHeaders = [.contentType(.json)]

        XCTAssertEqual(a, b)
    }
}
