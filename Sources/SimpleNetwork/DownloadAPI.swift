//
//  DownloadAPI.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 파일 다운로드 요청을 정의하는 프로토콜입니다.
///
/// `RequestAPI`와 달리 응답 바디를 디코딩하지 않고 `destination`에 직접 저장합니다.
/// 상위 디렉터리 생성은 호출자의 책임이며, 기존 파일이 있으면 덮어씁니다.
public protocol DownloadAPI: Sendable {
    associatedtype Query: QueryParameter

    /// HTTP 요청 메서드. 기본값은 `.get`.
    var httpMethod: HTTPMethod { get }

    /// API 엔드포인트 경로 (예: `/files/fw.bin`).
    var path: String { get }

    /// 쿼리 파라미터. 기본값은 `nil`.
    var query: Query? { get }

    /// 기본 URL (scheme + host).
    var baseURL: String { get }

    /// HTTP 헤더. 기본값은 `nil`.
    var headers: HTTPHeaders? { get }

    /// 다운로드한 바이트를 기록할 파일 URL.
    /// 상위 디렉터리는 호출자가 사전에 생성해야 합니다.
    var destination: URL { get }
}

public extension DownloadAPI {
    /// 완전한 요청 URL을 생성합니다. `RequestAPI`와 동일한 규칙을 따릅니다.
    var url: URL? {
        guard var urlComponents = URLComponents(string: baseURL) else { return nil }
        urlComponents.path = path

        if let query {
            let items = query.queryItems
            urlComponents.queryItems = items.isEmpty ? nil : items
        }

        if let encodedQuery = urlComponents.percentEncodedQuery {
            urlComponents.percentEncodedQuery = encodedQuery.replacingOccurrences(of: ",", with: "%2C")
        }

        return urlComponents.url
    }

    var httpMethod: HTTPMethod { .get }
    var query: Query? { nil }
    var headers: HTTPHeaders? { nil }
}
