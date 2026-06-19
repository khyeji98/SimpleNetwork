//
//  NetworkLogger.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation
import OSLog

/// SimpleNetwork 내부 로깅에 사용하는 커스텀 로거입니다.
///
/// Apple의 `os.Logger`를 래핑하여 `debug`/`info`/`error` 레벨을 제공합니다.
/// 통합 로그(Unified Logging)에 기록되므로 Console.app 및 Xcode 콘솔에서 확인할 수 있습니다.
public struct NetworkLogger: Sendable {

    /// 로그 레벨을 정의합니다.
    public enum Level: String, Sendable {
        case debug
        case info
        case error

        fileprivate var symbol: String {
            switch self {
            case .debug: return "🟡"
            case .info: return "🟢"
            case .error: return "🔴"
            }
        }
    }

    private let logger: Logger
    private let isEnabled: Bool

    /// NetworkLogger를 초기화합니다.
    /// - Parameters:
    ///   - subsystem: 로그를 그룹화할 서브시스템 식별자 (기본값: 번들 식별자)
    ///   - category: 로그 카테고리 (기본값: "Network")
    ///   - isEnabled: 로깅 활성화 여부 (기본값: true)
    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "SimpleNetwork",
        category: String = "Network",
        isEnabled: Bool = true
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.isEnabled = isEnabled
    }

    /// 디버그 레벨 로그를 기록합니다.
    public func debug(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }

        output(.debug, message())
    }

    /// 정보 레벨 로그를 기록합니다.
    public func info(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }

        output(.info, message())
    }

    /// 에러 레벨 로그를 기록합니다.
    public func error(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }

        output(.error, message())
    }

    private func output(_ level: Level, _ message: String) {
        let text = "\(level.symbol) \(message)"

        switch level {
        case .debug: logger.debug("\(text, privacy: .public)")
        case .info: logger.info("\(text, privacy: .public)")
        case .error: logger.error("\(text, privacy: .public)")
        }
    }
}
