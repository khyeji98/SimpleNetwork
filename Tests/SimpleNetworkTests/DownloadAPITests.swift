import XCTest
@testable import SimpleNetwork

final class DownloadAPITests: XCTestCase {

    // MARK: - URL 생성

    func test_DownloadAPI_url이_baseURL과_path와_query를_결합하고_콤마를_인코딩한다() {
        let api = MockCommaDownloadAPI(
            query: MockCommaQuery(tags: "a,b,c"),
            destination: FileManager.default.temporaryDirectory.appendingPathComponent("out.bin")
        )

        let url = api.url

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.hasPrefix("https://cdn.example.com/files/fw.bin"))
        XCTAssertTrue(url!.absoluteString.contains("%2C"))
        XCTAssertFalse(url!.absoluteString.contains(","))

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "tags" })?.name, "tags")
    }

    // MARK: - 기본값

    func test_httpMethod_기본값은_get() {
        let api = MockSimpleDownloadAPI(
            destination: FileManager.default.temporaryDirectory.appendingPathComponent("out.bin")
        )

        XCTAssertEqual(api.httpMethod, .get)
    }

    func test_headers_기본값은_nil() {
        let api = MockSimpleDownloadAPI(
            destination: FileManager.default.temporaryDirectory.appendingPathComponent("out.bin")
        )

        XCTAssertNil(api.headers)
    }

    func test_query_기본값은_nil() {
        let api = MockSimpleDownloadAPI(
            destination: FileManager.default.temporaryDirectory.appendingPathComponent("out.bin")
        )

        XCTAssertNil(api.query)
    }
}

// MARK: - Test Helpers

private struct MockSimpleDownloadAPI: DownloadAPI {
    typealias Query = EmptyQuery

    var baseURL: String { "https://cdn.example.com" }
    var path: String { "/files/fw.bin" }
    let destination: URL
}

private struct MockCommaQuery: QueryParameter {
    let tags: String
}

private struct MockCommaDownloadAPI: DownloadAPI {
    typealias Query = MockCommaQuery

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://cdn.example.com" }
    var path: String { "/files/fw.bin" }
    let query: MockCommaQuery?
    let destination: URL
}
