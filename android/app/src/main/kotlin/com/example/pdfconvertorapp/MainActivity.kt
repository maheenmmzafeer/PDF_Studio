package com.example.pdfconvertorapp

import android.app.Activity
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private companion object {
		const val REQUEST_CREATE_PDF = 1001
	}

	private var pendingPdfBytes: ByteArray? = null
	private var pendingPdfResult: MethodChannel.Result? = null
	private lateinit var pdfSaveChannel: MethodChannel
	private var pendingPdfFileName: String? = null

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

		pdfSaveChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"pdf_studio/pdf_save"
		)
		pdfSaveChannel.setMethodCallHandler { call, result ->
			if (call.method == "savePdf") {
				if (pendingPdfResult != null) {
					result.error("BUSY", "A PDF save is already in progress", null)
					return@setMethodCallHandler
				}

				val fileName = call.argument<String>("fileName") ?: "document.pdf"
				val bytes = call.argument<ByteArray>("bytes")
				if (bytes == null) {
					result.error("ARGUMENT_ERROR", "Missing PDF bytes", null)
					return@setMethodCallHandler
				}

				pendingPdfBytes = bytes
				pendingPdfResult = result
				pendingPdfFileName = fileName
				val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
					addCategory(Intent.CATEGORY_OPENABLE)
					type = "application/pdf"
					putExtra(Intent.EXTRA_TITLE, fileName)
				}
				startActivityForResult(intent, REQUEST_CREATE_PDF)
			} else {
				result.notImplemented()
			}
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode != REQUEST_CREATE_PDF) {
			return
		}

		val result = pendingPdfResult
		val bytes = pendingPdfBytes
		val fileName = pendingPdfFileName
		pendingPdfResult = null
		pendingPdfBytes = null
		pendingPdfFileName = null

		if (result == null) {
			return
		}

		if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null || fileName == null) {
			result.success(null)
			return
		}

		try {
			contentResolver.openOutputStream(data.data as Uri)?.use { outputStream ->
				outputStream.write(bytes)
				outputStream.flush()
			}
			result.success(fileName)
		} catch (error: Exception) {
			result.error("SAVE_FAILED", error.message, null)
		}
	}
}
