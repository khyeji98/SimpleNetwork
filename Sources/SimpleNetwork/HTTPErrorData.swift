//
//  HTTPErrorData.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// HTTP 오류 응답에서 함께 전달되는 본문과 헤더입니다.
public struct HTTPErrorData: Equatable, Sendable {
    /// 응답 본문입니다. 비어 있거나 제공되지 않은 경우 `nil`입니다.
    public let body: Data?

    /// 응답 헤더입니다. 비어 있거나 제공되지 않은 경우 `nil`입니다.
    public let headers: [String: String]?

    public init(body: Data?, headers: [String: String]?) {
        self.body = body?.isEmpty == false ? body : nil
        self.headers = headers?.isEmpty == false ? headers : nil
    }
}

extension HTTPErrorData {
    init(body: Data?, response: HTTPURLResponse) {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, field in
            result[String(describing: field.key)] = String(describing: field.value)
        }

        self.init(body: body, headers: headers)
    }
}
