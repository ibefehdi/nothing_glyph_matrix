# Glyph Matrix SDK (required — not shipped)

This plugin **does not redistribute** Nothing's proprietary SDK.

Android Gradle Plugin also **cannot** depend on a local `.aar` from inside a
Flutter plugin library module. Use the `classes.jar` from the official AAR instead.

## Setup

1. Download `glyph-matrix-sdk-2.0.aar` from:  
   https://github.com/Nothing-Developer-Programme/GlyphMatrix-Developer-Kit

2. Extract `classes.jar` from that AAR and save it here as:

   ```text
   nothing_glyph_matrix/android/libs/glyph-matrix-sdk.jar
   ```

   PowerShell example:

   ```powershell
   Expand-Archive glyph-matrix-sdk-2.0.aar -DestinationPath _tmp
   Copy-Item _tmp\classes.jar .\glyph-matrix-sdk.jar
   Remove-Item -Recurse _tmp
   ```

   (`Expand-Archive` needs a `.zip` extension — rename/copy the `.aar` to `.zip` first if needed.)

3. Accept Nothing's Glyph SDK EULA in that repository.

Do **not** add the AAR/JAR to your app's `build.gradle` — the plugin packages the JAR.

`*.aar` / `*.jar` here are gitignored and must not be published to pub.dev.
