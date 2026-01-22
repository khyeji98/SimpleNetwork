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
    associatedtype QueryParams: Encodable
    associatedtype Response: Decodable

    /// HTTP 요청 메서드
    var httpMethod: HTTPMethod { get }
    
    /// API 엔드포인트 경로 (예: "/v1/users")
    var path: String { get }
    
    /// 쿼리 파라미터
    var queryParams: QueryParams? { get }
    
    /// 기본 URL (scheme + host)
    var baseURL: String { get }
}

public extension RequestAPI {
    /// 쿼리 파라미터를 URLQueryItem 배열로 변환합니다.
    var queryItems: [URLQueryItem]? {
        guard let queryParams = queryParams else { return nil }
        guard let dict = try? queryParams.toDictionary() else { return nil }
        return dict.map { key, value in
            URLQueryItem(name: key, value: String(describing: value))
        }
    }

    /// 완전한 요청 URL을 생성합니다.
    var url: URL? {
        guard var urlComponents = URLComponents(string: baseURL) else { return nil }
        urlComponents.path = path
        urlComponents.queryItems = queryItems

        if let query = urlComponents.percentEncodedQuery {
            urlComponents.percentEncodedQuery = query.replacingOccurrences(of: ",", with: "%2C")
        }

        return urlComponents.url
    }
}

// MARK: - Private Helpers

private extension Encodable {
    func toDictionary() throws -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        return dictionary
    }
}
