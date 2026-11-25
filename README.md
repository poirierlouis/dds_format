# dds_format

A Dart library for reading DirectDraw Surface (`.dds`) files from an in-memory
`Uint8List` buffer.

`dds_format` parses standard `DDS_HEADER`, `DDS_PIXELFORMAT`, and extended 
`DDS_HEADER_DXT10` headers, builds a lazy surface index without copying pixel
data, and lets you extract either zero-copy raw surface bytes (for GPU upload)
or decoded 8-bit `R8G8B8A8` bytes (for CPU image processing).

## Features

- **Synchronous `DdsReader` API** backed by an in-memory `Uint8List` buffer.
- **Zero-copy raw surface access** via `readRaw(...)` (`Uint8List.sublistView`).
- **Unified `R8G8B8A8` decoding** via `readRgba8(...)` for both BCn-compressed 
  and uncompressed formats.
- **Broad header compatibility**:
  - `DX10` extended headers (`DDS_HEADER_DXT10`).
  - Legacy FourCC codes: `DXT1` (`bc1Unorm`), `DXT5` (`bc3Unorm`),
    `ATI1`/`BC4U` (`bc4Unorm`), `ATI2`/`BC5U` (`bc5Unorm`).
  - Legacy uncompressed bitmasks: 32-bit `R8G8B8A8`, 32-bit `B8G8R8A8`, 24-bit
    `B8G8R8`, 8-bit `R8` (luminance), and 8-bit `A8` (alpha).
- **All DDS resource types**:
  - 2D textures with full mipmap chains.
  - 6-face cubemaps (and cubemap arrays with `DX10`).
  - 2D texture arrays (`arraySize > 1`).
  - 3D volume textures (`depth > 1`).
- **Supported `DdsTextureFormat` values**:
  - Uncompressed: `r8g8b8a8Unorm`, `r8g8b8a8UnormSrgb`, `b8g8r8a8Unorm`,
    `b8g8r8Unorm`, `r8Unorm`, `a8Unorm`.
  - Block-compressed (BCn): `bc1Unorm`, `bc1UnormSrgb`, `bc3Unorm`,
    `bc3UnormSrgb`, `bc4Unorm`, `bc5Unorm`, `bc6hUf16`, `bc7Unorm`, `bc7UnormSrgb`.
- **Structured error reporting**: Throws `DdsFormatException` (implementing
  `FormatException`) for malformed, truncated, or unsupported DDS data, and
  `RangeError` for out-of-bounds surface indices.

## Requirements

- **Dart SDK**: `^3.13.7`
- **Dependencies**: None (uses only `dart:typed_data` and `dart:ffi`).

## Getting started

Add `dds_format` to your `pubspec.yaml`:

```sh
dart pub add dds_format
```

Or add it manually:

```yaml
dependencies:
  dds_format: ^0.1.0
```

## Usage

### Reading metadata and mip 0

```dart
import 'dart:typed_data';
import 'package:dds_format/dds_format.dart';

void readDds(Uint8List bytes) {
  final reader = DdsReader(bytes);

  print('Resource: ${reader.resourceType}');
  print('Format: ${reader.format}');
  print('Dimensions: ${reader.width}x${reader.height}x${reader.depth}');
  print('Mips: ${reader.mipCount}, Array: ${reader.arraySize}, Faces: ${reader.faceCount}');

  // Zero-copy view of mip 0 bytes (e.g. for GPU upload)
  final Uint8List rawBytes = reader.readRaw();

  // Decoded R8G8B8A8 bytes of length width * height * 4 (for CPU usage)
  final Uint8List rgbaBytes = reader.readRgba8();
}
```

### Indexing mipmaps, cubemaps, arrays, and 3D volumes

`readRaw` and `readRgba8` accept optional `arrayIndex`, `face`, `mipLevel`, and
`depthSlice` parameters (all defaulting to `0`). You can query per-mip
dimensions with `mipWidth(mipLevel)`, `mipHeight(mipLevel)`, and
`mipDepth(mipLevel)`:

```dart
final reader = DdsReader(bytes);

for (int a = 0; a < reader.arraySize; a++) {
  for (int f = 0; f < reader.faceCount; f++) {
    for (int m = 0; m < reader.mipCount; m++) {
      final w = reader.mipWidth(m);
      final h = reader.mipHeight(m);
      final d = reader.mipDepth(m);

      for (int z = 0; z < d; z++) {
        final rgba = reader.readRgba8(
          arrayIndex: a,
          face: f,
          mipLevel: m,
          depthSlice: z,
        );
        // Process w x h R8G8B8A8 slice...
      }
    }
  }
}
```

### Error handling

```dart
try {
  final reader = DdsReader(bytes);
  final rgba = reader.readRgba8(mipLevel: 0);
} on DdsFormatException catch (e) {
  // Invalid magic number, unsupported format/FourCC, or truncated buffer
  print('Invalid DDS: $e');
} on RangeError catch (e) {
  // Out-of-bounds arrayIndex, face, mipLevel, or depthSlice
  print('Invalid surface index: $e');
}
```

See `example/example.dart` for a complete runnable example.

## License & Attributions

- **Library**: Licensed under the [GNU General Public License v3.0](LICENSE).
- **Dart Logo Assets**: The sample Dart logo files in `example/`
  (`icon_dart@2x.*`, `lockup_dart_horizontal@2x.*`,
  `lockup_dart_vertical@2x.*`) are official Dart brand assets provided for
  example and testing purposes. Dart and the Dart logo are trademarks of Google
  LLC; see the [Dart Brand Guidelines](https://dart.dev/brand) for usage terms.

## Additional information

- **Source & Issues**: [https://github.com/poirierlouis/dds_format](https://github.com/poirierlouis/dds_format)
