package com.example.pdfconvertorapp

import android.media.MediaScannerConnection
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"pdf_studio/media_scan"
		).setMethodCallHandler { call, result ->
			if (call.method == "scanFile") {
				val path = call.argument<String>("path")
				if (path.isNullOrBlank()) {
					result.error("ARGUMENT_ERROR", "Missing file path", null)
					return@setMethodCallHandler
				}

				MediaScannerConnection.scanFile(
					applicationContext,
					arrayOf(path),
					null,
					null
				)
				result.success(true)
			} else {
				result.notImplemented()
			}
		}
	}
}
