//
//  DownloadEvent.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 다운로드 스트림이 방출하는 이벤트입니다.
///
/// `.progress`는 버퍼 flush 직후 반복 방출되고,
/// `.completed(URL)`은 스트림 종료 직전에 정확히 한 번 방출됩니다.
public enum DownloadEvent: Sendable {
    case progress(TransferProgress)
    case completed(URL)
}
