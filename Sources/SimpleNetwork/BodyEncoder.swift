//
//  BodyEncoder.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 요청 바디를 Data로 인코딩하는 프로토콜입니다.
///
/// 인코딩 전략과 인코딩 로직을 모두 채택 타입이 소유합니다.
/// 크기 제한, 압축, 검증 등 커스텀 정책이 필요하면 이 프로토콜을 직접 구현하세요.
public protocol BodyEncoder: Sendable {
    func encode(_ body: any Encodable & Sendable) throws -> Data
}

/// 라이브러리 기본 JSON 바디 인코더입니다.
///
/// 전략을 값으로 보관하고 `JSONEncoder`는 `encode(_:)` 안에서 생성하므로
/// 인스턴스를 여러 요청이 동시에 사용해도 안전합니다.
public struct JSONBodyEncoder: BodyEncoder {
    private let keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
    private let dateEncodingStrategy: JSONEncoder.DateEncodingStrategy
    private let outputFormatting: JSONEncoder.OutputFormatting

    /// JSONBodyEncoder를 초기화합니다.
    /// - Parameters:
    ///   - keyEncodingStrategy: 키 변환 전략 (기본값: 변환 없음)
    ///   - dateEncodingStrategy: 날짜 인코딩 전략 (기본값: Date의 기본 인코딩)
    ///   - outputFormatting: 출력 포맷 옵션 (기본값: 없음)
    public init(
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
        outputFormatting: JSONEncoder.OutputFormatting = []
    ) {
        self.keyEncodingStrategy = keyEncodingStrategy
        self.dateEncodingStrategy = dateEncodingStrategy
        self.outputFormatting = outputFormatting
    }

    /// 바디를 JSON Data로 인코딩합니다.
    public func encode(_ body: any Encodable & Sendable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.outputFormatting = outputFormatting

        return try encoder.encode(body)
    }
}
