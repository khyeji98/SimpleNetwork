# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0](https://github.com/khyeji98/SimpleNetwork/compare/v1.1.0...v1.2.0) (2026-06-19)


### Features

* NetworkLogger 도입 및 통신 로깅 추가 ([1fdd998](https://github.com/khyeji98/SimpleNetwork/commit/1fdd998aaa63a70cd10e4175ced955b4c5459e05))
* 다운로드 기능 및 통신 로깅 추가 (1.2.0) ([b613202](https://github.com/khyeji98/SimpleNetwork/commit/b6132026c5eef065ece3a8d2660c2595101f499a))

## [1.1.0](https://github.com/khyeji98/SimpleNetwork/compare/1.0.0...v1.1.0) (2026-04-20)


### Features

* add QueryParameter protocol with automatic conversion ([6b7a63a](https://github.com/khyeji98/SimpleNetwork/commit/6b7a63ab8c5c94f556eaf5c65c26fb8b326b0387))
* add type-safe HTTPHeader and HTTPHeaders ([bd7898d](https://github.com/khyeji98/SimpleNetwork/commit/bd7898d4cbd3475165ef4b90b9d4c7939ade3409))
* apply HTTPHeaders and QueryParameter to RequestAPI ([ae2b779](https://github.com/khyeji98/SimpleNetwork/commit/ae2b779cf95457785ceb8d00cbc210d6cf39709b))
* RequestAPI 타입 안전성 강화 (HTTPHeaders, QueryParameter) ([61cac75](https://github.com/khyeji98/SimpleNetwork/commit/61cac758a562a4c6a8f794b442f879d531ebe431))


### Bug Fixes

* 중첩 객체/배열을 QueryParameter에서 제외 ([4e51369](https://github.com/khyeji98/SimpleNetwork/commit/4e5136915368bb64ec0b4c12067b2238379c9400))

## [Unreleased]

## [1.0.0] - 2026-02-22

### Added
- Created `URLSessionService` to perform asynchronous network requests using Swift Concurrency (`async/await`).
- Added `RequestAPI` protocol to encapsulate API endpoint details (e.g., path, method, headers, and body).
- Implemented `HTTPMethod` enum to define standard HTTP request methods (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`).
- Introduced `NetworkError` to provide clear, identifiable error types (including HTTP status codes and decoding errors).
- Supported custom `JSONDecoder` and `JSONEncoder`, defaulting to `snake_case` conversion.
