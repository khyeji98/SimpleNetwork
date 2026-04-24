# SimpleNetwork

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS_15.0+_|_macOS_12.0+-lightgray.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

> [!IMPORTANT]
> 🚧 **Work In Progress**: This library is currently under active development. APIs are subject to change and features are being improved.

**SimpleNetwork** is a lightweight, protocol-oriented Swift networking library designed for modern iOS and macOS applications. It leverages Swift Concurrency (`async/await`) to provide a clean, readable, and highly reusable interface for making HTTP requests without the boilerplate of raw `URLSession`.

## Features

- 🏗 **Protocol-Oriented Design**: Define API requests seamlessly using the `RequestAPI` protocol.
- ⚡️ **Swift Concurrency**: Fully optimized for `async/await` to handle asynchronous operations cleanly.
- 🛡 **Type-Safe**: Request body parameters and response models are strictly typed via `Encodable` and `Decodable`.
- ⚙️ **Customizable**: Allows easy injection of custom `URLSession` and `JSONDecoder`/`JSONEncoder` (Defaults to `convertFromSnakeCase` & `convertToSnakeCase`).
- 🚨 **Detailed Error Handling**: Clear tracking of networking failures using `NetworkError`.

## Installation

### Swift Package Manager

Add `SimpleNetwork` as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/khyeji98/SimpleNetwork.git", .upToNextMajor(from: "1.0.0"))
]
```

Or add it directly via Xcode:
1. Go to **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/khyeji98/SimpleNetwork.git`
3. Choose the version rule (e.g., Up to Next Major Version `1.0.0`)

## Usage

### 1. Define your API Models

Create your data models that correspond to the JSON response and request body.

```swift
import Foundation

struct User: Codable {
    let id: Int
    let name: String
    let profileImageUrl: String?
}

// If no query parameters are needed
struct EmptyParams: Encodable {} 
```

### 2. Conform to `RequestAPI`

Define your API endpoints by adopting the `RequestAPI` protocol.

```swift
import SimpleNetwork
import Foundation

// MARK: - GET Request Example
struct GetUserAPI: RequestAPI {
    typealias QueryParams = EmptyParams 
    typealias Response = User

    var baseURL: String { "https://api.example.com" }
    var path: String { "/users/1" }
    var httpMethod: HTTPMethod { .get }
    var queryParams: QueryParams? { nil }
}

// MARK: - POST Request Example
struct CreateUserAPI: RequestAPI {
    typealias QueryParams = EmptyParams
    typealias Response = User
    
    let newUser: User
    
    var baseURL: String { "https://api.example.com" }
    var path: String { "/users" }
    var httpMethod: HTTPMethod { .post }
    var queryParams: QueryParams? { nil }
    
    var headers: [String : String]? {
        ["Authorization": "Bearer YOUR_ACCESS_TOKEN"]
    }
    
    var body: Encodable? { newUser }
}
```

### 3. Execute the Request

Perform the network call using `URLSessionService`.

```swift
let networkService = URLSessionService()

Task {
    do {
        // Fetch User (GET)
        let user: User = try await networkService.request(GetUserAPI())
        print("Fetched User: \(user.name)")
        
        // Create User (POST)
        let newUser = User(id: 2, name: "Alice", profileImageUrl: nil)
        let createdUser: User = try await networkService.request(CreateUserAPI(newUser: newUser))
        print("Successfully created User: \(createdUser.name)")
        
    } catch let error as NetworkError {
        print("Network Error Handle: \(error.localizedDescription)")
    } catch {
        print("Unexpected Error: \(error)")
    }
}
```

### 4. Download a File

Conform to `DownloadAPI` and consume the stream returned by `download(_:)`.

```swift
struct DownloadFirmwareAPI: DownloadAPI {
    typealias Query = EmptyQuery

    var baseURL: String { "https://cdn.example.com" }
    var path: String { "/firmware/v1.bin" }
    let destination: URL
}

let networkService = URLSessionService()
let destination = FileManager.default.temporaryDirectory
    .appendingPathComponent("firmware.bin")

Task {
    do {
        let api = DownloadFirmwareAPI(destination: destination)
        for try await event in networkService.download(api) {
            switch event {
            case .progress(let progress):
                if let fraction = progress.fractionCompleted {
                    print("\(Int(fraction * 100))% — \(progress.bytesTransferred) bytes")
                } else {
                    print("downloaded \(progress.bytesTransferred) bytes")
                }

            case .completed(let url):
                print("saved to \(url)")
            }
        }
    } catch {
        print("Download failed: \(error)")
    }
}
```

- `destination`의 상위 디렉터리는 호출자가 먼저 생성해야 합니다. 기존 파일이 있으면 덮어씁니다.
- `Task`가 취소되면 `onTermination`이 부분 파일을 정리합니다. `for try await` 소비자는 필요 시 `try Task.checkCancellation()`으로 취소를 전파하세요.

## Requirements

- iOS 15.0+
- macOS 12.0+
- Swift 5.9+

## License

SimpleNetwork is released under the MIT license. See [LICENSE](LICENSE) for details. (If applicable)

