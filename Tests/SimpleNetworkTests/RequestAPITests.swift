import XCTest
@testable import SimpleNetwork

final class RequestAPITests: XCTestCase {

    // MARK: - URL 생성

    func test_baseURL과_path로_URL_생성() {
        let api = MockGetAPI()

        XCTAssertEqual(api.url?.absoluteString, "https://api.example.com/v1/users")
    }

    func test_query가_있으면_URL에_쿼리_포함() {
        let api = MockSearchAPI(query: MockSearchQuery(page: 1, perPage: 20))
        let url = api.url

        XCTAssertNotNil(url)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let queryDict = Dictionary(
            (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { _, last in last }
        )
        XCTAssertEqual(queryDict["page"], "1")
        XCTAssertEqual(queryDict["per_page"], "20")
    }

    func test_query가_nil이면_쿼리_없는_URL() {
        let api = MockGetAPI()
        let url = api.url

        XCTAssertNil(URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems)
    }

    // MARK: - 기본값

    func test_headers_기본값은_nil() {
        let api = MockGetAPI()

        XCTAssertNil(api.headers)
    }

    func test_body_기본값은_nil() {
        let api = MockGetAPI()

        XCTAssertNil(api.body)
    }

    func test_query_기본값은_nil() {
        let api = MockGetAPI()

        XCTAssertNil(api.query)
    }

    // MARK: - HTTPHeaders 타입

    func test_headers가_HTTPHeaders_타입() {
        let api = MockAuthAPI()

        XCTAssertEqual(api.headers?.dictionary["Authorization"], "Bearer test-token")
        XCTAssertEqual(api.headers?.dictionary["Accept"], "application/json")
    }

    // MARK: - 쉼표 인코딩

    func test_쿼리_값에_쉼표가_있으면_인코딩() {
        let api = MockCommaAPI(query: MockCommaQuery(tags: "a,b,c"))
        let url = api.url

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("%2C"))
    }
}

// MARK: - Test Helpers

private struct MockResponse: Decodable {
    let id: Int
}

private struct MockGetAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockResponse

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
}

private struct MockSearchQuery: QueryParameter {
    let page: Int
    let perPage: Int
}

private struct MockSearchAPI: RequestAPI {
    typealias Query = MockSearchQuery
    typealias Response = MockResponse

    let query: MockSearchQuery?

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
}

private struct MockAuthAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = MockResponse

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/me" }
    var headers: HTTPHeaders? {
        [.authorization(bearer: "test-token"), .accept(.json)]
    }
}

private struct MockCommaQuery: QueryParameter {
    let tags: String
}

private struct MockCommaAPI: RequestAPI {
    typealias Query = MockCommaQuery
    typealias Response = MockResponse

    let query: MockCommaQuery?

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/items" }
}
