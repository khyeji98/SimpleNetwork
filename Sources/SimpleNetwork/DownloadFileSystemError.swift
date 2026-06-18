//
//  DownloadFileSystemError.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 다운로드 파일 저장 과정에서 발생하는 내부 파일시스템 에러입니다.
/// `NetworkError.unknown(_)`의 associated value로 래핑됩니다.
enum DownloadFileSystemError: Error, Sendable {
    case cannotCreateFile(path: String)
}

extension DownloadFileSystemError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cannotCreateFile(let path):
            return "파일을 생성할 수 없습니다. 상위 디렉터리가 존재하는지 확인하세요: \(path)"
        }
    }
}
