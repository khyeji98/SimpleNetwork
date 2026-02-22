# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-22

### Added
- Created `URLSessionService` to perform asynchronous network requests using Swift Concurrency (`async/await`).
- Added `RequestAPI` protocol to encapsulate API endpoint details (e.g., path, method, headers, and body).
- Implemented `HTTPMethod` enum to define standard HTTP request methods (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`).
- Introduced `NetworkError` to provide clear, identifiable error types (including HTTP status codes and decoding errors).
- Supported custom `JSONDecoder` and `JSONEncoder`, defaulting to `snake_case` conversion.
