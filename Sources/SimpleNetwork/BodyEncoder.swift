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
    private let maxByteCount: Int?

    /// JSONBodyEncoder를 초기화합니다.
    /// - Parameters:
    ///   - keyEncodingStrategy: 키 변환 전략 (기본값: 변환 없음)
    ///   - dateEncodingStrategy: 날짜 인코딩 전략 (기본값: Date의 기본 인코딩)
    ///   - outputFormatting: 출력 포맷 옵션 (기본값: 없음)
    ///   - maxByteCount: 허용할 최대 바디 크기. 초과하면 `NetworkError.bodyTooLarge`를 던집니다 (기본값: 제한 없음)
    public init(
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
        outputFormatting: JSONEncoder.OutputFormatting = [],
        maxByteCount: Int? = nil
    ) {
        self.keyEncodingStrategy = keyEncodingStrategy
        self.dateEncodingStrategy = dateEncodingStrategy
        self.outputFormatting = outputFormatting
        self.maxByteCount = maxByteCount
    }

    /// 바디를 JSON Data로 인코딩합니다.
    ///
    /// 크기 검사는 인코딩을 마친 뒤에 수행되므로 서버 전송은 막지만
    /// 인코딩 과정에서 발생하는 메모리 사용 자체를 막지는 않습니다.
    public func encode(_ body: any Encodable & Sendable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.outputFormatting = outputFormatting

        let data = try encoder.encode(body)
        if let maxByteCount, data.count > maxByteCount {
            throw NetworkError.bodyTooLarge(byteCount: data.count, limit: maxByteCount)
        }

        return data
    }
}
