//
//  QueryParameter.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 쿼리 파라미터를 정의하는 프로토콜입니다.
/// 구조체의 프로퍼티만 정의하면 라이브러리가 자동으로 URLQueryItem으로 변환합니다.
public protocol QueryParameter: Encodable, Sendable {}

public extension QueryParameter {
    /// 프로퍼티를 URLQueryItem 배열로 자동 변환합니다.
    /// 플랫한 key-value 구조만 지원합니다. 중첩 객체나 배열은 지원하지 않습니다.
    var queryItems: [URLQueryItem] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        return dict.compactMap { key, value in
            if value is NSNull {
                return nil
            }
            // 플랫 구조만 지원: 중첩 객체/배열은 제외하여 의도치 않은 문자열 직렬화 방지
            if value is [Any] || value is [String: Any] {
                return nil
            }
            let nsValue = value as AnyObject
            if nsValue === kCFBooleanTrue {
                return URLQueryItem(name: key, value: "true")
            } else if nsValue === kCFBooleanFalse {
                return URLQueryItem(name: key, value: "false")
            }
            return URLQueryItem(name: key, value: String(describing: value))
        }
        .sorted { $0.name < $1.name }
    }
}

/// 쿼리 파라미터가 없는 요청에 사용합니다.
public struct EmptyQuery: QueryParameter {}
