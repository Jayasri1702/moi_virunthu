package com.example.moi_virunthu

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.moi_virunthu/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register USB Printer Plugin
        flutterEngine.plugins.add(UsbPrinterPlugin())

        // WhatsApp integration
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendToWhatsApp") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                val filePath = call.argument<String>("filePath")

                if (phone != null && message != null && filePath != null) {
                    val success = sendToWhatsApp(phone, message, filePath)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone, message, and filePath are required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendToWhatsApp(phone: String, message: String, filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                return false
            }

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, message)
                putExtra("jid", "$phone@s.whatsapp.net")
                setPackage("com.whatsapp")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val packageManager = applicationContext.packageManager
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                true
            } else {
                intent.setPackage("com.whatsapp.w4b")
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    true
                } else {
                    false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}