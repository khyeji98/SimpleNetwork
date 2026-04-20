import XCTest
@testable import SimpleNetwork

final class QueryParameterTests: XCTestCase {

    // MARK: - QueryParameter 자동 변환

    func test_QueryParameter_자동_변환() {
        let query = SampleQuery(page: 1, perPage: 20)
        let items = query.queryItems

        let dict = Dictionary(items.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(dict["page"], "1")
        XCTAssertEqual(dict["per_page"], "20")
    }

    func test_QueryParameter_문자열_프로퍼티_변환() {
        let query = StringQuery(keyword: "swift", sort: "recent")
        let items = query.queryItems

        let dict = Dictionary(items.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(dict["keyword"], "swift")
        XCTAssertEqual(dict["sort"], "recent")
    }

    func test_QueryParameter_Bool_프로퍼티_변환() {
        let query = BoolQuery(isActive: true)
        let items = query.queryItems

        let dict = Dictionary(items.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(dict["is_active"], "true")
    }

    func test_QueryParameter_snake_case_변환() {
        let query = SampleQuery(page: 1, perPage: 10)
        let items = query.queryItems
        let names = items.map { $0.name }

        XCTAssertTrue(names.contains("per_page"))
        XCTAssertFalse(names.contains("perPage"))
    }

    // MARK: - Optional

    func test_QueryParameter_Optional_nil이면_queryItems에서_제외() {
        let query = OptionalQuery(keyword: "swift", sort: nil)
        let items = query.queryItems

        let names = items.map { $0.name }
        XCTAssertTrue(names.contains("keyword"))
        XCTAssertFalse(names.contains("sort"))
    }

    func test_QueryParameter_Optional_값이_있으면_포함() {
        let query = OptionalQuery(keyword: "swift", sort: "recent")
        let items = query.queryItems

        let dict = Dictionary(items.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(dict["keyword"], "swift")
        XCTAssertEqual(dict["sort"], "recent")
    }

    // MARK: - 정렬

    func test_QueryParameter_queryItems가_이름순_정렬() {
        let query = SampleQuery(page: 1, perPage: 20)
        let names = query.queryItems.map { $0.name }

        XCTAssertEqual(names, names.sorted())
    }

    // MARK: - 중첩 구조 제외

    func test_QueryParameter_배열_프로퍼티는_queryItems에서_제외() {
        let query = ArrayQuery(keyword: "swift", tags: ["ios", "spm"])
        let names = query.queryItems.map { $0.name }

        XCTAssertTrue(names.contains("keyword"))
        XCTAssertFalse(names.contains("tags"))
    }

    func test_QueryParameter_딕셔너리_프로퍼티는_queryItems에서_제외() {
        let query = NestedQuery(keyword: "swift", filters: ["lang": "ko"])
        let names = query.queryItems.map { $0.name }

        XCTAssertTrue(names.contains("keyword"))
        XCTAssertFalse(names.contains("filters"))
    }

    // MARK: - EmptyQuery

    func test_EmptyQuery_빈_queryItems() {
        let query = EmptyQuery()

        XCTAssertTrue(query.queryItems.isEmpty)
    }
}

// MARK: - Test Helpers

private struct SampleQuery: QueryParameter {
    let page: Int
    let perPage: Int
}

private struct StringQuery: QueryParameter {
    let keyword: String
    let sort: String
}

private struct BoolQuery: QueryParameter {
    let isActive: Bool
}

private struct OptionalQuery: QueryParameter {
    let keyword: String
    let sort: String?
}

private struct ArrayQuery: QueryParameter {
    let keyword: String
    let tags: [String]
}

private struct NestedQuery: QueryParameter {
    let keyword: String
    let filters: [String: String]
}
