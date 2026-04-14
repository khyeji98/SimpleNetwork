//
//  RequestAPI.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 네트워크 요청을 정의하는 프로토콜입니다.
/// 각 API 요청은 이 프로토콜을 채택하여 구현합니다.
public protocol RequestAPI {
    associatedtype Query: QueryParameter
    associatedtype Response: Decodable

    /// HTTP 요청 메서드
    var httpMethod: HTTPMethod { get }

    /// API 엔드포인트 경로 (예: "/v1/users")
    var path: String { get }

    /// 쿼리 파라미터
    var query: Query? { get }

    /// 기본 URL (scheme + host)
    var baseURL: String { get }

    /// HTTP 헤더 (Authorization, Content-Type 등)
    var headers: HTTPHeaders? { get }

    /// HTTP 요청 바디 (POST, PUT 등에서 사용)
    var body: Encodable? { get }
}

public extension RequestAPI {
    /// 완전한 요청 URL을 생성합니다.
    var url: URL? {
        guard var urlComponents = URLComponents(string: baseURL) else { return nil }
        urlComponents.path = path

        if let query = query {
            let items = query.queryItems
            urlComponents.queryItems = items.isEmpty ? nil : items
        }

        if let query = urlComponents.percentEncodedQuery {
            urlComponents.percentEncodedQuery = query.replacingOccurrences(of: ",", with: "%2C")
        }

        return urlComponents.url
    }

    var query: Query? { nil }
    var headers: HTTPHeaders? { nil }
    var body: Encodable? { nil }
}
