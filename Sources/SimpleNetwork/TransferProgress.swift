//
//  TransferProgress.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 전송(다운로드/업로드) 진행률 스냅샷입니다.
public struct TransferProgress: Sendable, Equatable, Hashable {
    /// 지금까지 누적된 바이트 수.
    public let bytesTransferred: Int64

    /// 예상 총 바이트 수. `Content-Length`가 없거나 `-1`이면 `nil`.
    public let totalBytes: Int64?

    /// 완료 비율. `totalBytes`가 존재하고 `> 0`일 때만 계산되며,
    /// 초과 수신 시 `1.0`으로 클램프됩니다.
    public var fractionCompleted: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }

        let ratio = Double(bytesTransferred) / Double(totalBytes)
        return min(1.0, ratio)
    }

    public init(bytesTransferred: Int64, totalBytes: Int64?) {
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
    }
}
