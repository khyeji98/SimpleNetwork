//
//  ResponseDecoder.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 응답 Data를 모델로 디코딩하는 프로토콜입니다.
///
/// 디코딩 전략과 디코딩 로직을 모두 채택 타입이 소유합니다.
/// 래핑된 응답 벗기기, 빈 바디 허용 등 커스텀 정책이 필요하면 이 프로토콜을 직접 구현하세요.
public protocol ResponseDecoder: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

/// 라이브러리 기본 JSON 응답 디코더입니다.
///
/// 전략을 값으로 보관하고 `JSONDecoder`는 `decode(_:from:)` 안에서 생성하므로
/// 인스턴스를 여러 요청이 동시에 사용해도 안전합니다.
public struct JSONResponseDecoder: ResponseDecoder {
    private let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy
    private let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy

    /// JSONResponseDecoder를 초기화합니다.
    /// - Parameters:
    ///   - keyDecodingStrategy: 키 변환 전략 (기본값: 변환 없음)
    ///   - dateDecodingStrategy: 날짜 디코딩 전략 (기본값: Date의 기본 디코딩)
    public init(
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
    ) {
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = keyDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy

        return try decoder.decode(type, from: data)
    }
}
