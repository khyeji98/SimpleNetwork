//
//  HTTPHeader.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// HTTP 헤더를 타입 안전하게 정의합니다.
public struct HTTPHeader: Equatable, Hashable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - Well-Known Headers

public extension HTTPHeader {
    static func authorization(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: value)
    }

    static func authorization(bearer token: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: "Bearer \(token)")
    }

    static func contentType(_ value: ContentType) -> HTTPHeader {
        HTTPHeader(name: "Content-Type", value: value.rawValue)
    }

    static func accept(_ value: ContentType) -> HTTPHeader {
        HTTPHeader(name: "Accept", value: value.rawValue)
    }

    static func userAgent(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "User-Agent", value: value)
    }

    static func acceptLanguage(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Accept-Language", value: value)
    }

    static func custom(name: String, value: String) -> HTTPHeader {
        HTTPHeader(name: name, value: value)
    }
}

// MARK: - ContentType

public extension HTTPHeader {
    enum ContentType: String, Sendable {
        case json = "application/json"
        case formURLEncoded = "application/x-www-form-urlencoded"
        case multipartFormData = "multipart/form-data"
        case xml = "application/xml"
        case plainText = "text/plain"
    }
}

// MARK: - HTTPHeaders

/// HTTP 헤더 컬렉션입니다. 같은 이름의 헤더는 마지막 값으로 덮어씁니다.
public struct HTTPHeaders: Equatable, Sendable {
    private var headers: [HTTPHeader]

    public init(_ headers: [HTTPHeader] = []) {
        self.headers = []
        headers.forEach { add($0) }
    }

    public mutating func add(_ header: HTTPHeader) {
        if let index = headers.firstIndex(where: { $0.name.lowercased() == header.name.lowercased() }) {
            headers[index] = header
        } else {
            headers.append(header)
        }
    }

    /// URLRequest에 적용할 때 사용하는 딕셔너리로 변환합니다.
    public var dictionary: [String: String] {
        Dictionary(headers.map { ($0.name, $0.value) }, uniquingKeysWith: { _, last in last })
    }
}

// MARK: - ExpressibleByArrayLiteral

extension HTTPHeaders: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: HTTPHeader...) {
        self.init(elements)
    }
}
