package com.ma.itbox

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ma.itbox/email_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendEmailWithAttachment") {
                val filePath = call.argument<String>("filePath")
                val recipient = call.argument<String>("recipient") ?: ""
                val subject = call.argument<String>("subject") ?: ""
                val body = call.argument<String>("body") ?: ""

                try {
                    val emailIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "message/rfc822"
                        if (recipient.isNotEmpty()) {
                            putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                        }
                        putExtra(Intent.EXTRA_SUBJECT, subject)
                        putExtra(Intent.EXTRA_TEXT, body)

                        if (!filePath.isNullOrEmpty()) {
                            val file = File(filePath)
                            val authority = "${applicationContext.packageName}.fileprovider"
                            val uri: Uri = FileProvider.getUriForFile(applicationContext, authority, file)
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    }

                    val chooser = Intent.createChooser(emailIntent, "Choose Email App")
                    chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("EMAIL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
