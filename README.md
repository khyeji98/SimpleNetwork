# SimpleNetwork

> [!IMPORTANT]
> 🚧 **Work In Progress**: This library is currently under active development. APIs are subject to change and features are being improved.


SimpleNetwork is a lightweight Swift networking library designed for modern iOS and macOS applications. It leverages Swift Concurrency (`async/await`) to provide a clean and easy-to-use interface for making HTTP requests.

## Features

- **Protocol-Oriented Design**: Define APIs easily using the `RequestAPI` protocol.
- **Swift Concurrency**: Fully supports `async/await` for asynchronous operations.
- **Type-Safe**: Request and response types are strongly defined.
- **Customizable**: Inject your own `URLSession` or `JSONDecoder` as needed.

## Installation

### Swift Package Manager

Add `SimpleNetwork` to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/khyeji98/SimpleNetwork.git", branch: "main")
]
```

## Usage

### 1. Define your API

Conform to the `RequestAPI` protocol to define your endpoints.

```swift
import SimpleNetwork
import Foundation

struct User: Decodable {
    let id: Int
    let name: String
}

struct GetUserAPI: RequestAPI {
    typealias QueryParams = EmptyParams // Or a struct conforming to Encodable
    typealias Response = User

    var baseURL: String { "https://api.example.com" }
    var path: String { "/users/1" }
    var httpMethod: HTTPMethod { .get }
    var queryParams: QueryParams? { nil }
}

// Helper for when no query params are needed
struct EmptyParams: Encodable {}
```

### 2. Make a Request

Use `URLSessionService` to execute the request.

```swift
let networkService = URLSessionService()

Task {
    do {
        let user = try await networkService.request(GetUserAPI())
        print("User: \(user.name)")
    } catch {
        print("Error: \(error)")
    }
}
```

## Requirements

- iOS 15.0+
- macOS 12.0+
