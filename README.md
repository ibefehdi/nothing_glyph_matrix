# nothing_glyph_matrix

Flutter plugin for the **Nothing Phone Glyph Matrix** (Phone (3), Phone (4a) Pro).

Drive the rear LED matrix from Flutter with:

- `showImage` — PNG bytes scaled to the matrix
- `showText` — short countdown / labels
- `showProgress` — 0–1 ring
- `GlyphMatrixDisplay` — priority helper (peek → rest → progress → idle image)

> **Not affiliated with Nothing.** The Glyph Matrix SDK is © Nothing Technology Limited.
> This package ships only the Flutter/Kotlin wrapper. You must obtain Nothing's AAR yourself.

## Requirements

- Android `minSdk` **33+**
- Physical Nothing device with Glyph Matrix (e.g. Phone (3))
- Nothing OS build that supports `setAppMatrixFrame` (typically ≥ `20250801`)
- `glyph-matrix-sdk-2.0.aar` from the [Glyph Matrix Developer Kit](https://github.com/Nothing-Developer-Programme/GlyphMatrix-Developer-Kit)

## Install the SDK JAR (required)

Nothing's EULA does **not** allow redistributing the SDK. Android also forbids
embedding a local `.aar` inside a Flutter plugin module.

1. Download `glyph-matrix-sdk-2.0.aar` from the [Glyph Matrix Developer Kit](https://github.com/Nothing-Developer-Programme/GlyphMatrix-Developer-Kit).
2. Extract its `classes.jar` into the plugin as:

   ```text
   nothing_glyph_matrix/android/libs/glyph-matrix-sdk.jar
   ```

See [android/libs/README.md](android/libs/README.md) for a one-liner extract command.

Your **app does not** add this JAR/AAR in `build.gradle` — only the plugin does.

Commercial use of Nothing's SDK may require permission: `GDKsupport@nothing.tech`.

## Add the package

```yaml
dependencies:
  nothing_glyph_matrix: ^0.1.0
```

Or for local development:

```yaml
dependencies:
  nothing_glyph_matrix:
    path: ../nothing_glyph_matrix
```

The plugin merges the `com.nothing.ketchum.permission.ENABLE` permission.

## Quick start

```dart
import 'package:flutter/services.dart';
import 'package:nothing_glyph_matrix/nothing_glyph_matrix.dart';

final display = GlyphMatrixDisplay();

Future<void> initGlyph() async {
  display.attach();
  await display.initialize();
  if (!display.supported) return;

  display.enabled = true;
  final logo = await rootBundle.load('assets/logo.png');
  await display.setIdleImage(logo.buffer.asUint8List());
}

// Rest countdown
await display.showSeconds(60);

// Progress ring (0–1)
await display.setProgress(0.4);

// Clear rest → back to progress / idle
await display.clearRest();
```

### Low-level API

```dart
final matrix = GlyphMatrix();
if (await matrix.isSupported()) {
  await matrix.showText('Hi');
  await matrix.showProgress(0.5);
  await matrix.clear();
}
```

## Debug tip (device)

```bash
adb shell settings put global nt_glyph_interface_debug_enable 1
```

(Auto-disables after ~48 hours.)

## Display priority

`GlyphMatrixDisplay` renders the highest-priority active layer:

1. Celebration text (`celebrate`)
2. Peek text (`showPeek`)
3. Rest seconds (`showSeconds`)
4. Progress ring (`setProgress`)
5. Idle image (`setIdleImage`)
6. Clear (after celebration until `clearSession`)

## License

- **This package (wrapper):** MIT — see [LICENSE](LICENSE)
- **Nothing Glyph Matrix SDK:** Nothing's EULA — see [NOTICE](NOTICE)
