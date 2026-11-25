# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-25

### Added

- Synchronous `DdsReader(Uint8List bytes)` API with lazy surface offset indexing and zero-copy `readRaw(...)` views.
- Unified `R8G8B8A8` CPU decoding via `readRgba8(...)` for both BCn-compressed and uncompressed formats.
- Header parsing for `DDS_HEADER`, `DDS_PIXELFORMAT`, and `DDS_HEADER_DXT10`, including legacy FourCCs (`DXT1`, `DXT5`, `ATI1`/`BC4U`, `ATI2`/`BC5U`) and legacy uncompressed bitmasks (`R8G8B8A8`, `B8G8R8A8`, `B8G8R8`, `R8`, `A8`).
- Support for 2D textures with mipmaps, 6-face cubemaps, texture arrays, and 3D volume textures (`DdsResourceType`).
- `DdsTextureFormat` enum with `DXGI_FORMAT` lookup and `mipByteSize(width, height)` calculation.
- Modularized `BcnDecoder` supporting `BC1`, `BC3`, `BC4`, `BC5`, `BC6H_UF16`, and `BC7` (including sRGB variants).
- Typed `DdsFormatException` (implementing `FormatException`) for malformed, truncated, or unsupported DDS buffers.
- Runnable usage example in `example/example.dart` and unit tests in `test/dds_format_test.dart` (including official Dart logo `.dds`/`.png` verification).

[unreleased]: https://github.com/poirierlouis/dds_format/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/poirierlouis/dds_format/releases/tag/v0.1.0
