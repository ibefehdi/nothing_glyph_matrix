package dev.ibefehdi.nothing_glyph_matrix

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Flutter plugin entry point for [GlyphMatrixHost]. */
class NothingGlyphMatrixPlugin : FlutterPlugin {
    private var host: GlyphMatrixHost? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        host =
            GlyphMatrixHost(
                binding.applicationContext,
                binding.binaryMessenger,
            )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        host?.dispose()
        host = null
    }
}
